/*<info serverAlias="DBAGE-bodb02" executers="bodbDownlineNet,bodbDownlineNetView" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Age_Transfer_Credit_All_Sel]
	@CustId					INT,
	@DownlineUsername		NVARCHAR(50),
	@SuperIDsTransferTotal	NVARCHAR(50) = '',
	@IsAllDayTransfer		BIT = 0,
	@Language				VARCHAR(2) = 'E'
AS

/*
	Created: 20180801@Percy
	DB: DBAGE.bodb02
	Task: Alpha - Transfer - Transfer All & Clear Credit - Select (Super/Master only)

	Revisions:
		- 20180801@Percy: Initialize SP [RedmineID: #92142]
		- 20200602@Percy: Separate PendingTransfer3rd from Cash and Balance [RedmineID: #135200]
		- 20210505@Sol: NAP - Alpha - Allow more time for transfer - [Redmine: #149927]
		- 20211111@Evan: Split transfer tickets out of bettrans - [Redmine: #164196]
		- 20230227@Evan: Balance-Up support transfer 247 [Redmine: #173554] 
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @RoleId TINYINT, @srecommend INT, @n INT = 1
	SELECT  @RoleId = roleid, @srecommend = srecommend FROM dbo.Customer WITH (NOLOCK) WHERE custId = @CustId

	SELECT  @DownlineUsername = LTRIM(RTRIM(@DownlineUsername))
	
	DECLARE @DownlineCustId INT, @DownlineRoleId TINYINT

	-- get move bet date
	DECLARE @balanceUpDay SMALLDATETIME, @moveBetsDay SMALLDATETIME
	DECLARE @tblMoveBetBalanceUp AS TABLE (BalanceUpDay SMALLDATETIME, MoveBetsDay SMALLDATETIME)

	INSERT INTO @tblMoveBetBalanceUp(BalanceUpDay,MoveBetsDay)
	EXEC bodb02.dbo.Age_SelBalanceUpDay

	SELECT @balanceUpDay = BalanceUpDay, @moveBetsDay = MoveBetsDay FROM @tblMoveBetBalanceUp

	IF @RoleId = 4
		SELECT  @DownlineCustId = custId, @DownlineRoleId = roleId
		FROM	dbo.custInfo WITH (NOLOCK)
		WHERE	srecommend = @CustId AND username = @DownlineUsername AND roleId = @RoleId - 1
	ELSE IF @RoleId = 3
		SELECT  @DownlineCustId = custId, @DownlineRoleId = roleId
		FROM	dbo.custInfo WITH (NOLOCK)
		WHERE	mrecommend = @CustId AND username = @DownlineUsername AND roleId = @RoleId - 1

	-- super/master only -- invalid downline
	IF @RoleId NOT IN (3,4) OR @DownlineCustId IS NULL
	BEGIN
		SELECT RowId, TransferredAmount, MemberOutStanding
		FROM (VALUES (1, 0, 0)) AS t(RowId, TransferredAmount, MemberOutStanding)
		WHERE 1 = 0

		SELECT RowId, GivenCredit, ClearableCredit
		FROM (VALUES (1, 0, 0)) AS t(RowId, GivenCredit, ClearableCredit)
		WHERE 1 = 0

		RETURN
	END

	-- Check rule before calculate
	BEGIN
		DECLARE @IsErr BIT = 0
		DECLARE @ErrTable TABLE (Id TINYINT, Content NVARCHAR(4000))
		
		-- 1. Nagative given credit
		IF @RoleId = 4
		BEGIN
			IF EXISTS (SELECT 1 FROM dbo.custInfo WITH (NOLOCK) WHERE mrecommend = @DownlineCustId AND ISNULL(credit, 0) < 0)
			BEGIN
				INSERT INTO @ErrTable (Id, Content)
				SELECT 1, dbo.f_Get_MsgNamebyMsgID(40037, @Language)
			END
		END
		ELSE IF @RoleId = 3
		BEGIN
			IF EXISTS (SELECT 1 FROM dbo.custInfo WITH (NOLOCK) WHERE recommend = @DownlineCustId AND ISNULL(credit, 0) < 0)
			BEGIN
				INSERT INTO @ErrTable (Id, Content)
				SELECT 1, dbo.f_Get_MsgNamebyMsgID(40037, @Language)
			END
		END

		-- 2. Nagative bet credit after transfer -- calculate balance part

		-- 3. Transferred to member
		DECLARE @tblcustId TABLE (custid INT)
		
		IF @IsAllDayTransfer = 0
		BEGIN
			IF @RoleId = 4
				INSERT INTO @tblcustId (custid)
				SELECT custid FROM dbo.custInfo WITH (NOLOCK) WHERE mrecommend = @DownlineCustId AND roleId = 1
			ELSE IF @RoleId = 3
				INSERT INTO @tblcustId (custid)
				SELECT custid FROM dbo.custInfo WITH (NOLOCK) WHERE recommend = @DownlineCustId AND roleId = 1

			IF EXISTS (
					SELECT TOP 1 1
					FROM @tblcustId c
						CROSS APPLY (
							SELECT TOP 1 1 AS t FROM dbo.Transfer b WITH (NOLOCK)
							WHERE b.custid = c.custid
								AND b.bettype IN (21003, 21004)
								AND b.transdate >= CONVERT(DATE, GETDATE()) AND b.transdate < DATEADD(DAY, 1, CONVERT(DATE, GETDATE()))
								AND b.winlostdate >= @balanceUpDay
						) AS b
				)
			BEGIN
				INSERT INTO @ErrTable (Id, Content)
				SELECT 3, dbo.f_Get_MsgNamebyMsgID(50013, @Language)
			END
		END

		-- 4. Condition transfer (Exclude Super)
		IF @RoleId = 3
		BEGIN
			DECLARE @ErrCode INT = 0, @ErrMsg NVARCHAR(4000) = '', @strTransferOption VARCHAR(8) = ''

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
				SELECT 4, @ErrMsg
			END
		END
	END
	
	-- Calculate balance
	BEGIN
		DECLARE @today SMALLDATETIME, @yesterday SMALLDATETIME
		SELECT  @today = CONVERT(DATE, GETDATE())
		SELECT  @yesterday = DATEADD(DAY, -1, @today)

		DECLARE @isTest BIT
		SELECT  @isTest = dbo.f_CheckSPVersion(@@PROCID)

		CREATE TABLE #SportBettypeMatrix (bettype INT, RefTable TINYINT)
		INSERT INTO #SportBettypeMatrix (bettype, RefTable)
		SELECT bettype, RefTable FROM dbo.f_SportBettypeMatrix_Sel(0,0,0,2,'','',@isTest)
		WHERE RefTable <> 0 -- exclude bettype on bettrans

		CREATE TABLE #Data
		(
			winlostdate SMALLDATETIME, bettype INT, statusId TINYINT,
			custId INT, roleId TINYINT,
			winlost MONEY, actual_stake MONEY, playercomm MONEY,
			awinlost MONEY, comm MONEY,
			mwinlost MONEY, acomm MONEY
		)

		-- Get Total Balance
		IF @RoleId = 4 -- Super view Master
		BEGIN
			-- bettrans
			INSERT INTO #Data
			(
				winlostdate, bettype, statusId,
				custId, roleId,
				winlost, actual_stake, playercomm,
				awinlost, comm,
				mwinlost, acomm
			)
			SELECT
				winlostdate, bettype, statusId,
				custId, 1,
				SUM(winlost), SUM(actual_stake), SUM(playercomm),
				SUM(awinlost), SUM(comm),
				SUM(mwinlost), SUM(acomm)
			FROM dbo.bettrans WITH (NOLOCK)
			WHERE mrecommend = @DownlineCustId
				AND winlostdate > @moveBetsDay
			GROUP BY
				winlostdate, bettype, statusId,
				custId
			-- Transfer
			INSERT INTO #Data
			(
				winlostdate, bettype, statusId,
				custId, roleId,
				winlost, actual_stake, playercomm,
				awinlost, comm,
				mwinlost, acomm
			)
			SELECT
				winlostdate, bettype, 131,
				custId, CASE custid WHEN mrecommend THEN 3 WHEN recommend THEN 2 ELSE 1 END,
				SUM(winlost), SUM(actual_stake), SUM(playercomm),
				SUM(awinlost), SUM(comm),
				SUM(mwinlost), SUM(acomm)
			FROM dbo.Transfer WITH (NOLOCK)
			WHERE mrecommend = @DownlineCustId
				AND 1 = CASE WHEN bettype = 19999 AND winlostdate > @moveBetsDay THEN 0 --> new sum
							WHEN bettype = 20000 AND winlostdate > @balanceUpDay THEN 0 --> new bal
							WHEN winlostdate < @balanceUpDay THEN 0 --> old data
						ELSE 1 END
				AND bettype NOT IN (21008, 21009)
			GROUP BY
				winlostdate, bettype, 
				custId, CASE custid WHEN mrecommend THEN 3 WHEN recommend THEN 2 ELSE 1 END

			-- Don't get tickets on bettrans which have bettypes on bettransRnG/LC with winlostdate >= yesterday
			DELETE d
			FROM #Data d
				INNER JOIN #SportBettypeMatrix s ON d.bettype = s.bettype
			WHERE s.RefTable IN (1,2)
				AND d.winlostdate >= @yesterday

			-- Don't get OutStanding amount on bettrans which have bettypes on translog, bettransRnG/LC
			DELETE d
			FROM #Data d
				INNER JOIN #SportBettypeMatrix s ON d.bettype = s.bettype
			WHERE d.statusId IN (0,1)

			-- Yesterday balance include today transfer tickets
			UPDATE #Data
			SET winlostdate = @yesterday
			WHERE bettype > 20000 AND winlostdate > @yesterday

			-- bettransRnG
			INSERT INTO #Data
			(
				winlostdate, statusId,
				custId, roleId,
				winlost, actual_stake, playercomm,
				awinlost, comm,
				mwinlost, acomm
			)
			SELECT
				winlostdate, 112 AS statusId,
				custId, 1 AS roleId,
				SUM(winlost) AS winlost, SUM(actual_stake), SUM(playercomm),
				SUM(awinlost), SUM(comm),
				SUM(mwinlost), SUM(acomm)
			FROM dbo.bettransRnG WITH (NOLOCK)
			WHERE srecommend = @srecommend -- using index on IX_srecommend_winlostdate
				AND winlostdate IN (@yesterday, @today)
				AND statusId NOT IN (0,1)
				AND mrecommend * @n = @DownlineCustId -- prevent using index IX_mrecommend (@n = 1)
			GROUP BY
				winlostdate,
				custId

			INSERT INTO #Data
			(
				winlostdate, statusId,
				custId, roleId,
				actual_stake
			)
			SELECT
				winlostdate, 0 AS statusId,
				custId, 1 AS roleId,
				SUM(actual_stake)
			FROM dbo.bettransRnG WITH (NOLOCK)
			WHERE srecommend = @srecommend -- using index on IX_srecommend
				AND statusId IN (0,1)
				AND mrecommend * @n = @DownlineCustId -- prevent using index IX_mrecommend (@n = 1)
			GROUP BY
				winlostdate,
				custId

			-- bettransLC
			INSERT INTO #Data
			(
				winlostdate, statusId,
				custId, roleId,
				winlost, actual_stake, playercomm,
				awinlost, comm,
				mwinlost, acomm
			)
			SELECT
				winlostdate, statusId,
				custId, 1 AS roleId,
				SUM(winlost) AS winlost, SUM(actual_stake), SUM(playercomm),
				SUM(awinlost), SUM(comm),
				SUM(mwinlost), SUM(acomm)
			FROM dbo.bettransLC WITH (NOLOCK)
			WHERE mrecommend = @DownlineCustId
				AND (statusID IN (0,1) OR winlostdate >= @yesterday)
			GROUP BY
				winlostdate, statusId,
				custId

			-- translog
			INSERT INTO #Data
			(
				statusId,
				custId, roleId,
				actual_stake
			)
			SELECT
				0 AS statusId,
				custId, 1 AS roleId,
				SUM(actual_stake)
			FROM dbo.translog WITH (NOLOCK)
			WHERE mrecommend = @DownlineCustId
				AND statusID IN (0,1)
			GROUP BY
				custId
		END
		ELSE IF @RoleId = 3 -- Master view Agent
		BEGIN
			-- bettrans
			INSERT INTO #Data
			(
				winlostdate, bettype, statusId,
				custId, roleId,
				winlost, actual_stake, playercomm,
				awinlost, comm
			)
			SELECT
				winlostdate, bettype, statusId,
				custId, 1,
				SUM(winlost), SUM(actual_stake), SUM(playercomm),
				SUM(awinlost), SUM(comm)
			FROM dbo.bettrans WITH (NOLOCK)
			WHERE recommend = @DownlineCustId
				AND winlostdate > @moveBetsDay
			GROUP BY
				winlostdate, bettype, statusId,
				custId
			-- Transfer
			INSERT INTO #Data
			(
				winlostdate, bettype, statusId,
				custId, roleId,
				winlost, actual_stake, playercomm,
				awinlost, comm
			)
			SELECT
				winlostdate, bettype, 131,
				custId, CASE custid WHEN recommend THEN 2 ELSE 1 END,
				SUM(winlost), SUM(actual_stake), SUM(playercomm),
				SUM(awinlost), SUM(comm)
			FROM dbo.Transfer WITH (NOLOCK)
			WHERE recommend = @DownlineCustId
				AND 1 = CASE WHEN bettype = 19999 AND winlostdate > @moveBetsDay THEN 0 --> new sum
							WHEN bettype = 20000 AND winlostdate > @balanceUpDay THEN 0 --> new bal
							WHEN winlostdate < @balanceUpDay THEN 0 --> old data
						ELSE 1 END
				AND bettype NOT IN (21008, 21009)
			GROUP BY
				winlostdate, bettype, 
				custId, CASE custid WHEN recommend THEN 2 ELSE 1 END

			-- Don't get tickets on bettrans which have bettypes on bettransRnG/LC with winlostdate >= yesterday
			DELETE d
			FROM #Data d
				INNER JOIN #SportBettypeMatrix s ON d.bettype = s.bettype
			WHERE s.RefTable IN (1,2)
				AND d.winlostdate >= @yesterday

			-- Don't get OutStanding amount on bettrans which have bettypes on translog, bettransRnG/LC
			DELETE d
			FROM #Data d
				INNER JOIN #SportBettypeMatrix s ON d.bettype = s.bettype
			WHERE d.statusId IN (0,1)

			-- Yesterday balance include today transfer tickets
			UPDATE #Data
			SET winlostdate = @yesterday
			WHERE bettype > 20000 AND winlostdate > @yesterday

			-- bettransRnG
			INSERT INTO #Data
			(
				winlostdate, statusId,
				custId, roleId,
				winlost, actual_stake, playercomm,
				awinlost, comm
			)
			SELECT
				winlostdate, statusId,
				custId, 1 AS roleId,
				SUM(winlost) AS winlost, SUM(actual_stake), SUM(playercomm),
				SUM(awinlost), SUM(comm)
			FROM dbo.bettransRnG WITH (NOLOCK)
			WHERE recommend = @DownlineCustId
				AND (statusID IN (0,1) OR winlostdate >= @yesterday)
			GROUP BY
				winlostdate, statusId,
				custId

			-- bettransLC
			INSERT INTO #Data
			(
				winlostdate, statusId,
				custId, roleId,
				winlost, actual_stake, playercomm,
				awinlost, comm
			)
			SELECT
				winlostdate, statusId,
				custId, 1 AS roleId,
				SUM(winlost) AS winlost, SUM(actual_stake), SUM(playercomm),
				SUM(awinlost), SUM(comm)
			FROM dbo.bettransLC WITH (NOLOCK)
			WHERE recommend = @DownlineCustId
				AND (statusID IN (0,1) OR winlostdate >= @yesterday)
			GROUP BY
				winlostdate, statusId,
				custId

			-- translog
			INSERT INTO #Data
			(
				statusId,
				custId, roleId,
				actual_stake
			)
			SELECT
				0 AS statusId,
				custId, 1 AS roleId,
				SUM(actual_stake)
			FROM dbo.translog WITH (NOLOCK)
			WHERE recommend = @DownlineCustId
				AND statusID IN (0,1)
			GROUP BY
				custId
		END
	END

	DROP TABLE #SportBettypeMatrix
	
	-- Return data
	BEGIN
		DECLARE @IsTotalTransfer BIT = 0

		IF ',' + @SuperIDsTransferTotal + ',' LIKE '%,' + CONVERT(VARCHAR(20), @srecommend) + ',%'
			SELECT @IsTotalTransfer = 1

		CREATE TABLE #Result
		(
			custId INT PRIMARY KEY,
			yesterdayMemberCash MONEY, totalMemberCash MONEY,
			yesterdayAgentCash MONEY, totalAgentCash MONEY,
			yesterdayMasterCash MONEY, totalMasterCash MONEY,
			Outstanding MONEY, AmountAfterTransfer MONEY
		)

		IF @RoleId = 4
		BEGIN
			INSERT INTO #Result
			(
				custId,
				yesterdayMemberCash, totalMemberCash,
				yesterdayAgentCash, totalAgentCash,
				yesterdayMasterCash, totalMasterCash,
				Outstanding, AmountAfterTransfer
			)
			SELECT
				custId,
				SUM(CASE WHEN statusId NOT IN (0,1) AND winlostdate <= @yesterday THEN
						CASE WHEN roleId = 1 THEN ISNULL(winlost,0)-ISNULL(actual_stake,0)+ISNULL(playercomm,0) ELSE 0 END
						ELSE 0 END),
				SUM(CASE WHEN statusId NOT IN (0,1) THEN
						CASE WHEN roleId = 1 THEN ISNULL(winlost,0)-ISNULL(actual_stake,0)+ISNULL(playercomm,0) ELSE 0 END
						ELSE 0 END),
				SUM(CASE WHEN statusId NOT IN (0,1) AND winlostdate <= @yesterday THEN
						CASE WHEN roleId = 2 THEN ISNULL(winlost,0)-ISNULL(actual_stake,0) ELSE ISNULL(awinlost,0)+ISNULL(comm,0)-ISNULL(playercomm,0) END
						ELSE 0 END),
				SUM(CASE WHEN statusId NOT IN (0,1) THEN
						CASE WHEN roleId = 2 THEN ISNULL(winlost,0)-ISNULL(actual_stake,0) ELSE ISNULL(awinlost,0)+ISNULL(comm,0)-ISNULL(playercomm,0) END
						ELSE 0 END),
				SUM(CASE WHEN statusId NOT IN (0,1) AND winlostdate <= @yesterday THEN
						CASE WHEN roleId = 3 THEN ISNULL(winlost,0)-ISNULL(actual_stake,0) ELSE ISNULL(mwinlost,0)+ISNULL(acomm,0)-ISNULL(comm,0) END
						ELSE 0 END),
				SUM(CASE WHEN statusId NOT IN (0,1) THEN
						CASE WHEN roleId = 3 THEN ISNULL(winlost,0)-ISNULL(actual_stake,0) ELSE ISNULL(mwinlost,0)+ISNULL(acomm,0)-ISNULL(comm,0) END
						ELSE 0 END),
				SUM(CASE WHEN statusId IN (0,1) AND roleId = 1 THEN ISNULL(actual_stake,0) ELSE 0 END),
				SUM(CASE WHEN @IsTotalTransfer = 1 OR roleId > 1 OR winlostdate <= @yesterday THEN CASE WHEN statusId IN (0,1) THEN -ISNULL(actual_stake,0) ELSE 0 END
						ELSE ISNULL(winlost,0)-ISNULL(actual_stake,0)+ISNULL(playercomm,0) END)
			FROM #Data
			GROUP BY custId
		END
		ELSE IF @RoleId = 3
		BEGIN
			INSERT INTO #Result
			(
				custId,
				yesterdayMemberCash, totalMemberCash,
				yesterdayAgentCash, totalAgentCash,
				Outstanding, AmountAfterTransfer
			)
			SELECT
				custId,
				SUM(CASE WHEN statusId NOT IN (0,1) AND winlostdate <= @yesterday THEN
						CASE WHEN roleId = 1 THEN ISNULL(winlost,0)-ISNULL(actual_stake,0)+ISNULL(playercomm,0) ELSE 0 END
						ELSE 0 END),
				SUM(CASE WHEN statusId NOT IN (0,1) THEN
						CASE WHEN roleId = 1 THEN ISNULL(winlost,0)-ISNULL(actual_stake,0)+ISNULL(playercomm,0) ELSE 0 END
						ELSE 0 END),
				SUM(CASE WHEN statusId NOT IN (0,1) AND winlostdate <= @yesterday THEN
						CASE WHEN roleId = 2 THEN ISNULL(winlost,0)-ISNULL(actual_stake,0) ELSE ISNULL(awinlost,0)+ISNULL(comm,0)-ISNULL(playercomm,0) END
						ELSE 0 END),
				SUM(CASE WHEN statusId NOT IN (0,1) THEN
						CASE WHEN roleId = 2 THEN ISNULL(winlost,0)-ISNULL(actual_stake,0) ELSE ISNULL(awinlost,0)+ISNULL(comm,0)-ISNULL(playercomm,0) END
						ELSE 0 END),
				SUM(CASE WHEN statusId IN (0,1) AND roleId = 1 THEN ISNULL(actual_stake,0) ELSE 0 END),
				SUM(CASE WHEN @IsTotalTransfer = 1 OR roleId > 1 OR winlostdate <= @yesterday THEN CASE WHEN statusId IN (0,1) THEN -ISNULL(actual_stake,0) ELSE 0 END
						ELSE ISNULL(winlost,0)-ISNULL(actual_stake,0)+ISNULL(playercomm,0) END)
			FROM #Data
			GROUP BY custId
		END

		DROP TABLE #Data

		DECLARE @memberOutStanding MONEY
		SELECT  @memberOutStanding = ISNULL(SUM(Outstanding), 0) FROM #Result

		-- Calculate credit
		BEGIN
			CREATE TABLE #NetPosition (custid INT, netPosition MONEY)

			INSERT INTO #NetPosition (custId, netPosition)
			EXEC DBTXN.bodb02.dbo.Age_GetCustomerNetPosition
				@CustId = @DownlineCustId,
				@RoleId = @DownlineRoleId

			-- Back to check rule before calculate
			-- 2. Nagative bet credit after transfer
			IF @RoleId = 4
			BEGIN
				IF EXISTS (
					SELECT TOP 1 1
					FROM dbo.custInfo c WITH (NOLOCK)
						LEFT JOIN #Result r ON c.custId = r.custId
						LEFT JOIN #NetPosition np ON c.custId = np.custId
					WHERE c.mrecommend = @DownlineCustId AND c.RoleId = 1 AND ISNULL(c.credit, 0) >= 0
						AND (ISNULL(c.credit,0)+ISNULL(r.AmountAfterTransfer,0)+ISNULL(np.netPosition,0)) < 0
				)
				BEGIN
					INSERT INTO @ErrTable (Id, Content)
					SELECT 2, dbo.f_Get_MsgNamebyMsgID(50012, @Language)
				END
			END
			ELSE IF @RoleId = 3
			BEGIN
				IF EXISTS (
					SELECT TOP 1 1
					FROM dbo.custInfo c WITH (NOLOCK)
						LEFT JOIN #Result r ON c.custId = r.custId
						LEFT JOIN #NetPosition np ON c.custId = np.custId
					WHERE c.recommend = @DownlineCustId AND c.RoleId = 1 AND ISNULL(c.credit, 0) >= 0
						AND (ISNULL(c.credit,0)+ISNULL(r.AmountAfterTransfer,0)+ISNULL(np.netPosition,0)) < 0
				)
				BEGIN
					INSERT INTO @ErrTable (Id, Content)
					SELECT 2, dbo.f_Get_MsgNamebyMsgID(50012, @Language)
				END
			END

			DECLARE @memberClearableCredit MONEY = 0

			IF EXISTS (SELECT 1 FROM @ErrTable)
			BEGIN
				SELECT @IsErr = 1
			END
			ELSE IF @RoleId = 4
			BEGIN
				SELECT @memberClearableCredit =
					SUM(CASE WHEN ISNULL(r.AmountAfterTransfer,0)+ISNULL(np.netPosition,0) >= 0 THEN ISNULL(c.credit,0)
							WHEN ISNULL(c.credit,0)+ISNULL(r.AmountAfterTransfer,0)+ISNULL(np.netPosition,0) <= 0 THEN 0
							ELSE ISNULL(c.credit,0)+ISNULL(r.AmountAfterTransfer,0)+ISNULL(np.netPosition,0) END)
				FROM dbo.custInfo c WITH (NOLOCK)
					LEFT JOIN #Result r ON c.custId = r.custId
					LEFT JOIN #NetPosition np ON c.custId = np.custId
				WHERE c.mrecommend = @DownlineCustId AND c.RoleId = 1
					AND ISNULL(c.credit, 0) > 0
			END
			ELSE IF @RoleId = 3
			BEGIN
				SELECT @memberClearableCredit =
					SUM(CASE WHEN ISNULL(r.AmountAfterTransfer,0)+ISNULL(np.netPosition,0) >= 0 THEN ISNULL(c.credit,0)
							WHEN ISNULL(c.credit,0)+ISNULL(r.AmountAfterTransfer,0)+ISNULL(np.netPosition,0) <= 0 THEN 0
							ELSE ISNULL(c.credit,0)+ISNULL(r.AmountAfterTransfer,0)+ISNULL(np.netPosition,0) END)
				FROM dbo.custInfo c WITH (NOLOCK)
					LEFT JOIN #Result r ON c.custId = r.custId
					LEFT JOIN #NetPosition np ON c.custId = np.custId
				WHERE c.recommend = @DownlineCustId AND c.RoleId = 1
					AND ISNULL(c.credit, 0) > 0
			END

			SELECT @memberClearableCredit = ISNULL(@memberClearableCredit, 0)

			DROP TABLE #NetPosition
		END

		-- Return error table
		SELECT ROW_NUMBER() OVER(ORDER BY Id) AS RowId, Content
		FROM @ErrTable
		ORDER BY RowId

		-- Return transfer table
		IF @IsErr = 1
		BEGIN
			SELECT 1 AS RowId, 0 AS TransferableAmount, @memberOutStanding AS MemberOutStanding
			UNION ALL
			SELECT 2, 0, NULL
			UNION ALL
			SELECT 3, 0, NULL WHERE @RoleId = 4
		END
		ELSE IF @IsTotalTransfer = 1
		BEGIN
			SELECT
				Detail AS RowId,
				u.TransferableAmount,
				CASE WHEN u.Detail = 1 THEN @memberOutStanding ELSE NULL END AS MemberOutStanding
			FROM
			(
				SELECT
					ISNULL(SUM(totalMemberCash), 0) AS [1],
					ISNULL(SUM(totalMemberCash+totalAgentCash), 0) AS [2],
					ISNULL(SUM(totalMemberCash+totalAgentCash+totalMasterCash), 0) AS [3]
				FROM #Result
			) AS Balance
			UNPIVOT
			(
				TransferableAmount
				FOR Detail IN ([1],[2],[3])
			) AS u
			WHERE (@RoleId = 4 OR u.Detail <> 3)
			ORDER BY RowId
		END
		ELSE
		BEGIN
			SELECT
				Detail AS RowId,
				u.TransferableAmount,
				CASE WHEN u.Detail = 1 THEN @memberOutStanding ELSE NULL END AS MemberOutStanding
			FROM
			(
				SELECT
					ISNULL(SUM(yesterdayMemberCash), 0) AS [1],
					ISNULL(SUM(yesterdayMemberCash+yesterdayAgentCash), 0) AS [2],
					ISNULL(SUM(yesterdayMemberCash+yesterdayAgentCash+yesterdayMasterCash), 0) AS [3]
				FROM #Result
			) AS Balance
			UNPIVOT
			(
				TransferableAmount
				FOR Detail IN ([1],[2],[3])
			) AS u
			WHERE (@RoleId = 4 OR u.Detail <> 3)
			ORDER BY RowId
		END

		DROP TABLE #Result

		-- Return credit table
		DECLARE @memberCredit MONEY, @agentCredit MONEY, @masterCredit MONEY

		IF @RoleId = 4
		BEGIN
			SELECT  @memberCredit = SUM(CASE WHEN roleId = 1 THEN ISNULL(credit, 0) ELSE 0 END),
					@agentCredit  = SUM(CASE WHEN roleId = 2 THEN ISNULL(credit, 0) ELSE 0 END),
					@masterCredit = SUM(CASE WHEN roleId = 3 THEN ISNULL(credit, 0) ELSE 0 END)
			FROM	dbo.custInfo WITH (NOLOCK)
			WHERE	mrecommend = @DownlineCustId
		END
		ELSE IF @RoleId = 3
		BEGIN
			SELECT  @memberCredit = SUM(CASE WHEN roleId = 1 THEN ISNULL(credit, 0) ELSE 0 END),
					@agentCredit  = SUM(CASE WHEN roleId = 2 THEN ISNULL(credit, 0) ELSE 0 END)
			FROM	dbo.custInfo WITH (NOLOCK)
			WHERE	recommend = @DownlineCustId
		END
		
		IF @IsErr = 1
		BEGIN
			SELECT 1 AS RowId, @memberCredit AS GivenCredit, 0 AS ClearableCredit
			UNION ALL
			SELECT 2, @agentCredit, 0
			UNION ALL
			SELECT 3, @masterCredit, 0 WHERE @RoleId = 4
		END
		ELSE
		BEGIN
			SELECT 1 AS RowId, @memberCredit AS GivenCredit, @memberClearableCredit AS ClearableCredit
			UNION ALL
			SELECT 2, @agentCredit, @agentCredit - @memberCredit + @memberClearableCredit
			UNION ALL
			SELECT 3, @masterCredit, @masterCredit - @memberCredit + @memberClearableCredit
			WHERE @RoleId = 4
		END
	END
END
GO