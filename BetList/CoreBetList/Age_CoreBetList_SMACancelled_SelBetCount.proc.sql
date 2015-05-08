USE bodb02
GO

ALTER PROCEDURE [dbo].[Age_CoreBetList_SMACancelled_SelBetCount]
	@CustId 			INT 			= NULL
	, @Username 		NVARCHAR(30) 	= NULL
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
		- Age_BetList_SelDeleted_UserList_Ag
		- Age_BetList_SelDeleted_UserList_MAg
		- Age_BetList_SelDeleted_UserList_SAg
*/
BEGIN
	SET NOCOUNT ON;
	IF ( @custid IS NULL )
	BEGIN
		SELECT @custid = custid 
		FROM dbo.customer with (nolock) 
		WHERE username = @username
			AND roleid = @roleid
	END
	
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
	
	CREATE TABLE #MemBetCount
	(
		custid 			INT 
		, username		NVARCHAR(30)
		, betcount		INT
	);
	
	CREATE TABLE #tempCust 
	( 
		transid 		BIGINT 
		, custid		INT 
		, productId 	INT
		, eventType 	TINYINT
	)
	
	-- CHECK for supporting cancelled ticket only
	IF( NOT EXISTS (SELECT TOP 1 1 FROM #TransStatus WHERE StatusId IN(101,102)) )
	BEGIN
		SELECT tk.* 
		FROM #MemBetCount tk
		
		RETURN;
	END
	
	-- MEMBER
	IF ( @roleid = 1 )
	BEGIN
		INSERT INTO #tempCust
		SELECT b.transid
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
		WHERE c.custid	 	= @custid
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
		FROM dbo.bettrans b WITH(nolock)
			INNER JOIN dbo.Customer c WITH(NOLOCK)
			ON b.mrecommend 	= c.custid	
			INNER JOIN #BettypeMatrix bt
			ON b.bettype	= bt.bettype			
			INNER JOIN #TransStatus stt
			ON b.statusid	= stt.statusid
		WHERE c.custid 	= @custid
			AND c.roleid 	= @roleid
	END
	--SUPER
	IF ( @roleid = 4 )
	BEGIN
		INSERT INTO #tempCust
		SELECT b.transid
			,b.custid
			,bt.ProductId
			,bt.EventType
		FROM dbo.bettrans b WITH(nolock)
			INNER JOIN dbo.Customer c WITH(NOLOCK)
			ON b.srecommend	= c.custid
			INNER JOIN #BettypeMatrix bt
			ON b.bettype	= bt.bettype
			INNER JOIN #TransStatus stt
			ON b.statusid	= stt.statusid
		WHERE c.custid 	= @custid
			AND c.roleid 	= @roleid
	END
	
	/*	- Keno					: ProductId = 8
		- Gold Delux			: ProductId = 12
	*/
	IF( EXISTS(SELECT TOP 1 1 FROM #tempCust WHERE EventType IN (0)) )
	BEGIN
		PRINT 0
		--INSERT INTO #MemBetCount
		SELECT
			b.custid
			, b.username
			, COUNT(1) AS betcount
			
		FROM dbo.bettrans AS b WITH (NOLOCK)
			INNER JOIN #tempCust c
			ON b.transid 	= c.transid
		WHERE c.ProductID 		IN ( 8, 12 ) 
			AND c.EventType 	= 0
			
		GROUP BY b.custid
			, b.username
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
		--INSERT INTO #MemBetCount
		SELECT
			b.custid
			, b.username
			, COUNT(1) AS betcount
			
		FROM dbo.bettrans 		AS b WITH (NOLOCK)
			INNER JOIN CteMatch AS m WITH (NOLOCK) 
			ON b.matchid		= m.matchid 		
			INNER JOIN #tempCust c
			ON b.transid 		= c.transid
			
		WHERE c.ProductID 		IN (1, 3, 4, 5) 
			AND c.EventType 	= 1
			
		GROUP BY b.custid
			, b.username
			
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
		--INSERT INTO #MemBetCount
		SELECT
			b.custid
			, b.username
			, COUNT(1) AS betcount				
			
		FROM dbo.bettrans AS b WITH (NOLOCK)
			INNER JOIN CteOutright AS m WITH (NOLOCK) 
			ON b.matchid		= m.orid
			INNER JOIN dbo.League AS l WITH (NOLOCK) 
			ON m.leagueID		= l.leagueID
			INNER JOIN #tempCust c
			ON b.transid 		= c.transid
			
		WHERE	c.ProductID		IN (1, 2) 
			AND c.EventType		= 2
			
		GROUP BY b.custid
			, b.username
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
		--INSERT INTO #MemBetCount
		SELECT
			b.custid
			, b.username 
			, COUNT(1) AS betcount
		FROM dbo.bettrans 				AS b WITH (NOLOCK)
			INNER JOIN CteVSOutright 	AS o with (NOLOCK) 
			ON b.oddsid			= o.Orid
			INNER JOIN #tempCust c
			ON b.transid 		= c.transid
		WHERE c.ProductID		IN (5) 
			AND bt.EventType	= 3
			
		GROUP BY b.custid
			, b.username
	END
	
	-- FETCH result
	SELECT b.custid
		, b.username
		, SUM(b.betcount) AS betcount
	FROM #MemBetCount b
	GROUP BY b.custid
		, b.username
	ORDER BY SUM(b.betcount) DESC
	
	RETURN;
END
GO

