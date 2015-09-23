USE [bodb_AGE]
GO
/****** Object:  StoredProcedure [dbo].[Age_CoreBetList_Running_SelBetTicket]    Script Date: 5/5/2015 1:45:13 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[Age_CoreBetList_Running_SelBetTicket]
(
	-- MEM INFO
	@CustId 			INT
	, @RoleID			TINYINT
	, @Username			NVARCHAR(30) = NULL
	, @FromDate			DATETIME = NULL
	, @ToDate 			DATETIME = NULL
	--Event
	, @MatchID			INT		= 0
	, @liveindicator	INT 	= NULL
	, @Betteam			NVARCHAR(20) = ''
	-- PRODUCT - BETTYPE - STATUS
	, @BettypeMatrix	[dbo].[TVP_SportBettypeMatrix]	READONLY
	, @Language 		VARCHAR(2) = 'E'
	, @ColumnOutput		VARCHAR(MAX) 	= NULL
	, @Error			INT 			= 0 OUTPUT
	, @ErrorMsg			VARCHAR(250) 	= '' OUTPUT
)
AS
/*
	Created: Bobby.Nguyen
	Task : Aphla site - refactor betlist core 
	DB: DBAGE.bodb02
	Original: 

	Revisions:
		- 20150504@Bobby.Nguyen: Create new SP
		- 20150706@Bobby: Exclude Metric Gaming running ticket from bettrans table
		- 20150814@Bobby: #41600 - Update time range to datetime formation
		- 20150910@Bobby: Enhance performence for SP core. Apply TVP for input parameters
	
	Param's Explanation:
		- @BettypeMatrix	: Table TYPE variable
		
	Wrapped SP List:
		- Age_BetList_SelRunningByDate_Mem
		- Age_BetList_SelRunningByBettype_Ag
		- Age_BetList_SelRunningByBettype_MAg
		- Age_BetList_SelRunningByBettypeMatch_SAg
		
	Scope of tickets:
		- bettrans	: All products - all status
		- translog	: Keno & GD - running status only
*/
BEGIN
	SET NOCOUNT ON;
		
	DECLARE @tempRunning TABLE
	(
		Sporttype smallint
		, custid INT
		, Username nvarchar(20) 
		, Bettype smallint
		, LeagueID int
		, refno bigint
		, TransID bigint
		, BetID bigint
		, MatchCode nvarchar(50)
		, Race nvarchar(20)
		, matchid INT
		, HomeID int
		, AwayID int 
		, hdp1 smallmoney 
		, hdp2 smallmoney 
		, Odds smallmoney 
		, Modds smallmoney 
		, Status nvarchar(10)
		, Stake money 
		, actual_stake money 
		, Transdate datetime
		, Betteam nvarchar(20)
		, APositiontaking smallmoney
		, MPositiontaking smallmoney
		, SPositiontaking smallmoney
		, tpositiontaking smallmoney 
		, Adiscount smallmoney
		, Mdiscount smallmoney
		, Sdiscount smallmoney
		, Liveindicator bit
		, Livehomescore smallint
		, Liveawayscore smallint
		, IP nvarchar(15)
		, isNeutral bit
		, oddstype tinyint
		, showtime nvarchar(50) 
		, comstatus nvarchar(20)	
		, BetCheck nvarchar(50)
		, transdesc	NVARCHAR(300)
		, productid TINYINT
		, eventtype TINYINT
	)
	
	SELECT @Error			= 0
		, @ErrorMsg			= ''
		, @CustID			= ISNULL(@CustID, 0)
		, @MatchID			= ISNULL(@MatchID, 0)
		, @Betteam			= ISNULL(@Betteam, '')
	
	-- CHECK member info
	IF( (@CustID = 0 AND @RoleId = 1)
		AND @UserName IS NOT NULL
	)
	BEGIN
		SELECT @CustID 	= CustID
		FROM bodb02.dbo.custinfo WITH(NOLOCK) 
		WHERE UserName	= @UserName
	END
	
	IF(ISNULL(@CustID, 0) = 0 )
	BEGIN
		SELECT @Error 	= 100
			, @ErrorMsg	= 'The customer was not found.'
			
		RETURN;
	END

	IF(@RoleID = 1)
	BEGIN
		INSERT INTO @tempRunning
		SELECT 
			0 Sporttype
			, b.custid
			, b.Username
			, b.Bettype
			, 0 LeagueID
			, b.refno
			, b.TransID
			, b.BetID
			, '' MatchCode
			, '' Race
			, b.matchid
			, 0 HomeID
			, 0 AwayID
			, b.hdp1
			, b.hdp2
			, b.Odds
			, b.Modds
			,CASE WHEN b.status = 'running' AND IsNull(b.SecAcceptFlag, 0) = 1 and IsNull(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
							 ELSE b.status 
							 END as status
			, b.Stake
			, b.actual_stake
			, b.Transdate
			, b.Betteam
			, b.APositiontaking
			, b.MPositiontaking
			, b.SPositiontaking
			, b.tpositiontaking
			, b.discount as Adiscount --Agent
			, b.adiscount as Mdiscount --Master
			, b.sdiscount as Sdiscount --Super
			, b.Liveindicator
			, b.Livehomescore
			, b.Liveawayscore
			, b.IP
			,CONVERT(BIT,0) IsNeutral
			, b.oddstype
			, '' showtime
			,CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END AS comstatus
			, b.BetCheck
			, ''transdesc
			,bt.productid
			,bt.eventtype
		FROM dbo.bettrans_running b WITH(NOLOCK)
			INNER JOIN @BettypeMatrix bt
			ON b.bettype	= bt.bettype
		WHERE custid		= @custid
			AND b.statusID 	IN (0,1)
			AND b.transdate BETWEEN @fromDate AND @toDate 
	END
	
	IF(@RoleID = 2)
	BEGIN
		INSERT INTO @tempRunning
		SELECT 
			0 Sporttype
			, b.custid
			, b.Username
			, b.Bettype
			, 0 LeagueID
			, b.refno
			, b.TransID
			, b.BetID
			, '' MatchCode
			, '' Race
			, b.matchid
			, 0 HomeID
			, 0 AwayID
			, b.hdp1
			, b.hdp2
			, b.Odds
			, b.Modds
			,CASE WHEN b.status = 'running' AND IsNull(b.SecAcceptFlag, 0) = 1 and IsNull(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
							 ELSE b.status 
							 END as status
			, b.Stake
			, b.actual_stake
			, b.Transdate
			, b.Betteam
			, b.APositiontaking
			, b.MPositiontaking
			, b.SPositiontaking
			, b.tpositiontaking
			, b.discount as Adiscount --Agent
			, b.adiscount as Mdiscount --Master
			, b.sdiscount as Sdiscount --Super
			, b.Liveindicator
			, b.Livehomescore
			, b.Liveawayscore
			, b.IP
			,CONVERT(BIT,0) IsNeutral
			, b.oddstype
			, '' showtime
			,CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END AS comstatus
			, b.BetCheck
			, ''transdesc
			,bt.productid
			,bt.eventtype
		FROM dbo.bettrans_running b WITH(NOLOCK)
			INNER JOIN @BettypeMatrix bt
			ON b.bettype	= bt.bettype
		WHERE recommend		= @custid
			AND bt.SubProduct NOT IN ('MG-SuperLive')
			AND b.statusID 	IN (0,1)
			AND (@matchid = 0 OR b.matchid 	= @matchid)
	END
	
	IF(@RoleID = 3)
	BEGIN
		INSERT INTO @tempRunning
		SELECT 
			0 Sporttype
			, b.custid
			, b.Username
			, b.Bettype
			, 0 LeagueID
			, b.refno
			, b.TransID
			, b.BetID
			, '' MatchCode
			, '' Race
			, b.matchid
			, 0 HomeID
			, 0 AwayID
			, b.hdp1
			, b.hdp2
			, b.Odds
			, b.Modds
			,CASE WHEN b.status = 'running' AND IsNull(b.SecAcceptFlag, 0) = 1 and IsNull(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
							 ELSE b.status 
							 END as status
			, b.Stake
			, b.actual_stake
			, b.Transdate
			, b.Betteam
			, b.APositiontaking
			, b.MPositiontaking
			, b.SPositiontaking
			, b.tpositiontaking
			, b.discount as Adiscount --Agent
			, b.adiscount as Mdiscount --Master
			, b.sdiscount as Sdiscount --Super
			, b.Liveindicator
			, b.Livehomescore
			, b.Liveawayscore
			, b.IP
			,CONVERT(BIT,0) IsNeutral
			, b.oddstype
			, '' showtime
			,CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END AS comstatus
			, b.BetCheck
			, ''transdesc
			,bt.productid
			,bt.eventtype
		FROM dbo.bettrans_running b WITH(NOLOCK)
			INNER JOIN @BettypeMatrix bt
			ON b.bettype	= bt.bettype
		WHERE mrecommend	= @custid
			AND bt.SubProduct NOT IN ('MG-SuperLive')
			AND b.statusID 	IN (0,1)
			AND (@matchid = 0 OR b.matchid 	= @matchid)
	END
	
	IF(@RoleID = 4)
	BEGIN
		INSERT INTO @tempRunning
		SELECT 
			0 Sporttype
			, b.custid
			, b.Username
			, b.Bettype
			, 0 LeagueID
			, b.refno
			, b.TransID
			, b.BetID
			, '' MatchCode
			, '' Race
			, b.matchid
			, 0 HomeID
			, 0 AwayID
			, b.hdp1
			, b.hdp2
			, b.Odds
			, b.Modds
			,CASE WHEN b.status = 'running' AND IsNull(b.SecAcceptFlag, 0) = 1 and IsNull(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
							 ELSE b.status 
							 END as status
			, b.Stake
			, b.actual_stake
			, b.Transdate
			, b.Betteam
			, b.APositiontaking
			, b.MPositiontaking
			, b.SPositiontaking
			, b.tpositiontaking
			, b.discount as Adiscount --Agent
			, b.adiscount as Mdiscount --Master
			, b.sdiscount as Sdiscount --Super
			, b.Liveindicator
			, b.Livehomescore
			, b.Liveawayscore
			, b.IP
			,CONVERT(BIT,0) IsNeutral
			, b.oddstype
			, '' showtime
			,CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END AS comstatus
			, b.BetCheck
			, ''transdesc
			,bt.productid
			,bt.eventtype
		FROM dbo.bettrans_running b WITH(NOLOCK)
			INNER JOIN @BettypeMatrix bt
			ON b.bettype	= bt.bettype
		WHERE srecommend	= @custid
			AND bt.SubProduct NOT IN ('MG-SuperLive')
			AND b.statusID 	IN (0,1)
			AND (@matchid = 0 OR b.matchid 	= @matchid)
			
	END

	/* translog - running tickets
		- Keno 			: ProductId = 8
		- GoldDelux		: ProductId = 12
		- Metric Gaming	: Bettype(801-899)
	*/
	IF(@RoleId 	= 1 
		AND EXISTS(SELECT TOP 1 1 FROM @BettypeMatrix WHERE ProductId IN (8, 12) OR SubProduct IN ('MG-SuperLive')))
	BEGIN
		INSERT INTO @tempRunning
		SELECT 
			CASE 	WHEN bt.ProductID = 8 THEN 202
						WHEN bt.ProductID = 12 THEN 255
						ELSE 0
				END	AS Sporttype
			, b.custid
			, b.Username
			, b.gameid Bettype
			, 0 LeagueID
			, b.translogid refno
			, b.translogid TransID
			, 0 BetID
			, '' MatchCode
			, '' Race
			,CASE WHEN bt.ProductID = 8 THEN fnc.GameId 
					WHEN bt.ProductID = 12 THEN 255 
					ELSE 0 END AS matchid
			, 0 HomeID
			, 0 AwayID
			, 0 hdp1
			, 0 hdp2
			, b.Odds
			, 0 Modds
			, status
			, b.Stake
			, b.actual_stake
			, b.Transdate
			,CASE WHEN bt.ProductID = 8 THEN fnc.ChoiceId 
					ELSE '' END AS betteam
			, b.APositiontaking
			, b.MPositiontaking
			, b.SPositiontaking
			, b.tpositiontaking
			, b.discount as Adiscount --Agent
			, b.adiscount as Mdiscount --Master
			, b.sdiscount as Sdiscount --Super
			, b.Liveindicator
			, 0 Livehomescore
			, 0 Liveawayscore
			, b.IP
			,CONVERT(BIT,0) IsNeutral
			,CASE WHEN b.gameid BETWEEN 801 AND 899 THEN CONVERT(TINYINT, ISNULL(b.custom1, 0))  ELSE 0 END AS OddsType 
			,'' showtime
			,'' comstatus
			,CASE WHEN bt.ProductID = 12 THEN b.Gameid3rd 
					ELSE '' 
				END AS betcheck
			, ''transdesc
			,bt.productid
			,bt.eventtype
		FROM bodb02.dbo.translog b WITH(NOLOCK)
			INNER JOIN @BettypeMatrix bt
			ON b.gameid		= bt.bettype
			OUTER APPLY dbo.f_ParseTransDesc(b.transdesc, b.gameid) fnc
		WHERE custid		= @custid
			AND b.statusID 	IN (0,1)
			AND (
				bt.ProductId	IN (8, 12) 
				OR SubProduct	IN ('MG-SuperLive')
			)
			AND b.transdate BETWEEN @fromDate AND @toDate 
	END
	
	IF(@liveindicator	IS NOT NULL
		OR @Betteam			<> ''
	)
	BEGIN
		DELETE b
		FROM @tempRunning b
			INNER JOIN @BettypeMatrix bt ON b.bettype = bt.bettype
		WHERE (
				@liveindicator IS NOT NULL 
				AND bt.productid = 3
				AND b.Liveindicator <> @liveindicator
			)
			OR (
				@betteam <> '' 
				AND bt.productid = 3
				AND b.betteam <> @betteam
			)
	END

	--CREATE CLUSTERED INDEX CIX_tempRunning ON @tempRunning(eventtype, productid)
	
	--IF(EXISTS(SELECT TOP 1 1 FROM @tempRunning WHERE eventtype = 1))
	--BEGIN
	UPDATE b
	SET sporttype 	= m.sporttype
		,leagueID 	= m.leagueID
		,matchcode 	= m.matchcode
		,homeID		= m.homeID
		,awayID		= m.awayID
		,showtime 	= m.showtime
	FROM @tempRunning b
		INNER JOIN bodb02.dbo.match m ON b.matchid = m.matchid
	WHERE b.eventtype = 1
	--END
	
	--IF(EXISTS(SELECT TOP 1 1 FROM @tempRunning WHERE eventtype = 2))
	--BEGIN	
	UPDATE b
	SET sporttype 	= l.sporttype
		,leagueID 	= m.leagueID
		,matchcode 	= m.matchcode
		,homeID		= m.teamID
		,awayID		= 0
		,showtime 	= ''
	FROM @tempRunning b
		INNER JOIN bodb02.dbo.outright as m with (nolock) 
		on  b.matchid=m.orid
		INNER JOIN bodb02.dbo.league l with (nolock) 
		on m.leagueid = l.leagueid 		
	WHERE b.eventtype = 2
	--END
	
	/*DECLARE @queryOutput NVARCHAR(MAX)
	SET @queryOutput = 'SELECT' 
						+ ' ' + @ColumnOutput 
						+ ' FROM @tempRunning t'
						+ '	ORDER BY t.transid DESC'
	
	EXEC sp_sqlexec @queryOutput
	*/

	SELECT *
	FROM @tempRunning t
	ORDER BY t.transid DESC
	
	-- Get bet detial
	SELECT 
			bm.refno 
			, bm.odds 
			, bm.stake
			, bm.status 
			, bm.apositiontaking
			, bm.mpositiontaking 
			, bm.spositiontaking
			, bm.bettype
			, bm.betteam  
			, '' AS transdesc
		FROM bodb02.dbo.bettransm bm WITH (NOLOCK)
			INNER JOIN @tempRunning b 
			ON bm.refno			= b.transid
			AND bm.bettype		= b.bettype
		WHERE bm.custid			= b.custid
			AND b.ProductId		= 2
			
		UNION ALL
		SELECT 
			bm.refno 
			, bm.odds 
			, bm.stake
			, bm.status 
			, bm.apositiontaking
			, bm.mpositiontaking 
			, bm.spositiontaking
			, bm.bettype
			, bm.betteam  
			, '' AS transdesc
		FROM bodb02.dbo.bettransm bm WITH (NOLOCK)
			INNER JOIN @tempRunning b 
			ON bm.refno			= b.refno
			AND bm.bettype		= b.bettype
		WHERE bm.custid			= b.custid
			AND b.ProductID		= 5

		-- SELECT bettransg
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
			, '' AS transdesc
		FROM bodb02.dbo.bettransg bg WITH (NOLOCK)
			INNER JOIN @tempRunning b
			ON bg.refno			= b.refno
			AND bg.bettype		= b.bettype
		WHERE bg.custid			= b.custid
			AND b.ProductId		= 4

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
		FROM bodb02.dbo.bettransg bg WITH (NOLOCK)
			INNER JOIN @tempRunning b
			ON bg.refno			= b.transid
			AND bg.bettype		= b.bettype
		WHERE bg.custid			= b.custid
			AND b.ProductId		= 12
	
	RETURN;
END
GO
GRANT EXECUTE ON [dbo].[Age_CoreBetList_Running_SelBetTicket] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_CoreBetList_Running_SelBetTicket] TO [bodbDownlineNetView]
GO
