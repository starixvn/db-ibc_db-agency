/*<info serverAlias="DBSIC-bodb02" executers="asv_CashService,wsv_CashService" selecters="" viewers="" isFunction="0" isNested=""></info>*/
ALTER PROCEDURE dbo.Age_CashPromotion_Reject_Multiple
(
    @AgentID INT,
	@TransIds VARCHAR(MAX), -- Json, multiple TransID
	@SubAccID INT = 0,
	@StatusId TINYINT = 5,
    @IP VARCHAR(50) = '',
	@ErrCode	INT = 0 OUTPUT,
	@ErrMsg	VARCHAR(2000) = NULL OUTPUT,
	@ErrExtraInfo	VARCHAR(MAX) OUTPUT
)
AS
/*
	Created: 20250729@Eden		
	Task: Reject Multiple Pending Promotion under Agent
	DB:  DBSIC-bodb02
		
	Revisions:
		- 20250723@Eden: Alpha - Agency Cash Service - Sprint 7 [redmine: #233481] 

	Parameter's Explanation:	
		@StatusId: 
			3: Expired
			5: Rejected

		@TransIds:
			[
				{"CustID":1176092,"TransID":414256454774554624},
				{"CustID":1176097,"TransID":414256454774554625}
			]

	DECLARE @ErrCode INT,
			@ErrMsg VARCHAR(2000),
			@ErrExtraInfo VARCHAR(MAX)
	EXEC Age_CashPromotion_Reject_Multiple  
		 @TransIds = '[{"CustID":2211693,"TransID":415381109140881409},{"CustID":12548899,"TransID":415380237262520322},{"CustID":12548899,"TransID":415380666759249922}]'
		,@AgentID = 1176086
		,@SubAccID = 1997747
		,@StatusId = 5
		,@IP = '1.1.1.1'
		,@ErrCode = @ErrCode OUTPUT
		,@ErrMsg = @ErrMsg OUTPUT
		,@ErrExtraInfo = @ErrExtraInfo OUTPUT
	SELECT @ErrCode AS ErrCode, @ErrMsg AS ErrMsg, @ErrExtraInfo AS ErrExtraInfo

*/ 
BEGIN
    SET NOCOUNT ON;
	DECLARE @SubAccName VARCHAR(30) = ''

	IF @StatusId NOT IN (5, 3)
	BEGIN
		SELECT @ErrCode = 101, @ErrMsg = 'Invalid StatusID.'
		RETURN
	END

	DECLARE @Trans_Tbl TABLE (
        CustID INT ,
        TransID BIGINT PRIMARY KEY
	)

	DECLARE @Err_Tbl TABLE (
        CustID INT ,
        TransID BIGINT,
		ErrorMsg VARCHAR(100)
	)

	INSERT INTO @Trans_Tbl (CustID, TransID)
    SELECT DISTINCT CustID, TransID
    FROM OPENJSON(@TransIds)
    WITH (CustID INT,TransID BIGINT)

	DELETE t
	OUTPUT deleted.TransID
		, deleted.CustID
		, 'Invalid TransID'
	INTO @Err_Tbl(TransID,CustID,ErrorMsg)
	FROM @Trans_Tbl t
		LEFT JOIN CashTransaction c WITH (NOLOCK)
			ON t.CustID = c.CustId 
			AND t.TransID = c.TransID
			AND c.TransactionTypeID = 11
		LEFT JOIN custdb.dbo.vw_CashService_Customer ci WITH(NOLOCK) 
			ON c.CustId = ci.custid
			AND ci.recommend = @AgentID
	WHERE ci.custid IS NULL

	DELETE t
	OUTPUT deleted.TransID
		, deleted.CustID
		, 'Invalid StatusID'
	INTO @Err_Tbl(TransID,CustID,ErrorMsg)
	FROM @Trans_Tbl t
		LEFT JOIN CashTransaction c WITH (NOLOCK)
			ON t.CustID = c.CustId 
			AND t.TransID = c.TransID
			AND c.TransactionTypeID = 11
			AND c.StatusId = 2
	WHERE c.custid IS NULL

	BEGIN TRY
		IF @SubAccID > 0 
		BEGIN	
			EXEC Age_GetSubAccName
				@SubAccID = @SubAccID,
				@SubAccName = @SubAccName OUTPUT
		END
	END TRY
	BEGIN CATCH
		PRINT 'Cannot get SubAccName'
		SET @SubAccName = ''
	END CATCH

	DECLARE @BatchNum INT = 1000

	CREATE TABLE #TransID_tblBatch (TransId bigint)
	DECLARE @tmp_LogData AS TABLE (CustID INT, TransId bigint)

	WHILE 1 = 1 -- Loop update by Batch
	BEGIN
		TRUNCATE TABLE #TransID_tblBatch

		DELETE TOP (@BatchNum) t
		OUTPUT deleted.TransID INTO #TransID_tblBatch
		FROM @Trans_Tbl t

		IF @@ROWCOUNT = 0
			BREAK

		--Update Transaction
		UPDATE c WITH(ROWLOCK,UPDLOCK)
		SET c.StatusId = @StatusId
			,c.OperatedTime = GETDATE()
			,c.OperatedBy = @AgentID
			,c.SubAccID = @SubAccID
			,c.RepUpdateTime = dbo.f_getdatetime2()
		OUTPUT inserted.CustID,inserted.TransId INTO @tmp_LogData(CustID,TransId)
		FROM CashTransaction c WITH(ROWLOCK,UPDLOCK)
			INNER JOIN #TransID_tblBatch t 
				ON t.TransID = c.TransID
		WHERE c.StatusId = 2 --Pending
			ANd c.TransactionTypeID = 11
			AND ISNULL(JSON_VALUE(c.ExtraInfo, '$.IsProcessing'),0) = 0 -- not locked transaction
	END

	DECLARE @TrackingValue	VARCHAR(MAX)
		,@TrackingValue2	VARCHAR(MAX)

	SELECT @TrackingValue =
								'<R custid="<CustID>" ' +
								'UserID="'+ COALESCE(CAST(@AgentID AS VARCHAR(20)), SPACE(1)) + '" ' +
								'SubAccName="'+ COALESCE(CAST(@SubAccName AS VARCHAR(30)), SPACE(1)) + '" ' +
								'StatusId="'+ COALESCE(CAST(@StatusId AS VARCHAR(3)), SPACE(1)) + '" ' +
								'TransId="<TransID>" ' +
								'IP="'+ COALESCE(CAST(@IP AS VARCHAR(50)), SPACE(1)) + '" />'

	SELECT @TrackingValue2 =
								'<R custid="<CustID>" ' +
								'UserID="'+ COALESCE(CAST(@AgentID AS VARCHAR(20)), SPACE(1)) + '" ' +
								'SubAccName="'+ COALESCE(CAST(@SubAccName AS VARCHAR(30)), SPACE(1)) + '" ' +
								'StatusId="'+ COALESCE(CAST(2 AS VARCHAR(3)), SPACE(1)) + '" ' +
								'TransId="<TransID>" ' +
								'IP="'+ COALESCE(CAST(@IP AS VARCHAR(50)), SPACE(1)) + '" />'

	--Return Log
	SELECT UserID = @AgentID
		,w.CustID
		,ActionID = 315103
		,TrackingValue = REPLACE(REPLACE(@TrackingValue,'<CustID>',w.CustID),'<TransID>',w.TransID)
		,TrackingValue2 = REPLACE(REPLACE(@TrackingValue2,'<CustID>',w.CustID),'<TransID>',w.TransID)
		,TrackingValueMask = NULL
		,TrackingValueMask2 = NULL
	FROM @tmp_LogData w

	IF EXISTS( SELECT 1 FROM @Err_Tbl)
	BEGIN
		SELECT @ErrExtraInfo =
		(
			SELECT e.CustID, e.TransID, e.ErrorMsg 
			FROM @Err_Tbl e
			FOR Json Path
		)
		
	END

	DROP TABLE #TransID_tblBatch
    SET NOCOUNT OFF;
END;