/*<info serverAlias="DBAGE-bodb02" executers="bodbAdminNet,bodbDownlineNet,bodbDownlineNetView" isFunction="0" isNested="1"></info>*/
ALTER PROCEDURE [dbo].[Age_Rpt_MatchWinlossDetail_Master_ByLeague] 
	@CustID			INT,
	@FromDate		SMALLDATETIME,
	@ToDate			SMALLDATETIME,
	@MoveBetsDay	SMALLDATETIME,
	@leagueIds		VARCHAR(MAX),
	@ProductIds		VARCHAR(MAX)
AS

/*
	Created: 
	Task : 
	DB: DBAGE.bodb02
	
	Revisions:
		- 20170224@Paul: Create new [RedmineID: #70554]
		- 20170622@Percy: Combine Betradar Virtual Sports with Virtual Sports [RedmineID: #78339]
		- 20170828@Percy: Support Lucky 3 [RedmineID: #76770]
		- 20171003@Percy: Add ruben = 1 to avoid recover tickets [RedmineID: #83356]
		- 20171020@Percy: Add @league3rdIds params to get data from league3rd table [RedmineID: #84690]
		- 20181003@Patrick: Index revolution [RedmineID: #101405]
		- 20181116@Patrick: Revise code to use index correctly on bettrans14 [RedmineId: #104853]
		- 20190826@Percy: Remove inactive products [RedmineID: #118699]
		- 20191030@Percy: Prevent divide by 0 [RedmineID: #118699]
		- 20200622@Sol: Archive VSRaceInfo - changed to use VSRaceInfo14 [RedmineID: #135963]
		- 20210305@Malcolm: Gather child matchs into a match (for cricket AIO)  - [RedminedId : #148454]
*/

