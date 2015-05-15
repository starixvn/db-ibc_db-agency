USE bodb02
GO

ALTER PROCEDURE [dbo].[Age_CoreBetList_SMABettype_SelBetTicket]
	@CustId 			INT
	, @RoleId			INT
	, @Language 		VARCHAR(2) 		= 'E'
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
		
	Wrapped SP List:
		- Age_BetList_SelRunningByBettype_Ag
		- Age_BetList_SelRunningByBettype_MAg
		- Age_BetList_SelRunningByBettype_SAg
	
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
		, custid 		INT 
		, ProductID		INT
		, EventType		TINYINT
	)
	
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
	)
	
	-- MEMBER
	IF ( @roleid = 1 )
	BEGIN
		INSERT INTO #tempCust
		SELECT b.transid
			,b.custid
			,bt.ProductId
			,bt.EventType
		FROM bodb_age.dbo.bettrans_running b WITH(nolock)			
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
			,b.custid
			,bt.ProductId
			,bt.EventType
		FROM bodb_age.dbo.bettrans_running b WITH(nolock)
			INNER JOIN bodb02.dbo.Customer c WITH(NOLOCK)
			ON b.recommend 	= c.custid
			INNER JOIN #BettypeMatrix bt
			ON b.bettype	= bt.bettype
			INNER JOIN #TransStatus stt
			ON b.statusid	= stt.statusid
		WHERE c.custid 		= @custid
			AND c.roleid 	= @roleid
	END
	-- MASTER
	IF ( @roleid = 3 )
	BEGIN
		INSERT INTO #tempCust
		SELECT b.transid
			,b.custid
			,bt.ProductId
			,bt.EventType
		FROM bodb_age.dbo.bettrans_running b WITH(nolock)
			INNER JOIN bodb02.dbo.Customer c WITH(NOLOCK)
			ON b.mrecommend = c.custid	
			INNER JOIN #BettypeMatrix bt
			ON b.bettype	= bt.bettype			
			INNER JOIN #TransStatus stt
			ON b.statusid	= stt.statusid
		WHERE c.custid 		= @custid
			AND c.roleid 	= @roleid
	END
	--SUPER
	IF ( @roleid = 4 )
	BEGIN
		WITH CteRecommend ( recommend )
		AS (
			SELECT custid
			FROM bodb02.dbo.Customer c WITH(NOLOCK)
			WHERE c.srecommend 	= @custid
				AND c.roleid 	= 2
		)
		INSERT INTO #tempCust
		SELECT b.transid
			,b.custid
			,bt.ProductId
			,bt.EventType
		FROM bodb02.dbo.bettrans b WITH(nolock)
			INNER JOIN CteRecommend c WITH(NOLOCK)
			ON b.recommend 	= c.recommend
			INNER JOIN #BettypeMatrix bt
			ON b.bettype	= bt.bettype
			INNER JOIN #TransStatus stt
			ON b.statusid	= stt.statusid
	END
	/*	- Mix & System Parlay	: ProductId = 1
		- P2P tickets			: ProductId = 9
		- Casino				: ProductId = 6
		- Bingo					: ProductId = 7
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
				WHEN c.ProductID = 6 THEN b.betid
				ELSE b.transid
			END							AS transid
			, b.refno
			, b.custid
			, b.Username
			, CASE	WHEN bt.ProductID = 9 THEN 253 
					WHEN bt.ProductID = 6 THEN 251
					WHEN bt.ProductID = 7 THEN 252
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
	END
	
	-- FETCH result
	SELECT m.*
	FROM #MemBetTicket m
	ORDER BY m.transid DESC
	
	/* get more detail ticket
		- HR tickets	: ProductID = 2
		- LC tickets	: ProductID = 4
		- VS tickets	: ProductID = 5
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
	)  
	
	IF EXISTS(SELECT TOP 1 1 FROM #tempCust WHERE ProductID IN( 4 ))
	BEGIN
		INSERT INTO @BettransDetail
		SELECT 
			bg.refno, 
			bg.odds, 
			bg.stake,
			bg.status ,
			bg.apositiontaking, 
			bg.mpositiontaking, 
			bg.spositiontaking,
			bg.bettype,
			bg.betteam  
		FROM bodb02.dbo.bettransg bg with (NOLOCK)
			INNER JOIN #MemBetTicket b 
			ON bg.refno 	= b.refno
			INNER JOIN #BettypeMatrix bt
			ON b.bettype = bt.bettype
		WHERE bt.ProductId 	IN (4)
	END
	
	SELECT bd.*
	FROM @BettransDetail bd
	ORDER BY bd.refno DESC
	
	DROP TABLE #MemBetTicket;
	
	RETURN;
END

GO