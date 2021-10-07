/*<info serverAlias="DBAGE-bodb02" executers="bodbDownlineNet,bodbDownlineNetView" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Age_BetStatistics_IPMatching_Master]
	@CustId			INT
	,@WinlostDate	SMALLDATETIME
	,@MemberCount	INT = 2
	,@MoveBetsDay	SMALLDATETIME
AS

/*
	Created: 20200114@Percy
	DB: DBAGE.bodb02
	Task: Alpha - Bet Statistics - IP Matching - View Masters

	Revisions:
		- 20200114@Percy:	Initialize SP [RedmineID: #124701]
		- 20211001@Evan:	Extend data type column IP [RedmineID: #90903]
*/

BEGIN
	SET NOCOUNT ON

	CREATE TABLE #bettype (bettype SMALLINT, RefTable TINYINT)
	INSERT INTO #bettype (bettype, RefTable)
	SELECT DISTINCT bettype, RefTable FROM dbo.SportBettypeMatrix WITH (NOLOCK) WHERE ProductId = 1 AND eventtype = 1 AND bettype <> 38

	DECLARE @matchCustInfo TABLE (matchid INT, custid INT)

	CREATE TABLE #BetStatisticsByIP (IP VARCHAR(45), CustId INT, BetCount INT, Stake MONEY, MemberWinLoss MONEY, SuperWinLoss MONEY, Company MONEY)
	CREATE CLUSTERED INDEX CIX_IP ON #BetStatisticsByIP (IP, CustId)

	IF @WinlostDate > @MoveBetsDay
	BEGIN
		-- bettrans
		INSERT INTO @matchCustInfo (matchid, custid)
		SELECT b.matchid, b.custid
		FROM dbo.bettrans b WITH (NOLOCK)
		WHERE b.srecommend = @CustId
			AND b.winlostdate = @WinlostDate
			AND EXISTS (SELECT 1 FROM #bettype bt WHERE b.bettype = bt.bettype)
		GROUP BY b.matchid, b.custid
		
		INSERT INTO #BetStatisticsByIP (IP, CustId, BetCount, Stake, MemberWinLoss, SuperWinLoss, Company)
		SELECT
			IP				= b.IP
			,CustId			= b.custid
			,BetCount		= COUNT(1)
			,Stake			= SUM(ABS(b.stake))
			,MemberWinLoss	= SUM(CASE WHEN b.statusID IN (0, 1) THEN 0 ELSE b.winlost - b.actual_stake + b.playercomm END)
			,SuperWinLoss	= SUM(CASE WHEN b.statusID IN (0, 1) THEN 0 ELSE b.swinlost + b.scomm - b.acomm END)
			,Company		= -SUM(CASE WHEN b.statusID IN (0, 1) THEN 0 ELSE b.winlost - b.actual_stake + b.swinlost + b.mwinlost + b.awinlost + b.scomm END)
		FROM dbo.bettrans b WITH (NOLOCK)
			CROSS APPLY @matchCustInfo m
		WHERE b.matchid = m.matchid AND b.custid = m.custid
			AND EXISTS (SELECT 1 FROM #bettype bt WHERE b.bettype = bt.bettype)
			AND 1 = CASE
					WHEN b.statusId NOT IN (0, 1) THEN 1
					ELSE CASE WHEN EXISTS (SELECT 1 FROM #bettype bt WHERE b.bettype = bt.bettype AND bt.RefTable = 3) THEN 0 ELSE 1 END END
		GROUP BY
			b.IP
			,b.custid
		OPTION (HASH GROUP)

		-- translog
		INSERT INTO #BetStatisticsByIP (IP, CustId, BetCount, Stake, MemberWinLoss, SuperWinLoss, Company)
		SELECT
			IP				= t.IP
			,CustId			= t.custid
			,BetCount		= COUNT(1)
			,Stake			= SUM(ABS(t.stake))
			,MemberWinLoss	= 0
			,SuperWinLoss	= 0
			,Company		= 0
		FROM dbo.translog t WITH (NOLOCK)
		WHERE t.srecommend = @CustId
			AND t.winlostdate = @WinlostDate
			AND t.statusId IN (0, 1)
			AND EXISTS (SELECT 1 FROM #bettype bt WHERE t.gameId = bt.bettype AND bt.RefTable = 3)
		GROUP BY
			t.IP
			,t.custid
		OPTION (HASH GROUP)
	END
	ELSE
	BEGIN
		-- bettrans14
		INSERT INTO @matchCustInfo (matchid, custid)
		SELECT b.matchid, b.custid
		FROM dbo.bettrans14 b WITH (NOLOCK)
		WHERE b.srecommend = @CustId
			AND b.winlostdate = @WinlostDate
			AND EXISTS (SELECT 1 FROM #bettype bt WHERE b.bettype = bt.bettype)
		GROUP BY b.matchid, b.custid

		INSERT INTO #BetStatisticsByIP (IP, CustId, BetCount, Stake, MemberWinLoss, SuperWinLoss, Company)
		SELECT
			IP				= b.IP
			,CustId			= b.custid
			,BetCount		= COUNT(1)
			,Stake			= SUM(ABS(b.stake))
			,MemberWinLoss	= SUM(b.winlost - b.actual_stake + b.playercomm)
			,SuperWinLoss	= SUM(b.swinlost + b.scomm - b.acomm)
			,Company		= -SUM(b.winlost - b.actual_stake + b.swinlost + b.mwinlost + b.awinlost + b.scomm)
		FROM dbo.bettrans14 b WITH (NOLOCK)
			CROSS APPLY @matchCustInfo m
		WHERE b.winlostdate = @WinlostDate
			AND b.matchid = m.matchid AND b.custid = m.custid
			AND EXISTS (SELECT 1 FROM #bettype bt WHERE b.bettype = bt.bettype)
		GROUP BY
			b.IP
			,b.custid
		OPTION (HASH GROUP)
	END

	DROP TABLE #bettype

	SELECT IP, MemberCount, BetCount, Stake, MemberWinLoss, SuperWinLoss, Company
	FROM
	(
		SELECT
			IP				= IP
			,MemberCount	= COUNT(DISTINCT custid)
			,BetCount		= SUM(BetCount)
			,Stake			= SUM(Stake)
			,MemberWinLoss	= SUM(MemberWinLoss)
			,SuperWinLoss	= SUM(SuperWinLoss)
			,Company		= SUM(Company)
		FROM #BetStatisticsByIP
		GROUP BY IP
		HAVING COUNT(DISTINCT custid) >= @MemberCount
	) r
	ORDER BY
		MemberCount DESC
		,Stake DESC
		,IP ASC

	DROP TABLE #BetStatisticsByIP
END
GO