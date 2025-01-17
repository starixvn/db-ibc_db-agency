/*<info serverAlias="DBCUST-CustDB" executers="wsv_alp" viewers="" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Age_ClearCredit_All_Ins]
	@UserId				INT,
	@CustId				INT,
	@SubAccId			INT,
	@DownlineUsername	VARCHAR(50),
	@IP					NVARCHAR(20) = '',
	@Language			VARCHAR(2) = 'E',
	@ErrCode			INT = 0 OUTPUT,
	@ErrMsg				NVARCHAR(4000) = '' OUTPUT,
	@MemberAmountXML	VARCHAR(MAX) = NULL --XML Member Amount
AS

/*
	Created: 20180801@Percy
	DB: DBCUST.CustDB
	Task: Alpha - Transfer - Transfer All & Clear Credit - Clear Credit

	Revisions:
		- 20180801@Percy: Initialize SP [RedmineID: #92142]
		- 20181102@Johnson: Apply service broker for logging [Redmine: #103547]
		- 20230227@Evan: Balance-Up support transfer 247 [Redmine: #173554]
		- 20230510@Eden: Scale out DBTRANS for Credit [Redmine: #181595]
		- 20241118@Max: Alpha - Offer Direct Member for Super/Master [Redmine: #211969]
		- 20241206@Johnson: Apply In-house replication for Credit Setting [RedmineID: #212684]
	Param's Explanation:`
		@MemberAmountXML = '<ROOT>
					  <R ID="1290" AM="2483.0000" />
					  <R ID="1309" AM="65.0000" />
					  <R ID="1311" AM="50.0000" />
					</ROOT>'
*/

