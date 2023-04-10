/*<info serverAlias="DBTXN-bodb02" executers="bodbDownlineNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE  [dbo].[Age_ClearBalanceCust_Job_Start]
	@PairOfBatch	INT = 200,
	@TotalPair		INT = 0 OUTPUT,
	@TotalBatch		INT = 0 OUTPUT,
	@TotalSuper		INT = 0 OUTPUT,
	@RunningMode	VARCHAR(15) = 'Normal' OUTPUT,
	@ErrCode		INT = 0 OUTPUT,
	@ErrMsg			NVARCHAR(4000) = '' OUTPUT
AS
/*
	Created:20230227@Bobby
	Task: 182071 - Auto Transfer/ Multiple Transfer	
	DB: DBTXN/bodb02

	Revisions:
		- 20230227@Bobby: AutoJob clear balance downlines [RedmineID: #182071]

	Param's Explanation:
		• @PairOfBatch: The number pairs of batch

*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @SessionDate	SMALLDATETIME,
		@Creator INT = 8; --StarixIT
	;

	SELECT @SessionDate		= CAST(GETDATE() AS DATE),
			@PairOfBatch	= ISNULL(@PairOfBatch, 200),
			@TotalPair		= 0,
			@TotalBatch		= 0,
			@TotalSuper		= 0,
			@RunningMode	= '';

	IF EXISTS (SELECT 1 FROM dbo.[Age_ClearBalanceCust_Process] WITH(NOLOCK) WHERE SessionDate = @SessionDate)
	BEGIN 
		GOTO RESUM_JOB;
	END

	-- TODO: INIT data from current setting
	START_JOB:
	BEGIN
		SET @RunningMode = 'Normal';

		--TODO: CLEANUP data
		DELETE dbo.Age_ClearBalanceCust_RunningSuper;
		DELETE dbo.Age_ClearBalanceCust_BatchLog;
		DELETE dbo.Age_ClearBalanceCust_Process;
		
		DROP TABLE IF EXISTS #tmpClearBalanceCust
		CREATE TABLE #tmpClearBalanceCust(FromCustId INT, ToCustId INT, RoleId TINYINT, SuperId INT, IsAllDayBalTransfer BIT
			, INDEX CIX_SuperRole CLUSTERED (SuperId, RoleId)
		);

		--TODO: get Snapshot from DBCUST
		INSERT INTO #tmpClearBalanceCust (FromCustId, ToCustId, RoleId, SuperId, IsAllDayBalTransfer)
		SELECT FromCustId, ToCustId, RoleId, SuperId, IsAllDayBalTransfer
		FROM OPENQUERY(DBCUST, N'SELECT FromCustId, 
				ToCustId, 
				RoleId, 
				SuperId, 
				IsAllDayBalTransfer  
			FROM CustDB.[dbo].[f_Age_ClearBalanceCust_Snapshot]()');

		IF NOT EXISTS (SELECT TOP 1 1 FROM #tmpClearBalanceCust)
			GOTO OUTPUT_JOB;


		--TODO: Process batching
		DROP TABLE IF EXISTS #tmpClearBalanceCust_RunningSuper;
		DROP TABLE IF EXISTS #tmpClearBalanceCust_Process;
		
		CREATE TABLE #tmpClearBalanceCust_RunningSuper(SuperId INT PRIMARY KEY, TotalDownline INT)
		CREATE TABLE #tmpClearBalanceCust_Process(
			SuperId INT, FromCustId INT, ToCustId INT, RoleID TINYINT, IsAllDayBalTransfer BIT, BatchNo INT
			,INDEX CIX_SuperBatch CLUSTERED (SuperId, BatchNo)
		);

		--TODO: Super order by TotalDownline
		INSERT INTO #tmpClearBalanceCust_RunningSuper
		SELECT SuperID, COUNT(1) AS TotalDownline
		FROM #tmpClearBalanceCust
		GROUP BY SuperID;


		-- TODO: Batching by Super
		INSERT INTO #tmpClearBalanceCust_Process (SuperID, FromCustId, ToCustId, RoleID, IsAllDayBalTransfer, BatchNo)
		SELECT SuperID, FromCustId, ToCustId, RoleID, IsAllDayBalTransfer
			,SUM(CASE WHEN t.superIdx%@PairOfBatch = 1 THEN 1 ELSE 0 END) OVER (ORDER BY t.rIdx) AS BatchNo
		FROM(
			SELECT rc.SuperID, rc.FromCustId, rc.ToCustId, rc.RoleID, rc.IsAllDayBalTransfer
				,ROW_NUMBER() OVER (ORDER BY rs.TotalDownline DESC, rs.SuperID, rc.RoleID, rc.FromCustId, rc.ToCustId) AS rIdx
				,ROW_NUMBER() OVER (
					PARTITION BY rs.TotalDownline, rs.SuperID, rc.RoleID, rc.FromCustId 
					ORDER BY rs.TotalDownline DESC, rs.SuperID, rc.RoleID, rc.FromCustId
				) AS superIdx
			FROM #tmpClearBalanceCust rc
			INNER JOIN #tmpClearBalanceCust_RunningSuper rs ON rs.SuperID = rc.SuperID
		) AS t

		-- TODO: Age_ClearBalanceCust_RunningSuper
		INSERT INTO dbo.Age_ClearBalanceCust_RunningSuper(SuperId, TotalBatch, RunningTotal, RunningBatchNo, TotalDownline)
		SELECT s.SuperId
			,COUNT(DISTINCT p.BatchNo) AS TotalBatch
			,0 AS RunningTotal
			,0 AS RunningBatchNo
			,s.TotalDownline
		FROM #tmpClearBalanceCust_Process p
		INNER JOIN #tmpClearBalanceCust_RunningSuper s ON s.SuperID = p.SuperID
		GROUP BY s.SuperId, s.TotalDownline

		-- TODO: Age_ClearBalanceCust_Process
		INSERT INTO [dbo].[Age_ClearBalanceCust_Process] (
				BatchNo
				,SuperID
				,SessionDate
				,FromCustID
				,ToCustID
				,IsAllDayBalTransfer
				,RoleID
				,[Status]
				,ModifiedTime
				,Creator
			)
			SELECT BatchNo
				,SuperID
				,@SessionDate AS SessionDate
				,FromCustID
				,ToCustID
				,IsAllDayBalTransfer
				,RoleID
				,'New' AS [Status]
				,GETDATE() AS ModifiedTime
				,@Creator AS Creator
			FROM #tmpClearBalanceCust_Process p;

		GOTO OUTPUT_JOB;
	END

	-- TODO: Reset data from current state
	RESUM_JOB:
	BEGIN
		SET @RunningMode = 'Resume';
		-- Update Waiting, Running to New if any
		UPDATE p WITH(ROWLOCK, UPDLOCK)
		SET p.[Status] = 'New', p.ModifiedTime = CURRENT_TIMESTAMP
		FROM dbo.[Age_ClearBalanceCust_Process] p
		WHERE p.SessionDate = @SessionDate
			AND [Status] IN ('Waiting', 'Running')

		-- Update Failed to New if any
		UPDATE p WITH(ROWLOCK, UPDLOCK)
		SET p.[Status] = 'New', p.ModifiedTime = CURRENT_TIMESTAMP
			,p.TryCount = NULL, p.Result = NULL, p.StartTime = NULL, p.EndTime = NULL
		FROM dbo.[Age_ClearBalanceCust_Process] p
			CROSS APPLY (
				SELECT ErrorType
				FROM OPENJSON(p.Result)
				WITH (
					ErrorType VARCHAR(30) '$.ErrType'
				)
			) AS err
		WHERE p.SessionDate = @SessionDate
			AND p.[Status] = 'Failed'
			AND p.TryCount BETWEEN 1 AND 4
			AND err.ErrorType IN ('DBIssue');

		GOTO OUTPUT_JOB;
	END

	
	OUTPUT_JOB:
	SELECT @TotalPair	= COUNT(1)
		,@TotalBatch	= COUNT(DISTINCT BatchNo)
		,@TotalSuper	= COUNT(DISTINCT SuperID)
	FROM [dbo].[Age_ClearBalanceCust_Process] (NOLOCK)
	WHERE [Status] = 'New';
END
GO