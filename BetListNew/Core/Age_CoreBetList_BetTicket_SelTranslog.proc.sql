USE [bodb02]
GO
/****** Object:  StoredProcedure [dbo].[Age_CoreBetList_Mem_SelBetTicket]    Script Date: 5/11/2015 10:31:30 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[Age_CoreBetList_BetTicket_SelTranslog]
AS
/*
Created: Bobby.Nguyen
Task : Re-factor core bet list
DB: DBAGE.bodb02
Original: 

Revisions:
	- 20150504@Bobby.Nguyen: Create new SP

Param's Explanation:
	
Dependences:
	- Age_CoreBetList_BetTicket_SelMainInfo
*/
BEGIN
	SET NOCOUNT ON;		
	/* 	CHECK for selecting from translog
		- Keno			: ProductId = 8
		- GoldDelux		: ProductId = 12
		- SportsBook	: ProductId = 1 
			+ Metric Gaming bettype(801-899)
	*/	
	IF (EXISTS (SELECT TOP 1 1 FROM #tempCust WHERE WhTicket = 0))
	BEGIN
		/*	- Keno				: ProductId = 8
			- Gold Delux		: ProductId = 12
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
				, 0 			AS oddsid
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
					
				, 0 AS APositiontaking
				, b.MPositiontaking
				, b.SPositiontaking
				, b.TPositiontaking
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
				,CASE 	WHEN c.ProductID = 8 	THEN fnc.GameId
						WHEN c.ProductID = 12 	THEN 255
					ELSE 0
				END		AS MatchID
				, ''	AS MatchCode
				, ''	AS Race
				, b.winlostdate AS eventdate
				, 0		AS HomeID
				, 0		AS AwayID		
				, 0		AS Betstatus
				, CONVERT(BIT,0) AS IsNeutral
				,'' AS Placing
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
				OUTER APPLY [dbo].[f_ParseTransDesc](b.transdesc, b.gameid) fnc
				
			WHERE c.WhTicket 		= 0
				AND c.EventType		= 0
				AND b.StatusID		IN (0,1)
		END
		/*	
			- SportsBook		: ProductId = 1 -> Metric Gaming bettype(801-899)
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
				, CASE WHEN b.gameid IN (801,803,804,805,806) THEN CONVERT(TINYINT, ISNULL(b.custom1, 0))  ELSE 0 END AS OddsType 
				, 0 AS oddsid
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
				, 0 AS apsitiontaking
				, b.mpositiontaking
				, b.spositiontaking
				, b.TPositiontaking
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
				,'' AS Placing
				, ISNULL(m.showtime,'') AS showtime
				, '' AS betcheck
				, 0 AS comstatus
				,b.transdesc
				
			FROM dbo.translog AS b WITH (NOLOCK)
				INNER JOIN #tempCust c 
				ON b.translogid		= c.transid
					AND b.custid	= c.custid
				INNER JOIN dbo.match m WITH(NOLOCK)
				ON b.eventid		= m.matchid
			WHERE c.WhTicket 		= 0
				AND c.EventType		= 1
				AND b.StatusID		IN (0,1)
		END
	END
	
	RETURN;
END
GO
GRANT EXECUTE ON [dbo].[Age_CoreBetList_BetTicket_SelTranslog] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_CoreBetList_BetTicket_SelTranslog] TO [bodbDownlineNetView]
GO
