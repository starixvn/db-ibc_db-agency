/*<info serverAlias="DBTXN-bodb02" executers="bodbDownlineNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE  [dbo].[Age_ClearBalanceCust_Job_Start]
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
	DB: DBTXN/bodb02

	Revisions:
		- 20230227@Bobby: AutoJob clear balance downlines [RedmineID: #182071]

	Param's Explanation:
		• @PairOfBatch: The number pairs of batch

*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @SessionDate	SMALLDATETIME,
		@Creator			INT, --StarixIT
		@AutoJob_ClearBalance_VName		VARCHAR(50)  = 'AutoJob_ClearBalance_Runtime',
		@AutoTransfer_StartTime			DATETIME,
		@AutoJob_ClearBalance_VValue	VARCHAR(200),
		@AutoTransfer_StartTime_Check	DATETIME,
		@AutoTransfer_RunningModeCheck	VARCHAR(15),
		@SiteDBGroupID					SMALLINT,
		@commandExec					NVARCHAR(MAX)
	;

	SELECT @AutoTransfer_StartTime = CURRENT_TIMESTAMP,
			@SessionDate			= CAST(@AutoTransfer_StartTime AS DATE),
			@PairOfBatch			= ISNULL(@PairOfBatch, 200),
			@TotalPair				= 0,
			@TotalBatch				= 0,
			@TotalSuper				= 0,
			@ErrCode				= 0,
			@ErrMsg					= ''
	;

	SELECT @Creator = custid
	FROM CustDB.dbo.custInfo WITH(NOLOCK) 
	WHERE username = 'StarixIT'
	;

	--TODO: Check setting
	SELECT @AutoJob_ClearBalance_VValue = VValue
	FROM SystemSettings (NOLOCK)
	WHERE VName = @AutoJob_ClearBalance_VName
	;

	SELECT @AutoTransfer_StartTime_Check	= CAST(JSON_VALUE(@AutoJob_ClearBalance_VValue, '$.StartTime') AS DATETIME),
		@AutoTransfer_RunningModeCheck		= JSON_VALUE(@AutoJob_ClearBalance_VValue, '$.RunningMode')

	-- TODO: INIT data from current setting
	IF @RunningMode IN ('Normal', 'Resume')
		AND NOT EXISTS (SELECT 1 FROM dbo.[Age_ClearBalanceCust_Process] WITH(NOLOCK) WHERE SessionDate = @SessionDate)
	BEGIN
		SELECT @SiteDBGroupID	= [dbo].[f_Get_SiteDBGroupID]();

		BEGIN TRY
			--TODO: CLEANUP data
			DELETE dbo.Age_ClearBalanceCust_RunningSuper;
			DELETE dbo.Age_ClearBalanceCust_BatchLog;
			DELETE dbo.Age_ClearBalanceCust_Process;
		
			DROP TABLE IF EXISTS #tmpClearBalanceCust
			CREATE TABLE #tmpClearBalanceCust(FromCustId INT, ToCustId INT PRIMARY KEY NONCLUSTERED, RoleId TINYINT, SuperId INT, IsAllDayBalTransfer BIT
				, INDEX CIX_SuperRole CLUSTERED (SuperId, RoleId)
			);

			--TODO: get Snapshot from DBCUST
			SET @commandExec  = N'INSERT INTO #tmpClearBalanceCust (FromCustId, ToCustId, RoleId, SuperId, IsAllDayBalTransfer)
				SELECT FromCustId, ToCustId, RoleId, SuperId, IsAllDayBalTransfer
				FROM OPENQUERY(DBCUST, ''SELECT FromCustId, ToCustId, RoleId, SuperId, IsAllDayBalTransfer FROM CustDB.dbo.f_Age_ClearBalanceCust_Snapshot('+ CAST(@SiteDBGroupID AS VARCHAR(10))+')'');'
			;
			EXEC sys.sp_executesql @commandExec;

			IF NOT EXISTS (SELECT TOP 1 1 FROM #tmpClearBalanceCust)
			BEGIN
				SELECT @ErrCode = 101
					,@ErrMsg	= 'There is no data to process.'
				RETURN;
			END

			--TODO: Process batching
			DROP TABLE IF EXISTS #tmpClearBalanceCust_RunningSuper;
			DROP TABLE IF EXISTS #tmpClearBalanceCust_Process;
		
			CREATE TABLE #tmpClearBalanceCust_RunningSuper(SuperId INT PRIMARY KEY, TotalDownline INT)
			CREATE TABLE #tmpClearBalanceCust_Process(
				SuperId INT, FromCustId INT, ToCustId INT PRIMARY KEY NONCLUSTERED, RoleID TINYINT, IsAllDayBalTransfer BIT, BatchNo INT
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

				--TODO: Update Setting
				SELECT @AutoJob_ClearBalance_VValue = (SELECT @AutoTransfer_StartTime AS StartTime, @RunningMode AS RunningMode FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
				IF EXISTS (SELECT 1 FROM dbo.SystemSettings WITH(NOLOCK) WHERE VName = @AutoJob_ClearBalance_VName)
				BEGIN
					UPDATE dbo.SystemSettings WITH(ROWLOCK, UPDLOCK)
					SET VValue = @AutoJob_ClearBalance_VValue
					WHERE VName = @AutoJob_ClearBalance_VName
				END
				ELSE
				BEGIN
					INSERT INTO dbo.SystemSettings(VName, VValue)
					VALUES (@AutoJob_ClearBalance_VName, @AutoJob_ClearBalance_VValue)
				END

				-- SET output
				SELECT @TotalPair	= COUNT(1)
					,@TotalBatch	= COUNT(DISTINCT BatchNo)
					,@TotalSuper	= COUNT(DISTINCT SuperID)
				FROM [dbo].[Age_ClearBalanceCust_Process] (NOLOCK)
				WHERE [Status] = 'New';
		END TRY
		BEGIN CATCH 
			SELECT @ErrCode = 102
				,@ErrMsg	= ERROR_MESSAGE()
		END CATCH
	END
	ELSE IF @RunningMode = 'Normal'
		AND EXISTS (SELECT 1 FROM dbo.[Age_ClearBalanceCust_Process] WITH(NOLOCK) WHERE SessionDate = @SessionDate)
	BEGIN
		-- TODO: Scaleout Threads -- parallisym threads at the same time
		SET @RunningMode = 'Scaleout';
		-- SET output
		SELECT @TotalPair	= COUNT(1)
			,@TotalBatch	= COUNT(DISTINCT BatchNo)
			,@TotalSuper	= COUNT(DISTINCT SuperID)
		FROM [dbo].[Age_ClearBalanceCust_Process] (NOLOCK)
		WHERE [Status] = 'New';
	END
	ELSE IF @RunningMode = 'Resume'
		AND EXISTS (SELECT 1 FROM dbo.[Age_ClearBalanceCust_Process] WITH(NOLOCK) WHERE SessionDate = @SessionDate)
	BEGIN
		BEGIN TRY
			-- Update Waiting, Processing to New if any
			UPDATE p WITH(ROWLOCK, UPDLOCK)
			SET p.[Status] = 'New', p.ModifiedTime = CURRENT_TIMESTAMP, p.Amount = NULL
				,p.TryCount = NULL, p.Result = NULL, p.StartTime = NULL, p.EndTime = NULL
			FROM dbo.[Age_ClearBalanceCust_Process] p
			WHERE p.SessionDate = @SessionDate
				AND [Status] IN ('Waiting', 'Processing')

			-- Update Failed, Pending to New if any
			UPDATE p WITH(ROWLOCK, UPDLOCK)
			SET p.[Status] = 'New', p.ModifiedTime = CURRENT_TIMESTAMP, p.Amount = NULL
				,p.TryCount = NULL, p.Result = NULL, p.StartTime = NULL, p.EndTime = NULL
			FROM dbo.[Age_ClearBalanceCust_Process] p
				INNER JOIN dbo.f_Age_ClearBalanceCust_ErrorSel() err ON err.ErrType = JSON_VALUE(p.Result, '$.ErrType')
			WHERE p.SessionDate = @SessionDate
				AND p.[Status] IN ('Failed', 'Pending')
				AND err.AllowReTry = 1
				AND 1 = CASE 
							WHEN err.ErrType = 'TransferUM' AND p.TryCount BETWEEN 1 AND 59 THEN 1 
							WHEN p.TryCount BETWEEN 1 AND 4 THEN 1 
						ELSE 0 END
			;


			--TODO: Update Setting
			SELECT @AutoJob_ClearBalance_VValue = (SELECT @AutoTransfer_StartTime AS StartTime, @RunningMode AS RunningMode FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
			IF EXISTS (SELECT 1 FROM dbo.SystemSettings WITH(NOLOCK) WHERE VName = @AutoJob_ClearBalance_VName)
			BEGIN
				UPDATE dbo.SystemSettings WITH(ROWLOCK, UPDLOCK)
				SET VValue = @AutoJob_ClearBalance_VValue
				WHERE VName = @AutoJob_ClearBalance_VName
			END
			ELSE
			BEGIN
				INSERT INTO dbo.SystemSettings(VName, VValue)
				SELECT @AutoJob_ClearBalance_VName AS VName,@AutoJob_ClearBalance_VValue AS VValue
			END

			-- SET output
			SELECT @TotalPair	= COUNT(1)
				,@TotalBatch	= COUNT(DISTINCT BatchNo)
				,@TotalSuper	= COUNT(DISTINCT SuperID)
			FROM [dbo].[Age_ClearBalanceCust_Process] (NOLOCK)
			WHERE [Status] = 'New';
		END TRY
		BEGIN CATCH 
			SELECT @ErrCode = 103
				,@ErrMsg	= ERROR_MESSAGE()
		END CATCH
	END
END
GO