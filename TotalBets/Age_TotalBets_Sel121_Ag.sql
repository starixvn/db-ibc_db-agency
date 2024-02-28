/*<info serverAlias="DBBOF-bodb02" executers="bodbDownlineNet,bodbDownlineNetView" isFunction="0"></info>*/	
ALTER PROCEDURE [dbo].[Age_TotalBets_Sel121_Ag]
	@custid int,
	@Language varchar(2) = 'E'
AS

/*
Created: 20120628@Sophia
Task : Retrieve Total bets for bettype 25: Draw No Bet, 121: Home No Bet, 122: Away No Bet
DB: DBBOF.bodb02

Revisions:
	- 20121003@Dan: update betteam for 121,122 bettype
	- 20180802@Helen: Update code for adjusting indexes - [Redmine:98757] 
	- 20201005@Danny: Change to use alias DBBOF alternative to DB042 [RedmineID: #139516]
	- 20240109@Lewis: Add LeagueGroupId [RedmineID: #197160]
	
Param's Explanation:
• @CustID: AgentID
*/
BEGIN
	SET NOCOUNT ON
	SELECT 
		m.showtime, 
		m.leagueid,
		l.LeagueGroupID,
		m.matchcode, 
		b.liveindicator, 
		b.livehomescore,
		b.liveawayscore,
		m.matchid,
		m.homeid,
		m.awayid,

		sum(Case when bettype=25 and betteam = 'h' then  (b.apositiontaking)*stake   else 0 end) AS home_odds_DNB,
		sum(Case when bettype=25 and betteam = 'a' then  (b.apositiontaking)*stake   else 0 end) AS away_odds_DNB,

		sum(Case when bettype=121 and betteam = 'x' then  (b.apositiontaking)*stake   else 0 end) AS home_odds_HNB,
		sum(Case when bettype=121 and betteam = 'a' then  (b.apositiontaking)*stake   else 0 end) AS away_odds_HNB,
		
		sum(Case when bettype=122 and betteam = 'h' then  (b.apositiontaking)*stake   else 0 end) AS home_odds_ANB,
		sum(Case when bettype=122 and betteam = 'x' then  (b.apositiontaking)*stake   else 0 end) AS away_odds_ANB,

		sum(case when bettype=25 then 1 else 0 end) as BetCount_DNB,
		sum(case when bettype=121 then 1 else 0 end) as BetCount_HNB,
		sum(case when bettype=122 then 1 else 0 end) as BetCount_ANB,
		
		isnull(m.isNeutral, CONVERT(BIT,0)) as IsNeutral
	FROM
		bettrans AS b  WITH (NOLOCK)
		INNER JOIN match AS m  WITH (NOLOCK) ON m.matchid = b.matchid and m.eventstatus='running'
		INNER JOIN League AS l WITH (NOLOCK) ON m.leagueid = l.leagueid
	WHERE  	
		b.recommend=@custid 
		AND m.eventstatus='running'
		AND b.bettype in (25,121,122)
		AND b.statusID in (0,1)
	group by b.liveindicator, 
		b.livehomescore,
		b.liveawayscore,
		m.homeid,
		m.awayid,
		m.matchid,
		m.matchcode, 
		m.leagueid,
		l.LeagueGroupID,
		m.showtime,
		m.isNeutral
	order by b.liveindicator desc, m.matchcode
END	
GO