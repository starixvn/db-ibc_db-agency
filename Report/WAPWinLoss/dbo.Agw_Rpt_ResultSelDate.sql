ALTER PROCEDURE [dbo].[Agw_Rpt_ResultSelDate]		
AS	

/*
Created: QuiNV
Task : Get top 10 date in match result
Date: 12/19/2008
DB: DB05.bodb02
Original: 

Revisions:
	- 20111005@Sophia: Edit the condition of evenstatus
    
Param's Explanation:
 
*/


SET NOCOUNT ON
BEGIN

SELECT TOP 10 *
FROM (

	  SELECT DISTINCT	CONVERT ( VARCHAR(10), eventdate, 101 ) AS evtdt
	  FROM	 match m WITH (NOLOCK)
	  LEFT OUTER JOIN	match_remark mr WITH (NOLOCK)
					ON	m.matchid = mr.matchid
	  WHERE (eventstatus NOT IN ('internal','closed','running')
				OR ( mr.IsPending=1 AND m.eventstatus IN ('running','closed') )
			    OR ( mr.IsHTCal = 1 AND m.eventstatus ='running')
			)
			OR betstatus like 'Refund%' and matchcode not like '%hedge%'
	  UNION ALL

	  SELECT DISTINCT CONVERT ( VARCHAR(10), eventdate, 101 ) AS evtdt
	  FROM match14 m WITH (NOLOCK)
	  LEFT OUTER JOIN	match_remark mr WITH (NOLOCK)
					ON	m.matchid = mr.matchid
	  WHERE (eventstatus NOT IN ('internal','closed','running')
				OR ( mr.IsPending=1 AND m.eventstatus IN ('running','closed') )
			    OR ( mr.IsHTCal = 1 AND m.eventstatus ='running')
			)
			OR betstatus like 'Refund%' and matchcode not like '%hedge%'

)as matchdate
order by evtdt desc

END

GO
GRANT EXECUTE ON [Agw_Rpt_ResultSelDate] TO [bodbDownlineNet]
GO