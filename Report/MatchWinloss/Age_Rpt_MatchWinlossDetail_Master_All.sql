/*<info serverAlias="DBAGE-bodb02" executers="bodbAdminNet,bodbDownlineNet,bodbDownlineNetView" viewers="vnteam" isFunction="0" isNested="1"></info>*/
USE [bodb02]
GO

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
	Original: Age_Rpt_MatchWinlossDetail_SAg_All
	Revisions:
		- 20170224@Paul: Create new [RedmineID: #70554]
		- 20170622@Percy: Combine Betradar Virtual Sports with Virtual Sports [RedmineID: #78339]
		- 20170828@Percy: Support Lucky 3 [RedmineID: #76770]
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
	DECLARE @isTest BIT = 0;
	SELECT  @isTest = dbo.f_CheckSPVersion(@@PROCID);

	SELECT @ProductIds = dbo.f_AddRelatedProducts(@ProductIds);

	INSERT INTO #SportBettype (ProductID, Bettype, EventType)
	SELECT ISNULL(p.GroupProductId, s.ProductID), Bettype, EventType
	FROM dbo.f_SportBettypeMatrixByProduct_Sel(@ProductIds, @isTest) s
		LEFT JOIN dbo.f_GroupProduct() p ON s.ProductID = p.ProductId;

	---- End get sport bettype ----

	BEGIN
		-- Get all leagues by sport's selected
		IF @tdate > @MoveBetsDay
		BEGIN
			INSERT INTO #SAgMatchWLDetails(BetGroup, matchid, homeid, awayid, bettype, liveindicator, leagueid, turnover, GrossComm, MemberWinLoss, MemberComm, AgWinLoss, AgComm, MAgWinLoss, MAgComm, SAgWinLoss, SAgComm, race, matchcode, isNeutral, showtime)
			SELECT  0 AS BetGroup,
					m.matchid,
					m.homeid,
					m.awayid,
					b.bettype,
					b.liveindicator,
					m.leagueid,
					SUM(ABS(stake)) AS turnover,
					SUM(scomm/(1 - tpositiontaking)) AS GrossComm,
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
				AND m.eventdate >= @fromdate
				AND m.eventdate <= @todate
				AND m.eventstatus = 'completed' 
				AND ISNULL(m.betstatus,'') <> 'refund'					
				AND b.statusID NOT IN (101, 102, 103)
				AND s.ProductID = 3													
			GROUP BY m.matchid, m.homeid, m.awayid, b.bettype, m.leagueid, m.matchcode, m.isNeutral, b.liveindicator;
			
			INSERT INTO #SAgMatchWLDetails(BetGroup, matchid, homeid, awayid, bettype, liveindicator, leagueid, turnover, GrossComm, MemberWinLoss, MemberComm, AgWinLoss, AgComm, MAgWinLoss, MAgComm, SAgWinLoss, SAgComm, race, matchcode, isNeutral, showtime)
			SELECT  0 AS BetGroup,
					m.matchid,
					m.homeid,
					m.awayid,
					CASE WHEN ISNULL(f.bettype,0) = 0 THEN b.bettype ELSE f.GroupTypeId END AS bettype,
					0 AS liveindicator,
					m.leagueid,
					SUM(ABS(stake)) AS turnover,
					SUM(scomm/(1 - tpositiontaking)) AS GrossComm,
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
				AND m.eventdate >= @fromdate
				AND m.eventdate <= @todate
				AND m.eventstatus = 'completed'
				AND ISNULL(m.betstatus,'') <> 'refund'
				AND b.Bettype < 19001
				AND b.bettype NOT IN (9, 29, 10)
				AND b.statusID NOT IN (101, 102, 103)
				AND s.ProductID <> 3
				AND s.EventType <> 3 --- exclude VS HR					
			GROUP BY m.matchid, m.homeid, m.awayid, m.leagueid, m.matchcode, m.isNeutral,m.showtime,
				CASE WHEN ISNULL(f.bettype,0) = 0 THEN b.bettype ELSE f.GroupTypeId END;
					
			-- Mix Parlay
			IF @showSB = 1
			BEGIN
				INSERT INTO #SAgMatchWLDetails(BetGroup, matchid, homeid, awayid, bettype, liveindicator, leagueid, turnover, GrossComm, MemberWinLoss, MemberComm, AgWinLoss, AgComm, MAgWinLoss, MAgComm, SAgWinLoss, SAgComm, race, matchcode, isNeutral, showtime)
				SELECT  3 AS BetGroup,
						0 AS matchid,
						0 AS homeid,
						0 AS awayid,
						b.bettype,
						0 AS liveindicator,
						0 AS leagueid,
						ISNULL(SUM(ABS(stake)), 0) AS turnover,
						ISNULL(SUM(scomm/(1 - tpositiontaking)), 0) AS GrossComm,
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
					AND b.winlostdate >= @fromdate
					AND b.winlostdate <= @todate
					AND b.ruben = 1
					AND b.statusID NOT IN (101, 102, 103) 
				GROUP BY b.bettype	
				HAVING ISNULL(COUNT(transid), 0) > 0;
			END
		
			-- Outright
			INSERT INTO #SAgMatchWLDetails(BetGroup, matchid, homeid, awayid, bettype, liveindicator, leagueid, turnover, GrossComm, MemberWinLoss, MemberComm, AgWinLoss, AgComm, MAgWinLoss, MAgComm, SAgWinLoss, SAgComm, race, matchcode, isNeutral, showtime)
			SELECT	(CASE b.bettype WHEN 10 THEN 2 ELSE 1 END) AS BetGroup,		
					0 AS matchid,
					0 AS homeid,
					0 AS awayid,
					b.bettype,
					0 AS liveindicator,
					m.leagueid,
					SUM(CASE WHEN b.liveawayscore = 0 and b.bettype in(33,43) THEN ABS(b.stake)/2 ELSE ABS(b.stake) END) AS TurnOver,
					ISNULL(SUM(scomm/(1 - tpositiontaking)), 0) AS GrossComm,
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
			GROUP BY b.bettype, m.groupmatch, m.leagueid
			HAVING ISNULL(COUNT(transid), 0) > 0;

			IF @showVS = 1 
			BEGIN
				-- Virtual HR		
				INSERT INTO #SAgMatchWLDetails(BetGroup, matchid, homeid, awayid, bettype, liveindicator, leagueid, turnover, GrossComm, MemberWinLoss, MemberComm, AgWinLoss, AgComm, MAgWinLoss, MAgComm, SAgWinLoss, SAgComm, race, matchcode, isNeutral, showtime)
				SELECT  0 AS BetGroup,
						'' matchid,
						0 AS homeid,
						0 AS awayid,
						b.bettype,
						0 AS liveindicator,
						r.leagueid,
						SUM(ABS(stake)) AS turnover,
						SUM(comm/(1 - tpositiontaking)) AS GrossComm,
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
					AND o.eventdate >= @fromdate
					AND o.eventdate <= @todate
					AND o.eventstatus = 'completed'
					AND ISNULL(r.betstatus,'') <> 'refund'
					AND s.ProductID = 5
					AND s.EventType = 3				
				GROUP BY r.LeagueID, r.EventTime, r.eventID, b.bettype;	
				
				INSERT INTO #SAgMatchWLDetails(BetGroup, matchid, homeid, awayid, bettype, liveindicator, leagueid, turnover, GrossComm, MemberWinLoss, MemberComm, AgWinLoss, AgComm, MAgWinLoss, MAgComm, SAgWinLoss, SAgComm, race, matchcode, isNeutral, showtime)
				SELECT  3 AS BetGroup,
						0 AS matchid,
						0 AS homeid,
						0 AS awayid,
						b.bettype,
						0 AS liveindicator,
						0 AS leagueid,
						ISNULL(SUM(ABS(stake)), 0) AS turnover,
						ISNULL(SUM(scomm/(1 - tpositiontaking)), 0) AS GrossComm,
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
					AND b.bettype IN (2799)
					AND b.winlostdate >= @fromdate
					AND b.winlostdate <= @todate
					AND b.ruben = 1
					AND b.statusID NOT IN (101, 102, 103) 
				GROUP BY b.bettype	
				HAVING ISNULL(COUNT(transid), 0) > 0;	
			END	

		END

		IF @fdate <= @MoveBetsDay
		BEGIN			
			CREATE TABLE #RecommendList (recommend INT);
		
			INSERT INTO #RecommendList (recommend)
			SELECT CustId 
			FROM dbo.CustInfo WITH (NOLOCK) 
			WHERE srecommend = @CustId AND RoleId = 2;
		
			INSERT INTO #SAgMatchWLDetails(BetGroup, matchid, homeid, awayid, bettype, liveindicator, leagueid, turnover, GrossComm, MemberWinLoss, MemberComm, AgWinLoss, AgComm, MAgWinLoss, MAgComm, SAgWinLoss, SAgComm, race, matchcode, isNeutral, showtime)
			SELECT  0 AS BetGroup,
					m.matchid,
					m.homeid,
					m.awayid,
					b.bettype,
					b.liveindicator,
					m.leagueid,
					SUM(ABS(stake)) AS turnover,
					SUM(scomm/(1 - tpositiontaking)) AS GrossComm,
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
				INNER JOIN #RecommendList R ON R.recommend = b.recommend
			WHERE m.eventdate >= @fdate
				AND m.eventdate <= @tdate
				AND m.eventstatus = 'completed'
				AND ISNULL(m.betstatus,'') <> 'refund'
				AND b.statusID NOT IN (101, 102, 103)
				AND s.ProductID = 3				
			GROUP BY m.matchid, m.homeid, m.awayid, b.bettype, m.leagueid, m.matchcode, m.isNeutral, b.liveindicator;
		
			--- Not number Game not group by liveindicator
			INSERT INTO #SAgMatchWLDetails(BetGroup, matchid, homeid, awayid, bettype, liveindicator, leagueid, turnover, GrossComm, MemberWinLoss, MemberComm, AgWinLoss, AgComm, MAgWinLoss, MAgComm, SAgWinLoss, SAgComm, race, matchcode, isNeutral, showtime)
			SELECT  0 AS BetGroup,
					m.matchid,
					m.homeid,
					m.awayid,
					CASE WHEN ISNULL(f.bettype, 0) = 0 THEN b.bettype ELSE f.GroupTypeId END AS bettype,
					0 AS liveindicator,
					m.leagueid,
					SUM(ABS(stake)) AS turnover,
					SUM(scomm/(1 - tpositiontaking)) AS GrossComm,
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
				INNER JOIN #RecommendList R ON R.recommend = b.recommend			
			WHERE m.eventdate >= @fdate
				AND m.eventdate <= @tdate
				AND m.eventstatus = 'completed'
				AND ISNULL(m.betstatus,'') <> 'refund'
				AND b.bettype < 19001 
				AND b.bettype NOT IN (9,29,10)
				AND b.statusID NOT IN (101, 102, 103)
				AND s.ProductID <> 3
				AND s.EventType <> 3				
			GROUP BY m.matchid, m.homeid, m.awayid, m.leagueid, m.matchcode, m.isNeutral,showtime,
				CASE WHEN ISNULL(f.bettype,0) = 0 THEN b.bettype ELSE f.GroupTypeId END;

			-- Mix parlay(14)
			IF @showSB = 1 
			BEGIN
				INSERT INTO #SAgMatchWLDetails(BetGroup, matchid, homeid, awayid, bettype, liveindicator, leagueid, turnover, GrossComm, MemberWinLoss, MemberComm, AgWinLoss, AgComm, MAgWinLoss, MAgComm, SAgWinLoss, SAgComm, race, matchcode, isNeutral, showtime) 
				SELECT  3 AS BetGroup,
						0 AS matchid,
						0 AS homeid,
						0 AS awayid,
						b.bettype,
						0 AS liveindicator,
						0 AS leagueid,
						ISNULL(SUM(ABS(stake)), 0) AS turnover,
						ISNULL(SUM(scomm/(1 - tpositiontaking)), 0) AS GrossComm,
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
					INNER JOIN #RecommendList R ON R.recommend = b.recommend
				WHERE b.bettype IN (9, 29)
					AND b.winlostdate >= @fdate
					AND b.winlostdate <= @tdate
					AND b.ruben = 1
					AND b.statusID NOT IN (101, 102, 103)				
				GROUP BY b.bettype		
				HAVING ISNULL(COUNT(transid),0) > 0;
			END
		
			---Outright, RB
			INSERT INTO #SAgMatchWLDetails(BetGroup, matchid, homeid, awayid, bettype, liveindicator, leagueid, turnover, GrossComm, MemberWinLoss, MemberComm, AgWinLoss, AgComm, MAgWinLoss, MAgComm, SAgWinLoss, SAgComm, race, matchcode, isNeutral, showtime) 
			SELECT  (CASE b.bettype WHEN 10 THEN 2 ELSE 1 END) AS BetGroup,		
					0 AS matchid,
					0 AS homeid,
					0 AS awayid,
					b.bettype,
					0 AS liveindicator,
					m.leagueid,
					--ISNULL(SUM(stake), 0) AS turnover,
					SUM(CASE WHEN b.liveawayscore = 0 AND b.bettype IN(33,43) THEN ABS(b.stake)/2 ELSE ABS(b.stake) END) AS TurnOver,
					ISNULL(SUM(scomm/(1 - tpositiontaking)), 0) AS GrossComm,
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
				INNER JOIN #RecommendList R ON R.recommend = b.recommend
			WHERE b.winlostdate >= @fdate
				AND b.winlostdate <= @tdate
				AND s.ProductID IN (1, 2)
				AND s.EventType = 2
				AND b.ruben=1
				AND b.statusID not in (101, 102, 103)				
			GROUP BY b.bettype, m.groupmatch, m.leagueid
			HAVING ISNULL(COUNT(transid),0) > 0;
		
			IF @showVS = 1 
			BEGIN
				-- Virtual HR		
				INSERT INTO #SAgMatchWLDetails(BetGroup, matchid, homeid, awayid, bettype, liveindicator, leagueid, turnover, GrossComm, MemberWinLoss, MemberComm, AgWinLoss, AgComm, MAgWinLoss, MAgComm, SAgWinLoss, SAgComm, race, matchcode, isNeutral, showtime) 
				SELECT  0 AS BetGroup,
						'' matchid,
						0 AS homeid,
						0 AS awayid,
						b.bettype,
						0 AS liveindicator,
						r.leagueid,
						SUM(ABS(stake)) AS turnover,
						SUM(comm/(1 - tpositiontaking)) AS GrossComm,
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
					INNER JOIN VSRaceInfo r WITH (NOLOCK) ON r.EventID = o.EventID
					INNER JOIN #SportBettype s ON b.bettype = s.Bettype
					INNER JOIN #RecommendList Re ON Re.recommend = b.recommend
				WHERE b.statusID NOT IN (101, 102, 103)
					AND o.eventdate >= @fdate
					AND o.eventdate <= @tdate
					AND o.eventstatus = 'completed' 
					AND ISNULL(r.betstatus,'') <> 'refund'
					AND s.ProductID = 5
					AND s.EventType = 3					
				GROUP BY r.LeagueID, r.EventTime, r.eventID, b.bettype;

				INSERT INTO #SAgMatchWLDetails(BetGroup, matchid, homeid, awayid, bettype, liveindicator, leagueid, turnover, GrossComm, MemberWinLoss, MemberComm, AgWinLoss, AgComm, MAgWinLoss, MAgComm, SAgWinLoss, SAgComm, race, matchcode, isNeutral, showtime)
				SELECT  3 AS BetGroup,
						0 AS matchid,
						0 AS homeid,
						0 AS awayid,
						b.bettype,
						0 AS liveindicator,
						0 AS leagueid,
						ISNULL(SUM(ABS(stake)), 0) AS turnover,
						ISNULL(SUM(scomm/(1 - tpositiontaking)), 0) AS GrossComm,
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
				WHERE b.srecommend = @custid
					AND b.bettype IN (2799)
					AND b.winlostdate >= @fromdate
					AND b.winlostdate <= @todate
					AND b.ruben = 1
					AND b.statusID NOT IN (101, 102, 103) 
				GROUP BY b.bettype	
				HAVING ISNULL(COUNT(transid), 0) > 0;
			END		
		
		END
	END



 
	SELECT  BetGroup, 
			matchid, 
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
			showtime
	FROM #SAgMatchWLDetails
	GROUP BY BetGroup, matchid, homeid, awayid, bettype, liveindicator, leagueid, race, matchcode, isNeutral, showtime
	ORDER BY betgroup, matchid, leagueid, race, bettype, liveindicator, matchcode;

	SET NOCOUNT OFF;
END
GO