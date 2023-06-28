/*<info serverAlias="DBTXN-bodb02" executers="bodbDownlineNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE  [dbo].[Age_ClearBalanceCust_Job_BatchSel]
	@NumOfThread	INT = 4
	,@RunningMode	VARCHAR(15) = 'Normal'
	,@ErrCode		INT = 0 OUTPUT
	,@ErrMsg		NVARCHAR(4000) = '' OUTPUT
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

	DECLARE @TotalThread	INT;

	SELECT @TotalThread = ISNULL(@NumOfThread, 4),
		@RunningMode	= ISNULL(@RunningMode, 'Normal'),
		@ErrCode		= 0,
		@ErrMsg			= ''
		;

	DROP TABLE IF EXISTS #tmpClearBalanceCust_BatchLog;
	CREATE TABLE #tmpClearBalanceCust_BatchLog (SuperId INT, BatchNo INT, FromCustId INT, ToCustId INT, INDEX IDX CLUSTERED (BatchNo, FromCustId));

	--TODO: NOT Running Super
	WITH CTE_ProcessingBatch AS (
		SELECT rs.SuperId
		FROM dbo.Age_ClearBalanceCust_RunningSuper rs WITH(UPDLOCK)
		WHERE rs.RunningBatchNo = 0
			AND rs.RunningTotal < rs.TotalBatch
	),
	CTE_SuperBatch AS (
		SELECT TOP(@NumOfThread) SuperId, BatchNo
		FROM (
			SELECT p.SuperId, p.BatchNo
				,ROW_NUMBER() OVER (PARTITION BY p.SuperID ORDER BY p.BatchNo ASC) AS runIdx
			FROM dbo.Age_ClearBalanceCust_Process p WITH(UPDLOCK)
				INNER JOIN CTE_ProcessingBatch rs ON rs.SuperId = p.SuperID
			WHERE p.[Status] = 'New'
			GROUP BY p.SuperId, p.BatchNo
		) AS t
		WHERE t.runIdx = 1
	)
	UPDATE p WITH(ROWLOCK, UPDLOCK)
		SET p.[Status] = 'Waiting'
			, p.ModifiedTime = CURRENT_TIMESTAMP
		OUTPUT INSERTED.SuperId, INSERTED.BatchNo, INSERTED.FromCustId, INSERTED.ToCustId
		INTO #tmpClearBalanceCust_BatchLog (SuperId, BatchNo, FromCustId, ToCustId)
	FROM dbo.Age_ClearBalanceCust_Process p
	INNER JOIN CTE_SuperBatch bl ON bl.SuperId = p.SuperID AND bl.BatchNo = p.BatchNo
	WHERE p.[Status] = 'New'

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

	--- OUTPUT
	SELECT bl.BatchNo, bl.FromCustId, STRING_AGG(bl.ToCustId, ',') AS ToCustIds, @RunningMode AS RunningMode
	FROM #tmpClearBalanceCust_BatchLog bl
	GROUP BY bl.BatchNo, bl.FromCustId
	ORDER BY bl.BatchNo ASC;
END
GO