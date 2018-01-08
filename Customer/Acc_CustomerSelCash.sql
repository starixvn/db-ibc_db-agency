/*<info serverAlias="DBAGE-bodb02" executers="bodbDownlineNet,bodbDownlineNetView" viewers="" isFunction="0" isNested="1"></info>*/
USE [bodb02]
GO

ALTER PROCEDURE [dbo].[Acc_CustomerSelCash]
	@CustId INT
AS

/*
	Created by Percy
	Date: 2017-10-20
	DB: DBAGE.bodb02
	Task: Core SP - Get Cash by CustId

	Revisions:
		- 20171020@Percy: Create new [RedmineID: #84690]
		- 20170108@Sophia: Enhance SP due to high CPU [Redmine: #88837]
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @yesterday SMALLDATETIME
	SELECT  @yesterday = CONVERT(DATE, DATEADD(DAY, -1, GETDATE()))

	-- Get bettype --
	DECLARE @isTest BIT = 0
	SELECT  @isTest = dbo.f_CheckSPVersion(@@PROCID)
	
	CREATE TABLE #SportBettype (bettype INT)
	INSERT INTO #SportBettype (bettype)
	SELECT bettype FROM dbo.f_SportBettypeMatrix_Sel (0, 0, 0, 2, '', '', @isTest)
	WHERE RefTable NOT IN (0, 3) -- exclude bettrans, translog

	DECLARE @roleID TINYINT

	SELECT  @roleID = roleid FROM dbo.custInfo WITH (NOLOCK) WHERE custid = @custID
	
	-- Get Balance Information --
	DECLARE @recommend TABLE (custid INT) -- using for super and master level	
	DECLARE @Super TABLE (custid INT) -- using for super level
	
	
	CREATE TABLE #BalanceInfo
	(
		superCash	MONEY DEFAULT ((0)), yesterdaySuperCash		MONEY DEFAULT ((0)),
		masterCash	MONEY DEFAULT ((0)), yesterdayMasterCash	MONEY DEFAULT ((0)),
		agentCash	MONEY DEFAULT ((0)), yesterdayAgentCash		MONEY DEFAULT ((0)),
		memberCash	MONEY DEFAULT ((0)), yesterdayMemberCash	MONEY DEFAULT ((0))
	)

    IF @roleid = 1
	BEGIN
		-- bettransRNG
		INSERT INTO #BalanceInfo (memberCash, yesterdayMemberCash)
		SELECT 
			SUM(winlost-actual_stake+playercomm),
			SUM(CASE WHEN winlostdate = @yesterday THEN winlost-actual_stake+playercomm ELSE 0 END)
	    FROM dbo.bettransRNG WITH (NOLOCK)
		WHERE custid = @custid
			AND winlostdate >= @yesterday
			AND statusID NOT IN (0, 1)

		-- bettransLC
		INSERT INTO #BalanceInfo (memberCash, yesterdayMemberCash)
		SELECT 
			SUM(winlost-actual_stake+playercomm),
			SUM(CASE WHEN winlostdate = @yesterday THEN winlost-actual_stake+playercomm ELSE 0 END)
	    FROM dbo.bettransLC WITH (NOLOCK)
		WHERE custid = @custid
			AND winlostdate >= @yesterday
			AND statusID NOT IN (0, 1)

		-- bettrans
		INSERT INTO #BalanceInfo (memberCash, yesterdayMemberCash)
		SELECT
			SUM(winlost-actual_stake+playercomm),
			SUM(CASE WHEN (winlostdate <= @yesterday OR b.bettype > 20000) THEN winlost-actual_stake+playercomm ELSE 0 END)
		FROM dbo.bettrans b WITH (NOLOCK)
		WHERE b.custid = @custid
			AND b.ruben = 1
			AND (
				b.winlostdate < @yesterday
				OR NOT EXISTS (SELECT TOP 1 1 FROM #SportBettype s WHERE s.Bettype = b.bettype)
			)
    END
    ELSE IF @roleid = 2
    BEGIN
		-- bettransRNG
		INSERT INTO #BalanceInfo (agentCash, yesterdayAgentCash, memberCash, yesterdayMemberCash)
		SELECT 
			SUM(awinlost+comm-playercomm),
			SUM(CASE WHEN winlostdate = @yesterday THEN awinlost+comm-playercomm ELSE 0 END),
			SUM(winlost-actual_stake+playercomm),
			SUM(CASE WHEN winlostdate = @yesterday THEN winlost-actual_stake+playercomm ELSE 0 END)
	    FROM dbo.bettransRNG WITH (NOLOCK)
		WHERE recommend = @custid
			AND winlostdate >= @yesterday
			AND statusID NOT IN (0, 1)

		-- bettransLC
		INSERT INTO #BalanceInfo (agentCash, yesterdayAgentCash, memberCash, yesterdayMemberCash)
		SELECT 
			SUM(awinlost+comm-playercomm),
			SUM(CASE WHEN winlostdate = @yesterday THEN awinlost+comm-playercomm ELSE 0 END),
			SUM(winlost-actual_stake+playercomm),
			SUM(CASE WHEN winlostdate = @yesterday THEN winlost-actual_stake+playercomm ELSE 0 END)
	    FROM dbo.bettransLC WITH (NOLOCK)
		WHERE recommend = @custid
			AND winlostdate >= @yesterday
			AND statusID NOT IN (0, 1)

		-- bettrans /* need check custid = recommend due to sum/balance/transfer tickets */
		INSERT INTO #BalanceInfo (agentCash, yesterdayAgentCash, memberCash, yesterdayMemberCash)
		SELECT
			SUM(CASE WHEN custid = recommend THEN winlost-actual_stake ELSE awinlost+comm-playercomm END),
			SUM(CASE WHEN custid = recommend THEN winlost-actual_stake ELSE awinlost+comm-playercomm END),
			SUM(CASE WHEN custid <> recommend THEN winlost-actual_stake+playercomm ELSE 0 END),
			SUM(CASE WHEN custid <> recommend THEN winlost-actual_stake+playercomm ELSE 0 END)
		FROM dbo.bettrans b WITH (NOLOCK)
		WHERE b.recommend = @custid
			AND b.ruben = 1
			AND b.winlostdate < @yesterday

		INSERT INTO #BalanceInfo (agentCash, yesterdayAgentCash, memberCash, yesterdayMemberCash)
		SELECT
			SUM(CASE WHEN custid = recommend THEN winlost-actual_stake ELSE awinlost+comm-playercomm END),
			SUM(CASE WHEN (winlostdate = @yesterday OR b.bettype > 20000) THEN CASE WHEN custid = recommend THEN winlost-actual_stake ELSE awinlost+comm-playercomm END ELSE 0 END),
			SUM(CASE WHEN custid <> recommend THEN winlost-actual_stake+playercomm ELSE 0 END),
			SUM(CASE WHEN custid <> recommend AND (winlostdate = @yesterday OR b.bettype > 20000) THEN winlost-actual_stake+playercomm ELSE 0 END)
		FROM dbo.bettrans b WITH (NOLOCK)
		WHERE b.recommend = @custid
			AND b.ruben = 1
			AND b.winlostdate >= @yesterday
			AND NOT EXISTS (SELECT TOP 1 1 FROM #SportBettype s WHERE s.Bettype = b.bettype)
    END
    ELSE IF @roleid = 3
    BEGIN
		INSERT INTO @recommend (custid)
		SELECT custid FROM dbo.custinfo WITH (NOLOCK)
		WHERE mrecommend = @custid AND roleid = 2

		-- bettransRNG
		INSERT INTO #BalanceInfo (masterCash, yesterdayMasterCash, agentCash, yesterdayAgentCash, memberCash, yesterdayMemberCash)
		SELECT 
			SUM(mwinlost+acomm-comm),
			SUM(CASE WHEN winlostdate = @yesterday THEN mwinlost+acomm-comm ELSE 0 END),
			SUM(awinlost+comm-playercomm),
			SUM(CASE WHEN winlostdate = @yesterday THEN awinlost+comm-playercomm ELSE 0 END),
			SUM(winlost-actual_stake+playercomm),
			SUM(CASE WHEN winlostdate = @yesterday THEN winlost-actual_stake+playercomm ELSE 0 END)
	    FROM dbo.bettransRNG WITH (NOLOCK)
		WHERE mrecommend = @custid
			AND winlostdate >= @yesterday
			AND statusID NOT IN (0, 1)

		-- bettransLC
		INSERT INTO #BalanceInfo (masterCash, yesterdayMasterCash, agentCash, yesterdayAgentCash, memberCash, yesterdayMemberCash)
		SELECT 
			SUM(mwinlost+acomm-comm),
			SUM(CASE WHEN winlostdate = @yesterday THEN mwinlost+acomm-comm ELSE 0 END),
			SUM(awinlost+comm-playercomm),
			SUM(CASE WHEN winlostdate = @yesterday THEN awinlost+comm-playercomm ELSE 0 END),
			SUM(winlost-actual_stake+playercomm),
			SUM(CASE WHEN winlostdate = @yesterday THEN winlost-actual_stake+playercomm ELSE 0 END)
	    FROM dbo.bettransLC WITH (NOLOCK)
		WHERE mrecommend = @custid
			AND winlostdate >= @yesterday
			AND statusID NOT IN (0, 1)

		-- bettrans /* need check custid = recommend due to sum/balance/transfer tickets */
		INSERT INTO #BalanceInfo (masterCash, yesterdayMasterCash, agentCash, yesterdayAgentCash, memberCash, yesterdayMemberCash)
		SELECT
			SUM(mwinlost+acomm-comm),
			SUM(mwinlost+acomm-comm),
			SUM(CASE WHEN custid = recommend THEN winlost-actual_stake ELSE awinlost+comm-playercomm END),
			SUM(CASE WHEN custid = recommend THEN winlost-actual_stake ELSE awinlost+comm-playercomm END),
			SUM(CASE WHEN custid <> recommend THEN winlost-actual_stake+playercomm ELSE 0 END),
			SUM(CASE WHEN custid <> recommend THEN winlost-actual_stake+playercomm ELSE 0 END)
		FROM dbo.bettrans b WITH (NOLOCK)
		WHERE EXISTS (SELECT TOP 1 1 FROM @recommend r WHERE b.recommend = r.custid)
			AND b.ruben = 1
			AND b.winlostdate < @yesterday

		INSERT INTO #BalanceInfo (masterCash, yesterdayMasterCash, agentCash, yesterdayAgentCash, memberCash, yesterdayMemberCash)
		SELECT
			SUM(mwinlost+acomm-comm),
			SUM(CASE WHEN (winlostdate = @yesterday OR bettype > 20000) THEN mwinlost+acomm-comm ELSE 0 END),
			SUM(CASE WHEN custid = recommend THEN winlost-actual_stake ELSE awinlost+comm-playercomm END),
			SUM(CASE WHEN (winlostdate = @yesterday OR bettype > 20000) THEN CASE WHEN custid = recommend THEN winlost-actual_stake ELSE awinlost+comm-playercomm END ELSE 0 END),
			SUM(CASE WHEN custid <> recommend THEN winlost-actual_stake+playercomm ELSE 0 END),
			SUM(CASE WHEN (winlostdate = @yesterday OR bettype > 20000) AND custid <> recommend THEN winlost-actual_stake+playercomm ELSE 0 END)
		FROM dbo.bettrans b WITH (NOLOCK)
		WHERE EXISTS (SELECT TOP 1 1 FROM @recommend r WHERE b.recommend = r.custid)
			AND b.ruben = 1
			AND b.winlostdate >= @yesterday
			AND NOT EXISTS (SELECT TOP 1 1 FROM #SportBettype s WHERE s.Bettype = b.bettype)

			-- sum, balance, transfer tickets of this master
		INSERT INTO #BalanceInfo (masterCash, yesterdayMasterCash, agentCash, yesterdayAgentCash, memberCash, yesterdayMemberCash)
		SELECT
			SUM(winlost-actual_stake),
			SUM(CASE WHEN (winlostdate <= @yesterday OR b.bettype > 20000) THEN winlost-actual_stake ELSE 0 END),
			SUM(awinlost+comm-playercomm),
			SUM(CASE WHEN (winlostdate <= @yesterday OR b.bettype > 20000) THEN awinlost+comm-playercomm ELSE 0 END),
			0,
			0
		FROM dbo.bettrans b WITH (NOLOCK)
		WHERE custid = @custid
			AND b.matchid = 0
			AND b.bettype >= 19999
			AND b.ruben = 1
    END
    ELSE IF @roleid = 4
    BEGIN
		--- 20180108@Sophia: use table variable @recommend to avoid re-build plan in case big line 
		INSERT INTO @recommend (custid)
		SELECT custid FROM dbo.custinfo WITH (NOLOCK)
		WHERE srecommend = @custid AND roleid = 2

		INSERT INTO @Super (custid) -- this super and all masters
		SELECT custid FROM dbo.custinfo WITH (NOLOCK)
		WHERE srecommend = @custid AND roleid IN (3, 4)

		-- bettransRNG
		INSERT INTO #BalanceInfo (superCash, yesterdaySuperCash, masterCash, yesterdayMasterCash, agentCash, yesterdayAgentCash, memberCash, yesterdayMemberCash)
		SELECT 
			SUM(swinlost+scomm-acomm),
			SUM(CASE WHEN winlostdate = @yesterday THEN swinlost+scomm-acomm ELSE 0 END),
			SUM(mwinlost+acomm-comm),
			SUM(CASE WHEN winlostdate = @yesterday THEN mwinlost+acomm-comm ELSE 0 END),
			SUM(awinlost+comm-playercomm),
			SUM(CASE WHEN winlostdate = @yesterday THEN awinlost+comm-playercomm ELSE 0 END),
			SUM(winlost-actual_stake+playercomm),
			SUM(CASE WHEN winlostdate = @yesterday THEN winlost-actual_stake+playercomm ELSE 0 END)
	    FROM dbo.bettransRNG WITH (NOLOCK)
		WHERE srecommend = @custid
			AND winlostdate >= @yesterday
			AND statusID NOT IN (0, 1)

		-- bettransLC
		INSERT INTO #BalanceInfo (superCash, yesterdaySuperCash, masterCash, yesterdayMasterCash, agentCash, yesterdayAgentCash, memberCash, yesterdayMemberCash)
		SELECT 
			SUM(swinlost+scomm-acomm),
			SUM(CASE WHEN winlostdate = @yesterday THEN swinlost+scomm-acomm ELSE 0 END),
			SUM(mwinlost+acomm-comm),
			SUM(CASE WHEN winlostdate = @yesterday THEN mwinlost+acomm-comm ELSE 0 END),
			SUM(awinlost+comm-playercomm),
			SUM(CASE WHEN winlostdate = @yesterday THEN awinlost+comm-playercomm ELSE 0 END),
			SUM(winlost-actual_stake+playercomm),
			SUM(CASE WHEN winlostdate = @yesterday THEN winlost-actual_stake+playercomm ELSE 0 END)
	    FROM dbo.bettransLC WITH (NOLOCK)
		WHERE srecommend = @custid
			AND winlostdate >= @yesterday
			AND statusID NOT IN (0, 1)

		-- bettrans /* need check custid = recommend due to sum/balance/transfer tickets */
		INSERT INTO #BalanceInfo (superCash, yesterdaySuperCash, masterCash, yesterdayMasterCash, agentCash, yesterdayAgentCash, memberCash, yesterdayMemberCash)
		SELECT
			SUM(swinlost+scomm-acomm),
			SUM(swinlost+scomm-acomm),
			SUM(mwinlost+acomm-comm),
			SUM(mwinlost+acomm-comm),
			SUM(CASE WHEN custid = recommend THEN winlost-actual_stake ELSE awinlost+comm-playercomm END),
			SUM(CASE WHEN custid = recommend THEN winlost-actual_stake ELSE awinlost+comm-playercomm END),
			SUM(CASE WHEN custid <> recommend THEN winlost-actual_stake+playercomm ELSE 0 END),
			SUM(CASE WHEN custid <> recommend THEN winlost-actual_stake+playercomm ELSE 0 END)
		FROM dbo.bettrans b WITH (NOLOCK)
		WHERE EXISTS (SELECT TOP 1 1 FROM @recommend r WHERE b.recommend = r.custid)
			AND b.ruben = 1
			AND b.winlostdate < @yesterday

		INSERT INTO #BalanceInfo (superCash, yesterdaySuperCash, masterCash, yesterdayMasterCash, agentCash, yesterdayAgentCash, memberCash, yesterdayMemberCash)
		SELECT
			SUM(swinlost+scomm-acomm),
			SUM(CASE WHEN (winlostdate = @yesterday OR bettype > 20000) THEN swinlost+scomm-acomm ELSE 0 END),
			SUM(mwinlost+acomm-comm),
			SUM(CASE WHEN (winlostdate = @yesterday OR bettype > 20000) THEN mwinlost+acomm-comm ELSE 0 END),
			SUM(CASE WHEN custid = recommend THEN winlost-actual_stake ELSE awinlost+comm-playercomm END),
			SUM(CASE WHEN (winlostdate = @yesterday OR bettype > 20000) THEN CASE WHEN custid = recommend THEN winlost-actual_stake ELSE awinlost+comm-playercomm END ELSE 0 END),
			SUM(CASE WHEN custid <> recommend THEN winlost-actual_stake+playercomm ELSE 0 END),
			SUM(CASE WHEN (winlostdate = @yesterday OR bettype > 20000) AND custid <> recommend THEN winlost-actual_stake+playercomm ELSE 0 END)
		FROM dbo.bettrans b WITH (NOLOCK)
		WHERE EXISTS (SELECT TOP 1 1 FROM @recommend r WHERE b.recommend = r.custid)
			AND b.ruben = 1
			AND b.winlostdate >= @yesterday
			AND NOT EXISTS (SELECT TOP 1 1 FROM #SportBettype s WHERE s.Bettype = b.bettype)

			-- sum, balance, transfer tickets of this super and all masters
		INSERT INTO #BalanceInfo (superCash, yesterdaySuperCash, masterCash, yesterdayMasterCash, agentCash, yesterdayAgentCash, memberCash, yesterdayMemberCash)
		SELECT
			SUM(CASE WHEN custid = srecommend THEN winlost-actual_stake ELSE swinlost+scomm-acomm END),
			SUM(CASE WHEN (winlostdate <= @yesterday OR b.bettype > 20000) THEN CASE WHEN custid = srecommend THEN winlost-actual_stake ELSE swinlost+scomm-acomm END ELSE 0 END),
			SUM(CASE WHEN custid = mrecommend THEN winlost-actual_stake ELSE mwinlost+acomm-comm END),
			SUM(CASE WHEN (winlostdate <= @yesterday OR b.bettype > 20000) THEN CASE WHEN custid = mrecommend THEN winlost-actual_stake ELSE mwinlost+acomm-comm END ELSE 0 END),
			SUM(awinlost+comm-playercomm),
			SUM(CASE WHEN (winlostdate <= @yesterday OR b.bettype > 20000) THEN awinlost+comm-playercomm ELSE 0 END),
			0,
			0
		FROM dbo.bettrans b WITH (NOLOCK)
		WHERE EXISTS (SELECT TOP 1 1 FROM @Super c WHERE b.custid = c.custid)
			AND b.matchid = 0
			AND b.bettype >= 19999
			AND b.ruben = 1
    END

	SELECT
		SUM(superCash)				AS superCash,
		SUM(yesterdaySuperCash)		AS yesterdaySuperCash,
		SUM(masterCash)				AS masterCash,
		SUM(yesterdayMasterCash)	AS yesterdayMasterCash,
		SUM(agentCash)				AS agentCash,
		SUM(yesterdayAgentCash)		AS yesterdayAgentCash,
		SUM(memberCash)				AS memberCash,
		SUM(yesterdayMemberCash)	AS yesterdayMemberCash
	FROM #BalanceInfo
	
	DROP TABLE #SportBettype
	DROP TABLE #BalanceInfo
	
END
GO