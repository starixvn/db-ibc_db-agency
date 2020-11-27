/*<info serverAlias="DBBOF-bodb02" executers="bodbDownlineNet,bodbDownlineNetView" isFunction="0"></info>*/	
ALTER PROCEDURE [dbo].[Age_TotalBets_Sel25_MAg]
	@custid int,
	@Language varchar(2) = 'E'
AS

/*
Task : Retrieve Total bets for bettype 25
DB: DBBOF.bodb02
Revisions:
	- 20060302: remove refno
	- 20100527@Henry: Change to use StatusID instead of Status in WHERE statement
	- 20120626@Sophia: Add new bettype 123 for Draw/No Draw
	- 20150408@Cody: Apply bet radar bettype (157, 167) [Remine: #32734]
	- 20180802@Helen: Update code for adjusting indexes - [Redmine:98757]
	- 20201005@Danny: Change to use alias DBBOF alternative to DB042 [RedmineID: #139516]
	
Param's Explanation:
• @CustID: Master Agent ID
*/
BEGIN
	SET NOCOUNT ON
	select 
		m.showtime, 
		m.leagueid,
		m.matchcode,
		a.liveindicator, 
		a.livehomescore,
		a.liveawayscore,
		m.matchid,
		m.homeid,
		m.awayid,
		
		sum((Case when (bettype = 2 OR bettype = 157) and betteam = 'h' then (a.mpositiontaking)*stake else 0 end)*(case when abs(odds) <1 then 1 else abs(odds) end)) AS home_odds_OE,
		sum((Case when (bettype = 2 OR bettype = 157) and betteam = 'a' then (a.mpositiontaking)*stake else 0 end)*(case when abs(odds) <1 then 1 else abs(odds) end)) AS away_odds_OE,
		
		sum((Case when bettype=12 and betteam = 'h' then (a.mpositiontaking)*stake else 0 end)*(case when abs(odds) <1 then 1 else abs(odds) end)) AS home_odds_OE_1st,
		sum((Case when bettype=12 and betteam = 'a' then (a.mpositiontaking)*stake else 0 end)*(case when abs(odds) <1 then 1 else abs(odds) end)) AS away_odds_OE_1st,
		
		--league.lcolor,
		sum(Case when bettype=5 and betteam = '1' then  (a.mpositiontaking)*stake   else 0 end) AS odds_1,
		sum(Case when bettype=5 and betteam = 'x' then  (a.mpositiontaking)*stake   else 0 end) AS odds_x,
		sum(Case when bettype=5 and betteam = '2' then  (a.mpositiontaking)*stake   else 0 end) AS odds_2,

		sum(Case when (bettype = 15 OR bettype = 167) and betteam = '1' then  (a.mpositiontaking)*stake   else 0 end) AS odds_1_1st,
		sum(Case when (bettype = 15 OR bettype = 167) and betteam = 'x' then  (a.mpositiontaking)*stake   else 0 end) AS odds_x_1st,
		sum(Case when (bettype = 15 OR bettype = 167) and betteam = '2' then  (a.mpositiontaking)*stake   else 0 end) AS odds_2_1st,
		
		sum(Case when bettype=123 and betteam = 'h' then  (a.mpositiontaking)*stake   else 0 end) AS home_odds_DND,
		sum(Case when bettype=123 and betteam = 'a' then  (a.mpositiontaking)*stake   else 0 end) AS away_odds_DND,

		sum(case when (bettype = 2 OR bettype = 157) then 1 else 0 end) as BetCount_OE,
		sum(case when bettype=12 then 1 else 0 end) as BetCount_OE_1st,
		sum(case when bettype=5 then 1 else 0 end) as BetCount_1x2,
		sum(case when (bettype = 15 OR bettype = 167) then 1 else 0 end) as BetCount_1x2_1st,
		sum(case when bettype=123 then 1 else 0 end) as BetCount_DND,
		
		isnull(m.isNeutral, CONVERT(BIT,0)) as IsNeutral
	FROM
		bettrans AS a  WITH (NOLOCK)
		INNER JOIN match AS m  WITH (NOLOCK) ON m.matchid       = a.matchid and 	m.eventstatus='running'
	where  	
		a.mrecommend=@custid and
		m.eventstatus='running'  and
		a.bettype in (2, 12, 5, 15, 123, 157, 167)
		AND a.statusID in (0,1)
		
	group by a.liveindicator, 
		a.livehomescore,
		a.liveawayscore,
		m.homeid,
		m.awayid,
		m.matchid,
		m.matchcode, 
		m.leagueid, 
		m.showtime,
		m.isNeutral
	order by a.liveindicator desc, m.matchcode
END
GO