BEGIN 
	SET NOCOUNT ON;

	-- for Parlay
	DECLARE @showSB	BIT,
			@showVS	BIT;

	SELECT	@showSB = CASE WHEN PATINDEX('%,1,%', ',' + @ProductIds + ',') > 0 THEN 1 ELSE 0 END,
			@showVS = CASE WHEN PATINDEX('%,5,%', ',' + @ProductIds + ',') > 0 THEN 1 ELSE 0 END;

	---- To avoid parametter sniffing
	DECLARE @FDate SMALLDATETIME, @TDate SMALLDATETIME;
	SELECT @FDate = @fromdate, @TDate= @todate;

	CREATE TABLE #SAgMatchWLDetails(
		BetGroup		INT,
		matchid			INT,
		ParentID		INT,
		ChildMatchType	TINYINT,
		homeid			INT,
		awayid			INT,
		bettype			SMALLINT,
		liveindicator	INT,
		leagueid		INT,
		turnover		MONEY,
		GrossComm		MONEY,
		MemberWinLoss	MONEY,
		MemberComm		MONEY,
		AgWinLoss		MONEY,
		AgComm			MONEY,
		MAgWinLoss		MONEY,
		MAgComm			MONEY,
		SAgWinLoss		MONEY,
		SAgComm			MONEY,
		race			NVARCHAR(20),
		matchcode		NVARCHAR(50),
		isNeutral		BIT,
		showtime		NVARCHAR(50)
	);

	CREATE TABLE #SportBettype(
		ProductID	INT,
		Bettype		INT,
		EventType	INT
	);


	----- Get sport bettype-------
	----- Check SP Version
	DECLARE @isTest BIT = 0
	SELECT  @isTest = dbo.f_CheckSPVersion(@@PROCID)

	SELECT @ProductIds = dbo.f_AddRelatedProducts(@ProductIds);

	INSERT INTO #SportBettype (ProductID, Bettype, EventType)
	SELECT ISNULL(p.GroupProductId, s.ProductID), Bettype, EventType
	FROM dbo.f_SportBettypeMatrixByProduct(@ProductIds, @isTest) s
		LEFT JOIN dbo.f_GroupProduct() p ON s.ProductID = p.ProductId;

	---- End get sport bettype ----

	CREATE TABLE #tmpLeague (LeagueId INT)

	--CREATE TABLE #RecommendList (recommend INT);
		
	--INSERT INTO #RecommendList (recommend)
	--SELECT CustId 
	--FROM dbo.CustInfo WITH (NOLOCK) 
	--WHERE srecommend = @CustId AND RoleId = 2;

	IF ISNULL(@leagueIds, '') <> ''
	BEGIN
		INSERT INTO #tmpLeague (leagueId)
		SELECT leagueId
		FROM dbo.League WITH (NOLOCK)
		WHERE ',' + @leagueIds + ',' LIKE '%,' + CONVERT(VARCHAR(10), leagueId) + ',%'
	
		IF @tdate > @MoveBetsDay
		BEGIN
			INSERT INTO #SAgMatchWLDetails(BetGroup, matchid, ParentID, ChildMatchType, homeid, awayid, bettype, liveindicator, leagueid, turnover, GrossComm, MemberWinLoss, MemberComm, AgWinLoss, AgComm, MAgWinLoss, MAgComm, SAgWinLoss, SAgComm, race, matchcode, isNeutral, showtime)
			SELECT  0 AS BetGroup,
					m.matchid,
					m.ParentID,
					m.ChildMatchType,
					m.homeid,
					m.awayid,
					b.bettype,
					b.liveindicator,
					m.leagueid,
					SUM(ABS(stake)) AS turnover,
					SUM(CASE WHEN tpositiontaking = 1 THEN 0 ELSE scomm/(1 - tpositiontaking) END) AS GrossComm,
					SUM(winlost - actual_stake) AS MemberWinLoss,
					SUM(playercomm) AS MemberComm,
					SUM(awinlost) AS AgWinLoss,
					SUM(comm - playercomm) AS  AgComm,
					SUM(mwinlost) AS MAgWinLoss,
					SUM(acomm - comm) AS  MAgComm,
					SUM(swinlost) AS SAgWinLoss,
					SUM(scomm - acomm) AS SAgComm,
					'' AS race,
					m.matchcode,
					ISNULL(m.isNeutral, CONVERT(BIT, 0)) AS IsNeutral,
					'' AS showtime
			FROM bettrans b WITH (NOLOCK)
				INNER JOIN match m WITH (NOLOCK) ON m.matchid = b.matchid
				INNER JOIN #SportBettype s ON b.bettype = s.Bettype 		
			WHERE b.srecommend = @custid
				AND b.winlostdate >= @fromdate
				AND b.winlostdate <= @todate
				AND m.eventstatus = 'completed' 
				AND ISNULL(m.betstatus,'') <> 'refund'					
				AND b.statusID NOT IN (101, 102, 103)
				AND b.ruben = 1
				AND s.ProductID = 3	
				AND EXISTS (SELECT l.leagueid FROM #tmpLeague l WHERE l.leagueid = m.leagueid)								
			GROUP BY m.matchid, m.ParentID, m.ChildMatchType, m.homeid, m.awayid, b.bettype, m.leagueid, m.matchcode, m.isNeutral, b.liveindicator;
			
			 --- Not number Game not group by liveindicator	
			INSERT INTO #SAgMatchWLDetails(BetGroup, matchid, ParentID, ChildMatchType, homeid, awayid, bettype, liveindicator, leagueid, turnover, GrossComm, MemberWinLoss, MemberComm, AgWinLoss, AgComm, MAgWinLoss, MAgComm, SAgWinLoss, SAgComm, race, matchcode, isNeutral, showtime)
			SELECT  0 AS BetGroup,
					m.matchid,
					m.ParentID,
					m.ChildMatchType,
					m.homeid,
					m.awayid,
					CASE WHEN ISNULL(f.bettype,0) = 0 THEN b.bettype ELSE f.GroupTypeId END AS bettype,
					0 AS liveindicator,
					m.leagueid,
					SUM(ABS(stake)) AS turnover,
					SUM(CASE WHEN tpositiontaking = 1 THEN 0 ELSE scomm/(1 - tpositiontaking) END) AS GrossComm,
					SUM(winlost - actual_stake) AS MemberWinLoss,
					SUM(playercomm) AS MemberComm,
					SUM(awinlost) AS AgWinLoss,
					SUM(comm - playercomm) AS  AgComm,
					SUM(mwinlost) AS MAgWinLoss,
					SUM(acomm - comm) AS  MAgComm,
					SUM(swinlost) AS SAgWinLoss,
					SUM(scomm - acomm) AS  SAgComm,
					'' AS race,
					m.matchcode,
					ISNULL(m.isNeutral, CONVERT(BIT, 0)) AS IsNeutral,
					ISNULL(m.showtime, '') AS showtime
			FROM bettrans b WITH (NOLOCK)
				INNER JOIN match m WITH (NOLOCK) ON m.matchid = b.matchid 	
				LEFT JOIN (SELECT bettype, GroupTypeId FROM [dbo].[f_GroupBettype]()) f ON f.bettype = b.bettype
				INNER JOIN #SportBettype s ON b.bettype = s.Bettype			
			WHERE b.srecommend = @custid				
				AND b.winlostdate >= @fromdate
				AND b.winlostdate <= @todate
				AND m.eventstatus = 'completed'
				AND ISNULL(m.betstatus,'') <> 'refund'
				AND b.Bettype < 19001
				AND b.bettype NOT IN (9, 29, 10)
				AND b.statusID NOT IN (101, 102, 103)
				AND b.ruben = 1
				AND s.ProductID NOT IN (3, 30)
				AND s.EventType NOT IN (3, 5)
				AND EXISTS (SELECT l.leagueid FROM #tmpLeague l WHERE l.leagueid = m.leagueid)
			GROUP BY m.matchid, m.ParentID, m.ChildMatchType, m.homeid, m.awayid, m.leagueid, m.matchcode, m.isNeutral,m.showtime,
				CASE WHEN ISNULL(f.bettype,0) = 0 THEN b.bettype ELSE f.GroupTypeId END;
		
			-- Outright
			INSERT INTO #SAgMatchWLDetails(BetGroup, matchid, ParentID, ChildMatchType, homeid, awayid, bettype, liveindicator, leagueid, turnover, GrossComm, MemberWinLoss, MemberComm, AgWinLoss, AgComm, MAgWinLoss, MAgComm, SAgWinLoss, SAgComm, race, matchcode, isNeutral, showtime)
			SELECT  (CASE b.bettype WHEN 10 THEN 2 ELSE 1 END) AS BetGroup,		
					0 AS matchid,
					0 AS ParentID,
					0 AS ChildMatchType,
					0 AS homeid,
					0 AS awayid,
					b.bettype,
					0 AS liveindicator,
					m.leagueid,
					SUM(CASE WHEN b.liveawayscore = 0 and b.bettype in(33,43) THEN ABS(b.stake)/2 ELSE ABS(b.stake) END) AS TurnOver,
					ISNULL(SUM(CASE WHEN tpositiontaking = 1 THEN 0 ELSE scomm/(1 - tpositiontaking) END), 0) AS GrossComm,
					ISNULL(SUM(winlost - actual_stake), 0) AS MemberWinLoss,
					ISNULL(SUM(playercomm), 0) AS MemberComm,
					ISNULL(SUM(awinlost), 0) AS AgWinLoss,
					ISNULL(SUM(comm - playercomm), 0) AS  AgComm,
					ISNULL(SUM(mwinlost), 0) AS MAgWinLoss,
					ISNULL(SUM(acomm - comm), 0) AS  MAgComm,
					ISNULL(SUM(swinlost), 0) AS SAgWinLoss,
					ISNULL(SUM(scomm - acomm), 0) AS  SAgComm,
					m.groupmatch AS race,	
					'ZZZZ' AS matchcode,
					CONVERT(BIT,0) AS IsNeutral,
					'' AS showtime
			FROM bettrans b WITH (NOLOCK)
				INNER JOIN outright m with (nolock) on m.orid = b.matchid
				INNER JOIN #SportBettype s ON b.bettype = s.Bettype
			WHERE b.srecommend = @custid
				AND b.winlostdate >= @fromdate
				AND b.winlostdate <= @todate
				AND s.ProductID IN (1, 2)
				AND s.EventType = 2
				AND b.ruben = 1
				AND b.statusID NOT IN (101, 102, 103)
				AND EXISTS (SELECT l.leagueid FROM #tmpLeague l WHERE l.leagueid = m.leagueid)
			GROUP BY b.bettype, m.groupmatch, m.leagueid
			HAVING ISNULL(COUNT(transid), 0) > 0;

			IF @showVS = 1 
			BEGIN
				-- Virtual HR		
				INSERT INTO #SAgMatchWLDetails(BetGroup, matchid, ParentID, ChildMatchType, homeid, awayid, bettype, liveindicator, leagueid, turnover, GrossComm, MemberWinLoss, MemberComm, AgWinLoss, AgComm, MAgWinLoss, MAgComm, SAgWinLoss, SAgComm, race, matchcode, isNeutral, showtime)
				SELECT  0 AS BetGroup,
						'' matchid,
						0 AS ParentID,
						0 AS ChildMatchType,
						0 AS homeid,
						0 AS awayid,
						b.bettype,
						0 AS liveindicator,
						r.leagueid,
						SUM(ABS(stake)) AS turnover,
						SUM(CASE WHEN tpositiontaking = 1 THEN 0 ELSE scomm/(1 - tpositiontaking) END) AS GrossComm,
						SUM(winlost - actual_stake) AS MemberWinLoss,
						SUM(playercomm) AS MemberComm,
						SUM(awinlost) AS AgWinLoss,
						SUM(comm - playercomm) AS  AgComm,
						SUM(mwinlost) AS MAgWinLoss,
						SUM(acomm - comm) AS  MAgComm,
						SUM(swinlost) AS SAgWinLoss,
						SUM(scomm - acomm) AS  SAgComm,
						r.EventID AS Race,
						'' matchcode,
						CONVERT (BIT, 0) AS IsNeutral,
						r.EventTime AS showtime
				FROM bettrans b WITH (NOLOCK)
					INNER JOIN VSOutright o WITH (NOLOCK) ON b.oddsid = o.Orid
					INNER JOIN VSRaceInfo r WITH (NOLOCK) ON r.EventID = o.EventID
					INNER JOIN #SportBettype s ON s.Bettype = b.bettype
				WHERE b.srecommend = @custid
					AND b.statusID NOT IN (101, 102, 103)
					AND b.ruben = 1
					AND b.winlostdate >= @fromdate
					AND b.winlostdate <= @todate
					AND o.eventstatus = 'completed'
					AND ISNULL(r.betstatus,'') <> 'refund'
					AND s.ProductID = 5
					AND s.EventType = 3
					AND EXISTS (SELECT l.leagueid FROM #tmpLeague l WHERE l.leagueid = r.leagueid)
				GROUP BY r.LeagueID, r.EventTime, r.eventID, b.bettype;
			END	
		END

		IF @fdate <= @MoveBetsDay
		BEGIN
			INSERT INTO #SAgMatchWLDetails(BetGroup, matchid, ParentID, ChildMatchType, homeid, awayid, bettype, liveindicator, leagueid, turnover, GrossComm, MemberWinLoss, MemberComm, AgWinLoss, AgComm, MAgWinLoss, MAgComm, SAgWinLoss, SAgComm, race, matchcode, isNeutral, showtime)
			SELECT  0 AS BetGroup,
					m.matchid,
					m.ParentID,
					m.ChildMatchType,
					m.homeid,
					m.awayid,
					b.bettype,
					b.liveindicator,
					m.leagueid,
					SUM(ABS(stake)) AS turnover,
					SUM(CASE WHEN tpositiontaking = 1 THEN 0 ELSE scomm/(1 - tpositiontaking) END) AS GrossComm,
					SUM(winlost - actual_stake) AS MemberWinLoss,
					SUM(playercomm) AS MemberComm,
					SUM(awinlost) AS AgWinLoss,
					SUM(comm - playercomm) AS  AgComm,
					SUM(mwinlost) AS MAgWinLoss,
					SUM(acomm - comm) AS  MAgComm,
					SUM(swinlost) AS SAgWinLoss,
					SUM(scomm - acomm) AS  SAgComm,
					'' AS race,	
					m.matchcode,
					ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
					'' AS showtime
			FROM bettrans14 b WITH (NOLOCK)
				INNER JOIN match14 m WITH (NOLOCK) ON m.matchid = b.matchid
				INNER JOIN #SportBettype s ON b.bettype = s.Bettype		
				--INNER JOIN #RecommendList R ON R.recommend = b.recommend
			WHERE b.winlostdate >= @fdate
				AND b.winlostdate <= @tdate
				AND b.srecommend = @CustId
				AND m.eventstatus = 'completed'
				AND ISNULL(m.betstatus,'') <> 'refund'
				AND b.statusID NOT IN (101, 102, 103)
				AND b.ruben = 1
				AND s.ProductID = 3
				AND EXISTS (SELECT l.leagueid FROM #tmpLeague l WHERE l.leagueid = m.leagueid)		
			GROUP BY m.matchid, m.ParentID, m.ChildMatchType, m.homeid, m.awayid, b.bettype, m.leagueid, m.matchcode, m.isNeutral, b.liveindicator;
		
			--- Not number Game not group by liveindicator
			INSERT INTO #SAgMatchWLDetails(BetGroup, matchid, ParentID, ChildMatchType, homeid, awayid, bettype, liveindicator, leagueid, turnover, GrossComm, MemberWinLoss, MemberComm, AgWinLoss, AgComm, MAgWinLoss, MAgComm, SAgWinLoss, SAgComm, race, matchcode, isNeutral, showtime)
			SELECT  0 AS BetGroup,
					m.matchid,
					m.ParentID,
					m.ChildMatchType,
					m.homeid,
					m.awayid,
					CASE WHEN ISNULL(f.bettype, 0) = 0 THEN b.bettype ELSE f.GroupTypeId END AS bettype,
					0 AS liveindicator,
					m.leagueid,
					SUM(ABS(stake)) AS turnover,
					SUM(CASE WHEN tpositiontaking = 1 THEN 0 ELSE scomm/(1 - tpositiontaking) END) AS GrossComm,
					SUM(winlost - actual_stake) AS MemberWinLoss,
					SUM(playercomm) AS MemberComm,
					SUM(awinlost) AS AgWinLoss,
					SUM(comm - playercomm) AS  AgComm,
					SUM(mwinlost) AS MAgWinLoss,
					SUM(acomm - comm) AS  MAgComm,
					SUM(swinlost) AS SAgWinLoss,
					SUM(scomm - acomm) AS  SAgComm,
					'' AS race,	
					m.matchcode,
					ISNULL(m.isNeutral, CONVERT(BIT, 0)) AS IsNeutral,
					ISNULL(m.showtime, '') AS showtime
			FROM bettrans14 b WITH (NOLOCK)
				INNER JOIN match14 m WITH (NOLOCK) ON m.matchid = b.matchid 	
				LEFT JOIN (SELECT * FROM [dbo].[f_GroupBettype]()) f ON f.bettype = b.bettype
				INNER JOIN #SportBettype s ON b.bettype = s.Bettype
				--INNER JOIN #RecommendList R ON R.recommend = b.recommend			
			WHERE b.winlostdate >= @fdate
				AND b.winlostdate <= @tdate
				AND b.srecommend = @CustId
				AND m.eventstatus = 'completed'
				AND ISNULL(m.betstatus,'') <> 'refund'
				AND b.bettype < 19001 
				AND b.bettype NOT IN (9,29,10)
				AND b.statusID NOT IN (101, 102, 103)
				AND b.ruben = 1
				AND s.ProductID NOT IN (3, 30)
				AND s.EventType NOT IN (3, 5)
				AND EXISTS (SELECT l.leagueid FROM #tmpLeague l WHERE l.leagueid = m.leagueid)					
			GROUP BY m.matchid, m.ParentID, m.ChildMatchType, m.homeid, m.awayid, m.leagueid, m.matchcode, m.isNeutral,showtime,
				CASE WHEN ISNULL(f.bettype,0) = 0 THEN b.bettype ELSE f.GroupTypeId END;
		
			---Outright, RB
			INSERT INTO #SAgMatchWLDetails(BetGroup, matchid, ParentID, ChildMatchType, homeid, awayid, bettype, liveindicator, leagueid, turnover, GrossComm, MemberWinLoss, MemberComm, AgWinLoss, AgComm, MAgWinLoss, MAgComm, SAgWinLoss, SAgComm, race, matchcode, isNeutral, showtime)
			SELECT  (CASE b.bettype WHEN 10 THEN 2 ELSE 1 END) AS BetGroup,		
					0 AS matchid,
					0 AS ParentID,
					0 AS ChildMatchType,
					0 AS homeid,
					0 AS awayid,
					b.bettype,
					0 AS liveindicator,
					m.leagueid,
					SUM(CASE WHEN b.liveawayscore = 0 AND b.bettype IN(33,43) THEN ABS(b.stake)/2 ELSE ABS(b.stake) END) AS TurnOver,
					ISNULL(SUM(CASE WHEN tpositiontaking = 1 THEN 0 ELSE scomm/(1 - tpositiontaking) END), 0) AS GrossComm,
					ISNULL(SUM(winlost - actual_stake), 0) AS MemberWinLoss,
					ISNULL(SUM(playercomm), 0) AS MemberComm,
					ISNULL(SUM(awinlost), 0) AS AgWinLoss,
					ISNULL(SUM(comm - playercomm), 0) AS  AgComm,
					ISNULL(SUM(mwinlost), 0) AS MAgWinLoss,
					ISNULL(SUM(acomm - comm), 0) AS  MAgComm,
					ISNULL(SUM(swinlost), 0) AS SAgWinLoss,
					ISNULL(SUM(scomm - acomm), 0) AS  SAgComm,
					m.groupmatch AS race,		
					'ZZZZ' AS matchcode,
					CONVERT(BIT,0) AS IsNeutral,
					'' AS showtime
			FROM bettrans14 b WITH (NOLOCK)
				INNER JOIN outright14 m with (nolock) on m.orid = b.matchid
				INNER JOIN #SportBettype s ON b.bettype = s.Bettype
				--INNER JOIN #RecommendList R ON R.recommend = b.recommend
			WHERE b.winlostdate >= @fdate
				AND b.winlostdate <= @tdate
				AND b.srecommend = @CustId
				AND s.ProductID IN (1, 2)
				AND s.EventType = 2
				AND b.ruben=1
				AND b.statusID NOT IN (101, 102, 103)
				AND EXISTS (SELECT l.leagueid FROM #tmpLeague l WHERE l.leagueid = m.leagueid)
			GROUP BY b.bettype, m.groupmatch, m.leagueid
			HAVING ISNULL(COUNT(transid),0) > 0;
		
			IF @showVS = 1 
			BEGIN
				-- Virtual HR		
				INSERT INTO #SAgMatchWLDetails(BetGroup, matchid, ParentID, ChildMatchType, homeid, awayid, bettype, liveindicator, leagueid, turnover, GrossComm, MemberWinLoss, MemberComm, AgWinLoss, AgComm, MAgWinLoss, MAgComm, SAgWinLoss, SAgComm, race, matchcode, isNeutral, showtime)
				SELECT  0 AS BetGroup,
						'' matchid,
						0 AS ParentID,
						0 AS ChildMatchType,
						0 AS homeid,
						0 AS awayid,
						b.bettype,
						0 AS liveindicator,
						r.leagueid,
						SUM(ABS(stake)) AS turnover,
						SUM(CASE WHEN tpositiontaking = 1 THEN 0 ELSE scomm/(1 - tpositiontaking) END) AS GrossComm,
						SUM(winlost - actual_stake) AS MemberWinLoss,
						SUM(playercomm) AS MemberComm,
						SUM(awinlost) AS AgWinLoss,
						SUM(comm - playercomm) AS  AgComm,
						SUM(mwinlost) AS MAgWinLoss,
						SUM(acomm - comm) AS  MAgComm,
						SUM(swinlost) AS SAgWinLoss,
						SUM(scomm - acomm) AS  SAgComm,						
						r.EventID AS Race,
						'' AS matchcode,
						CONVERT (BIT, 0) AS IsNeutral,
						r.EventTime AS showtime
				FROM bettrans14 b WITH (NOLOCK)
					INNER JOIN VSOutright14 o WITH (NOLOCK) ON b.oddsid = o.Orid
					INNER JOIN VSRaceInfo14 r WITH (NOLOCK) ON r.EventID = o.EventID
					INNER JOIN #SportBettype s ON b.bettype = s.Bettype
					--INNER JOIN #RecommendList Re ON Re.recommend = b.recommend
				WHERE b.statusID NOT IN (101, 102, 103)
					AND b.ruben = 1
					AND b.srecommend = @CustId
					AND b.winlostdate >= @fdate
					AND b.winlostdate <= @tdate
					AND o.eventstatus = 'completed' 
					AND ISNULL(r.betstatus,'') <> 'refund'
					AND s.ProductID = 5
					AND s.EventType = 3	
					AND EXISTS (SELECT l.leagueid FROM #tmpLeague l WHERE l.leagueid = r.leagueid)	
				GROUP BY r.LeagueID, r.EventTime, r.eventID, b.bettype;
			END		
		END
	END

	SELECT  BetGroup, 
			CASE WHEN ChildMatchType = 200 THEN ParentID ELSE matchid END AS matchid, 
			homeid, 
			awayid, 
			bettype, 
			liveindicator,
			leagueid,
			SUM(turnover) AS turnover,
			SUM(GrossComm) AS GrossComm, 
			SUM(MemberWinLoss) AS MemberWinLoss, 
			SUM(MemberComm) AS MemberComm, 
			SUM(AgWinLoss) AS AgWinLoss,
			SUM(AgComm) AS AgComm, 
			SUM(MAgWinLoss) AS MAgWinLoss, 
			SUM(MAgComm) AS MAgComm, 
			SUM(SAgWinLoss) AS SAgWinLoss, 
			SUM(SAgComm) AS SAgComm, 
			race,
			matchcode,	
			isNeutral,
			showtime,
			CASE WHEN matchid < 1000000000 THEN 0 ELSE 1 END AS LeagueType -- 0: league, 1: League3rd
	FROM #SAgMatchWLDetails
	GROUP BY BetGroup, CASE WHEN ChildMatchType = 200 THEN ParentID ELSE matchid END, homeid, awayid, bettype, liveindicator, leagueid, race, matchcode, isNeutral, showtime,
		CASE WHEN matchid < 1000000000 THEN 0 ELSE 1 END
	ORDER BY betgroup, CASE WHEN ChildMatchType = 200 THEN ParentID ELSE matchid END, leagueid, race, bettype, liveindicator, matchcode;

	--DROP TABLE #RecommendList
	DROP TABLE #SAgMatchWLDetails
	DROP TABLE #SportBettype
	DROP TABLE #tmpLeague

	SET NOCOUNT OFF;
END
GO