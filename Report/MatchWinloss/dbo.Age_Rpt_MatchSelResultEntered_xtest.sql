 
ALTER PROCEDURE [dbo].[Age_Rpt_MatchSelResultEntered_xtest]   
 @isShowAll bit = 1 -- 1: Show All; 0: is NOT show Test  
AS  
/*  
Created:   
Task :   
DB: DB052.bodb02  
Original:Age_Rpt_MatchSelResultEntered, Dot_Member_RawMenu  
Revisions:  
    - 20100528@Terry: Add more sporttype Entertainment  
    - 20101105@Terry: Add more sporttype NumberGame  
    - 20101207@Simon: Show All League or only show Live belong to @isShowAll.  
	- 20110302@Lukas: add more sporttype Greyhound Racing(152), Harness Racing (153)
	- 20110421@Lukas: add Netball game (sporttype = 32)  
	- 20110525@Jamie: Optimize the way to get data 
	- 20120202@Sophia: Optimize the way to get data 
*/  
SET NOCOUNT ON


SELECT @ISSHOWALL = CASE @ISSHOWALL	WHEN 1 THEN NULL ELSE 0	END  
  
Declare @FromDate datetime, @ToDate datetime

SELECT @TODATE = CONVERT ( DATETIME, CONVERT ( NVARCHAR(20), GETDATE ( ), 101 ) )
SELECT @FROMDATE = DATEADD ( dd, -1, @TODATE )


SELECT	DATEDIFF ( dd, @FROMDATE, a.kickofftime ) AS IsToday, a.kickofftime as Eventdate, a.Sporttype,  COUNT (MATCHID), 
		SUM ( CASE WHEN eventstatus IN ('completed', 'refund') THEN 1 ELSE 0	END ) AS Entered,
		SUM ( CASE WHEN eventstatus NOT IN ('completed', 'refund') THEN 1 ELSE 0 END ) AS NonEntered
