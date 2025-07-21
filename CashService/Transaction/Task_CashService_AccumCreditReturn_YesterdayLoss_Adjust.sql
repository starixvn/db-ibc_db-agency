/*<info serverAlias="DBSIC-bodb02" executers="wsv_CashService" selecters="" viewers="" isFunction="0" isNested=""></info>*/
ALTER PROCEDURE dbo.Task_CashService_AccumCreditReturn_YesterdayLoss_Adjust
    @CustIDList NVARCHAR(MAX), -- JSON: [{CustID,YesterdayLoss}]
	@CashAccumCreditTbl VARCHAR(MAX) = '' OUTPUT
AS
/*
	Created: 20250617@Eden		
	Task: Adjust AccumCreditReturn and CashTransaction for a batch of customers with yesterday loss, input as JSON.
	DB:  DBSIC-bodb02
		
	Revisions:
		- 20250617@Eden: Alpha - Agency Cash Service [redmine: #223896] 
		- 20250624@Eden: Alpha - Agency Cash Service - Sprint 5 [redmine: #223896] 

	Parameter's Explanation:	
			[{"CustID":1,"YesterdayWL":0.25}, 
			{"CustID":2,"YesterdayWL":2.25}]
	Sample:
		DECLARE @CashAccumCreditTbl VARCHAR(MAX)
		EXEC Task_CashService_AccumCreditReturn_YesterdayLoss_Adjust
			@CustIDList = '[
				{"CustID":187909799,"YesterdayWL": -207}, 
				{"CustID":236672808,"YesterdayWL":-210}]',
			@CashAccumCreditTbl = @CashAccumCreditTbl OUTPUT
		SELECT @CashAccumCreditTbl
		
		SELECT * FROM CashTransaction (NOLOCK) WHERE custid in(187909799,236672808) AND TransactiontypeID = 10 AND createdTime = CONVERT(DATE,GETDATE())
		SELECT * FROM CashAccumCredit (NOLOCK) WHERE custid in(187909799,236672808) 

*/ 
BEGIN
    SET NOCOUNT ON;
	DECLARE @SiteDBGroupID SMALLINT
	SELECT @SiteDBGroupID = dbo.f_Get_SiteDBGroupID()
	DECLARE @CurrentDate DATE = GETDATE()
	DECLARE @UserID INT = 0

	DECLARE @tmp_LogData AS TABLE (
		 UserID	INT
		,CustID	INT
		,ActionID INT
		,TrackingValue	VARCHAR(MAX)
		,TrackingValue2	VARCHAR(MAX)
	)

	DECLARE @CashTransactionLog TABLE
	(
		 CustID INT
		,Amount MONEY
		,AdjustCreditAmt MONEY
		,Old_Amount MONEY
		,Old_AdjustCreditAmt MONEY
	)

    --Parse JSON input to temp table
    DECLARE @TempLossTbl TABLE (
        CustID INT PRIMARY KEY,
        YesterdayWL MONEY,
        NewAdjustAmt MONEY DEFAULT(0),
		CustDBGroupID SMALLINT,
		SiteDBGroupID SMALLINT
    );
    INSERT INTO @TempLossTbl (CustID, YesterdayWL)
    SELECT CustID, YesterdayWL
    FROM OPENJSON(@CustIDList)
    WITH (
        CustID INT,
        YesterdayWL MONEY
    )
	WHERE YesterdayWL < 0

    -- Calculate NewAdjustAmt
    UPDATE w
    SET NewAdjustAmt = CASE	WHEN w.YesterdayWL - ISNULL(c.Amount,0) < 0 
								THEN w.YesterdayWL - ISNULL(c.Amount,0) 
								ELSE 0 END,
		CustDBGroupID = s.CustDBGroupID,
		SiteDBGroupID = s.SiteDBGroupID
    FROM @TempLossTbl w
		LEFT JOIN CashTransaction c WITH(NOLOCK) 
			ON w.CustID = c.CustID
			AND c.TransactionTypeID = 10
			AND c.CreatedTime = @CurrentDate
		INNER JOIN custdb.dbo.vw_CashService_Customer ci WITH(NOLOCK)
			ON w.custid = ci.custid
		INNER JOIN custdb.dbo.[Site] s WITH(NOLOCK)
			ON ci.[site] = s.[site]

	--Delete if Wrong sitedb
	DELETE @TempLossTbl WHERE SiteDBGroupID <> @SiteDBGroupID

	 -- Update CashAccumCredit, only if value changes
    DECLARE @CashAccumCredit TABLE (
		CustID INT NOT NULL,
		recommend INT NOT NULL,
		mrecommend INT NOT NULL,
		srecommend INT NOT NULL,
		AccumCreditReturn MONEY NOT NULL,
		ModifiedDate DATETIME NOT NULL,
		RepUpdateTime DATETIME2 NULL,
		NewAdjustAmt MONEY
	)

    UPDATE c WITH(UPDLOCK,ROWLOCK)
    SET AccumCreditReturn = CASE WHEN AccumCreditReturn + w.NewAdjustAmt < 0 THEN 0 
									  ELSE AccumCreditReturn + w.NewAdjustAmt 
								 END,
        ModifiedDate = @CurrentDate,
        RepUpdateTime = dbo.f_getdatetime2()
    OUTPUT inserted.CustID, inserted.recommend,inserted.mrecommend,inserted.srecommend,inserted.AccumCreditReturn,inserted.ModifiedDate,inserted.RepUpdateTime, inserted.AccumCreditReturn - deleted.AccumCreditReturn
	INTO @CashAccumCredit(CustID,recommend,mrecommend,srecommend,AccumCreditReturn,ModifiedDate,RepUpdateTime,NewAdjustAmt)
    FROM @TempLossTbl w
		INNER JOIN CashAccumCredit c WITH(UPDLOCK,ROWLOCK) ON w.CustID = c.CustID
    WHERE w.NewAdjustAmt < 0

	--Update NewAdjustAmt = Real adjust value of CashAccumCredit table
	UPDATE t
	SET t.NewAdjustAmt = c.NewAdjustAmt
	FROM @TempLossTbl t
		INNER JOIN @CashAccumCredit c
			ON t.CustID = c.CustID

	-- Update CashTransaction if change Yesterday Loss Amount
    UPDATE c WITH(UPDLOCK,ROWLOCK)
    SET AdjustCreditAmt = AdjustCreditAmt + w.NewAdjustAmt,
        Amount = w.YesterdayWL,
        CreatedTime = @CurrentDate,
		ExtraInfo = JSON_MODIFY(ISNULL(ExtraInfo,'{}'),'append $.adjhistory',JSON_QUERY('{"Amt":'+ CONVERT(VARCHAR(30),c.Amount)+',"AdjustAmt":'+ CONVERT(VARCHAR(30),c.AdjustCreditAmt)+'}')),
        RepUpdateTime = dbo.f_getdatetime2()
	OUTPUT inserted.CustID, inserted.Amount, inserted.AdjustCreditAmt, deleted.Amount, deleted.AdjustCreditAmt
	INTO @CashTransactionLog(CustID,Amount,AdjustCreditAmt,Old_Amount,Old_AdjustCreditAmt)
    FROM @TempLossTbl w
		INNER JOIN CashTransaction c WITH(UPDLOCK,ROWLOCK)
			ON w.CustID = c.CustID 
			AND c.CreatedTime = @CurrentDate
			AND c.TransactionTypeID = 10
    WHERE NewAdjustAmt < 0

    -- Insert new CashTransaction if not exists
    INSERT INTO CashTransaction (CustID, TransactionTypeID, CreatedTime, RepUpdateTime, Amount, AdjustCreditAmt, StatusId, Creator, SiteDBGroupID, ExtraInfo)
	OUTPUT inserted.CustID, inserted.Amount, inserted.AdjustCreditAmt
	INTO @CashTransactionLog(CustID,Amount,AdjustCreditAmt)
    SELECT 
        w.CustID, 
        10							AS TransactionTypeID, 
        @CurrentDate				AS CreatedTime, 
        dbo.f_getdatetime2()		AS RepUpdateTime,
        w.YesterdayWL				AS Amount, 
        w.NewAdjustAmt				AS AdjustCreditAmt,
		2							AS StatusId,
		0							AS Creator,
		@SiteDBGroupID				AS SiteDBGroupID,
		NULL						AS ExtraInfo
    FROM @TempLossTbl w
    WHERE NewAdjustAmt < 0
		AND NOT EXISTS (
            SELECT 1 FROM CashTransaction c WITH(NOLOCK)
            WHERE c.CustID = w.CustID
              AND c.CreatedTime = @CurrentDate
              AND c.TransactionTypeID = 10
        );

    -- 2.1.6: Return updated CashAccumCredit as JSON
    SELECT @CashAccumCreditTbl = (
		SELECT c.CustID,recommend,mrecommend,srecommend,AccumCreditReturn,ModifiedDate,RepUpdateTime,t.CustDBGroupID
		FROM @CashAccumCredit c
			INNER JOIN @TempLossTbl t ON c.CustID = t.CustID
		FOR JSON PATH
	)

	INSERT INTO @tmp_LogData(UserID,CustID,ActionID,TrackingValue,TrackingValue2)
	SELECT UserID = @UserID
		,w.CustID
		,ActionID = 310105
		,TrackingValue = '<R Amount="'+ COALESCE(CAST(w.Amount AS VARCHAR(100)), SPACE(1)) + '" ' +
						 'AdjustCreditAmt="'+ COALESCE(CAST(w.AdjustCreditAmt AS VARCHAR(100)), SPACE(1)) + '" />'
		,TrackingValue2 = CASE WHEN w.Old_Amount IS NOT NULL THEN
						'<R Amount="'+ COALESCE(CAST(w.Old_Amount AS VARCHAR(100)), SPACE(1)) + '" ' +
						 'AdjustCreditAmt="'+ COALESCE(CAST(w.Old_AdjustCreditAmt AS VARCHAR(100)), SPACE(1)) + '" />'
				END
	FROM @CashTransactionLog w

	SELECT UserID,
		c.CustID,
		c.ActionID,
		c.TrackingValue,
		c.TrackingValue2,
		NULL AS TrackingValueMask,
		NULL AS TrackingValueMask2,
		t.CustDBGroupID
	FROM @tmp_LogData c
		INNER JOIN @TempLossTbl t ON c.CustID = t.CustID
END
GO
