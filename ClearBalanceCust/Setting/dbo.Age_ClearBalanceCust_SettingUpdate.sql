/*<info serverAlias="DBCUST-CustDB" executers="bodbDownlineNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Age_ClearBalanceCust_SettingUpdate]
	@FromCustId		INT,
	@ToCustId		INT,
	@IsAllowAutoTransfer	BIT,
	@IsAutoJobRunning		BIT,
	@AutoTransferSchedule	VARCHAR(20),
	@Old_TransferOption		VARCHAR(8)='',
	@Creator		INT,
	@SubAccId		INT,
	@Language		VARCHAR(2)= 'E',
	@IP				VARCHAR(45)='',
	@ErrCode		INT = 0 OUTPUT,
	@ErrMsg			NVARCHAR(4000) = '' OUTPUT

AS
/*
	Created:20230227@Bobby
	Task: 182071 - Auto Transfer/ Multiple Transfer	
	DB: DBCUST-CustDB

	Revisions:
		- 20230227@Bobby: AutoJob clear balance downlines [RedmineID: #182071]
		- 20230822@Bobby: Enhance checking cross level [RedmineID: #193021]
		- 20231009@Bobby: Enhance constraint temp table [RedmineID: #195213]
		- 20231101@Luke: Alpha - Enhance auto transfer function (phase 2) [Redmine: #195135]

	Param's Explanation:
		• @FromCustID: The direct UplineID
		• @ToCustID: The CustID is to add auto transfer

*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @today DATE, @tomorrow DATE, @RoleID TINYINT, @batchCount INT, @pairCount INT, @IsAllowAutoTransfer_Old BIT;

	-- Logging
	DECLARE @LogSPData	NVARCHAR(MAX),
		@TrackingValue2 NVARCHAR(MAX),
		@StartTime		DATETIME,
		@duration		INT,
		@LogActionID	INT = 95086,
		@AfftectedRows	INT,
		@RunSPNameLog	VARCHAR(100);

	SELECT @ErrCode	= 0
		,@ErrMsg = ''
		,@today	= GETDATE()
		,@tomorrow	= DATEADD(DAY, 1, @today)
		,@StartTime = CURRENT_TIMESTAMP
		,@RunSPNameLog = '<Age_ClearBalanceCust_SettingUpdate';

	SELECT @RoleID = (SELECT TOP 1 RoleID FROM CustDB.dbo.customer WITH (NOLOCK) WHERE custid = @FromCustID);	

	IF EXISTS(
		SELECT TOP 1 1
		FROM Age_ClearBalanceCust_Setting WITH (NOLOCK)
		WHERE FromCustID = @FromCustId AND ToCustID = @ToCustId 
	)	
		SET @IsAllowAutoTransfer_Old = 1
	ELSE 
		SET @IsAllowAutoTransfer_Old = 0

	DECLARE	@AutoTransferSchedule_Numeric TINYINT,
			@Old_AutoTransferSchedule_Numeric TINYINT

	SELECT @AutoTransferSchedule_Numeric = dbo.f_AutoTransferSchedule_CharToNumeric(@AutoTransferSchedule)
	SELECT @Old_AutoTransferSchedule_Numeric = ScheduleOption 
		FROM dbo.Age_ClearBalanceCust_Setting WITH (NOLOCK)
		WHERE FromCustID = @FromCustId AND ToCustID = @ToCustId
 
	--Update auto transfer schedule
	IF @IsAllowAutoTransfer = 1 AND @IsAllowAutoTransfer_Old = 1
	BEGIN
		EXEC dbo.Age_AutoTransferSchedule_Upd
			@FromCustID	= @FromCustID
			,@ToCustID	= @ToCustId
			,@AutoTransferSchedule	= @AutoTransferSchedule
			,@Old_TransferOption = @Old_TransferOption
			,@IsAutoJobRunning = @IsAutoJobRunning
			,@Creator = @Creator
			,@SubAccId = @SubAccId
			,@Language = @Language
			,@IP = @IP 
			,@ErrCode = @ErrCode OUTPUT 
			,@ErrMsg = @ErrMsg OUTPUT	
			
		IF @ErrCode > 0
			RETURN
	END
	ELSE
	--enable/disable auto transfer
	BEGIN
		DECLARE @New_TransferOption				TINYINT
				,@Old_TransferOption_numeric	TINYINT
				,@IsAllDayBalanceTransfer		BIT = 0
	
		IF @roleid = 4
		BEGIN
			SELECT @IsAllDayBalanceTransfer = IsAllDayBalTransfer
			FROM CustSuper WITH (NOLOCK)
			WHERE custid = @FromCustId
		END
		IF @roleid = 3
		BEGIN
			SELECT @New_TransferOption = TransferOption
			FROM CustMaster WITH (NOLOCK)
			WHERE custid = @FromCustId

			SELECT @IsAllDayBalanceTransfer = IsAllDayBalTransfer
			FROM CustMaster WITH (NOLOCK)
			WHERE custid = @FromCustId
		END
		ELSE IF @roleid = 2
		BEGIN
			SELECT @New_TransferOption = TransferOption
			FROM CustAgent WITH (NOLOCK)
			WHERE custid = @FromCustId

			SELECT @IsAllDayBalanceTransfer = IsAllDayBalTransfer
			FROM CustMaster cm WITH (NOLOCK)
				INNER JOIN custinfo c WITH (NOLOCK) ON cm.custid = c.mrecommend
			WHERE c.custid = @FromCustId
		END

		--Check if upline is on ADBT
		IF @IsAllDayBalanceTransfer = 1
		BEGIN
			SELECT @ErrCode = 108,
					@ErrMsg = CASE WHEN @Language = 'E' THEN 'Your account has been enabled for All Day Balance Transfer. The page will be automatically refreshed.' 
									ELSE [dbo].[f_Get_MsgNamebyMsgID](50037,@Language) 
									END
			RETURN
		END

		SELECT @Old_TransferOption_numeric = dbo.f_Binary_Decimal(@Old_TransferOption)

		--Check if Transfer Condition of Master/Agent already changed
		IF @Old_TransferOption_numeric <> @New_TransferOption AND @IsAllowAutoTransfer = 1 AND @RoleID IN (2,3) 
		BEGIN
			SELECT @ErrCode = 105,
					@ErrMsg = CASE WHEN @Language = 'E' THEN 'Your Transfer Condition was changed by upline. The page will be automatically refreshed.' 
									ELSE [dbo].[f_Get_MsgNamebyMsgID](50035,@Language) 
									END
			RETURN
		END

		IF @RoleID NOT IN (2,3,4)
		BEGIN  
			SELECT @ErrCode	= 101, 
				@ErrMsg		= CASE WHEN @Language = 'E' THEN 'Customer does not exist.'  
									ELSE [dbo].[f_Get_MsgNamebyMsgID](40014,@Language)
									END    
			GOTO SP_END;  
		END  

		DROP TABLE IF EXISTS #tmpClearBalanceCust;
		CREATE TABLE #tmpClearBalanceCust (FromCustID INT, ToCustID INT PRIMARY KEY, CreatedDate DATETIME, EffectedDate DATE, TransferOption TINYINT);

		INSERT INTO #tmpClearBalanceCust (FromCustID, ToCustID, TransferOption)
		SELECT @FromCustID AS FromCustID, @ToCustId AS ToCustID, @AutoTransferSchedule_Numeric AS TransferOption

		SET @batchCount = @@ROWCOUNT;

		SELECT @pairCount = (
			SELECT COUNT(1) AS PairCount
				FROM dbo.customer c WITH (NOLOCK) 
				INNER JOIN #tmpClearBalanceCust cbs ON cbs.ToCustID = c.custid
			WHERE 1 = CASE 
					WHEN @RoleID = 2 AND c.recommend = @FromCustID AND c.RoleID = 1 THEN 1 -- direct agent/member
					WHEN @RoleID = 3 AND c.mrecommend = @FromCustID AND c.RoleID = 2 THEN 1 --direct master/agent
					WHEN @RoleID = 4 AND c.srecommend = @FromCustID AND c.RoleID = 3 THEN 1 --direct super/master
					ELSE 0
				END
		);

		IF @batchCount <> @pairCount
		BEGIN  
			SELECT @ErrCode	= 102, 
					@ErrMsg	= CASE WHEN @Language = 'E' THEN 'Downline does not match.'  
									ELSE [dbo].[f_Get_MsgNamebyMsgID](40014,@Language)
								END    
			GOTO SP_END;
		END

		--- CHECK for turn OFF AutoTransfer
		IF (
			@IsAllowAutoTransfer = 0
			AND @IsAutoJobRunning = 1
		)
		BEGIN
			SELECT @ErrCode	= 103, 
					@ErrMsg	= [dbo].[f_Get_MsgNamebyMsgID](50019,@Language) 
			GOTO SP_END;
		END

		--TODO: ON/OFF auto transfer setting
		DECLARE @tmpResult TABLE (CustId INT, [EffectiveDate] DATE);

		BEGIN TRY
			IF @IsAllowAutoTransfer = 1 AND @IsAllowAutoTransfer_Old = 0
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
					   ,[Creator]
					   ,[ScheduleOption])
				OUTPUT INSERTED.ToCustID,INSERTED.[EffectiveDate]
				INTO @tmpResult (CustId,[EffectiveDate])
				SELECT ins.FromCustID, cte.ToCustID
					, GETDATE() AS [CreatedDate]
					, CASE WHEN @IsAutoJobRunning = 1 THEN @tomorrow ELSE @today END [EffectiveDate]
					, @Creator AS [Creator]
					, ins.TransferOption
				FROM #tmpClearBalanceCust ins
				INNER JOIN CTE_Insert cte ON cte.ToCustID = ins.ToCustID
				;

				SET @AfftectedRows = @@ROWCOUNT;

				IF EXISTS (SELECT 1 FROM @tmpResult WHERE EffectiveDate > @today)
				BEGIN
					SELECT @ErrCode	= 0,  -- just information NOT Error
							@ErrMsg	= [dbo].[f_Get_MsgNamebyMsgID](50038,@Language)
				END
			END
			ELSE IF @IsAllowAutoTransfer = 0
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
		IF @ErrCode > 0
		BEGIN
			-- NOT write log with error cases
			RETURN;
		END

		SET @duration  = DATEDIFF(MILLISECOND, @StartTime, CURRENT_TIMESTAMP);
		-- TODO: Write log runSP
		BEGIN TRY
			SELECT @LogSPData = CAST(
					(SELECT @FromCustID AS '@FromCustId', @ToCustId AS '@ToCustId', @IsAllowAutoTransfer AS '@IsAllowAutoTransfer',
						@IsAutoJobRunning AS '@IsAutoJobRunning', 
						ISNULL(@IP, SPACE(1)) AS '@IP', @Language AS '@Language', @SubAccId AS '@SubAccId',
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
						@IsAutoJobRunning AS '@IsAutoJobRunning', 
						ISNULL(@IP, SPACE(1)) AS '@IP', @Language AS '@Language', @SubAccId AS '@SubAccId',
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
		--log add auto transfer schedule
		IF @IsAllowAutoTransfer_Old = 0
		BEGIN
			SELECT @LogSPData = '<Age_ClearBalanceCust_SettingUpdate FromCustId="' + COALESCE(CAST(@FromCustId AS VARCHAR(20)),SPACE(1)) +'" '+
									'ToCustID="' +  COALESCE(CAST(@ToCustId AS VARCHAR(20)),SPACE(1)) +'" '+
									'Schedule="' + COALESCE(CAST(@AutoTransferSchedule AS VARCHAR(20)), SPACE(1)) +'" '+									
									'SubAccId="'+ coalesce(cast(@SubAccID as varchar(20)),space(1)) + '" '+
									'Language="' + COALESCE(CAST(@Language AS VARCHAR(2)),SPACE(1)) +'" '+
									'IP="' + COALESCE(CAST(@IP AS VARCHAR(20)),SPACE(1)) +'" '+
									'ErrCode="' + COALESCE(CAST(@ErrCode AS VARCHAR(10)),SPACE(1)) +'" '+
									'ErrMsg="' + COALESCE(CAST(@ErrMsg AS NVARCHAR(3000)),SPACE(1)) +'"'+ '/>'

			SELECT @TrackingValue2 = '<Age_ClearBalanceCust_SettingUpdate FromCustId="' + COALESCE(CAST(@FromCustId AS VARCHAR(20)),SPACE(1)) +'" '+
									'ToCustID="' +  COALESCE(CAST(@ToCustId AS VARCHAR(20)),SPACE(1)) +'" '+
									'Schedule=""' +'/>'	
			BEGIN TRY
				EXEC DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_RunSP
					@UserID = @Creator,
					@CustID = @ToCustID,
					@ActionID = 95099,
					@TrackingValue = @LogSPData,
					@TrackingValue2 = @TrackingValue2,
					@Duration = @Duration
			END TRY
			BEGIN CATCH
				EXEC bodb_CustomerLog.dbo.WriteLog_UserLog_RunSP
					@UserID = @Creator,
					@CustID = @ToCustID,
					@ActionID = 95099,
					@TrackingValue = @LogSPData,
					@TrackingValue2 = @TrackingValue2,
					@Duration = @Duration
			END CATCH
		END
		ELSE IF @IsAllowAutoTransfer = 0
		BEGIN
			SELECT @LogSPData = '<Age_ClearBalanceCust_SettingUpdate FromCustId="' + COALESCE(CAST(@FromCustId AS VARCHAR(20)),SPACE(1)) +'" '+
									'ToCustID="' +  COALESCE(CAST(@ToCustId AS VARCHAR(20)),SPACE(1)) +'" '+
									'Schedule="" '+
									'SubAccId="'+ coalesce(cast(@SubAccID as varchar(20)),space(1)) + '" '+
									'Language="' + COALESCE(CAST(@Language AS VARCHAR(2)),SPACE(1)) +'" '+
									'IP="' + COALESCE(CAST(@IP AS VARCHAR(20)),SPACE(1)) +'" '+
									'ErrCode="' + COALESCE(CAST(@ErrCode AS VARCHAR(10)),SPACE(1)) +'" '+
									'ErrMsg="' + COALESCE(CAST(@ErrMsg AS NVARCHAR(3000)),SPACE(1)) +'"'+ '/>'

			SELECT @TrackingValue2 = '<Age_ClearBalanceCust_SettingUpdate FromCustId="' + COALESCE(CAST(@FromCustId AS VARCHAR(20)),SPACE(1)) +'" '+
									'ToCustID="' +  COALESCE(CAST(@ToCustId AS VARCHAR(20)),SPACE(1)) +'" '+
									'Schedule="' + COALESCE(CAST(dbo.f_AutoTransferSchedule_NumericToChar(@Old_AutoTransferSchedule_numeric) AS VARCHAR(20)), SPACE(1)) +'" ' +'/>'	
			BEGIN TRY
				EXEC DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_RunSP
					@UserID = @Creator,
					@CustID = @ToCustID,
					@ActionID = 95109,
					@TrackingValue = @LogSPData,
					@TrackingValue2 = @TrackingValue2,
					@Duration = @Duration
			END TRY
			BEGIN CATCH
				EXEC bodb_CustomerLog.dbo.WriteLog_UserLog_RunSP
					@UserID = @Creator,
					@CustID = @ToCustID,
					@ActionID = 95109,
					@TrackingValue = @LogSPData,
					@TrackingValue2 = @TrackingValue2,
					@Duration = @Duration
			END CATCH
		END
	END
END
GO