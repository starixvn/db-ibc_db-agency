USE bodb02
GO

ALTER PROCEDURE [dbo].[Age_CoreBetList_SMAEventBettype14_SelBetTicket]
	@CustId 			INT
	, @RoleId			INT
	, @MatchId 			INT
	, @Bettype 			INT
	, @Liveindicator 	INT
	, @Betteam 			NVARCHAR(20)
	
	, @Error			INT = 0
	, @ErrorMsg			NVARCHAR(250) = NULL
AS
/*
Created: 
Task : Betlist
DB: DBAGE.bodb02
Original:BetsSelBetListMatchWinLoss_Ag
Revisions:
    - 200712/11@Phuc: For API
    - 20080108: add leaguename,typenamee2,sportname
    - 20080629@Viet: Remove Teamname, Leaguename, Sportname, TypeName
    - 20090326@Phuc: get indexname for FI
    - 20090406@HanhVu: remove refno
    - 20090416@Minh: remove indexName
	- 20090421@[HiepVo]: Include more columns: comm, acomm, scomm, awinlost, mwinlost, swinlost
	- 20090505@HiepVo: Change formula of commission
	- 20090618@AnhPham: Remove 'Customer' table
	- 20090710@Phuc: unhide IP for TB currency.	
	- 20101123@Jacob: Add column betid in select clause
	- 20110408@Amy: Change function to get Odds value and showed odds type
	- 20110809@Sophia: Add a new parametter @liveindicator
	- 20110811@Sophia: Add new columns actual_stake and modds 
	- 20111216@Sophia: Remove function f_GetOddsByBettype , f_GetChoice , f_ShowOddsByBettype
	- 20120112@Sophia:  Add refno, showtime for Table - Shoe - Hand of LiveCasino 
						Add Sub table for Live Casino
	- 20120926@Sophia: Get comstatus
	- 20141016@Sophia: support Sporting solution-grouped bettype 
	- 20150209@Tom: Support 60 BetRadar (27218) Show betcheck coloum on Bettype 216,217 
	- 20150331@Cody: Aplly sport bettype matrix [Redmine: #30169]
*/
BEGIN
	SET NOCOUNT ON;
	
	IF ( @roleid = 1 )
	BEGIN
		INSERT INTO #tempCust
		SELECT b.transid
			,b.custid
		FROM dbo.bettrans14 b WITH(nolock)
			INNER JOIN #BettypeMatrix bt
			ON b.bettype	= bt.bettype			
			INNER JOIN #TransStatus stt
			ON b.statusid	= stt.statusid
		WHERE b.custid 		= @custid
			AND b.matchid	= @matchid

	END
	
	IF ( @roleid = 2 )
	BEGIN
		INSERT INTO #tempCust
		SELECT b.transid
			,b.custid
		FROM dbo.bettrans14 b WITH(nolock)
			INNER JOIN dbo.Customer c WITH(NOLOCK)
			ON b.recommend	= c.custid
			INNER JOIN #BettypeMatrix bt
			ON b.bettype	= bt.bettype			
			INNER JOIN #TransStatus stt
			ON b.statusid	= stt.statusid
		WHERE c.custid  	= @custid
			AND c.roleid 	= @roleid
			AND b.matchid	= @matchid
			
	END
	
	IF ( @roleid = 3 )
	BEGIN
		INSERT INTO #tempCust
		SELECT b.transid
			,b.custid
		FROM dbo.bettrans14 b WITH(nolock)
			INNER JOIN dbo.Customer c WITH(NOLOCK)
			ON b.mrecommend 	= c.custid
			INNER JOIN #BettypeMatrix bt
			ON b.bettype	= bt.bettype			
			INNER JOIN #TransStatus stt
			ON b.statusid	= stt.statusid
		WHERE c.custid 	= @custid
			AND c.roleid 	= @roleid
			AND b.matchid	= @matchid
			
	END
	
	IF ( @roleid = 4 )
	BEGIN
		INSERT INTO #tempCust
		SELECT b.transid
			,b.custid
		FROM dbo.bettrans14 b WITH(nolock)
			INNER JOIN dbo.Customer c WITH(NOLOCK)
			ON b.srecommend 	= c.custid
			INNER JOIN #BettypeMatrix bt
			ON b.bettype	= bt.bettype			
			INNER JOIN #TransStatus stt
			ON b.statusid	= stt.statusid
		WHERE c.custid 	= @custid
			AND c.roleid 	= @roleid
			AND b.matchid	= @matchid
			
	END
	
	IF( EXISTS(SELECT TOP 1 1 FROM #BettypeMatrix WHERE EventType = 1) )
	BEGIN
		--INSERT INTO #MemBetTicket
		SELECT 
			b.transid
			, b.custid
			, b.username
			, m.leagueID
			, m.sporttype
			, b.bettype
			, b.matchid
			, m.matchcode
			, '' AS Race
			, m.homeID
			, m.awayID
			, CONVERT(FLOAT, b.hdp1) AS hdp1
			, CONVERT(FLOAT, b.hdp2) AS hdp2 
			, b.odds
			, b.modds
			, CASE WHEN b.status = 'running' AND ISNULL(b.SecAcceptFlag, 0) = 1 AND ISNULL(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
				ELSE b.status 
			END AS status
			, b.stake
			, b.actual_stake
			, (b.winlost-actual_stake) winlost
			, b.awinlost
			, b.mwinlost
			, b.swinlost
			
			, b.playercomm
			, (b.comm - b.playercomm) AS comm
			, (b.acomm - b.comm) AS acomm 
			, (b.scomm - b.acomm) AS scomm
			
			, b.transdate
			, b.winlostdate
			, b.betteam
			, b.apositiontaking
			, b.mpositiontaking
			, b.spositiontaking	
			, b.discount AS Adiscount
			, b.adiscount AS Mdiscount
			, b.sdiscount AS Sdiscount	
			, b.liveindicator
			, b.livehomescore
			, b.liveawayscore
			
			, b.IP AS IP
			, m.betstatus
			, ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral
			, b.OddsType
			, b.betid
			, m.showtime
			, b.refno
			, b.betcheck
			, CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END AS comstatus 
			
		FROM dbo.bettrans14 b WITH(NOLOCK)
			INNER JOIN #tempCust c
			ON b.transid 	= c.transid
			INNER JOIN dbo.macth14 m WITH (NOLOCK) 
			ON b.matchid	= m.orid
	END
	
	IF( EXISTS(SELECT TOP 1 1 FROM #BettypeMatrix WHERE EventType = 2) )
	BEGIN
		--INSERT INTO #MemBetTicket
		SELECT 
			b.transid
			, b.custid
			, b.username
			, m.leagueID
			, l.sporttype
			, b.bettype
			, 0 AS matchid
			, m.matchcode
			, m.GroupMatch AS Race
			, m.TeamID AS HomeID
			, 0 AS awayID
			, 0 AS hdp1
			, 0 AS hdp2 
			, b.odds
			, b.modds
			, CASE WHEN b.status = 'running' AND ISNULL(b.SecAcceptFlag, 0) = 1 AND ISNULL(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
				ELSE b.status 
			END AS status
			, b.stake
			, b.actual_stake
			, (b.winlost-actual_stake) winlost
			, b.awinlost
			, b.mwinlost
			, b.swinlost
			
			, b.playercomm
			, (b.comm - b.playercomm) AS comm
			, (b.acomm - b.comm) AS acomm 
			, (b.scomm - b.acomm) AS scomm
			
			, b.transdate
			, b.winlostdate
			, '' AS betteam
			, b.apositiontaking
			, b.mpositiontaking
			, b.spositiontaking	
			, b.discount AS Adiscount
			, b.adiscount AS Mdiscount
			, b.sdiscount AS Sdiscount	
			, 0 AS liveindicator
			, 0 AS livehomescore
			, 0 AS liveawayscore
			
			, b.IP AS IP
			, m.betstatus
			, isnull(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral
			, 0 AS OddsType
			, b.betid
			, 0 AS showtime
			, b.refno
			, b.betcheck
			, CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END AS comstatus 
		FROM dbo.bettrans14 b WITH(NOLOCK)
			INNER JOIN #tempCust c
			ON b.transid 	= c.transid
			INNER JOIN dbo.outright14 m WITH (NOLOCK) 
			ON b.matchid	= m.orid
			INNER JOIN league l WITH (NOLOCK) 
			ON m.leagueid 	= l.leagueid
	END
	
	-- FETCH result
	SELECT m.*
	FROM #MemBetTicket m 
	WHERE (
			(m.sporttype = 161 AND b.liveindicator = ISNULL(@liveindicator, b.liveindicator))
			OR m.sporttype <> 161 
		)
		AND	( 
			(LEN(b.betteam) > 0 AND m.sporttype = 161 AND b.betteam = @betteam)
			OR LEN(b.betteam) = 0
		)
	
	IF EXISTS(SELECT TOP 1 1 FROM #BettypeMatrix WHERE ProductID IN( 4 ))
	BEGIN

		SELECT 
			bg.refno, 
			bg.odds, 
			bg.stake,
			bg.status ,
			bg.apositiontaking, 
			bg.mpositiontaking, 
			bg.spositiontaking,
			bg.betteam  
		FROM dbo.bettransg14 bg with (NOLOCK)
			INNER JOIN #MemBetTicket b 
			ON bg.custid	= b.custid
			AND bg.refno 	= B.refno
			INNER JOIN #BettypeMatrix bt
			ON b.bettype = bt.bettype
		WHERE bt.ProductId 	IN (4)
	END
	
	RETURN;
END
GO

