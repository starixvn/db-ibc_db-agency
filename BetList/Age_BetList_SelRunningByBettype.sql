ALTER PROCEDURE Age_BetList_SelRunningByBettype
	@custid int,
	@bettype int,
	@Language varchar(2) = 'E'
 AS
--Original: BetsSelBetList_SAg
--AGENT SITE
--Vinh@20080104: include mix parlay
--Phuc@2008-01-06:Merge Age_BetList_SelRunningByBettype_SAg/Mag/Ag =>Age_BetList_SelRunningByBettype Add typenamee2,sportname 2008-01-05
SET NOCOUNT ON
if @bettype<9
BEGIN
	select 
	isnull(s.sportname,space(100)) as sportname,
	customer.username,
	case @Language when 'E' then l.leaguename when 'J' then isnull(l.leaguenamej, l.leaguename) else isnull(l.leaguenamec_uni, l.leaguename) end + N'<br>' + case @Language when 'E' then bettype.typenamee when 'J' then isnull(bettype.typenamej, bettype.typenamee) else isnull(bettype.typenamec_uni, bettype.typenamee) end as typenamee,
	case @Language when 'E' then l.leaguename when 'J' then isnull(l.leaguenamej, l.leaguename) else isnull(l.leaguenamec_uni, l.leaguename) end  as leaguename,
	case @Language when 'E' then bettype.typenamee when 'J' then isnull(bettype.typenamej, bettype.typenamee) else isnull(bettype.typenamec_uni, bettype.typenamee) end as typenamee2,
	convert(nvarchar,bettrans.transid) AS refno,bettrans.bettype,
	bettrans.transid,match.matchcode,
	case @Language when 'E' then a.teamname when 'J' then isnull(a.teamnamej, a.teamname) else isnull(a.teamnamec_uni, a.teamname) end as home,
	case @Language when 'E' then b.teamname when 'J' then isnull(b.teamnamej, b.teamname) else isnull(b.teamnamec_uni, b.teamname) end as away,
	convert(float, bettrans.hdp1) as hdp1, convert(float, bettrans.hdp2) as hdp2, bettrans.odds,
	bettrans.status,bettrans.stake,bettrans.transdate,
	bettrans.betteam,bettrans.comstatus,bettrans.status ,bettrans.spositiontaking ,bettrans.mpositiontaking ,bettrans.apositiontaking
	from 
		bettrans with (nolock)
		inner join customer with (nolock) on bettrans.custid=customer.custid
		inner join customer owner with(nolock) on owner.custid=@custid  
		inner join bettype with (nolock) on bettype.typeid=bettrans.bettype	
		inner join match with (nolock) on  bettrans.matchid=match.matchid 
		inner join team a with (nolock) on a.teamid=match.homeid 
		inner join team b  with (nolock) on  b.teamid=match.awayid
		inner join league as l with (nolock) on match.leagueid = l.leagueid
		left join dbo.sports as s with(nolock) on l.sporttype=s.sporttype
	where 
		@custid=case when owner.roleid=2 then bettrans.recommend when owner.roleid=3 then bettrans.mrecommend when owner.roleid=4 then bettrans.srecommend else -@custid end  and 
		bettrans.status='running' and bettrans.bettype=@bettype
	order by bettrans.status,bettrans.transid
END
else if @bettype=10
BEGIN
	select 
	isnull(s.sportname,space(100)) as sportname,
	customer.username,
	case @Language when 'E' then bettype.typenamee when 'J' then isnull(bettype.typenamej, bettype.typenamee) else isnull(bettype.typenamec_uni, bettype.typenamee) end as typenamee,
	case @Language when 'E' then bettype.typenamee when 'J' then isnull(bettype.typenamej, bettype.typenamee) else isnull(bettype.typenamec_uni, bettype.typenamee) end as typenamee2,
	convert(nvarchar,bettrans.transid) AS refno,bettrans.bettype,
	bettrans.transid,match.matchcode,
	case @Language when 'E' then a.teamname when 'J' then isnull(a.teamnamej, a.teamname) else isnull(a.teamnamec_uni, a.teamname) end as home,
	'' as away,
	convert(float, bettrans.hdp1) as hdp1, convert(float, bettrans.hdp2) as hdp2, bettrans.odds,
	bettrans.status,bettrans.stake,bettrans.transdate,
	bettrans.betteam,bettrans.comstatus,bettrans.status ,bettrans.spositiontaking ,bettrans.mpositiontaking ,bettrans.apositiontaking,
	case @Language when 'E' then l.leaguename when 'J' then isnull(l.leaguenamej, l.leaguename) else isnull(l.leaguenamec_uni, l.leaguename) end as leaguename
	from 
		bettrans with (nolock)
		inner join customer with (nolock) on bettrans.custid=customer.custid 
		inner join customer owner with(nolock) on owner.custid=@custid
		inner join bettype with (nolock) on bettype.typeid=bettrans.bettype	
		inner join outright as match with (nolock) on  bettrans.matchid=match.orid 
		inner join team a with (nolock) on a.teamid=match.teamid
		inner join league as l with (nolock) on l.leagueid = match.leagueid
		left join dbo.sports as s with(nolock) on l.sporttype=s.sporttype
	where 
		@custid=case when owner.roleid=2 then bettrans.recommend when owner.roleid=3 then bettrans.mrecommend when owner.roleid=4 then bettrans.srecommend else -@custid end  and 
	 	bettrans.status='running' and bettrans.bettype=@bettype
	order by bettrans.status,bettrans.transid
END
else if @bettype=9 --inlcude mix parlay - Vinh@20071228
BEGIN
	select 
		customer.username,0,
		case @Language when 'E' then 'Multiple Bet' when 'C' then (select typenamec_uni from bettype where typeid=9) when 'J' then (select typenamej from bettype where typeid=9) end AS typenamee,
		case @Language when 'E' then 'Multiple Bet' when 'C' then (select typenamec_uni from bettype where typeid=9) when 'J' then (select typenamej from bettype where typeid=9) end AS typenamee2,
		convert(nvarchar,bettrans.transid) AS refno,
		--convert(nvarchar,bettrans.refno) AS refno,
		9 AS bettype,
		bettrans.transid,'' matchcode,'' home,'' away,'' hdp1,'' hdp2,bettrans.odds,
		bettrans.status,bettrans.stake,bettrans.transdate,bettrans.betteam,bettrans.comstatus,0 AS livehomescore, 
		0 AS liveawayscore,0 AS liveindicator ,bettrans.tpositiontaking,bettrans.spositiontaking,bettrans.mpositiontaking,bettrans.apositiontaking
	from bettrans with (nolock)
		inner join customer with (nolock) on customer.custid=bettrans.custid
		inner join customer owner with(nolock) on owner.custid=@custid
	where
		@custid=case when owner.roleid=2 then bettrans.recommend when owner.roleid=3 then bettrans.mrecommend when owner.roleid=4 then bettrans.srecommend else -@custid end  and 
		bettrans.status=case when owner.roleid=2 then 'running' else bettrans.status end and 
		bettrans.ruben=0 and 
		bettrans.matchid=0 and comstatus<>'s'
	order by customer.username
END




GO
GRANT EXECUTE ON Age_BetList_SelRunningByBettype TO [bodbadmin]
GO
GRANT EXECUTE ON Age_BetList_SelRunningByBettype TO [bodbDownlineNet]
GO
GRANT EXECUTE ON Age_BetList_SelRunningByBettype TO [bodbDownlineNetView]
GO
GRANT EXECUTE ON Age_BetList_SelRunningByBettype TO [bodbSuperNet]

