/*<info serverAlias="DBAGE-bodb02" executers="bodbDownlineNet,bodbDownlineNetView" isFunction="0" isNested="0"></info>*/
USE [bodb02]
GO

ALTER PROCEDURE [dbo].[Age_Transfer_Credit_All_Sel]
	@CustId					INT,
	@DownlineUsername		NVARCHAR(50),
	@SuperIDsTransferTotal	NVARCHAR(50) = ''
AS

/*
	Created: 20180801@Percy
	DB: DBAGE.bodb02
	Task: Alpha - Transfer - Transfer All & Clear Credit - Select (Super/Master only)

	Revisions:
		- 20180801@Percy: Initialize SP [RedmineID: #92142]
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @RoleId TINYINT, @srecommend INT, @n INT = 1
	SELECT  @RoleId = roleid, @srecommend = srecommend FROM dbo.Customer WITH (NOLOCK) WHERE custId = @CustId

	SELECT  @DownlineUsername = LTRIM(RTRIM(@DownlineUsername))
	
	DECLARE @DownlineCustId INT, @DownlineRoleId TINYINT

	IF @RoleId = 4
		SELECT  @DownlineCustId = custId, @DownlineRoleId = roleId
		FROM	dbo.custInfo WITH (NOLOCK) -- using DBACC to get index seek on username
		WHERE	srecommend = @CustId AND username = @DownlineUsername AND roleId = @RoleId - 1
	ELSE IF @RoleId = 3
		SELECT  @DownlineCustId = custId, @DownlineRoleId = roleId
		FROM	dbo.custInfo WITH (NOLOCK) -- using DBACC to get index seek on username
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

		--CREATE CLUSTERED INDEX CIX_WLD ON #Data (winlostdate, bettype, statusId)

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
				custId, CASE custid WHEN mrecommend THEN 3 WHEN recommend THEN 2 ELSE 1 END,
				SUM(winlost), SUM(actual_stake), SUM(playercomm),
				SUM(awinlost), SUM(comm),
				SUM(mwinlost), SUM(acomm)
			FROM dbo.bettrans WITH (NOLOCK)
			WHERE srecommend = CASE WHEN @n = 1 THEN @srecommend ELSE 0 END -- using index IX_srecommend, using CASE WHEN to remove sort GROUP BY (@n=1)
			GROUP BY
				winlostdate, bettype, statusId,
				custId, CASE custid WHEN mrecommend THEN 3 WHEN recommend THEN 2 ELSE 1 END

			-- Remove custid is not belong to mrecommend = @DownlineCustId
			DELETE d
			FROM #Data d
				INNER JOIN dbo.custInfo c WITH (NOLOCK) ON d.custId = c.custId
			WHERE c.srecommend = @srecommend AND c.mrecommend <> @DownlineCustId

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
				custId, CASE custid WHEN recommend THEN 2 ELSE 1 END,
				SUM(winlost), SUM(actual_stake), SUM(playercomm),
				SUM(awinlost), SUM(comm)
			FROM dbo.bettrans WITH (NOLOCK)
			WHERE srecommend = CASE WHEN @n = 1 THEN @srecommend ELSE 0 END -- using index IX_srecommend, using CASE WHEN to remove sort GROUP BY (@n=1)
			GROUP BY
				winlostdate, bettype, statusId,
				custId, CASE custid WHEN recommend THEN 2 ELSE 1 END

			-- Remove custid is not belong to mrecommend = @DownlineCustId
			DELETE d
			FROM #Data d
				INNER JOIN dbo.custInfo c WITH (NOLOCK) ON d.custId = c.custId
			WHERE c.srecommend = @srecommend AND c.recommend <> @DownlineCustId

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
		DECLARE @IsTotalTransfer MONEY = 0

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

		CREATE TABLE #NetPosition (custid INT, netPosition MONEY)
		INSERT INTO #NetPosition (custId, netPosition)
		EXEC DBTXN.bodb02.dbo.Age_GetCustomerNetPosition
			@CustId = @DownlineCustId,
			@RoleId = @DownlineRoleId

		DECLARE @memberClearableCredit MONEY
		
		IF @RoleId = 4
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

		-- Return transfer table
		IF @IsTotalTransfer = 1
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
		
		SELECT 1 AS RowId, @memberCredit AS GivenCredit, @memberClearableCredit AS ClearableCredit
		UNION ALL
		SELECT 2, @agentCredit, @agentCredit - @memberCredit + @memberClearableCredit
		UNION ALL
		SELECT 3, @masterCredit, @masterCredit - @memberCredit + @memberClearableCredit
		WHERE @RoleId = 4
	END
END
GO