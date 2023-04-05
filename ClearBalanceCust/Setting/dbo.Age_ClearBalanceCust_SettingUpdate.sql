/*<info serverAlias="DBTXN-bodb02" executers="bodbDownlineNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE  [dbo].[Age_ClearBalanceCust_SettingUpdate]
	@FromCustId		INT,
	@ToCustId		INT,
	@IsAllowAutoTransfer BIT,
	@Creator		INT,
	@Language		VARCHAR(2)= 'E',
	@IP				VARCHAR(45)='',
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
		• @FromCustID: The direct UplineID
		• @ToCustIDs: The list CustID(s) being to add auto config

*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @today DATE, @tomorrow DATE, @RoleID TINYINT, @batchCount INT, @pairCount INT, @IsAllowAutoTransfer_Old BIT;

	-- Logging
	DECLARE @LogSPData	VARCHAR(8000),
		@TrackingValue2 VARCHAR(8000),
		@StartTime		DATETIME,
		@duration		INT,
		@LogActionID	INT = 95086,
		@AfftectedRows	INT,
		@RunSPNameLog	VARCHAR(100);

	SELECT @today	= GETDATE()
		,@tomorrow	= DATEADD(DAY, 1, @today)
		,@StartTime = CURRENT_TIMESTAMP
		,@IsAllowAutoTransfer_Old = IIF(@IsAllowAutoTransfer = 0, 1, 0)
		,@RunSPNameLog = '<Age_ClearBalanceCust_SettingUpdate';

	DROP TABLE IF EXISTS #tmpClearBalanceCust;
	CREATE TABLE #tmpClearBalanceCust (FromCustID INT, ToCustID INT, CreatedDate DATETIME, EffectedDate DATE, 
		CONSTRAINT  PK_CustPair_Del PRIMARY KEY (FromCustID, ToCustID) 
	);

	SELECT @RoleID = (SELECT TOP 1 RoleID FROM CustDB.dbo.customer WITH (NOLOCK) WHERE custid = @FromCustID);

	IF @RoleID IS NULL 
	BEGIN  
		SELECT @ErrCode	= 102, 
			@ErrMsg		= CASE WHEN @Language = 'E' THEN 'Customer does not exist.'  
								ELSE [dbo].[f_Get_MsgNamebyMsgID](40014,@Language)
								END    
		GOTO SP_END;  
	END  

	INSERT INTO #tmpClearBalanceCust (FromCustID, ToCustID)
	SELECT @FromCustID AS FromCustID, @ToCustId AS ToCustID

	SET @batchCount = @@ROWCOUNT;

	SELECT @pairCount = (
		SELECT COUNT(1) AS PairCount
			FROM CustDB.dbo.customer c WITH (NOLOCK) 
			INNER JOIN #tmpClearBalanceCust cbs ON cbs.ToCustID = c.custid
		WHERE 1 = CASE 
				WHEN @RoleID = 2 AND c.recommend = @FromCustID THEN 1
				WHEN @RoleID = 3 AND c.mrecommend = @FromCustID THEN 1
				WHEN @RoleID = 4 AND c.srecommend = @FromCustID THEN 1
				ELSE 0
			END
	);

	IF @batchCount <> @pairCount
	BEGIN  
		SELECT @ErrCode	= 103, 
				@ErrMsg	= CASE WHEN @Language = 'E' THEN 'Downline does not match.'  
								ELSE [dbo].[f_Get_MsgNamebyMsgID](40014,@Language)
							END    
		GOTO SP_END;
	END

	--- CHECK for turn OFF AutoTransfer
	IF @IsAllowAutoTransfer = 0
		AND EXISTS (
			SELECT TOP 1 1 AS HasRunning
			FROM dbo.Age_ClearBalanceCust_Process WITH(NOLOCK)
			WHERE SessionDate = @today
				AND FromCustId = @FromCustID AND ToCustId = @ToCustID
				AND [Status] IN ('New', 'Waiting', 'Running')
				OR ([Status] = 'Failed' AND TryCount BETWEEN 1 AND 4)
		)
	BEGIN
		SELECT @ErrCode	= 104, 
				@ErrMsg	= CASE WHEN @Language = 'E' THEN 'You cannot turn off Auto Transfer for this account because the Auto Transfer process is running. Please try again after the process is complete..'  
								ELSE [dbo].[f_Get_MsgNamebyMsgID](500019,@Language)
							END    
		GOTO SP_END;
	END

	--TODO: ON/OFF auto transfer setting
	DECLARE @tmpResult TABLE (CustId INT, [EffectiveDate] DATE);

	BEGIN TRY
		IF @IsAllowAutoTransfer = 1
		BEGIN
			WITH CTE_Insert AS (
				SELECT ins.ToCustID 
				FROM #tmpClearBalanceCust ins
				LEFT JOIN [dbo].[Age_ClearBalanceCust_Setting] s (NOLOCK) 
					ON s.FromCustID = ins.FromCustID 
					AND s.ToCustID = ins.ToCustID
				WHERE s.ToCustID IS NULL
			)
			INSERT INTO [dbo].[Age_ClearBalanceCust_Setting]
				   ([FromCustID]
				   ,[ToCustID]
				   ,[CreatedDate]
				   ,[EffectiveDate]
				   ,[Creator])
			OUTPUT INSERTED.ToCustID,INSERTED.[EffectiveDate]
			INTO @tmpResult (CustId,[EffectiveDate])
			SELECT ins.FromCustID, cte.ToCustID
				, GETDATE() AS [CreatedDate]
				, CASE WHEN ck.HasRunning > 0 THEN @tomorrow ELSE @today END [EffectiveDate]
				, @Creator AS [Creator]
			FROM #tmpClearBalanceCust ins
			INNER JOIN CTE_Insert cte ON cte.ToCustID = ins.ToCustID
			OUTER APPLY (
				SELECT TOP 1 1 AS HasRunning
				FROM dbo.Age_ClearBalanceCust_Process p WITH(NOLOCK)
				WHERE SessionDate = @today
					AND [Status] IN ('New', 'Waiting', 'Running')
					OR ([Status] = 'Failed' AND TryCount BETWEEN 1 AND 4)
			) AS ck;

			SET @AfftectedRows = @@ROWCOUNT;

			IF EXISTS (SELECT 1 FROM @tmpResult WHERE EffectiveDate > @today)
			BEGIN
				SELECT @ErrCode	= 0, 
						@ErrMsg	= CASE WHEN @Language = 'E' THEN 'The Auto Transfer is running now. This account will be auto transferred at the next schedule of your transfer condition.'  
										ELSE [dbo].[f_Get_MsgNamebyMsgID](500020,@Language)
									END    
			END
		END
		ELSE
		BEGIN
			WITH CTE_Remove AS (
				SELECT del.FromCustID, del.ToCustID 
				FROM #tmpClearBalanceCust del
				INNER JOIN [dbo].[Age_ClearBalanceCust_Setting] s (NOLOCK)
					ON s.FromCustID = del.FromCustID 
					AND s.ToCustID = del.ToCustID
			)
			DELETE d WITH(ROWLOCK)
			OUTPUT DELETED.ToCustId
			INTO @tmpResult(CustId)
			FROM [dbo].[Age_ClearBalanceCust_Setting] d
			INNER JOIN CTE_Remove cte ON cte.FromCustID = d.FromCustID AND cte.ToCustID = d.ToCustID;
		
			SET @AfftectedRows = @@ROWCOUNT;
		END

		IF @AfftectedRows = 0
			RETURN;
	END TRY
	BEGIN CATCH
		SELECT @ErrCode	= 104, 
				@ErrMsg	= ERROR_MESSAGE() 
	END CATCH

	SP_END:
	SET @duration  = DATEDIFF(MILLISECOND, @StartTime, CURRENT_TIMESTAMP);
	-- TODO: Write log runSP
	BEGIN TRY
		SELECT @LogSPData = CAST(
				(SELECT @FromCustID AS '@FromCustId', @ToCustId AS '@ToCustId', @IsAllowAutoTransfer AS '@IsAllowAutoTransfer',
					ISNULL(@IP, SPACE(1)) AS '@IP', @Language AS '@Language', @Creator AS '@Creator',
					@ErrCode AS '@ErrCode', @ErrMsg AS '@ErrMsg'
				FOR XML PATH('SP_TEMPLATE')) AS VARCHAR(8000)
			)
			,@TrackingValue2 = CAST(
				(SELECT @FromCustID AS '@FromCustId', @ToCustId AS '@ToCustId', @IsAllowAutoTransfer_Old AS '@IsAllowAutoTransfer'
				FOR XML PATH('SP_TEMPLATE')) AS VARCHAR(8000)
			);

		SELECT @LogSPData		= REPLACE(@LogSPData, '<SP_TEMPLATE', @RunSPNameLog),
				@TrackingValue2 = REPLACE(@TrackingValue2, '<SP_TEMPLATE', @RunSPNameLog);

		EXEC DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_RunSP 
			@UserID = @Creator,
			@CustID = @ToCustID,
			@ActionID = @LogActionID,
			@TrackingValue = @LogSPData,
			@TrackingValue2 = @TrackingValue2,
			@duration = @duration
	END TRY
	BEGIN CATCH
		SELECT @ErrMsg  = CONCAT(@ErrMsg, ERROR_NUMBER(),': ',ERROR_MESSAGE());
		SELECT @LogSPData = CAST(
				(SELECT @FromCustID AS '@FromCustId', @ToCustId AS '@ToCustId', @IsAllowAutoTransfer AS '@IsAllowAutoTransfer',
					ISNULL(@IP, SPACE(1)) AS '@IP', @Language AS '@Language', @Creator AS '@Creator',
					@ErrCode AS '@ErrCode', @ErrMsg AS '@ErrMsg'
				FOR XML PATH('SP_TEMPLATE')) AS VARCHAR(8000)
			),
			@TrackingValue2 = CAST(
				(SELECT @FromCustID AS '@FromCustId', @ToCustId AS '@ToCustId', @IsAllowAutoTransfer_Old AS '@IsAllowAutoTransfer'
				FOR XML PATH('SP_TEMPLATE')) AS VARCHAR(8000)
			);
		
		SELECT @LogSPData		= REPLACE(@LogSPData, '<SP_TEMPLATE', @RunSPNameLog),
				@TrackingValue2 = REPLACE(@TrackingValue2, '<SP_TEMPLATE', @RunSPNameLog);

		EXEC bodb_CustomerLog.dbo.WriteLog_UserLog_RunSP 
			@UserID = @Creator,
			@CustID = @ToCustID,
			@ActionID = @LogActionID,
			@TrackingValue = @LogSPData,
			@TrackingValue2 = @TrackingValue2,
			@duration = @duration

	END CATCH
END
GO