/*<info serverAlias="DBAGE-bodb02" executers="bodbAdminNet,bodbDownlineNet,bodbDownlineNetView" viewers="" isFunction="0" isNested="0"></info>*/
USE [bodb02]
GO

ALTER PROCEDURE [dbo].[Age_Rpt_MatchWinloss_GetLeagueByProduct]
	@custid			INT,
	@ProductIds		VARCHAR(MAX),
	@IsShowAll		BIT = 1, 
	@fromdate		SMALLDATETIME,
	@todate			SMALLDATETIME,
	@movebetsday	DATETIME,
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
		- 20171101@Percy: Enhance Performance on bettrans14 [RedmineID: #86200]
*/

BEGIN
	SET NOCOUNT ON;

	DECLARE @showSB	BIT,
			@showRB	BIT,
			@showNG	BIT,
			@showVS	BIT,
			@showLK3 BIT;

	SELECT	@showSB = CASE WHEN PATINDEX('%,1,%', ',' + @ProductIds + ',') > 0 THEN 1 ELSE 0 END,
			@showRB = CASE WHEN PATINDEX('%,2,%', ',' + @ProductIds + ',') > 0 THEN 1 ELSE 0 END,
			@showNG = CASE WHEN PATINDEX('%,3,%', ',' + @ProductIds + ',') > 0 THEN 1 ELSE 0 END,
			@showVS = CASE WHEN PATINDEX('%,5,%', ',' + @ProductIds + ',') > 0 THEN 1 ELSE 0 END,
			@showLK3 = CASE WHEN PATINDEX('%,26,%', ',' + @ProductIds + ',') > 0 THEN 1 ELSE 0 END;

	DECLARE @isTest BIT;
	SELECT  @isTest = dbo.f_CheckSPVersion(@@PROCID);

	IF @IsShowAll IS NULL
		SELECT @IsShowAll = 1;

	SELECT @ProductIds = dbo.f_AddRelatedProducts(@ProductIds);

	CREATE TABLE #SportBettype (
		Bettype INT,
		EventType INT
	);
	
	CREATE CLUSTERED INDEX ix_SportBettype_cl ON #SportBettype(Bettype);

	INSERT INTO #SportBettype (Bettype, EventType)
	SELECT Bettype, EventType
	FROM dbo.f_SportBettypeMatrixByProduct_Sel(@ProductIds, @isTest)
	WHERE EventType IN (1, 2, 3);

	DECLARE @RoleID INT;

	SELECT @RoleID = RoleID FROM dbo.CustInfo WITH (NOLOCK) WHERE custid = @custid;

	CREATE TABLE #tmpLeagues(leagueid INT);
	CREATE TABLE #tmpmatchid(matchid INT, EventType INT UNIQUE(matchid, EventType));

	DECLARE @fdate SMALLDATETIME, @tdate SMALLDATETIME;

	/* range bettrans */
	IF @ToDate > @MoveBetsDay
	BEGIN
		SELECT @tdate = @ToDate, @fdate = CASE WHEN @FromDate <= @MoveBetsDay THEN DATEADD(DAY, 1, @MoveBetsDay) ELSE @FromDate END

		-- Super
		IF @roleid = 4
		BEGIN
			DECLARE @tblRecommend TABLE (recommend INT PRIMARY KEY);

			INSERT INTO @tblRecommend (recommend)
			SELECT CustId
			FROM dbo.custInfo WITH (NOLOCK)
			WHERE roleid = 2 AND srecommend = @CustID;

			INSERT INTO #tmpmatchid (matchid, EventType)
			SELECT DISTINCT CASE WHEN tbl.EventType IN (1, 2) THEN matchid ELSE oddsid END, tbl.EventType
			FROM dbo.bettrans b WITH (NOLOCK)
				INNER JOIN @tblRecommend r ON b.recommend = r.recommend
				INNER JOIN #SportBettype tbl ON tbl.bettype = b.bettype
			WHERE b.statusID NOT IN (101, 102, 103)
				AND b.ruben = 1
				AND winlostdate BETWEEN @fdate AND @tdate;
		END
		-- Master
		ELSE IF @RoleID = 3
		BEGIN
			INSERT INTO #tmpmatchid (matchid, EventType)
			SELECT DISTINCT CASE WHEN tbl.EventType IN (1, 2) THEN matchid ELSE oddsid END, tbl.EventType
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
			SELECT DISTINCT CASE WHEN tbl.EventType IN (1, 2) THEN matchid ELSE oddsid END, tbl.EventType
			FROM dbo.bettrans b WITH (NOLOCK)
				INNER JOIN #SportBettype tbl ON tbl.bettype = b.bettype
			WHERE b.recommend = @custid 
				AND b.statusID NOT IN (101, 102, 103)
				AND b.ruben = 1
				AND winlostdate BETWEEN @fdate AND @tdate;
		END

		-- get leagueid
		INSERT INTO #tmpLeagues (leagueid)
		SELECT DISTINCT l.leagueid
		FROM dbo.match m WITH (NOLOCK) 
			INNER JOIN dbo.league l WITH (NOLOCK) ON m.leagueid = l.leagueid
			INNER JOIN #tmpmatchid tmp ON tmp.matchid = m.matchid
		WHERE m.eventdate BETWEEN @fdate AND @tdate
			AND m.eventstatus = 'completed'
			AND tmp.EventType = 1
			AND l.isTest <= @IsShowAll;
								
		INSERT INTO #tmpLeagues (leagueid) 
		SELECT DISTINCT m.leagueid
		FROM dbo.outright m WITH (NOLOCK) 
			INNER JOIN dbo.league l WITH (NOLOCK) ON m.leagueid = l.leagueid 
			INNER JOIN #tmpmatchid tmp ON tmp.matchid = m.orid
		WHERE m.eventdate BETWEEN @fdate AND @tdate
			AND m.oddsstatus = 'completed'
			AND tmp.EventType = 2
			AND l.isTest <= @IsShowAll;

		INSERT INTO #tmpLeagues (leagueid)
		SELECT DISTINCT l.leagueid
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
			DECLARE @tblMrecommend TABLE (mrecommend INT PRIMARY KEY)

			INSERT INTO @tblMrecommend (mrecommend)
			SELECT CustId
			FROM dbo.custInfo WITH (NOLOCK)
			WHERE roleid = 3 AND srecommend = @CustID;

			INSERT INTO #tmpmatchid (matchid, EventType)
			SELECT DISTINCT CASE WHEN tbl.EventType IN (1, 2) THEN matchid ELSE oddsid END, tbl.EventType
			FROM dbo.bettrans14 b WITH (NOLOCK)
				INNER JOIN @tblMrecommend m ON b.mrecommend = m.mrecommend
				INNER JOIN #SportBettype tbl ON tbl.bettype = b.bettype
			WHERE b.statusID NOT IN (101, 102, 103)
				AND winlostdate BETWEEN @fdate AND @tdate;
		END
		-- Master
		ELSE IF @RoleID = 3
		BEGIN
			INSERT INTO #tmpmatchid (matchid, EventType)
			SELECT DISTINCT CASE WHEN tbl.EventType IN (1, 2) THEN matchid ELSE oddsid END, tbl.EventType
			FROM dbo.bettrans14 b WITH (NOLOCK)
				INNER JOIN #SportBettype tbl ON tbl.bettype = b.bettype
			WHERE b.mrecommend = @custid 
				AND b.statusID NOT IN (101, 102, 103)
				AND winlostdate BETWEEN @fdate AND @tdate;
		END
		-- Agent
		ELSE IF @RoleID = 2
		BEGIN
			DECLARE @mrecommend INT
			SELECT  @mrecommend = mrecommend
			FROM dbo.custInfo WITH (NOLOCK)
			WHERE custid = @custid

			INSERT INTO #tmpmatchid (matchid, EventType)
			SELECT DISTINCT CASE WHEN tbl.EventType IN (1, 2) THEN matchid ELSE oddsid END, tbl.EventType
			FROM dbo.bettrans14 b WITH (NOLOCK)
				INNER JOIN #SportBettype tbl ON tbl.bettype = b.bettype
			WHERE b.mrecommend = @mrecommend
				AND b.recommend = @custid 
				AND b.statusID NOT IN (101, 102, 103)
				AND winlostdate BETWEEN @fdate AND @tdate;
		END

		-- get leagueid
		INSERT INTO #tmpLeagues (leagueid)
		SELECT DISTINCT l.leagueid
		FROM dbo.match14 m WITH (NOLOCK) 
			INNER JOIN dbo.league l WITH (NOLOCK) ON m.leagueid = l.leagueid
			INNER JOIN #tmpmatchid tmp ON tmp.matchid = m.matchid
		WHERE m.eventdate BETWEEN @fdate AND @tdate
			AND m.eventstatus = 'completed'
			AND tmp.EventType = 1
			AND l.isTest <= @IsShowAll;
								
		INSERT INTO #tmpLeagues (leagueid) 
		SELECT DISTINCT m.leagueid
		FROM dbo.outright14 m WITH (NOLOCK) 
			INNER JOIN dbo.league l WITH (NOLOCK) ON m.leagueid = l.leagueid 
			INNER JOIN #tmpmatchid tmp ON tmp.matchid = m.orid
		WHERE m.eventdate BETWEEN @fdate AND @tdate
			AND m.oddsstatus = 'completed'
			AND tmp.EventType = 2
			AND l.isTest <= @IsShowAll;

		INSERT INTO #tmpLeagues (leagueid)
		SELECT DISTINCT l.leagueid
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
		l.leagueid,
		l.sporttype,
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
	ORDER BY l.sporttype;

	DROP TABLE #tmpLeagues;

	SET NOCOUNT OFF;
END
GO
