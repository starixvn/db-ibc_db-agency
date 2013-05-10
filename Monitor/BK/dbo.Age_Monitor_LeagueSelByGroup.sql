  ALTER PROCEDURE [dbo].[Age_Monitor_LeagueSelByGroup] 
 @custid int = 0,   
 @Language NVARCHAR(2) = 'E',    
 @sporttypegroup tinyint = 0, 
 @isShowAll bit = 1 -- 1: Show All; 0: is NOT show Test
     
AS    
/*    
Created: Johnson   
Date: 2010-12-28
Task:   Monitor Last Bet List
DB: DB05.bodb02    
Original:   
    
Revisions:
	- 20110128@Amy: select HR meeting in 2 days (today and tomorrow)
					select outright leagues with eventdate >= today
	- 20110129@Amy: get league name by language and sort by leaguename
 
 Parameter's Explanation:
 - @custid : Agent's ID 
 - @sporttypegroup : 0: all sports, 1: soccer, 99: others
 - @isShowAll: 1: Show All; 0: is NOT show Test
*/    
    
SET NOCOUNT ON    

--DECLARE @roleid INT
CREATE TABLE #league(leagueid int, sporttype int)
DECLARE @Disable151 BIT , -- Horse Racing
	@Disable161	BIT -- Number Game
	
DECLARE @Fromdate DATETIME
DECLARE @Todate DATETIME
SET @Fromdate=CONVERT(varchar(8), GETDATE(), 112) 
SET @Todate=dateadd(day,1,@Fromdate)
	
SELECT @isShowAll = CASE @isShowAll WHEN 1 THEN NULL ELSE 0 END

SELECT @Disable151 = CASE WHEN DisableHorseRacing = 0 THEN 0
						WHEN DisableOpenTote = 0 THEN 0 ELSE 1 END,
	@Disable161 = DisableNumber	
	FROM Custinfo WITH(NOLOCK)
	WHERE custid = @custid
	
    	
IF @sporttypegroup = 0 -- get all sports
BEGIN
	
	INSERT INTO #league
	SELECT distinct m.leagueid,m.sporttype
	FROM match m WITH(NOLOCK) 		
	WHERE m.eventstatus != 'completed' AND		
		CASE WHEN m.sporttype = 161 AND @Disable161 = 1 THEN 0 ELSE 1 END = 1 
		
	--Outright
	INSERT INTO #league
	SELECT distinct l.leagueid,l.sporttype
	FROM outright o WITH(NOLOCK) 
		INNER JOIN league l WITH(NOLOCK) ON o.leagueid = l.leagueid 
	WHERE o.oddsstatus != 'completed' AND	
			(o.eventdate >= @Fromdate) AND
			l.sporttype <> 151
		
	-- Horse Racing
	IF @Disable151=0 
	BEGIN
		INSERT INTO #league
		SELECT distinct l.leagueid,l.sporttype
		FROM outright o WITH(NOLOCK) 
			INNER JOIN league l WITH(NOLOCK) ON o.leagueid = l.leagueid 
		WHERE o.oddsstatus != 'completed' AND	
				(o.eventdate between @Fromdate and @Todate) AND
				l.sporttype = 151
	END
		
END	
ELSE IF @sporttypegroup = 1 -- Soccer 
BEGIN
	INSERT INTO #league
	SELECT distinct m.leagueid, m.sporttype
	FROM match m WITH(NOLOCK) 
	WHERE m.eventstatus != 'completed' AND m.sporttype = 1
		
	--Outright
	INSERT INTO #league
	SELECT distinct l.leagueid,l.sporttype
	FROM outright o WITH(NOLOCK) 
		INNER JOIN league l WITH(NOLOCK) ON o.leagueid = l.leagueid 
	WHERE o.oddsstatus != 'completed' AND 
			(o.eventdate >= @Fromdate) AND
			l.sporttype = 1
			
END	
ELSE  -- Other Sports
BEGIN
	INSERT INTO #league
	SELECT distinct m.leagueid, m.sporttype
	FROM match m WITH(NOLOCK) 
	WHERE m.eventstatus != 'completed' AND m.sporttype <> 1 AND		
		CASE WHEN m.sporttype = 161 AND @Disable161 = 1 THEN 0 ELSE 1 END = 1 
		
	--Outright
	INSERT INTO #league
	SELECT distinct l.leagueid,l.sporttype
	FROM outright o WITH(NOLOCK) 
		INNER JOIN league l WITH(NOLOCK) ON o.leagueid = l.leagueid 
	WHERE o.oddsstatus != 'completed' AND 
			(o.eventdate >= @Fromdate) AND
		l.sporttype not in (1,151)
		
	-- Horse racing
	IF @Disable151=0 
	BEGIN
		INSERT INTO #league
		SELECT distinct l.leagueid,l.sporttype
		FROM outright o WITH(NOLOCK) 
			INNER JOIN league l WITH(NOLOCK) ON o.leagueid = l.leagueid 
		WHERE o.oddsstatus != 'completed' AND 
				(o.eventdate between @Fromdate and @Todate) AND
			l.sporttype = 151
	END
END

SELECT distinct l.sporttype,l.leagueid , 
	CASE @Language 
		WHEN 'E' THEN l1.leaguename
		WHEN 'CS' THEN (case when l1.leaguenamecn= '' or l1.leaguenamecn is null then l1.leaguename else l1.leaguenamecn end)
		WHEN 'CT' THEN (case when l1.leaguenamec_uni= '' or l1.leaguenamec_uni is null then l1.leaguename else l1.leaguenamec_uni end)
		WHEN 'TH' THEN (case when l1.leaguenameth = '' or l1.leaguenameth is null then l1.leaguename else l1.leaguenameth end)
		WHEN 'J' THEN (case when l1.leaguenamej= '' or l1.leaguenamej is null then l1.leaguename else l1.leaguenamej end)
		WHEN 'KO' THEN (case when l1.leaguenameko= '' or l1.leaguenameko is null then l1.leaguename else l1.leaguenameko end)
		ELSE l1.leaguename
	END	 as leaguename
FROM #league l
LEFT JOIN league l1 WITH(NOLOCK) ON l.leagueid = l1.leagueid
WHERE l1.isTest = isnull(@isShowAll,l1.isTest)
ORDER BY l.sporttype, leaguename

drop table #league
GO
GRANT EXECUTE ON [dbo].[Age_Monitor_LeagueSelByGroup] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_Monitor_LeagueSelByGroup] TO [bodbDownlineNetView]
GO
GRANT VIEW DEFINITION ON [dbo].[Age_Monitor_LeagueSelByGroup] TO [vnteam]
GO
