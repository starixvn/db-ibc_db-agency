/*<info serverAlias="DBAGE-bodb02" executers="bodbDownlineNet,bodbDownlineNetView" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Age_Rpt_MatchSelResultEntered]
	@IncludeTestData BIT = 1 -- 1: Show All; 0: is NOT show Test  
AS

/*  
	Created:   
	Task:
	DB: DBAGE.bodb02  
	Original: Age_Rpt_MatchSelResultEntered  
	
	Revisions:  
		- 20100528@Terry: Add more sporttype Entertainment  
		- 20101105@Terry: Add more sporttype NumberGame  
		- 20101207@Simon: Show All League or only show Live belong to @isShowAll.  
		- 20110302@Lukas: add more sporttype Greyhound Racing(152), Harness Racing (153)
		- 20110421@Lukas: add Netball game (sporttype = 32)  
		- 20110525@Jamie: Optimize the way to get data
		- 20120906@Thien: fix issue: Entered/Non-Entered report wrongly recognizes refund" racing race as "Non-Entered"
		- 20130226@Elodie: Add Virtual HR product
		- 20140618@Viet: enhance sp
		- 20150310@Cody: Apply sport bettype matrix [redmine: #30169]
		- 20160329@Francis: Revise sp not to use SportBettypeMatrix to enhance performance
		- 20160429@Dominic: Remove redundant logic/enhance SP -  [Redmine: #55746]
		- 20161228@Paul: change IsToday data type from INT to BIT, @isShowAll to @IncludeTestData -  [Redmine: #66991]
		- 20171020@Percy: Add match3rd table [RedmineID: #84690]
		- 20180125@Percy: Rollback code for BF [RedmineID: #90043]
		- 20180814@Percy: Reopen code for BF [RedmineID: #90258]
		- 20190826@Percy: Remove inactive products [RedmineID: #118699]
		- 20211115@Malcolm: Exclude Matchs are deleted [Redmine: #164321]
*/
 
BEGIN
	SET NOCOUNT ON

	DECLARE @FromDate DATETIME, @ToDate DATETIME

	-- from yesterday to today
	SELECT @ToDate = CONVERT(DATE, GETDATE())
	SELECT @FromDate = DATEADD(DAY, -1, @ToDate)

	CREATE TABLE #tmp(IsToday BIT, EventDate SMALLDATETIME, Sporttype INT, Entered INT, NonEntered INT)
		
	-- match
	;WITH m AS (
		SELECT leagueid, eventdate,
			SUM(CASE WHEN eventstatus IN ('completed', 'refund') THEN 1 ELSE 0 END) AS Entered,
			SUM(CASE WHEN eventstatus NOT IN ('completed', 'refund') THEN 1 ELSE 0 END) AS NonEntered
		FROM dbo.match WITH (NOLOCK)
		WHERE eventdate BETWEEN @FromDate AND @ToDate
			AND eventStatus <> 'closed'
			AND IsDeleted <> 1
		GROUP BY leagueid, eventdate
	)
	INSERT INTO #tmp (IsToday, EventDate, Sporttype, Entered, NonEntered)
	SELECT
		CASE WHEN DATEDIFF(DAY, @ToDate, m.eventdate) = 0 THEN 1 ELSE 0 END AS IsToday,
		m.eventdate, l.sporttype,
		SUM(Entered) Entered, SUM(NonEntered) NonEntered
	FROM m
		INNER JOIN dbo.League l WITH (NOLOCK) ON m.leagueid = l.leagueid
	WHERE l.isTest <= @IncludeTestData AND l.IsDeleted <> 1
	GROUP BY m.eventdate, l.sporttype

	-- Outright
	INSERT INTO #tmp (IsToday, EventDate, Sporttype, Entered, NonEntered)
	SELECT
		CASE WHEN DATEDIFF(DAY, @ToDate, eventdate) = 0 THEN 1 ELSE 0 END AS IsToday,
		eventdate, sporttype,
		SUM(CASE WHEN eventstatus IN ('completed', 'refund') THEN 1 ELSE 0 END) AS Entered,
		SUM(CASE WHEN eventstatus NOT IN ('completed', 'refund') THEN 1 ELSE 0 END) AS NonEntered
	FROM
	(
		SELECT m.LeagueID, l.sporttype, m.eventdate, MAX(OddsStatus) AS eventstatus
		FROM dbo.Outright m WITH (NOLOCK)
			INNER JOIN dbo.League l WITH (NOLOCK) ON m.LeagueId = l.LeagueId AND l.Sporttype BETWEEN 151 AND 153
		WHERE m.eventdate BETWEEN @FromDate AND @ToDate
			AND m.OddsStatus <> 'closed'
			AND l.isTest <= @IncludeTestData
			AND m.IsDeleted <> 1
			AND l.IsDeleted <> 1
		GROUP BY m.LeagueID, l.sporttype, m.eventdate, m.GroupMatch
	) AS match
	GROUP BY eventdate, sporttype

	-- VSRaceInfo, VSOutright
	INSERT INTO #tmp (IsToday, EventDate, Sporttype, Entered, NonEntered)
	SELECT
		CASE WHEN DATEDIFF(DAY, @ToDate, m.eventdate) = 0 THEN 1 ELSE 0 END AS IsToday,
		m.eventdate, l.sporttype,
		SUM(CASE WHEN m.eventstatus IN ('completed', 'refund') THEN 1 ELSE 0 END) AS Entered,
		SUM(CASE WHEN m.eventstatus NOT IN ('completed', 'refund') THEN 1 ELSE 0 END) AS NonEntered
	FROM
	(
		SELECT r.LeagueID, o.EventDate, MAX(r.EventStatus) AS eventstatus
		FROM VSRaceInfo r WITH (NOLOCK)
			INNER JOIN VSOutright o WITH (NOLOCK) ON o.EventID = r.EventID
		WHERE o.EventDate BETWEEN @FromDate AND @ToDate
			AND r.EventStatus <> 'closed'
		GROUP BY r.LeagueID, o.EventDate, r.EventTime
	) AS m
		INNER JOIN dbo.League l WITH (NOLOCK) ON m.LeagueID = l.LeagueID
	WHERE l.isTest <= @IncludeTestData AND l.IsDeleted <> 1
	GROUP BY m.EventDate, l.sporttype
	
	SELECT IsToday, EventDate, Sporttype, Entered, NonEntered
	FROM #tmp
	ORDER BY EventDate, sporttype

	DROP TABLE #tmp
END
GO