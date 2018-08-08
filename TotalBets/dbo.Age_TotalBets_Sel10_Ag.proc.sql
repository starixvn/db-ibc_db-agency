/*<info serverAlias="DB042-bodb02" executers="bodbDownlineNet,bodbDownlineNetView" viewers="vnteam" isFunction="0"></info>*/	
ALTER PROCEDURE [dbo].[Age_TotalBets_Sel10_Ag]
@custid int,
@Language varchar(2) = 'E'
 AS
 
/*
Created: 20090122@Thien
Task : Retrieve Total Bet values for bettype 10
DB: DB053.bodb02
Original:

Revisions:
    - 20060222: remove refno
    - 20090217@HanhVu: change the formula of totalwinlost value (member's won - member's lose)
    -- 20100527@Henry: Change to use StatusID instead of Status in WHERE statement
	- 20180802@Helen: Update code for adjusting indexes - [Redmine:98757] 
	
Param's Explanation:
• @custid: agent ID
*/
BEGIN
	SET NOCOUNT ON
	SELECT
		m.leagueid, 
		m.matchcode, 
		m.orid,
		m.teamid,
		sum(a.apositiontaking*stake) AS balance,
		sum(1) as BetCount,
		sum(a.apositiontaking*stake*a.odds) - isnull(leaguetotal.totalbalance, 0) as totalwinlost,
		CONVERT(BIT,0) as IsNeutral
	FROM bettrans AS a  WITH (NOLOCK)
		INNER JOIN outright AS m  WITH (NOLOCK) ON m.orid = a.matchid 
		INNER JOIN 	(
					SELECT 
						m.leagueid, sum(a.apositiontaking*stake) as totalbalance
					FROM bettrans AS a  WITH (NOLOCK)
						INNER JOIN outright AS m  WITH (NOLOCK) ON m.orid = a.matchid 
					WHERE a.recommend=@custid and
						 a.statusID IN (0,1) and
						a.bettype = 10
					GROUP BY m.leagueid
				) as leaguetotal ON leaguetotal.leagueid = m.leagueid
	WHERE  	
		a.recommend=@custid and
		a.statusID IN (0,1)  and
		a.bettype = 10	
	GROUP BY 
		m.teamid,
		m.orid,
		m.matchcode, 
		m.leagueid,
		leaguetotal.totalbalance,
		m.leagueid
	ORDER BY m.matchcode DESC

END


GO
GRANT EXECUTE ON [dbo].[Age_TotalBets_Sel10_Ag] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_TotalBets_Sel10_Ag] TO [bodbDownlineNetView]
GO
GRANT VIEW DEFINITION ON [dbo].[Age_TotalBets_Sel10_Ag] TO [vnteam]