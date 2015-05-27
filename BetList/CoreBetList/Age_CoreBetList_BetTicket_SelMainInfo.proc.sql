USE [bodb02]
GO
/****** Object:  StoredProcedure [dbo].[Age_CoreBetList_Mem_SelBetTicket]    Script Date: 5/11/2015 10:31:30 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[Age_CoreBetList_BetTicket_SelMainInfo]
AS
/*
	Created: Bobby.Nguyen
	Task : Re-factor core bet list
	DB: DBAGE.bodb02
	Original: 

	Revisions:
		- 20150504@Bobby.Nguyen: Create new SP - Apply GD product
		- 20150526@Bobby.Nguyen: Apply metric-gaming bettype
	
	Param's Explanation:
		
		
	Dependences:
		- CREATE TABLE #tempCust 
		( 
			transid			BIGINT
			, refno			BIGINT
			, custid 		INT 
			, productId 	INT 
			, eventType		TINYINT
			, WhTicket		TINYINT
		)
*/
BEGIN
	SET NOCOUNT ON;
	
	-- CHECK dependences tables 
	IF ( OBJECT_ID('tempdb..#tempCust') IS NULL )
	BEGIN
		RAISERROR(
			N'The table input of bet list detail was not found.'
			, 10
			, 1
		);
		RETURN;
	END
	-- CREATE output main info ticket
	CREATE TABLE #MemBetTicket
	(
		TransID 			BIGINT
		, RefNO 			BIGINT	
		, custid 			INT
		, Username 			NVARCHAR(30)
		, Sporttype 		SMALLINT
		, Bettype 			SMALLINT
		, BetID 			BIGINT
		, Betteam 			NVARCHAR(20)
		, hdp1 				SMALLMONEY
		, hdp2 				SMALLMONEY 
		, OddsType 			TINYINT
		, Odds 				SMALLMONEY 
		, modds 			SMALLMONEY
		, Stake 			MONEY
		, actual_stake 		MONEY
		, Status 			NVARCHAR(10)
		, transdate 		DATETIME
		, winlostdate 		DATETIME
		, winlost 			MONEY
		, awinlost 			MONEY
		, mwinlost 			MONEY
		, swinlost 			MONEY
		, playerComm		MONEY
		, comm				MONEY
		, acomm				MONEY
		, scomm				MONEY
		, APositiontaking	SMALLMONEY
		, MPositiontaking	SMALLMONEY
		, SPositiontaking	SMALLMONEY
		, Adiscount 		SMALLMONEY
		, Mdiscount 		SMALLMONEY
		, Sdiscount 		SMALLMONEY
		, liveindicator 	BIT
		, livehomescore 	SMALLINT
		, liveawayscore 	SMALLINT
		, finalhomescore 	SMALLINT
		, finalawayscore 	SMALLINT 
		, hthomescore 		SMALLINT
		, htawayscore 		SMALLINT 
		, IP 				NVARCHAR(15)
		, LeagueID 			INT
		, MatchID 			INT
		, MatchCode 		NVARCHAR(50)
		, Race 				NVARCHAR(20)
		, eventdate 		DATETIME
		, HomeID 			INT
		, AwayID 			INT 	
		, Betstatus 		NVARCHAR(50)
		, isNeutral 		BIT
		, showtime 			NVARCHAR(50)
		, betcheck 			NVARCHAR(50)
		, comstatus 		NVARCHAR(20)
		, transdesc			NVARCHAR(300)
	);
	
	-- CREATE output detail tickets
	CREATE TABLE #BettransDetail 
	(  
		refno 				BIGINT  
		, odds 				SMALLMONEY
		, stake 			MONEY
		, status 			NVARCHAR(10)
		, apositiontaking 	SMALLMONEY
		, mpositiontaking 	SMALLMONEY
		, spositiontaking 	SMALLMONEY
		, bettype 			SMALLINT
		, betteam 			NVARCHAR (10)
		, transdesc			VARCHAR (300)
	) 
	/* 	CHECK for selecting from translog
		Keno		: ProductId = 8
		GoldDelux	: ProductId = 12
	*/	
	IF (EXISTS (SELECT TOP 1 1 FROM #tempCust WHERE WhTicket = 0))
	BEGIN
		/*	- Keno					: ProductId = 8
			- Gold Delux			: ProductId = 12
		*/
		IF (EXISTS ( SELECT TOP 1 1 FROM #tempCust WHERE WhTicket = 0 AND EventType = 0))
		BEGIN
			INSERT INTO #MemBetTicket
			SELECT 
				b.translogid 	AS transid
				, b.translogid 	AS refno
				, b.custid
				, b.UserName
				, CASE 	WHEN c.ProductID = 8 THEN 202
						WHEN c.ProductID = 12 THEN 255
						ELSE 0
				END	AS Sporttype
				, b.GameId 		AS bettype
				, 0 			AS betid
				, CASE WHEN c.ProductID = 8 THEN fnc.ChoiceId 
					ELSE '' END AS betteam
				, 0				AS hdp1
				, 0				AS hdp2
				, 0 			AS OddsType
				, b.Odds 
				, 0 			AS modds
				, b.Stake
				, b.actual_stake 
				, b.Status				
				, b.transdate
				, b.winlostdate						
				, 0	AS Winlost
				, 0 AS awinlost
				, 0 AS mwinlost
				, 0 AS swinlost
				, 0 AS PlayerComm
				, 0 AS comm
				, 0 AS acomm 
				, 0 AS scomm
					
				, b.APositiontaking
				, b.MPositiontaking
				, b.SPositiontaking
				
				,b.discount 	AS adiscount
				,b.adiscount 	AS mdiscount
				,b.sdiscount 	AS sdiscount
					
				, 0		AS Liveindicator
				, 0		AS Livehomescore
				, 0		AS Liveawayscore
				, 0 	AS finalhomescore 	
				, 0 	AS finalawayscore 	 
				, 0 	AS hthomescore 		
				, 0 	AS htawayscore 		 
				, b.IP	AS IP
				, 0		AS LeagueID
				, CASE WHEN c.ProductID = 8 THEN fnc.GameId ELSE 0 END AS MatchID
				, ''	AS MatchCode
				, ''	AS Race
				, b.winlostdate AS eventdate
				, 0		AS HomeID
				, 0		AS AwayID		
				, 0		AS Betstatus
				, CONVERT(BIT,0) AS IsNeutral
				, '' 	AS showtime
				, CASE WHEN ( c.ProductID IN (12) AND b.gameid IN ( 1701,1702 )  )
					THEN b.Gameid3rd 
					ELSE '' 
				END AS betcheck
				, 0	AS comstatus
				, '' AS transdesc
			FROM dbo.translog AS b WITH (NOLOCK)
				INNER JOIN #tempCust c 
				ON b.translogid		= c.transid
					AND b.custid	= c.custid
				CROSS APPLY (
					SELECT TOP 1 GameId, ChoiceId
					FROM (
						SELECT GameId, ChoiceId 
						FROM [dbo].[f_ParseTransDesc](b.transdesc, b.gameid)
						UNION
						SELECT '' AS GameId, '' AS ChoiceId 
					) AS tmp
				) AS fnc
			WHERE c.WhTicket 		= 0
				AND c.EventType		= 0
		END
		/*	- SportsBook			: ProductId = 1 -> Metric Gaming bettype(801-899)
		*/
		IF (EXISTS ( SELECT TOP 1 1 FROM #tempCust WHERE WhTicket = 0 AND EventType = 1))
		BEGIN
			INSERT INTO #MemBetTicket
			SELECT
				b.translogid AS transid
				, b.translogid AS refno
				, b.custid
				, b.username
				, m.sporttype
				, b.gameid AS bettype
				, 0 AS betid
				, '' AS betteam
				, 0 AS hdp1
				, 0 AS hdp2

				, 0 AS OddsType 
				, b.odds 
				, 0 AS modds
				, b.stake 
				, b.actual_stake
				, b.status 
				, b.transdate
				, b.winlostdate			
				, 0 AS winlost
				, 0 AS awinlost
				, 0 AS mwinlost
				, 0 AS swinlost
				, 0 AS PlayerComm
				, 0 AS comm
				, 0 AS acomm
				, 0 AS scomm
				, b.apsitiontaking
				, b.mpositiontaking
				, b.spositiontaking
				, b.discount
				, b.adiscount
				, b.sdiscount
				, 0 AS Liveindicator
				, 0 AS Livehomescore
				, 0 AS Liveawayscore
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
				, ISNULL(m.showtime,'') AS showtime
				, '' AS betcheck
				, CASE WHEN b.comstatus = '1' 
						THEN '1' 
					ELSE '0' 
				END		AS comstatus
				,b.transdesc
			FROM dbo.translog AS b WITH (NOLOCK)
				INNER JOIN #tempCust c 
				ON b.translogid		= c.transid
					AND b.custid	= c.custid
				INNER JOIN dbo.match m WITH(NOLOCK)
				ON b.eventid		= m.matchid
			WHERE c.WhTicket 		= 0
				AND c.EventType		= 1
		END
	END
	
	-- CHECK for selecting from bettrans
	IF (EXISTS ( SELECT TOP 1 1 FROM #tempCust WHERE WhTicket = 1))
	BEGIN
		/*	- Mix & System Parlay	: ProductId = 1
			- P2P tickets			: ProductId = 9
			- Casino				: ProductId = 6
			- Bingo					: ProductId = 7
			- Keno					: ProductId = 8
			- Gold Delux			: ProductId = 12
		*/
		IF (EXISTS ( SELECT TOP 1 1 FROM #tempCust WHERE WhTicket = 1 AND EventType = 0))
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
				, b.Username
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
				
				, '' 	AS showtime
				, CASE WHEN c.ProductID IN ( 9, 12 ) AND b.bettype IN ( 1000,1701,1702 )
					THEN b.betcheck 
					ELSE ''
				END	AS betcheck
				, CASE WHEN b.comstatus = '1' 
							THEN '1' 
						ELSE '0' 
				END		AS comstatus
				, '' AS transdesc
			FROM dbo.bettrans AS b WITH (NOLOCK)
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
			WHERE	c.WhTicket 		= 1
				AND c.EventType 	= 0
		END
		/* normal tickets 
			- SB		: ProductID = 1
			- NG		: ProductID = 3
			- LC		: ProductID = 4
			- VS		: ProductID = 5
		*/
		IF (EXISTS (SELECT TOP 1 1 FROM #tempCust WHERE WhTicket = 1 AND EventType = 1))
		BEGIN
			INSERT INTO #MemBetTicket
			SELECT
				b.transid
				, b.refno
				, b.custid
				, b.username
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
				, b.odds 
				, b.modds
				, b.stake 
				, b.actual_stake
				, CASE WHEN b.status = 'running' AND ISNULL(b.SecAcceptFlag, 0) = 1 AND ISNULL(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
					ELSE b.status 
				END AS status
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
				, ISNULL(m.showtime,'') AS showtime
				, CASE WHEN (c.ProductId = 1 AND b.bettype IN (216,217)) 
						THEN b.betcheck 
						ELSE '' 
					END	AS betcheck
				, CASE WHEN b.comstatus = '1' 
						THEN '1' 
					ELSE '0' 
				END		AS comstatus
				, CASE WHEN b.bettype BETWEEN 801 AND 899 THEN b.transdesc ELSE '' END AS transdesc
			FROM dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN dbo.match AS m WITH (NOLOCK) 
				ON b.matchid		= m.matchid 		
				INNER JOIN #tempCust c 
				ON b.transid		= c.transid
					AND b.custid	= c.custid
				
			WHERE c.WhTicket 		= 1
				AND c.EventType 	= 1
		END
		/* 
			- SB outright	: ProductID = 1
			- HR tickets	: ProductID = 2
		*/
		IF (EXISTS (SELECT TOP 1 1 FROM #tempCust WHERE WhTicket = 1 AND EventType = 2))
		BEGIN
			INSERT INTO #MemBetTicket
			SELECT
				b.transid
				, b.refno
				, b.custid
				, b.username
				, l.sporttype
				, b.bettype
				, ISNULL(b.BetID,0)
				, '' AS Betteam
				, 0 AS hdp1 
				, 0 AS hdp2 
				, 0 AS OddsType
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
				, '' AS showtime
				, '' AS betcheck
				, CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END AS comstatus				
				, '' AS transdesc
				
			FROM dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN dbo.Outright AS m WITH (NOLOCK) 
				ON b.matchid		= m.orid
				INNER JOIN dbo.League AS l WITH (NOLOCK) 
				ON m.leagueID		= l.leagueID
				INNER JOIN #tempCust c 
				ON b.transid		= c.transid
					AND b.custid	= c.custid
			WHERE c.EventType		= 2
				AND c.WhTicket 		= 1
		END
		
		IF (EXISTS (SELECT TOP 1 1 FROM #tempCust WHERE WhTicket = 1 AND EventType = 3))
		BEGIN
			INSERT INTO #MemBetTicket
			SELECT
				b.transid
				, b.refno
				, b.custid
				, b.username
				, r.Sporttype
				, b.Bettype
				, ISNULL(b.BetID,0)
				, '' AS betteam
				, b.hdp1
				, b.hdp2
				, 0 AS OddsType
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
				, r.EventTime AS showtime
				, '' AS betcheck
				, CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END AS comstatus
				, '' AS transdesc
				
			FROM dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN dbo.VSOutright o WITH (NOLOCK) 
				ON b.oddsid			= o.Orid
				INNER JOIN dbo.VSRaceInfo r WITH (NOLOCK) 
				ON r.EventID		= o.EventID
				INNER JOIN #tempCust c 
				ON b.transid		= c.transid
					AND b.custid	= c.custid

			WHERE c.EventType		= 3
				AND c.WhTicket 		= 1
		END
	END
	
	-- CHECK for selecting from bettrans14
	IF (EXISTS (SELECT TOP 1 1 FROM #tempCust WHERE WhTicket = 2))
	BEGIN
		EXEC [dbo].[Age_CoreBetList_BetTicket_SelMainInfo14]
	END
	
	-- OUTPUT main ticket
	SELECT *
	FROM #MemBetTicket t
	ORDER BY t.transid DESC
			
	IF ( EXISTS (SELECT TOP 1 1 
			FROM #tempCust c
			WHERE c.ProductId IN (2, 5, 4, 12)
		)
	)
	BEGIN
		EXEC [dbo].[Age_CoreBetList_BetTicket_SelDetail]
	END
	
	-- OUTPUT ticket detail
	SELECT * 
	FROM #BettransDetail d
	ORDER BY d.refno DESC
	
	DROP TABLE #MemBetTicket;
	DROP TABLE #BettransDetail;
	RETURN;
END
GO
GRANT EXECUTE ON [dbo].[Age_CoreBetList_BetTicket_SelMainInfo] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_CoreBetList_BetTicket_SelMainInfo] TO [bodbDownlineNetView]
GO
