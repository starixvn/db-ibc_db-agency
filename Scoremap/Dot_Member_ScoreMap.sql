USE [bodb02]
GO
/****** Object:  StoredProcedure [dbo].[Dot_Member_ScoreMap]    Script Date: 09/15/2011 03:24:47 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[Dot_Member_ScoreMap]
	@matchid int, 
	@custid int,
	@homeBeginScore smallint = 0,
	@homeEndScore smallint = 5,
	@awayBeginScore smallint = 0,
	@awayEndScore smallint = 5
AS
BEGIN
/*
	Created by: KaiChen
	Date: 20110403
	Task: forecast function for member site (copy from Dot_Admin_f1,Dot_Admin_f2,Dot_Admin_f3,Dot_Admin_f4,Dot_Admin_f5,Dot_Admin_f6@DB02)
	DB: DBO6.bodb02	
	
	20110408@KaiChen(DB06): identify HT,FT . producing two result to help web page display 
	20110616@Tim(DB06): score input from parameter
	20110812@Tim(DB06): add 6 new bettype calculation (13,24,25,26,27,28)
*/
	SET NOCOUNT ON;
	
	declare @tmpScores table(home int, away int)
	declare @tmpBettrans table(transid bigint primary key, betteam nvarchar(10), matchid int, custid int, bettype smallint,
							   hdp1 smallmoney, hdp2 smallmoney, odds smallmoney, stake money, liveindicator bit, 
								livehomescore smallint, liveawayscore smallint)

	-- get scores template
	Insert into @tmpScores (home, away) select home, away from scores where (home between @homeBeginScore and @homeEndScore) and (away between @awayBeginScore and @awayEndScore )	
	
	-- get member tickets into temp table
	Insert into @tmpBettrans 
	select transid, betteam, matchid, custid, bettype, hdp1, hdp2, odds, stake, liveindicator, livehomescore, liveawayscore
	from bettrans with (nolock)
	where matchid = @matchid
		and custid = @custID
		and bettype in (1,2,3,4,5,6,7,8,15,13,24,25,26,27,28)
		and ruben = 0
        and [status] = 'running'
	--HT,bettype = 7,8,15
	select home,away,
					 isnull(-sum(case
						when r<=-0.5 and bt in (7,8) then 1
						when r<0 and bt in (7,8) then 1+(r*2)
						else 0
					end * risk) 
					+sum(case
						when r>=0.5 and bt in (7,8) then 1
						when r>0 and bt in (7,8) then 1-(r*2)
						else 0
					end * risk * trueodds),0)
				+/*once bt = 7,8 will calculate equation above ,the other way will calculate below*/
					isnull(-sum(case
						when r=0 and bt = 15 then 1
						else 0
					end * risk) 
					+sum(case
						when r=1 and bt = 15 then 1
						else 0
					end * risk * trueodds),0)
			  total
	from(
			select	s.home,
					s.away, 
					r.risk, 
					r.trueodds,
					case	
							when betteam  = 'h' and bt = 7 then (home+hc) - (away) 
							when betteam <> 'h' and bt = 7 then (away+hc) - (home) 
							when betteam  = 'h' and bt = 8 then (home+away) - hc 
							when betteam <> 'h' and bt = 8 then hc - (home+away) 
							when home>away and betteam = '1' and bt = 15 then 1 
							when away>home and betteam = '2' and bt = 15 then 1
							when home=away and betteam = 'x' and bt = 15 then 1 
							else 0
					end  r,
					bt
			from @tmpScores s Cross Join 
			(
					select	betteam,
							sum( ( (stake * case when odds<0 then -odds else 1 end)) * case when odds <0 then 1/-CAST(odds as float) else odds end ) / sum( (stake*case when odds<0 then -odds else 1 end) ) trueodds,
							sum( (stake * case when odds<0 then -odds else 1 end) ) risk,
							case when betteam = 'h' and liveindicator = 1 then (hdp2+liveawayscore)-(hdp1 + livehomescore)
								 when betteam = 'h' and liveindicator <> 1 then hdp2-hdp1
								 when betteam <> 'h' and liveindicator = 1 then (hdp1+livehomescore)-(hdp2+liveawayscore) 
								 else hdp1-hdp2	 
							end hc,
							0 hd,
							7 bt
					from @tmpBettrans b 
					where bettype = 7 
					group by betteam, hdp1, hdp2, liveindicator, livehomescore, liveawayscore
				Union all
					select	betteam,
						sum( ( (stake * case when odds<0 then -odds else 1 end) ) * case when odds <0 then 1/-CAST(odds as float) else odds end ) / sum( (stake*case when odds<0 then -odds else 1 end) ) trueodds,
						sum( (stake *case when odds<0 then -odds else 1 end) ) risk,
						hdp1,
						0 hd,
						8 bt
					from @tmpBettrans b 
					where bettype  = 8
					group by betteam, hdp1, liveindicator, livehomescore, liveawayscore
				Union all
					select	betteam,
						sum( stake * ( odds-1)) / sum(stake) trueodds,
						sum( stake ) risk,
						0 hc,
						0 hd,
						15 bt
					from @tmpBettrans b 
					where bettype = 15 
					group by betteam
			) r
		)u
	group by home, away
	order by home, away
	
	--FT bettype = 1,2,3,4,5,6
	select home,away,
					 isnull(-sum(case
						when r<=-0.5 and bt in (1,3,25) then 1
						when r<0 and bt in (1,3,25) then 1+(r*2)
						else 0
					end * risk) 
					+sum(case
						when r>=0.5 and bt in (1,3,25) then 1
						when r>0 and bt in (1,3,25) then 1-(r*2)
						else 0
					end * risk * trueodds),0)
				+/*once bt = 1,3,25 will calculate equation above ,the other way will calculate below*/
					isnull(-sum(case
						when r=0 and bt in (2,4,5,6,13,24,26,27,28)then 1
						else 0
					end * risk) 
					+sum(case
						when r=1 and bt in (2,4,5,6,13,24,26,27,28)then 1
						else 0
					end * risk * trueodds),0)
			  total
	from(
			select	s.home,
					s.away, 
					r.risk, 
					r.trueodds,
					case	when betteam  = 'h' and bt = 1 then (home+hc) - (away) 
							when betteam <> 'h' and bt = 1 then (away+hc) - (home) 
							when betteam  = 'h' and bt = 2 then (home+away)&1  
							when betteam <> 'h' and bt = 2 then 1-( (home+away)&1)
							when betteam  = 'h' and bt = 3 then (home+away) - hc 
							when betteam <> 'h' and bt = 3 then hc - (home+away)
							when hc=home and hd=away and bt = 4 then 1  
							when home>away and betteam = '1' and bt = 5 then 1 
							when away>home and betteam = '2' and bt = 5 then 1
							when home=away and betteam = 'x' and bt = 5 then 1 
							when home+away>= hc and home+away<=hd and bt = 6 then 1 
							when betteam = 'hy' and away = 0 and bt = 13 then 1
							when betteam = 'hn' and away > 0 and bt = 13 then 1
							when betteam = 'ay' and home = 0 and bt = 13 then 1
							when betteam = 'an' and home > 0 and bt = 13 then 1
							when betteam = '1x' and (home >= away) and bt = 24 then 1
							when betteam = '2x' and (away >= home) and bt = 24 then 1
							when betteam = '12' and (home <> away) and bt = 24 then 1
							when betteam = 'h' and (home > away) and bt = 25 then 1
							when betteam = 'a' and (away > home) and bt = 25 then 1
							when betteam = 'n' and home = 0 and away = 0 and bt= 26 then 1
							when betteam = 'o' and (home = 0 or away = 0) and home + away >=1 and bt= 26 then 1
							when betteam = 'b' and home + away >= 2 and home <> 0 and away <> 0  and bt= 26 then 1
							when betteam = 'h' and away = 0 and home >= 1 and bt = 27 then 1
							when betteam = 'a' and home = 0 and away >= 1 and bt = 27 then 1
							when betteam = '1' and hc + home - away > 0 and  bt = 28 then 1 
							when betteam = '2' and hc + away - home > 0 and  bt = 28 then 1
							when betteam = 'x' and hc - (home - away) = 0 and bt = 28 then 1 
							else 0
					end  r,
					bt
			from @tmpScores s Cross Join 
			(
					select	betteam,
							sum( ( (stake * case when odds<0 then -odds else 1 end)) * case when odds <0 then 1/-CAST(odds as float) else odds end ) / sum( (stake*case when odds<0 then -odds else 1 end) ) trueodds,
							sum( (stake * case when odds<0 then -odds else 1 end) ) risk,
							case when betteam = 'h' and liveindicator = 1 then (hdp2+liveawayscore)-(hdp1 + livehomescore)
								 when betteam = 'h' and liveindicator <> 1 then hdp2-hdp1
								 when betteam <> 'h' and liveindicator = 1 then (hdp1+livehomescore)-(hdp2+liveawayscore) 
								 else hdp1-hdp2	 
							end hc,
							0 hd,
							1 bt
					from @tmpBettrans b 
					where bettype = 1 
					group by betteam, hdp1, hdp2, liveindicator, livehomescore, liveawayscore
				Union all
					select	betteam,
						sum( (stake * case when odds<0 then -odds else 1 end ) * case when odds <0 then 1/-CAST(odds as float) else odds end ) / sum(stake * case when odds<0 then -odds else 1 end) trueodds,
						sum(stake * case when odds<0 then -odds else 1 end) risk,
						0 hc,
						0 hd,
						2 bt
					from @tmpBettrans b 
					where bettype = 2 
					group by betteam, hdp1
				Union all
					select	betteam,
						sum( ( (stake * case when odds<0 then -odds else 1 end) ) * case when odds <0 then 1/-CAST(odds as float) else odds end ) / sum( (stake*case when odds<0 then -odds else 1 end) ) trueodds,
						sum( (stake *case when odds<0 then -odds else 1 end) ) risk,
						hdp1,
						0 hd,
						3 bt
					from @tmpBettrans b 
					where bettype = 3
					group by betteam, hdp1, liveindicator, livehomescore, liveawayscore
				Union all
					select	betteam,
						sum(stake * (odds-1)) / sum(stake) trueodds,
						sum(stake) risk,
						hdp1,
						hdp2,
						4 bt
					from @tmpBettrans b
					where bettype = 4 
					group by betteam, hdp1,hdp2
				Union all
					select	betteam,
						sum( stake * ( odds-1)) / sum(stake) trueodds,
						sum( stake ) risk,
						0 hc,
						0 hd,
						5 bt
					from @tmpBettrans b 
					where bettype = 5
					group by betteam
				Union all
					select	betteam, 
							sum( stake * (odds-1)) / sum(stake) trueodds,
							sum(stake) risk,
							cast(left(betteam,1)as int) as hc,
							case right(betteam,1) 
								when 'r' then 999
								else cast(right(betteam,1) as int) 
							end as hd,
							6 bt
					from @tmpBettrans b 
					where bettype = 6
					group by betteam
				Union all
					select	betteam, 
							sum( stake * (odds-1)) / sum(stake) trueodds,
							sum(stake) risk,
							0 hc,
							0 hd,
							13 bt
					from @tmpBettrans b 
					where bettype = 13
					group by betteam
				Union all
					select	betteam, 
							sum( stake * (odds-1)) / sum(stake) trueodds,
							sum(stake) risk,
							0 hc,
							0 hd,
							24 bt
					from @tmpBettrans b 
					where bettype = 24
					group by betteam
				Union all
					select	betteam, 
							sum( stake * (odds-1)) / sum(stake) trueodds,
							sum(stake) risk,
							0 hc,
							0 hd,
							25 bt
					from @tmpBettrans b 
					where bettype = 25
					group by betteam
				Union all
					select	betteam, 
							sum( stake * (odds-1)) / sum(stake) trueodds,
							sum(stake) risk,
							0 hc,
							0 hd,
							26 bt
					from @tmpBettrans b 
					where bettype = 26
					group by betteam
				Union all
					select	betteam, 
							sum( stake * (odds-1)) / sum(stake) trueodds,
							sum(stake) risk,
							0 hc,
							0 hd,
							27 bt
					from @tmpBettrans b 
					where bettype = 27
					group by betteam
				Union all
					select	betteam, 
							sum( stake * (odds-1)) / sum(stake) trueodds,
							sum(stake) risk,
							case when betteam = '1' then hdp2-hdp1
								 else hdp1-hdp2	 
							end hc,
							0 hd,
							28 bt
					from @tmpBettrans b 
					where bettype = 28
					group by betteam, hdp1, hdp2
			) r
		)u
	group by home, away
	order by home, away
END

GO
GRANT VIEW DEFINITION ON [dbo].[Dot_Member_ScoreMap] TO [vnteam]