/*<info serverAlias="DBSIC-bodb02" executers="wsv_CashService" selecters="" viewers="" isFunction="0" isNested=""></info>*/
ALTER PROCEDURE dbo.Task_CashService_UpdateExpiredStatus
   @IsTest BIT = 0
AS
/*
	Created: 20250626@Eden		
	Task: Set Expired for pending deposit status
	DB:  DBSIC-bodb02
		
	Revisions:
		- 20250626@Eden: Alpha - Agency Cash Service - Sprint 5 [redmine: #223896] 
		- 20250723@Eden: Alpha - Agency Cash Service - Sprint 7 [redmine: #233481] 
		- 20250808@Eden: Alpha - Agency Cash Service - Sprint 8 [redmine: #235012]

	Parameter's Explanation:	
			
	Sample:
	EXEC  Task_CashService_UpdateExpiredStatus @IsTest = 0

*/ 
BEGIN
    SET NOCOUNT ON;
	DECLARE @UserID INT = 10278938 --starixIT
		, @MaxLoop INT = 10
		, @LoopCnt INT = 0
		, @BatchNum INT = 1000
		, @ExpriredTime INT = 60 -- Minutes

	CREATE TABLE #TransID_tbl (TransId bigint)
	DECLARE @tmp_LogData AS TABLE (CustID INT, TransID BIGINT)

	WHILE 1 = 1 -- Loop update by Batch
	BEGIN
		TRUNCATE TABLE #TransID_tbl

		INSERT INTO #TransID_tbl(TransId)
		SELECT TOP (@BatchNum) c.TransID
		FROM CashTransaction c WITH(NOLOCK)
			CROSS APPLY (
				SELECT TOP 1 1 AS IsTest
				FROM CustDB.dbo.custInfo ci WITH (NOLOCK)
				WHERE ci.custid = c.CustID
					AND 1 = CASE WHEN @IsTest = 1 AND ci.currency = 20 THEN 1
								WHEN @IsTest = 0 THEN 1
							ELSE 0 END
			)ci
		WHERE c.TransactionTypeID = 1 -- Manual Deposit
			AND ISNULL(c.OperatedTime, c.CreatedTime) < DATEADD(Minute, - @ExpriredTime, GETDATE())
			AND c.StatusId = 2 --Pending
			AND ISNULL(JSON_VALUE(c.ExtraInfo, '$.IsProcessing'),0) = 0 -- not locked transaction

		IF @@ROWCOUNT = 0
			BREAK

		--Update Transaction
		UPDATE c WITH(ROWLOCK,UPDLOCK)
		SET c.StatusId = 3 --Expired
			,c.OperatedTime = GETDATE()
			,c.OperatedBy = @UserID
			,c.SubAccID = 0
			,c.RepUpdateTime = dbo.f_getdatetime2()
		OUTPUT inserted.CustID, inserted.TransId INTO @tmp_LogData(CustID, TransID)
		FROM CashTransaction c WITH(ROWLOCK,UPDLOCK)
			INNER JOIN #TransID_tbl t 
				ON t.TransID = c.TransID
		WHERE c.StatusId = 2 --Pending
			AND ISNULL(JSON_VALUE(c.ExtraInfo, '$.IsProcessing'),0) = 0 -- not locked transaction
			AND ISNULL(c.OperatedTime, c.CreatedTime) < DATEADD(Minute, - @ExpriredTime, GETDATE())

		SET @LoopCnt = @LoopCnt + 1

		IF @LoopCnt > @MaxLoop 
			BREAK
	END

	DECLARE @TrackingValue	VARCHAR(MAX)
		,@TrackingValue2	VARCHAR(MAX)

	SELECT @TrackingValue =
								'<R custid="<CustID>" ' +
								'UserID="'+ COALESCE(CAST(@UserID AS VARCHAR(20)), SPACE(1)) + '" ' +
								'StatusId="'+ COALESCE(CAST(3 AS VARCHAR(3)), SPACE(1)) + '" ' +
								'TransId="<TransID>" />'

	SELECT @TrackingValue2 =
								'<R custid="<CustID>" ' +
								'UserID="'+ COALESCE(CAST(@UserID AS VARCHAR(20)), SPACE(1)) + '" ' +
								'StatusId="'+ COALESCE(CAST(2 AS VARCHAR(3)), SPACE(1)) + '" ' +
								'TransId="<TransID>" />'

	--Return Log
	SELECT UserID = @UserID
		,w.CustID
		,ActionID = 310016
		,TrackingValue = REPLACE(REPLACE(@TrackingValue,'<CustID>',w.CustID),'<TransID>',w.TransID)
		,TrackingValue2 = REPLACE(REPLACE(@TrackingValue2,'<CustID>',w.CustID),'<TransID>',w.TransID)
		,TrackingValueMask = NULL
		,TrackingValueMask2 = NULL
		,s.CustDBGroupID
	FROM @tmp_LogData w
		INNER JOIN custdb.dbo.vw_CashService_Customer ci WITH(NOLOCK)
			ON w.custid = ci.custid
		INNER JOIN custdb.dbo.[Site] s WITH(NOLOCK)
			ON ci.[site] = s.[site]

	DROP TABLE #TransID_tbl
END
GO
