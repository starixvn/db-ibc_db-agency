/*<info serverAlias="DBAGE-bodb02" executers="bodbAdminNet,bodbDownlineNet,bodbDownlineNetView" viewers="vnteam" isFunction="0" isNested="0"></info>*/
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

	SELECT @IsShowAll = CASE @IsShowAll WHEN 1 THEN NULL ELSE 0 END;

	DECLARE @RoleID INT;

	SELECT TOP 1 @RoleID = RoleID 
	FROM dbo.CustInfo (NOLOCK) 
	WHERE custid = @custid;

	CREATE TABLE #tmpLeagues(leagueid INT);

	CREATE TABLE #tmpmatchid(matchid INT);

	DECLARE @fdate SMALLDATETIME,
			@tdate SMALLDATETIME;

	SELECT	@fdate = @fromdate,
			@tdate = @todate;

	IF @roleid = 4
	BEGIN
		DECLARE @recommend TABLE (CustId INT PRIMARY KEY);

		INSERT INTO @recommend (CustId)
		SELECT CustId 
		FROM dbo.custInfo (NOLOCK) 
		WHERE roleid = 2 AND srecommend = @CustID;

		IF @Todate > @MoveBetsDay
		BEGIN
			IF @fromdate <= @movebetsday
			BEGIN
				SET @fdate = DATEADD(DD, 1, @movebetsday);
			END

			INSERT INTO #tmpmatchid(matchid)
			SELECT DISTINCT CASE WHEN tbl.EventType = 1 THEN matchid 
								WHEN tbl.EventType = 2 THEN matchid
								WHEN tbl.EventType = 3 THEN oddsid
							END
			FROM dbo.bettrans b WITH(NOLOCK)
				INNER JOIN @recommend m ON b.recommend = m.CustId
				JOIN #SportBettype tbl ON tbl.bettype = b.bettype
			WHERE b.statusID NOT IN (101, 102, 103)
				AND b.ruben = 1
				AND winlostdate BETWEEN @fdate AND @tdate;									
		END

		SELECT	@fdate = @fromdate,
				@tdate = @todate;

		IF @fromdate <= @MoveBetsDay
		BEGIN
			IF @todate > @movebetsday
			BEGIN
				SET @tdate = @movebetsday;
			END

			INSERT INTO #tmpmatchid(matchid)
			SELECT DISTINCT CASE WHEN tbl.EventType = 1 THEN matchid 
								WHEN tbl.EventType = 2 THEN matchid
								WHEN tbl.EventType = 3 THEN oddsid
							END
			FROM dbo.bettrans14 b WITH(NOLOCK)
				JOIN #SportBettype tbl ON tbl.bettype = b.bettype
			WHERE b.srecommend = @custid 
				AND b.statusID NOT IN (101, 102, 103)
				AND b.ruben = 1
				AND winlostdate BETWEEN @fdate AND @tdate;
		END
	END

	IF @roleid = 3
	BEGIN
		IF @Todate > @MoveBetsDay
		BEGIN
			IF @fromdate <= @movebetsday
			BEGIN
				SET @fdate = DATEADD(DD, 1, @movebetsday);
			END

			INSERT INTO #tmpmatchid(matchid)
			SELECT DISTINCT CASE WHEN tbl.EventType = 1 THEN matchid 
								WHEN tbl.EventType = 2 THEN matchid
								WHEN tbl.EventType = 3 THEN oddsid
							END
			FROM dbo.bettrans b WITH(NOLOCK)
				JOIN #SportBettype tbl ON tbl.bettype = b.bettype
			WHERE b.mrecommend = @custid 
				AND b.statusID NOT IN (101, 102, 103)
				AND b.ruben = 1
				AND winlostdate BETWEEN @fdate AND @tdate;									
		END

		SELECT	@fdate = @fromdate,
				@tdate = @todate;

		IF @fromdate <= @MoveBetsDay
		BEGIN
			IF @todate > @movebetsday
			BEGIN
				SET @tdate = @movebetsday;
			END

			INSERT INTO #tmpmatchid(matchid)
			SELECT DISTINCT CASE WHEN tbl.EventType = 1 THEN matchid 
								WHEN tbl.EventType = 2 THEN matchid
								WHEN tbl.EventType = 3 THEN oddsid
							END
			FROM dbo.bettrans14 b WITH(NOLOCK)
				JOIN #SportBettype tbl ON tbl.bettype = b.bettype
			WHERE b.mrecommend = @custid 
				AND b.statusID NOT IN (101, 102, 103)
				AND b.ruben = 1
				AND winlostdate BETWEEN @fdate AND @tdate;
		END
	END

	IF @roleid = 2
	BEGIN
		IF @Todate > @MoveBetsDay
		BEGIN
			IF @fromdate <= @movebetsday
			BEGIN
				SET @fdate = DATEADD(DD, 1, @movebetsday);
			END

			INSERT INTO #tmpmatchid(matchid)
			SELECT DISTINCT CASE WHEN tbl.EventType = 1 THEN matchid 
								WHEN tbl.EventType = 2 THEN matchid
								WHEN tbl.EventType = 3 THEN oddsid
							END
			FROM dbo.bettrans b WITH(NOLOCK)
				JOIN #SportBettype tbl ON tbl.bettype = b.bettype
			WHERE b.recommend = @custid 
				AND b.statusID NOT IN (101, 102, 103)
				AND b.ruben = 1
				AND winlostdate BETWEEN @fdate AND @tdate;		
		END

		SELECT	@fdate = @fromdate,
				@tdate = @todate;

		IF @fromdate <= @MoveBetsDay
		BEGIN
			IF @todate > @movebetsday
			BEGIN
				SET @tdate = @movebetsday;
			END

			INSERT INTO #tmpmatchid(matchid)
			SELECT DISTINCT CASE WHEN tbl.EventType = 1 THEN matchid 
								WHEN tbl.EventType = 2 THEN matchid
								WHEN tbl.EventType = 3 THEN oddsid
							END
			FROM dbo.bettrans14 b WITH(NOLOCK)
				JOIN #SportBettype tbl ON tbl.bettype = b.bettype
			WHERE b.recommend = @custid 
				AND b.statusID NOT IN (101, 102, 103)
				AND b.ruben = 1
				AND winlostdate BETWEEN @fdate AND @tdate;					
		END
	END

	IF @Todate > @MoveBetsDay
	BEGIN
		INSERT INTO #tmpLeagues(leagueid)
		SELECT DISTINCT m.leagueid
		FROM match m WITH(NOLOCK) 
			INNER JOIN league l WITH(NOLOCK) ON m.leagueid = l.leagueid
			INNER JOIN #tmpmatchid tmp ON tmp.matchid = m.matchid
		WHERE m.eventdate >= @fromdate 
			AND m.eventdate <= @todate
			AND m.eventstatus = 'completed'
			AND 1 = CASE WHEN @showSB = 1 AND l.sporttype <= 99 THEN 1
						 WHEN @showNG = 1 AND l.sporttype = 161 THEN 1
						 WHEN @showVS = 1 AND l.sporttype IN (180, 186, 190, 191) THEN 1
						 WHEN @showLK3 = 1 AND l.sporttype = 160 THEN 1
						 ELSE 0 END
			AND l.isTest = isnull(@IsShowAll, l.isTest);
						
		INSERT INTO #tmpLeagues(leagueid)
		SELECT DISTINCT r.leagueid
		FROM VSRaceInfo r WITH(NOLOCK) 
			INNER JOIN league l WITH(NOLOCK) ON r.leagueid = l.leagueid
			INNER JOIN VSOutright o WITH(NOLOCK) ON r.EventID = o.EventID
			INNER JOIN #tmpmatchid tmp ON tmp.matchid = o.orid
		WHERE o.EventDate >= @fromdate 
			AND o.EventDate <= @todate
			AND o.eventstatus = 'completed'
			AND @showVS = 1 AND r.sporttype in (181, 182, 184,183,185)
			AND l.isTest = isnull(@IsShowAll, l.isTest);
								
		INSERT INTO #tmpLeagues(leagueid) 
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
			AND l.isTest = isnull(@IsShowAll, l.isTest);
						
	END				 

	IF @fromdate <= @MoveBetsDay
	BEGIN
		INSERT INTO #tmpLeagues(leagueid)
		SELECT DISTINCT m.leagueid
		FROM match14 m WITH(NOLOCK) 
			INNER JOIN league l WITH(NOLOCK) ON m.leagueid = l.leagueid
			INNER JOIN #tmpmatchid tmp ON tmp.matchid = m.matchid
		WHERE m.eventdate >= @fromdate 
			AND m.eventdate <= @todate
			AND m.eventstatus = 'completed'
			AND 1 = CASE WHEN @showSB = 1 AND l.sporttype <= 99 THEN 1
						 WHEN @showNG = 1 AND l.sporttype = 161 THEN 1
						 WHEN @showVS = 1 AND l.sporttype IN (180, 186, 190, 191) THEN 1
						 WHEN @showLK3 = 1 AND l.sporttype = 160 THEN 1
						 ELSE 0 END
			AND l.isTest = isnull(@IsShowAll, l.isTest);
						
		INSERT INTO #tmpLeagues(leagueid)
		SELECT DISTINCT r.leagueid
		FROM VSRaceInfo r WITH(NOLOCK) 
			INNER JOIN league l WITH(NOLOCK) ON r.leagueid = l.leagueid
			INNER JOIN VSOutright14 o WITH(NOLOCK) ON r.EventID = o.EventID		
			INNER JOIN #tmpmatchid tmp ON tmp.matchid = o.orid
		WHERE o.EventDate >= @fromdate 
			AND o.EventDate <= @todate
			AND o.eventstatus = 'completed'
			AND @showVS = 1 AND r.sporttype IN(181, 182, 184,183,185)
			AND l.isTest = isnull(@IsShowAll, l.isTest);
						
		INSERT INTO #tmpLeagues(leagueid)
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
			AND l.isTest = isnull(@IsShowAll, l.isTest);
	END

	DROP TABLE #tmpmatchid;

	SELECT	DISTINCT l1.leagueid , l1.sporttype,
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
	ORDER BY l1.sporttype;

	DROP TABLE #tmpLeagues;
	DROP TABLE #SportBettype;

	SET NOCOUNT OFF;
END
GO
