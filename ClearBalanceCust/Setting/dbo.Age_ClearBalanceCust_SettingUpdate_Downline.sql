/*<info serverAlias="DBCUST-CustDB" executers="bodbDownlineNet,bodbAdminNet,bodbDownlineNetView" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Age_ClearBalanceCust_SettingUpdate_Downline]
	@UplineId		INT,
	@Creator		INT,
	@IsAllDownline	BIT = 0,
	@Language		VARCHAR(2)= 'E',
	@IP				VARCHAR(45)='',
	@TargetIds		VARCHAR(4000) = '' OUTPUT,
	@ErrCode		INT = 0 OUTPUT,
	@ErrMsg			NVARCHAR(4000) = '' OUTPUT

AS
/*
	Created:20230906@Bobby
	Task: 182071 - Auto Transfer/ Multiple Transfer	
	DB: DBCUST-CustDB

	Revisions:
		- 20230906@Bobby: Enhance ADBT config [RedmineID: #193017]

	Param's Explanation:
		• @UplineId: Can be super or master
		• @Creator: Can be admin or super
		• @IsAllDownline: Update all downlines or NOT

*/
BEGIN
	SET NOCOUNT ON;
	DECLARE 
		@srecommend					INT,
		@mrecommend					INT,
		@roleId						TINYINT,
		@IsAllDownline_Check		BIT,
		@rTotal						INT;

	-- Logging
	DECLARE	@IsAllowAutoTransfer BIT, 
		@IsAllowAutoTransfer_Old BIT,
		@StartTime		DATETIME,
		@duration		INT,
		@LogActionID	INT,
		@RunSPNameLog	VARCHAR(100);

	SELECT @ErrCode	= 0
		,@ErrMsg = ''
		,@StartTime = CURRENT_TIMESTAMP
		,@IsAllowAutoTransfer = 0
		,@IsAllowAutoTransfer_Old = 1
		,@RunSPNameLog = 'Age_ClearBalanceCust_SettingUpdate_Downline';

	SELECT @roleId		= RoleId
		,@mrecommend	= mrecommend
		,@srecommend	= srecommend
	FROM dbo.Customer c WITH(NOLOCK)
	WHERE c.CustId = @UplineId

	IF @roleId IS NULL
		RETURN;

	DROP TABLE IF EXISTS #tmpClearBalanceSetting;
	CREATE TABLE #tmpClearBalanceSetting (rIdx INT IDENTITY(1,1) PRIMARY KEY, FromCustId INT, ToCustId INT, RoleId INT);

	-- Auto update downline on master levels
	SELECT @IsAllDownline_Check = CASE WHEN @roleId = 3 THEN 1 ELSE @IsAllDownline END

	-- Admin set super and downlines IF ANY
	IF @roleId = 4
	BEGIN
		WITH CTE_Downline AS (
			SELECT s.FromCustID, s.ToCustID, c.RoleId
			FROM dbo.Customer c WITH(NOLOCK)
				INNER JOIN dbo.Age_ClearBalanceCust_Setting s WITH(NOLOCK)
				ON s.FromCustID = c.custid
			WHERE c.custid = @srecommend  -- super level
				AND c.roleid IN (4)
			UNION ALL
			SELECT s.FromCustID, s.ToCustID, c.RoleId
			FROM dbo.Customer c WITH(NOLOCK)
				INNER JOIN dbo.Age_ClearBalanceCust_Setting s WITH(NOLOCK)
				ON s.FromCustID = c.custid
			WHERE @IsAllDownline_Check = 1
				AND c.srecommend = @srecommend 
				AND c.roleid IN (2, 3) -- all downlines
		)
		INSERT INTO #tmpClearBalanceSetting (FromCustID, ToCustID, RoleId)
		SELECT DISTINCT FromCustID, ToCustID, RoleId
		FROM CTE_Downline;

		SET @rTotal = @@ROWCOUNT;
	END

	-- Admin/Super set on master
	IF @roleId = 3
	BEGIN
		WITH CTE_Downline AS (
			SELECT s.FromCustID, s.ToCustID, c.RoleId
			FROM dbo.Customer c WITH(NOLOCK)
				INNER JOIN dbo.Age_ClearBalanceCust_Setting s WITH(NOLOCK)
				ON s.FromCustID = c.custid
			WHERE c.custid = @mrecommend  -- master level
				AND c.roleid IN (3)
			UNION ALL
			SELECT s.FromCustID, s.ToCustID, c.RoleId
			FROM dbo.Customer c WITH(NOLOCK)
				INNER JOIN dbo.Age_ClearBalanceCust_Setting s WITH(NOLOCK)
				ON s.FromCustID = c.custid
			WHERE @IsAllDownline_Check = 1
				AND c.mrecommend = @mrecommend 
				AND c.roleid IN (2) -- all downlines
		)
		INSERT INTO #tmpClearBalanceSetting (FromCustID, ToCustID, RoleId)
		SELECT DISTINCT FromCustID, ToCustID, RoleId
		FROM CTE_Downline;

		SET @rTotal = @@ROWCOUNT;
	END

	IF @rTotal = 0
		RETURN

	-- TODO: Set TargetIds
	SET @TargetIds = '';
	SELECT @TargetIds = STRING_AGG(FromCustId ,',')
	FROM (
		SELECT DISTINCT FromCustId 
		FROM #tmpClearBalanceSetting
	) AS t

	-- TODO: Update Setting
	DECLARE @rBatch INT = 50, @logData NVARCHAR(4000);

	DECLARE @tmpBatch TABLE (FromCustId INT, ToCustId INT, RoleId INT);

	WHILE EXISTS(SELECT 1 FROM #tmpClearBalanceSetting)
	BEGIN
		SELECT @ErrCode = 0, @ErrMsg = '', @StartTime = CURRENT_TIMESTAMP;
		DELETE @tmpBatch;

		DELETE TOP(@rBatch) tmp
		OUTPUT DELETED.FromCustId, DELETED.ToCustId, DELETED.RoleId
		INTO @tmpBatch(FromCustId, ToCustId, RoleId)
		FROM #tmpClearBalanceSetting tmp
		
		DELETE TOP(@rBatch) s
		FROM dbo.Age_ClearBalanceCust_Setting s WITH(ROWLOCK)
		INNER JOIN @tmpBatch b ON s.FromCustId = b.FromCustId AND s.ToCustId = b.ToCustId

		-- TODO: WRITE Log RunSP
		SET @duration  = DATEDIFF(MILLISECOND, @StartTime, CURRENT_TIMESTAMP);
		
		SELECT @logData = (
			SELECT 
				tb.ToCustId AS '@cid',
				CASE 
					WHEN RoleId = 4 THEN 95097 -- view log master
					WHEN RoleId = 3 THEN 95098 -- view log agent
					WHEN RoleId = 2 THEN 95099 -- view log member
					ELSE 0 END AS '@aid'
			FROM @tmpBatch tb
			FOR XML PATH('r')
		);

		BEGIN TRY
			EXEC DBLOG.bodb_CustomerLog.dbo.Age_WriteLog_UserLog_RunSP_Multiple
				@UserID = @Creator,
				@SpName = @RunSPNameLog,
				@LogData = @LogData,
				@Duration = @Duration,
				@Language = @Language,
				@IP = @IP,
				@ErrCode = @ErrCode,
				@ErrMsg = @ErrMsg

		END TRY
		BEGIN CATCH
			SELECT @ErrCode = 101
				, @ErrMsg  = CONCAT(@ErrMsg, ERROR_NUMBER(),': ',ERROR_MESSAGE());

			EXEC bodb_CustomerLog.dbo.Age_WriteLog_UserLog_RunSP_Multiple
				@UserID = @Creator,
				@SpName = @RunSPNameLog,
				@LogData = @LogData,
				@Duration = @Duration,
				@Language = @Language,
				@IP = @IP,
				@ErrCode = @ErrCode,
				@ErrMsg = @ErrMsg

		END CATCH
		-- NEXT batch
	END
END
GO
