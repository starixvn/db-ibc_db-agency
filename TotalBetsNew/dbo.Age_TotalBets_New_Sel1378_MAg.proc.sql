ALTER PROCEDURE [dbo].[Age_TotalBets_New_Sel1378_MAg]
	@custid INT,
	@Language VARCHAR(2) = 'E'
AS

/*
Created: 20111109@Tom
Task : Retrieve Total Bet values for bettype 1,3,7,8
DB: DB052.bodb02
Original: Age_TotalBets_Sel1378_MAg

Revisions:


Param's Explanation:
• @custid: master ID
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
	SUM(CASE WHEN bettype=1 THEN hometotalM ELSE 0 END) AS home_odds_HDP,
	SUM(CASE WHEN bettype=1 THEN awaytotalM ELSE 0 END) AS away_odds_HDP,
	SUM(CASE WHEN bettype=7 THEN hometotalM ELSE 0 END) AS home_odds_HTHDP,
	SUM(CASE WHEN bettype=7 THEN awaytotalM ELSE 0 END) AS away_odds_HTHDP,
	SUM(CASE WHEN bettype=3 THEN hometotalM ELSE 0 END) AS home_odds_OU,
	SUM(CASE WHEN bettype=3 THEN awaytotalM ELSE 0 END) AS away_odds_OU,
	SUM(CASE WHEN bettype=8 THEN hometotalM ELSE 0 END) AS home_odds_HTOU,
	SUM(CASE WHEN bettype=8 THEN awaytotalM ELSE 0 END) AS away_odds_HTOU,
	SUM(CASE WHEN bettype=1 THEN BetCount ELSE 0 END) AS BetCount_HDP,
	SUM(CASE WHEN bettype=7 THEN BetCount ELSE 0 END) AS BetCount_HTHDP,
	SUM(CASE WHEN bettype=3 THEN BetCount ELSE 0 END) AS BetCount_OU,
	SUM(CASE WHEN bettype=8 THEN BetCount ELSE 0 END) AS BetCount_HTOU,
	ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral
FROM
	(SELECT
		matchid,
		bettype,
		liveindicator,
		livehomescore,
		liveawayscore,
		hometotalM,
		awaytotalM,
		BetCount
	FROM  dbo.bettrans_forecast_agent WITH (NOLOCK)
	WHERE
			bettype IN (1,3,7,8)
			AND mrecommend = @custid
			) AS b
	INNER JOIN dbo.match m WITH (NOLOCK) ON m.matchid = b.matchid
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
	b.liveindicator DESC, m.matchcode



GO
GRANT EXECUTE ON [dbo].[Age_TotalBets_New_Sel1378_MAg] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_TotalBets_New_Sel1378_MAg] TO [bodbDownlineNetView]
GO
GRANT VIEW definition ON [dbo].[Age_TotalBets_New_Sel1378_MAg] TO [vnteam]