BEGIN
	SET NOCOUNT ON
	
	-- General Info
	DECLARE @currency INT, @actualrate FLOAT, @currencyName NVARCHAR(10)

	DECLARE @RoleId TINYINT, @srecommend INT, @username VARCHAR(50)
	SELECT  @RoleId = roleid, @srecommend = srecommend, @currency = currency, @username = username
	FROM	CustDB.dbo.custInfo WITH (NOLOCK)
	WHERE	custId = @CustId

	SELECT  @DownlineUsername = LTRIM(RTRIM(@DownlineUsername))
	
	DECLARE @DownlineCustId INT, @DownlineRoleId TINYINT, @DownlineCredit MONEY
	
	IF @RoleId = 4
		SELECT  @DownlineCustId = custId, @DownlineRoleId = roleId, @DownlineCredit = ISNULL(credit, 0)
		FROM	dbo.custInfo WITH (NOLOCK)
		WHERE	srecommend = @CustId AND username = @DownlineUsername AND roleId = @RoleId - 1
	ELSE IF @RoleId = 3
		SELECT  @DownlineCustId = custId, @DownlineRoleId = roleId, @DownlineCredit = ISNULL(credit, 0)
		FROM	dbo.custInfo WITH (NOLOCK)
		WHERE	mrecommend = @CustId AND username = @DownlineUsername AND roleId = @RoleId - 1

	-- super/master only -- invalid downline
	IF @RoleId NOT IN (3,4) OR @DownlineCustId IS NULL
	BEGIN
		SELECT  @ErrCode = 100,
				@ErrMsg = CASE @Language WHEN 'E' THEN 'Customer does not exist' ELSE dbo.f_Get_MsgNamebyMsgID (40014, @Language) END
		
		RETURN
	END

	-- Check rule before clear credit
	BEGIN
		DECLARE @IsErr BIT = 0
		DECLARE @ErrTable TABLE (Id TINYINT, Content NVARCHAR(4000))

		-- 1. Given credit of selected account
		IF @DownlineCredit <= 0
		BEGIN
			INSERT INTO @ErrTable (Id, Content)
			SELECT 1, dbo.f_Get_MsgNamebyMsgID(40036, @Language)
		END

		-- 3. Nagative given credit
		IF @RoleId = 4
		BEGIN
			IF EXISTS (SELECT 1 FROM dbo.custInfo WITH (NOLOCK) WHERE mrecommend = @DownlineCustId AND ISNULL(credit, 0) < 0)
			BEGIN
				INSERT INTO @ErrTable (Id, Content)
				SELECT 3, dbo.f_Get_MsgNamebyMsgID(40037, @Language)
			END
		END
		ELSE IF @RoleId = 3
		BEGIN
			IF EXISTS (SELECT 1 FROM dbo.custInfo WITH (NOLOCK) WHERE recommend = @DownlineCustId AND ISNULL(credit, 0) < 0)
			BEGIN
				INSERT INTO @ErrTable (Id, Content)
				SELECT 3, dbo.f_Get_MsgNamebyMsgID(40037, @Language)
			END
		END

		-- 3. Nagative bet credit -- calculate amount part
	END

	-- List of Agents
	BEGIN
		DECLARE @tblrecommend TABLE (recommend INT PRIMARY KEY)

		IF @RoleId = 4
			INSERT INTO @tblrecommend (recommend)
			SELECT custid FROM dbo.custInfo WITH (NOLOCK) WHERE mrecommend = @DownlineCustId AND roleId = 2
			UNION ALL 
			SELECT -3
		ELSE
			INSERT INTO @tblrecommend (recommend)
			VALUES (@DownlineCustId)
	END

	DECLARE @SubAccName NVARCHAR(50)
	IF @SubAccId > 0
		SELECT @SubAccName = username FROM dbo.custSub WITH (NOLOCK) WHERE SubAccID = @SubAccID

	-- Clear given credit process
	BEGIN
		-- same error message when clear failed
		SELECT  @ErrMsg = 'Clear credit unsuccessfully. Please try again.'

		DECLARE @GivenCreditMember MONEY = 0, @GivenCreditAgent MONEY = 0,
				@ClearedCreditMember MONEY = 0, @ClearedCreditAgent MONEY = 0,
				@DirectMemberCredit MONEY = 0, @DirectmemberClearedCredit MONEY = 0
		
		-- for log
		DECLARE @UpdCredit TABLE (custId INT, oldCredit MONEY, newCredit MONEY)
		DECLARE @ActionId INT = 1212
		DECLARE @LogData VARCHAR(1000)
		DECLARE @log xml, @SB_Error BIT = 0
		/*
			========================= Start Member =========================
		*/

		DECLARE @recommend INT
		DECLARE @DocHandler INT	
		CREATE TABLE #MemberAmount (custId INT, amount MONEY)
		CREATE TABLE #tblMember (custId INT, recommend INT, credit MONEY, betCredit MONEY, newCredit MONEY)

		IF ISNULL(@MemberAmountXML,'') <> ''
		BEGIN
			-- For read xml					
			EXEC sp_xml_preparedocument @DocHandler OUTPUT, @MemberAmountXML

			INSERT INTO #MemberAmount(custId,amount)
			SELECT ID,AM
			FROM OPENXML (@DocHandler, '/ROOT/R',1) 
			WITH (
				ID INT, 
				AM MONEY
			) AS Data

			EXEC sp_xml_removedocument @DocHandler
			-- end read xml	
		END		

		IF @RoleId = 4
		BEGIN
			INSERT INTO #tblMember (custId, recommend, credit, betCredit, newCredit)
			SELECT c.custId, c.recommend,
				ISNULL(c.credit, 0),
				ISNULL(c.credit, 0) + ISNULL(m.amount, 0),
				CASE WHEN ISNULL(m.amount, 0) >= 0 THEN 0 ELSE ABS(ISNULL(m.amount, 0)) END
			FROM dbo.custInfo c WITH (NOLOCK)
				LEFT JOIN #MemberAmount m ON c.custid = m.custId
			WHERE c.mrecommend = @DownlineCustId AND c.roleId = 1
		END
		ELSE
		BEGIN
			INSERT INTO #tblMember (custId, recommend, credit, betCredit, newCredit)
			SELECT c.custId, c.recommend,
				ISNULL(c.credit, 0),
				ISNULL(c.credit, 0) + ISNULL(m.amount, 0),
				CASE WHEN ISNULL(m.amount, 0) >= 0 THEN 0 ELSE ABS(ISNULL(m.amount, 0)) END
			FROM dbo.custInfo c WITH (NOLOCK)
				LEFT JOIN #MemberAmount m ON c.custid = m.custId
			WHERE c.recommend = @DownlineCustId AND c.roleId = 1
		END

		DROP TABLE #MemberAmount

		-- Back to check rule before transfer
		-- 4. Nagative bet credit
		IF EXISTS (SELECT 1 FROM #tblMember WHERE betCredit < 0)
		BEGIN
			INSERT INTO @ErrTable (Id, Content)
			SELECT 4, dbo.f_Get_MsgNamebyMsgID(50012, @Language)
		END

		IF EXISTS (SELECT 1 FROM @ErrTable)
		BEGIN
			SELECT @ErrCode = 200
			SELECT @IsErr = 1
		END

		IF @IsErr = 0
		BEGIN
			SELECT @GivenCreditMember = SUM(CASE WHEN recommend > 0 THEN credit ELSE 0 END) 
				, @DirectMemberCredit = SUM(CASE WHEN recommend = -3 THEN credit ELSE 0 END) 
			FROM #tblMember

			DELETE #tblMember WHERE betCredit <= 0

			DECLARE CS_agent CURSOR
				FOR SELECT recommend FROM @tblrecommend

			OPEN CS_agent

			FETCH NEXT FROM CS_agent
				INTO @recommend

			WHILE @@FETCH_STATUS = 0
			BEGIN
				UPDATE c WITH (ROWLOCK, UPDLOCK)
				SET c.credit = t.newCredit,
					RepUpdateTime = dbo.f_GetDateTime2()
				OUTPUT DELETED.custid, DELETED.credit, INSERTED.credit INTO @UpdCredit (custid, oldCredit, newCredit)
				FROM dbo.CustInfo c
					INNER JOIN #tblMember t ON c.custid = t.custid
				WHERE c.recommend = @recommend

				IF @@ERROR <> 0
				BEGIN
					SELECT @ErrCode = 111
					RETURN
				END

				SELECT @ClearedCreditMember = @ClearedCreditMember + ISNULL(SUM(CASE WHEN @recommend > 0 THEN (oldCredit - newCredit) ELSE 0 END),0) 
					, @DirectmemberClearedCredit = @DirectmemberClearedCredit + ISNULL(SUM(CASE WHEN @recommend = -3 THEN (oldCredit - newCredit) ELSE 0 END),0)
				FROM @UpdCredit

				-- for log
				SELECT @LogData = 'Clear Credit all:' + CASE @RoleId WHEN 4 THEN ' Master ' WHEN 3 THEN ' Agent ' END + @DownlineUsername

				IF @SubAccID > 0
					SELECT @LogData = 'SubAccount:' + COALESCE(@SubAccName, SPACE(1)) + ' - ' + @LogData
				
				SELECT @log = '', @SB_Error = 0
				
				SELECT @log = (
					SELECT @UserID as UserID,CustID, oldCredit as OldValue, newCredit as NewValue, @ip as IP, @LogData as Doing, @ActionId as ActionID, getdate() as LogDate
					FROM @UpdCredit
					FOR XML RAW('Row')
				)

				EXEC bodb_CustomerLog.sb.CustomerLog_SendMessage @xml = @log, 
																@MessageType='MessageType_CustomerLog_UserLog_Credit', 
																@functionName = 'UserLog_Others',
																@SB_Error = @SB_Error out

				--if ssb error
				IF @SB_Error = 1
				BEGIN
					-- Write log
					BEGIN TRY
						INSERT INTO DBLOG.bodb_CustomerLog.dbo.Userlog_Credit (userid, custid, OldValue, NewValue, ip, doing, ActionID)
						SELECT	@UserID, custid, oldCredit, newCredit, @ip, @LogData, @ActionId 
						FROM	@UpdCredit 
					END TRY
					BEGIN CATCH
						SELECT @LogData = @LogData + ' ErrMsg=' + ERROR_MESSAGE()
	
						INSERT INTO bodb_CustomerLog.dbo.userlog_Credit(userid, custid, OldValue, NewValue, ip, doing, ActionID)
						SELECT	@UserID, custid, oldCredit, newCredit, @ip, @LogData, @ActionId 
						FROM	@UpdCredit 
					END CATCH						
				END	
				DELETE @UpdCredit

				FETCH NEXT FROM CS_agent
					INTO @recommend
			END

			CLOSE CS_agent

			DEALLOCATE CS_agent

			DROP TABLE #tblMember

			/*
				========================= End Member =========================
			*/

			/*
				========================= Start Agent =========================
			*/
			CREATE TABLE #tblrecommend (custId INT PRIMARY KEY, credit MONEY, updCredit MONEY DEFAULT(0))

			IF @RoleId = 4
				INSERT INTO #tblrecommend (custid, credit, updCredit)
				SELECT a.custid, a.credit, ISNULL(m.usedCredit, 0)
				FROM dbo.custInfo a WITH (NOLOCK)
					LEFT JOIN (
						SELECT recommend, SUM(ISNULL(credit, 0)) AS usedCredit
						FROM dbo.custInfo WITH (NOLOCK)
						WHERE mrecommend = @DownlineCustId AND roleId = 1
						GROUP BY recommend
					) m ON a.custid = m.recommend
				WHERE a.mrecommend = @DownlineCustId AND a.roleId = 2 AND ISNULL(a.credit, 0) <> 0
			ELSE
				INSERT INTO #tblrecommend (custid, credit, updCredit)
				SELECT a.custid, a.credit, ISNULL(m.usedCredit, 0)
				FROM dbo.custInfo a WITH (NOLOCK)
					LEFT JOIN (
						SELECT recommend, SUM(ISNULL(credit, 0)) AS usedCredit
						FROM dbo.custInfo WITH (NOLOCK)
						WHERE recommend = @DownlineCustId AND roleId = 1
						GROUP BY recommend
					) m ON a.custid = m.recommend
				WHERE a.custid = @DownlineCustId AND a.roleId = 2 AND ISNULL(a.credit, 0) <> 0
			
			UPDATE c WITH (ROWLOCK, UPDLOCK)
			SET c.credit = t.UpdCredit,
				RepUpdateTime = dbo.f_GetDateTime2()
			OUTPUT DELETED.custid, DELETED.credit, INSERTED.credit INTO @UpdCredit (custid, oldCredit, newCredit)
			FROM dbo.CustInfo c
				INNER JOIN #tblrecommend t ON c.custid = t.custid

			IF @@ERROR <> 0
			BEGIN
				SELECT @ErrCode = 112
				RETURN
			END

			SELECT @ClearedCreditAgent = SUM(oldCredit - newCredit) FROM @UpdCredit

			-- for log
			SELECT @LogData = 'Clear Credit all:' + CASE @RoleId WHEN 4 THEN ' Master ' WHEN 3 THEN ' Agent ' END + @DownlineUsername

			IF @SubAccID > 0
				SELECT @LogData = 'SubAccount:' + COALESCE(@SubAccName, SPACE(1)) + ' - ' + @LogData
			
			SELECT @log = '', @SB_Error = 0
					
			SELECT @log = (
				SELECT @UserID as UserID,CustID, oldCredit as OldValue, newCredit as NewValue, @ip as IP, @LogData as Doing, @ActionId as ActionID, getdate() as LogDate
				FROM @UpdCredit
				FOR XML RAW('Row')
			)

			EXEC bodb_CustomerLog.sb.CustomerLog_SendMessage @xml = @log, 
															@MessageType='MessageType_CustomerLog_UserLog_Credit', 
															@functionName = 'UserLog_Others',
															@SB_Error = @SB_Error out

			--if ssb error
			IF @SB_Error = 1
			BEGIN
				-- Write log
				BEGIN TRY
					INSERT INTO DBLOG.bodb_CustomerLog.dbo.Userlog_Credit (userid, custid, OldValue, NewValue, ip, doing, ActionID)
					SELECT	@UserID, custid, oldCredit, newCredit, @ip, @LogData, @ActionId 
					FROM	@UpdCredit
				END TRY
				BEGIN CATCH
					SELECT @LogData = @LogData + ' ErrMsg=' + ERROR_MESSAGE()
		
					INSERT INTO bodb_CustomerLog.dbo.userlog_Credit(userid, custid, OldValue, NewValue, ip, doing, ActionID)
					SELECT	@UserID, custid, oldCredit, newCredit, @ip, @LogData, @ActionId 
					FROM	@UpdCredit
				END CATCH
			END
			
			DELETE @UpdCredit

			SELECT @GivenCreditAgent = SUM(credit) FROM #tblrecommend

			DROP TABLE #tblrecommend

			/*
				========================= End Agent =========================
			*/

			/*
				========================= Start Master =========================
			*/
			IF @RoleId = 4
			BEGIN
				DECLARE @usedCreditMaster MONEY
				SELECT  @usedCreditMaster = SUM(ISNULL(credit, 0))
				FROM dbo.custInfo WITH (NOLOCK)
				WHERE mrecommend = @DownlineCustId 
					AND 1 = CASE WHEN roleId = 2 THEN 1
								WHEN roleid = 1 AND recommend = -3 THEN 1
								ELSE 0 END

				SELECT  @usedCreditMaster = ISNULL(@usedCreditMaster, 0)

				UPDATE dbo.custInfo WITH (ROWLOCK, UPDLOCK)
				SET credit = @usedCreditMaster,
					RepUpdateTime = dbo.f_GetDateTime2()
				WHERE custId = @DownlineCustId

				IF @@ERROR <> 0
				BEGIN
					SELECT @ErrCode = 113
					RETURN
				END

				-- for log
				SELECT @LogData = 'Clear Credit all:' + CASE @RoleId WHEN 4 THEN ' Master ' WHEN 3 THEN ' Agent ' END + @DownlineUsername

				IF @SubAccID > 0
					SELECT @LogData = 'SubAccount:' + COALESCE(@SubAccName, SPACE(1)) + ' - ' + @LogData
				
				SELECT @log = '', @SB_Error = 0
					
				SELECT @log = (SELECT @UserID as '@UserID',
									@DownlineCustId as '@CustID',
									@LogData as '@Doing',
									@DownlineCredit as '@OldValue',
									@usedCreditMaster as '@NewValue',
									@IP as '@IP',
									@ActionId as '@ActionID',
									getdate() as '@LogDate'
								FOR XML PATH('Row')	
							)

				EXEC bodb_CustomerLog.sb.CustomerLog_SendMessage @xml = @log, 
																@MessageType='MessageType_CustomerLog_UserLog_Credit', 
																@functionName = 'UserLog_Others',
																@SB_Error = @SB_Error out

				--if ssb error
				IF @SB_Error = 1
				BEGIN
					-- write log
					BEGIN TRY  
						EXEC DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_Credit  
							@UserID		= @UserID,
							@CustID		= @DownlineCustId,
							@Doing		= @LogData,
							@OldValue	= @DownlineCredit,
							@NewValue	= @usedCreditMaster,
							@IP			= @IP,
							@ActionID	= @ActionId
					END TRY  
					BEGIN CATCH  
						SELECT @LogData = @LogData + ' ErrMsg=' + ERROR_MESSAGE()
		  
						EXEC bodb_CustomerLog.dbo.WriteLog_UserLog_Credit  
							@UserID		= @UserID,
							@CustID		= @DownlineCustId,
							@Doing		= @LogData,
							@OldValue	= @DownlineCredit,
							@NewValue	= @usedCreditMaster,
							@IP			= @IP,
							@ActionID	= @ActionId
					END CATCH
				END	
			END
		END

		/*
			========================= End Master =========================
		*/

		SELECT @ErrMsg = ''

		-- Return error table
		SELECT ROW_NUMBER() OVER(ORDER BY Id) AS RowId, Content
		FROM @ErrTable
		ORDER BY RowId

		-- Return cleared credit table
		SELECT 1 AS RowId, @GivenCreditMember AS GivenCredit, @ClearedCreditMember AS ClearedCredit
		UNION ALL
		SELECT 2, @GivenCreditAgent, @ClearedCreditAgent
		UNION ALL
		SELECT -3, @DirectMemberCredit, @DirectmemberClearedCredit
		UNION ALL
		SELECT 3, @DownlineCredit, @DownlineCredit - @usedCreditMaster
		WHERE @RoleId = 4
	END
END
GO