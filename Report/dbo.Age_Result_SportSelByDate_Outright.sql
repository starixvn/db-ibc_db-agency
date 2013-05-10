CREATE PROCEDURE Age_Result_SportSelByDate_Outright
	@FromDate DATETIME,
	@ToDate DATETIME
AS
/*
Created: 
Task : get SPORT by date for Agent Outright Results page
DB: DB05.bodb02

Revisions:    
	- 20080618@HiepVo: CREATE NEW
				   
*/

SET NOCOUNT ON

SELECT DISTINCT 
	league.sporttype
FROM         
	(SELECT distinct leagueid
	 FROM dbo.outright AS o1 with (nolock)
	 where oddsstatus = 'completed' and [status] = 'WON'
		and eventdate >= @FromDate and eventdate <= @ToDate
	 UNION ALL
	 SELECT distinct leagueid
	 FROM dbo.outright14 AS o14 with (nolock)
	 where oddsstatus = 'completed' and [status] = 'WON'
		and eventdate >= @FromDate and eventdate <= @ToDate
	) AS outright 
	 INNER JOIN dbo.league with (nolock) on outright.leagueid = league.leagueid
WHERE league.sporttype <> 151


GO
GRANT EXECUTE ON [dbo].Age_Result_SportSelByDate_Outright TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].Age_Result_SportSelByDate_Outright TO [bodbDownlineNetView]
GO



 