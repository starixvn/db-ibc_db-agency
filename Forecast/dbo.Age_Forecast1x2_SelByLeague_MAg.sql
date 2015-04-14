ALTER PROCEDURE Age_Forecast1x2_SelByLeague_MAg
	@leagueid int,
	@custid int
AS
/*
Task: Forecast for 1x2 bettype according to league
DB: DB05.bodb02
Revisions: 
	- 20090213@Kiwi: Remove inner join customer table because we retrieve data directly from bettrans table.)
	-- 20100527@Henry: Change to use StatusID instead of Status in WHERE statement
	- 20110520@Johnson: change the type of variables @Bettype1x2, @BettypeHT1x2 to int
	- 20150408@Cody: Apply bet radar bettype (167) [Remine: #32734]
*/

SET NOCOUNT ON
Declare @BetType1x2			INT
		,@BetTypeHT1x2		INT
		,@BetTypeHT1x2_167	INT
		
select @BetType1x2 = 5
		,@BetTypeHT1x2 = 15
		,@BetTypeHT1x2_167 = 167

	select x.MatchID, x.homeid,	x.awayid,	
		x.liveindicator, isnull(x.LiveHomeScore, 0) as livehomescore, isnull(x.LiveAwayScore, 0) as liveawayscore,x.ShowTime,x.MatchCode,isNeutral,
		(x.awaywin - x.homelose - x.drawlose) 'al',
		(x.homewin - x.awaylose - x.drawlose) 'hl',
		(x.drawwin - x.awaylose - x.homelose) 'dl',
	
		(x.ht_awaywin - x.ht_drawlose - x.ht_homelose) 'ht_al',
		(x.ht_homewin - x.ht_drawlose - x.ht_awaylose) 'ht_hl',
		(x.ht_drawwin - x.ht_awaylose - x.ht_homelose) 'ht_dl'
	from 
		(select m.MatchID, m.homeid,	m.awayid,	
			b.liveindicator, isnull(b.LiveHomeScore, 0) as livehomescore, isnull(b.LiveAwayScore, 0) as liveawayscore,M.ShowTime,M.MatchCode,
			isnull(m.isNeutral, CONVERT(BIT,0)) as IsNeutral,
			sum(case when betteam='1' and bettype = @BetType1x2 then (case when odds < 0 then 1 else odds - 1 end) * stake * (b.mpositiontaking) else 0 end) homewin,
			sum(case when betteam='2' and bettype = @BetType1x2 then (case when odds < 0 then 1 else odds - 1 end) * stake * (b.mpositiontaking) else 0 end) awaywin,			
			sum(case when betteam='x' and bettype = @BetType1x2 then (case when odds < 0 then 1 else odds - 1 end) * stake * (b.mpositiontaking) else 0 end) drawwin,
			
			sum(case when betteam='1' and bettype = @BetType1x2 then (case when odds < 0 then abs(odds - 1) else 1 end)  * stake * (b.mpositiontaking) else 0 end) homelose,
			sum(case when betteam='2' and bettype = @BetType1x2 then (case when odds < 0 then abs(odds - 1) else 1 end)  * stake * (b.mpositiontaking) else 0 end) awaylose,			
			sum(case when betteam='x' and bettype = @BetType1x2 then (case when odds < 0 then abs(odds - 1) else 1 end)  * stake * (b.mpositiontaking) else 0 end) drawlose,

			sum(case when betteam='1' and (bettype = @BetTypeHT1x2 OR bettype = @BetTypeHT1x2_167) then (case when odds < 0 then 1 else odds - 1 end) * stake * (b.mpositiontaking) else 0 end) ht_homewin,
			sum(case when betteam='2' and (bettype = @BetTypeHT1x2 OR bettype = @BetTypeHT1x2_167) then (case when odds < 0 then 1 else odds - 1 end) * stake * (b.mpositiontaking) else 0 end) ht_awaywin,			
			sum(case when betteam='x' and (bettype = @BetTypeHT1x2 OR bettype = @BetTypeHT1x2_167) then (case when odds < 0 then 1 else odds - 1 end) * stake * (b.mpositiontaking) else 0 end) ht_drawwin,
			
			sum(case when betteam='1' and (bettype = @BetTypeHT1x2 OR bettype = @BetTypeHT1x2_167) then (case when odds < 0 then abs(odds - 1) else 1 end)  * stake * (b.mpositiontaking) else 0 end) ht_homelose,
			sum(case when betteam='2' and (bettype = @BetTypeHT1x2 OR bettype = @BetTypeHT1x2_167) then (case when odds < 0 then abs(odds - 1) else 1 end)  * stake * (b.mpositiontaking) else 0 end) ht_awaylose,			
			sum(case when betteam='x' and (bettype = @BetTypeHT1x2 OR bettype = @BetTypeHT1x2_167) then (case when odds < 0 then abs(odds - 1) else 1 end)  * stake * (b.mpositiontaking) else 0 end) ht_drawlose
		from bettrans b with(nolock)
			inner join Match M with (NOLOCK) on b.MatchID = M.MatchID and M.EventStatus = 'running'
		where b.bettype in (@Bettype1x2, @BettypeHT1x2, @BetTypeHT1x2_167)
			AND LeagueID = @LeagueID
			AND b.mrecommend = @custid
			--AND b.status in ('running','waiting')
			and b.statusID in (0,1)
			AND b.ruben = 0
		group by liveindicator, b.currency ,m.MatchID, m.homeid, m.awayid,	
			b.liveindicator, b.LiveHomeScore,b.LiveAwayScore,M.ShowTime,M.MatchCode,isNeutral
		)x 
GO
GRANT EXEC ON Age_Forecast1x2_SelByLeague_MAg TO [bodbDownlineNet]
GO
GRANT EXEC ON Age_Forecast1x2_SelByLeague_MAg TO [bodbDownlineNetView]
GO



