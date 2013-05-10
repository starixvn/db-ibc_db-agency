USE [bodb02]
GO
/****** Object:  StoredProcedure [dbo].[Dot_Admin_f4_SingleMatch]    Script Date: 09/15/2011 03:34:54 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO



ALTER procedure [dbo].[Dot_Admin_f4_SingleMatch] 
@matchid int ,
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
		case when hdp1=home and hdp2=away then 1 else 0 end r
	from	scores s (nolock) left join
	(
		select		betteam,
				sum( ( ((stake * (1-tpositiontaking)) * case when odds<0 then -odds+1 else 1 end) * b.virtualrate) * case when odds<0 then 1/odds+1 else odds-1 end ) / sum( ((stake* (1-tpositiontaking))*case when odds<0 then -odds else 1 end) * b.virtualrate) trueodds,
				sum( ((stake* (1-tpositiontaking)) *case when odds<0 then -odds+1 else 1 end) * b.virtualrate) risk,
				hdp1,hdp2
		from		bettrans b (nolock) 
		where		matchid = @matchid
		and		bettype = 4 and ruben = 0 AND liveindicator = @liveindicator
		group by 	betteam, hdp1,hdp2
	) r
on 1=1
	
) t
group by home,away
order by home,away
end 



GO
GRANT VIEW DEFINITION ON [dbo].[Dot_Admin_f4_SingleMatch] TO [vnteam]