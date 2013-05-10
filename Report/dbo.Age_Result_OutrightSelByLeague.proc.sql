CREATE PROCEDURE [dbo].[Age_Result_OutrightSelByLeague]
	@FromDate DATETIME,
	@ToDate DATETIME,
	@LeagueID INT = 0,
	@sporttype tinyint = 0	
AS 

/*
Created:
Task: Get Result Outright (exclude Horse Racing)
DB: DB05.bodb02

Revisions:    
	- 20080618@HiepVo: CREATE NEW
*/

SELECT DISTINCT 
		league.sporttype, outright.leagueid, outright.eventdate, outright.teamid, 
		outright.status
	FROM         
		(SELECT leagueid, eventdate, teamid, status
		 FROM dbo.outright AS o1 with (nolock)
		 where oddsstatus = 'completed' and [status] = 'WON'
			and eventdate >= @FromDate and eventdate <= @ToDate
			and leagueid = case when @LeagueID = 0 then leagueid else @LeagueID end
		 UNION ALL
		 SELECT leagueid, eventdate, teamid, status
		 FROM dbo.outright14 AS o14 with (nolock)
		 where oddsstatus = 'completed' and [status] = 'WON'
			and eventdate >= @FromDate and eventdate <= @ToDate
			and leagueid = case when @LeagueID = 0 then leagueid else @LeagueID end
		) AS outright 
		 INNER JOIN dbo.league with (nolock) on outright.leagueid = league.leagueid
	WHERE league.sporttype <> 151
	and league.sporttype = case when @sporttype = 0 then league.sporttype else @sporttype end
	ORDER BY outright.eventdate, outright.teamid
	
GO
GRANT EXECUTE ON [dbo].[Age_Result_OutrightSelByLeague] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_Result_OutrightSelByLeague] TO [bodbDownlineNetView]
GO