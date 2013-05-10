ALTER PROCEDURE [dbo].[Age_TotalBets_New_Sel2021_SAg]
	@custid INT,
	@Language VARCHAR(2) = 'E'
AS

/*
Created: 20111109@Tom
Task : Retrieve Total Bet values for bettype 20,21
DB: DB052.bodb02
Original: Age_TotalBets_Sel2021_SAg

Revisions:


Param's Explanation:
• @custid: super ID
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
	SUM(CASE WHEN bettype=20 THEN hometotalS ELSE 0 END) AS home_odds,
	SUM(CASE WHEN bettype=20 THEN awaytotalS ELSE 0 END) AS away_odds,
	SUM(CASE WHEN bettype=20 THEN homewinS ELSE 0 END) AS WinLost_home,
	SUM(CASE WHEN bettype=20 THEN awaywinS ELSE 0 END) AS WinLost_away,
	SUM(CASE WHEN bettype=21 THEN hometotalS ELSE 0 END) AS home_odds_HT,
	SUM(CASE WHEN bettype=21 THEN awaytotalS ELSE 0 END) AS away_odds_HT,
	SUM(CASE WHEN bettype=21 THEN homewinS ELSE 0 END) AS WinLost_home_HT,
	SUM(CASE WHEN bettype=21 THEN awaywinS ELSE 0 END) AS WinLost_away_HT,
	ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral
FROM
	(SELECT
		matchid,
		bettype,
		liveindicator,
		livehomescore,
		liveawayscore,
		hometotalS,
		awaytotalS,
		homewinS,
		awaywinS,		
		BetCount
	FROM  dbo.bettrans_forecast_agent WITH (NOLOCK)
	WHERE
			bettype IN (20,21)
			AND srecommend = @custid
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
GRANT EXECUTE ON [dbo].[Age_TotalBets_New_Sel2021_SAg] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_TotalBets_New_Sel2021_SAg] TO [bodbDownlineNetView]
GO
GRANT VIEW definition ON [dbo].[Age_TotalBets_New_Sel2021_SAg] TO [vnteam]

