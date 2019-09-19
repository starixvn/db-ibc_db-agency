/*<info serverAlias="DBAGE-bodb02" executers="bodbAdminNet,bodbDownlineNet,bodbDownlineNetView" isFunction="0" isNested="0"></info>*/
USE [bodb02]
GO

ALTER PROCEDURE [dbo].[Age_Rpt_MatchWinloss_GetLeagueByProduct]
	@custid			INT,
	@ProductIds		VARCHAR(MAX),
	@IsShowAll		BIT = 1, 
	@fromdate		SMALLDATETIME,
	@todate			SMALLDATETIME,
	@movebetsday	SMALLDATETIME,
	@Language		VARCHAR(3) = 'E'
AS

/*
	Created: 
	Task : 
	DB: DBAGE.bodb02
	Original: Age_Rpt_MatchWinloss_SelLeagueBySport
	
	Revisions:
		- 20170224@Paul: Create new [RedmineID: #70554]
		- 20170622@Percy: Combine Betradar Virtual Sports with Virtual Sports [RedmineID: #78339]
		- 20170828@Percy: Support Lucky 3 [RedmineID: #76770]
		- 20171020@Percy: Return flag field for league/league3rd [RedmineID: #84690]
		- 20171101@Percy: Enhance Performance on bettrans14 [RedmineID: #86200]
		- 20180130@Percy: Clean redundant code [RedmineID: #86086]
		- 20181003@Patrick: Index revolution [RedmineID: #101405]
		- 20190826@Percy: Remove inactive products [RedmineID: #118699]

	Param's Explanation:
		Output: LeagueType (0: league, 1: league3rd)
*/

