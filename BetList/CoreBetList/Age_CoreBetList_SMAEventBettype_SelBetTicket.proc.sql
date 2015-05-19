USE bodb02
GO

ALTER PROCEDURE [dbo].[Age_CoreBetList_SMAEventBettype_SelBetTicket]
	@CustId 			INT 			= NULL
	, @Username 		VARCHAR(50) 	= NULL
	, @RoleId			INT
	, @MatchId 			INT
	-- PRODUCT - BETTYPE - STATUS
	, @BettypeMatrix	XML 			= NULL
	, @TransStatus		VARCHAR(250) 	= NULL
	, @Language 		VARCHAR(2) 		= 'E'
	, @Liveindicator 	INT 			= 0
	, @Betteam 			NVARCHAR(20)	= NULL
	, @Error			INT 			= 0
	, @ErrorMsg			NVARCHAR(250) = NULL
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
		- Age_BetList_SelRunningByBettypeMatch_Ag
		- Age_BetList_SelRunningByBettypeMatch_MAg
		- Age_BetList_SelRunningByBettypeMatch_SAg
		- Age_BetList_SelWinlossByBettypeMatch_Ag
		- Age_BetList_SelWinlossByBettypeMatch_MAg
		- Age_BetList_SelWinlossByBettypeMatch_SAg
	
*/
BEGIN
	SET NOCOUNT ON;
	
	DECLARE @IsBet14	BIT
	
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
	
	--CHECK bettrans14
	SELECT TOP 1 @IsBet14 = CAST(1 AS BIT) 
	FROM dbo.match14 WITH(NOLOCK) 
	WHERE matchid	= @matchid
	
	SET @IsBet14 = ISNULL(@IsBet14, 0)
	
	IF ( @custid IS NULL )
	BEGIN
		SELECT @custid = custid 
		FROM dbo.customer WITH (nolock) 
		WHERE username = @username
	END
	
	CREATE TABLE #tempCust 
	( 
		transid			BIGINT
		, refno			BIGINT
		, custid 		INT 
		, productId 	INT 
		, eventType		TINYINT 
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
	
	IF( @IsBet14 = 1 )
	BEGIN
		INSERT INTO #MemBetTicket
		EXEC [dbo].[Age_CoreBetList_SMAEventBettype14_SelBetTicket]
			@CustId				= @CustId
			, @RoleId			= @RoleId
			, @MatchId 			= @MatchId
		
		GOTO FetchResult;
		
	END

	IF ( @roleid = 1 )
	BEGIN
		INSERT INTO #tempCust
		SELECT b.transid
			,b.refno
			,b.custid
			,bt.ProductId
			,bt.EventType
		FROM dbo.bettrans b WITH(nolock)
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
			,b.refno
			,b.custid
			,bt.ProductId
			,bt.EventType
		FROM dbo.bettrans b WITH(NOLOCK)
			INNER JOIN #BettypeMatrix bt
			ON b.bettype	= bt.bettype
			INNER JOIN #TransStatus stt
			ON b.statusid	= stt.statusid
		WHERE b.recommend	= @custid
			AND b.matchid	= @matchid
	END
	
	IF ( @roleid = 3 )
	BEGIN
		WITH CteRecommend ( custid )
		AS (
			SELECT custid
			FROM dbo.Customer c WITH(NOLOCK)
			WHERE c.mrecommend 	= @custid
				AND c.roleid 	= 2
		)
		INSERT INTO #tempCust
		SELECT b.transid
			,b.refno
			,b.custid
			,bt.ProductId
			,bt.EventType
		FROM dbo.bettrans b WITH(NOLOCK)
			INNER JOIN CteRecommend c
			ON b.recommend = c.custid
			INNER JOIN #BettypeMatrix bt
			ON b.bettype	= bt.bettype
			INNER JOIN #TransStatus stt
			ON b.statusid	= stt.statusid
		WHERE b.matchid		= @matchid
	END
	
	IF ( @roleid = 4 )
	BEGIN
		WITH CteRecommend ( custid )
		AS (
			SELECT custid
			FROM dbo.Customer c WITH(NOLOCK)
			WHERE c.srecommend 	= @custid
				AND c.roleid 	= 2
		)
		INSERT INTO #tempCust
		SELECT b.transid
			,b.refno
			,b.custid
			,bt.ProductId
			,bt.EventType
		FROM dbo.bettrans b WITH(NOLOCK)
			INNER JOIN CteRecommend c
			ON b.recommend = c.custid
			INNER JOIN #BettypeMatrix bt
			ON b.bettype	= bt.bettype
			INNER JOIN #TransStatus stt
			ON b.statusid	= stt.statusid
		WHERE b.matchid		= @matchid
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
			, CASE WHEN ( c.ProductID = 1 AND b.bettype IN (217, 216) )
				THEN b.betcheck 
				ELSE '' 
			END		AS betcheck
			, CASE WHEN b.comstatus = '1' 
					THEN '1' 
				ELSE '0' 
			END		AS comstatus
			
		FROM dbo.bettrans b WITH(NOLOCK)
			INNER JOIN #tempCust c
			ON b.transid 		= c.transid
				AND b.custid 	= c.custid
			INNER JOIN dbo.match m WITH (NOLOCK) 
			ON b.matchid		= m.matchid
			
		WHERE c.EventType 		= 1
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
			
		FROM dbo.bettrans b WITH(NOLOCK)
			INNER JOIN #tempCust c
			ON b.transid 		= c.transid
				AND b.custid 	= c.custid
			INNER JOIN dbo.outright m WITH (NOLOCK) 
			ON b.matchid		= m.orid
			INNER JOIN dbo.league l WITH (NOLOCK) 
			ON m.leagueid 		= l.leagueid
			
		WHERE c.EventType 		= 2
	END
	
	-- CHECK liveindicator & betteam
	FetchResult:
	SELECT b.*
	FROM #MemBetTicket b 
	WHERE ( @liveindicator IS NULL OR b.Liveindicator = CASE WHEN b.sporttype = 161 THEN @liveindicator ELSE b.liveindicator END )
		AND ( LEN(b.betteam) = 0 OR (b.betteam = CASE WHEN b.sporttype = 161 THEN @betteam ELSE b.betteam END) )
	ORDER BY b.transid DESC
	
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
	
	IF EXISTS(SELECT TOP 1 1 FROM #BettypeMatrix WHERE ProductID IN( 4 ))
	BEGIN
		IF (@IsBet14 = 0)
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
			FROM dbo.bettransg bg with (NOLOCK)
				INNER JOIN #MemBetTicket b 
				ON bg.refno 	= B.refno
				INNER JOIN #BettypeMatrix bt
				ON b.bettype 	= bt.bettype
			WHERE bt.ProductId 	IN (4)
		END
		
		IF (@IsBet14 = 1)
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
			FROM dbo.bettransg14 bg with (NOLOCK)
				INNER JOIN #MemBetTicket b 
				ON bg.refno 	= B.refno
				INNER JOIN #BettypeMatrix bt
				ON b.bettype = bt.bettype
			WHERE bt.ProductId 	IN (4)
		END
	END
	
	SELECT *
	FROM @BettransDetail bd
	ORDER BY bd.refno DESC
	
	DROP TABLE #MemBetTicket;
	RETURN;
END
GO
GRANT EXECUTE ON [dbo].[Age_CoreBetList_SMAEventBettype_SelBetTicket] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_CoreBetList_SMAEventBettype_SelBetTicket] TO [bodbDownlineNetView]
GO

