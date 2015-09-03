USE [bodb_AGE]
GO
/****** Object:  StoredProcedure [dbo].[Age_TotalBets_Sel1378_SAg]    Script Date: 08/27/2015 02:17:28 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE  [dbo].[Age_TotalBets_Sel1378_SAg]
	@custid INT,
	@Language varchar(2) = 'E'
AS
/*
Original: SP eagenttotalbet13
Task: Retrieve Total Bet values for 1,3,7,8 bet types.
DB: DBAGE/bodb_AGE
Revisions:
	- 20090216@Kiwi: Remove status in ('running', 'waiting') to avoid Key Lookup while using Index named _MS_Sys_38_52_42.
	- 20130925@Jamie: Change to bodb_Age / bettrans_running 
	- 20140618@Viet: put index hint
	- 20150825@Winnie: MyanmarOdds
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
	sum(Case when bettype IN (1,301) and betteam = 'h' then Stake else 0 End) AS home_odds_HDP,
	sum(Case when bettype IN (1,301)and betteam = 'a' then Stake else 0 End) AS away_odds_HDP,
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
		FROM	dbo.bettrans_running WITH(NOLOCK, INDEX=IX_srecommend)
		WHERE
				bettype IN (1,3,7,8,301,302,303,304)
				AND srecommend = @custid
				--AND ruben = 0
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




GO
GRANT VIEW DEFINITION ON [dbo].[Age_TotalBets_Sel1378_SAg] TO [vnteam] AS [dbo]