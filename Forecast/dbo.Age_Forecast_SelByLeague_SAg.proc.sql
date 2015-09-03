USE [bodb02]
GO
/****** Object:  StoredProcedure [dbo].[Age_Forecast_SelByLeague_SAg_xtest]    Script Date: 9/3/2015 1:00:39 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[Age_Forecast_SelByLeague_SAg]
	@BaseOffsetHDP int,
	@BaseOffsetOU int,
	@BaseOffsetHTHDP int,
	@BaseOffsetHTOU int,
	@LeagueID int,
	@srecommend int,
	@Language varchar(2)
AS
--DB: DB05.bodb02
--WARNING: TAKE A DEEP BREATH BEFORE READING THIS SP
--Original: ForecastSAgByLeague2
-- 20100527@Henry: Change to use StatusID instead of Status in WHERE statement
-- 20150903@Winnie: Myanmar odds
SET NOCOUNT ON
--Declare @BetTypeHDP int, @BetTypeOU int, 
--@VScoreHDP smallmoney, @VScoreOU smallmoney, 
--@BetTypeHTHDP int, @BetTypeHTOU int
--Select @BetTypeHDP = 1, @BetTypeOU = 3,@BetTypeHTHDP = 7, @BetTypeHTOU = 8


--Declare @Result TABLE (ForecastID int, bettype int, liveindicator bit, status varchar(10), offset smallmoney, hometotal money, awaytotal money, homelose money, awaylose money, betcount int, BaseOffset smallmoney, WinLostStatus int, MatchID int, FOffset smallmoney)
--WinlostStatus: 
--	1: home win 1/2
--	2: home win 1
--	3: home lose 1/2
--	2: home lose 1
--	5: draw
select R.MatchID,
	m.homeid,
	m.awayid,	
	R.liveindicator, isnull(M.LiveHomeScore, 0) as livehomescore, isnull(M.LiveAwayScore, 0) as liveawayscore,M.ShowTime,M.MatchCode,

--R.status,
--	Sum(case when R.bettype = @BettypeHDP and R.FOffset = 0 then R.HomeTotal else 0 end) as HomeTotal_HDP, 
--	Sum(case when R.bettype = @BettypeHDP and R.FOffset = 0 then R.AwayTotal else 0 end) as AwayTotal_HDP, 
--	sum(case when R.bettype = @BettypeHDP and R.FOffset = 0 then R.BetCount else 0 end) as BetCount_HDP, 
--	Sum(case when R.bettype = @BettypeOU and R.FOffset = 0 then R.HomeTotal else 0 end) as HomeTotal_OU, 
--	Sum(case when R.bettype = @BettypeOU and R.FOffset = 0 then R.AwayTotal else 0 end) as AwayTotal_OU, 
--	sum(case when R.bettype = @BettypeOU and R.FOffset = 0 then R.BetCount else 0 end) as BetCount_OU, 
	sum(case when R.bettype IN (1,301)--= @BettypeHDP 
	and R.FOffset = -1 then case R.WinLostStatus when 1 then R.AwayLose/2 when 2 then R.AwayLose when 3 then R.HomeLose/2 when 4 then R.HomeLose when 6 then R.drawMO else 0 end else 0 end)  as WinLost_M1_HDP,
	sum(case when R.bettype IN (1,301)--= @BettypeHDP 
	and R.FOffset = 0 then case R.WinLostStatus when 1 then R.AwayLose/2 when 2 then R.AwayLose when 3 then R.HomeLose/2 when 4 then R.HomeLose  when 6 then R.drawMO else 0 end else 0 end)  as WinLost_0_HDP,
	sum(case when R.bettype IN (1,301)--= @BettypeHDP 
	and R.FOffset = 1 then case R.WinLostStatus when 1 then R.AwayLose/2 when 2 then R.AwayLose when 3 then R.HomeLose/2 when 4 then R.HomeLose  when 6 then R.drawMO else 0 end else 0 end)  as WinLost_1_HDP,

	sum(case when R.bettype IN(3,302)--= @BettypeOU 
	and R.FOffset = 0 then case R.WinLostStatus when 1 then R.AwayLose/2 when 2 then R.AwayLose when 3 then R.HomeLose/2 when 4 then R.HomeLose  when 6 then R.drawMO else 0 end end)  as WinLost_0_OU,
	sum(case when R.bettype IN(3,302)--= @BettypeOU 
	and R.FOffset = 1 then case R.WinLostStatus when 1 then R.AwayLose/2 when 2 then R.AwayLose when 3 then R.HomeLose/2 when 4 then R.HomeLose  when 6 then R.drawMO else 0 end end)  as WinLost_1_OU,
	sum(case when R.bettype IN(3,302)--= @BettypeOU 
	and R.FOffset = 2 then case R.WinLostStatus when 1 then R.AwayLose/2 when 2 then R.AwayLose when 3 then R.HomeLose/2 when 4 then R.HomeLose  when 6 then R.drawMO else 0 end end)  as WinLost_2_OU,

	sum(case when R.bettype IN (7,303)--= @BettypeHTHDP 
	and R.FOffset = -1 then case R.WinLostStatus when 1 then R.AwayLose/2 when 2 then R.AwayLose when 3 then R.HomeLose/2 when 4 then R.HomeLose  when 6 then R.drawMO else 0 end else 0 end)  as WinLost_M1_HTHDP,
	sum(case when R.bettype IN (7,303)--= @BettypeHTHDP 
	and R.FOffset = 0 then case R.WinLostStatus when 1 then R.AwayLose/2 when 2 then R.AwayLose when 3 then R.HomeLose/2 when 4 then R.HomeLose  when 6 then R.drawMO else 0 end else 0 end)  as WinLost_0_HTHDP,
	sum(case when R.bettype IN (7,303)--= @BettypeHTHDP 
	and R.FOffset = 1 then case R.WinLostStatus when 1 then R.AwayLose/2 when 2 then R.AwayLose when 3 then R.HomeLose/2 when 4 then R.HomeLose  when 6 then R.drawMO else 0 end else 0 end)  as WinLost_1_HTHDP,

	sum(case when R.bettype IN (8,304)--= @BettypeHTOU 
	and R.FOffset = 0 then case R.WinLostStatus when 1 then R.AwayLose/2 when 2 then R.AwayLose when 3 then R.HomeLose/2 when 4 then R.HomeLose  when 6 then R.drawMO else 0 end end)  as WinLost_0_HTOU,
	sum(case when R.bettype IN (8,304)--= @BettypeHTOU 
	and R.FOffset = 1 then case R.WinLostStatus when 1 then R.AwayLose/2 when 2 then R.AwayLose when 3 then R.HomeLose/2 when 4 then R.HomeLose  when 6 then R.drawMO else 0 end end)  as WinLost_1_HTOU,
	sum(case when R.bettype IN (8,304)--= @BettypeHTOU 
	and R.FOffset = 2 then case R.WinLostStatus when 1 then R.AwayLose/2 when 2 then R.AwayLose when 3 then R.HomeLose/2 when 4 then R.HomeLose  when 6 then R.drawMO else 0 end end)  as WinLost_2_HTOU,
	isnull(m.isNeutral, CONVERT(BIT,0)) as IsNeutral
from 	
	(
		Select 
			1 as ForecastID, F.bettype, liveindicator, '' as status, F.offset, 
--			hometotal, awaytotal, 
			homelose, awaylose, F.drawMO,
--			betcount, 
			BaseOffset + ForecastOffset.offset as BaseOffset, 
			case when F.BetType in (1,7,301,303) THEN--(@BetTypeHDP,@BetTypeHTHDP) then
				case 
					when F.VScoreHDP + BaseOffset + ForecastOffset.offset - F.Offset > 0 and F.VScoreHDP + BaseOffset + ForecastOffset.offset - F.Offset <0.5 then 1
					when F.VScoreHDP + BaseOffset + ForecastOffset.offset - F.Offset > 0.25 then 2
					when F.VScoreHDP + BaseOffset + ForecastOffset.offset - F.Offset < 0 and F.VScoreHDP + BaseOffset + ForecastOffset.offset - F.Offset >-0.5 then 3
					when F.VScoreHDP + BaseOffset + ForecastOffset.offset - F.Offset < -0.25 then 4
					when F.VScoreHDP + BaseOffset + ForecastOffset.offset - F.Offset =0 then 6
					else 5
				end
			when F.BetType in (3,8,302,304) THEN--(@BetTypeOU,@BetTypeHTOU) then
				case 
					when F.VScoreOU + BaseOffset + ForecastOffset.offset - F.Offset = 0.25 then 1
					when F.VScoreOU + BaseOffset + ForecastOffset.offset - F.Offset > 0.25 then 2
					when F.VScoreOU + BaseOffset + ForecastOffset.offset - F.Offset = -0.25 then 3
					when F.VScoreOU + BaseOffset + ForecastOffset.offset - F.Offset < -0.25 then 4
					when F.VScoreOU + BaseOffset + ForecastOffset.offset - F.Offset = 0 then 6
					else 5
				end
			end as WinlostStatus,
			F.MatchID, ForecastOffset.Offset as fOffset
		from (
				select  
					x.bettype AS bettype, x.liveindicator, 
				--	x.status, 
					-x.hdp + score AS offset, 
--					sum(x.hometotal ) as HomeTotal,
--					sum(x.awaytotal ) as AwayTotal,
					sum((x.homewin - x.awaylose) ) as AwayLose,
					sum((x.awaywin - x.homelose) ) as HomeLose,
					sum(x.MOwin+x.MOlose) AS drawMO,
--					sum(c) AS BetCount,
					@BaseOffsetHDP AS BaseOffset,
					MatchID,
					VScoreHDP,
					VScoreOU
				from 
					(
						select 
				--			status, 
							b.bettype,
							b.currency, b.hdp2 - b.hdp1 as hdp, b.livehomescore - b.liveawayscore AS score, b.liveindicator,
--							sum(case when betteam='h' then case when abs(odds) > 1 then abs(odds) * stake else stake end * (b.spositiontaking) else 0 end) AS hometotal,
--							sum(case when betteam='a' then case when abs(odds) > 1 then abs(odds) * stake else stake end * (b.spositiontaking) else 0 end) AS awaytotal, 
							sum(case when b.bettype =301 AND oddsspread>0 then (case when odds < 0 then 1 else odds end) * stake * (b.spositiontaking)*(oddsspread/100) else 0 end) MOwin,
							sum(case when b.bettype =301 AND oddsspread<0 then (case when odds < 0 then abs(odds) else 1 end)  * stake * (b.spositiontaking)*(oddsspread/100) else 0 end) MOlose,
							sum(case when betteam='h' then (case when odds < 0 then 1 else odds end) * stake * (b.spositiontaking) else 0 end) AS homewin,
							sum(case when betteam='a' then (case when odds < 0 then 1 else odds end) * stake * (b.spositiontaking) else 0 end) AS awaywin,
							sum(case when betteam='h' then (case when odds < 0 then abs(odds) else 1 end)  * stake * (b.spositiontaking) else 0 end) AS homelose,
							sum(case when betteam='a' then (case when odds < 0 then abs(odds) else 1 end)  * stake * (b.spositiontaking) else 0 end) AS awaylose,
--							count(*) AS c,

							M.MatchID,
							isnull(o.livehomescore, 0) - isnull(o.liveawayscore, 0) as VScoreHDP,
							isnull(o.livehomescore, 0) + isnull(o.liveawayscore, 0) as VScoreOU
						from 
							bettrans AS b with (nolock) 
							inner join Match as M with (NOLOCK) on b.MatchID = M.MatchID
							inner join Odds as O with (NOLOCK) on b.OddsID = O.OddsID
							inner join League as L with (NOLOCK) on M.LeagueID = L.LeagueID and L.LeagueID = @LeagueID
						where 
							b.srecommend = @srecommend
							and b.bettype IN (1,301)--=@BetTypeHDP
							--AND b.status in ('running','waiting')
							and b.statusID in (0,1)
							and b.ruben=0
						group by 
				--			status, 
							b.bettype,
							b.currency, b.hdp2 - b.hdp1, b.livehomescore - b.liveawayscore, b.liveindicator, M.MatchID, o.livehomescore, o.liveawayscore
					) AS x 
				group by 
				--	x.status, 
					-x.hdp + score, x.liveindicator, MatchID, VScoreHDP, VScoreOU,x.bettype
				
				UNION ALL
				select 
					x.bettype AS bettype, x.liveindicator, 
				--	x.status, 					
					x.hdp + score AS offset, 
--					sum(x.hometotal * e.) as HomeTotal,
--					sum(x.awaytotal * e.) as AwayTotal,
					sum((x.homewin - x.awaylose)) as AwayLose,
					sum((x.awaywin - x.homelose)) as HomeLose,
					sum(x.MOwin+x.MOlose) AS drawMO,
--					sum(c) AS BetCount,
					@BaseOffsetOU AS BaseOffset,
					MatchID,
					VScoreHDP,
					VScoreOU
				from 
						(
						select 
							b.liveindicator,  
				--			status, 
							b.bettype,
							b.currency, b.hdp1 as hdp, 0 AS score,
--							sum(case when betteam='h' then case when abs(odds) > 1 then abs(odds) * stake else stake end * (b.spositiontaking) else 0 end) AS hometotal,
--							sum(case when betteam='a' then case when abs(odds) > 1 then abs(odds) * stake else stake end * (b.spositiontaking) else 0 end) AS awaytotal, 
							sum(case when b.bettype =302 AND oddsspread>0 then (case when odds < 0 then 1 else odds end) * stake * (b.spositiontaking)*(oddsspread/100) else 0 end) MOwin,
							sum(case when b.bettype =302 AND oddsspread<0 then (case when odds < 0 then abs(odds) else 1 end)  * stake * (b.spositiontaking)*(oddsspread/100) else 0 end) MOlose,
							sum(case when betteam='h' then (case when odds < 0 then 1 else odds end) * stake * (b.spositiontaking) else 0 end) AS homewin,
							sum(case when betteam='a' then (case when odds < 0 then 1 else odds end) * stake * (b.spositiontaking) else 0 end) AS awaywin,
							sum(case when betteam='h' then (case when odds < 0 then abs(odds) else 1 end)  * stake * (b.spositiontaking) else 0 end) AS homelose,
							sum(case when betteam='a' then (case when odds < 0 then abs(odds) else 1 end)  * stake * (b.spositiontaking) else 0 end) AS awaylose,
--							count(*) AS c,

							M.MatchID,
							isnull(o.livehomescore, 0) - isnull(o.liveawayscore, 0) as VScoreHDP,
							isnull(o.livehomescore, 0) + isnull(o.liveawayscore, 0) as VScoreOU
						from 
							bettrans AS b with (nolock)  							
							inner join Match as M with (NOLOCK) on b.MatchID = M.MatchID and M.EventStatus = 'running'
							inner join Odds as O with (NOLOCK) on b.OddsID = O.OddsID
							inner join League as L with (NOLOCK) on M.LeagueID = L.LeagueID and L.LeagueID = @LeagueID
						where 
							b.srecommend = @srecommend
							and b.bettype IN (3,302)--=@BetTypeOU
							--AND b.status in ('running','waiting')
							and b.statusID in (0,1)
							and b.ruben=0
						group by 
				--			status, 
							b.bettype,
							b.currency, b.hdp1, b.liveindicator, M.MatchID, o.livehomescore, o.liveawayscore
					) AS x 
				group by 
				--	x.status, 
					liveindicator, x.score, x.hdp, MatchID, VScoreHDP, VScoreOU,x.bettype
--FIRST HALF HERE----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
				UNION ALL
				select  
					x.bettype AS bettype, x.liveindicator, 
				--	x.status, 
					-x.hdp + score AS offset, 
--					sum(x.hometotal ) as HomeTotal,
--					sum(x.awaytotal ) as AwayTotal,
					sum((x.homewin - x.awaylose) ) as AwayLose,
					sum((x.awaywin - x.homelose) ) as HomeLose,
					sum(x.MOwin+x.MOlose) AS drawMO,
--					sum(c) AS BetCount,
					@BaseOffsetHTHDP AS BaseOffset,
					MatchID,
					VScoreHDP,
					VScoreOU
				from 
					(
						select 
				--			status, 
							b.bettype,
							b.currency, b.hdp2 - b.hdp1 as hdp, b.livehomescore - b.liveawayscore AS score, b.liveindicator,
--							sum(case when betteam='h' then case when abs(odds) > 1 then abs(odds) * stake else stake end * (b.spositiontaking) else 0 end) AS hometotal,
--							sum(case when betteam='a' then case when abs(odds) > 1 then abs(odds) * stake else stake end * (b.spositiontaking) else 0 end) AS awaytotal, 
							sum(case when b.bettype =303 AND oddsspread>0 then (case when odds < 0 then 1 else odds end) * stake * (b.spositiontaking)*(oddsspread/100) else 0 end) MOwin,
							sum(case when b.bettype =303 AND oddsspread<0 then (case when odds < 0 then abs(odds) else 1 end)  * stake * (b.spositiontaking)*(oddsspread/100) else 0 end) MOlose,
							sum(case when betteam='h' then (case when odds < 0 then 1 else odds end) * stake * (b.spositiontaking) else 0 end) AS homewin,
							sum(case when betteam='a' then (case when odds < 0 then 1 else odds end) * stake * (b.spositiontaking) else 0 end) AS awaywin,
							sum(case when betteam='h' then (case when odds < 0 then abs(odds) else 1 end)  * stake * (b.spositiontaking) else 0 end) AS homelose,
							sum(case when betteam='a' then (case when odds < 0 then abs(odds) else 1 end)  * stake * (b.spositiontaking) else 0 end) AS awaylose,
--							count(*) AS c,

							M.MatchID,
							isnull(o.livehomescore, 0) - isnull(o.liveawayscore, 0) as VScoreHDP,
							isnull(o.livehomescore, 0) + isnull(o.liveawayscore, 0) as VScoreOU
						from 
							bettrans AS b with (nolock) 
							inner join Match as M with (NOLOCK) on b.MatchID = M.MatchID
							inner join Odds as O with (NOLOCK) on b.OddsID = O.OddsID
							inner join League as L with (NOLOCK) on M.LeagueID = L.LeagueID and L.LeagueID = @LeagueID
						where 
							b.srecommend = @srecommend
							and b.bettype IN (7,303)--=@BetTypeHTHDP
							--AND b.status in ('running','waiting')
							and b.statusID in (0,1)
							and b.ruben=0
						group by 
				--			status, 
							b.bettype,
							b.currency, b.hdp2 - b.hdp1, b.livehomescore - b.liveawayscore, b.liveindicator, M.MatchID, o.livehomescore, o.liveawayscore
					) AS x 
				group by 
				--	x.status, 
					-x.hdp + score, x.liveindicator, MatchID, VScoreHDP, VScoreOU,x.bettype
				
				UNION ALL
				select 
					x.bettype AS bettype, x.liveindicator, 
				--	x.status, 
					x.hdp + score AS offset, 
--					sum(x.hometotal * e.) as HomeTotal,
--					sum(x.awaytotal * e.) as AwayTotal,
					sum((x.homewin - x.awaylose)) as AwayLose,
					sum((x.awaywin - x.homelose)) as HomeLose,
					sum(x.MOwin+x.MOlose) AS drawMO,
--					sum(c) AS BetCount,
					@BaseOffsetHTOU AS BaseOffset,
					MatchID,
					VScoreHDP,
					VScoreOU
				from 
						(
						select 
							b.liveindicator,  
				--			status, 
							b.bettype,
							b.currency, b.hdp1 as hdp, 0 AS score,
--							sum(case when betteam='h' then case when abs(odds) > 1 then abs(odds) * stake else stake end * (b.spositiontaking) else 0 end) AS hometotal,
--							sum(case when betteam='a' then case when abs(odds) > 1 then abs(odds) * stake else stake end * (b.spositiontaking) else 0 end) AS awaytotal, 
							sum(case when b.bettype =304 AND oddsspread>0 then (case when odds < 0 then 1 else odds end) * stake * (b.spositiontaking)*(oddsspread/100) else 0 end) MOwin,
							sum(case when b.bettype =304 AND oddsspread<0 then (case when odds < 0 then abs(odds) else 1 end)  * stake * (b.spositiontaking)*(oddsspread/100) else 0 end) MOlose,
							sum(case when betteam='h' then (case when odds < 0 then 1 else odds end) * stake * (b.spositiontaking) else 0 end) AS homewin,
							sum(case when betteam='a' then (case when odds < 0 then 1 else odds end) * stake * (b.spositiontaking) else 0 end) AS awaywin,
							sum(case when betteam='h' then (case when odds < 0 then abs(odds) else 1 end)  * stake * (b.spositiontaking) else 0 end) AS homelose,
							sum(case when betteam='a' then (case when odds < 0 then abs(odds) else 1 end)  * stake * (b.spositiontaking) else 0 end) AS awaylose,
--							count(*) AS c,

							M.MatchID,
							isnull(o.livehomescore, 0) - isnull(o.liveawayscore, 0) as VScoreHDP,
							isnull(o.livehomescore, 0) + isnull(o.liveawayscore, 0) as VScoreOU
						from 
							bettrans AS b with (nolock)  							
							inner join Match as M with (NOLOCK) on b.MatchID = M.MatchID and M.EventStatus = 'running'
							inner join Odds as O with (NOLOCK) on b.OddsID = O.OddsID
							inner join League as L with (NOLOCK) on M.LeagueID = L.LeagueID and L.LeagueID = @LeagueID
						where 
							b.srecommend = @srecommend
							and b.bettype IN (8,304)--=@BetTypeHTOU
							--AND b.status in ('running','waiting')
							and b.statusID in (0,1)
							and b.ruben=0
						group by 
				--			status, 
							b.bettype,
							b.currency, b.hdp1, b.liveindicator, M.MatchID, o.livehomescore, o.liveawayscore
					) AS x 
				group by 
				--	x.status, 
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
						select 8 as bettype,2 as offset UNION ALL
						select 301 as bettype,-1 as offset union all
						select 301 as bettype,0 as offset union all
						select 301 as bettype,1 as offset union all
						select 302 as bettype,0 as offset union all
						select 302 as bettype,1 as offset union all
						select 302 as bettype,2 as offset union all
						select 303 as bettype,-1 as offset union all
						select 303 as bettype,0 as offset union all
						select 303 as bettype,1 as offset union all
						select 304 as bettype,0 as offset union all
						select 304 as bettype,1 as offset union all
						select 304 as bettype,2 as offset
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
--,R.status





