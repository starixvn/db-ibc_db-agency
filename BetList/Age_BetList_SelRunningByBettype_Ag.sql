
ALTER PROC [dbo].[Age_BetList_SelRunningByBettype_Ag]
	@custid int,
	@bettype int,
	@Language varchar(2) = 'E'
 AS

/*
Created: 
Task : Betlist
DB: DBAGE/bodb_AGE
Original:BetsSelBetList_Ag
Revisions:
    - 20080104@Vinh: include mix parlay
    - 20080105: Add typenamee2,sportname 
    - 20080629@Viet: Remove Teamname, Leaguename, Sportname, TypeName
    - 20090326@Phuc: get indexname for FI
    - 20090406@HanhVu: remove refno
    - 20090416@Minh: remove indexName
    - 20090618@AnhPham: Remove 'Customer' table
   	- 20090710@Phuc: unhide IP for TB currency.
   	- 20090930@Phuc: get oddstype.
   	- 20091208@Henry: Add 1 more column: refno for calling Mix Parlay SP
   	- 20100527@Henry: Change to use StatusID instead of Status in WHERE statement
   	- 20100611@Henry: Change mix-parlay match from 0 to 9
   	- 20110408@Amy: Change function to get Odds value and showed odds type
   	- 20110516@Johnson: Apply new arrange bettype
   	- 20110801@Sophia: Add new bettype = 29 : Combination mix parlay
	- 20110802@Lukas: get 'waiting' tickets for mix parlay - support live-mix parlay
	- 20110809@Sophia: Not to use function f_GetChoice to get betteam ( Bettype <>14, 16)
	- 20110811@Sophia: Add new columns actual_stake and modds 
	- 20110829@Sophia: Add new columns BetID
	- 20110930@Johnson: Get column matchid into betlist
	- 20111122@Sophia: Add Checktime and SecAcceptFlag to show status waiting or running
	- 20111216@Sophia: Remove function f_GetOddsByBettype , f_GetChoice , f_ShowOddsByBettype
	- 20120119@Sophia:  Add showtime for Table - Shoe - Hand of LiveCasino 
						 Add Sub table for Live Casino
	- 20120424@Lukas: Get more column custid
	- 20120705@Sophia: Get sporttype for outright
	- 20120926@Sophia: Get Comstatus
	- 20130107@Dan: merge code from production
	- 20130121@Dan: Move sp from DB053/bodb02 to DBAGE/bodb_AGE
	- 20140425@Dom: Group TB and FGLG
*/

SET NOCOUNT ON
IF @bettype IN ( 9, 29)--inlcude mix parlay and Combination mix parlay
BEGIN
	select 
		0 as sporttype,
		b.username,				
		b.bettype,
		b.custid,
		b.transid,
		b.refno,
		0 as matchid,
		'' matchcode,
		0 as homeID,
		0 as awayID,
		'' hdp1,
		'' hdp2,
		b.odds,
		b.modds,
		b.status,
		b.stake,
		b.actual_stake,
		b.transdate,		
		b.betteam,
		b.betID,
		0 AS livehomescore, 
		0 AS liveawayscore,
		0 AS liveindicator ,
		b.tpositiontaking,
		b.spositiontaking,
		b.mpositiontaking,
		b.apositiontaking, 
		b.discount as adiscount,
		b.adiscount as mdiscount,
		b.sdiscount as sdiscount,
		b.IP as IP,
		CONVERT(BIT,0) as IsNeutral,
		0 as oddstype,
		'' as showtime,
		CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END AS comstatus	
	from dbo.bettrans_running b with (nolock)
	where
		b.Recommend=@custid and 
		b.bettype = @bettype and
		--b.matchid = 0 and
		b.matchid = @bettype and
		--b.status='running' and
		b.statusID BETWEEN 0 and 1 AND 
		b.ruben=0 
		
	order by b.status, b.transid
	RETURN
END