BEGIN
	SET NOCOUNT ON;

	DECLARE @isTest BIT;
	SELECT  @isTest = dbo.f_CheckSPVersion(@@PROCID);

	IF @IsShowAll IS NULL
		SELECT @IsShowAll = 0;

	SELECT @ProductIds = dbo.f_AddRelatedProducts(@ProductIds);

	CREATE TABLE #SportBettype
	(
		Bettype		INT,
		EventType	INT
	);

	INSERT INTO #SportBettype (Bettype, EventType)
	SELECT Bettype, EventType
	FROM dbo.f_SportBettypeMatrixByProduct(@ProductIds, @isTest)
	WHERE EventType IN (1, 2, 3, 5);

	CREATE CLUSTERED INDEX ix_SportBettype_cl ON #SportBettype (Bettype);

	DECLARE @RoleID INT;

	SELECT @RoleID = RoleID FROM dbo.CustInfo WITH (NOLOCK) WHERE custid = @custid;

	CREATE TABLE #tmpLeagues(leagueid INT, LeagueType TINYINT);
	CREATE TABLE #tmpmatchid(matchid INT, EventType INT UNIQUE(matchid, EventType));

	DECLARE @fdate SMALLDATETIME, @tdate SMALLDATETIME;

	/* range bettrans */
	IF @ToDate > @MoveBetsDay
	BEGIN
		SELECT @tdate = @ToDate, @fdate = CASE WHEN @FromDate <= @MoveBetsDay THEN DATEADD(DAY, 1, @MoveBetsDay) ELSE @FromDate END

		-- Super
		IF @roleid = 4
		BEGIN

			INSERT INTO #tmpmatchid (matchid, EventType)
			SELECT DISTINCT CASE WHEN tbl.EventType IN (1, 2, 5) THEN matchid ELSE oddsid END, tbl.EventType
			FROM dbo.bettrans b WITH (NOLOCK)
				INNER JOIN #SportBettype tbl ON tbl.bettype = b.bettype
			WHERE b.srecommend = @CustID
				AND b.statusID NOT IN (101, 102, 103)
				AND b.ruben = 1
				AND winlostdate BETWEEN @fdate AND @tdate;
		END
		-- Master
		ELSE IF @RoleID = 3
		BEGIN
			INSERT INTO #tmpmatchid (matchid, EventType)
			SELECT DISTINCT CASE WHEN tbl.EventType IN (1, 2, 5) THEN matchid ELSE oddsid END, tbl.EventType
			FROM dbo.bettrans b WITH (NOLOCK)
				INNER JOIN #SportBettype tbl ON tbl.bettype = b.bettype
			WHERE b.mrecommend = @custid 
				AND b.statusID NOT IN (101, 102, 103)
				AND b.ruben = 1
				AND winlostdate BETWEEN @fdate AND @tdate;
		END
		-- Agent
		ELSE IF @RoleID = 2
		BEGIN
			INSERT INTO #tmpmatchid (matchid, EventType)
			SELECT DISTINCT CASE WHEN tbl.EventType IN (1, 2, 5) THEN matchid ELSE oddsid END, tbl.EventType
			FROM dbo.bettrans b WITH (NOLOCK)
				INNER JOIN #SportBettype tbl ON tbl.bettype = b.bettype
			WHERE b.recommend = @custid 
				AND b.statusID NOT IN (101, 102, 103)
				AND b.ruben = 1
				AND winlostdate BETWEEN @fdate AND @tdate;
		END

		-- get leagueid
		INSERT INTO #tmpLeagues (leagueid, LeagueType)
		SELECT DISTINCT l.leagueid, 0
		FROM dbo.match m WITH (NOLOCK) 
			INNER JOIN dbo.league l WITH (NOLOCK) ON m.leagueid = l.leagueid
			INNER JOIN #tmpmatchid tmp ON tmp.matchid = m.matchid
		WHERE m.eventdate BETWEEN @fdate AND @tdate
			AND m.eventstatus = 'completed'
			AND tmp.EventType = 1
			AND l.isTest <= @IsShowAll;
								
		INSERT INTO #tmpLeagues (leagueid, LeagueType) 
		SELECT DISTINCT l.leagueid, 0
		FROM dbo.outright m WITH (NOLOCK) 
			INNER JOIN dbo.league l WITH (NOLOCK) ON m.leagueid = l.leagueid 
			INNER JOIN #tmpmatchid tmp ON tmp.matchid = m.orid
		WHERE m.eventdate BETWEEN @fdate AND @tdate
			AND m.oddsstatus = 'completed'
			AND tmp.EventType = 2
			AND l.isTest <= @IsShowAll;

		INSERT INTO #tmpLeagues (leagueid, LeagueType)
		SELECT DISTINCT l.leagueid, 0
		FROM dbo.VSRaceInfo r WITH (NOLOCK) 
			INNER JOIN dbo.league l WITH (NOLOCK) ON r.leagueid = l.leagueid
			INNER JOIN dbo.VSOutright o WITH (NOLOCK) ON r.EventID = o.EventID
			INNER JOIN #tmpmatchid tmp ON tmp.matchid = o.orid
		WHERE o.eventdate BETWEEN @fdate AND @tdate
			AND o.eventstatus = 'completed'
			AND tmp.EventType = 3
			AND l.isTest <= @IsShowAll;
	END

	TRUNCATE TABLE #tmpmatchid

	/* bettrans14: using index on mrecommend, please consider if any change*/
	IF @FromDate <= @MoveBetsDay
	BEGIN
		SELECT @fdate = @FromDate, @tdate = CASE WHEN @ToDate > @MoveBetsDay THEN @MoveBetsDay ELSE @ToDate END

		-- Super
		IF @roleid = 4
		BEGIN
			DECLARE @n INT = 2147483647
			
			INSERT INTO #tmpmatchid (matchid, EventType)
			SELECT DISTINCT CASE WHEN tbl.EventType IN (1, 2, 5) THEN matchid ELSE oddsid END, tbl.EventType
			FROM dbo.bettrans14 b WITH (NOLOCK)
				INNER JOIN #SportBettype tbl ON tbl.bettype = b.bettype
			WHERE b.srecommend = @CustID
				AND b.statusID NOT IN (101, 102, 103)
				AND winlostdate BETWEEN @fdate AND @tdate
			--OPTION (OPTIMIZE FOR (@n = 1));
		END
		-- Master
		ELSE IF @RoleID = 3
		BEGIN
			INSERT INTO #tmpmatchid (matchid, EventType)
			SELECT DISTINCT CASE WHEN tbl.EventType IN (1, 2, 5) THEN matchid ELSE oddsid END, tbl.EventType
			FROM dbo.bettrans14 b WITH (NOLOCK)
				INNER JOIN #SportBettype tbl ON tbl.bettype = b.bettype
			WHERE b.mrecommend = @custid 
				AND b.statusID NOT IN (101, 102, 103)
				AND winlostdate BETWEEN @fdate AND @tdate;
		END
		-- Agent
		ELSE IF @RoleID = 2
		BEGIN

			INSERT INTO #tmpmatchid (matchid, EventType)
			SELECT DISTINCT CASE WHEN tbl.EventType IN (1, 2, 5) THEN matchid ELSE oddsid END, tbl.EventType
			FROM dbo.bettrans14 b WITH (NOLOCK)
				INNER JOIN #SportBettype tbl ON tbl.bettype = b.bettype
			WHERE b.recommend = @custid 
				AND b.statusID NOT IN (101, 102, 103)
				AND winlostdate BETWEEN @fdate AND @tdate;
		END

		-- get leagueid
		INSERT INTO #tmpLeagues (leagueid, LeagueType)
		SELECT DISTINCT l.leagueid, 0
		FROM dbo.match14 m WITH (NOLOCK) 
			INNER JOIN dbo.league l WITH (NOLOCK) ON m.leagueid = l.leagueid
			INNER JOIN #tmpmatchid tmp ON tmp.matchid = m.matchid
		WHERE m.eventdate BETWEEN @fdate AND @tdate
			AND m.eventstatus = 'completed'
			AND tmp.EventType = 1
			AND l.isTest <= @IsShowAll;
								
		INSERT INTO #tmpLeagues (leagueid, LeagueType) 
		SELECT DISTINCT l.leagueid, 0
		FROM dbo.outright14 m WITH (NOLOCK) 
			INNER JOIN dbo.league l WITH (NOLOCK) ON m.leagueid = l.leagueid 
			INNER JOIN #tmpmatchid tmp ON tmp.matchid = m.orid
		WHERE m.eventdate BETWEEN @fdate AND @tdate
			AND m.oddsstatus = 'completed'
			AND tmp.EventType = 2
			AND l.isTest <= @IsShowAll;

		INSERT INTO #tmpLeagues (leagueid, LeagueType)
		SELECT DISTINCT l.leagueid, 0
		FROM dbo.VSRaceInfo r WITH (NOLOCK) 
			INNER JOIN dbo.league l WITH (NOLOCK) ON r.leagueid = l.leagueid
			INNER JOIN dbo.VSOutright14 o WITH (NOLOCK) ON r.EventID = o.EventID
			INNER JOIN #tmpmatchid tmp ON tmp.matchid = o.orid
		WHERE o.eventdate BETWEEN @fdate AND @tdate
			AND o.eventstatus = 'completed'
			AND tmp.EventType = 3
			AND l.isTest <= @IsShowAll;
	END
	
	DROP TABLE #tmpmatchid;
	DROP TABLE #SportBettype;

	SELECT
		DISTINCT
		l.leagueid,
		l.sporttype,
		tmp.LeagueType,
		CASE @Language 
			WHEN 'E' THEN l.leaguename
			WHEN 'CS' THEN (CASE WHEN l.leaguenamecn= '' or l.leaguenamecn is null THEN l.leaguename ELSE l.leaguenamecn END)
			WHEN 'CT' THEN (CASE WHEN l.leaguenamec_uni= '' or l.leaguenamec_uni is null THEN l.leaguename ELSE l.leaguenamec_uni END)
			WHEN 'TH' THEN (CASE WHEN l.leaguenameth = '' or l.leaguenameth is null THEN l.leaguename ELSE l.leaguenameth END)
			WHEN 'J' THEN (CASE WHEN l.leaguenamej= '' or l.leaguenamej is null THEN l.leaguename ELSE l.leaguenamej END)
			WHEN 'KO' THEN (CASE WHEN l.leaguenameko= '' or l.leaguenameko is null THEN l.leaguename ELSE l.leaguenameko END)
			ELSE l.leaguename
		END	AS leaguename
	FROM #tmpLeagues tmp
		INNER JOIN league l WITH (NOLOCK) ON l.leagueid = tmp.leagueid
	WHERE tmp.LeagueType = 0
	ORDER BY sporttype;
	
	DROP TABLE #tmpLeagues;

	SET NOCOUNT OFF;
END
GO
