/*<info serverAlias="DBSIC-bodb02,DBCTG-bodb02" executers="bodbDownlineNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE  [dbo].[Age_ClearBalanceCust_Job_ReTrySel]
	@NumOfThread	INT = 4
	,@ErrCode		INT = 0 OUTPUT
	,@ErrMsg		NVARCHAR(4000) = '' OUTPUT
	,@IsCompleted	BIT = 0 OUTPUT
AS
/*
	Created:20230227@bobby
	Task: 182071 - Auto Transfer/ Multiple Transfer	
	DB: DBSIC-bodb02,DBCTG-bodb02

	Revisions:
		- 20230227@bobby: INIT [RedmineID: #182071]

	Param's Explanation:
		• @NumOfBatch: Number of thread(s) are being run by WEB

*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @RunningMode	VARCHAR(15),
		@TotalThread		INT
	;

	SELECT @TotalThread = ISNULL(@NumOfThread, 2),
		@RunningMode	= 'ReTry',
		@ErrCode		= 0,
		@ErrMsg			= '',
		@IsCompleted	= 1
		;

	DROP TABLE IF EXISTS #tmpClearBalanceCust_BatchLog;
	CREATE TABLE #tmpClearBalanceCust_BatchLog (SuperId INT, BatchNo INT, FromCustId INT, ToCustId INT, INDEX IDX CLUSTERED (BatchNo, FromCustId));

	--TODO: NOT Running Super
	WITH CTE_ProcessingBatch AS (
		SELECT rs.SuperId
		FROM dbo.Age_ClearBalanceCust_RunningSuper rs WITH(UPDLOCK)
		WHERE rs.RunningBatchNo = 0 ---> NOT running
			AND rs.RunningTotal > 0 ---> 1 batch at least
	),
	CTE_ClearBalanceCust_ReTry AS (
		SELECT p.SuperId, p.BatchNo, p.FromCustId, p.ToCustId
		FROM dbo.Age_ClearBalanceCust_Process p WITH(UPDLOCK)
			INNER JOIN CTE_ProcessingBatch cte ON cte.SuperId = p.SuperId
			INNER JOIN dbo.f_Age_ClearBalanceCust_ErrorSel() err ON err.ErrType = JSON_VALUE(p.Result, '$.ErrType')
		WHERE p.[Status] IN ('Failed', 'Pending') 
			AND DATEDIFF(MINUTE, p.ModifiedTime, CURRENT_TIMESTAMP) >= 1 -- 1 minute delay time
			AND err.AllowReTry = 1
			AND 1 = CASE 
						WHEN err.ErrType = 'TransferUM' AND ISNULL(p.TryCount, 1) BETWEEN 1 AND 59 THEN 1 
						WHEN ISNULL(p.TryCount, 1) BETWEEN 1 AND 4 THEN 1
						ELSE 0
					END
	),
	CTE_RetryBatch AS (
		SELECT TOP(@NumOfThread) SuperId, BatchNo
		FROM (
			SELECT p.SuperId, p.BatchNo
				,ROW_NUMBER() OVER (PARTITION BY p.SuperID ORDER BY p.BatchNo ASC) AS runIdx
			FROM CTE_ClearBalanceCust_ReTry p
			GROUP BY p.SuperId, p.BatchNo
		) AS t
		WHERE t.runIdx = 1
		ORDER BY t.BatchNo ASC
	)
	UPDATE p WITH(ROWLOCK, UPDLOCK)
		SET p.[Status] = 'Waiting'
			, p.ModifiedTime = CURRENT_TIMESTAMP, p.StartTime = NULL, p.EndTime = NULL, p.Amount = NULL
			, p.TryCount = ISNULL(p.TryCount, 0) + 1
		OUTPUT INSERTED.SuperId, INSERTED.BatchNo, INSERTED.FromCustId, INSERTED.ToCustId
		INTO #tmpClearBalanceCust_BatchLog (SuperId, BatchNo, FromCustId, ToCustId)
	FROM  dbo.Age_ClearBalanceCust_Process p
	INNER JOIN CTE_RetryBatch bl ON bl.SuperId = p.SuperId AND bl.BatchNo = p.BatchNo
	INNER JOIN CTE_ClearBalanceCust_ReTry rt ON rt.FromCustId = p.FromCustId AND rt.ToCustId = p.ToCustId

	--TODO: SET Running Super
	;WITH CTE_Super AS (
		SELECT DISTINCT SuperId, BatchNo
		FROM #tmpClearBalanceCust_BatchLog
	)
	UPDATE rs WITH(ROWLOCK, UPDLOCK)
	SET rs.RunningBatchNo = cte.BatchNo
	FROM dbo.Age_ClearBalanceCust_RunningSuper rs
	INNER JOIN CTE_Super cte ON cte.SuperId = rs.SuperId
	;

	--OUTPUT
	SELECT bl.BatchNo, bl.FromCustId, STRING_AGG(bl.ToCustId, ',') AS ToCustIds, @RunningMode AS RunningMode
	FROM #tmpClearBalanceCust_BatchLog bl
	GROUP BY bl.BatchNo, bl.FromCustId
	ORDER BY bl.BatchNo ASC;

	-- CHECK: Completed or NOT
	SELECT @IsCompleted = MAX(IsCompletedCheck)
	FROM (
		SELECT TOP(1) IsCompletedCheck = 0
		FROM dbo.Age_ClearBalanceCust_Process p WITH(NOLOCK) 
		WHERE 
			p.Status IN ('New', 'Waiting', 'Processing') --> Main Thread running
			OR (p.Status IN ('Failed') AND p.TryCount BETWEEN 1 AND 4) --> ReTry Thread running
			OR (p.Status IN ('Pending') AND p.TryCount BETWEEN 1 AND 59) --> TransferUM Pending
	
		UNION ALL -- CHECK: Today snapshot COMPLETED OR NOT
		SELECT 0
		WHERE NOT EXISTS (
			SELECT TOP 1 1
			FROM dbo.Age_ClearBalanceCust_Process p WITH(NOLOCK) 
		)
	) AS ck;

	-- TODO: Update AutoJob CompletedTime
	IF @IsCompleted = 1
	BEGIN
		EXEC [dbo].[Age_ClearBalanceCust_Job_RuntimeUpd] @IsCompleted = 1
	END
END
GO