USE bodb02
GO

ALTER PROCEDURE [dbo].[Age_CoreBetList_SMACancelled_SelBetTicket]
	@CustId 			INT
	, @RoleId			INT
	, @Language 		VARCHAR(2) 		= 'E'
	, @Error			INT 			= 0
	, @ErrorMsg			NVARCHAR(250) 	= NULL
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
		- dbo.Age_BetList_SelDeleted
*/
BEGIN
	SET NOCOUNT ON;
		
	-- CHECK SMA & temp table
	IF (@custid IS NULL
		OR OBJECT_ID('tempdb..#TransStatus') IS NULL 
		OR OBJECT_ID('tempdb..#BettypeMatrix') IS NULL 
	) 
	BEGIN
		SELECT @Error		= 100
			, @ErrorMsg		= 'Invalid input information.'
			
		RETURN;
	END
	
	CREATE TABLE #tempCust 
	( 
		transid			BIGINT
		, refno			INT
		, custid 		INT 
		, productId 	INT
		, eventType 	TINYINT
	)
	
	-- CREATE output data
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
	
	-- CHECK for supporting cancelled ticket only
	IF( NOT EXISTS (SELECT TOP 1 1 FROM #TransStatus WHERE StatusId IN(101,102)) )
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
		FROM dbo.bettrans b WITH(nolock)
			INNER JOIN dbo.Customer c WITH(NOLOCK)
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
			,b.refno
			,b.custid
			,bt.ProductId
			,bt.EventType
		FROM dbo.bettrans b WITH(nolock)
			INNER JOIN dbo.Customer c WITH(NOLOCK)
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
		INSERT INTO #tempCust
		SELECT b.transid
			,b.refno
			,b.custid
			,bt.ProductId
			,bt.EventType
		FROM dbo.bettrans b WITH(nolock)
			INNER JOIN dbo.Customer c WITH(NOLOCK)
			ON b.srecommend 	= c.custid
			INNER JOIN #BettypeMatrix bt
			ON b.bettype	= bt.bettype
			INNER JOIN #TransStatus stt
			ON b.statusid	= stt.statusid
		WHERE c.custid 		= @custid
			AND c.roleid 	= @roleid
	END
	
	/*	- Keno					: ProductId = 8
		- Gold Delux			: ProductId = 12
	*/
	IF( EXISTS(SELECT TOP 1 1 FROM #tempCust s WHERE s.EventType IN (0)) )
	BEGIN
		PRINT 0
		--INSERT INTO #MemBetTicket
		SELECT
			b.transid
			, b.refno
			, b.custid
			, b.username
			, CASE	WHEN bt.ProductID = 8 THEN 202
					WHEN bt.ProductID = 12 THEN 255
					ELSE 0
			END	AS Sporttype
			
			, b.bettype
			, ISNULL(b.BetID,0)
			, CASE WHEN WHEN bt.ProductID = 8
						THEN fnc.ChoiceId 
					ELSE '' 
			END	AS Betteam 
			, 0	AS hdp1
			, 0 AS hdp2
			, CASE WHEN bt.ProductID = 8
					THEN b.OddsType
				ELSE 0
			END		AS OddsType
			, CASE WHEN bt.ProductID IN ( 8 )
						THEN b.Odds 
					ELSE 0 
				END	AS Odds
			, 0 AS modds
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
				
			, 0	AS Liveindicator
			, 0 AS Livehomescore
			, 0	AS Liveawayscore
			, 0	AS finalhomescore 	
			, 0	AS finalawayscore 	 
			, 0	AS hthomescore 		
			, 0	AS htawayscore 		 
			, b.IP	AS IP
			, 0	AS LeagueID
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
			, CASE WHEN bt.ProductID IN ( 12 )
						THEN b.betcheck 
					ELSE ''
			END		AS betcheck
			, CASE WHEN b.comstatus = '1' 
						THEN '1' 
					ELSE '0' 
			END		AS comstatus
			
		FROM dbo.bettrans AS b WITH (NOLOCK)
			INNER JOIN #tempCust c
			ON b.transid 	= c.transid
			CROSS APPLY (
				SELECT TOP 1 GameId, ChoiceId
				FROM (
					SELECT GameId, ChoiceId 
					FROM [dbo].[f_ParseTransDesc](b.transdesc, b.bettype)
					UNION
					SELECT 0 AS GameId, 0 AS ChoiceId 
				) AS tmp
			) AS fnc
		WHERE c.ProductID 		IN ( 8, 12 ) 
			AND c.EventType 	= 0
	END

	/* normal tickets 
		- SB		: ProductID = 1
		- NG		: ProductID = 3
		- LC		: ProductID = 4
		- VS		: ProductID = 5
	*/
	IF( EXISTS(SELECT TOP 1 1 FROM #tempCust s WHERE s.EventType IN (1)) )
	BEGIN
		PRINT 1;
		WITH CteMatch 
		AS(
			SELECT sporttype, homeid, awayid, leagueid, matchid, matchcode, eventdate, isneutral, showtime 
			FROM dbo.match (nolock) 
			WHERE eventdate > DATEADD(day,-3,CURRENT_TIMESTAMP)
		)
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
			
		FROM dbo.bettrans 		AS b WITH (NOLOCK)
			INNER JOIN CteMatch AS m WITH (NOLOCK) 
			ON b.matchid		= m.matchid 		
			INNER JOIN #tempCust c
			ON b.transid 		= c.transid
			
		WHERE c.ProductID 		IN (1, 3, 4, 5) 
			AND c.EventType 	= 1
	END

	/* 
		- SB outright	: ProductID = 1
		- HR tickets	: ProductID = 2
	*/
	IF( EXISTS(SELECT TOP 1 1 FROM #tempCust s WHERE s.EventType IN (2)) )
	BEGIN
		PRINT 2;
		WITH CteOutright 
		AS(
			SELECT teamid as homeid, leagueid, orid, matchcode, groupmatch, eventdate 
			FROM dbo.outright (nolock) 
			WHERE eventdate > DATEADD(day,-3,CURRENT_TIMESTAMP)
		)
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
			
		FROM dbo.bettrans AS b WITH (NOLOCK)
			INNER JOIN CteOutright AS m WITH (NOLOCK) 
			ON b.matchid		= m.orid
			INNER JOIN dbo.League AS l WITH (NOLOCK) 
			ON m.leagueID		= l.leagueID
			INNER JOIN #tempCust c
			ON b.transid 		= c.transid
		WHERE	c.ProductID		IN (1, 2) 
			AND c.EventType		= 2
	END

	/* VS tickets 
		- VS			: ProductID = 3
	*/
	IF( EXISTS(SELECT TOP 1 1 FROM #tempCust s WHERE s.EventType IN (3)) )
	BEGIN
		PRINT 3;
		WITH CteVSOutright 
		AS(
			SELECT RacerID as homeid, r.LeagueID, o.Orid, eventdate , o.EventID, Placing, SportType, o.RacerNum, r.EventTime
			FROM dbo.VSOutright o (nolock) 
				INNER JOIN dbo.VSRaceInfo r WITH (NOLOCK) 
				ON r.EventID = o.EventID 						
			WHERE EventDate > DATEADD(day,-3,CURRENT_TIMESTAMP)
		)
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
		FROM dbo.bettrans 				AS b WITH (NOLOCK)
			INNER JOIN CteVSOutright 	AS o with (NOLOCK) 
			ON b.oddsid			= o.Orid
			INNER JOIN #tempCust c
			ON b.transid 		= c.transid
		WHERE c.ProductID		IN (5) 
			AND bt.EventType	= 3)
	END
	
	-- FETCH result
	SELECT m.*
	FROM #MemBetTicket m
	ORDER BY m.transid DESC
	
	IF EXISTS(SELECT TOP 1 1 FROM #tempCust WHERE ProductID IN( 4 ))
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
		FROM dbo.bettransg 			AS bg WITH (NOLOCK)
			INNER JOIN #tempCust 	AS b 
			ON bg.custid	= b.custid
			AND bg.refno 	= b.refno
		WHERE b.ProductId 	IN (4)
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
