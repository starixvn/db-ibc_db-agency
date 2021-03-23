/*<info serverAlias="DBTXN-bodb02" executers="bodbDownlineNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Age_Transfer_All_Ins]
	@UserId					INT,
	@CustId					INT,
	@SubAccId				INT,
	@DownlineUsername		NVARCHAR(50),
	@SuperIDsTransferTotal	NVARCHAR(50) = '',
	@IsAllDayTransfer		BIT = 0,
	@IP						NVARCHAR(15) = '',
	@Language				VARCHAR(2) = 'E',
	@ErrCode				INT = 0 OUTPUT,
	@ErrMsg					NVARCHAR(4000) = '' OUTPUT
AS

/*
	Created: 20180801@Percy
	DB: DBTXN.bodb02
	Task: Alpha - Transfer - Transfer All & Clear Credit - Transfer All

	Revisions:
		- 20180801@Percy: Initialize SP [RedmineID: #92142]
		- 20181109@Percy: Correct balance member [RedmineID: #104536]
		- 20200602@Percy: Separate PendingTransfer3rd from Cash and Balance [RedmineID: #135200]
		- 20200821@Sophia: prevent duplicated transfer [Redmine: #137141]
		- 20200821@Sophia: Check UM Transfer Function [Redmine: #136992]
		- 20201005@Danny: Convert Ipv6 to dummy IPv4 [Redmine: #142511]
		- 20201015@Malcolm : Add sub account information when transfering [RedmineId : #143478]
		- 20201228@Danny: Capture total cash before transfering  [Redmine: #146038]
*/

