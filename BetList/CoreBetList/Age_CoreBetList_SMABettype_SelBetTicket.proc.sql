USE bodb02
GO

ALTER PROCEDURE [dbo].[Age_CoreBetList_SMABettype_SelBetTicket]
	@CustId 			INT
	, @RoleId			INT
	, @EventDate		DATETIME		= NULL
	, @Language			VARCHAR(2) = 'E'
	-- PRODUCT - BETTYPE - STATUS
	, @BettypeMatrix	XML 			= NULL
	, @TransStatus		VARCHAR(250) 	= NULL
	, @Error			INT 			= 0
	, @ErrorMsg			NVARCHAR(250) 	= ''
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
		- @EventDate		: Indicate cancelled tickets
		
	Wrapped SP List:
		- Age_BetList_SelRunningByBettype_Ag
		- Age_BetList_SelRunningByBettype_MAg
		- Age_BetList_SelRunningByBettype_SAg
		- Age_BetList_SelDeleted
	
*/
BEGIN
	SET NOCOUNT ON;
	
	-- CHECK TransStatus
	IF ( OBJECT_ID('tempdb..#TransStatus') IS NULL )
	BEGIN
		CREATE TABLE #TransStatus (
			StatusID 		INT
		);
		INSERT INTO #TransStatus
		SELECT CAST(t.Val AS INT) 
		FROM [bodb02].[dbo].[Age_f_SplitString] (@TransStatus, ',') t
	END
	
	-- CHECK BettypeMatrix
	IF ( OBJECT_ID('tempdb..#BettypeMatrix') IS NULL )
	BEGIN
		CREATE TABLE #BettypeMatrix (
			ProductID 		INT
			, Bettype 		INT
			, EventType 	INT
		);
		WITH CteBT (ProductID, Bettype, EventType)
		AS (
			SELECT bt.Col.value('@ProductID'	,'INT')
				, bt.Col.value('@Bettype'		,'INT')
				, bt.Col.value('@EventType'		,'INT')
			FROM  @BettypeMatrix.nodes('//row') bt(Col)
		)
		INSERT INTO #BettypeMatrix
		SELECT *
		FROM CteBT bt
	END
	CREATE TABLE #tempCust 
	( 
		transid			BIGINT
		, refno			BIGINT
		, custid 		INT 
		, productId 	INT 
		, eventType		TINYINT
		, WhTicket		TINYINT
	)
	-- MEMBER
	IF ( @roleid = 1 )
	BEGIN
		INSERT INTO #tempCust
		SELECT b.transid	
			,b.refno
			,b.custid
			,bt.ProductId
			,bt.EventType
			,1 AS WhTicket
		FROM bodb02.dbo.bettrans b WITH(nolock)			
			INNER JOIN #BettypeMatrix bt
			ON b.bettype	= bt.bettype
			INNER JOIN #TransStatus stt
			ON b.statusid	= stt.statusid
		WHERE b.custid 		= @custid
		
	END
	-- AGENT
	IF ( @roleid = 2 )
	BEGIN
		INSERT INTO #tempCust
		SELECT b.transid	
			,b.refno
			,b.custid
			,bt.ProductId
			,bt.EventType
			,1 AS WhTicket
		FROM bodb02.dbo.bettrans b WITH(NOLOCK)
			INNER JOIN bodb02.dbo.Customer c WITH(NOLOCK)
			ON b.recommend 	= c.custid	
			INNER JOIN #BettypeMatrix bt
			ON b.bettype	= bt.bettype
			INNER JOIN #TransStatus stt
			ON b.statusid	= stt.statusid
		WHERE c.recommend 	= @custid
			AND c.roleid 	= 2
	END
	-- MASTER
	IF ( @roleid = 3 )
	BEGIN
		INSERT INTO #tempCust
		SELECT b.transid	
			,b.refno
			,b.custid
			,bt.ProductId
			,bt.EventType
			,1 AS WhTicket
		FROM bodb02.dbo.bettrans b WITH(nolock)
			INNER JOIN bodb02.dbo.Customer c WITH(NOLOCK)
			ON b.recommend 	= c.custid	
			INNER JOIN #BettypeMatrix bt
			ON b.bettype	= bt.bettype			
			INNER JOIN #TransStatus stt
			ON b.statusid	= stt.statusid
		WHERE c.mrecommend 	= @custid
			AND c.roleid 	= 2
	END
	--SUPER
	IF ( @roleid = 4 )
	BEGIN
		INSERT INTO #tempCust
		SELECT b.transid	
			,b.refno
			,b.custid
			,bt.ProductId
			,bt.EventType
			,1 AS WhTicket
		FROM bodb02.dbo.bettrans b WITH(nolock)
			INNER JOIN bodb02.dbo.Customer c WITH(NOLOCK)
			ON b.recommend 	= c.custid	
			INNER JOIN #BettypeMatrix bt
			ON b.bettype	= bt.bettype			
			INNER JOIN #TransStatus stt
			ON b.statusid	= stt.statusid
		WHERE c.srecommend 	= @custid
			AND c.roleid 	= 2
	END
	
	CREATE CLUSTERED INDEX [CIX_tempCust] ON #tempCust (WhTicket, eventType)
	--CALL to get ticket info
	EXEC [dbo].[Age_CoreBetList_BetTicket_SelMainInfo]
	
	DROP TABLE #tempCust;
	
	RETURN;
	/*	- Mix & System Parlay	: ProductId = 1
		- P2P tickets			: ProductId = 9
		- Casino				: ProductId = 6
		- Bingo					: ProductId = 7
		- Keno					: ProductId = 8
		- Gold Delux			: ProductId = 12
	*/
	IF( EXISTS(SELECT TOP 1 1 FROM #tempCust WHERE EventType = 0) )
	BEGIN
		INSERT INTO #MemBetTicket
		SELECT
			CASE WHEN c.ProductID = 1 THEN 
					CASE WHEN ISNULL(b.betid,0) = 0 
						THEN b.TransID 
						ELSE b.betid 
					END
				--WHEN c.ProductID = 6 THEN b.betid
				ELSE b.transid
			END							AS transid
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
			, CASE WHEN c.ProductID IN ( 1, 8 )
						THEN b.modds 
					ELSE 0 
				END						AS modds
			, b.Stake
			, b.actual_stake 
			, b.Status				
			, b.transdate
			, b.winlostdate						
			, 0 AS Winlost
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
			, 0		AS MatchID
			, ''	AS MatchCode
			, ''	AS Race
			, b.winlostdate AS eventdate		
			, 0		AS HomeID
			, 0		AS AwayID		
			, 0		AS Betstatus
			, CONVERT(BIT,0) AS IsNeutral
			
			, '' 	AS showtime
			, CASE WHEN c.ProductID = 9
						THEN b.betcheck 
					ELSE ''
			END		AS betcheck
			, CASE WHEN b.comstatus = '1' 
						THEN '1' 
					ELSE '0' 
			END		AS comstatus
			
		FROM bodb02.dbo.bettrans b WITH(NOLOCK)
			INNER JOIN #tempCust c
			ON b.transid 	= c.transid
			
		WHERE c.EventType 	= 0
	END
	/* Keno & GoldDelux: running tickets 
		- Keno					: ProductId = 8
		- Gold Delux			: ProductId = 12
	*/
	IF ( EXISTS(SELECT TOP 1 1 FROM #TransStatus WHERE StatusId IN (0,1)) 
			AND EXISTS(SELECT TOP 1 1 FROM #BettypeMatrix WHERE ProductID IN (8,12))
	)
	BEGIN
		
		INSERT INTO #MemBetTicket
		SELECT 
			b.translogid 	AS transid
			, b.TransLogId 	AS refno
			, b.custid
			, b.UserName
			, CASE 	WHEN bt.ProductID = 8 THEN 202
					WHEN bt.ProductID = 12 THEN 255
					ELSE 0
				END			AS Sporttype
			, b.GameId 		AS bettype
			, 0 			AS betid
			, CASE WHEN bt.ProductID = 8 THEN fnc.ChoiceId ELSE '' END AS betteam
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
			, CASE WHEN bt.ProductID = 8 THEN fnc.GameId ELSE 0 END AS MatchID
			, ''	AS MatchCode
			, ''	AS Race
			, b.winlostdate AS eventdate
			, 0		AS HomeID
			, 0		AS AwayID		
			, 0		AS Betstatus
			, CONVERT(BIT,0) AS IsNeutral
			, '' 	AS showtime
			, CASE WHEN bt.ProductID = 12 THEN b.Gameid3rd ELSE '' END AS betcheck
			, 0 	AS comstatus
		FROM bodb02.dbo.translog AS b WITH (NOLOCK)
			INNER JOIN #BettypeMatrix bt 
			ON b.gameid		= bt.Bettype
			INNER JOIN #TransStatus st
			ON b.statusID		= st.StatusID
			CROSS APPLY (
				SELECT TOP 1 GameId, ChoiceId
				FROM (
					SELECT GameId, ChoiceId 
					FROM bodb02.[dbo].[f_ParseTransDesc](b.transdesc, bt.bettype)
					UNION
					SELECT '' AS GameId, '' AS ChoiceId 
				) AS tmp
			) AS fnc
		WHERE b.custid		= @CustID
			AND (bt.ProductID	IN (8, 12) AND bt.EventType	= 0)
	END
	/* normal tickets 
		- SB		: ProductID = 1
		- NG		: ProductID = 3
		- LC		: ProductID = 4
		- VS		: ProductID = 5
	*/
	IF( EXISTS(SELECT TOP 1 1 FROM #tempCust WHERE EventType = 1) )
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
			, NULL AS winlostdate			
			
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
			, CASE WHEN ( c.ProductID = 1 AND b.bettype IN (217, 216) )
				THEN b.betcheck 
				ELSE '' 
			END		AS betcheck
			, CASE WHEN b.comstatus = '1' 
					THEN '1' 
				ELSE '0' 
			END		AS comstatus
			
		FROM bodb02.dbo.bettrans b WITH(NOLOCK)
			INNER JOIN #tempCust c
			ON b.transid 	= c.transid
			INNER JOIN bodb02.dbo.match m WITH (NOLOCK) 
			ON b.matchid	= m.matchid
			
		WHERE c.EventType 	= 1
			AND (@EventDate IS NULL OR m.eventdate > @EventDate) --DATEADD(day,-3,CURRENT_TIMESTAMP)
	END
	/* 
		- SB outright	: ProductID = 1
		- HR tickets	: ProductID = 2
	*/
	IF( EXISTS(SELECT TOP 1 1 FROM #tempCust WHERE EventType = 2) )
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
			, NULL AS winlostdate
			
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
			
		FROM bodb02.dbo.bettrans b WITH(NOLOCK)
			INNER JOIN #tempCust c
			ON b.transid 	= c.transid
			INNER JOIN bodb02.dbo.outright m WITH (NOLOCK) 
			ON b.matchid	= m.orid
			INNER JOIN bodb02.dbo.league l WITH (NOLOCK) 
			ON m.leagueid 	= l.leagueid
			
		WHERE c.EventType 	= 2
			AND (@EventDate IS NULL OR m.eventdate > @EventDate) --DATEADD(day,-3,CURRENT_TIMESTAMP)
	END
	
	/* VS tickets 
		- VS			: ProductID = 3
	*/
	IF( EXISTS(SELECT TOP 1 1 FROM #tempCust s WHERE s.EventType IN (3)) )
	BEGIN
		INSERT INTO #MemBetTicket
		SELECT
			b.transid
			, b.refno
			, b.custid
			, b.username 
			, o.Sporttype
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
			, o.LeagueID
			, b.MatchID	
			, o.RacerNum AS MatchCode
			, b.oddsid 	AS Race
			, o.eventdate
			, o.RacerID AS homeID
			, 0 AS awayID		
			, '' AS Betstatus
			, CONVERT(BIT,0) AS IsNeutral	
			, o.EventTime AS showtime
			, '' AS betcheck
			, CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END AS comstatus

		FROM dbo.bettrans AS b WITH (NOLOCK)
			INNER JOIN #tempCust c
			ON b.transid 	= c.transid
			INNER JOIN dbo.VSOutright o (nolock) 
			ON b.oddsid		= o.Orid
			INNER JOIN dbo.VSRaceInfo r WITH (NOLOCK) 
			ON o.EventID 	= r.EventID
			
		WHERE c.EventType	= 3
			AND (@EventDate IS NULL OR o.eventdate > @EventDate) --DATEADD(day,-3,CURRENT_TIMESTAMP)
	END
	
	-- FETCH result
	SELECT m.*
	FROM #MemBetTicket m
	ORDER BY m.transid DESC
	
	/* get more detail ticket
		- HR tickets	: ProductID = 2
		- LC tickets	: ProductID = 4
		- VS tickets	: ProductID = 5
		- GD tickets	: ProductID = 12
	*/
	
	DECLARE @BettransDetail TABLE
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
	
	IF EXISTS(SELECT TOP 1 1 FROM #tempCust WHERE ProductID IN( 4, 12 ))
	BEGIN
		INSERT INTO @BettransDetail
		SELECT 
			bg.refno 
			, bg.odds 
			, bg.stake
			, bg.status 
			, bg.apositiontaking
			, bg.mpositiontaking 
			, bg.spositiontaking
			, bg.bettype
			, bg.betteam 
			, '' AS transdesc
		FROM bodb02.dbo.bettransg bg with (NOLOCK)
			INNER JOIN #MemBetTicket b 
			ON bg.refno 	= b.refno
			INNER JOIN #BettypeMatrix bt
			ON b.bettype 	= bt.bettype
		WHERE bt.ProductId 	= 4
		
		UNION ALL
		SELECT 
			bg.refno 
			, bg.odds 
			, bg.stake
			, bg.status 
			, bg.apositiontaking
			, bg.mpositiontaking 
			, bg.spositiontaking
			, bg.bettype
			, bg.betteam 
			, bg.transdesc
		FROM bodb02.dbo.bettransg bg with (NOLOCK)
			INNER JOIN #MemBetTicket b 
			ON bg.refno 	= b.transid
			INNER JOIN #BettypeMatrix bt
			ON b.bettype 	= bt.bettype
		WHERE bt.ProductId 	= 12
	END
	
	SELECT bd.*
	FROM @BettransDetail bd
	ORDER BY bd.refno DESC
	
	DROP TABLE #MemBetTicket;
	
	RETURN;
END
GO
GRANT EXECUTE ON [dbo].[Age_CoreBetList_SMABettype_SelBetTicket] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_CoreBetList_SMABettype_SelBetTicket] TO [bodbDownlineNetView]
GO