/*<info serverAlias="DBTXN-bodb02" executers="bodbDownlineNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE  [dbo].[Age_ClearBalanceCust_Job_ReTrySel]
	@NumOfThread	INT = 4
	,@ErrCode		INT = 0 OUTPUT
	,@ErrMsg		NVARCHAR(4000) = '' OUTPUT
	,@IsCompleted	BIT = 0 OUTPUT
AS
/*
	Created:20230227@bobby
	Task: 182071 - Auto Transfer/ Multiple Transfer	
	DB: DBTXN/bodb02

	Revisions:
		- 20230227@bobby: INIT [RedmineID: #182071]

	Param's Explanation:
		• @NumOfBatch: Number of thread(s) are being run by WEB

*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @RunningMode	VARCHAR(15),
		@TotalThread		INT;

	SELECT @TotalThread = ISNULL(@NumOfThread, 2),
		@RunningMode	= 'ReTry',
		@ErrCode		= 0,
		@ErrMsg			= '',
		@IsCompleted	= 1
		;

	DROP TABLE IF EXISTS #tmpClearBalanceCust_BatchLog;
	CREATE TABLE #tmpClearBalanceCust_BatchLog (SuperId INT, BatchNo INT PRIMARY KEY, RoleID TINYINT, FromCustId INT, ToCustIds VARCHAR(4000));

	DROP TABLE IF EXISTS #tmpClearBalanceCust_ReTry;
	CREATE TABLE #tmpClearBalanceCust_ReTry (SuperId INT, BatchNo INT, RoleID TINYINT, FromCustId INT, ToCustId INT PRIMARY KEY);

	--TODO: Check ReTry pair(s) IF any
	INSERT INTO #tmpClearBalanceCust_ReTry (SuperId, BatchNo, RoleID, FromCustId, ToCustId)
	SELECT p.SuperId, p.BatchNo, p.RoleID, p.FromCustId, p.ToCustId
	FROM dbo.Age_ClearBalanceCust_Process p WITH(NOLOCK)
	WHERE p.[Status] = 'Failed' 
		AND ISJSON(p.Result) > 0 AND JSON_VALUE(p.Result, '$.ErrType') IN ('DBIssue','TransferUM', 'AccTransfering', 'ProcessingTime', 'BalanceZero')
		AND DATEDIFF(MINUTE, p.ModifiedTime, CURRENT_TIMESTAMP) >= 1 -- 1 minute delay time
		AND ISNULL(p.TryCount, 1) BETWEEN 1 AND 4

	--TODO: Waiting Batch
	INSERT INTO #tmpClearBalanceCust_BatchLog
	SELECT TOP(@NumOfThread) SuperId, BatchNo, RoleID, FromCustId, ToCustIds
	FROM (
		SELECT p.SuperId, p.BatchNo, p.RoleID, p.FromCustId, STRING_AGG(p.ToCustId,',') AS ToCustIds
			,ROW_NUMBER() OVER (PARTITION BY p.SuperID ORDER BY p.BatchNo ASC) AS runIdx
		FROM #tmpClearBalanceCust_ReTry p
		GROUP BY p.SuperId, p.BatchNo, p.RoleID, p.FromCustId
	) AS t
	WHERE t.runIdx = 1
	ORDER BY t.BatchNo ASC;

	IF EXISTS (SELECT 1 FROM #tmpClearBalanceCust_BatchLog)
	BEGIN
		BEGIN TRY
			UPDATE p WITH(ROWLOCK, UPDLOCK)
			SET p.[Status] = 'Waiting'
				, p.ModifiedTime = CURRENT_TIMESTAMP, p.StartTime = NULL, p.EndTime = NULL, p.Amount = NULL
				, p.TryCount = ISNULL(p.TryCount, 0) + 1
			FROM  dbo.Age_ClearBalanceCust_Process p
			INNER JOIN #tmpClearBalanceCust_BatchLog bl ON bl.SuperId = p.SuperId AND bl.BatchNo = p.BatchNo
			INNER JOIN #tmpClearBalanceCust_ReTry rt ON rt.SuperId = bl.SuperId AND rt.BatchNo = bl.BatchNo AND rt.FromCustId = p.FromCustId AND rt.ToCustId = p.ToCustId

		END TRY
		BEGIN CATCH
			SELECT @ErrCode = 101
				,@ErrMsg = ERROR_MESSAGE()
		END CATCH
	END

	SELECT bl.BatchNo, bl.FromCustId, bl.ToCustIds, @RunningMode AS RunningMode
		--, CONCAT('EXEC dbo.Age_ClearBalanceCust_Job_BatchProcess @BatchNo=', BatchNo, ', @FromCustId=', FromCustId, ', @ToCustIds=''', ToCustIds, ''', @RunningMode=''', @RunningMode, '''')
	FROM #tmpClearBalanceCust_BatchLog bl
	ORDER BY bl.BatchNo ASC;

	-- CHECK: Finished or NOT
	SELECT TOP(1) @IsCompleted = 0
	FROM Age_ClearBalanceCust_Process p WITH(NOLOCK) 
	WHERE 
		p.Status IN ('New', 'Waiting', 'Processing')	--> Main Thread running
		OR (p.Status IN ('Failed') AND p.TryCount BETWEEN 1 AND 4) --> ReTry Thread running

END
GO