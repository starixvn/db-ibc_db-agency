/*<info serverAlias="DBCUST-CustDB" executers="bodbDownlineNet" isFunction="0" isNested="0"></info>*/
USE [CustDB]
GO

ALTER PROCEDURE [dbo].[Age_ClearCredit_All_Ins]
	@UserId				INT,
	@CustId				INT,
	@SubAccId			INT,
	@DownlineUsername	VARCHAR(50),
	@IP					NVARCHAR(20) = '',
	@Language			VARCHAR(2) = 'E',
	@ErrCode			INT = 0 OUTPUT,
	@ErrMsg				NVARCHAR(4000) = '' OUTPUT
AS

/*
	Created: 20180801@Percy
	DB: DBAGE.bodb02
	Task: Alpha - Transfer - Transfer All & Clear Credit - Clear Credit

	Revisions:
		- 20180801@Percy: Initialize SP [RedmineID: #92142]
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
	SELECT  @DownlineCustId = custId, @DownlineRoleId = roleId, @DownlineCredit = ISNULL(credit, 0)
	FROM	dbo.custInfo WITH (NOLOCK)
	WHERE	username = @DownlineUsername AND roleId = @RoleId - 1

	-- super/master only -- invalid downline
	IF @RoleId NOT IN (3,4) OR @DownlineCustId IS NULL
	BEGIN
		SELECT  @ErrCode = 100,
				@ErrMsg = CASE @Language WHEN 'E' THEN 'Customer does not exist' ELSE dbo.f_Get_MsgNamebyMsgID (40014, @Language) END
		
		RETURN
	END

	IF @DownlineCredit = 0
	BEGIN
		SELECT  @ErrCode = 101,
				@ErrMsg = CASE @Language WHEN 'E' THEN 'The selected customer has no credit to be cleared.' ELSE dbo.f_Get_MsgNamebyMsgID (40036, @Language) END
		
		RETURN
	END

	-- List of Agents
	BEGIN
		DECLARE @tblrecommend TABLE (recommend INT PRIMARY KEY)

		IF @RoleId = 4
			INSERT INTO @tblrecommend (recommend)
			SELECT custid FROM dbo.custInfo WITH (NOLOCK) WHERE mrecommend = @DownlineCustId AND roleId = 2
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
				@ClearedCreditMember MONEY = 0, @ClearedCreditAgent MONEY = 0
		
		-- for log
		DECLARE @UpdCredit TABLE (custId INT, oldCredit MONEY, newCredit MONEY)
		DECLARE @ActionId INT = 1212
		DECLARE @LogData VARCHAR(1000)
		/*
			========================= Start Member =========================
		*/

		DECLARE @recommend INT

		CREATE TABLE #MemberAmount (custId INT, amount MONEY)
		CREATE TABLE #tblMember (custId INT, recommend INT, credit MONEY, betCredit MONEY, newCredit MONEY)

		INSERT INTO #MemberAmount (custId, amount)
		EXEC DBTXN.bodb02.dbo.Age_Customer_TotalAmount_Sel @custId = @DownlineCustId, @RoleId = @DownlineRoleId

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
				AND ISNULL(c.credit, 0) <> 0
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
				AND ISNULL(c.credit, 0) <> 0
		END

		DROP TABLE #MemberAmount

		SELECT @GivenCreditMember = SUM(credit) FROM #tblMember

		DELETE #tblMember WHERE betCredit < 0

		DECLARE CS_agent CURSOR
			FOR SELECT recommend FROM @tblrecommend

		OPEN CS_agent

		FETCH NEXT FROM CS_agent
			INTO @recommend

		WHILE @@FETCH_STATUS = 0
		BEGIN
			SELECT @ErrCode = 0

			-- Prevent user from decreasing given credit due to processing data
			EXEC DBTXN.bodb02.dbo.Acc_Core_IsMainProcessRunning
					@CustId				= 0,
					@UplineId			= @recommend,
					@IsDepositMember	= 0,
					@ErrCode			= @ErrCode OUTPUT,
					@ErrMsg				= @ErrMsg OUTPUT

			IF @ErrCode = 0
			BEGIN
				UPDATE c WITH (ROWLOCK, UPDLOCK)
				SET c.credit = t.newCredit
					OUTPUT DELETED.custid, DELETED.credit, INSERTED.credit INTO @UpdCredit (custid, oldCredit, newCredit)
				FROM dbo.CustInfo c
					INNER JOIN #tblMember t ON c.custid = t.custid

				IF @@ERROR <> 0
				BEGIN
					SELECT @ErrCode = 111
					RETURN
				END

				SELECT @ClearedCreditMember = @ClearedCreditMember + SUM(oldCredit - newCredit) FROM @UpdCredit

				-- for log
				SELECT @LogData = 'Clear Credit all:' + CASE @RoleId WHEN 4 THEN ' Master ' WHEN 3 THEN ' Agent ' END + @DownlineUsername

				IF @SubAccID > 0
					SELECT @LogData = 'SubAccount:' + COALESCE(@SubAccName, SPACE(1)) + ' - ' + @LogData

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

				DELETE @UpdCredit
			END

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
			SELECT a.custid, a.credit, m.usedCredit
			FROM dbo.custInfo a WITH (NOLOCK)
				INNER JOIN (
					SELECT recommend, SUM(ISNULL(credit, 0)) AS usedCredit
					FROM dbo.custInfo WITH (NOLOCK)
					WHERE mrecommend = @DownlineCustId AND roleId = 1
					GROUP BY recommend
				) m ON a.custid = m.recommend
			WHERE a.mrecommend = @DownlineCustId AND a.roleId = 2 AND ISNULL(a.credit, 0) <> 0
		ELSE
			INSERT INTO #tblrecommend (custid, credit, updCredit)
			SELECT a.custid, a.credit, m.usedCredit
			FROM dbo.custInfo a WITH (NOLOCK)
				INNER JOIN (
					SELECT recommend, SUM(ISNULL(credit, 0)) AS usedCredit
					FROM dbo.custInfo WITH (NOLOCK)
					WHERE recommend = @DownlineCustId AND roleId = 1
					GROUP BY recommend
				) m ON a.custid = m.recommend
			WHERE a.custid = @DownlineCustId AND a.roleId = 2 AND ISNULL(a.credit, 0) <> 0
			
		UPDATE c WITH (ROWLOCK, UPDLOCK)
		SET c.credit = t.UpdCredit
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
			WHERE mrecommend = @DownlineCustId AND roleId = 2

			UPDATE dbo.custInfo WITH (ROWLOCK, UPDLOCK)
			SET credit = @usedCreditMaster
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
		/*
			========================= End Master =========================
		*/

		SELECT @ErrMsg = ''

		SELECT 1 AS RowId, @GivenCreditMember AS GivenCredit, @ClearedCreditMember AS ClearedCredit
		UNION ALL
		SELECT 2, @GivenCreditAgent, @ClearedCreditAgent
		UNION ALL
		SELECT 3, @DownlineCredit, @DownlineCredit - @usedCreditMaster
		WHERE @RoleId = 4
	END
END
GO