BEGIN
	SET NOCOUNT ON
	
	select @IP = dbo.f_ConvertIPv6ToDummy(@IP)	

	---- #1 CHECK UM TRANSFER FUNCTION
	EXEC DBCUST.CUSTDB.dbo.Acc_Transfer_CheckUM  
		@CustID = @CustID
		,@Language = @Language
		,@ErrMsg = @ErrMsg OUTPUT 
		,@ErrCode = @ErrCode OUTPUT
		 
	IF @ErrCode <> 0  -- Function Transfer is under UM 
	BEGIN
		RETURN		
	END		

	---- #2 CHECK FLAG ISTRANSFERRING = 1 THEN RAISE ERROR
	EXEC DBCUST.CUSTDB.dbo.Acc_Transfer_CheckRunningByCust  
			@CustID = @CustID
			,@Language = @Language
			,@ErrMsg = @ErrMsg OUTPUT 
			,@ErrCode = @ErrCode OUTPUT
			 
	IF @ErrCode <> 0  -- the auto transfer job is running this custid
	BEGIN		
		RETURN		
	END	
	
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
		FROM	DBCUST.CustDB.dbo.custInfo WITH (NOLOCK) -- get credit amount real time
		WHERE	srecommend = @CustId AND username = @DownlineUsername AND roleId = @RoleId - 1
	ELSE IF @RoleId = 3
		SELECT  @DownlineCustId = custId, @DownlineRoleId = roleId, @DownlineCredit = ISNULL(credit, 0)
		FROM	DBCUST.CustDB.dbo.custInfo WITH (NOLOCK) -- get credit amount real time
		WHERE	mrecommend = @CustId AND username = @DownlineUsername AND roleId = @RoleId - 1

	-- super/master only -- invalid downline
	IF @RoleId NOT IN (3,4) OR @DownlineCustId IS NULL
	BEGIN
		SELECT  @ErrCode = 100,
				@ErrMsg = CASE @Language WHEN 'E' THEN 'Customer does not exist' ELSE dbo.f_Get_MsgNamebyMsgID (40014, @Language) END
		
		RETURN
	END

	SELECT	@currencyName = currency, @actualrate = actualrate
	FROM	CustDB.dbo.Exchange WITH (NOLOCK)
	WHERE	exchangeid = @currency

	-- Check rule before transfer
	BEGIN
		DECLARE @IsErr BIT = 0
		DECLARE @ErrTable TABLE (Id TINYINT, Content NVARCHAR(4000))
	
		-- 1. Check processing data
		DECLARE @EndProcessingTime DATETIME, @RemainingTime VARCHAR(30)
		EXEC dbo.Acc_CheckProcessingData @EndProcessingTime = @EndProcessingTime OUTPUT

		IF @EndProcessingTime IS NOT NULL
		BEGIN
			SELECT  @ErrMsg = CASE @Language WHEN 'E' THEN 'To ensure the accuracy of data while being processed, all transfer transaction cannot be executed. The expected time to finish is {expandedtime} (GMT +8). We are sorry for any inconvenience caused.'
										ELSE dbo.f_Get_MsgNamebyMsgID(50010, @Language)	END,
					@RemainingTime = CONVERT(VARCHAR(8), DATEADD(HOUR, 12, @EndProcessingTime), 114) + ' ' + CONVERT(VARCHAR(10), DATEADD(HOUR, 12, @EndProcessingTime), 101) --convert time to GMT +8

			SELECT	@ErrMsg = REPLACE(@ErrMsg, '{expandedtime}', @RemainingTime)

			INSERT INTO @ErrTable (Id, Content)
			SELECT 1, @ErrMsg

			SELECT @ErrMsg = ''
		END

		-- 2. Nagative given credit
		IF @RoleId = 4
		BEGIN
			 -- get credit amount real time: DBCUST
			IF EXISTS (SELECT 1 FROM DBCUST.CustDB.dbo.custInfo WITH (NOLOCK) WHERE mrecommend = @DownlineCustId AND ISNULL(credit, 0) < 0)
			BEGIN
				INSERT INTO @ErrTable (Id, Content)
				SELECT 2, dbo.f_Get_MsgNamebyMsgID(40037, @Language)
			END
		END
		ELSE IF @RoleId = 3
		BEGIN
			-- get credit amount real time: DBCUST
			IF EXISTS (SELECT 1 FROM DBCUST.CustDB.dbo.custInfo WITH (NOLOCK) WHERE recommend = @DownlineCustId AND ISNULL(credit, 0) < 0)
			BEGIN
				INSERT INTO @ErrTable (Id, Content)
				SELECT 2, dbo.f_Get_MsgNamebyMsgID(40037, @Language)
			END
		END

		-- 3. Nagative bet credit after transfer -- calculate balance part

		-- 4.Transferred to member
		DECLARE @tblcustId TABLE (custid INT)
		
		IF @IsAllDayTransfer = 0
		BEGIN
			IF @RoleId = 4
				INSERT INTO @tblcustId (custid)
				SELECT custid FROM CustDB.dbo.custInfo WITH (NOLOCK) WHERE mrecommend = @DownlineCustId AND roleId = 1
			ELSE IF @RoleId = 3
				INSERT INTO @tblcustId (custid)
				SELECT custid FROM CustDB.dbo.custInfo WITH (NOLOCK) WHERE recommend = @DownlineCustId AND roleId = 1

			IF EXISTS (
					SELECT TOP 1 1
					FROM @tblcustId c
						CROSS APPLY (
							SELECT TOP 1 1 AS t FROM dbo.bettrans b WITH (NOLOCK)
							WHERE b.custid = c.custid
								AND b.matchId = 0
								AND b.bettype IN (21003, 21004)
								AND b.transdate >= CONVERT(DATE, GETDATE()) AND b.transdate < DATEADD(DAY, 1, CONVERT(DATE, GETDATE()))
						) AS b
				)
			BEGIN
				INSERT INTO @ErrTable (Id, Content)
				SELECT 4, dbo.f_Get_MsgNamebyMsgID(50013, @Language)
			END
		END

		-- 5. Condition transfer (Exclude Super)
		IF @RoleId = 3
		BEGIN
			DECLARE @strTransferOption VARCHAR(8)

			SELECT @ErrCode = 0, @ErrMsg = ''

			EXEC DBCUST.CustDB.dbo.Age_Transfer_CheckTransferOption
				@CustId				= @CustId,
				@Language			= @Language,
				@ErrCode			= @ErrCode OUTPUT,
				@ErrMsg				= @ErrMsg OUTPUT,
				@strTransferOption	= @strTransferOption OUTPUT
				
			IF @ErrCode <> 0
			BEGIN
				SELECT @ErrMsg = dbo.f_Get_MsgNamebyMsgID(50014, @Language)
							+	CASE WHEN SUBSTRING(@strTransferOption, 2, 1) = 1 THEN [dbo].[f_Get_MsgNamebyMsgID](90002,@Language) + ' - ' ELSE '' END +
								CASE WHEN SUBSTRING(@strTransferOption, 3, 1) = 1 THEN [dbo].[f_Get_MsgNamebyMsgID](90003,@Language) + ' - ' ELSE '' END +
								CASE WHEN SUBSTRING(@strTransferOption, 4, 1) = 1 THEN [dbo].[f_Get_MsgNamebyMsgID](90004,@Language) + ' - ' ELSE '' END +
								CASE WHEN SUBSTRING(@strTransferOption, 5, 1) = 1 THEN [dbo].[f_Get_MsgNamebyMsgID](90005,@Language) + ' - ' ELSE '' END +
								CASE WHEN SUBSTRING(@strTransferOption, 6, 1) = 1 THEN [dbo].[f_Get_MsgNamebyMsgID](90006,@Language) + ' - ' ELSE '' END +
								CASE WHEN SUBSTRING(@strTransferOption, 7, 1) = 1 THEN [dbo].[f_Get_MsgNamebyMsgID](90007,@Language) + ' - ' ELSE '' END +
								CASE WHEN SUBSTRING(@strTransferOption, 1, 1) = 1 THEN [dbo].[f_Get_MsgNamebyMsgID](90008,@Language) + ' - ' ELSE '' END
				SELECT @ErrMsg = LEFT(@ErrMsg, LEN(@ErrMsg) - 2)

				INSERT INTO @ErrTable (Id, Content)
				SELECT 5, @ErrMsg
			END

			SELECT @ErrCode = 0, @ErrMsg = ''
		END
	END

	-- Get Agent List
	BEGIN
		DECLARE @tblrecommend TABLE (ID INT IDENTITY (1,1), recommend INT, username NVARCHAR(50))

		IF @RoleId = 4
		BEGIN
			INSERT INTO @tblrecommend (recommend, username)
			SELECT custId, username
			FROM CustDB.dbo.custInfo WITH (NOLOCK)
			WHERE mrecommend = @DownlineCustId AND RoleId = 2
		END
		ELSE IF @RoleId = 3
		BEGIN
			INSERT INTO @tblrecommend (recommend, username)
			VALUES (@DownlineCustId, @DownlineUsername)
		END
		
		DECLARE @i INT = 1, @recommend INT
				
		WHILE 1 = 1
		BEGIN 		
			SELECT @recommend = recommend FROM @tblrecommend 
			WHERE ID = @i
			
			IF @@ROWCOUNT = 0  
			BREAK
			
			---- #2 CHECK FLAG ISTRANSFERRING = 1 THEN RAISE ERROR
			EXEC DBCUST.CustDB.dbo.Acc_Transfer_CheckRunningByCust  
					@CustID = @recommend
					,@Language = @Language
					,@ErrMsg = @ErrMsg OUTPUT 
					,@ErrCode = @ErrCode OUTPUT
					 
			IF @ErrCode <> 0  -- the auto transfer job is running this custid
			BEGIN		
				RETURN		
			END			
			
			SELECT @i = @i +1 
		END 
	END
	
	
	

	-- Calculate data
	BEGIN
		DECLARE @yesterday SMALLDATETIME
		SELECT  @yesterday = DATEADD(DAY, -1, CONVERT(DATE, GETDATE()))

		DECLARE @masterBalance MONEY

		CREATE TABLE #tempData
		(
			winlostdate SMALLDATETIME, bettype INT, statusId TINYINT,
			custid INT, recommend INT,
			winlost MONEY DEFAULT (0), actual_stake MONEY DEFAULT (0), playercomm MONEY DEFAULT (0),
			awinlost MONEY DEFAULT (0), comm MONEY DEFAULT (0),
			mwinlost MONEY DEFAULT (0), acomm MONEY DEFAULT (0)
		)
		
		-- Total Balance
		BEGIN
			-- bettrans
			INSERT INTO #tempData
			(
				winlostdate, bettype, statusId,
				custid, recommend,
				winlost, actual_stake, playercomm,
				awinlost, comm,
				mwinlost, acomm
			)
			SELECT
				b.winlostdate, b.bettype, b.statusId,
				b.custid, b.recommend,
				SUM(b.winlost), SUM(b.actual_stake), SUM(b.playercomm),
				SUM(b.awinlost), SUM(b.comm),
				SUM(b.mwinlost), SUM(b.acomm)
			FROM dbo.bettrans b WITH (NOLOCK)
				INNER JOIN @tblrecommend r ON b.recommend = r.recommend
			WHERE b.bettype NOT IN (21008, 21009)
			GROUP BY
				b.winlostdate, b.bettype, b.statusId,
				b.custid, b.recommend

			-- Master Balance
			IF @RoleId = 4
			BEGIN
				INSERT INTO #tempData
				(
					winlostdate, bettype, statusId,
					custid,
					winlost, actual_stake
				)
				SELECT
					winlostdate, bettype, 112,
					@DownlineCustId,
					SUM(winlost), SUM(actual_stake)
				FROM dbo.bettrans WITH (NOLOCK)
				WHERE custId = @DownlineCustId AND matchId = 0 AND bettype >= 20000
				GROUP BY
					winlostdate, bettype
			END

			-- Don't get tickets on bettrans which have bettypes on bettransRnG/LC with winlostdate >= yesterday
			DELETE t
			FROM #tempData t
			WHERE EXISTS (
				SELECT 1 FROM dbo.SportBettypeMatrix s WITH (NOLOCK)
				WHERE t.bettype = s.bettype AND s.RefTable IN (1,2)
			)
				AND t.winlostdate >= @yesterday

			-- Don't get OutStanding amount on bettrans which have bettypes on translog, bettransRnG/LC
			DELETE t
			FROM #tempData t
			WHERE EXISTS (
				SELECT 1 FROM dbo.SportBettypeMatrix s WITH (NOLOCK)
				WHERE t.bettype = s.bettype AND s.RefTable IN (1,2,3)
			)
				AND t.statusId IN (0,1)

			-- Yesterday balance include today transfer tickets
			UPDATE #tempData
			SET winlostdate = @yesterday
			WHERE bettype > 20000 AND winlostdate > @yesterday

			-- bettransRnG
			INSERT INTO #tempData
			(
				winlostdate, statusId, custid, recommend,
				winlost, actual_stake, playercomm,
				awinlost, comm,
				mwinlost, acomm
			)
			SELECT
				b.winlostdate, b.statusId, b.custid, b.recommend,
				SUM(b.winlost), SUM(b.actual_stake), SUM(b.playercomm),
				SUM(b.awinlost), SUM(b.comm),
				SUM(b.mwinlost), SUM(b.acomm)
			FROM dbo.bettransRnG b WITH (NOLOCK)
				INNER JOIN @tblrecommend r ON b.recommend = r.recommend
			WHERE (b.winlostdate >= @yesterday OR statusId IN (0,1))
			GROUP BY
				b.winlostdate, b.statusId, b.custid, b.recommend

			-- bettransLC
			INSERT INTO #tempData
			(
				winlostdate, statusId, custid, recommend,
				winlost, actual_stake, playercomm,
				awinlost, comm,
				mwinlost, acomm
			)
			SELECT
				b.winlostdate, b.statusId, b.custid, b.recommend,
				SUM(b.winlost), SUM(b.actual_stake), SUM(b.playercomm),
				SUM(b.awinlost), SUM(b.comm),
				SUM(b.mwinlost), SUM(b.acomm)
			FROM dbo.bettransLC b WITH (NOLOCK)
				INNER JOIN @tblrecommend r ON b.recommend = r.recommend
			WHERE (b.winlostdate >= @yesterday OR statusId IN (0,1))
			GROUP BY
				b.winlostdate, b.statusId, b.custid, b.recommend

			-- translog
			INSERT INTO #tempData
			(
				statusId, custid, recommend,
				actual_stake
			)
			SELECT
				0 AS statusId, t.custid, t.recommend,
				SUM(t.actual_stake)
			FROM dbo.translog t WITH (NOLOCK)
				INNER JOIN @tblrecommend r ON t.recommend = r.recommend
			WHERE t.statusId IN (0,1)
			GROUP BY t.custid, t.recommend
		END
	END

	DECLARE @IsTotalTransfer BIT = 0
	IF ',' + @SuperIDsTransferTotal + ',' LIKE '%,' + CONVERT(VARCHAR(20), @srecommend) + ',%'
		SELECT @IsTotalTransfer = 1

	-- Back to check rule before transfer
	-- 3. Nagative bet credit after transfer
	CREATE TABLE #NetPosition (custid INT, netPosition MONEY)

	INSERT INTO #NetPosition (custId, netPosition)
	EXEC dbo.Age_GetCustomerNetPosition
		@CustId = @DownlineCustId,
		@RoleId = @DownlineRoleId

	CREATE TABLE #MemberNagativeBetCredit (custId INT)

	;WITH cte_member AS
	(
		SELECT custId,
			SUM(CASE WHEN statusId IN (0,1) THEN -ISNULL(actual_stake, 0) ELSE ISNULL(winlost - actual_stake + playercomm, 0) END
				- CASE WHEN statusId NOT IN (0,1) AND (@IsTotalTransfer = 1 OR winlostdate <= @yesterday) THEN ISNULL(winlost - actual_stake + playercomm, 0) ELSE 0 END)
				AS amountAfterTransfer
		FROM #tempData
		GROUP BY custId
	)
	INSERT INTO #MemberNagativeBetCredit (custid)
	SELECT m.custid
	FROM cte_member m
		INNER JOIN DBCUST.CustDB.dbo.custInfo c WITH (NOLOCK) ON m.custId = c.custId -- get credit amount real time
		LEFT JOIN #NetPosition np ON m.custid = np.custid
	WHERE c.roleId = 1 AND ISNULL(c.credit, 0) + m.amountAfterTransfer + ISNULL(np.netPosition, 0) < 0

	IF @@ROWCOUNT <> 0
	BEGIN
		INSERT INTO @ErrTable (Id, Content)
		SELECT 3, dbo.f_Get_MsgNamebyMsgID(50012, @Language)
	END

	DROP TABLE #MemberNagativeBetCredit

	IF EXISTS (SELECT 1 FROM @ErrTable)
	BEGIN
		SELECT @ErrCode = 200
		SELECT @IsErr = 1
	END

	-- Calculate transfer amount
	CREATE TABLE #Member (custid INT PRIMARY KEY, recommend INT, mrecommend INT, srecommend INT, memberName VARCHAR(50), agentName VARCHAR(50), memberBalance MONEY DEFAULT 0)
	CREATE TABLE #Agent  (recommend	INT PRIMARY KEY, mrecommend INT, srecommend INT, agentName VARCHAR(50), masterName VARCHAR(50), agentBalance MONEY DEFAULT 0)
	CREATE TABLE #SkippedMember (custid INT PRIMARY KEY, recommend INT, mrecommend INT, srecommend INT)

	DECLARE @TransferredMember MONEY = 0, @TransferredAgent MONEY = 0

	IF @IsErr = 0
	BEGIN
		-- Member
		;WITH cte_member AS
		(
			SELECT custId, SUM(ISNULL(winlost - actual_stake + playercomm, 0)) AS memberBalance
			FROM #tempData
			WHERE statusId NOT IN (0,1)
				AND (@IsTotalTransfer = 1 OR winlostdate <= @yesterday)
			GROUP BY custId
			HAVING SUM(ISNULL(winlost - actual_stake + playercomm, 0)) <> 0
		)
		INSERT INTO #Member (custid, recommend, mrecommend, srecommend, memberName, agentName, memberBalance)
		SELECT c.custid, c.recommend, c.mrecommend, c.srecommend, c.username, r.username, m.memberBalance
		FROM cte_member m
			INNER JOIN CustDB.dbo.custInfo c WITH (NOLOCK) ON m.custId = c.custId
			INNER JOIN @tblrecommend r ON c.recommend = r.recommend
		WHERE c.roleId = 1

		-- Agent
		IF @RoleId = 4
		BEGIN
			;WITH cte_agent AS
			(
				SELECT recommend, SUM(ISNULL(winlost-actual_stake+awinlost+comm, 0)) AS agentBalance
				FROM #tempData
				WHERE statusId NOT IN (0,1)
					AND (@IsTotalTransfer = 1 OR winlostdate <= @yesterday)
				GROUP BY recommend
				HAVING SUM(ISNULL(winlost-actual_stake+awinlost+comm, 0)) <> 0
			)
			INSERT INTO #Agent (recommend, mrecommend, srecommend, agentName, masterName, agentBalance)
			SELECT r.recommend, @DownlineCustId, @srecommend, r.username, @DownlineUsername, a.agentBalance
			FROM cte_agent a
				INNER JOIN @tblrecommend r ON a.recommend = r.recommend
		END
		ELSE IF @RoleId = 3
		BEGIN
			INSERT INTO #Agent (recommend, mrecommend, srecommend, agentName, masterName, agentBalance)
			SELECT @DownlineCustId, @CustId, @srecommend, @DownlineUsername, @username, SUM(ISNULL(winlost-actual_stake+awinlost+comm, 0))
			FROM #tempData
			WHERE statusId NOT IN (0,1)
				AND (@IsTotalTransfer = 1 OR winlostdate <= @yesterday)
			HAVING SUM(ISNULL(winlost-actual_stake+awinlost+comm, 0)) <> 0
		END

		-- Master
		IF @RoleId = 4
		BEGIN
			SELECT @masterBalance = SUM(ISNULL(winlost-actual_stake+mwinlost+awinlost+acomm, 0))
			FROM #tempData
			WHERE statusId NOT IN (0,1)
				AND (@IsTotalTransfer = 1 OR winlostdate <= @yesterday)

			SELECT @masterBalance = ISNULL(@masterBalance, 0)
		END
	END

	DECLARE @memberOutStanding MONEY
	SELECT  @memberOutStanding = SUM(actual_stake) FROM #tempData WHERE statusId IN (0,1)

	DROP TABLE #tempData

	-- Transfer process
	DECLARE @Now SMALLDATETIME
	SELECT  @Now = GETDATE()

	DECLARE @count INT, @batch INT
	SELECT  @count = 0, @batch = 500

	DECLARE @LogData NVARCHAR(1000)

	DECLARE @SubAccName VARCHAR(50)

	IF @SubAccID > 0
	BEGIN
		SELECT @SubAccName = username
		FROM DBCUST.CustDB.dbo.custSub WITH(NOLOCK) 
		WHERE SubAccID = @SubAccID
	END

	IF @IsErr = 0
	BEGIN
		-- same error message when insert failed
		SELECT  @ErrMsg = 'Transfer all unsuccessfully. Please try again.'

		DECLARE @memberId INT, @agentId INT, @masterId INT, @superId INT,
				@memberName VARCHAR(50), @agentName VARCHAR(50), @masterName VARCHAR(50), @superName VARCHAR(50),
				@memberBalance MONEY, @agentBalance MONEY, @ABSmemberBalance MONEY

		DECLARE @isResetYesterdayBalance BIT, @ErrCode_ResetYesterdayBalance BIT, @YesterdayBalance MONEY

		DECLARE @refno BIGINT, @grefno INT

		/*
			============================== Start Member - Agent ==============================
		*/
		DECLARE CS_member CURSOR FAST_FORWARD
			FOR SELECT custid, recommend, mrecommend, srecommend, memberName, agentName, memberBalance FROM #Member

		OPEN CS_member

		FETCH NEXT FROM CS_member
			INTO @memberId, @agentId, @masterId, @superId, @memberName, @agentName, @memberBalance

		WHILE @@FETCH_STATUS = 0
		BEGIN
			UPDATE dbo.ref WITH (ROWLOCK, UPDLOCK)
			SET @grefno = transcode = transcode + 1
			WHERE refid = 'acc'

			IF @@ERROR <> 0
			BEGIN
				SELECT @ErrCode = 114
				RETURN
			END

			SELECT @refno = 200000000000 + @grefno

			IF @IsAllDayTransfer = 0
				AND EXISTS (
					SELECT 1
					FROM dbo.bettrans WITH (NOLOCK)
					WHERE custid = @memberId
						AND matchid = 0
						AND bettype IN (21003, 21004)
						AND transdate BETWEEN CONVERT(VARCHAR(10), CURRENT_TIMESTAMP, 120) AND CONVERT(VARCHAR(10), CURRENT_TIMESTAMP, 120) + ' 23:59:59'
				)
			BEGIN
				INSERT INTO #SkippedMember (custid, recommend, mrecommend, srecommend)
				VALUES (@memberId, @agentId, @masterId, @superId)
			END
			ELSE IF @memberBalance > 0
			BEGIN
				-- for agent
				DECLARE @TotalCashAg MONEY 
				EXEC Acc_CustomerSelCash_CaptureBalance @custid = @agentId, @TotalCash  = @TotalCashAg OUTPUT

				INSERT INTO dbo.bettrans (matchid, creator, custid, username, refno, transdate, bettype, transdesc, winlost, actual_stake, status, ruben, winlostdate, currency, actualrate, currencyName, recommend, mrecommend, srecommend, scomm, swinlost, ip, statusID, balance)
				VALUES (0, @UserID, @agentId, @agentName, @refno, @Now, 21004, 'From Customer::' + @memberName + CASE WHEN @SubAccID > 0 THEN ' (By ' + @SubAccName + ')' ELSE '' END, 
						@memberBalance, 0, 'Completed', 1, CONVERT(NVARCHAR(10), @Now, 120), @currency, @actualrate, @currencyName, @agentId, @masterId, @superId, 0, 0, @IP, 131, @TotalCashAg)

				IF @@ERROR <> 0
				BEGIN
					-- rollback
					DELETE dbo.bettrans WITH (ROWLOCK, UPDLOCK)
					WHERE custid IN (@agentId, @memberId)
						AND matchid = 0
						AND bettype IN (21003, 21004)
						AND refno = @refno

					SELECT @ErrCode = 101

					RETURN
				END

				-- update debit balance
				EXEC Dot_BalanceDebitUpd @CustID = @memberId, @balance = @memberBalance, @Type = 2, @IsForced = 1, @ErrCode = @ErrCode OUTPUT
					
				IF @ErrCode <> 0
				BEGIN
					-- rollback
					DELETE dbo.bettrans WITH (ROWLOCK, UPDLOCK)
					WHERE custid IN (@agentId, @memberId)
						AND matchid = 0
						AND bettype IN (21003, 21004)
						AND refno = @refno

					SELECT @ErrCode = 102

					RETURN
				END

				-- for member
				DECLARE @TotalCashMem MONEY 
				EXEC Acc_CustomerSelCash_CaptureBalance @custid = @memberId, @TotalCash  = @TotalCashMem OUTPUT

				INSERT INTO dbo.bettrans (matchid, creator, custid, username, refno, transdate, bettype, transdesc, winlost, actual_stake, status, ruben, winlostdate, currency, actualrate, currencyName, recommend, mrecommend, srecommend, scomm, swinlost, ip, statusID, balance)
				VALUES (0, @UserID, @memberId, @memberName, @refno, @Now, 21004, 'To Customer::' + @agentName + CASE WHEN @SubAccID > 0 THEN ' (By ' + @SubAccName + ')' ELSE '' END, 0, 
						@memberBalance, 'Completed', 1, CONVERT(NVARCHAR(10), @Now, 120), @currency, @actualrate, @currencyName, @agentId, @masterId, @superId, 0, 0, @IP, 131, @TotalCashMem)

				IF @@ERROR <> 0
				BEGIN
					-- rollback
					DELETE dbo.bettrans WITH (ROWLOCK, UPDLOCK)
					WHERE custid IN (@agentId, @memberId)
						AND matchid = 0
						AND bettype IN (21003, 21004)
						AND refno = @refno

					SELECT @ErrCode = 101

					-- rollback balance  
					EXEC Dot_BalanceCreditUpd @CustID = @memberId, @balance = @memberBalance, @Type = 2
						
					RETURN
				END

				-- log data
				SELECT @LogData = 'Transfer all:'
									+ ' Transfer from Member ' + @memberName + ' to Agent ' + @agentName + ' with amount ' + CONVERT(VARCHAR(20), @memberBalance)
									+ ' Ref.No ' + CONVERT(VARCHAR(20), @refno)

				-- Reset yesterday balance for games
				EXEC Acc_BalanceGameResetYesterday
					@CustID						= @memberId,
					@isResetYesterdayBalance	= @isResetYesterdayBalance OUTPUT,
					@YesterdayBalance			= @YesterdayBalance OUTPUT,
					@ErrCode					= @ErrCode_ResetYesterdayBalance OUTPUT

				-- for log
				SELECT @LogData = @LogData
								+ CASE WHEN @isResetYesterdayBalance = 1 THEN
										CASE WHEN @ErrCode_ResetYesterdayBalance = 0 THEN '. (ResetBalanceGame = suscess, YesterdayBalance =' + CAST(@YesterdayBalance AS VARCHAR(50)) + ')'
										ELSE '. (ResetBalanceGame = fail)' END
									ELSE '' END

				-- write log
				IF @SubAccID > 0
					SELECT @LogData = 'SubAccount:' + COALESCE(@SubAccName, SPACE(1)) + ' - ' + @LogData

				BEGIN TRY
					EXEC DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_Transfer
						@UserID		= @UserID,
						@FromCustID = @memberId,
						@ToCustID	= @agentId,
						@IP			= @IP,
						@Doing		= @LogData
				END TRY
				BEGIN CATCH
					SELECT @LogData = @LogData + ' ErrMsg=' + ERROR_MESSAGE()

					EXEC bodb_CustomerLog.dbo.WriteLog_UserLog_Transfer
						@UserID		= @UserID,
						@FromCustID = @memberId,
						@ToCustID	= @agentId,
						@IP			= @IP,
						@Doing		= @LogData
				END CATCH

				SELECT @TransferredMember = @TransferredMember + @memberBalance

				SET @count = @count + 1

				IF @count % @batch = 0
					WAITFOR DELAY '000:00:00.280'
			END
			ELSE IF @memberBalance < 0
			BEGIN
				-- for agent

				DECLARE @TotalCashAgNev MONEY 
				EXEC Acc_CustomerSelCash_CaptureBalance @custid = @agentId, @TotalCash  = @TotalCashAgNev OUTPUT

				INSERT INTO dbo.bettrans (matchid, creator, custid, username, refno, transdate, bettype, transdesc, winlost, actual_stake, status, ruben, winlostdate, currency, actualrate, currencyName, recommend, mrecommend, srecommend, scomm, swinlost, ip, statusID, balance)
				VALUES (0, @UserID, @agentId, @agentName, @refno, CURRENT_TIMESTAMP, 21004, 'To Customer::' + @memberName + CASE WHEN @SubAccID > 0 THEN ' (By ' + @SubAccName + ')' ELSE '' END, 0, 
						ABS(@memberBalance), 'Completed', 1, CONVERT(NVARCHAR(10), @Now, 120), @currency, @actualrate, @currencyName, @agentId, @masterId, @superId, 0, 0, @IP, 131, @TotalCashAgNev)

				IF @@ERROR <> 0
				BEGIN
					-- rollback
					DELETE dbo.bettrans WITH (ROWLOCK, UPDLOCK)
					WHERE custid IN (@agentId, @memberId)
						AND matchid = 0
						AND bettype IN (21003, 21004)
						AND refno = @refno

					SELECT @ErrCode = 103

					RETURN
				END

				-- for member
				DECLARE @TotalCashMemNev MONEY 
				EXEC Acc_CustomerSelCash_CaptureBalance @custid = @memberId, @TotalCash  = @TotalCashMemNev OUTPUT

				INSERT INTO dbo.bettrans (matchid, creator, custid, username, refno, transdate, bettype, transdesc, winlost, actual_stake, status, ruben, winlostdate, currency, actualrate, currencyName, recommend, mrecommend, srecommend, scomm, swinlost, ip, statusID, balance)
				VALUES (0, @UserID, @memberId, @memberName, @refno, CURRENT_TIMESTAMP, 21004, 'From Customer::' + @agentName + CASE WHEN @SubAccID > 0 THEN ' (By ' + @SubAccName + ')' ELSE '' END, 
						ABS(@memberBalance), 0, 'Completed', 1, CONVERT(NVARCHAR(10), @Now, 120), @currency, @actualrate, @currencyName, @agentId, @masterId, @superId, 0, 0, @IP, 131, @TotalCashMemNev)

				IF @@ERROR <> 0
				BEGIN
					-- rollback
					DELETE dbo.bettrans WITH (ROWLOCK, UPDLOCK)
					WHERE custid IN (@agentId, @memberId)
						AND matchid = 0
						AND bettype IN (21003, 21004)
						AND refno = @refno

					SELECT @ErrCode = 104

					RETURN
				END

				---update credit balance  
				SELECT @ABSmemberBalance = ABS(@memberBalance)

				EXEC Dot_BalanceCreditUpd @CustID = @memberId, @balance = @ABSmemberBalance, @Type = 2

				-- log data
				SELECT @LogData = 'Transfer all:'
									+ ' Transfer from Agent ' + @agentName + ' to Member ' + @memberName + ' with amount ' + CONVERT(VARCHAR(20), @memberBalance)
									+ ' Ref.No ' + CONVERT(VARCHAR(20), @refno)

				-- Reset yesterday balance for games
				EXEC Acc_BalanceGameResetYesterday
					@CustID						= @memberId,
					@isResetYesterdayBalance	= @isResetYesterdayBalance OUTPUT,
					@YesterdayBalance			= @YesterdayBalance OUTPUT,
					@ErrCode					= @ErrCode_ResetYesterdayBalance OUTPUT

				-- for log
				SELECT @LogData = @LogData
								+ CASE WHEN @isResetYesterdayBalance = 1 THEN
										CASE WHEN @ErrCode_ResetYesterdayBalance = 0 THEN '. (ResetBalanceGame = suscess, YesterdayBalance =' + CAST(@YesterdayBalance AS VARCHAR(50)) + ')'
										ELSE '. (ResetBalanceGame = fail)' END
									ELSE '' END

				-- write log
				IF @SubAccID > 0
					SELECT @LogData = 'SubAccount:' + COALESCE(@SubAccName, SPACE(1)) + ' - ' + @LogData

				BEGIN TRY
					EXEC DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_Transfer
						@UserID		= @UserID,
						@FromCustID = @agentId,
						@ToCustID	= @memberId,
						@IP			= @IP,
						@Doing		= @LogData
				END TRY
				BEGIN CATCH
					SELECT @LogData = @LogData + ' ErrMsg=' + ERROR_MESSAGE()

					EXEC bodb_CustomerLog.dbo.WriteLog_UserLog_Transfer
						@UserID		= @UserID,
						@FromCustID = @agentId,
						@ToCustID	= @memberId,
						@IP			= @IP,
						@Doing		= @LogData
				END CATCH

				SELECT @TransferredMember = @TransferredMember + @memberBalance

				SET @count = @count + 1

				IF @count % @batch = 0
					WAITFOR DELAY '000:00:00.280'
			END

			FETCH NEXT FROM CS_member
				INTO @memberId, @agentId, @masterId, @superId, @memberName, @agentName, @memberBalance
		END

		CLOSE CS_member

		DEALLOCATE CS_member

		DROP TABLE #Member

		/*
			============================== End Member - Agent ==============================
		*/

		-- If exists transfered members, skip transfer upline
		IF EXISTS (SELECT 1 FROM #SkippedMember)
		BEGIN
			IF @RoleId = 3
				RETURN
			
			DELETE #Agent
			WHERE recommend IN (SELECT recommend FROM #SkippedMember)
			
			SET @masterBalance = 0
		END

		DROP TABLE #SkippedMember

		/*
			============================== Start Agent - Master ==============================
		*/
		DECLARE CS_agent CURSOR
			FOR SELECT recommend, mrecommend, srecommend, agentname, mastername, agentBalance
		FROM #Agent

		OPEN CS_agent

		FETCH NEXT FROM CS_agent
			INTO @agentId, @masterId, @superId, @agentName, @masterName, @agentBalance

		WHILE @@FETCH_STATUS = 0
		BEGIN
			UPDATE dbo.ref WITH (ROWLOCK, UPDLOCK)
			SET @grefno = transcode = transcode + 1
			WHERE refid = 'acc'

			IF @@ERROR <> 0
			BEGIN
				SELECT @ErrCode = 115
				RETURN
			END

			SELECT @refno = 200000000000 + @grefno

			IF @agentBalance > 0
			BEGIN
				-- for master

				DECLARE @TotalCashMAg MONEY 
				EXEC Acc_CustomerSelCash_CaptureBalance @custid = @masterId, @TotalCash  = @TotalCashMAg OUTPUT

				INSERT INTO dbo.bettrans (matchid, creator, custid, username, refno, transdate, bettype, transdesc, winlost, actual_stake, status, ruben, winlostdate, currency, actualrate, currencyName, recommend, mrecommend, srecommend, scomm, swinlost, ip, statusID, balance)
				VALUES (0, @UserID, @masterId, @masterName, @refno, @Now, 21003, 'From Customer::' + @agentName + CASE WHEN @SubAccID > 0 THEN ' (By ' + @SubAccName + ')' ELSE '' END, 
						@agentBalance, 0, 'Completed', 1, CONVERT(NVARCHAR(10), @Now, 120), @currency, @actualrate, @currencyName, 0, @masterId, @superId, 0, 0, @IP, 131, @TotalCashMAg)

				IF @@ERROR <> 0
				BEGIN
					DELETE dbo.bettrans WITH (ROWLOCK, UPDLOCK)
					WHERE custid IN (@masterId, @agentId)
						AND matchid = 0
						AND bettype IN (21003, 21004)
						AND refno = @refno

					SELECT @ErrCode = 105

					RETURN
				END

				-- for agent

				DECLARE @TotalCashAgPov MONEY 
				EXEC Acc_CustomerSelCash_CaptureBalance @custid = @agentId, @TotalCash  = @TotalCashAgPov OUTPUT

				INSERT INTO dbo.bettrans (matchid, creator, custid, username, refno, transdate, bettype, transdesc, winlost, actual_stake, status, ruben, winlostdate, currency, actualrate, currencyName, recommend, mrecommend, srecommend, scomm, swinlost, ip, statusID, balance)
				VALUES (0, @UserID, @agentId, @agentName, @refno, @Now, 21003, 'To Customer::' + @masterName + CASE WHEN @SubAccID > 0 THEN ' (By ' + @SubAccName + ')' ELSE '' END, 0, 
						@agentBalance, 'Completed', 1, CONVERT(NVARCHAR(10), @Now, 120), @currency, @actualrate, @currencyName, @agentId, @masterId, @superId, 0, 0, @IP, 131, @TotalCashAgPov)

				IF @@ERROR <> 0
				BEGIN
					-- rollback
					DELETE dbo.bettrans WITH (ROWLOCK, UPDLOCK)
					WHERE custid IN (@masterId, @agentId)
						AND matchid = 0
						AND bettype IN (21003, 21004)
						AND refno = @refno

					SELECT @ErrCode = 106

					RETURN
				END

				-- for log
				SELECT @LogData = 'Transfer all:'
								+ ' Transfer from Agent ' + @agentName + ' to Master ' + @masterName + ' with amount ' + CONVERT(VARCHAR(20), @agentBalance)
								+ ' Ref.No ' + CONVERT(VARCHAR(20), @refno)

				-- write log
				IF @SubAccID > 0
					SELECT @LogData = 'SubAccount:' + COALESCE(@SubAccName, SPACE(1)) + ' - ' + @LogData

				BEGIN TRY
					EXEC DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_Transfer
						@UserID		= @UserID,
						@FromCustID = @agentId,
						@ToCustID	= @masterId,
						@IP			= @IP,
						@Doing		= @LogData
				END TRY
				BEGIN CATCH
					SELECT @LogData = @LogData + ' ErrMsg=' + ERROR_MESSAGE()

					EXEC bodb_CustomerLog.dbo.WriteLog_UserLog_Transfer
						@UserID		= @UserID,
						@FromCustID = @agentId,
						@ToCustID	= @masterId,
						@IP			= @IP,
						@Doing		= @LogData
				END CATCH

				SET @count = @count + 1

				IF @count % @batch = 0
					WAITFOR DELAY '000:00:00.280'
			END
			ELSE IF @agentBalance < 0
			BEGIN
				-- for master

				DECLARE @TotalCashMAgNev MONEY 
				EXEC Acc_CustomerSelCash_CaptureBalance @custid = @masterId, @TotalCash  = @TotalCashMAgNev OUTPUT

				INSERT INTO dbo.bettrans (matchid, creator, custid, username, refno, transdate, bettype, transdesc, winlost, actual_stake, status, ruben, winlostdate, currency, actualrate, currencyName, recommend, mrecommend, srecommend, scomm, swinlost, ip, statusID, balance)
				VALUES (0, @UserID, @masterId, @masterName, @refno, @Now, 21003, 'To Customer::' + @agentName + CASE WHEN @SubAccID > 0 THEN ' (By ' + @SubAccName + ')' ELSE '' END, 0, 
						ABS(@agentBalance), 'Completed', 1, CONVERT(NVARCHAR(10), @Now, 120), @currency, @actualrate, @currencyName, 0, @masterId, @superId, 0, 0, @IP, 131, @TotalCashMAgNev)

				IF @@ERROR <> 0
				BEGIN
					-- rollback
					DELETE dbo.bettrans WITH (ROWLOCK, UPDLOCK)
					WHERE custid IN (@masterId, @agentId)
						AND matchid = 0
						AND bettype IN (21003, 21004)
						AND refno = @refno

					SELECT @ErrCode = 107

					RETURN
				END

				-- for agent
				DECLARE @TotalCashAgNegative MONEY 
				EXEC Acc_CustomerSelCash_CaptureBalance @custid = @agentId, @TotalCash  = @TotalCashAgNegative OUTPUT

				INSERT INTO dbo.bettrans (matchid, creator, custid, username, refno, transdate, bettype, transdesc, winlost, actual_stake, status, ruben, winlostdate, currency, actualrate, currencyName, recommend, mrecommend, srecommend, scomm, swinlost, ip, statusID, balance)
				VALUES (0, @UserID, @agentId, @agentName, @refno, @Now, 21003, 'From Customer::' + @masterName + CASE WHEN @SubAccID > 0 THEN ' (By ' + @SubAccName + ')' ELSE '' END, 
						ABS(@agentBalance), 0, 'Completed', 1, CONVERT(NVARCHAR(10), @Now, 120), @currency, @actualrate, @currencyName, @agentId, @masterId, @superId, 0, 0, @IP, 131,@TotalCashAgNegative)

				IF @@ERROR <> 0
				BEGIN
					-- rollback
					DELETE dbo.bettrans WITH (ROWLOCK, UPDLOCK)
					WHERE custid IN (@masterId, @agentId)
						AND matchid = 0
						AND bettype IN (21003, 21004)
						AND refno = @refno

					SELECT @ErrCode = 108

					RETURN
				END


				-- for log
				SELECT @LogData = 'Transfer all:'
								+ ' Transfer from Master ' + @masterName + ' to Agent ' + @agentName + ' with amount ' + CONVERT(VARCHAR(20), @agentBalance)
								+ ' Ref.No ' + CONVERT(VARCHAR(20), @refno)

				-- write log
				IF @SubAccID > 0
					SELECT @LogData = 'SubAccount:' + COALESCE(@SubAccName, SPACE(1)) + ' - ' + @LogData

				BEGIN TRY
					EXEC DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_Transfer
						@UserID		= @UserID,
						@FromCustID = @masterId,
						@ToCustID	= @agentId,
						@IP			= @IP,
						@Doing		= @LogData
				END TRY
				BEGIN CATCH
					SELECT @LogData = @LogData + ' ErrMsg=' + ERROR_MESSAGE()

					EXEC bodb_CustomerLog.dbo.WriteLog_UserLog_Transfer
						@UserID		= @UserID,
						@FromCustID = @masterId,
						@ToCustID	= @agentId,
						@IP			= @IP,
						@Doing		= @LogData
				END CATCH

				SET @count = @count + 1

				IF @count % @batch = 0
					WAITFOR DELAY '000:00:00.280'
			END

			SELECT @TransferredAgent = @TransferredAgent + @agentBalance

			FETCH NEXT FROM CS_agent
				INTO @agentId, @masterId, @superId, @agentName, @masterName, @agentBalance
		END

		CLOSE CS_agent

		DEALLOCATE CS_agent

		DROP TABLE #Agent

		/*
			============================== End Agent - Master ==============================
		*/

		/*
			============================== Start Master - Super ==============================
		*/
		IF @RoleId = 4 AND ISNULL(@masterBalance, 0) <> 0
		BEGIN
			SELECT @superId = @CustId, @superName = @username, @masterId = @DownlineCustId, @masterName = @DownlineUsername
			
			UPDATE dbo.ref WITH (ROWLOCK, UPDLOCK)
			SET @grefno = transcode = transcode + 1
			WHERE refid = 'acc'

			IF @@ERROR <> 0
			BEGIN
				SELECT @ErrCode = 116

				RETURN
			END

			SELECT @refno = 200000000000 + @grefno

			IF @masterBalance > 0
			BEGIN
				-- for super
				DECLARE @TotalCashSAg MONEY 
				EXEC Acc_CustomerSelCash_CaptureBalance @custid = @superId, @TotalCash  = @TotalCashSAg OUTPUT

				INSERT INTO dbo.bettrans (matchid, creator, custid, username, refno, transdate, bettype, transdesc, winlost, actual_stake, status, ruben, winlostdate, currency, actualrate, currencyName, mrecommend, srecommend, scomm, swinlost, recommend, ip, statusID, balance)
				VALUES (0, @UserID, @superId, @superName, @refno, @Now, 21003, 'From Customer::' + @masterName + CASE WHEN @SubAccID > 0 THEN ' (By ' + @SubAccName + ')' ELSE '' END, 
						@masterBalance, 0, 'Completed', 1, CONVERT(NVARCHAR(10), @Now, 120), @currency, @actualrate, @currencyName, 0, @superId, 0, 0, 0, @ip, 131, @TotalCashSAg)

				IF @@ERROR <> 0
				BEGIN
					-- rollback
					DELETE dbo.bettrans WITH (ROWLOCK, UPDLOCK)
					WHERE custid IN (@superId, @masterId)
						AND matchid = 0
						AND bettype IN (21003, 21004)
						AND refno = @refno

					SELECT @ErrCode = 109

					RETURN
				END

				-- for master
				DECLARE @TotalCashMAgPov MONEY 
				EXEC Acc_CustomerSelCash_CaptureBalance @custid = @masterId, @TotalCash  = @TotalCashMAgPov OUTPUT

				INSERT INTO dbo.bettrans (matchid, creator, custid, username, refno, transdate, bettype, transdesc, winlost, actual_stake, status, ruben, winlostdate, currency, actualrate, currencyName, mrecommend, srecommend, scomm, swinlost, recommend, ip, statusID, balance)
				VALUES (0, @UserID, @masterId, @masterName, @refno, @Now, 21003, 'To Customer::' + @superName + CASE WHEN @SubAccID > 0 THEN ' (By ' + @SubAccName + ')' ELSE '' END, 0, 
						@masterBalance, 'Completed', 1, CONVERT(NVARCHAR(10), @Now, 120), @currency, @actualrate, @currencyName, @masterId, @superId, 0, 0, 0, @ip, 131, @TotalCashMAgPov)

				IF @@ERROR <> 0
				BEGIN
					-- rollback
					DELETE dbo.bettrans WITH (ROWLOCK, UPDLOCK)
					WHERE custid IN (@superId, @masterId)
						AND matchid = 0
						AND bettype IN (21003, 21004)
						AND refno = @refno

					SELECT @ErrCode = 110

					RETURN
				END

				-- for log
				SELECT @LogData = 'Transfer all:'
								+ ' Transfer from Master ' + @masterName + ' to Super ' + @superName + ' with amount ' + CONVERT(VARCHAR(20), @masterBalance)
								+ ' Ref.No ' + CONVERT(VARCHAR(20), @refno)

				-- write log
				IF @SubAccID > 0
					SELECT @LogData = 'SubAccount:' + COALESCE(@SubAccName, SPACE(1)) + ' - ' + @LogData

				BEGIN TRY
					EXEC DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_Transfer
						@UserID		= @UserID,
						@FromCustID = @masterId,
						@ToCustID	= @superId,
						@IP			= @IP,
						@Doing		= @LogData
				END TRY
				BEGIN CATCH
					SELECT @LogData = @LogData + ' ErrMsg=' + ERROR_MESSAGE()

					EXEC bodb_CustomerLog.dbo.WriteLog_UserLog_Transfer
						@UserID		= @UserID,
						@FromCustID = @masterId,
						@ToCustID	= @superId,
						@IP			= @IP,
						@Doing		= @LogData
				END CATCH

				SET @count = @count + 1

				IF @count % @batch = 0
					WAITFOR DELAY '000:00:00.280'
			END
			ELSE IF @masterBalance < 0
			BEGIN
				-- for super
				DECLARE @TotalCashSAgNev MONEY 
				EXEC Acc_CustomerSelCash_CaptureBalance @custid = @superId, @TotalCash  = @TotalCashSAgNev OUTPUT

				INSERT INTO dbo.bettrans (matchid, creator, custid, username, refno, transdate, bettype, transdesc, winlost, actual_stake, status, ruben, winlostdate, currency, actualrate, currencyName, mrecommend, srecommend, scomm, swinlost, recommend, ip, statusID, balance)
				VALUES (0, @UserID, @superId, @superName, @refno, @Now, 21003, 'To Customer::' + @masterName + CASE WHEN @SubAccID > 0 THEN ' (By ' + @SubAccName + ')' ELSE '' END, 0, 
						ABS(@masterBalance), 'Completed', 1, CONVERT(NVARCHAR(10), @Now, 120), @currency, @actualrate, @currencyName, 0, @superId, 0, 0, 0, @ip, 131, @TotalCashSAgNev)

				IF @@ERROR <> 0
				BEGIN
					-- rollback
					DELETE dbo.bettrans WITH (ROWLOCK, UPDLOCK)
					WHERE custid IN (@superId, @masterId)
						AND matchid = 0
						AND bettype IN (21003, 21004)
						AND refno = @refno

					SELECT @ErrCode = 111

					RETURN
				END

				-- for master
				DECLARE @TotalCashMAgNegative MONEY 
				EXEC Acc_CustomerSelCash_CaptureBalance @custid = @masterId, @TotalCash  = @TotalCashMAgNegative OUTPUT

				INSERT INTO dbo.bettrans (matchid, creator, custid, username, refno, transdate, bettype, transdesc, winlost, actual_stake, status, ruben, winlostdate, currency, actualrate, currencyName, mrecommend, srecommend, scomm, swinlost, recommend, ip, statusID, balance)
				VALUES (0, @UserID, @masterId, @masterName, @refno, CURRENT_TIMESTAMP, 21003, 'From Customer::' + @superName + CASE WHEN @SubAccID > 0 THEN ' (By ' + @SubAccName + ')' ELSE '' END, 
						ABS(@masterBalance), 0, 'Completed', 1, CONVERT(NVARCHAR(10), @Now, 120), @currency, @actualrate, @currencyName, @masterId, @superId, 0, 0, 0, @ip, 131, @TotalCashMAgNegative)

				IF @@ERROR <> 0
				BEGIN
					-- rollback
					DELETE dbo.bettrans WITH (ROWLOCK, UPDLOCK)
					WHERE custid IN (@superId, @masterId)
						AND matchid = 0
						AND bettype IN (21003, 21004)
						AND refno = @refno

					SELECT @ErrCode = 112

					RETURN
				END

				-- for log
				SELECT @LogData = 'Transfer all:'
								+ ' Transfer from Super ' + @superName + ' to Master ' + @masterName + ' with amount ' + CONVERT(VARCHAR(20), @masterBalance)
								+ ' Ref.No ' + CONVERT(VARCHAR(20), @refno)

				-- write log
				IF @SubAccID > 0
					SELECT @LogData = 'SubAccount:' + COALESCE(@SubAccName, SPACE(1)) + ' - ' + @LogData

				BEGIN TRY
					EXEC DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_Transfer
						@UserID		= @UserID,
						@FromCustID = @superId,
						@ToCustID	= @masterId,
						@IP			= @IP,
						@Doing		= @LogData
				END TRY
				BEGIN CATCH
					SELECT @LogData = @LogData + ' ErrMsg=' + ERROR_MESSAGE()

					EXEC bodb_CustomerLog.dbo.WriteLog_UserLog_Transfer
						@UserID		= @UserID,
						@FromCustID = @superId,
						@ToCustID	= @masterId,
						@IP			= @IP,
						@Doing		= @LogData
				END CATCH

				SET @count = @count + 1

				IF @count % @batch = 0
					WAITFOR DELAY '000:00:00.280'
			END
		END

		/*
			============================== End Master - Super ==============================
		*/

		SELECT @ErrMsg = ''

		-- Write log all
		BEGIN
			SELECT @LogData = 'Transfer All: for ' + CASE @RoleId WHEN 4 THEN 'Super' WHEN 3 THEN 'Master' ELSE '' END + @username

			IF @SubAccID > 0
				SELECT @LogData = 'SubAccount:' + COALESCE(@SubAccName, SPACE(1)) + ' - ' + @LogData

			BEGIN TRY
				EXEC DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_Transfer
					@UserID		= @UserID,
					@FromCustID = @CustId,
					@ToCustID	= 0,
					@IP			= @IP,
					@Doing		= @LogData
			END TRY
			BEGIN CATCH
				SELECT @LogData = @LogData + ' ErrMsg=' + ERROR_MESSAGE()

				EXEC bodb_CustomerLog.dbo.WriteLog_UserLog_Transfer
					@UserID		= @UserID,
					@FromCustID = @CustId,
					@ToCustID	= 0,
					@IP			= @IP,
					@Doing		= @LogData
			END CATCH
		END
	END
	
	-- Return error table
	SELECT ROW_NUMBER() OVER(ORDER BY Id) AS RowId, Content
	FROM @ErrTable
	ORDER BY RowId

	-- Return transferred table
	SELECT 1 AS RowId, @TransferredMember AS TransferredAmount, @memberOutStanding AS MemberOutStanding
	UNION ALL
	SELECT 2, @TransferredAgent, NULL
	UNION ALL
	SELECT 3, @masterBalance, NULL
	WHERE @RoleId = 4
END
GO