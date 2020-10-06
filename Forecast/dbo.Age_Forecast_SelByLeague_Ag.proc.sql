/*<info serverAlias="DB042-bodb02" executers="bodbDownlineNet,bodbDownlineNetView" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Age_Forecast_SelByLeague_Ag]
	@BaseOffsetHDP int,
	@BaseOffsetOU int,
	@BaseOffsetHTHDP int,
	@BaseOffsetHTOU int,
	@LeagueID int,
	@recommend int,
	@Language varchar(2)
AS
/*
	Created:
	DB: DB042.bodb02
	WARNING: TAKE A DEEP BREATH BEFORE READING THIS SP
	
	Revisions:
		- 20100527@Henry: Change to use StatusID instead of Status in WHERE statement
		- 20150903@Winnie: Myanmar odds
		- 20180802@Helen: Update code for adjusting indexes - [Redmine:98757]
		- 20181226@Percy: Add table OddsES for E-Sports [RedmineID: #106994]
		- 20190415@Percy: Get livehomescore/liveawayscore data from match table instead of odds table [RedmineID: #113303]
		- 20190918@Percy: Remove inactive products [RedmineID: #118699]
		- 20200929@Malcolm : Offer Myanmar Odds for bettype in (1,3,7,8) [RedmineId : #141956]
	
	Supported bettypes: 1,3,7,8,301,302,303,304
	
	--WinlostStatus: 
	--	1: home win 1/2
	--	2: home win 1
	--	3: home lose 1/2
	--	2: home lose 1
	--	5: draw
*/
BEGIN
	SET NOCOUNT ON
	
	select R.MatchID,
		m.homeid,
		m.awayid,	
		R.liveindicator, isnull(M.LiveHomeScore, 0) as LiveHomeScore, isnull(M.LiveAwayScore, 0) as LiveAwayScore,M.ShowTime,M.MatchCode,

		sum(case when R.bettype = 1--= @BettypeHDP 
		and R.FOffset = -1 then case R.WinLostStatus when 1 then (R.AwayLose)/2 when 2 then R.AwayLose when 3 then (R.HomeLose)/2 when 4 then R.HomeLose else (MYO_Won + MYO_Lose) end else 0 end)  as WinLost_M1_HDP,
		sum(case when R.bettype = 1--= @BettypeHDP 
		and R.FOffset = 0 then case R.WinLostStatus when 1 then (R.AwayLose)/2  when 2 then R.AwayLose when 3 then (R.HomeLose)/2 when 4 then R.HomeLose else (MYO_Won + MYO_Lose) end else 0 end)  as WinLost_0_HDP,
		sum(case when R.bettype = 1--= @BettypeHDP 
		and R.FOffset = 1 then case R.WinLostStatus when 1 then (R.AwayLose)/2  when 2 then R.AwayLose when 3 then (R.HomeLose)/2 when 4 then R.HomeLose else (MYO_Won + MYO_Lose) end else 0 end)  as WinLost_1_HDP,

		sum(case when R.bettype = 3-- = @BettypeOU 
		and R.FOffset = 0 then case R.WinLostStatus when 1 then (R.AwayLose)/2  when 2 then R.AwayLose when 3 then (R.HomeLose)/2 when 4 then R.HomeLose else (MYO_Won + MYO_Lose) end end)  as WinLost_0_OU,
		sum(case when R.bettype = 3-- = @BettypeOU 
		and R.FOffset = 1 then case R.WinLostStatus when 1 then (R.AwayLose)/2  when 2 then R.AwayLose when 3 then (R.HomeLose)/2 when 4 then R.HomeLose else (MYO_Won + MYO_Lose) end end)  as WinLost_1_OU,
		sum(case when R.bettype = 3-- = @BettypeOU 
		and R.FOffset = 2 then case R.WinLostStatus when 1 then (R.AwayLose)/2  when 2 then R.AwayLose when 3 then (R.HomeLose)/2 when 4 then R.HomeLose else (MYO_Won + MYO_Lose) end end)  as WinLost_2_OU,

		sum(case when R.bettype = 7--= @BettypeHTHDP 
		and R.FOffset = -1 then case R.WinLostStatus when 1 then (R.AwayLose)/2  when 2 then R.AwayLose when 3 then (R.HomeLose)/2 when 4 then R.HomeLose else (MYO_Won + MYO_Lose) end else 0 end)  as WinLost_M1_HTHDP,
		sum(case when R.bettype = 7--= @BettypeHTHDP 
		and R.FOffset = 0 then case R.WinLostStatus when 1 then (R.AwayLose)/2  when 2 then R.AwayLose when 3 then (R.HomeLose)/2 when 4 then R.HomeLose else (MYO_Won + MYO_Lose) end else 0 end)  as WinLost_0_HTHDP,
		sum(case when R.bettype = 7--= @BettypeHTHDP 
		and R.FOffset = 1 then case R.WinLostStatus when 1 then (R.AwayLose)/2  when 2 then R.AwayLose when 3 then (R.HomeLose)/2 when 4 then R.HomeLose else (MYO_Won + MYO_Lose) end else 0 end)  as WinLost_1_HTHDP,

		sum(case when R.bettype = 8--= @BettypeHTOU 
		and R.FOffset = 0 then case R.WinLostStatus when 1 then (R.AwayLose)/2  when 2 then R.AwayLose when 3 then (R.HomeLose)/2 when 4 then R.HomeLose else (MYO_Won + MYO_Lose) end end)  as WinLost_0_HTOU, 	
		sum(case when R.bettype = 8--= @BettypeHTOU 
		and R.FOffset = 1 then case R.WinLostStatus when 1 then (R.AwayLose)/2  when 2 then R.AwayLose when 3 then (R.HomeLose)/2 when 4 then R.HomeLose else (MYO_Won + MYO_Lose) end end)  as WinLost_1_HTOU,
		sum(case when R.bettype = 8--= @BettypeHTOU 
		and R.FOffset = 2 then case R.WinLostStatus when 1 then (R.AwayLose)/2  when 2 then R.AwayLose when 3 then (R.HomeLose)/2 when 4 then R.HomeLose else (MYO_Won + MYO_Lose) end end)  as WinLost_2_HTOU,
		
		isnull(m.isNeutral, CONVERT(BIT,0)) as IsNeutral
	from 	
		(
			Select 
				1 as ForecastID, F.bettype, liveindicator, '' as status, F.offset, 
				homelose, awaylose, MYO_Won, MYO_Lose,
				BaseOffset + ForecastOffset.offset as BaseOffset, 
				case when F.BetType in (1,7) THEN--(@BetTypeHDP,@BetTypeHTHDP) then
					case 
						when F.VScoreHDP + BaseOffset + ForecastOffset.offset - F.Offset > 0 and F.VScoreHDP + BaseOffset + ForecastOffset.offset - F.Offset <0.5 then 1
						when F.VScoreHDP + BaseOffset + ForecastOffset.offset - F.Offset > 0.25 then 2
						when F.VScoreHDP + BaseOffset + ForecastOffset.offset - F.Offset < 0 and F.VScoreHDP + BaseOffset + ForecastOffset.offset - F.Offset >-0.5 then 3
						when F.VScoreHDP + BaseOffset + ForecastOffset.offset - F.Offset < -0.25 then 4
						when F.VScoreHDP + BaseOffset + ForecastOffset.offset - F.Offset =0 then 6
						else 5
					end
				when F.BetType in (3,8) THEN--(@BetTypeOU,@BetTypeHTOU) then
					case 
						when F.VScoreOU + BaseOffset + ForecastOffset.offset - F.Offset = 0.25 then 1
						when F.VScoreOU + BaseOffset + ForecastOffset.offset - F.Offset > 0.25 then 2
						when F.VScoreOU + BaseOffset + ForecastOffset.offset - F.Offset = -0.25 then 3
						when F.VScoreOU + BaseOffset + ForecastOffset.offset - F.Offset < -0.25 then 4
						when F.VScoreHDP + BaseOffset + ForecastOffset.offset - F.Offset =0 then 6
						else 5
					end
				end as WinlostStatus,
				F.MatchID, ForecastOffset.Offset as fOffset
			from (
					select  
						x.bettype AS bettype, x.liveindicator, 
						-x.hdp + score AS offset, 
						sum((x.homewin - x.awaylose) ) as AwayLose,
						sum((x.awaywin - x.homelose) ) as HomeLose,
						sum(MYO_Won) AS MYO_Won,
						sum(MYO_Lose) AS MYO_Lose,
						@BaseOffsetHDP AS BaseOffset,
						MatchID,
						VScoreHDP,
						VScoreOU
					from 
						(
							select 
								b.bettype,
								b.currency, b.hdp2 - b.hdp1 as hdp, b.livehomescore - b.liveawayscore AS score, b.liveindicator,
								sum(case when betteam='h' then (case when odds < 0 then 1 else odds end) * stake * (b.apositiontaking) else 0 end) AS homewin,
								sum(case when betteam='a' then (case when odds < 0 then 1 else odds end) * stake * (b.apositiontaking) else 0 end) AS awaywin,
								sum(case when betteam='h' then (case when odds < 0 then abs(odds) else 1 end)  * stake * (b.apositiontaking) else 0 end) AS homelose,
								sum(case when betteam='a' then (case when odds < 0 then abs(odds) else 1 end)  * stake * (b.apositiontaking) else 0 end) AS awaylose,
								sum(case when oddstype= 6 and oddsspread > 0 then oddsspread * stake * odds * b.apositiontaking/100 else 0 end) AS MYO_Won,
								sum(case when oddstype= 6 and oddsspread < 0  then oddsspread  * stake * b.apositiontaking/100  else 0 end) AS MYO_Lose,
								M.MatchID,
								isnull(m.livehomescore, 0) - isnull(m.liveawayscore, 0) as VScoreHDP,
								isnull(m.livehomescore, 0) + isnull(m.liveawayscore, 0) as VScoreOU
							from 
								bettrans AS b WITH (NOLOCK, INDEX = IX_betrunning_recommend)
								inner join Match as M with (NOLOCK) on b.MatchID = M.MatchID
								inner join League as L with (NOLOCK) on M.LeagueID = L.LeagueID and L.LeagueID = @LeagueID
							where 
								b.recommend = @recommend
								and b.bettype = 1--=@BetTypeHDP
								and b.statusID in (0,1) 
								
							group by 
								b.bettype,
								b.currency, b.hdp2 - b.hdp1, b.livehomescore - b.liveawayscore, b.liveindicator, M.MatchID, m.livehomescore, m.liveawayscore

							union all
							select 
								b.bettype,
								b.currency, b.hdp2 - b.hdp1 as hdp, b.livehomescore - b.liveawayscore AS score, b.liveindicator,
								sum(case when betteam='h' then (case when odds < 0 then 1 else odds end) * stake * (b.apositiontaking) else 0 end) AS homewin,
								sum(case when betteam='a' then (case when odds < 0 then 1 else odds end) * stake * (b.apositiontaking) else 0 end) AS awaywin,
								sum(case when betteam='h' then (case when odds < 0 then abs(odds) else 1 end)  * stake * (b.apositiontaking) else 0 end) AS homelose,
								sum(case when betteam='a' then (case when odds < 0 then abs(odds) else 1 end)  * stake * (b.apositiontaking) else 0 end) AS awaylose,
								sum(case when oddstype= 6 and oddsspread > 0 then oddsspread * stake * odds * b.apositiontaking/100 else 0 end) AS MYO_Won,
								sum(case when oddstype= 6 and oddsspread < 0  then oddsspread  * stake * b.apositiontaking/100  else 0 end) AS MYO_Lose,
								M.MatchID,
								isnull(o.livehomescore, 0) - isnull(o.liveawayscore, 0) as VScoreHDP,
								isnull(o.livehomescore, 0) + isnull(o.liveawayscore, 0) as VScoreOU
							from 
								bettrans AS b WITH (NOLOCK, INDEX = IX_betrunning_recommend)
								inner join Match as M with (NOLOCK) on b.MatchID = M.MatchID
								inner join OddsES as O with (NOLOCK) on b.OddsID = O.OddsID
								inner join League as L with (NOLOCK) on M.LeagueID = L.LeagueID and L.LeagueID = @LeagueID
							where 
								b.recommend = @recommend
								and b.bettype = 1
								and b.statusID in (0,1) 
							group by 
								b.bettype,
								b.currency, b.hdp2 - b.hdp1, b.livehomescore - b.liveawayscore, b.liveindicator, M.MatchID, o.livehomescore, o.liveawayscore
						) AS x 
					group by 
						-x.hdp + score, x.liveindicator, MatchID, VScoreHDP, VScoreOU,x.bettype
					
					UNION ALL
					select 
						x.bettype AS bettype, x.liveindicator, 
						x.hdp + score AS offset, 
						sum((x.homewin - x.awaylose)) as AwayLose,
						sum((x.awaywin - x.homelose)) as HomeLose,
						sum(MYO_Won) AS MYO_Won,
						sum(MYO_Lose) AS MYO_Lose,
						@BaseOffsetOU AS BaseOffset,
						MatchID,
						VScoreHDP,
						VScoreOU
					from 
							(
							select 
								b.liveindicator,  
								b.bettype,
								b.currency, b.hdp1 as hdp, 0 AS score,
								sum(case when betteam='h' then (case when odds < 0 then 1 else odds end) * stake * (b.apositiontaking) else 0 end) AS homewin,
								sum(case when betteam='a' then (case when odds < 0 then 1 else odds end) * stake * (b.apositiontaking) else 0 end) AS awaywin,
								sum(case when betteam='h' then (case when odds < 0 then abs(odds) else 1 end)  * stake * (b.apositiontaking) else 0 end) AS homelose,
								sum(case when betteam='a' then (case when odds < 0 then abs(odds) else 1 end)  * stake * (b.apositiontaking) else 0 end) AS awaylose,
								sum(case when oddstype= 6 and oddsspread > 0 then oddsspread * stake * odds * b.apositiontaking/100 else 0 end) AS MYO_Won,
								sum(case when oddstype= 6 and oddsspread < 0  then oddsspread  * stake * b.apositiontaking/100 else 0 end) AS MYO_Lose,
								M.MatchID,
								isnull(m.livehomescore, 0) - isnull(m.liveawayscore, 0) as VScoreHDP,
								isnull(m.livehomescore, 0) + isnull(m.liveawayscore, 0) as VScoreOU
							from 
								bettrans AS b with (nolock)  							
								inner join Match as M with (NOLOCK) on b.MatchID = M.MatchID and M.EventStatus = 'running'
								inner join League as L with (NOLOCK) on M.LeagueID = L.LeagueID and L.LeagueID = @LeagueID
							where 
								b.recommend = @recommend
								and b.bettype = 3--=@BetTypeOU
								and b.statusID in (0,1) 
							group by 
								b.bettype,
								b.currency, b.hdp1, b.liveindicator, M.MatchID, m.livehomescore, m.liveawayscore

							union all
							select 
								b.liveindicator,  
								b.bettype,
								b.currency, b.hdp1 as hdp, 0 AS score,
								sum(case when betteam='h' then (case when odds < 0 then 1 else odds end) * stake * (b.apositiontaking) else 0 end) AS homewin,
								sum(case when betteam='a' then (case when odds < 0 then 1 else odds end) * stake * (b.apositiontaking) else 0 end) AS awaywin,
								sum(case when betteam='h' then (case when odds < 0 then abs(odds) else 1 end)  * stake * (b.apositiontaking) else 0 end) AS homelose,
								sum(case when betteam='a' then (case when odds < 0 then abs(odds) else 1 end)  * stake * (b.apositiontaking) else 0 end) AS awaylose,
								sum(case when oddstype= 6 and oddsspread > 0 then oddsspread * stake * odds * b.apositiontaking/100 else 0 end) AS MYO_Won,
								sum(case when oddstype= 6 and oddsspread < 0  then oddsspread  * stake * b.apositiontaking/100 else 0 end) AS MYO_Lose,
								M.MatchID,
								isnull(o.livehomescore, 0) - isnull(o.liveawayscore, 0) as VScoreHDP,
								isnull(o.livehomescore, 0) + isnull(o.liveawayscore, 0) as VScoreOU
							from 
								bettrans AS b with (nolock)  							
								inner join Match as M with (NOLOCK) on b.MatchID = M.MatchID and M.EventStatus = 'running'
								inner join OddsES as O with (NOLOCK) on b.OddsID = O.OddsID
								inner join League as L with (NOLOCK) on M.LeagueID = L.LeagueID and L.LeagueID = @LeagueID
							where 
								b.recommend = @recommend
								and b.bettype = 3
								and b.statusID in (0,1) 
							group by 
								b.bettype,
								b.currency, b.hdp1, b.liveindicator, M.MatchID, o.livehomescore, o.liveawayscore
						) AS x 
					group by 
						liveindicator, x.score, x.hdp, MatchID, VScoreHDP, VScoreOU,x.bettype
	--FIRST HALF HERE----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
					UNION ALL
					select  
						x.bettype AS bettype, x.liveindicator, 
						-x.hdp + score AS offset, 
						sum((x.homewin - x.awaylose) ) as AwayLose,
						sum((x.awaywin - x.homelose) ) as HomeLose,
						sum(MYO_Won) AS MYO_Won,
						sum(MYO_Lose) AS MYO_Lose,
						@BaseOffsetHTHDP AS BaseOffset,
						MatchID,
						VScoreHDP,
						VScoreOU
					from 
						(
							select 
								b.bettype,
								b.currency, b.hdp2 - b.hdp1 hdp, b.livehomescore - b.liveawayscore AS score, b.liveindicator,
								sum(case when betteam='h' then (case when odds < 0 then 1 else odds end) * stake * (b.apositiontaking) else 0 end) AS homewin,
								sum(case when betteam='a' then (case when odds < 0 then 1 else odds end) * stake * (b.apositiontaking) else 0 end) AS awaywin,
								sum(case when betteam='h' then (case when odds < 0 then abs(odds) else 1 end)  * stake * (b.apositiontaking) else 0 end) AS homelose,
								sum(case when betteam='a' then (case when odds < 0 then abs(odds) else 1 end)  * stake * (b.apositiontaking) else 0 end) AS awaylose,
								sum(case when oddstype= 6 and oddsspread > 0 then oddsspread * stake * odds * b.apositiontaking/100 else 0 end) AS MYO_Won,
								sum(case when oddstype= 6 and oddsspread < 0  then oddsspread  * stake * b.apositiontaking/100 else 0 end) AS MYO_Lose,
								M.MatchID,
								isnull(m.livehomescore, 0) - isnull(m.liveawayscore, 0) as VScoreHDP,
								isnull(m.livehomescore, 0) + isnull(m.liveawayscore, 0) as VScoreOU
							from 
								bettrans AS b WITH (NOLOCK, INDEX = IX_betrunning_recommend) 
								inner join Match as M with (NOLOCK) on b.MatchID = M.MatchID
								inner join League as L with (NOLOCK) on M.LeagueID = L.LeagueID and L.LeagueID = @LeagueID
							where 
								b.recommend = @recommend
								and b.bettype = 7--=@BetTypeHTHDP
								and b.statusID in (0,1) 
							group by 
					--			status, 
								b.bettype,
								b.currency, b.hdp2 - b.hdp1, b.livehomescore - b.liveawayscore, b.liveindicator, M.MatchID, m.livehomescore, m.liveawayscore
							
							UNION ALL
							select 
								b.bettype,
								b.currency, b.hdp2 - b.hdp1 hdp, b.livehomescore - b.liveawayscore AS score, b.liveindicator,
								sum(case when betteam='h' then (case when odds < 0 then 1 else odds end) * stake * (b.apositiontaking) else 0 end) AS homewin,
								sum(case when betteam='a' then (case when odds < 0 then 1 else odds end) * stake * (b.apositiontaking) else 0 end) AS awaywin,
								sum(case when betteam='h' then (case when odds < 0 then abs(odds) else 1 end)  * stake * (b.apositiontaking) else 0 end) AS homelose,
								sum(case when betteam='a' then (case when odds < 0 then abs(odds) else 1 end)  * stake * (b.apositiontaking) else 0 end) AS awaylose,
								sum(case when oddstype= 6 and oddsspread > 0 then oddsspread * stake * odds * b.apositiontaking/100 else 0 end) AS MYO_Won,
								sum(case when oddstype= 6 and oddsspread < 0  then oddsspread  * stake * b.apositiontaking/100  else 0 end) AS MYO_Lose,
								M.MatchID,
								isnull(o.livehomescore, 0) - isnull(o.liveawayscore, 0) as VScoreHDP,
								isnull(o.livehomescore, 0) + isnull(o.liveawayscore, 0) as VScoreOU
							from 
								bettrans AS b WITH (NOLOCK, INDEX = IX_betrunning_recommend) 
								inner join Match as M with (NOLOCK) on b.MatchID = M.MatchID
								inner join OddsES as O with (NOLOCK) on b.OddsID = O.OddsID
								inner join League as L with (NOLOCK) on M.LeagueID = L.LeagueID and L.LeagueID = @LeagueID
							where 
								b.recommend = @recommend
								and b.bettype = 7
								and b.statusID in (0,1) 
							group by 
								b.bettype,
								b.currency, b.hdp2 - b.hdp1, b.livehomescore - b.liveawayscore, b.liveindicator, M.MatchID, o.livehomescore, o.liveawayscore
						) AS x 
					group by 
						-x.hdp + score, x.liveindicator, MatchID, VScoreHDP, VScoreOU,x.bettype
					
					UNION ALL
					select 
						x.bettype AS bettype, x.liveindicator, 
						x.hdp + score AS offset, 
						sum((x.homewin - x.awaylose)) as AwayLose,
						sum((x.awaywin - x.homelose)) as HomeLose,
						sum(MYO_Won) AS MYO_Won,
						sum(MYO_Lose) AS MYO_Lose,
						@BaseOffsetHTOU AS BaseOffset,
						MatchID,
						VScoreHDP,
						VScoreOU
					from 
							(
							select 
								b.liveindicator,  
								b.bettype,
								b.currency, b.hdp1 as hdp, 0 AS score,
								sum(case when betteam='h' then (case when odds < 0 then 1 else odds end) * stake * (b.apositiontaking) else 0 end) AS homewin,
								sum(case when betteam='a' then (case when odds < 0 then 1 else odds end) * stake * (b.apositiontaking) else 0 end) AS awaywin,
								sum(case when betteam='h' then (case when odds < 0 then abs(odds) else 1 end)  * stake * (b.apositiontaking) else 0 end) AS homelose,
								sum(case when betteam='a' then (case when odds < 0 then abs(odds) else 1 end)  * stake * (b.apositiontaking) else 0 end) AS awaylose,
								sum(case when oddstype= 6 and oddsspread > 0 then oddsspread * stake * odds * b.apositiontaking/100 else 0 end) AS MYO_Won,
								sum(case when oddstype= 6 and oddsspread < 0  then oddsspread  * stake * b.apositiontaking/100  else 0 end) AS MYO_Lose,
								M.MatchID,
								isnull(m.livehomescore, 0) - isnull(m.liveawayscore, 0) as VScoreHDP,
								isnull(m.livehomescore, 0) + isnull(m.liveawayscore, 0) as VScoreOU
							from 
								bettrans AS b WITH (NOLOCK, INDEX = IX_betrunning_recommend)  							
								inner join Match as M with (NOLOCK) on b.MatchID = M.MatchID and M.EventStatus = 'running'
								inner join League as L with (NOLOCK) on M.LeagueID = L.LeagueID and L.LeagueID = @LeagueID
							where 
								b.recommend = @recommend
								and b.bettype = 8--=@BetTypeHTOU
								and b.statusID in (0,1) 
							group by 
								b.bettype,
								b.currency, b.hdp1, b.liveindicator, M.MatchID, m.livehomescore, m.liveawayscore
							
							UNION ALL
							select 
								b.liveindicator,  
								b.bettype,
								b.currency, b.hdp1 as hdp, 0 AS score,
								sum(case when betteam='h' then (case when odds < 0 then 1 else odds end) * stake * (b.apositiontaking) else 0 end) AS homewin,
								sum(case when betteam='a' then (case when odds < 0 then 1 else odds end) * stake * (b.apositiontaking) else 0 end) AS awaywin,
								sum(case when betteam='h' then (case when odds < 0 then abs(odds) else 1 end)  * stake * (b.apositiontaking) else 0 end) AS homelose,
								sum(case when betteam='a' then (case when odds < 0 then abs(odds) else 1 end)  * stake * (b.apositiontaking) else 0 end) AS awaylose,
								sum(case when oddstype= 6 and oddsspread > 0 then oddsspread * stake * odds * b.apositiontaking/100 else 0 end) AS MYO_Won,
								sum(case when oddstype= 6 and oddsspread < 0  then oddsspread  * stake * b.apositiontaking/100 else 0 end) AS MYO_Lose,
								M.MatchID,
								isnull(o.livehomescore, 0) - isnull(o.liveawayscore, 0) as VScoreHDP,
								isnull(o.livehomescore, 0) + isnull(o.liveawayscore, 0) as VScoreOU
							from 
								bettrans AS b WITH (NOLOCK, INDEX = IX_betrunning_recommend)  							
								inner join Match as M with (NOLOCK) on b.MatchID = M.MatchID and M.EventStatus = 'running'
								inner join OddsES as O with (NOLOCK) on b.OddsID = O.OddsID
								inner join League as L with (NOLOCK) on M.LeagueID = L.LeagueID and L.LeagueID = @LeagueID
							where 
								b.recommend = @recommend
								and b.bettype = 8
								and b.statusID in (0,1) 
							group by 
								b.bettype,
								b.currency, b.hdp1, b.liveindicator, M.MatchID, o.livehomescore, o.liveawayscore
						) AS x 
					group by 
						liveindicator, x.score, x.hdp, MatchID, VScoreHDP, VScoreOU,x.bettype
			
				) as F 
				INNER JOIN 	(
							select 1 as bettype,-1 as offset union all
							select 1 as bettype,0 as offset union all
							select 1 as bettype,1 as offset union all
							select 3 as bettype,0 as offset union all
							select 3 as bettype,1 as offset union all
							select 3 as bettype,2 as offset union all
							select 7 as bettype,-1 as offset union all
							select 7 as bettype,0 as offset union all
							select 7 as bettype,1 as offset union all
							select 8 as bettype,0 as offset union all
							select 8 as bettype,1 as offset union all
							select 8 as bettype,2 as offset
						) as ForecastOffset on F.bettype = ForecastOffset.bettype	
		) as R 
		INNER JOIN Match as M with (NOLOCK) on R.MatchID = M.MatchID	
	group by R.MatchID,  R.liveindicator, 
		m.homeid,
		m.awayid,	
		M.LiveHomeScore, M.LiveAwayScore, 	
		M.ShowTime, M.MatchCode,
		m.isNeutral
	order by R.LiveIndicator desc, M.MatchCode
END	
GO