if @bettype=10 -- Outright
BEGIN
	select 
		l.sporttype,
		b.username,
		b.bettype,	
		b.custid,			
		b.transid,
		b.refno,
		0 as matchid,
		m.matchcode,
		m.teamID as homeID,
		0 as awayID,
		convert(float, b.hdp1) as hdp1, 
		convert(float, b.hdp2) as hdp2, 
		b.odds,
		b.modds,
		b.status,
		b.stake,
		b.actual_stake,
		b.transdate,		
		b.betteam,
		b.betID,
		b.spositiontaking,
		b.mpositiontaking,
		b.apositiontaking, 
		b.discount as adiscount,
		b.adiscount as mdiscount,
		b.sdiscount as sdiscount,
		m.LeagueID,
		b.livehomescore,
		b.liveawayscore,
		b.liveindicator, 
		IP as IP,
		CONVERT(BIT,0) as IsNeutral,
		0 as oddstype,
		'' as showtime,
		CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END AS comstatus
	from 		
		dbo.bettrans_running b with (nolock)
		INNER JOIN bodb02.dbo.outright as m with (nolock) on  b.matchid=m.orid
		INNER JOIN bodb02.dbo.league l with (nolock) on m.leagueid = l.leagueid	
	where 
		b.Recommend=@custid  
		and b.bettype=@bettype
		--and b.status='running' 
		and b.statusID=0 		
	order by b.status, b.transid
	RETURN
END

if @bettype<=19000
BEGIN
	select 
		m.sporttype,
		b.username,
		m.leagueID, 
		b.bettype,
		b.custid,		
		b.transid,
		b.refno,
		m.matchid,
		m.matchcode,
		m.homeID,
		m.awayID,
		convert(float, b.hdp1) as hdp1, 
		convert(float, b.hdp2) as hdp2, 
		b.odds,
		b.modds,
		CASE WHEN b.status = 'running' AND IsNull(b.SecAcceptFlag, 0) = 1 and IsNull(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
				 ELSE b.status 
				 END as status,
		b.stake,
		b.actual_stake,
		b.transdate,		
		b.betteam,
		b.betID,
		b.spositiontaking,
		b.mpositiontaking,
		b.apositiontaking, 
		b.discount as adiscount,
		b.adiscount as mdiscount,
		b.sdiscount as sdiscount,
		b.livehomescore,
		b.liveawayscore,
		b.liveindicator, 
		IP as IP,
		isnull(m.isNeutral, CONVERT(BIT,0)) as IsNeutral,
		b.OddsType,
		m.showtime,
		CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END AS comstatus
 	from 		
		dbo.bettrans_running b with (nolock)
		inner join bodb02.dbo.match m with (nolock) on  b.matchid=m.matchid 				
	where 
		b.Recommend=@custid
		--and b.bettype=@bettype
		and ( (@bettype=6 AND b.bettype IN(6,126)) OR (@bettype=14 and b.bettype IN(14,127)) OR bettype = @bettype )
		--and b.status in ('waiting','running')
		and b.statusID in (0,1)
		
	order by b.status, b.transid
END

IF @bettype between 1101 and 1199
BEGIN
	--get data from bettransg for bettype 1101
	SELECT 
		bg.refno, 
		bg.odds, 
		bg.stake,
		bg.status ,
		bg.apositiontaking, 
		bg.mpositiontaking, 
		bg.spositiontaking,
		bg.betteam  
	FROM bodb02.dbo.bettransg bg with (NOLOCK)	
	INNER JOIN dbo.bettrans_running b ON bg.refno = b.refno
	WHERE	b.Recommend=@custid  and 		
			b.bettype=@bettype and
			b.statusID in (0,1)
END



GO

GRANT EXECUTE ON [dbo].[Age_BetList_SelRunningByBettype_Ag] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_BetList_SelRunningByBettype_Ag] TO [bodbDownlineNetView]
GO
GRANT VIEW DEFINITION ON [dbo].[Age_BetList_SelRunningByBettype_Ag] TO vnteam
