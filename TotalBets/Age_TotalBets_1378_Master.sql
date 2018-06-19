/*<info serverAlias="DBAGE-bodb02" executers="bodbDownlineNet,bodbDownlineNetView" viewers="" isFunction="0" isNested="0"></info>*/
USE [bodb02]
GO

ALTER PROCEDURE [dbo].[Age_TotalBets_1378_Master]
	@CustId		INT,
	@Language	VARCHAR(2) = 'E' -- not use, will remove later
AS

/*
	Created: 20180617@Percy
	DB: DBAGE.bodb02
	Task: Alpha - Total Bets - Super view
	Original: Age_TotalBets_Sel1378_SAg

	Revisions:
		- 20180617@Percy: Initilize SP [RedmineID: #97037]
*/

BEGIN
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
		sum(Case when bettype IN (1,301) and betteam = 'h' then Stake else 0 End) AS home_odds_HDP,
		sum(Case when bettype IN (1,301) and betteam = 'a' then Stake else 0 End) AS away_odds_HDP,
		sum(Case when bettype IN (7,303) and betteam = 'h' then Stake else 0 End) AS home_odds_HTHDP,
		sum(Case when bettype IN (7,303) and betteam = 'a' then Stake else 0 End) AS away_odds_HTHDP,
		sum(Case when bettype IN (3,302) and betteam = 'h' then Stake else 0 End) AS home_odds_OU,
		sum(Case when bettype IN (3,302) and betteam = 'a' then Stake else 0 End) AS away_odds_OU,
		sum(Case when bettype IN (8,304) and betteam = 'h' then Stake else 0 End) AS home_odds_HTOU,
		sum(Case when bettype IN (8,304) and betteam = 'a' then Stake else 0 End) AS away_odds_HTOU,
		sum(case when bettype IN (1,301) then BetCount else 0 end) as BetCount_HDP,
		sum(case when bettype IN (7,303) then BetCount else 0 end) as BetCount_HTHDP,
		sum(case when bettype IN (3,302) then BetCount else 0 end) as BetCount_OU,
		sum(case when bettype IN (8,304) then BetCount else 0 end) as BetCount_HTOU,
		isnull(m.isNeutral, CONVERT(BIT,0)) as IsNeutral
	FROM
		(	SELECT
				matchid, bettype, betteam,
				liveindicator, livehomescore, liveawayscore,
				SUM(spositiontaking * stake * case when abs(odds) <1 then 1 else abs(odds) end) Stake, COUNT(*) BetCount
			FROM	dbo.bettrans WITH(NOLOCK, INDEX = IX_betrunning_srecommend)
			WHERE
					bettype IN (1,3,7,8,301,302,303,304)
					AND srecommend = @custid
					AND statusID IN (0,1)
			GROUP BY matchid, bettype, betteam, liveindicator, livehomescore, liveawayscore) as b
		INNER JOIN bodb02.dbo.match m  WITH (NOLOCK) ON m.matchid = b.matchid 	
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
		b.liveindicator desc,m.matchcode
END
GO