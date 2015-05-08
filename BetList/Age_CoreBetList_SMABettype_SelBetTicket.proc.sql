USE bodb02
GO

ALTER PROCEDURE [dbo].[Age_CoreBetList_SMABettype_SelBetTicket]
	@CustId 			INT
	, @RoleId			INT
	, @BettypeMatrix 	XML = NULL
	, @TransStatus		VARCHAR(100)
	, @Language 		VARCHAR(2) = 'E'
	
	, @Error			INT = 0
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
		- Age_BetList_SelRunningByBettype_Ag
		- Age_BetList_SelRunningByBettype_MAg
		- Age_BetList_SelRunningByBettype_SAg
	
*/
BEGIN
	SET NOCOUNT ON;
		
	CREATE TABLE #TransStatus ()
	
	CREATE TABLE #BettypeMatrix ()
	
	CREATE TABLE #tempCust 
	( 
		transid			BIGINT
		, custid 		INT 
	)
	
	CREATE TABLE #MemBetTicket
	(
		transid					BIGINT
		, custid				INT
		, username				NVARCHAR(30)
		, leagueID				INT
		, sporttype				INT
		, bettype				INT
		, matchid				INT
		, matchcode				NVARCHAR(50)
		, Race					NVARCHAR(20)
		, HomeID				INT
		, awayID				INT
		, hdp1					SMALLMONEY
		, hdp2 					SMALLMONEY
		, odds					SMALLMONEY
		, modds					SMALLMONEY
		, status				NVARCHAR(10)
		, stake					MONEY
		, actual_stake			MONEY
		, winlost				MONEY
		, awinlost				MONEY
		, mwinlost				MONEY
		, swinlost				MONEY
		, playercomm			MONEY
		, comm					MONEY
		, acomm 				MONEY
		, scomm					MONEY
		, transdate				DATETIME
		, winlostdate			DATETIME
		, betteam				NVARCHAR(20)
		, apositiontaking		SMALLMONEY
		, mpositiontaking		SMALLMONEY
		, spositiontaking		SMALLMONEY
		, adiscount				SMALLMONEY
		, mdiscount				SMALLMONEY
		, sdiscount				SMALLMONEY
		, liveindicator			BIT
		, livehomescore			SMALLINT
		, liveawayscore			SMALLINT
		, IP					NVARCHAR(15)
		, betstatus				NVARCHAR(50)
		, IsNeutral				BIT
		, OddsType				TINYINT
		, betid					BIGINT
		, showtime				NVARCHAR(50)
		, refno					BIGINT
		, betcheck				NVARCHAR(50)
		, comstatus				NVARCHAR(20)
	)
	
	-- CHECK for supporting running ticket only
	IF( NOT EXISTS (SELECT TOP 1 1 FROM #TransStatus WHERE StatusId IN(0,1)) )
	BEGIN
		SELECT tk.* 
		FROM #MemBetTicket tk
		
		RETURN;
	END
	
	-- MEMBER
	IF ( @roleid = 1 )
	BEGIN
		INSERT INTO #tempCust
		SELECT b.transid
			,b.custid
		FROM dbo.bettrans_running b WITH(nolock)			
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
		FROM dbo.bettrans_running b WITH(nolock)
			INNER JOIN bodb02.dbo.Customer c WITH(NOLOCK)
			ON b.custid 	= c.custid
			INNER JOIN #BettypeMatrix bt
			ON b.bettype	= bt.bettype
			INNER JOIN #TransStatus stt
			ON b.statusid	= stt.statusid
		WHERE c.recommend 	= @custid
			AND c.roleid 	= @roleid
	END
	-- MASTER
	IF ( @roleid = 3 )
	BEGIN
		INSERT INTO #tempCust
		SELECT b.transid
			,b.custid
		FROM dbo.bettrans_running b WITH(nolock)
			INNER JOIN bodb02.dbo.Customer c WITH(NOLOCK)
			ON b.custid 	= c.custid	
			INNER JOIN #BettypeMatrix bt
			ON b.bettype	= bt.bettype			
			INNER JOIN #TransStatus stt
			ON b.statusid	= stt.statusid
		WHERE c.mrecommend 	= @custid
			AND c.roleid 	= @roleid
	END
	--SUPER
	IF ( @roleid = 4 )
	BEGIN
		INSERT INTO #tempCust
		SELECT b.transid
			,b.custid
		FROM dbo.bettrans_running b WITH(nolock)
			INNER JOIN dbo.Customer c WITH(NOLOCK)
			ON b.custid 	= c.custid
			INNER JOIN #BettypeMatrix bt
			ON b.bettype	= bt.bettype
			INNER JOIN #TransStatus stt
			ON b.statusid	= stt.statusid
		WHERE c.srecommend 	= @custid
			AND c.roleid 	= @roleid
	END
	
	IF( EXISTS(SELECT TOP 1 1 FROM #BettypeMatrix WHERE EventType = 0) )
	BEGIN
		--INSERT INTO #MemBetTicket
		SELECT 
			b.transid
			, b.custid
			, b.username
			, 0 AS leagueId
			, 0 AS sporttype
			, b.bettype
			, 0 AS matchid
			, '' AS matchcode
			, '' AS Race
			, 0 AS homeID
			, 0 AS awayID
			, 0 AS hdp1
			, 0 AS hdp2 
			, b.odds
			, b.modds
			, b.status 
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
			, b.discount 	AS Adiscount
			, b.adiscount 	AS Mdiscount
			, b.sdiscount 	AS Sdiscount	
			, 0 AS liveindicator
			, 0 AS livehomescore
			, 0 AS liveawayscore
			
			, b.IP AS IP
			, m.betstatus
			, ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral
			, 0 AS OddsType
			, b.betid
			, '' AS showtime
			, b.refno
			, '' AS betcheck
			, CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END AS comstatus 
			
		FROM dbo.bettrans_running b WITH(NOLOCK)
			INNER JOIN #tempCust c
			ON b.transid 	= c.transid
			
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
			, CASE WHEN b.bettype IN (216,217) THEN b.betcheck ELSE '' END AS betcheck
			, CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END AS comstatus 
			
		FROM dbo.bettrans_running b WITH(NOLOCK)
			INNER JOIN #tempCust c
			ON b.transid 	= c.transid
			INNER JOIN bodb02.dbo.macth m WITH (NOLOCK) 
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
			, convert(float, b.hdp1) as hdp1
			, convert(float, b.hdp2) as hdp2
			, b.odds
			, b.modds
			, b.status 
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
			, b.livehomescore
			, b.liveawayscore
			
			, b.IP AS IP
			, m.betstatus
			, isnull(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral
			, 0 AS OddsType
			, b.betid
			, 0 AS showtime
			, b.refno
			, '' AS betcheck
			, CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END AS comstatus 
			
		FROM dbo.bettrans_running b WITH(NOLOCK)
			INNER JOIN #tempCust c
			ON b.transid 	= c.transid
			INNER JOIN bodb02.dbo.outright m WITH (NOLOCK) 
			ON b.matchid	= m.orid
			INNER JOIN bodb02.dbo.league l WITH (NOLOCK) 
			ON m.leagueid 	= l.leagueid
	END
	
	-- FETCH result
	SELECT m.*
	FROM #MemBetTicket m
	
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
		FROM bodb02.dbo.bettransg bg with (NOLOCK)
			INNER JOIN #MemBetTicket b 
			ON bg.custid	= b.custid
			AND bg.refno 	= b.refno
			INNER JOIN #BettypeMatrix bt
			ON b.bettype = bt.bettype
		WHERE bt.ProductId 	IN (4)
	END
	
	RETURN;
END
/*
SET NOCOUNT ON
if @custid is null
	select @custid = custid from customer with (nolock) where username = @username

IF exists(SELECT TOP 1 1 FROM Match WITH(NOLOCK) WHERE MatchID=@MatchID)
BEGIN		
	SELECT
		m.sporttype,
		b.username,
		b.bettype,
		m.leagueID,			
		b.transid,
		m.matchcode,
		m.homeID,
		m.awayID,
		convert(float, b.hdp1) AS hdp1, 
		convert(float, b.hdp2) AS hdp2, 
		b.odds,
		b.modds,
		b.status,
		b.stake,
		b.actual_stake,
		(b.winlost-actual_stake) winlost,
		b.awinlost,
		b.mwinlost,
		b.swinlost,
		
		b.playercomm,
		(b.comm - b.playercomm) AS comm,
		(b.acomm - b.comm) AS acomm ,
		(b.scomm - b.acomm) AS scomm,
		
		b.transdate,
		b.winlostdate,
		b.betteam,
		b.apositiontaking,
		b.mpositiontaking,
		b.spositiontaking,	
		b.discount AS Adiscount,
		b.adiscount AS Mdiscount,
		b.sdiscount AS Sdiscount,	
		b.liveindicator,
		b.livehomescore,
		b.liveawayscore,
		b.matchid, 
		b.IP AS IP,
		m.betstatus,
		isnull(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
		b.OddsType,
		b.betid,
		m.showtime,
		b.refno,
		b.betcheck,
		CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END AS comstatus
	FROM
		bettrans b with (nolock) 
		inner join match m with (nolock) on b.matchid=m.matchid 
		LEFT JOIN (SELECT Bettype, GroupTypeId FROM [dbo].[f_GroupBettype_xtest]()) f ON f.bettype = b.bettype				
	WHERE
		b.matchid=@matchid and 
		b.recommend=@custid  and 		
		(b.bettype=@bettype OR GroupTypeId = @bettype ) AND
		b.Liveindicator = CASE WHEN m.sporttype = 161 THEN @liveindicator ELSE b.liveindicator END 
	ORDER BY
		b.status, b.transid
		
	 
	-- IF @bettype between 1101 and 1199
	IF EXISTS(SELECT TOP 1 1 FROM SportBettypeMatrix WITH(NOLOCK) WHERE ProductID = 4 AND bettype = @bettype)
	BEGIN
		--get data from bettransg for bettype 1101
		SELECT 
			bg.refno, 
			bg.odds, 
			bg.stake,
			bg.status ,
			bg.apositiontaking, 
			bg.mpositiontaking, 
			bg.spositiontaking,
			bg.betteam  
		FROM bettransg bg with (NOLOCK)
		INNER JOIN bettrans B ON bg.refno = B.refno
		WHERE	bg.matchid=@matchid and 
				b.recommend=@custid  and 		
				b.bettype=@bettype 
	END

END
ELSE
BEGIN
	SELECT
		m.sporttype,
		b.username,
		b.bettype,
		m.leagueID,			
		b.transid,
		m.matchcode,
		m.homeID,
		m.awayID,
		convert(float, b.hdp1) AS hdp1, 
		convert(float, b.hdp2) AS hdp2, 
		b.odds,
		b.modds,
		b.status,
		b.stake,
		b.actual_stake,
		(b.winlost-actual_stake) winlost,
		b.awinlost,
		b.mwinlost,
		b.swinlost,
		
		b.playercomm,
		(b.comm - b.playercomm) AS comm,
		(b.acomm - b.comm) AS acomm ,
		(b.scomm - b.acomm) AS scomm,
		
		b.transdate,
		b.winlostdate,
		b.betteam,
		b.apositiontaking,
		b.mpositiontaking,
		b.spositiontaking,	
		b.discount AS Adiscount,
		b.adiscount AS Mdiscount,
		b.sdiscount AS Sdiscount,	
		b.liveindicator,
		b.livehomescore,
		b.liveawayscore,
		b.matchid, 
		b.IP AS IP,
		m.betstatus,
		isnull(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
		b.OddsType,
		b.betid,
		m.showtime,
		b.refno,
		b.betcheck,
		CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END AS comstatus
	FROM
		bettrans14 b with (nolock) 
		inner join match14 m with (nolock) on b.matchid=m.matchid 	
		LEFT JOIN (SELECT Bettype, GroupTypeId FROM [dbo].[f_GroupBettype_xtest]()) f ON f.bettype = b.bettype			
	WHERE
		b.matchid=@matchid and 
		b.recommend=@custid  and 		
		(b.bettype=@bettype OR GroupTypeId = @bettype ) AND
		b.Liveindicator= CASE WHEN m.sporttype = 161 THEN @liveindicator ELSE b.liveindicator END 
	ORDER BY
		b.status, b.transid
		
--IF @bettype between 1101 and 1199
IF EXISTS(SELECT TOP 1 1 FROM SportBettypeMatrix WITH(NOLOCK) WHERE ProductID = 4 AND bettype = @bettype)	
	BEGIN
		--get data from bettransg for bettype 1101
		SELECT 
			bg.refno, 
			bg.odds, 
			bg.stake,
			bg.status ,
			bg.apositiontaking, 
			bg.mpositiontaking, 
			bg.spositiontaking,
			bg.betteam  
		FROM bettransg14 bg with (NOLOCK)
		INNER JOIN bettrans14 B ON bg.refno = B.refno
		WHERE	bg.matchid=@matchid and 
				b.recommend=@custid  and 		
				b.bettype=@bettype 
	END
END
*/
GO
GRANT EXECUTE ON [dbo].[Age_BetList_SelWinlossByBettypeMatch_Ag] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_BetList_SelWinlossByBettypeMatch_Ag] TO [bodbDownlineNetView]
GO
GRANT VIEW DEFINITION ON [dbo].[Age_BetList_SelWinlossByBettypeMatch_Ag] TO vnteam
