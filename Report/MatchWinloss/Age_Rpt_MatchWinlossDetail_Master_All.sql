/*<info serverAlias="DBAGE-bodb02" executers="wsv_nap,wsv_alp,wsv_alpv" isFunction="0" isNested="1"></info>*/
ALTER PROCEDURE [dbo].[Age_Rpt_MatchWinlossDetail_Master_All] 
	@CustID			INT,
	@fromdate		SMALLDATETIME, 
	@todate			SMALLDATETIME,
	@MoveBetsDay	SMALLDATETIME,
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
		- 20171020@Percy: Get data from league3rd table [RedmineID: #84690]
		- 20181003@Patrick: Index revolution [RedmineID: #101405]
		- 20181116@Patrick: Revise code to use index correctly on bettrans14 [RedmineId: #104853]
		- 20190826@Percy: Remove inactive products [RedmineID: #118699]
		- 20191030@Percy: Prevent divide by 0 [RedmineID: #118699]
		- 20200622@Sol: Archive VSRaceInfo - changed to use VSRaceInfo14 [RedmineID: #135963]
		- 20201201@Malcolm : Support Leap Gaming [RedminedId : #131375]
		- 20201229@Malcolm : Support Happy 5 Linked Games [RedminedId : #146542]
		- 20210305@Malcolm: Gather child matchs into a match (for cricket AIO)  - [RedminedId : #148454]
		- 20210823@Sol: Alpha - Allow more time to transfer (phase 2b) - [RedmineID: #160440]
		- 20221229@Bobby: Enhance GrossComm figure [RedmineID: #182155]
		- 20240104@Lewis: Add LeagueGroupId [Redmine: #197160]
		- 20240711@Lewis: Add VS5 - EventType = 5 [RedmineID: #206527]
*/

BEGIN
	SET NOCOUNT ON;

	-- for Parlay
	DECLARE @showSB	BIT,
			@showVS	BIT,
			@showNG BIT

	SELECT	@showSB = CASE WHEN PATINDEX('%,1,%', ',' + @ProductIds + ',') > 0 THEN 1 ELSE 0 END,
			@showVS = CASE WHEN PATINDEX('%,5,%', ',' + @ProductIds + ',') > 0 THEN 1 ELSE 0 END,
			@showNG = CASE WHEN PATINDEX('%,3,%', ',' + @ProductIds + ',') > 0 THEN 1 ELSE 0 END;

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
		showtime		NVARCHAR(50),
		LeagueType		INT
	);

	CREATE TABLE #SportBettype(
		ProductID	INT,
		Bettype		INT,
		EventType	INT,
		RefTable	TINYINT
	);

	----- Get sport bettype-------
	----- Check SP Version
	DECLARE @isTest BIT = 0;
	SELECT  @isTest = dbo.f_CheckSPVersion(@@PROCID);

	SELECT @ProductIds = dbo.f_AddRelatedProducts(@ProductIds);

	INSERT INTO #SportBettype (ProductID, Bettype, EventType, RefTable)
	SELECT ISNULL(p.GroupProductId, s.ProductID), Bettype, EventType, s.RefTable
	FROM dbo.f_SportBettypeMatrixByProduct(@ProductIds, @isTest) s
		LEFT JOIN dbo.f_GroupProduct() p ON s.ProductID = p.ProductId;

	---- End get sport bettype ----

	BEGIN
		-- Get all leagues by sport's selected
		IF @tdate > @MoveBetsDay
		BEGIN
			IF @FromDate <= @MoveBetsDay
			BEGIN
				SET @FDate = DATEADD(DD, 1, @MoveBetsDay);
			END

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
					SUM(CASE 
						WHEN s.RefTable IN (1,2) THEN 0 
						WHEN tpositiontaking = 1 THEN 0 
						ELSE scomm/(1 - tpositiontaking) 
					END) AS GrossComm,
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
				AND b.winlostdate BETWEEN @FDate AND @TDate
				AND m.eventstatus = 'completed' 
				AND ISNULL(m.betstatus,'') <> 'refund'					
				AND b.statusID NOT IN (101, 102, 103)
				AND b.ruben = 1
				AND s.ProductID = 3													
			GROUP BY m.matchid, m.ParentID, m.ChildMatchType, m.homeid, m.awayid, b.bettype, m.leagueid, m.matchcode, m.isNeutral, b.liveindicator;
			
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
					SUM(CASE 
						WHEN s.RefTable IN (1,2) THEN 0 
						WHEN tpositiontaking = 1 THEN 0 
						ELSE scomm/(1 - tpositiontaking) 
					END) AS GrossComm,
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
				AND b.winlostdate BETWEEN @FDate AND @TDate
				AND m.eventstatus = 'completed'
				AND ISNULL(m.betstatus,'') <> 'refund'
				AND b.Bettype < 19001
				AND b.bettype NOT IN (9, 29, 10)
				AND b.statusID NOT IN (101, 102, 103)
				AND b.ruben = 1
				AND s.ProductID <> 3
				AND s.EventType NOT IN (3,5) --- exclude VS HR	+ VS5				
			GROUP BY m.matchid, m.ParentID, m.ChildMatchType, m.homeid, m.awayid, m.leagueid, m.matchcode, m.isNeutral,m.showtime,
				CASE WHEN ISNULL(f.bettype,0) = 0 THEN b.bettype ELSE f.GroupTypeId END;
			
			
			-- match3rd
			INSERT INTO #SAgMatchWLDetails(BetGroup, matchid, ParentID, ChildMatchType, homeid, awayid, bettype, liveindicator, leagueid, turnover, GrossComm, MemberWinLoss, MemberComm, AgWinLoss, AgComm, MAgWinLoss, MAgComm, SAgWinLoss, SAgComm, race, matchcode, isNeutral, showtime, LeagueType)
			SELECT  0 AS BetGroup,
					m.Match3rdId,
					0 AS ParentID,
					0 AS ChildMatchType,
					m.homeid,
					m.awayid,
					CASE WHEN ISNULL(f.bettype,0) = 0 THEN b.bettype ELSE f.GroupTypeId END AS bettype,
					0 AS liveindicator,
					m.League3rdId,
					SUM(ABS(stake)) AS turnover,
					SUM(CASE 
						WHEN s.RefTable IN (1,2) THEN 0 
						WHEN tpositiontaking = 1 THEN 0 
						ELSE scomm/(1 - tpositiontaking) 
					END) AS GrossComm,
					SUM(winlost - actual_stake) AS MemberWinLoss,
					SUM(playercomm) AS MemberComm,
					SUM(awinlost) AS AgWinLoss,
					SUM(comm - playercomm) AS  AgComm,
					SUM(mwinlost) AS MAgWinLoss,
					SUM(acomm - comm) AS  MAgComm,
					SUM(swinlost) AS SAgWinLoss,
					SUM(scomm - acomm) AS SAgComm,
					'' AS race,
					l.LeagueCode AS matchcode,
					0 AS IsNeutral,
					ISNULL(m.StartTime,'') as showtime,
					1 AS LeagueType
			FROM dbo.bettrans b WITH (NOLOCK)
				INNER JOIN dbo.Match3rd m WITH (NOLOCK) ON m.Match3rdId = b.matchid
				INNER JOIN dbo.League3rd l WITH (NOLOCK) ON l.League3rdId = m.League3rdId
				INNER JOIN #SportBettype s ON b.bettype = s.Bettype 		
				LEFT JOIN (SELECT bettype ,GroupTypeId FROM [dbo].[f_GroupBettype]()) f ON f.bettype = b.bettype
			WHERE b.srecommend = @custid
				AND b.winlostdate BETWEEN @FDate AND @TDate
				AND m.eventstatus = 'completed'
				AND b.statusID NOT IN (101, 102, 103)
				AND b.ruben = 1
				AND s.ProductID = 5
				AND s.EventType = 5
			GROUP BY m.Match3rdId, m.homeid, m.awayid, CASE WHEN ISNULL(f.bettype,0) = 0 THEN b.bettype ELSE f.GroupTypeId END, m.League3rdId, l.LeagueCode,ISNULL(m.StartTime,'')

			--Number game
			IF @showNG = 1
			BEGIN
				INSERT INTO #SAgMatchWLDetails(BetGroup, matchid, ParentID, ChildMatchType, homeid, awayid, bettype, liveindicator, leagueid, turnover, GrossComm, MemberWinLoss, MemberComm, AgWinLoss, AgComm, MAgWinLoss, MAgComm, SAgWinLoss, SAgComm, race, matchcode, isNeutral, showtime)
				SELECT  4 AS BetGroup,
						0 AS matchid,
						0 AS ParentID,
						0 AS ChildMatchType,
						0 AS homeid,
						0 AS awayid,
						b.bettype,
						0 AS liveindicator,
						0 AS leagueid,
						ISNULL(SUM(ABS(stake)), 0) AS turnover,
						ISNULL(SUM(CASE 
							WHEN s.RefTable IN (1,2) THEN 0 
							WHEN tpositiontaking = 1 THEN 0 
							ELSE scomm/(1 - tpositiontaking) 
						END), 0) AS GrossComm,
						ISNULL(SUM(winlost - actual_stake), 0) AS MemberWinLoss,
						ISNULL(SUM(playercomm), 0) AS MemberComm,
						ISNULL(SUM(awinlost), 0) AS AgWinLoss,
						ISNULL(SUM(comm - playercomm), 0) AS  AgComm,
						ISNULL(SUM(mwinlost), 0) AS MAgWinLoss,
						ISNULL(SUM(acomm - comm), 0) AS  MAgComm,
						ISNULL(SUM(swinlost), 0) AS SAgWinLoss,
						ISNULL(SUM(scomm - acomm), 0) AS  SAgComm,
						'' AS race,
						'' AS matchcode,
						CONVERT(BIT,0) AS IsNeutral,
						'' AS showtime
				FROM bettrans b WITH (NOLOCK)
					INNER JOIN #SportBettype s ON s.Bettype = b.bettype
				WHERE b.srecommend = @custid
					AND b.winlostdate BETWEEN @FDate AND @TDate
					AND b.ruben = 1
					AND b.statusID NOT IN (101, 102, 103) 
					AND s.ProductID = 3
					AND s.EventType <> 1
				GROUP BY b.bettype	
				HAVING ISNULL(COUNT(transid), 0) > 0;
			END

			-- Mix Parlay
			IF @showSB = 1
			BEGIN
				INSERT INTO #SAgMatchWLDetails(BetGroup, matchid, ParentID, ChildMatchType, homeid, awayid, bettype, liveindicator, leagueid, turnover, GrossComm, MemberWinLoss, MemberComm, AgWinLoss, AgComm, MAgWinLoss, MAgComm, SAgWinLoss, SAgComm, race, matchcode, isNeutral, showtime)
				SELECT  3 AS BetGroup,
						0 AS matchid,
						0 AS ParentID,
						0 AS ChildMatchType,
						0 AS homeid,
						0 AS awayid,
						b.bettype,
						0 AS liveindicator,
						0 AS leagueid,
						ISNULL(SUM(ABS(stake)), 0) AS turnover,
						ISNULL(SUM(CASE WHEN tpositiontaking = 1 THEN 0 ELSE scomm/(1 - tpositiontaking) END), 0) AS GrossComm,
						ISNULL(SUM(winlost - actual_stake), 0) AS MemberWinLoss,
						ISNULL(SUM(playercomm), 0) AS MemberComm,
						ISNULL(SUM(awinlost), 0) AS AgWinLoss,
						ISNULL(SUM(comm - playercomm), 0) AS  AgComm,
						ISNULL(SUM(mwinlost), 0) AS MAgWinLoss,
						ISNULL(SUM(acomm - comm), 0) AS  MAgComm,
						ISNULL(SUM(swinlost), 0) AS SAgWinLoss,
						ISNULL(SUM(scomm - acomm), 0) AS  SAgComm,
						'' AS race,
						'' AS matchcode,
						CONVERT(BIT,0) AS IsNeutral,
						'' AS showtime
				FROM bettrans b WITH (NOLOCK)
				WHERE b.srecommend = @custid
					AND b.bettype IN (9, 29)
					AND b.winlostdate BETWEEN @FDate AND @TDate
					AND b.ruben = 1
					AND b.statusID NOT IN (101, 102, 103) 
				GROUP BY b.bettype	
				HAVING ISNULL(COUNT(transid), 0) > 0;
			END
		
			-- Outright
			INSERT INTO #SAgMatchWLDetails(BetGroup, matchid, ParentID, ChildMatchType, homeid, awayid, bettype, liveindicator, leagueid, turnover, GrossComm, MemberWinLoss, MemberComm, AgWinLoss, AgComm, MAgWinLoss, MAgComm, SAgWinLoss, SAgComm, race, matchcode, isNeutral, showtime)
			SELECT	(CASE b.bettype WHEN 10 THEN 2 ELSE 1 END) AS BetGroup,		
					0 AS matchid,
					0 AS ParentID,
					0 AS ChildMatchType,
					0 AS homeid,
					0 AS awayid,
					b.bettype,
					0 AS liveindicator,
					m.leagueid,
					SUM(CASE WHEN b.liveawayscore = 0 and b.bettype in(33,43) THEN ABS(b.stake)/2 ELSE ABS(b.stake) END) AS TurnOver,
					ISNULL(SUM(CASE 
						WHEN s.RefTable IN (1,2) THEN 0 
						WHEN tpositiontaking = 1 THEN 0 
						ELSE scomm/(1 - tpositiontaking) 
					END), 0) AS GrossComm,
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
				AND b.winlostdate BETWEEN @FDate AND @TDate
				AND s.ProductID IN (1, 2)
				AND s.EventType = 2
				AND b.ruben = 1
				AND b.statusID NOT IN (101, 102, 103)				
			GROUP BY b.bettype, m.groupmatch, m.leagueid
			HAVING ISNULL(COUNT(transid), 0) > 0;

			IF @showVS = 1 
			BEGIN
				-- Virtual HR		
				INSERT INTO #SAgMatchWLDetails(BetGroup, matchid, ParentID, ChildMatchType, homeid, awayid, bettype, liveindicator, leagueid, turnover, GrossComm, MemberWinLoss, MemberComm, AgWinLoss, AgComm, MAgWinLoss, MAgComm, SAgWinLoss, SAgComm, race, matchcode, isNeutral, showtime, LeagueType)
				SELECT  0 AS BetGroup,
						r.EventID as matchid,
						0 AS ParentID,
						0 AS ChildMatchType,
						0 AS homeid,
						0 AS awayid,
						CASE WHEN ISNULL(f.bettype,0) = 0 THEN b.bettype ELSE f.GroupTypeId END AS bettype,
						0 AS liveindicator,
						r.leagueid,
						SUM(ABS(stake)) AS turnover,
						SUM(CASE 
							WHEN s.RefTable IN (1,2) THEN 0 
							WHEN tpositiontaking = 1 THEN 0 
							ELSE scomm/(1 - tpositiontaking) 
						END) AS GrossComm,
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
						r.EventTime AS showtime,
						1 AS LeagueType
				FROM bettrans b WITH (NOLOCK)
					INNER JOIN VSOutright o WITH (NOLOCK) ON b.oddsid = o.Orid
					INNER JOIN VSRaceInfo r WITH (NOLOCK) ON r.EventID = o.EventID
					LEFT JOIN (SELECT bettype, GroupTypeId FROM [dbo].[f_GroupBettype]()) f ON f.bettype = b.bettype
					INNER JOIN #SportBettype s ON s.Bettype = b.bettype
				WHERE b.srecommend = @custid
					AND b.statusID NOT IN (101, 102, 103)
					AND b.ruben = 1
					AND b.winlostdate BETWEEN @FDate AND @TDate
					AND r.eventstatus = 'completed'
					AND ISNULL(r.betstatus,'') <> 'refund'
					AND s.ProductID = 5
					AND s.EventType = 3		--VS2 (use league3rd)		
				GROUP BY r.LeagueID, r.EventTime, r.eventID, CASE WHEN ISNULL(f.bettype,0) = 0 THEN b.bettype ELSE f.GroupTypeId END;	
				
				INSERT INTO #SAgMatchWLDetails(BetGroup, matchid, ParentID, ChildMatchType, homeid, awayid, bettype, liveindicator, leagueid, turnover, GrossComm, MemberWinLoss, MemberComm, AgWinLoss, AgComm, MAgWinLoss, MAgComm, SAgWinLoss, SAgComm, race, matchcode, isNeutral, showtime)
				SELECT  3 AS BetGroup,
						0 AS matchid,
						0 AS ParentID,
						0 AS ChildMatchType,
						0 AS homeid,
						0 AS awayid,
						b.bettype,
						0 AS liveindicator,
						0 AS leagueid,
						ISNULL(SUM(ABS(stake)), 0) AS turnover,
						ISNULL(SUM(CASE 
							WHEN s.RefTable IN (1,2) THEN 0 
							WHEN tpositiontaking = 1 THEN 0 
							ELSE scomm/(1 - tpositiontaking) 
						END), 0) AS GrossComm,
						ISNULL(SUM(winlost - actual_stake), 0) AS MemberWinLoss,
						ISNULL(SUM(playercomm), 0) AS MemberComm,
						ISNULL(SUM(awinlost), 0) AS AgWinLoss,
						ISNULL(SUM(comm - playercomm), 0) AS  AgComm,
						ISNULL(SUM(mwinlost), 0) AS MAgWinLoss,
						ISNULL(SUM(acomm - comm), 0) AS  MAgComm,
						ISNULL(SUM(swinlost), 0) AS SAgWinLoss,
						ISNULL(SUM(scomm - acomm), 0) AS  SAgComm,
						'' AS race,
						'' AS matchcode,
						CONVERT(BIT,0) AS IsNeutral,
						'' AS showtime
				FROM bettrans b WITH (NOLOCK)
					INNER JOIN #SportBettype s ON s.Bettype = b.bettype
				WHERE b.srecommend = @custid
					AND s.ProductID = 5
					AND s.EventType = 0
					AND b.winlostdate BETWEEN @FDate AND @TDate
					AND b.ruben = 1
					AND b.statusID NOT IN (101, 102, 103) 
				GROUP BY b.bettype
				HAVING ISNULL(COUNT(transid), 0) > 0;	

			END	
		END

		IF @FromDate <= @MoveBetsDay
		BEGIN			
			
			SET @FDate = @FromDate;
			
			IF @ToDate > @MoveBetsDay
			BEGIN
				SET @TDate = @MoveBetsDay;
			END
		
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
					SUM(CASE 
						WHEN s.RefTable IN (1,2) THEN 0 
						WHEN tpositiontaking = 1 THEN 0 
						ELSE scomm/(1 - tpositiontaking) 
					END) AS GrossComm,
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
			WHERE b.winlostdate BETWEEN @FDate AND @TDate
				AND b.srecommend = @CustId
				AND m.eventstatus = 'completed'
				AND ISNULL(m.betstatus,'') <> 'refund'
				AND b.statusID NOT IN (101, 102, 103)
				AND b.ruben = 1
				AND s.ProductID = 3				
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
					SUM(CASE 
						WHEN s.RefTable IN (1,2) THEN 0 
						WHEN tpositiontaking = 1 THEN 0 
						ELSE scomm/(1 - tpositiontaking) 
					END) AS GrossComm,
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
				LEFT JOIN (SELECT bettype, GroupTypeId FROM [dbo].[f_GroupBettype]()) f ON f.bettype = b.bettype
				INNER JOIN #SportBettype s ON b.bettype = s.Bettype
				--INNER JOIN #RecommendList R ON R.recommend = b.recommend			
			WHERE b.winlostdate BETWEEN @FDate AND @TDate
				AND b.srecommend = @CustId
				AND m.eventstatus = 'completed'
				AND ISNULL(m.betstatus,'') <> 'refund'
				AND b.bettype < 19001 
				AND b.bettype NOT IN (9,29,10)
				AND b.statusID NOT IN (101, 102, 103)
				AND b.ruben = 1
				AND s.ProductID <> 3
				AND s.EventType NOT IN (3,5)	--- exclude VS HR	+ VS5				
			GROUP BY m.matchid, m.ParentID, m.ChildMatchType, m.homeid, m.awayid, m.leagueid, m.matchcode, m.isNeutral,showtime,
				CASE WHEN ISNULL(f.bettype,0) = 0 THEN b.bettype ELSE f.GroupTypeId END;

			-- match3rd
			INSERT INTO #SAgMatchWLDetails(BetGroup, matchid, ParentID, ChildMatchType, homeid, awayid, bettype, liveindicator, leagueid, turnover, GrossComm, MemberWinLoss, MemberComm, AgWinLoss, AgComm, MAgWinLoss, MAgComm, SAgWinLoss, SAgComm, race, matchcode, isNeutral, showtime, LeagueType)
			SELECT  0 AS BetGroup,
					m.Match3rdId,
					0 AS ParentID,
					0 AS ChildMatchType,
					m.homeid,
					m.awayid,
					CASE WHEN ISNULL(f.bettype,0) = 0 THEN b.bettype ELSE f.GroupTypeId END AS bettype,
					0 AS liveindicator,
					m.League3rdId,
					SUM(ABS(stake)) AS turnover,
					SUM(CASE 
						WHEN s.RefTable IN (1,2) THEN 0 
						WHEN tpositiontaking = 1 THEN 0 
						ELSE scomm/(1 - tpositiontaking) 
					END) AS GrossComm,
					SUM(winlost - actual_stake) AS MemberWinLoss,
					SUM(playercomm) AS MemberComm,
					SUM(awinlost) AS AgWinLoss,
					SUM(comm - playercomm) AS  AgComm,
					SUM(mwinlost) AS MAgWinLoss,
					SUM(acomm - comm) AS  MAgComm,
					SUM(swinlost) AS SAgWinLoss,
					SUM(scomm - acomm) AS SAgComm,
					'' AS race,
					l.LeagueCode AS matchcode,
					0 AS IsNeutral,
					ISNULL(m.StartTime,'') as showtime,
					1 AS LeagueType
			FROM dbo.bettrans14 b WITH (NOLOCK)
				INNER JOIN dbo.Match3rd14 m WITH (NOLOCK) ON m.Match3rdId = b.matchid
				INNER JOIN dbo.League3rd l WITH (NOLOCK) ON l.League3rdId = m.League3rdId
				INNER JOIN #SportBettype s ON b.bettype = s.Bettype 
				LEFT JOIN (SELECT bettype, GroupTypeId FROM [dbo].[f_GroupBettype]()) f ON f.bettype = b.bettype
			WHERE b.srecommend = @custid
				AND b.winlostdate BETWEEN @FDate AND @TDate
				AND m.eventstatus = 'completed'
				AND b.statusID NOT IN (101, 102, 103)
				AND b.ruben = 1
				AND s.ProductID = 5
				AND s.EventType = 5
			GROUP BY m.Match3rdId, m.homeid, m.awayid, CASE WHEN ISNULL(f.bettype,0) = 0 THEN b.bettype ELSE f.GroupTypeId END, m.League3rdId, l.LeagueCode,ISNULL(m.StartTime,'')

			-- Number Game
			IF @showNG = 1
			BEGIN
				INSERT INTO #SAgMatchWLDetails(BetGroup, matchid, ParentID, ChildMatchType, homeid, awayid, bettype, liveindicator, leagueid, turnover, GrossComm, MemberWinLoss, MemberComm, AgWinLoss, AgComm, MAgWinLoss, MAgComm, SAgWinLoss, SAgComm, race, matchcode, isNeutral, showtime) 
				SELECT  4 AS BetGroup,
						0 AS matchid,
						0 AS ParentID,
						0 AS ChildMatchType,
						0 AS homeid,
						0 AS awayid,
						b.bettype,
						0 AS liveindicator,
						0 AS leagueid,
						ISNULL(SUM(ABS(stake)), 0) AS turnover,
						ISNULL(SUM(CASE 
							WHEN s.RefTable IN (1,2) THEN 0 
							WHEN tpositiontaking = 1 THEN 0 
							ELSE scomm/(1 - tpositiontaking) 
						END), 0) AS GrossComm,
						ISNULL(SUM(winlost - actual_stake), 0) AS MemberWinLoss,
						ISNULL(SUM(playercomm), 0) AS MemberComm,
						ISNULL(SUM(awinlost), 0) AS AgWinLoss,
						ISNULL(SUM(comm - playercomm), 0) AS  AgComm,
						ISNULL(SUM(mwinlost), 0) AS MAgWinLoss,
						ISNULL(SUM(acomm - comm), 0) AS  MAgComm,
						ISNULL(SUM(swinlost), 0) AS SAgWinLoss,
						ISNULL(SUM(scomm - acomm), 0) AS  SAgComm,
						'' AS race,	
						'' AS matchcode,
						CONVERT(BIT, 0) AS IsNeutral,
						'' AS showtime
				FROM bettrans14 b WITH (NOLOCK)
					INNER JOIN #SportBettype s ON s.Bettype = b.bettype
				WHERE b.srecommend = @CustId
					AND b.winlostdate BETWEEN @FDate AND @TDate
					AND b.ruben = 1
					AND b.statusID NOT IN (101, 102, 103)
					AND s.ProductID = 3
					AND s.EventType <> 1
				GROUP BY b.bettype		
				HAVING ISNULL(COUNT(transid),0) > 0;
			END
			-- Mix parlay(14)
			IF @showSB = 1 
			BEGIN
				INSERT INTO #SAgMatchWLDetails(BetGroup, matchid, ParentID, ChildMatchType, homeid, awayid, bettype, liveindicator, leagueid, turnover, GrossComm, MemberWinLoss, MemberComm, AgWinLoss, AgComm, MAgWinLoss, MAgComm, SAgWinLoss, SAgComm, race, matchcode, isNeutral, showtime) 
				SELECT  3 AS BetGroup,
						0 AS matchid,
						0 AS ParentID,
						0 AS ChildMatchType,
						0 AS homeid,
						0 AS awayid,
						b.bettype,
						0 AS liveindicator,
						0 AS leagueid,
						ISNULL(SUM(ABS(stake)), 0) AS turnover,
						ISNULL(SUM(CASE WHEN tpositiontaking = 1 THEN 0 ELSE scomm/(1 - tpositiontaking) END), 0) AS GrossComm,
						ISNULL(SUM(winlost - actual_stake), 0) AS MemberWinLoss,
						ISNULL(SUM(playercomm), 0) AS MemberComm,
						ISNULL(SUM(awinlost), 0) AS AgWinLoss,
						ISNULL(SUM(comm - playercomm), 0) AS  AgComm,
						ISNULL(SUM(mwinlost), 0) AS MAgWinLoss,
						ISNULL(SUM(acomm - comm), 0) AS  MAgComm,
						ISNULL(SUM(swinlost), 0) AS SAgWinLoss,
						ISNULL(SUM(scomm - acomm), 0) AS  SAgComm,
						'' AS race,	
						'' AS matchcode,
						CONVERT(BIT, 0) AS IsNeutral,
						'' AS showtime
				FROM bettrans14 b WITH (NOLOCK)
					--INNER JOIN #RecommendList R ON R.recommend = b.recommend
				WHERE b.bettype IN (9, 29)
					AND b.srecommend = @CustId
					AND b.winlostdate BETWEEN @FDate AND @TDate
					AND b.ruben = 1
					AND b.statusID NOT IN (101, 102, 103)				
				GROUP BY b.bettype		
				HAVING ISNULL(COUNT(transid),0) > 0;
			END
		
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
					--ISNULL(SUM(stake), 0) AS turnover,
					SUM(CASE WHEN b.liveawayscore = 0 AND b.bettype IN(33,43) THEN ABS(b.stake)/2 ELSE ABS(b.stake) END) AS TurnOver,
					ISNULL(SUM(CASE 
						WHEN s.RefTable IN (1,2) THEN 0 
						WHEN tpositiontaking = 1 THEN 0 
						ELSE scomm/(1 - tpositiontaking) 
					END), 0) AS GrossComm,
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
				INNER JOIN outright14 m WITH (NOLOCK) ON m.orid = b.matchid
				INNER JOIN #SportBettype s ON b.bettype = s.Bettype
				--INNER JOIN #RecommendList R ON R.recommend = b.recommend
			WHERE b.winlostdate BETWEEN @FDate AND @TDate
				AND b.srecommend = @CustId
				AND s.ProductID IN (1, 2)
				AND s.EventType = 2
				AND b.ruben=1
				AND b.statusID not in (101, 102, 103)				
			GROUP BY b.bettype, m.groupmatch, m.leagueid
			HAVING ISNULL(COUNT(transid),0) > 0;
		
			IF @showVS = 1 
			BEGIN
				-- Virtual HR		
				INSERT INTO #SAgMatchWLDetails(BetGroup, matchid, ParentID, ChildMatchType, homeid, awayid, bettype, liveindicator, leagueid, turnover, GrossComm, MemberWinLoss, MemberComm, AgWinLoss, AgComm, MAgWinLoss, MAgComm, SAgWinLoss, SAgComm, race, matchcode, isNeutral, showtime, LeagueType) 
				SELECT  0 AS BetGroup,
						r.EventID as matchid,
						0 AS ParentID,
						0 AS ChildMatchType,
						0 AS homeid,
						0 AS awayid,
						CASE WHEN ISNULL(f.bettype, 0) = 0 THEN b.bettype ELSE f.GroupTypeId END AS bettype,
						0 AS liveindicator,
						r.leagueid,
						SUM(ABS(stake)) AS turnover,
						SUM(CASE 
							WHEN s.RefTable IN (1,2) THEN 0 
							WHEN tpositiontaking = 1 THEN 0 
							ELSE scomm/(1 - tpositiontaking) 
						END) AS GrossComm,
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
						r.EventTime AS showtime,
						1 AS LeagueType
				FROM bettrans14 b WITH (NOLOCK)
					INNER JOIN VSOutright14 o WITH (NOLOCK) ON b.oddsid = o.Orid
					INNER JOIN VSRaceInfo14 r WITH (NOLOCK) ON r.EventID = o.EventID
					LEFT JOIN (SELECT bettype, GroupTypeId FROM [dbo].[f_GroupBettype]()) f ON f.bettype = b.bettype
					INNER JOIN #SportBettype s ON b.bettype = s.Bettype
					--INNER JOIN #RecommendList Re ON Re.recommend = b.recommend
				WHERE b.statusID NOT IN (101, 102, 103)
					AND b.ruben = 1
					AND b.srecommend = @CustId
					AND b.winlostdate BETWEEN @FDate AND @TDate
					AND r.eventstatus = 'completed' 
					AND ISNULL(r.betstatus,'') <> 'refund'
					AND s.ProductID = 5
					AND s.EventType = 3			--VS2 (use league3rd)		
				GROUP BY r.LeagueID, r.EventTime, r.eventID, CASE WHEN ISNULL(f.bettype,0) = 0 THEN b.bettype ELSE f.GroupTypeId END;

				INSERT INTO #SAgMatchWLDetails(BetGroup, matchid, ParentID, ChildMatchType, homeid, awayid, bettype, liveindicator, leagueid, turnover, GrossComm, MemberWinLoss, MemberComm, AgWinLoss, AgComm, MAgWinLoss, MAgComm, SAgWinLoss, SAgComm, race, matchcode, isNeutral, showtime)
				SELECT  3 AS BetGroup,
						0 AS matchid,
						0 AS ParentID,
						0 AS ChildMatchType,
						0 AS homeid,
						0 AS awayid,
						b.bettype,
						0 AS liveindicator,
						0 AS leagueid,
						ISNULL(SUM(ABS(stake)), 0) AS turnover,
						ISNULL(SUM(CASE 
							WHEN s.RefTable IN (1,2) THEN 0 
							WHEN tpositiontaking = 1 THEN 0 
							ELSE scomm/(1 - tpositiontaking) 
						END), 0) AS GrossComm,
						ISNULL(SUM(winlost - actual_stake), 0) AS MemberWinLoss,
						ISNULL(SUM(playercomm), 0) AS MemberComm,
						ISNULL(SUM(awinlost), 0) AS AgWinLoss,
						ISNULL(SUM(comm - playercomm), 0) AS  AgComm,
						ISNULL(SUM(mwinlost), 0) AS MAgWinLoss,
						ISNULL(SUM(acomm - comm), 0) AS  MAgComm,
						ISNULL(SUM(swinlost), 0) AS SAgWinLoss,
						ISNULL(SUM(scomm - acomm), 0) AS  SAgComm,
						'' AS race,
						'' AS matchcode,
						CONVERT(BIT,0) AS IsNeutral,
						'' AS showtime
				FROM bettrans14 b WITH (NOLOCK)
					INNER JOIN #SportBettype s ON s.Bettype = b.bettype
				WHERE b.srecommend = @custid
					AND s.ProductID = 5
					AND s.EventType = 0
					AND b.winlostdate BETWEEN @FDate AND @TDate
					AND b.ruben = 1
					AND b.statusID NOT IN (101, 102, 103) 
				GROUP BY b.bettype
				HAVING ISNULL(COUNT(transid), 0) > 0;
				
	
			END		
			
			--DROP TABLE #RecommendList
		END
	END

	SELECT  BetGroup, 
			CASE WHEN ChildMatchType = 200 THEN ParentID ELSE matchid END AS matchid, 
			homeid, 
			awayid, 
			bettype, 
			liveindicator,
			s.leagueid,
			ISNULL(l.LeagueGroupID,0) as LeagueGroupID,
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
			ISNULL(s.LeagueType,0) AS LeagueType -- 0: league, 1: League3rd
	FROM #SAgMatchWLDetails s 
	LEFT JOIN League l  WITH (NOLOCK) ON s.leagueid = l.leagueid
	GROUP BY BetGroup, CASE WHEN ChildMatchType = 200 THEN ParentID ELSE matchid END, homeid, awayid, bettype, liveindicator, s.leagueid, ISNULL(l.LeagueGroupID,0), race, matchcode, isNeutral, showtime,ISNULL(s.LeagueType,0)
	ORDER BY betgroup, CASE WHEN ChildMatchType = 200 THEN ParentID ELSE matchid END, leagueid, race, bettype, liveindicator, matchcode;

	DROP TABLE #SAgMatchWLDetails
	DROP TABLE #SportBettype

	SET NOCOUNT OFF;
END

GO