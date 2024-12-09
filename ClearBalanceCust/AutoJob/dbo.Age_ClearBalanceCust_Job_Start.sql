/*<info serverAlias="DBSIC-bodb02,DBCTG-bodb02" executers="wsv_alp" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE  [dbo].[Age_ClearBalanceCust_Job_Start]
	@Environment	VARCHAR(10),
	@RunningMode	VARCHAR(15),
	@PairOfBatch	INT = 200,
	@TotalPair		INT = 0 OUTPUT,
	@TotalBatch		INT = 0 OUTPUT,
	@TotalSuper		INT = 0 OUTPUT,
	@ErrCode		INT = 0 OUTPUT,
	@ErrMsg			NVARCHAR(4000) = '' OUTPUT
AS
/*
	Created:20230227@Bobby
	Task: 182071 - Auto Transfer/ Multiple Transfer	
	DB: DBSIC-bodb02,DBCTG-bodb02

	Revisions:
		- 20230227@Bobby: AutoJob clear balance downlines [RedmineID: #182071]
		- 20231027@Bobby: AutoJob transfer - Environment testing [RedmineID: #195135]
		- 20241206@Helen: Alpha - Offer Direct Member for Super/Master [Redmine: #211969]

	Param's Explanation:
		• @PairOfBatch: The number pairs of batch

*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @SessionDate			SMALLDATETIME,
		@Creator					INT, --StarixIT
		@AutoJob_VName_ConfigUAT	VARCHAR(50),
		@AutoJob_VValue_ConfigUAT	VARCHAR(200),
		@AutoTransfer_StartTime		DATETIME,
		@SiteDBGroupID				SMALLINT,
		@commandExec				NVARCHAR(MAX),
		@TestSuperIds				VARCHAR(200)
	;

	SELECT @AutoTransfer_StartTime = CURRENT_TIMESTAMP,
			@SessionDate			= CAST(@AutoTransfer_StartTime AS DATE),
			@PairOfBatch			= ISNULL(@PairOfBatch, 200),
			@TotalPair				= 0,
			@TotalBatch				= 0,
			@TotalSuper				= 0,
			@ErrCode				= 0,
			@ErrMsg					= '',
			@AutoJob_VName_ConfigUAT	= 'AutoJob_ClearBalance_ConfigUAT'
	;

	SELECT @Creator = custid
	FROM CustDB.dbo.custInfo WITH(NOLOCK) 
	WHERE username = 'StarixIT'
	;

	SELECT @AutoJob_VValue_ConfigUAT = VValue
	FROM dbo.SystemSettings (NOLOCK)
	WHERE VName = @AutoJob_VName_ConfigUAT
	;

	-- TODO: INIT data from current setting
	IF @RunningMode IN ('Normal', 'Resume')
		AND NOT EXISTS (SELECT 1 FROM dbo.[Age_ClearBalanceCust_Process] WITH(NOLOCK) WHERE SessionDate = @SessionDate AND Environment = @Environment)
	BEGIN
		SELECT @SiteDBGroupID	= [dbo].[f_Get_SiteDBGroupID]()
			,@TestSuperIds		= ISNULL(JSON_VALUE(@AutoJob_VValue_ConfigUAT, '$.sids'), '')
		;

		BEGIN TRY
			--TODO: CLEANUP data
			DELETE dbo.Age_ClearBalanceCust_RunningSuper WHERE Environment = @Environment;
			DELETE dbo.Age_ClearBalanceCust_BatchLog WHERE Environment = @Environment;
			DELETE dbo.Age_ClearBalanceCust_Process WHERE Environment = @Environment;
		
			DROP TABLE IF EXISTS #tmpClearBalanceCust
			CREATE TABLE #tmpClearBalanceCust(FromCustId INT, ToCustId INT PRIMARY KEY NONCLUSTERED, RoleId TINYINT, SuperId INT, IsAllDayBalTransfer BIT
				, DirectMember INT DEFAULT (0)
				, INDEX CIX_SuperRole CLUSTERED (SuperId, RoleId)
			);

			--TODO: get Snapshot from DBCUST
			SET @commandExec  = N'INSERT INTO #tmpClearBalanceCust (FromCustId, ToCustId, RoleId, SuperId, IsAllDayBalTransfer)
				SELECT FromCustId, ToCustId, RoleId, SuperId, IsAllDayBalTransfer
				FROM OPENQUERY(DBCUST, ''SELECT FromCustId, ToCustId, RoleId, SuperId, IsAllDayBalTransfer FROM CustDB.dbo.f_Age_ClearBalanceCust_Snapshot('+ CAST(@SiteDBGroupID AS VARCHAR(10))+','''''+@TestSuperIds+''''','''''+ @Environment +''''')'');'
			;
			EXEC sys.sp_executesql @commandExec;

			IF NOT EXISTS (SELECT TOP 1 1 FROM #tmpClearBalanceCust)
			BEGIN
				SELECT @ErrCode = 101
					,@ErrMsg	= 'There is no data to process.'

				--TODO: Update StartTime & CompletedTime
				EXEC [dbo].[Age_ClearBalanceCust_Job_RuntimeUpd]
					@Environment = @Environment,
					@StartTime = @AutoTransfer_StartTime,
					@RunningMode = @RunningMode,
					@IsCompleted = 1
				RETURN;
			END

			UPDATE t
				SET DirectMember = ci.recommend
			FROM #tmpClearBalanceCust t
				INNER JOIN CUSTDB.dbo.Custinfo ci WITH (NOLOCK) ON t.ToCustId = ci.custid
			WHERE ci.recommend IN (-3,-4) AND t.RoleId IN (3,4) AND ci.roleid = 1

			--TODO: Process batching
			DROP TABLE IF EXISTS #tmpClearBalanceCust_RunningSuper;
			DROP TABLE IF EXISTS #tmpClearBalanceCust_Process;
		
			CREATE TABLE #tmpClearBalanceCust_RunningSuper(SuperId INT PRIMARY KEY, TotalDownline INT)
			CREATE TABLE #tmpClearBalanceCust_Process(
				SuperId INT, FromCustId INT, ToCustId INT PRIMARY KEY NONCLUSTERED, RoleID TINYINT, IsAllDayBalTransfer BIT, BatchNo INT
				, DirectMember INT
				,INDEX CIX_SuperBatch CLUSTERED (SuperId, BatchNo)
			);

			--TODO: Super order by TotalDownline
			INSERT INTO #tmpClearBalanceCust_RunningSuper
			SELECT SuperID, COUNT(1) AS TotalDownline
			FROM #tmpClearBalanceCust
			GROUP BY SuperID;

			-- TODO: Batching by Super
			INSERT INTO #tmpClearBalanceCust_Process (SuperID, FromCustId, ToCustId, RoleID, IsAllDayBalTransfer, BatchNo,DirectMember)
			SELECT SuperID, FromCustId, ToCustId, RoleID, IsAllDayBalTransfer, t.DirectMember
				,SUM(CASE WHEN t.superIdx%@PairOfBatch = 1 THEN 1 ELSE 0 END) OVER (ORDER BY t.rIdx) AS BatchNo
			FROM(
				SELECT rc.SuperID, rc.FromCustId, rc.ToCustId, rc.RoleID, rc.IsAllDayBalTransfer, rc.DirectMember
					,ROW_NUMBER() OVER (ORDER BY rs.TotalDownline DESC, rs.SuperID, IIF(rc.DirectMember < 0, rc.DirectMember, rc.RoleID), rc.FromCustId, rc.ToCustId) AS rIdx
					,ROW_NUMBER() OVER (
						PARTITION BY rs.TotalDownline, rs.SuperID, IIF(rc.DirectMember < 0, rc.DirectMember, rc.RoleID), rc.FromCustId 
						ORDER BY rs.TotalDownline DESC, rs.SuperID, IIF(rc.DirectMember < 0, rc.DirectMember, rc.RoleID), rc.FromCustId
					) AS superIdx
				FROM #tmpClearBalanceCust rc
				INNER JOIN #tmpClearBalanceCust_RunningSuper rs ON rs.SuperID = rc.SuperID
			) AS t

			-- TODO: Age_ClearBalanceCust_RunningSuper
			INSERT INTO dbo.Age_ClearBalanceCust_RunningSuper(SuperId, TotalBatch, RunningTotal, RunningBatchNo, TotalDownline, Environment)
			SELECT s.SuperId
				,COUNT(DISTINCT p.BatchNo) AS TotalBatch
				,0 AS RunningTotal
				,0 AS RunningBatchNo
				,s.TotalDownline
				,@Environment AS Environment
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
					,Environment
					,DirectMember
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
				,@Environment AS Environment
				,DirectMember
			FROM #tmpClearBalanceCust_Process p;

			-- SET output
			SELECT @TotalPair	= COUNT(1)
				,@TotalBatch	= COUNT(DISTINCT BatchNo)
				,@TotalSuper	= COUNT(DISTINCT SuperID)
			FROM [dbo].[Age_ClearBalanceCust_Process] (NOLOCK)
			WHERE [Status] = 'New' AND Environment = @Environment;

			--TODO: Update StartTime & CompletedTime
			EXEC [dbo].[Age_ClearBalanceCust_Job_RuntimeUpd]
				@Environment = @Environment,
				@StartTime = @AutoTransfer_StartTime,
				@RunningMode = @RunningMode,
				@IsCompleted = 0
		END TRY
		BEGIN CATCH 
			SELECT @ErrCode = 102
				,@ErrMsg	= ERROR_MESSAGE()
		END CATCH
	END
	ELSE IF @RunningMode = 'Normal'
		AND EXISTS (SELECT 1 FROM dbo.[Age_ClearBalanceCust_Process] WITH(NOLOCK) WHERE SessionDate = @SessionDate AND Environment = @Environment)
	BEGIN
		-- TODO: Scaleout Threads -- parallisym threads at the same time
		SET @RunningMode = 'Scaleout';
		-- SET output
		SELECT @TotalPair	= COUNT(1)
			,@TotalBatch	= COUNT(DISTINCT BatchNo)
			,@TotalSuper	= COUNT(DISTINCT SuperID)
		FROM [dbo].[Age_ClearBalanceCust_Process] (NOLOCK)
		WHERE [Status] = 'New' AND Environment = @Environment;
	END
	ELSE IF @RunningMode = 'Resume'
		AND EXISTS (SELECT 1 FROM dbo.[Age_ClearBalanceCust_Process] WITH(NOLOCK) WHERE SessionDate = @SessionDate AND Environment = @Environment)
	BEGIN
		BEGIN TRY
			-- Update Waiting, Processing to New if any
			UPDATE p WITH(ROWLOCK, UPDLOCK)
			SET p.[Status] = 'New', p.ModifiedTime = CURRENT_TIMESTAMP, p.Amount = NULL
				,p.TryCount = NULL, p.Result = NULL, p.StartTime = NULL, p.EndTime = NULL
			FROM dbo.[Age_ClearBalanceCust_Process] p
			WHERE p.SessionDate = @SessionDate AND p.Environment = @Environment
				AND [Status] IN ('Waiting', 'Processing')
				AND p.TryCount IS NULL -- NOT touch on ReTry thread

			-- TODO: Age_ClearBalanceCust_RunningSuper
			UPDATE u WITH(ROWLOCK, UPDLOCK)
			SET u.RunningBatchNo = 0
			FROM dbo.Age_ClearBalanceCust_RunningSuper u
			WHERE Environment = @Environment

			-- SET output
			SELECT @TotalPair	= COUNT(1)
				,@TotalBatch	= COUNT(DISTINCT BatchNo)
				,@TotalSuper	= COUNT(DISTINCT SuperID)
			FROM [dbo].[Age_ClearBalanceCust_Process] (NOLOCK)
			WHERE [Status] = 'New' AND Environment = @Environment;

			--TODO: Update Setting - Resume Mode
			IF (@TotalBatch > 0)
			BEGIN
				EXEC [dbo].[Age_ClearBalanceCust_Job_RuntimeUpd]
					@Environment = @Environment,
					@StartTime = @AutoTransfer_StartTime,
					@RunningMode = @RunningMode,
					@IsCompleted = 0
			END
		END TRY
		BEGIN CATCH 
			SELECT @ErrCode = 103
				,@ErrMsg	= ERROR_MESSAGE()
		END CATCH
	END
END
GO