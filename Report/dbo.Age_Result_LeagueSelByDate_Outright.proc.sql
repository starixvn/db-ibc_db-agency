CREATE PROCEDURE [dbo].[Age_Result_LeagueSelByDate_Outright]
	@FromDate DATETIME,
	@ToDate DATETIME,
	@sporttype tinyint = 0
	
AS
/*
Created:
Task: Get League data into drop down list box for Outright result
DB: DB05.bodb02
Original: LeagueSelForResult

Revisions:    
	- 20080618@HiepVo: CREATE NEW
*/

SET NOCOUNT ON

SELECT DISTINCT 
		league.leagueid
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
	and league.sporttype = case when @sporttype = 0 then league.sporttype else @sporttype end


GO
GRANT EXECUTE ON [dbo].[Age_Result_LeagueSelByDate_Outright] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_Result_LeagueSelByDate_Outright] TO [bodbDownlineNetView]
GO

