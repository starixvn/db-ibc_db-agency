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
	CREATE TABLE #tmpClearBalanceCust_BatchLog (SuperId INT, BatchNo INT PRIMARY KEY, RoleID TINYINT, FromCustId INT, ToCustIds VARCHAR(4000));

	--Waiting/Running Batch
	WITH CTE_ProcessingBatch AS (
		SELECT p.SuperId
		FROM dbo.Age_ClearBalanceCust_Process p WITH(NOLOCK)
		WHERE Status IN ('Waiting', 'Running')
		GROUP BY p.SuperId
	)
	INSERT INTO #tmpClearBalanceCust_BatchLog
	SELECT TOP(@NumOfThread) SuperId, BatchNo, RoleID, FromCustId, ToCustIds
	FROM (
		SELECT p.SuperId, p.BatchNo, p.RoleID, p.FromCustId, STRING_AGG(p.ToCustId,',') AS ToCustIds
			,ROW_NUMBER() OVER (PARTITION BY p.SuperID ORDER BY p.BatchNo ASC) AS runIdx
		
		FROM dbo.Age_ClearBalanceCust_Process p WITH(NOLOCK)
			LEFT JOIN CTE_ProcessingBatch rs ON rs.SuperId = p.SuperID
		WHERE rs.SuperId IS NULL -- NOT RUNNING Super
			AND p.[Status] = 'New'
		GROUP BY p.SuperId, p.BatchNo, p.RoleID, p.FromCustId
	) AS t
	WHERE t.runIdx = 1
	ORDER BY t.BatchNo ASC;

	IF EXISTS (SELECT 1 FROM #tmpClearBalanceCust_BatchLog)
	BEGIN
		BEGIN TRY
			BEGIN TRAN 
			UPDATE p WITH(ROWLOCK, UPDLOCK)
			SET p.[Status] = 'Waiting'
				, p.ModifiedTime = CURRENT_TIMESTAMP
			FROM  dbo.Age_ClearBalanceCust_Process p
			INNER JOIN #tmpClearBalanceCust_BatchLog bl ON bl.SuperId = p.SuperID AND bl.BatchNo = p.BatchNo

			COMMIT;
		END TRY
		BEGIN CATCH
			IF @@TRANCOUNT > 0
				ROLLBACK;

			SELECT @ErrCode = 101
				,@ErrMsg = ERROR_MESSAGE()
		END CATCH
	END

	SELECT bl.BatchNo, bl.FromCustId, bl.ToCustIds, @RunningMode AS RunningMode
		--, CONCAT('EXEC dbo.Age_ClearBalanceCust_Job_BatchProcess @BatchNo=', BatchNo, ', @FromCustId=', FromCustId, ', @ToCustIds=''', ToCustIds, ''', @RunningMode=''', @RunningMode, '''')
	FROM #tmpClearBalanceCust_BatchLog bl
	ORDER BY bl.BatchNo ASC;
END
GO