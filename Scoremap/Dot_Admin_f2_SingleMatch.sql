USE [bodb02]
GO
/****** Object:  StoredProcedure [dbo].[Dot_Admin_f2_SingleMatch]    Script Date: 09/15/2011 03:33:21 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO



ALTER procedure [dbo].[Dot_Admin_f2_SingleMatch] 
@matchid int,
@liveindicator bit 
as begin
select	home, away,
	round(isnull(-sum(case
		when r=0 then 1
		else 0
	end * risk) 
	+sum(case
		when r=1 then 1
		else 0
	end * risk * trueodds),0),0) total
from
(
	select	s.home,
		s.away, 
		r.risk, 
		r.trueodds,
		betteam,
		case when betteam = 'h' then (home+away)&1  else 1-( (home+away)&1) end r
	from	scores s (nolock) left join
	(
		select		betteam,
				sum( ( ((stake * (1-tpositiontaking)) * case when odds<0 then -odds else 1 end) * b.virtualrate) * case when odds <0 then 1/-odds else odds end ) / sum( ((stake* (1-tpositiontaking))*case when odds<0 then -odds else 1 end) * b.virtualrate) trueodds,
				sum( ((stake* (1-tpositiontaking)) *case when odds<0 then -odds else 1 end) * b.virtualrate) risk
		from		bettrans b (nolock) 
		where		matchid = @matchid
		and		bettype = 2 and ruben = 0 AND liveindicator = @liveindicator
		group by 	betteam, hdp1
	) r
	on 1=1
) t
group by home,away
order by home,away
end 





GO
GRANT VIEW DEFINITION ON [dbo].[Dot_Admin_f2_SingleMatch] TO [vnteam]