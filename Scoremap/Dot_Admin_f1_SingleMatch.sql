USE [bodb02]
GO
/****** Object:  StoredProcedure [dbo].[Dot_Admin_f1_SingleMatch]    Script Date: 09/15/2011 03:31:50 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO



ALTER procedure [dbo].[Dot_Admin_f1_SingleMatch] 
@matchid int, 
@liveindicator bit
as begin
select	home, away,
	round(isnull(-sum(case
		when r<=-0.5 then 1
		when r<0 then 1+(r*2)
		else 0
	end * risk) 
	+sum(case
		when r>=0.5 then 1
		when r>0 then 1-(r*2)
		else 0
	end * risk * trueodds),0),0) total
from
(
	select	s.home,
		s.away, 
		r.risk, 
		r.trueodds,
		case when betteam = 'h' then (home+hc) - (away) else (away+hc) - (home) end  r
	from	scores s (nolock) left join 
	(
		select		betteam,
				sum( ( ((stake * (1-tpositiontaking)) * case when odds<0 then -odds else 1 end) * b.virtualrate) * case when odds <0 then 1/-odds else odds end ) / sum( ((stake* (1-tpositiontaking))*case when odds<0 then -odds else 1 end) * b.virtualrate) trueodds,
				sum( ((stake* (1-tpositiontaking)) *case when odds<0 then -odds else 1 end) * b.virtualrate) risk,
				case betteam when 'h' then hdp2-hdp1 else hdp1-hdp2 end hc
		from		bettrans b (nolock) 
		where		matchid = @matchid
		and		bettype = 1 and ruben = 0 AND liveindicator = @liveindicator
		group by 	betteam, hdp1, hdp2
	) r
	on 1=1
) t
group by home,away
order by home,away
end 





GO
GRANT VIEW DEFINITION ON [dbo].[Dot_Admin_f1_SingleMatch] TO [vnteam]