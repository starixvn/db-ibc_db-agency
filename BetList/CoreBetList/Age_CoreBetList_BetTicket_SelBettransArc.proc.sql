USE [bodb_archive]
GO
/****** Object:  StoredProcedure [dbo].[Age_CoreBetList_Mem_SelBetTicket]    Script Date: 5/11/2015 10:31:30 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[Age_CoreBetList_BetTicket_SelBettransArc]
AS
/*
Created: Bobby.Nguyen
Task : Re-factor core betlist and apply GD product
DB: DBARC.bodb_archive
Original: 

Revisions:
	- 20150504@Bobby.Nguyen: Create new SP

Param's Explanation:
	
Dependences:
	- Age_CoreBetList_BetTicket_SelMainInfo
*/
BEGIN
	SET NOCOUNT ON;
	
	-- CHECK for existing table bettrans
	IF (OBJECT_ID('bodb_archive.dbo.bettrans_bk', 'U') IS NULL ) RETURN
	
	CREATE TABLE #custInfo (
		CustId 		INT
		, Username 	NVARCHAR(30)
	);
	INSERT INTO #custInfo
	SELECT c.CustId, c.Username
	FROM bodb02.dbo.custinfo c WITH(NOLOCK)
		INNER JOIN #tempCust t 
		ON c.custid = t.custid
	GROUP BY c.custid, c.username
	
	-- CHECK for selecting from betrans_bk
	IF (EXISTS ( SELECT TOP 1 1 FROM #tempCust WHERE WhTicket = 3))
	BEGIN
		/*	- Mix & System Parlay	: ProductId = 1
			- P2P tickets			: ProductId = 9
			- Casino				: ProductId = 6
			- Bingo					: ProductId = 7
			- Keno					: ProductId = 8
			- Gold Delux			: ProductId = 12
		*/
		IF (EXISTS ( SELECT TOP 1 1 FROM #tempCust WHERE WhTicket = 3 AND EventType = 0))
		BEGIN
			INSERT INTO #MemBetTicket
			SELECT
				CASE WHEN c.ProductID = 1 THEN 
						CASE WHEN ISNULL(b.betid,0) = 0 
							THEN b.TransID 
							ELSE b.betid 
						END
					ELSE b.transid
				END	AS transid
				, b.refno
				, b.custid
				, ci.username
				, CASE	WHEN c.ProductID = 9 THEN 253 
						WHEN c.ProductID = 6 THEN 251
						WHEN c.ProductID = 7 THEN 252
						WHEN c.ProductID = 8 THEN 202
						WHEN c.ProductID = 12 THEN 255
						ELSE 0
				END							AS Sporttype
				
				, b.bettype
				, ISNULL(b.BetID,0)
				, CASE WHEN c.ProductID = 1
							THEN b.Betteam 
						WHEN c.ProductID = 8
							THEN fnc.ChoiceId 
						ELSE '' 
					END						AS Betteam 
				, CASE WHEN c.ProductID = 1
							THEN b.hdp1 
						ELSE 0
					END						AS hdp1
				, CASE WHEN c.ProductID = 1
							THEN b.hdp2 
						ELSE 0 
					END						AS hdp2
				, CASE WHEN c.ProductID = 8
						THEN b.OddsType
					ELSE 0
				END		AS OddsType
				, b.oddsid				
				, CASE WHEN c.ProductID IN ( 1, 8 )
							THEN b.Odds 
						ELSE 0 
					END						AS Odds
				, CASE WHEN c.ProductID IN ( 1 )
							THEN b.modds 
						ELSE 0 
					END						AS modds
				, b.Stake
				, b.actual_stake 
				, b.Status				
				, b.Transdate
				, b.winlostdate						
				, CASE WHEN b.bettype IN (23102, 23002, 23202) THEN 0 
						ELSE (b.winlost - b.actual_stake) 
					END	AS winlost
				, b.awinlost
				, b.mwinlost
				, b.swinlost
				, b.PlayerComm
				, (b.comm - b.playercomm)	AS comm
				, (b.acomm - b.comm)		AS acomm 
				, (b.scomm - b.acomm)		AS scomm
					
				, b.APositiontaking
				, b.MPositiontaking
				, b.SPositiontaking
				, b.TPositiontaking	
				, b.discount
				, b.adiscount
				, b.sdiscount
					
				, CASE WHEN c.ProductID = 1
						THEN b.Liveindicator
					ELSE 0
				END		AS Liveindicator
				, CASE WHEN c.ProductID = 1 
						THEN b.Livehomescore
					ELSE 0
				END		AS Livehomescore
				, CASE WHEN c.ProductID = 1 
						THEN b.Liveawayscore
					ELSE 0
				END		AS Liveawayscore
				, 0 	AS finalhomescore 	
				, 0 	AS finalawayscore 	 
				, 0 	AS hthomescore 		
				, 0 	AS htawayscore 		 
				, b.IP	AS IP
				, 0		AS LeagueID
				,CASE WHEN c.ProductID = 8 
						THEN fnc.GameId
					ELSE 0
				END		AS MatchID
				, ''	AS MatchCode
				, ''	AS Race
				, b.winlostdate AS eventdate
				, 0		AS HomeID
				, 0		AS AwayID		
				, 0		AS Betstatus
				, CONVERT(BIT,0) AS IsNeutral
				, '' AS Placing
				, '' 	AS showtime
				, CASE WHEN c.ProductID IN ( 9, 12 ) 
							AND b.bettype IN ( 1000,1701,1702 )
						THEN b.betcheck 
						ELSE ''
					END	AS betcheck
				, CASE WHEN b.comstatus = '1' 
							THEN '1' 
						ELSE '0' 
				END		AS comstatus
				, '' AS transdesc
				
			FROM dbo.bettrans_bk AS b WITH (NOLOCK)
				INNER JOIN #tempCust c 
				ON b.transid		= c.transid
					AND b.custid	= c.custid
				CROSS APPLY (
					SELECT TOP 1 GameId, ChoiceId
					FROM (
						SELECT GameId, ChoiceId 
						FROM [dbo].[f_ParseTransDesc](b.transdesc, b.bettype)
						UNION
						SELECT '' AS GameId, '' AS ChoiceId 
					) AS tmp
				) AS fnc
				INNER JOIN #custInfo ci
				ON b.custid 		= ci.custid
			WHERE	c.WhTicket 		= 3
				AND c.EventType 	= 0
		END
		/* normal tickets 
			- SB		: ProductID = 1
			- NG		: ProductID = 3
			- LC		: ProductID = 4
			- VS		: ProductID = 5
		*/
		IF (EXISTS ( SELECT TOP 1 1 FROM #tempCust WHERE WhTicket = 3 AND EventType = 1))
		BEGIN
			INSERT INTO #MemBetTicket
			SELECT
				b.transid
				, b.refno
				, b.custid
				, ci.username
				, m.Sporttype
				, b.Bettype
				, ISNULL(b.BetID,0)
				, b.betteam
				, CASE WHEN c.ProductID IN (4) THEN 0
						ELSE b.hdp1
				END		AS hdp1
				, CASE WHEN c.ProductID IN (3, 4) THEN 0
						ELSE b.hdp2
				END		AS hdp2

				, b.OddsType 
				, b.oddsid				
				, b.odds 
				, b.modds
				, b.stake 
				, b.actual_stake
				, b.status 
				, b.transdate
				, b.winlostdate			
				, (b.winlost-actual_stake) AS winlost
				, b.awinlost
				, b.mwinlost
				, b.swinlost
				, b.PlayerComm
				, (b.comm - b.playercomm) 	AS comm
				, (b.acomm - b.comm) 		AS acomm
				, (b.scomm - b.acomm) 		AS scomm
				, b.APositiontaking
				, b.MPositiontaking
				, b.SPositiontaking
				, b.TPositiontaking	
				, b.discount
				, b.adiscount
				, b.sdiscount
					
				, b.Liveindicator
				, b.Livehomescore
				, b.Liveawayscore
				, m.finalhomescore 	
				, m.finalawayscore 	 
				, m.hthomescore 		
				, m.htawayscore 		
				
				, b.IP
				, m.LeagueID
				, m.MatchID	
				, m.MatchCode
				, '' AS Race
				, m.eventdate
				, m.HomeID
				, m.AwayID 		
				, m.Betstatus
				, ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral
				, '' AS Placing
				, ISNULL(m.showtime,'') AS showtime
				, CASE WHEN (c.ProductId = 1 AND b.bettype IN (216,217)) 
						THEN b.betcheck 
						ELSE '' 
					END	AS betcheck
				, CASE WHEN b.comstatus = '1' 
						THEN '1' 
					ELSE '0' 
				END		AS comstatus
				, CASE 
					WHEN b.bettype BETWEEN 801 AND 899 THEN b.transdesc -- metric gaming
					ELSE '' 
				END AS transdesc
				
			FROM dbo.bettrans_bk AS b WITH (NOLOCK)
				INNER JOIN dbo.match_bk AS m WITH (NOLOCK) 
				ON b.matchid		= m.matchid 		
				INNER JOIN #tempCust c 
				ON b.transid		= c.transid
					AND b.custid	= c.custid
				INNER JOIN #custInfo ci
				ON b.custid 		= ci.custid
			WHERE c.WhTicket 		= 3
				AND c.EventType 	= 1
		END
		/* 
			- SB outright	: ProductID = 1
			- HR tickets	: ProductID = 2
		*/
		IF (EXISTS (SELECT TOP 1 1 FROM #tempCust WHERE WhTicket = 3 AND EventType = 2))
		BEGIN
			INSERT INTO #MemBetTicket
			SELECT
				b.transid
				, b.refno
				, b.custid
				, ci.username
				, l.sporttype
				, b.bettype
				, ISNULL(b.BetID,0)
				, '' AS Betteam
				, 0 AS hdp1 
				, 0 AS hdp2 
				, 0 AS OddsType
				, b.oddsid				
				, b.Odds
				, b.modds
				, b.Stake 
				, b.actual_stake
				, b.status				
				, b.transdate
				, b.winlostdate
				, (b.winlost-actual_stake) AS winlost
				, b.awinlost
				, b.mwinlost
				, b.swinlost
				, b.PlayerComm
				, (b.comm - b.playercomm) AS comm
				, (b.acomm - b.comm) AS acomm
				, (b.scomm - b.acomm) AS scomm
					
				, b.APositiontaking			
				, b.MPositiontaking			
				, b.SPositiontaking
				, b.TPositiontaking	
				, b.discount
				, b.adiscount
				, b.sdiscount
					
				, 0 AS LiveIndicator
				, b.LiveHomescore
				, b.LiveAwayscore
				, 0 AS finalhomescore 	
				, 0 AS finalawayscore 	 
				, 0 AS hthomescore 		
				, 0 AS htawayscore
				, b.IP
				, m.LeagueID
				, m.OrId AS MatchID	
				, m.MatchCode
				, m.GroupMatch AS Race
				, m.eventdate
				, m.TeamID AS HomeID
				, 0 AS AwayID		
				, 0 AS Betstatus
				, CONVERT(BIT,0) AS IsNeutral
				, '' AS Placing
				, '' AS showtime
				, '' AS betcheck
				, CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END AS comstatus				
				, '' AS transdesc
				
			FROM dbo.bettrans_bk AS b WITH (NOLOCK)
				INNER JOIN bodb02.dbo.Outright_bk AS m WITH (NOLOCK) 
				ON b.matchid		= m.orid
				INNER JOIN bodb02.dbo.League AS l WITH (NOLOCK) 
				ON m.leagueID		= l.leagueID
				INNER JOIN #tempCust c 
				ON b.transid		= c.transid
					AND b.custid	= c.custid
				INNER JOIN #custInfo ci
				ON b.custid 		= ci.custid
			WHERE c.WhTicket 		= 3
				AND c.EventType		= 2
		END
		
		IF (EXISTS (SELECT TOP 1 1 FROM #tempCust WHERE WhTicket = 3 AND EventType = 3))
		BEGIN
			INSERT INTO #MemBetTicket
			SELECT
				b.transid
				, b.refno
				, b.custid
				, ci.username 
				, r.Sporttype
				, b.Bettype
				, ISNULL(b.BetID,0)
				, '' AS betteam
				, b.hdp1
				, b.hdp2
				, 0 AS OddsType
				, b.oddsid				
				, b.odds
				, b.modds
				, b.Stake 
				, b.actual_stake
				, b.status
				, b.transdate
				, b.winlostdate			
				, (b.winlost-actual_stake) AS winlost
				, b.awinlost
				, b.mwinlost
				, b.swinlost
				, b.PlayerComm
				, (b.comm - b.playercomm) 	AS comm
				, (b.acomm - b.comm) 		AS acomm
				, (b.scomm - b.acomm) 		AS scomm
				, b.APositiontaking
				, b.MPositiontaking
				, b.SPositiontaking
				, b.TPositiontaking	
				, b.discount
				, b.adiscount
				, b.sdiscount
					
				, 0 AS Liveindicator
				, b.Livehomescore
				, b.Liveawayscore
				, 0 AS finalhomescore 	
				, 0 AS finalawayscore 	 
				, 0 AS hthomescore 		
				, 0 AS htawayscore
				
				, b.IP
				, r.LeagueID
				, b.MatchID	
				, o.RacerNum AS MatchCode
				, b.oddsid 	AS Race
				, o.eventdate
				, o.RacerID AS homeID
				, 0 AS awayID		
				, '' AS Betstatus
				, CONVERT(BIT,0) AS IsNeutral	
				, o.Placing
				, r.EventTime AS showtime
				, '' AS betcheck
				, CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END AS comstatus
				, '' AS transdesc
				
			FROM dbo.bettrans_bk AS b WITH (NOLOCK)
				INNER JOIN bodb02.dbo.VSOutright_bk o WITH (NOLOCK) 
				ON b.oddsid			= o.Orid
				INNER JOIN bodb02.dbo.VSRaceInfo r WITH (NOLOCK) 
				ON r.EventID		= o.EventID
				INNER JOIN #tempCust c 
				ON b.transid		= c.transid
					AND b.custid	= c.custid
				INNER JOIN #custInfo ci
				ON b.custid 		= ci.custid
			WHERE c.WhTicket 		= 3
				AND c.EventType		= 3
		END
	END
	
	RETURN
END
GO
GRANT EXECUTE ON [dbo].[Age_CoreBetList_BetTicket_SelBettransArc] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_CoreBetList_BetTicket_SelBettransArc] TO [bodbDownlineNetView]
GO