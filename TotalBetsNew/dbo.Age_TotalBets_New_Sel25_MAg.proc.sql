ALTER PROCEDURE [dbo].[Age_TotalBets_New_Sel25_MAg]
	@custid INT,
	@Language VARCHAR(2) = 'E'
AS

/*
Created: 20111109@Tom
Task : Retrieve Total Bet values for bettype (2, 12, 5, 15)
DB: DB052.bodb02
Original: Age_TotalBets_Sel25_MAg

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
	b.livehomescore,
	b.liveawayscore,
	m.matchid,
	m.homeID,
	m.awayID,
	SUM(CASE WHEN bettype=2 THEN hometotalM ELSE 0 END) AS home_odds_OE,
	SUM(CASE WHEN bettype=2 THEN awaytotalM ELSE 0 END) AS away_odds_OE,
	SUM(CASE WHEN bettype=12 THEN hometotalM ELSE 0 END) AS home_odds_OE_1st,
	SUM(CASE WHEN bettype=12 THEN awaytotalM ELSE 0 END) AS away_odds_OE_1st,	
	SUM(CASE WHEN bettype=5 THEN hometotalM ELSE 0 END) AS odds_1,
	SUM(CASE WHEN bettype=5 THEN drawtotalM ELSE 0 END) AS odds_x,
	SUM(CASE WHEN bettype=5 THEN awaytotalM ELSE 0 END) AS odds_2,	
	SUM(CASE WHEN bettype=15 THEN hometotalM ELSE 0 END) AS odds_1_1st,
	SUM(CASE WHEN bettype=15 THEN drawtotalM ELSE 0 END) AS odds_x_1st,
	SUM(CASE WHEN bettype=15 THEN awaytotalM ELSE 0 END) AS odds_2_1st,
	sum(case when bettype=2 then BetCount else 0 end) as BetCount_OE,
	sum(case when bettype=12 then BetCount else 0 end) as BetCount_OE_1st,
	sum(case when bettype=5 then BetCount else 0 end) as BetCount_1x2,
	sum(case when bettype=15 then BetCount else 0 end) as BetCount_1x2_1st,
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
		drawtotalM,		
		BetCount
	FROM  dbo.bettrans_forecast_agent WITH (NOLOCK)
	WHERE
			bettype IN (2, 12, 5, 15)
			AND mrecommend = @custid
			) AS b
	INNER JOIN dbo.match m WITH (NOLOCK) ON m.matchid = b.matchid
WHERE
	m.eventstatus = 'running'
	
GROUP BY
	m.leagueID,
	m.matchcode,
	b.liveindicator,
	b.livehomescore,
	b.liveawayscore,
	m.homeID,
	m.awayID,
	m.matchid,
	m.showtime, 
	m.isNeutral
ORDER BY	
	b.liveindicator DESC, m.matchcode



GO
GRANT EXECUTE ON [dbo].[Age_TotalBets_New_Sel25_MAg] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_TotalBets_New_Sel25_MAg] TO [bodbDownlineNetView]
GO
GRANT VIEW definition ON [dbo].[Age_TotalBets_New_Sel25_MAg] TO [vnteam]

