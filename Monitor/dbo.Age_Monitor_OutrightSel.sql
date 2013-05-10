 ALTER PROCEDURE [dbo].[Age_Monitor_OutrightSel]
 AS

/*	
	Created	: Johnson
	Task: Monitor lastest bets list- get outright running
	Date: 28/06/2011
	DB: DB05.BODB02
	Revision:
		- 20130228@Elodie: Add Virtual HR product
	Parameter's Explanation:		
		- @matchid: lastest outright's ID running got 
*/ 

 BEGIN
	SET NOCOUNT ON
		
	SELECT 
		l.sporttype AS sporttype,
		m.oddsstatus AS status,
		m.orid AS matchid,		
		m.leagueid,
		m.matchcode,		
		m.teamid AS homeid,
		0 AS awayid,
		ISNULL(m.groupmatch,'') AS race,
		'' showtime
	FROM outright m WITH(NOLOCK)
		INNER JOIN league l WITH(NOLOCK) ON m.leagueid = l.leagueid
	WHERE oddsstatus <> 'completed' 
		AND eventdate >= CONVERT(varchar(10),DATEADD(dd,-1,CURRENT_TIMESTAMP),120)
	
	UNION ALL
	SELECT 
		r.sporttype AS sporttype,
		o.EventStatus AS status,
		o.Orid AS matchid,		
		r.leagueid,
		convert(nvarchar(50), o.RacerNum) matchcode,		
		o.RacerID AS homeid,
		0 AS awayid,
		o.Orid AS race,
		r.EventTime showtime
	FROM VSOutright o WITH(NOLOCK)
		INNER JOIN VSRaceInfo r WITH(NOLOCK) ON o.EventID = r.EventID
	WHERE r.EventStatus <> 'completed' 
		AND eventdate >= CONVERT(varchar(10),DATEADD(dd,-1,CURRENT_TIMESTAMP),120)
 END
 
GO
GRANT EXECUTE ON [dbo].[Age_Monitor_OutrightSel] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_Monitor_OutrightSel] TO [bodbDownlineNetView]
GO
GRANT VIEW DEFINITION ON [dbo].[Age_Monitor_OutrightSel] TO [vnteam]