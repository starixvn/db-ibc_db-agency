USE [bodb02]
GO

ALTER PROCEDURE [dbo].[Age_Rpt_MatchWinloss_SelLeagueBySport]
	@custid		INT,
	@showSB BIT = 1,
	@showRB BIT = 0,
	@showNG BIT = 0,
	@showP2P BIT = 0,
	@showLiveCasino BIT = 0,
	@showVS BIT = 0,
	@IsShowAll BIT = 1, 
	@fromdate	DATETIME,
	@todate		DATETIME,
	@movebetsday DATETIME,
	@Language	VARCHAR(3) = 'E'
AS
/*
	Created : Johnson
	Task: Match Winloss Detail
	DB: DBAGE.BODB02
	Date: 2011-02-17
	Revision's:
		- 20110308@Lukas: change param @showHR -> @showRB, add more sporttype 152 & 153
		- 20120202@Sophia: Add Live Casino
		- 20120803@Sophia: Add Sporttype = 180 for Virtual Sports
		- 20120810@Elodie: add @IsShowAll parameter 
		- 20130221@Elodie: Add range sport type for Virtual sports (180 -> 186)
		- 20130228@Elodie: Add Virtual HR product
		- 20131126@Kathy: Add Virtual Greyhounds (182), Motor Racing (184) [Redmine:#7234]
		- 20140404@Dom: Add Virtual Speedway (183), Virtual Cycling Racing (185)
		- 20150425@Tom: Select League By Custid
		- 20160712@Percy: Using inline function for SportBettypeMatrix [RedmineID: #53152]
	Parameter's Explanation
		- @custid : Agent's ID	
		- @IsShowAll: indicate whether to show test leagues or not
				1: Show all include test leagues
				0: Not show test leagues
*/
SET NOCOUNT ON

DECLARE @isTest BIT
SELECT  @isTest = dbo.f_CheckSPVersion(@@SPID)

IF OBJECT_ID('tempdb..#SportBettype') IS NOT NULL
BEGIN
	DROP TABLE #SportBettype
END

CREATE TABLE #SportBettype (
			ProductID INT
			,Bettype INT
			,EventType INT
		)		

DECLARE @ProductPrefix VARCHAR(100)='-'

IF @ShowSB	= 1
	BEGIN
		SET @ProductPrefix=@ProductPrefix+',SB'
	END

IF @showRB	= 1
	BEGIN	
		SET @ProductPrefix=@ProductPrefix+',RB'
	END

IF @showNG	= 1
	BEGIN	
		SET @ProductPrefix=@ProductPrefix+',NG'
	END
	
IF @showLiveCasino	= 1
	BEGIN	
		SET @ProductPrefix=@ProductPrefix+',LC'		
	END
	
IF @showVS	= 1
	BEGIN	
		SET @ProductPrefix=@ProductPrefix+',VS'
	END	
	
INSERT INTO #SportBettype (ProductID, Bettype, EventType)
SELECT ProductID, Bettype, EventType FROM dbo.f_SportBettypeMatrix_Sel (0, 0, 0, 2, '', @ProductPrefix, @isTest)

SELECT @IsShowAll = CASE @IsShowAll WHEN 1 THEN NULL ELSE 0 END
DECLARE @RoleID INT

SELECT TOP 1 @RoleID = RoleID FROM dbo.CustInfo (NOLOCK) WHERE custid = @custid

CREATE TABLE #tmpLeagues(leagueid INT)

CREATE TABLE #tmpmatchid(matchid INT)

