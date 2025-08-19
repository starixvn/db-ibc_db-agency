/*<info serverAlias="DBSIC-bodb02" executers="wsv_CashService" selecters="" viewers="" isFunction="0" isNested=""></info>*/
ALTER PROCEDURE dbo.Task_CashPromotion_UpdateExpiredStatus
   @IsTest BIT = 0
AS
/*
	Created: 20250806@Eden
	Task: Marks expired for pending promotion transactions (TransactionTypeID = 11) older than 30 days
	DB:  DBSIC-bodb02
	
	Revisions:
		- 20250806@Eden: Alpha - Agency Cash Service - Promotion Expiry [redmine: #235012]

	Parameter's Explanation:
	Sample:
	EXEC  Task_CashPromotion_UpdateExpiredStatus @IsTest = 0
*/
BEGIN
    SET NOCOUNT ON;
	DECLARE @UserID INT = 10278938 --starixIT
		, @BatchNum INT = 1000
		, @ExpiredDays INT = 30 -- Days
		 
	CREATE TABLE #TransID_tbl (TransId bigint)
	CREATE TABLE #TransID_tbl_Batch (TransId bigint)
	DECLARE @tmp_LogData AS TABLE (CustID INT, TransID BIGINT)

	INSERT INTO #TransID_tbl(TransId)
	SELECT c.TransID
	FROM CashTransaction c WITH(NOLOCK)
		CROSS APPLY (
			SELECT TOP 1 ci.recommend
			FROM CustDB.dbo.vw_CashService_Customer ci WITH (NOLOCK)
			WHERE ci.custid = c.CustID
				AND 1 = CASE WHEN @IsTest = 1 AND ci.currency = 20 THEN 1
							WHEN @IsTest = 0 THEN 1
							ELSE 0 END
		)ci
		CROSS APPLY (
			SELECT TOP 1 1 AS EnabledCashService
			FROM CustDB.dbo.vw_CustInfoExtra cs WITH (NOLOCK)
			WHERE ci.recommend = cs.CustID
				AND cs.ServiceType = 0 -- Agent disable Cash service
		)cs
	WHERE c.TransactionTypeID = 11 -- Promotion
		AND c.StatusId = 2 --Pending
		AND c.CreatedTime < DATEADD(DAY, -@ExpiredDays, GETDATE())

	WHILE 1 = 1 -- Loop update by Batch
	BEGIN
		TRUNCATE TABLE #TransID_tbl_Batch

		DELETE TOP(@BatchNum) t
		OUTPUT deleted.TransId INTO #TransID_tbl_Batch (TransId)
		FROM #TransID_tbl t

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
			INNER JOIN #TransID_tbl_Batch t 
				ON t.TransID = c.TransID
		WHERE c.StatusId = 2 --Pending
			AND c.TransactionTypeID = 11 -- Promotion
			AND ISNULL(JSON_VALUE(c.ExtraInfo, '$.IsProcessing'),0) = 0 -- not locked transaction
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
		,ActionID = 315104
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
