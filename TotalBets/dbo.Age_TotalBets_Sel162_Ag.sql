ALTER PROCEDURE [dbo].[Age_TotalBets_Sel162_Ag]
	@custid INT,
	@Language varchar(2) = 'E'
AS


/*
Created:  20120116@Sophia
Task : Retrieve Total Bet values for Live Casino
DB: DB053.bodb02

Revisions:
	    
Param's Explanation:
• @custid: Agent ID
*/


SET NOCOUNT ON

SELECT  m.bettype, 
		m.showtime,
		m.matchid,
		m.leagueid, 
		sum( Banker) Banker,
		sum( Player) Player,
		sum( Others) Others
FROM (
			SELECT  b.bettype,
					m.showtime,
					m.matchid,
					m.leagueid,
					sum(Case when bettype=1101 and betteam = '1' then Stake else 0 End) AS Banker,
					sum(Case when bettype=1101 and betteam = '2' then Stake else 0 End) AS Player,
					sum(Case when (bettype=1101 and betteam NOT IN ('1','2')) OR (bettype<>1101) then Stake else 0 End) AS Others	
			FROM
				(SELECT
						bg.matchid,
						bg.bettype,
						bg.betteam,						
						SUM(bg.apositiontaking * bg.stake * case when abs(bg.odds) <1 then 1 else abs(bg.odds) end) Stake
				FROM	bettransg bg with (nolock)
						INNER JOIN bettrans b WITH (NOLOCK) ON bg.refno = b.refno
				WHERE
						b.bettype BETWEEN 1101 AND 1199
						AND b.recommend = @custid
						AND b.ruben = 0
				GROUP BY bg.matchid, bg.bettype, bg.betteam ) as b 
				INNER JOIN match m WITH (NOLOCK) ON m.matchid = b.matchid  	
			WHERE	
				m.eventstatus = 'running'
			GROUP BY
				b.bettype,
				m.showtime,
				m.matchid,
				m.leagueid
				) m
	GROUP BY
			m.bettype,
			m.showtime,
		    m.matchid,
			m.leagueid
ORDER BY	m.bettype

GO
GRANT EXECUTE ON [dbo].[Age_TotalBets_Sel162_Ag] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_TotalBets_Sel162_Ag] TO [bodbDownlineNetView]
GO
GRANT VIEW DEFINITION ON [dbo].[Age_TotalBets_Sel162_Ag] TO [vnteam]