IF @roleid = 4
BEGIN
	IF @Todate > @MoveBetsDay
		BEGIN
			IF EXISTS( SELECT TOP 1 1 FROM #SportBettype tbl WHERE tbl.EventType = 1 )
				INSERT INTO #tmpmatchid(matchid)
				SELECT DISTINCT matchid 
					FROM dbo.bettrans b WITH(NOLOCK)
					WHERE b.srecommend = @custid 
						AND b.statusID NOT IN (101, 102, 103)
						AND b.ruben = 1
						AND EXISTS (SELECT TOP 1 1 FROM #SportBettype tbl WHERE tbl.bettype = b.bettype AND tbl.EventType = 1 )
			
			IF EXISTS( SELECT TOP 1 1 FROM #SportBettype tbl WHERE tbl.EventType = 2 )
				INSERT INTO #tmpmatchid(matchid)
				SELECT DISTINCT matchid 
								FROM dbo.bettrans b WITH(NOLOCK)
								WHERE b.srecommend = @custid 
									AND b.statusID NOT IN (101, 102, 103)
									AND b.ruben = 1
									AND EXISTS (SELECT TOP 1 1 FROM #SportBettype tbl WHERE tbl.bettype = b.bettype AND tbl.EventType = 2 )
			
			IF EXISTS( SELECT TOP 1 1 FROM #SportBettype tbl WHERE tbl.EventType = 3 )
				INSERT INTO #tmpmatchid(matchid)
				SELECT DISTINCT oddsid 
								FROM dbo.bettrans b WITH(NOLOCK)
								WHERE b.srecommend = @custid 
									AND b.statusID NOT IN (101, 102, 103)
									AND b.ruben = 1
									AND EXISTS (SELECT TOP 1 1 FROM #SportBettype tbl WHERE tbl.bettype = b.bettype AND tbl.EventType = 3 )
									
									
		END

	IF @fromdate <= @MoveBetsDay
	BEGIN
		IF EXISTS( SELECT TOP 1 1 FROM #SportBettype tbl WHERE tbl.EventType = 1 )
			INSERT INTO #tmpmatchid(matchid)
			SELECT DISTINCT matchid 
				FROM dbo.bettrans14 b WITH(NOLOCK)
				WHERE b.srecommend = @custid 
					AND b.statusID NOT IN (101, 102, 103)
					AND b.ruben = 1
					AND EXISTS (SELECT TOP 1 1 FROM #SportBettype tbl WHERE tbl.bettype = b.bettype AND tbl.EventType = 1 )
			
		IF EXISTS( SELECT TOP 1 1 FROM #SportBettype tbl WHERE tbl.EventType = 2 )
			INSERT INTO #tmpmatchid(matchid)
			SELECT DISTINCT matchid 
								FROM dbo.bettrans14 b WITH(NOLOCK)
								WHERE b.srecommend = @custid 
									AND b.statusID NOT IN (101, 102, 103)
									AND b.ruben = 1
									AND EXISTS (SELECT TOP 1 1 FROM #SportBettype tbl WHERE tbl.bettype = b.bettype AND tbl.EventType = 2 )
		
		IF EXISTS( SELECT TOP 1 1 FROM #SportBettype tbl WHERE tbl.EventType = 3 )
			INSERT INTO #tmpmatchid(matchid)
			SELECT DISTINCT oddsid 
								FROM dbo.bettrans14 b WITH(NOLOCK)
								WHERE b.srecommend = @custid 
									AND b.statusID NOT IN (101, 102, 103)
									AND b.ruben = 1
									AND EXISTS (SELECT TOP 1 1 FROM #SportBettype tbl WHERE tbl.bettype = b.bettype AND tbl.EventType = 3 )
					
	END
END

IF @roleid = 3
BEGIN
	IF @Todate > @MoveBetsDay
		BEGIN
			IF EXISTS( SELECT TOP 1 1 FROM #SportBettype tbl WHERE tbl.EventType = 1 )
				INSERT INTO #tmpmatchid(matchid)
				SELECT DISTINCT matchid 
					FROM dbo.bettrans b WITH(NOLOCK)
					WHERE b.mrecommend = @custid 
						AND b.statusID NOT IN (101, 102, 103)
						AND b.ruben = 1
						AND EXISTS (SELECT TOP 1 1 FROM #SportBettype tbl WHERE tbl.bettype = b.bettype AND tbl.EventType = 1 )
			
			IF EXISTS( SELECT TOP 1 1 FROM #SportBettype tbl WHERE tbl.EventType = 2 )
				INSERT INTO #tmpmatchid(matchid)
				SELECT DISTINCT matchid 
								FROM dbo.bettrans b WITH(NOLOCK)
								WHERE b.mrecommend = @custid 
									AND b.statusID NOT IN (101, 102, 103)
									AND b.ruben = 1
									AND EXISTS (SELECT TOP 1 1 FROM #SportBettype tbl WHERE tbl.bettype = b.bettype AND tbl.EventType = 2 )
			
			IF EXISTS( SELECT TOP 1 1 FROM #SportBettype tbl WHERE tbl.EventType = 3 )
				INSERT INTO #tmpmatchid(matchid)
				SELECT DISTINCT oddsid 
								FROM dbo.bettrans b WITH(NOLOCK)
								WHERE b.mrecommend = @custid 
									AND b.statusID NOT IN (101, 102, 103)
									AND b.ruben = 1
									AND EXISTS (SELECT TOP 1 1 FROM #SportBettype tbl WHERE tbl.bettype = b.bettype AND tbl.EventType = 3 )
									
									
		END

	IF @fromdate <= @MoveBetsDay
	BEGIN
		IF EXISTS( SELECT TOP 1 1 FROM #SportBettype tbl WHERE tbl.EventType = 1 )
			INSERT INTO #tmpmatchid(matchid)
			SELECT DISTINCT matchid 
				FROM dbo.bettrans14 b WITH(NOLOCK)
				WHERE b.mrecommend = @custid 
					AND b.statusID NOT IN (101, 102, 103)
					AND b.ruben = 1
					AND EXISTS (SELECT TOP 1 1 FROM #SportBettype tbl WHERE tbl.bettype = b.bettype AND tbl.EventType = 1 )
			
		IF EXISTS( SELECT TOP 1 1 FROM #SportBettype tbl WHERE tbl.EventType = 2 )
			INSERT INTO #tmpmatchid(matchid)
			SELECT DISTINCT matchid 
								FROM dbo.bettrans14 b WITH(NOLOCK)
								WHERE b.mrecommend = @custid 
									AND b.statusID NOT IN (101, 102, 103)
									AND b.ruben = 1
									AND EXISTS (SELECT TOP 1 1 FROM #SportBettype tbl WHERE tbl.bettype = b.bettype AND tbl.EventType = 2 )
		
		IF EXISTS( SELECT TOP 1 1 FROM #SportBettype tbl WHERE tbl.EventType = 3 )
			INSERT INTO #tmpmatchid(matchid)
			SELECT DISTINCT oddsid 
								FROM dbo.bettrans14 b WITH(NOLOCK)
								WHERE b.mrecommend = @custid 
									AND b.statusID NOT IN (101, 102, 103)
									AND b.ruben = 1
									AND EXISTS (SELECT TOP 1 1 FROM #SportBettype tbl WHERE tbl.bettype = b.bettype AND tbl.EventType = 3 )
					
	END
END

IF @roleid = 2
BEGIN
	IF @Todate > @MoveBetsDay
		BEGIN
			IF EXISTS( SELECT TOP 1 1 FROM #SportBettype tbl WHERE tbl.EventType = 1 )
				INSERT INTO #tmpmatchid(matchid)
				SELECT DISTINCT matchid 
					FROM dbo.bettrans b WITH(NOLOCK)
					WHERE b.recommend = @custid 
						AND b.statusID NOT IN (101, 102, 103)
						AND b.ruben = 1
						AND EXISTS (SELECT TOP 1 1 FROM #SportBettype tbl WHERE tbl.bettype = b.bettype AND tbl.EventType = 1 )
			
			IF EXISTS( SELECT TOP 1 1 FROM #SportBettype tbl WHERE tbl.EventType = 2 )
				INSERT INTO #tmpmatchid(matchid)
				SELECT DISTINCT matchid 
								FROM dbo.bettrans b WITH(NOLOCK)
								WHERE b.recommend = @custid 
									AND b.statusID NOT IN (101, 102, 103)
									AND b.ruben = 1
									AND EXISTS (SELECT TOP 1 1 FROM #SportBettype tbl WHERE tbl.bettype = b.bettype AND tbl.EventType = 2 )
			
			IF EXISTS( SELECT TOP 1 1 FROM #SportBettype tbl WHERE tbl.EventType = 3 )
				INSERT INTO #tmpmatchid(matchid)
				SELECT DISTINCT oddsid 
								FROM dbo.bettrans b WITH(NOLOCK)
								WHERE b.recommend = @custid 
									AND b.statusID NOT IN (101, 102, 103)
									AND b.ruben = 1
									AND EXISTS (SELECT TOP 1 1 FROM #SportBettype tbl WHERE tbl.bettype = b.bettype AND tbl.EventType = 3 )
									
									
		END

	IF @fromdate <= @MoveBetsDay
	BEGIN
		IF EXISTS( SELECT TOP 1 1 FROM #SportBettype tbl WHERE tbl.EventType = 1 )
			INSERT INTO #tmpmatchid(matchid)
			SELECT DISTINCT matchid 
				FROM dbo.bettrans14 b WITH(NOLOCK)
				WHERE b.recommend = @custid 
					AND b.statusID NOT IN (101, 102, 103)
					AND b.ruben = 1
					AND EXISTS (SELECT TOP 1 1 FROM #SportBettype tbl WHERE tbl.bettype = b.bettype AND tbl.EventType = 1 )
			
		IF EXISTS( SELECT TOP 1 1 FROM #SportBettype tbl WHERE tbl.EventType = 2 )
			INSERT INTO #tmpmatchid(matchid)
			SELECT DISTINCT matchid 
								FROM dbo.bettrans14 b WITH(NOLOCK)
								WHERE b.recommend = @custid 
									AND b.statusID NOT IN (101, 102, 103)
									AND b.ruben = 1
									AND EXISTS (SELECT TOP 1 1 FROM #SportBettype tbl WHERE tbl.bettype = b.bettype AND tbl.EventType = 2 )
		
		IF EXISTS( SELECT TOP 1 1 FROM #SportBettype tbl WHERE tbl.EventType = 3 )
			INSERT INTO #tmpmatchid(matchid)
			SELECT DISTINCT oddsid 
								FROM dbo.bettrans14 b WITH(NOLOCK)
								WHERE b.recommend = @custid 
									AND b.statusID NOT IN (101, 102, 103)
									AND b.ruben = 1
									AND EXISTS (SELECT TOP 1 1 FROM #SportBettype tbl WHERE tbl.bettype = b.bettype AND tbl.EventType = 3 )
					
	END
END

IF @Todate > @MoveBetsDay
BEGIN
	INSERT INTO #tmpLeagues
	SELECT DISTINCT m.leagueid
	FROM match m WITH(NOLOCK) 
		INNER JOIN league l WITH(NOLOCK) ON m.leagueid = l.leagueid
		INNER JOIN #tmpmatchid tmp ON tmp.matchid = m.matchid
	WHERE m.eventdate >= @fromdate 
		AND m.eventdate <= @todate
		AND m.eventstatus = 'completed'
		AND 1 = CASE WHEN @showSB = 1 AND l.sporttype <= 99 THEN 1
					 WHEN @showNG = 1 AND l.sporttype = 161 THEN 1 
					 WHEN @showP2P = 1 AND l.sporttype = 253 THEN 1 
					 WHEN @showLiveCasino = 1 AND l.sporttype = 162 THEN 1
					 WHEN @showVS = 1 AND l.sporttype BETWEEN 180 AND 186 AND l.sporttype NOT in (181, 182, 184,183,185) THEN 1
					 ELSE 0 END
		AND l.isTest = isnull(@IsShowAll, l.isTest)
						
	INSERT INTO #tmpLeagues
	SELECT DISTINCT r.leagueid
	FROM VSRaceInfo r WITH(NOLOCK) 
		INNER JOIN league l WITH(NOLOCK) ON r.leagueid = l.leagueid
		INNER JOIN VSOutright o WITH(NOLOCK) ON r.EventID = o.EventID
		INNER JOIN #tmpmatchid tmp ON tmp.matchid = o.orid
	WHERE o.EventDate >= @fromdate 
		AND o.EventDate <= @todate
		AND o.eventstatus = 'completed'
		AND @showVS = 1 AND r.sporttype in (181, 182, 184,183,185)
		AND l.isTest = isnull(@IsShowAll, l.isTest) 
								
	INSERT INTO #tmpLeagues					 
	SELECT DISTINCT m.leagueid
	FROM outright m WITH(NOLOCK) 
		INNER JOIN league l WITH(NOLOCK) ON m.leagueid = l.leagueid 
		INNER JOIN #tmpmatchid tmp ON tmp.matchid = m.orid
	WHERE m.eventdate >= @fromdate
		AND m.eventdate <= @todate
		AND m.oddsstatus = 'completed'
		AND 1= CASE WHEN @showSB = 1 AND l.sporttype <= 99 THEN 1
					WHEN @showRB = 1 AND l.sporttype BETWEEN 151 AND 153 THEN 1 
					ELSE 0 END
		AND l.isTest = isnull(@IsShowAll, l.isTest) 
						
END				 

IF @fromdate <= @MoveBetsDay
BEGIN
	INSERT INTO #tmpLeagues
	SELECT DISTINCT m.leagueid
	FROM match14 m WITH(NOLOCK) 
		INNER JOIN league l WITH(NOLOCK) ON m.leagueid = l.leagueid
		INNER JOIN #tmpmatchid tmp ON tmp.matchid = m.matchid
	WHERE m.eventdate >= @fromdate 
		AND m.eventdate <= @todate
		AND m.eventstatus = 'completed'
		AND 1 = CASE WHEN @showSB = 1 AND l.sporttype <= 99 THEN 1
					 WHEN @showNG = 1 AND l.sporttype = 161 THEN 1 
					 WHEN @showP2P = 1 AND l.sporttype = 253 THEN 1 
					 WHEN @showLiveCasino = 1 AND l.sporttype = 162 THEN 1
					 WHEN @showVS = 1 AND l.sporttype BETWEEN 180 AND 186 AND l.sporttype NOT IN (181, 182, 184,183,185) THEN 1 
					 ELSE 0 END
		AND l.isTest = isnull(@IsShowAll, l.isTest)
						
	INSERT INTO #tmpLeagues
	SELECT DISTINCT r.leagueid
	FROM VSRaceInfo r WITH(NOLOCK) 
		INNER JOIN league l WITH(NOLOCK) ON r.leagueid = l.leagueid
		INNER JOIN VSOutright14 o WITH(NOLOCK) ON r.EventID = o.EventID		
		INNER JOIN #tmpmatchid tmp ON tmp.matchid = o.orid
	WHERE o.EventDate >= @fromdate 
		AND o.EventDate <= @todate
		AND o.eventstatus = 'completed'
		AND @showVS = 1 AND r.sporttype IN(181, 182, 184,183,185)
		AND l.isTest = isnull(@IsShowAll, l.isTest) 
						
	INSERT INTO #tmpLeagues					 
	SELECT DISTINCT m.leagueid
	FROM outright14 m WITH(NOLOCK) 
		INNER JOIN league l WITH(NOLOCK) ON m.leagueid = l.leagueid 		
		INNER JOIN #tmpmatchid tmp ON tmp.matchid = m.orid
	WHERE m.eventdate >= @fromdate
		AND m.eventdate <= @todate
		AND m.oddsstatus = 'completed'
		AND 1= CASE WHEN @showSB = 1 AND l.sporttype <= 99 THEN 1
					WHEN @showRB = 1 AND l.sporttype BETWEEN 151 AND 153 THEN 1 
					ELSE 0 END
		AND l.isTest = isnull(@IsShowAll, l.isTest)
END

DROP TABLE #tmpmatchid

SELECT DISTINCT l1.leagueid , l1.sporttype,
	CASE @Language 
		WHEN 'E' THEN l1.leaguename
		WHEN 'CS' THEN (case when l1.leaguenamecn= '' or l1.leaguenamecn is null then l1.leaguename else l1.leaguenamecn end)
		WHEN 'CT' THEN (case when l1.leaguenamec_uni= '' or l1.leaguenamec_uni is null then l1.leaguename else l1.leaguenamec_uni end)
		WHEN 'TH' THEN (case when l1.leaguenameth = '' or l1.leaguenameth is null then l1.leaguename else l1.leaguenameth end)
		WHEN 'J' THEN (case when l1.leaguenamej= '' or l1.leaguenamej is null then l1.leaguename else l1.leaguenamej end)
		WHEN 'KO' THEN (case when l1.leaguenameko= '' or l1.leaguenameko is null then l1.leaguename else l1.leaguenameko end)
		ELSE l1.leaguename
	END	 as leaguename
FROM #tmpLeagues l
	INNER JOIN league l1 WITH(NOLOCK)  ON l.leagueid = l1.leagueid
ORDER BY l1.sporttype  

DROP TABLE #tmpLeagues
DROP TABLE #SportBettype
	
GO
GRANT EXECUTE ON [dbo].[Age_Rpt_MatchWinLoss_SelLeagueBySport] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_Rpt_MatchWinLoss_SelLeagueBySport] TO [bodbDownlineNetView]
GO
GRANT VIEW DEFINITION ON [dbo].[Age_Rpt_MatchWinLoss_SelLeagueBySport] TO vnteam
