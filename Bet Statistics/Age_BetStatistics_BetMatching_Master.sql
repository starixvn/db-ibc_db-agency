/*<info serverAlias="DBAGE-bodb02" executers="bodbDownlineNet,bodbDownlineNetView" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Age_BetStatistics_BetMatching_Master]
	@CustId			INT
	,@WinlostDate	SMALLDATETIME
	,@BetCount		INT = 2
	,@MoveBetsDay	SMALLDATETIME
	,@IsExportExcel	BIT = 0
AS

/*
	Created: 20200114@Percy
	DB: DBAGE.bodb02
	Task: Alpha - Bet Statistics - Bet Choice Matching - View Masters

	Revisions:
		- 20200114@Percy: Initialize SP [RedmineID: #127288]
		- 20211001@Evan: Extend data type column IP [RedmineID: #90903]
		- 20240130@Lewis: Add leaguegroupid [RedmineID: #197160]
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @matchCustInfo TABLE (matchid INT, custid INT, bettype SMALLINT, betteam NVARCHAR(10), hdp1 SMALLMONEY, hdp2 SMALLMONEY, livehomescore SMALLINT, liveawayscore SMALLINT, liveindicator BIT)

	CREATE TABLE #BetMatching
	(
		matchid			INT
		,livehomescore	SMALLINT
		,liveawayscore	SMALLINT
		,liveindicator	BIT
		,custid			INT
		,bettype		SMALLINT
		,betteam		NVARCHAR(10)
		,hdp1			SMALLMONEY
		,hdp2			SMALLMONEY
		,IP				VARCHAR(45)
		,odds			SMALLMONEY
		,oddstype		TINYINT
		,transdate		DATETIME
		,transid		BIGINT
		,statusID		TINYINT
		,stake			MONEY
		,actual_stake	MONEY
		,winlost		MONEY
		,awinlost		MONEY
		,mwinlost		MONEY
		,swinlost		MONEY
		,playercomm		MONEY
		,comm			MONEY
		,acomm			MONEY
		,scomm			MONEY
	)

	IF @WinlostDate > @MoveBetsDay
	BEGIN
		-- bettrans
		INSERT INTO @matchCustInfo (matchid, custid, bettype, betteam, hdp1, hdp2, livehomescore, liveawayscore, liveindicator)
		SELECT b.matchid, b.custid, b.bettype, b.betteam, b.hdp1, b.hdp2, b.livehomescore, b.liveawayscore, b.liveindicator
		FROM dbo.bettrans b WITH (NOLOCK, INDEX = IX_srecommend)
		WHERE b.srecommend = @CustId
			AND b.winlostdate = @WinlostDate
			AND b.bettype IN (1, 3, 5, 7, 8, 15)
			AND b.statusID NOT IN (101, 102, 103)
		GROUP BY b.matchid, b.custid, b.bettype, b.betteam, b.hdp1, b.hdp2, b.livehomescore, b.liveawayscore, b.liveindicator
		HAVING COUNT(1) >= @BetCount
		OPTION (HASH GROUP)

		INSERT INTO #BetMatching
		(
			matchid
			,livehomescore
			,liveawayscore
			,liveindicator
			,custid
			,bettype
			,betteam
			,hdp1
			,hdp2
			,IP
			,odds
			,oddstype
			,transdate
			,transid
			,statusID
			,stake
			,actual_stake
			,winlost
			,awinlost
			,mwinlost
			,swinlost
			,playercomm
			,comm
			,acomm
			,scomm
		)
		SELECT
			b.matchid
			,b.livehomescore
			,b.liveawayscore
			,b.liveindicator
			,b.custid
			,b.bettype
			,b.betteam
			,b.hdp1
			,b.hdp2
			,b.IP
			,b.odds
			,b.oddstype
			,b.transdate
			,b.transid
			,b.statusID
			,b.stake
			,b.actual_stake
			,b.winlost
			,b.awinlost
			,b.mwinlost
			,b.swinlost
			,b.playercomm
			,b.comm
			,b.acomm
			,b.scomm
		FROM dbo.bettrans b WITH (NOLOCK, INDEX = CIX_matchid_bettype)
			CROSS APPLY @matchCustInfo mc
		WHERE b.matchid			= mc.matchid
			AND b.custid		= mc.custid
			AND b.bettype		= mc.bettype
			AND b.betteam		= mc.betteam
			AND b.hdp1			= mc.hdp1
			AND b.hdp2			= mc.hdp2
			AND b.livehomescore	= mc.livehomescore
			AND b.liveawayscore	= mc.liveawayscore
			AND b.liveindicator	= mc.liveindicator
			AND b.statusID NOT IN (101, 102, 103)

		SELECT
			m.leagueid
			,l.LeagueGroupID
			,m.GlobalShowTime
			,m.sporttype
			,m.matchid
			,m.homeid
			,m.awayid
			,b.livehomescore
			,b.liveawayscore
			,b.liveindicator
			,b.custid
			,c.username
			,b.bettype
			,b.betteam
			,b.hdp1
			,b.hdp2
			,b.IP
			,b.odds
			,b.oddstype
			,b.transdate
			,b.transid
			,IsRunning		= CASE WHEN b.statusID IN (0, 1) THEN 1 ELSE 0 END
			,stake			= ABS(b.stake)
			,MemberWinLoss	= (CASE WHEN b.statusID NOT IN (0, 1) THEN b.winlost - b.actual_stake + b.playercomm ELSE 0 END)
			,SuperWinLoss	= (CASE WHEN b.statusID NOT IN (0, 1) THEN b.swinlost + b.scomm - b.acomm ELSE 0 END)
			,Company		= -(CASE WHEN b.statusID NOT IN (0, 1) THEN b.winlost - b.actual_stake + b.swinlost + b.mwinlost + b.awinlost + b.scomm ELSE 0 END)
		FROM #BetMatching b
			INNER JOIN dbo.match m WITH (NOLOCK) ON b.matchid = m.matchid
			INNER JOIN dbo.League l WITH (NOLOCK) ON m.leagueid = l.leagueid
			INNER JOIN dbo.Customer c WITH (NOLOCK) ON b.custid = c.custid
		ORDER BY m.GlobalShowTime DESC, c.username ASC, b.transid DESC
	END
	ELSE
	BEGIN
		-- bettrans14
		INSERT INTO @matchCustInfo (matchid, custid, bettype, betteam, hdp1, hdp2, livehomescore, liveawayscore, liveindicator)
		SELECT b.matchid, b.custid, b.bettype, b.betteam, b.hdp1, b.hdp2, b.livehomescore, b.liveawayscore, b.liveindicator
		FROM dbo.bettrans14 b WITH (NOLOCK, INDEX = IX_srecommend)
		WHERE b.srecommend = @CustId
			AND b.winlostdate = @WinlostDate
			AND b.bettype IN (1, 3, 5, 7, 8, 15)
			AND b.statusID NOT IN (101, 102, 103)
		GROUP BY b.matchid, b.custid, b.bettype, b.betteam, b.hdp1, b.hdp2, b.livehomescore, b.liveawayscore, b.liveindicator
		HAVING COUNT(1) >= @BetCount
		OPTION (HASH GROUP)

		INSERT INTO #BetMatching
		(
			matchid
			,livehomescore
			,liveawayscore
			,liveindicator
			,custid
			,bettype
			,betteam
			,hdp1
			,hdp2
			,IP
			,odds
			,oddstype
			,transdate
			,transid
			,statusID
			,stake
			,actual_stake
			,winlost
			,awinlost
			,mwinlost
			,swinlost
			,playercomm
			,comm
			,acomm
			,scomm
		)
		SELECT
			b.matchid
			,b.livehomescore
			,b.liveawayscore
			,b.liveindicator
			,b.custid
			,b.bettype
			,b.betteam
			,b.hdp1
			,b.hdp2
			,b.IP
			,b.odds
			,b.oddstype
			,b.transdate
			,b.transid
			,b.statusID
			,b.stake
			,b.actual_stake
			,b.winlost
			,b.awinlost
			,b.mwinlost
			,b.swinlost
			,b.playercomm
			,b.comm
			,b.acomm
			,b.scomm
		FROM dbo.bettrans14 b WITH (NOLOCK)
			CROSS APPLY @matchCustInfo mc
		WHERE b.winlostdate		= @WinlostDate
			AND b.matchid		= mc.matchid
			AND b.custid		= mc.custid
			AND b.bettype		= mc.bettype
			AND b.betteam		= mc.betteam
			AND b.hdp1			= mc.hdp1
			AND b.hdp2			= mc.hdp2
			AND b.livehomescore	= mc.livehomescore
			AND b.liveawayscore	= mc.liveawayscore
			AND b.liveindicator	= mc.liveindicator
			AND b.statusID NOT IN (101, 102, 103)

		SELECT
			m.leagueid
			,l.LeagueGroupID
			,m.GlobalShowTime
			,m.sporttype
			,m.matchid
			,m.homeid
			,m.awayid
			,b.livehomescore
			,b.liveawayscore
			,b.liveindicator
			,b.custid
			,c.username
			,b.bettype
			,b.betteam
			,b.hdp1
			,b.hdp2
			,b.IP
			,b.odds
			,b.oddstype
			,b.transdate
			,b.transid
			,IsRunning		= CASE WHEN b.statusID IN (0, 1) THEN 1 ELSE 0 END
			,stake			= ABS(b.stake)
			,MemberWinLoss	= (CASE WHEN b.statusID NOT IN (0, 1) THEN b.winlost - b.actual_stake + b.playercomm ELSE 0 END)
			,SuperWinLoss	= (CASE WHEN b.statusID NOT IN (0, 1) THEN b.swinlost + b.scomm - b.acomm ELSE 0 END)
			,Company		= -(CASE WHEN b.statusID NOT IN (0, 1) THEN b.winlost - b.actual_stake + b.swinlost + b.mwinlost + b.awinlost + b.scomm ELSE 0 END)
		FROM #BetMatching b
			INNER JOIN dbo.match14 m WITH (NOLOCK) ON b.matchid = m.matchid
			INNER JOIN dbo.League l WITH (NOLOCK) ON m.leagueid = l.leagueid
			INNER JOIN dbo.Customer c WITH (NOLOCK) ON b.custid = c.custid
		ORDER BY m.GlobalShowTime DESC, c.username ASC, b.transid DESC
	END

	-- Get sharing IP
	CREATE TABLE #IP (custid INT, IP VARCHAR(45))

	CREATE INDEX IX_IP ON #IP (custid, IP)

	IF @IsExportExcel = 1 -- if export excel, return empty table
	BEGIN
		SELECT custid, username, IP
		FROM (VALUES (0, '', '')) t(custid, username, IP)
		WHERE custid <> 0
	END
	ELSE
	BEGIN
		INSERT INTO #IP (custid, IP)
		SELECT DISTINCT custid, IP
		FROM #BetMatching

		CREATE TABLE #bettype (bettype SMALLINT, RefTable TINYINT)
		INSERT INTO #bettype (bettype, RefTable)
		SELECT DISTINCT bettype, RefTable FROM dbo.SportBettypeMatrix WITH (NOLOCK) WHERE ProductId = 1 AND eventtype = 1 AND bettype <> 38

		SELECT b.custid, c.username, b.IP
		FROM
		(
			SELECT b.custid, b.IP
			FROM
			(
				SELECT b.custid, b.IP
				FROM dbo.bettrans b WITH (NOLOCK)
				WHERE b.srecommend = @CustId
					AND EXISTS (SELECT 1 FROM #IP i WHERE b.custid <> i.custid AND b.IP = i.IP)
					AND EXISTS (SELECT 1 FROM #bettype bt WHERE b.bettype = bt.bettype)
					AND 1 = CASE
							WHEN b.statusId NOT IN (0, 1) THEN 1
							ELSE CASE WHEN EXISTS (SELECT 1 FROM #bettype bt WHERE b.bettype = bt.bettype AND bt.RefTable = 3) THEN 0 ELSE 1 END END

				UNION ALL
				SELECT t.custid, t.IP
				FROM dbo.translog t WITH (NOLOCK)
				WHERE t.srecommend = @CustId
					AND EXISTS (SELECT 1 FROM #IP i WHERE t.custid <> i.custid AND t.IP = i.IP)
					AND t.statusId IN (0, 1)
					AND EXISTS (SELECT 1 FROM #bettype bt WHERE t.gameId = bt.bettype AND bt.RefTable = 3)

				UNION ALL
				SELECT b.custid, b.IP
				FROM dbo.bettrans14 b WITH (NOLOCK)
				WHERE b.srecommend = @CustId
					AND EXISTS (SELECT 1 FROM #IP i WHERE b.custid <> i.custid AND b.IP = i.IP)
					AND EXISTS (SELECT 1 FROM #bettype bt WHERE b.bettype = bt.bettype)
			) b
			GROUP BY b.custid, b.IP
		) b
			INNER JOIN dbo.Customer c WITH (NOLOCK) ON b.custid = c.custid
		OPTION (HASH GROUP)

		DROP TABLE #bettype
	END

	DROP TABLE #BetMatching
	DROP TABLE #IP
END
