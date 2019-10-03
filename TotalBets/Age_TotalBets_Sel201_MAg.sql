/*<info serverAlias="DB042-bodb02" executers="bodbDownlineNet,bodbDownlineNetView" isFunction="0"></info>*/	
ALTER PROCEDURE [dbo].[Age_TotalBets_Sel201_MAg]
    @CustID     int,
    @Language   varchar(2) = 'E'
AS
/*
Created: 20090306@AnhPham
Task : Total bets for financial bettype of agent downline
DB: DB042.bodb02

Param's Explanation:
• @CustID: agentID

Revisions:
	
*/

SELECT
    m.leagueid,
	m.matchid,
	m.homeid,
	--m.matchcode as matchcode,
	b.bettype,	
	sum(case when betteam = 'h' and b.ruben = 0 then (b.mpositiontaking)* stake else 0 end) AS home_total,
	sum(case when betteam = 'a' and b.ruben = 0 then (b.mpositiontaking)* stake else 0 end) AS away_total,
	
	sum(case when b.ruben = 1 then b.mwinlost else 0 end) winlost
FROM
	bettrans b WITH(NOLOCK)
	INNER JOIN match m WITH (NOLOCK) ON m.matchid = b.matchid 
WHERE 
	b.mrecommend = @CustID AND
	m.eventstatus = 'running' AND
	((b.bettype between 51 and 56) OR (b.bettype between 61 and 66))AND
	b.liveindicator=1
GROUP BY
    m.leagueid,
	m.matchid,	
	m.homeid,
	--m.matchcode,
	b.bettype
ORDER BY
    m.leagueid,
	m.matchid,	
	m.homeid,
	--m.matchcode,
	b.bettype
GO