FROM (
	SELECT DISTINCT matchID, match.sporttype  , CONVERT(DATETIME,CONVERT(NVARCHAR(20),kickofftime,101)) as kickofftime , EventStatus
	FROM (
			--***************NonEntered
			--All Sport and Number game
			SELECT	LeagueID, kickofftime , 
					MAX ( EventStatus ) AS EventStatus,  
					m.sporttype, o.bettype, m.matchID
			FROM	Match m WITH (NOLOCK)
				INNER JOIN Odds o WITH (NOLOCK) ON	m.matchid = o.matchid
			WHERE	CASE WHEN	m.eventstatus IN (N'running', N'internal') 
								and o.oddsstatus IN (N'running',N'internal',N'closePrice', N'suspend') 
								and kickofftime > DATEADD(hour,-10,CURRENT_TIMESTAMP) 
					THEN 1 ELSE 0 END = 1	
					AND m.sporttype <> 162
					AND kickofftime <= @ToDate
			GROUP BY leagueid, kickofftime, m.matchid, m.sporttype, o.bettype ,m.matchid

			--Live Casino
			UNION ALL
			SELECT	LeagueID, kickofftime,
					MAX(EventStatus ) AS EventStatus, m.sporttype, 0 as bettype,  m.matchID
			FROM	Match m WITH (NOLOCK)	
			WHERE	m.eventstatus IN (N'running', N'internal') 
					AND m.sporttype = 162
					and kickofftime BETWEEN @FROMDATE AND @TODATE
			GROUP BY leagueid, kickofftime, m.matchid,m.sporttype,m.matchid

			UNION ALL
			--Add the next day Match from 21 PM 
			SELECT  LeagueID, kickofftime,
					MAX( EventStatus ) AS EventStatus,  m.sporttype, o.bettype,  m.matchID
			FROM	Match m with (nolock) 
				INNER JOIN Odds o with(nolock) ON m.matchid=o.matchid
			WHERE o.bettype in (1,2,3,5,7,8,12,15,20,21,22)
				and (datepart(hour,CURRENT_TIMESTAMP) >= 21)
				and kickofftime between DATEADD(day,1,CONVERT(char(10),CURRENT_TIMESTAMP,120)) and DATEADD(day,2,CONVERT(char(10),CURRENT_TIMESTAMP,120)) 
				and eventstatus=N'running' 
				AND o.oddsstatus in (N'running',N'suspend',N'closePrice')
				AND kickofftime<= @TODATE
			GROUP BY leagueid, kickofftime, m.matchid ,m.sporttype,o.bettype,m.matchid

			UNION ALL

		--	Outright and HorseRacing
			SELECT  o.LeagueID,
					-- kickofftime,
				    CASE WHEN o.creator = 151 
				    THEN (SELECT MIN(kickofftime)
						 FROM Outright
						 WHERE leagueid = o.leagueid AND eventdate = o.eventdate) 
					ELSE kickofftime
					END as kickofftime,			 
					MAX ( OddsStatus ) AS EventStatus, 
					CASE WHEN leaguename LIKE '%NFL%' AND l.sporttype = 2 THEN 3
						 WHEN (leaguename LIKE '%NHL%' OR leaguename LIKE '%hockey%') AND l.sporttype = 2 THEN 4
					ELSE l.sporttype 
					END as sporttype,
					case when o.creator = 151 then 151 else 10 end as bettype,
					o.LeagueID as matchID
			FROM	Outright o WITH (NOLOCK)
				INNER JOIN League l WITH (NOLOCK)	ON o.LeagueId = l.LeagueId  
			WHERE	case
					when o.creator = 151 and o.oddsstatus IN (N'running',N'internal',N'closePrice', N'suspend') 
						 and programdate between DATEADD(day,-1,CONVERT(char(10),CURRENT_TIMESTAMP,120)) 
						 and CONVERT(char(10),CURRENT_TIMESTAMP,120) then 1
					when o.creator <> 151 and o.oddsstatus IN (N'running',N'internal',N'closePrice') and o.kickofftime > CURRENT_TIMESTAMP then 1
					else 0
					end = 1
			 		AND  kickofftime <= @TODATE
			GROUP BY o.LeagueID, kickofftime, GroupMatch ,o.eventdate,o.creator, l.leaguename, l.sporttype
			
					
			UNION ALL
			---*********************** Entered 
			--All Sport and Number game and Live Casino
			SELECT	LeagueID,  kickofftime,
					MAX ( EventStatus ) AS EventStatus, m.sporttype, 0 as bettype, m.matchid
			FROM	Match m WITH (NOLOCK)
			WHERE	m.eventstatus = 'completed'
					AND kickofftime BETWEEN @FROMDATE AND @TODATE
			GROUP BY leagueid, kickofftime, m.matchid, m.sporttype, m.matchid
			
			UNION ALL 
			SELECT	o.LeagueID, kickofftime,
					MAX ( OddsStatus ) AS EventStatus, 
					CASE WHEN leaguename LIKE '%NFL%' AND l.sporttype = 2 THEN 3
						 WHEN (leaguename LIKE '%NHL%' OR leaguename LIKE '%hockey%') AND l.sporttype = 2 THEN 4
					ELSE l.sporttype 
					END as sporttype, 
					case when o.creator = 151 then 151 else 10 end as bettype,
					o.LeagueID as matchID
			from Outright o with (NOLOCK)   
			inner join League l with (NOLOCK)  on o.LeagueId = l.LeagueId  
			WHERE	o.OddsStatus = 'completed' --<> 'closed'  
 				  AND kickofftime BETWEEN @FROMDATE AND @TODATE
			GROUP BY o.LeagueID, kickofftime, GroupMatch ,o.eventdate,o.creator, l.leaguename, l.sporttype
	
	 ) as Match
	INNER JOIN League l with (NOLOCK) on Match.LeagueID = l.LeagueID and l.isTest = isnull(@isShowAll, l.isTest)   

) a
 
GROUP BY DATEDIFF ( dd, @FROMDATE, a.kickofftime ),a.kickofftime, a.sporttype  
ORDER BY DATEDIFF ( dd, @FROMDATE, a.kickofftime ), a.kickofftime , a.Sporttype 


GO
GRANT EXECUTE ON [dbo].[Age_Rpt_MatchSelResultEntered] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_Rpt_MatchSelResultEntered] TO [bodbDownlineNetView]
GO
GRANT VIEW DEFINITION ON [dbo].[Age_Rpt_MatchSelResultEntered] TO [vnteam]
GO