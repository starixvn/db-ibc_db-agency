/*<info serverAlias="DBBOF-bodb02" executers="bodbDownlineNet,bodbDownlineNetView" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Age_TotalBets_1378_Master]
	@CustId INT
AS

/*
	Created: 20180617@Percy
	DB: DBBOF.bodb02
	Task: Alpha - Total Bets - Super view

	Revisions:
		- 20180617@Percy: Initilize SP [RedmineID: #97037]
		- 20190918@Percy: Remove inactive products [RedmineID: #118699]
		- 20201005@Danny: Change to use alias DBBOF alternative to DB042 [RedmineID: #139516]
		- 20221227@Bobby: Correct formula for calculating Total Bet [RedmineID: #181608]
		- 20240109@Lewis: Add LeagueGroupId [RedmineID: #197160]
*/

BEGIN
	SET NOCOUNT ON

	SELECT
		m.showtime,
		m.leagueID,
		l.LeagueGroupID,
		m.matchcode,
		b.liveindicator,
		m.matchid,
		m.homeID,
		m.awayID,
		b.livehomescore,
		b.liveawayscore,
		sum(Case when bettype = 1 and betteam = 'h' then Stake else 0 End) AS home_odds_HDP,
		sum(Case when bettype = 1 and betteam = 'a' then Stake else 0 End) AS away_odds_HDP,
		sum(Case when bettype = 7 and betteam = 'h' then Stake else 0 End) AS home_odds_HTHDP,
		sum(Case when bettype = 7 and betteam = 'a' then Stake else 0 End) AS away_odds_HTHDP,
		sum(Case when bettype = 3 and betteam = 'h' then Stake else 0 End) AS home_odds_OU,
		sum(Case when bettype = 3 and betteam = 'a' then Stake else 0 End) AS away_odds_OU,
		sum(Case when bettype = 8 and betteam = 'h' then Stake else 0 End) AS home_odds_HTOU,
		sum(Case when bettype = 8 and betteam = 'a' then Stake else 0 End) AS away_odds_HTOU,
		sum(case when bettype = 1 then BetCount else 0 end) as BetCount_HDP,
		sum(case when bettype = 7 then BetCount else 0 end) as BetCount_HTHDP,
		sum(case when bettype = 3 then BetCount else 0 end) as BetCount_OU,
		sum(case when bettype = 8 then BetCount else 0 end) as BetCount_HTOU,
		isnull(m.isNeutral, CONVERT(BIT,0)) as IsNeutral
	FROM
		(	SELECT
				matchid, bettype, betteam,
				liveindicator, livehomescore, liveawayscore,
				SUM(spositiontaking * actual_stake) Stake, COUNT(*) BetCount
			FROM	dbo.bettrans WITH(NOLOCK, INDEX = IX_betrunning_srecommend)
			WHERE
					bettype IN (1,3,7,8)
					AND srecommend = @custid
					AND statusID IN (0,1)
			GROUP BY matchid, bettype, betteam, liveindicator, livehomescore, liveawayscore) as b
		INNER JOIN bodb02.dbo.match m  WITH (NOLOCK) ON m.matchid = b.matchid
		INNER JOIN League l WITH (NOLOCK) ON m.leagueid = l.leagueid
	WHERE
		m.eventstatus = 'running'
	
	GROUP BY
		m.showtime,
		m.leagueID,
		l.LeagueGroupID,
		m.matchcode,
		b.liveindicator,
		m.matchid,
		m.homeID,
		m.awayID,
		b.livehomescore,
		b.liveawayscore,
		m.isNeutral
	ORDER BY
		b.liveindicator desc,m.matchcode
END
GO