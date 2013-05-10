ALTER PROCEDURE [dbo].[Age_TotalBets_Sel1378_MAg]
	@custid INT,
	@Language varchar(2) = 'E'
AS

/*
Created: 20090122@Thien
Task : Retrieve Total Bet values for bettype 1,3,7,8
DB: DB05.bodb02
Original: eagenttotalbet13

Revisions:
    -- 20100527@Henry: Change to use StatusID instead of Status in WHERE statement

Param's Explanation:
• @custid: Master Agent ID
*/
SET NOCOUNT ON

SELECT
	m.showtime, 
	m.leagueID,
	m.matchcode,
	b.liveindicator,
	m.matchid,
	m.homeID,
	m.awayID,
	b.livehomescore,
	b.liveawayscore,
	sum(Case when bettype=1 and betteam = 'h' then Stake else 0 End) AS home_odds_HDP,
	sum(Case when bettype=1 and betteam = 'a' then Stake else 0 End) AS away_odds_HDP,
	sum(Case when bettype=7 and betteam = 'h' then Stake else 0 End) AS home_odds_HTHDP,
	sum(Case when bettype=7 and betteam = 'a' then Stake else 0 End) AS away_odds_HTHDP,
	sum(Case when bettype=3 and betteam = 'h' then Stake else 0 End) AS home_odds_OU,
	sum(Case when bettype=3 and betteam = 'a' then Stake else 0 End) AS away_odds_OU,
	sum(Case when bettype=8 and betteam = 'h' then Stake else 0 End) AS home_odds_HTOU,
	sum(Case when bettype=8 and betteam = 'a' then Stake else 0 End) AS away_odds_HTOU,
	sum(case when bettype=1 then BetCount else 0 end) as BetCount_HDP,
	sum(case when bettype=7 then BetCount else 0 end) as BetCount_HTHDP,
	sum(case when bettype=3 then BetCount else 0 end) as BetCount_OU,
	sum(case when bettype=8 then BetCount else 0 end) as BetCount_HTOU,
	isnull(m.isNeutral, CONVERT(BIT,0)) as IsNeutral
FROM
	(SELECT
		matchid, bettype, betteam,
		liveindicator, livehomescore, liveawayscore,
		SUM(mpositiontaking * stake * case when abs(odds) <1 then 1 else abs(odds) end) Stake, COUNT(*) BetCount
	FROM bettrans WITH (NOLOCK)
	WHERE
			bettype IN (1,3,7,8)
			AND mrecommend = @custid
			--AND status in ('running', 'waiting')
			AND statusID in (0,1)
			AND ruben = 0
	GROUP BY matchid, bettype, betteam, liveindicator, livehomescore, liveawayscore) as b
	INNER JOIN match 	m  WITH (NOLOCK) ON m.matchid       = b.matchid 	
WHERE	
	m.eventstatus = 'running'	
	
GROUP BY
	m.showtime, 
	m.leagueID,
	m.matchcode,
	b.liveindicator,
	m.matchid,
	m.homeID,
	m.awayID,
	b.livehomescore,
	b.liveawayscore,
	m.isNeutral
ORDER BY	
	b.liveindicator desc, m.matchcode


GO
GRANT EXECUTE ON [dbo].[Age_TotalBets_Sel1378_MAg] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_TotalBets_Sel1378_MAg] TO [bodbDownlineNetView]
GO
GRANT VIEW DEFINITION ON [dbo].[Age_TotalBets_Sel1378_MAg] TO [vnteam]
