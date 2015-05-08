USE [bodb02]
GO
/****** Object:  StoredProcedure [dbo].[Age_BetList_CoreMem_SelBetTicket]    Script Date: 5/5/2015 1:45:13 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[Age_BetList_CoreMemTransDate_SelBetTicket]
(
	-- MEM INFO
	@CustId 			INT
	, @Username			NVARCHAR(30)
	, @FromDate			DATE
	, @ToDate 			DATE
	, @Error			INT = 0 OUTPUT
	, @ErrorMsg			VARCHAR(250) = '' OUTPUT
)
AS
/*
	Created: Bobby.Nguyen
	Task : Aphla site - refactor betlist core 
	DB: DB053.bodb02
	Original: 

	Revisions:
		- 20150504@Bobby.Nguyen: Create new SP
	
	Param's Explanation:
		- @BettypeMatrix	: XML.format(<BettypeMatrix><row ProductID="1" Bettype="1" EventType="1" /></BettypeMatrix>)
		- @TransStatus		: string formation (0,1,102,103,111,112,113)
		- @SelDateType		: 0 - winlosdate | 1 - transdate
*/
BEGIN
	SET NOCOUNT ON;
	
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
		, HomeID 			INT
		, AwayID 			INT 	
		, Betstatus 		NVARCHAR(50)
		, isNeutral 		BIT
		
		, showtime 			NVARCHAR(50)
		, betcheck 			NVARCHAR(50)
		, comstatus 		NVARCHAR(20)
	)
	
	-- do selecting from bettrans
	/*	- Mix & System Parlay	: ProductId = 1
		- P2P tickets			: ProductId = 9
		- Casino				: ProductId = 6
		- Bingo					: ProductId = 7
		- Keno					: ProductId = 8
		- Gold Delux			: ProductId = 12
	*/
	IF( EXISTS(SELECT TOP 1 1 FROM #BettypeMatrix s WHERE s.EventType IN (0)) )
	BEGIN
		PRINT 0
		--INSERT INTO #MemBetTicket
		SELECT
			CASE WHEN bt.ProductID = 1 THEN 
					CASE WHEN ISNULL(b.betid,0) = 0 
						THEN b.TransID 
						ELSE b.betid 
					END
				ELSE b.transid
			END							AS transid
			, b.refno
			, b.custid
			, @Username					AS Username
			, CASE	WHEN bt.ProductID = 9 THEN 253 
					WHEN bt.ProductID = 6 THEN 251
					WHEN bt.ProductID = 7 THEN 252
					WHEN bt.ProductID = 8 THEN 202
					WHEN bt.ProductID = 12 THEN 255
					ELSE 0
			END							AS Sporttype
			
			, b.bettype
			, ISNULL(b.BetID,0)
			, CASE WHEN bt.ProductID = 1
						THEN b.Betteam 
					WHEN bt.ProductID = 8
						THEN fnc.ChoiceId 
					ELSE '' 
				END						AS Betteam 
			, CASE WHEN bt.ProductID = 1
						THEN b.hdp1 
					ELSE 0
				END						AS hdp1
			, CASE WHEN bt.ProductID = 1
						THEN b.hdp2 
					ELSE 0 
				END						AS hdp2
			--, 0 AS OddsType
			, CASE WHEN bt.ProductID = 8
					THEN b.OddsType
				ELSE 0
			END		AS OddsType
			--, b.Odds 
			, CASE WHEN bt.ProductID IN ( 1, 8 )
						THEN b.Odds 
					ELSE 0 
				END						AS Odds
			--, b.modds
			, CASE WHEN bt.ProductID IN ( 1 )
						THEN b.modds 
					ELSE 0 
				END						AS modds
			, b.Stake
			, b.actual_stake 
			, b.Status				
			, b.Transdate
			, b.winlostdate						
			, (b.winlost-actual_stake)	AS winlost
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
				
			, CASE WHEN bt.ProductID = 1
					THEN b.Liveindicator
				ELSE 0
			END		AS Liveindicator
			, CASE WHEN bt.ProductID = 1 
					THEN b.Livehomescore
				ELSE 0
			END		AS Livehomescore
			, CASE WHEN bt.ProductID = 1 
					THEN b.Liveawayscore
				ELSE 0
			END		AS Liveawayscore
			, 0 	AS finalhomescore 	
			, 0 	AS finalawayscore 	 
			, 0 	AS hthomescore 		
			, 0 	AS htawayscore 		 
			, b.IP	AS IP
			, 0		AS LeagueID
			,CASE WHEN bt.ProductID = 8 
					THEN fnc.GameId
				ELSE 0
			END		AS MatchID
			, ''	AS MatchCode
			, ''	AS Race
			, 0		AS HomeID
			, 0		AS AwayID		
			, 0		AS Betstatus
			, CONVERT(BIT,0) AS IsNeutral
			
			, '' 	AS showtime
			, CASE WHEN bt.ProductID IN ( 9, 12 )
						THEN b.betcheck 
					ELSE ''
			END		AS betcheck
			, CASE WHEN b.comstatus = '1' 
						THEN '1' 
					ELSE '0' 
			END		AS comstatus
			
		--FROM dbo.bettrans AS b WITH (NOLOCK, INDEX=IX_custid_matchid_bettype)
		FROM dbo.bettrans AS b WITH (NOLOCK)
			INNER JOIN #BettypeMatrix bt 
			ON b.bettype		= bt.Bettype
			INNER JOIN #TransStatus st
			ON b.statusID		= st.StatusID
			CROSS APPLY (
				SELECT TOP 1 GameId, ChoiceId
				FROM (
					SELECT GameId, ChoiceId 
					FROM [dbo].[f_ParseTransDesc](b.transdesc, b.bettype)
					UNION
					SELECT 0 AS GameId, 0 AS ChoiceId 
				) AS tmp
			) AS fnc
		WHERE	b.transdate	BETWEEN @fromdate AND @todate 
			--AND	b.recommend		= @Recommend 
			AND	b.custid		= @CustID
			AND b.matchid		IN (0, 9, 29, 1000) 
			AND (bt.ProductID	IN (1, 6, 7, 8, 9, 12) AND bt.EventType	= 0)
	END

	/* normal tickets 
		- SB		: ProductID = 1
		- NG		: ProductID = 3
		- LC		: ProductID = 4
		- VS		: ProductID = 5
	*/
	IF( EXISTS(SELECT TOP 1 1 FROM #BettypeMatrix s WHERE s.EventType IN (1)) )
	BEGIN
		PRINT 1
		--INSERT INTO #MemBetTicket
		SELECT
			b.transid
			, b.refno
			, b.custid
			, @Username AS username
			, m.Sporttype
			, b.Bettype
			, ISNULL(b.BetID,0)
			, b.betteam
			, CASE WHEN bt.ProductID IN (4) THEN 0
					ELSE b.hdp1
			END		AS hdp1
			, CASE WHEN bt.ProductID IN (3, 4) THEN 0
					ELSE b.hdp2
			END		AS hdp2

			, b.OddsType 
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
			, m.HomeID
			, m.AwayID 		
			, m.Betstatus
			, ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral
			, ISNULL(m.showtime,'') AS showtime
			, CASE WHEN ( bt.ProductID = 1 AND b.bettype IN (217, 216) )
				THEN b.betcheck 
				ELSE '' 
			END		AS betcheck
			, CASE WHEN b.comstatus = '1' 
					THEN '1' 
				ELSE '0' 
			END		AS comstatus
			
		--FROM dbo.bettrans AS b WITH (NOLOCK, INDEX=IX_custid_matchid_bettype)
		FROM dbo.bettrans AS b WITH (NOLOCK)
			INNER JOIN dbo.MATCH AS m WITH (NOLOCK) 
			ON b.matchid		= m.matchid 		
			INNER JOIN #BettypeMatrix bt 
			ON b.bettype		= bt.Bettype
			INNER JOIN #TransStatus st
			ON b.statusID		= st.StatusID
		WHERE	b.transdate	BETWEEN @fromdate AND @todate 
			--AND	b.recommend		= @Recommend 
			AND	b.custid		= @CustID
			AND (bt.ProductID	IN (1, 3, 4, 5) AND bt.EventType = 1)
	END

	/* 
		- SB outright	: ProductID = 1
		- HR tickets	: ProductID = 2
	*/
	IF( EXISTS(SELECT TOP 1 1 FROM #BettypeMatrix s WHERE s.EventType IN (2)) )
	BEGIN
		PRINT 2
		--INSERT INTO #MemBetTicket
		SELECT
			b.transid
			, b.refno
			, b.custid
			, @Username AS username
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
			, m.TeamID AS HomeID
			, 0 AS AwayID		
			, 0 AS Betstatus
			, CONVERT(BIT,0) AS IsNeutral
			, '' AS showtime
			, '' AS betcheck
			, CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END AS comstatus				
			
		--FROM dbo.bettrans AS b WITH (NOLOCK, INDEX=IX_custid_matchid_bettype)
		FROM dbo.bettrans AS b WITH (NOLOCK)
			INNER JOIN dbo.Outright AS m WITH (NOLOCK) 
			ON b.matchid		= m.orid
			INNER JOIN dbo.League AS l WITH (NOLOCK) 
			ON m.leagueID		= l.leagueID
			INNER JOIN #BettypeMatrix bt 
			ON b.bettype		= bt.Bettype
			INNER JOIN #TransStatus st
			ON b.statusID		= st.StatusID
		WHERE	b.transdate	BETWEEN @fromdate AND @todate 
			--AND	b.recommend		= @Recommend 
			AND	b.custid		= @CustID
			AND (bt.ProductID	IN (1, 2) AND bt.EventType	= 2)
	END

	/* VS tickets 
		- VS			: ProductID = 3
	*/
	IF( EXISTS(SELECT TOP 1 1 FROM #BettypeMatrix s WHERE s.EventType IN (3)) )
	BEGIN
		PRINT 3
		--INSERT INTO #MemBetTicket
		SELECT
			b.transid
			, b.refno
			, b.custid
			, @Username AS username 
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
			, o.RacerID AS homeID
			, 0 AS awayID		
			, '' AS Betstatus
			, CONVERT(BIT,0) AS IsNeutral	
			, r.EventTime AS showtime
			, '' AS betcheck
			, CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END AS comstatus

		--FROM dbo.bettrans AS b WITH (NOLOCK, INDEX=IX_custid_matchid_bettype)
		FROM dbo.bettrans AS b WITH (NOLOCK)
			INNER JOIN VSOutright o with (NOLOCK) 
			ON b.oddsid			= o.Orid
			INNER JOIN VSRaceInfo r WITH (NOLOCK) 
			ON r.EventID		= o.EventID
			INNER JOIN #BettypeMatrix bt 
			ON b.bettype		= bt.Bettype
			INNER JOIN #TransStatus st
			ON b.statusID		= st.StatusID

		WHERE b.transdate	BETWEEN @fromdate AND @todate 
			--AND	b.recommend		= @Recommend 
			AND	b.custid		= @CustID
			AND (bt.ProductID	IN (5) AND bt.EventType	= 3)
	END
	
	-- RETURN main tickets		
	SELECT tk.*
	FROM #MemBetTicket tk
	
	DROP TABLE #MemBetTicket
	
	RETURN;
END
