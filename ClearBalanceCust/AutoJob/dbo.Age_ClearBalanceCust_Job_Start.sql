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

	DECLARE @SessionDate	SMALLDATETIME;

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
		TRUNCATE TABLE dbo.Age_ClearBalanceCust_RunningSuper;
		TRUNCATE TABLE dbo.Age_ClearBalanceCust_BatchLog;
		TRUNCATE TABLE dbo.Age_ClearBalanceCust_Process;
		
		DECLARE @openExecSQL NVARCHAR(MAX), @Creator INT = 8;

		DROP TABLE IF EXISTS #tmpSMACust;
		CREATE TABLE #tmpSMACust(RoleId INT PRIMARY KEY, FromCustIds VARCHAR(8000));

		DROP TABLE IF EXISTS #tmpCustSetting;
		CREATE TABLE #tmpCustSetting (custid INT PRIMARY KEY, RoleId INT, TransferOption TINYINT, IsAllDayBalTransfer BIT)

		DROP TABLE IF EXISTS #tmpClearBalanceCust
		CREATE TABLE #tmpClearBalanceCust(FromCustId INT, ToCustId INT, RoleId TINYINT, SuperId INT, IsAllDayBalTransfer BIT
			, INDEX CIX_SuperRole CLUSTERED (SuperId, RoleId)
		);

		INSERT INTO #tmpSMACust(RoleId, FromCustIds)
		SELECT t.roleid, STRING_AGG(t.FromCustID, ',') As FromCustIds
		FROM (
			SELECT c.custid AS FromCustID, c.roleid
			FROM dbo.Age_ClearBalanceCust_Setting s WITH(NOLOCK)
			INNER JOIN CUSTDB.dbo.Customer c WITH(NOLOCK) ON c.custid =  s.FromCustId
			WHERE s.EffectiveDate <= @SessionDate
			GROUP BY c.custid, c.roleid
		) AS t
		GROUP BY t.roleid;

		--select * from #tmpSMACust;

		IF EXISTS(SELECT 1 FROM #tmpSMACust WHERE RoleId = 2)
		BEGIN
			SELECT @openExecSQL = N'\
				INSERT INTO #tmpCustSetting (custid, RoleId, TransferOption, IsAllDayBalTransfer)
				SELECT custid, 2, TransferOption, IsAllDayBalTransfer
				FROM OPENQUERY(DBCUST,N''\
				SELECT ca.custid, ca.TransferOption, cm.IsAllDayBalTransfer
				FROM CustDB.dbo.CustAgent ca WITH (NOLOCK)
				INNER JOIN CustDB.dbo.Customer c WITH (NOLOCK) ON c.custid = ca.custid
				INNER JOIN CustDB.dbo.CustMaster cm WITH (NOLOCK) ON cm.custid = c.mrecommend
					CROSS APPLY (
						SELECT strTransferOption = CustDB.dbo.F_Decimal_Binary(ISNULL(ca.TransferOption,0))
					) AS ck
				WHERE ca.custid  IN ('+ t.FromCustIds +') \
					AND 1 = CASE WHEN SUBSTRING(ck.strTransferOption, 8, 1) = 1 
								AND SUBSTRING(ck.strTransferOption, DATEPART(WEEKDAY, CURRENT_TIMESTAMP), 1) = 0 THEN 1 
						ELSE 0 END'')'
			FROM #tmpSMACust t
			WHERE t.RoleId = 2;

			EXEC (@openExecSQL);
		END

		IF EXISTS(SELECT 1 FROM #tmpSMACust WHERE RoleId = 3)
		BEGIN
			SELECT @openExecSQL = N'\
				INSERT INTO #tmpCustSetting (custid, RoleId, TransferOption, IsAllDayBalTransfer)
				SELECT custid, 3, TransferOption, IsAllDayBalTransfer
				FROM OPENQUERY(DBCUST,N''\
				SELECT cm.custid, cm.TransferOption, cm.IsAllDayBalTransfer
				FROM CustDB.dbo.CustMaster cm WITH (NOLOCK)
				CROSS APPLY (
						SELECT strTransferOption = CustDB.dbo.F_Decimal_Binary(ISNULL(cm.TransferOption,0))
					) AS ck
				WHERE cm.custid  IN ('+ t.FromCustIds +') \
					AND 1 = CASE WHEN SUBSTRING(ck.strTransferOption, 8, 1) = 1 
								AND SUBSTRING(ck.strTransferOption, DATEPART(WEEKDAY, CURRENT_TIMESTAMP), 1) = 0 THEN 1 
						ELSE 0 END'')'
			FROM #tmpSMACust t
			WHERE t.RoleId = 3;

			EXEC (@openExecSQL);
		END

		IF EXISTS(SELECT 1 FROM #tmpSMACust WHERE RoleId = 4)
		BEGIN
			SELECT @openExecSQL = N'\
				INSERT INTO #tmpCustSetting (custid, RoleId, TransferOption, IsAllDayBalTransfer)
				SELECT custid, 4, TransferOption, IsAllDayBalTransfer
				FROM OPENQUERY(DBCUST,N''\
				SELECT cs.custid, cs.TransferOption, cs.IsAllDayBalTransfer
				FROM CustDB.dbo.CustSuper cs WITH (NOLOCK)
					CROSS APPLY (
						SELECT strTransferOption = CustDB.dbo.F_Decimal_Binary(ISNULL(cs.TransferOption,0))
					) AS ck
				WHERE cs.custid  IN ('+ t.FromCustIds +')'')'
			FROM #tmpSMACust t
			WHERE t.RoleId = 4;

			EXEC (@openExecSQL);
		END

		--select * from #tmpCustSetting;

		IF NOT EXISTS (SELECT 1 FROM #tmpCustSetting)
			GOTO OUTPUT_JOB;

		WITH CTE_ClearBalanceCust AS (
			SELECT s.FromCustId, s.ToCustId, c.RoleId, c.srecommend AS SuperId, ISNULL(sma.IsAllDayBalTransfer, 0) AS IsAllDayBalTransfer
			FROM dbo.Age_ClearBalanceCust_Setting s WITH(NOLOCK)
				INNER JOIN CUSTDB.dbo.Customer c WITH(NOLOCK) ON c.custid = s.ToCustId AND c.recommend = s.FromCustId AND c.RoleId = 1
				INNER JOIN #tmpCustSetting sma ON sma.custid = s.FromCustID
			WHERE sma.RoleId = 2
				AND s.EffectiveDate <= @SessionDate

			UNION ALL
			SELECT s.FromCustId, s.ToCustId, c.RoleId, c.srecommend, ISNULL(sma.IsAllDayBalTransfer, 0)
			FROM dbo.Age_ClearBalanceCust_Setting s WITH(NOLOCK)
				INNER JOIN CUSTDB.dbo.Customer c WITH(NOLOCK) ON c.custid = s.ToCustId AND c.mrecommend = s.FromCustId AND c.RoleId = 2
				INNER JOIN #tmpCustSetting sma ON sma.custid = s.FromCustID
			WHERE sma.RoleId = 3
				AND s.EffectiveDate <= @SessionDate

			UNION ALL
			SELECT s.FromCustId, s.ToCustId, c.RoleId, c.srecommend, ISNULL(sma.IsAllDayBalTransfer, 0)
			FROM dbo.Age_ClearBalanceCust_Setting s WITH(NOLOCK)
				INNER JOIN CUSTDB.dbo.Customer c WITH(NOLOCK) ON c.custid = s.ToCustId AND c.srecommend = s.FromCustId AND c.RoleId = 3
				INNER JOIN #tmpCustSetting sma ON sma.custid = s.FromCustID
			WHERE sma.RoleId = 4
				AND s.EffectiveDate <= @SessionDate
		)
		INSERT INTO #tmpClearBalanceCust
		SELECT FromCustId, ToCustId, RoleId, SuperId, IsAllDayBalTransfer
		FROM CTE_ClearBalanceCust
		

		DROP TABLE IF EXISTS #tmpClearBalanceCust_RunningSuper;
		DROP TABLE IF EXISTS #tmpClearBalanceCust_Process;
		
		CREATE TABLE #tmpClearBalanceCust_RunningSuper(SuperId INT PRIMARY KEY, TotalDownline INT)
		CREATE TABLE #tmpClearBalanceCust_Process(
			SuperId INT, FromCustId INT, ToCustId INT, RoleID TINYINT, IsAllDayBalTransfer BIT, BatchNo INT
			,INDEX CIX_SuperBatch CLUSTERED (SuperId, BatchNo)
		);


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
		SET @RunningMode = 'Resum';
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
					ErrorType VARCHAR(30) '$.ErrorType'
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