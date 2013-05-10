ALTER PROCEDURE [dbo].[Age_BetList_SelAllByDate_Ag]
	@custid int=null,
	@AgID int,
	@FromDate datetime,
	@ToDate datetime,
	@Language varchar(2) = 'E'
AS
SET NOCOUNT ON

/*
Created: 
Task : Betlist
DB: DB05.bodb02
Original:BetsSelBetListEnglishAgent2
Revisions:
    - 20060222: remove refno
    - 20060222: remove odds depend
    - 20071211@Phuc: calling from API
    - 20080704@Viet: Remove Teamname, Leaguename, Sportname, TypeName
    - 20081218@Nqminh: March->IsNeutral field
    - 20090326@Phuc: get indexname for FI
    - 20090401@Nqminh: Add MixParlay tickets
*/

select 
	c.username,
	m.sporttype,
	m.leagueID,	
	convert(nvarchar(20),b.transid) AS refno,
	b.bettype,
	b.transid,
	m.matchcode,
	m.matchcode as indexname,
	m.homeID,
	m.awayID,
	convert(float, b.hdp1) as hdp1, 
	convert(float, b.hdp2) as hdp2, 
	b.odds,
	b.status, 	
	b.stake,
	b.transdate,
	dbo.f_GetChoice(b.betteam, b.bettype,@Language) betteam,
	b.comstatus,
	b.apositiontaking,	
	b.discount as adiscount,
	b.liveindicator, 
	b.livehomescore, 
	b.liveawayscore, 
	case when b.currency = 4 then '' else b.IP end as IP, --Hide IP for TB currency
	m.betstatus,
	isnull(m.isNeutral, CONVERT(BIT,0)) as IsNeutral
from 
	bettrans b with (nolock)
	INNER JOIN match m with (nolock) ON b.matchid=m.matchid 
	INNER JOIN customer c with (nolock) ON b.custid=c.custid 
	--left outer JOIN dbo.Match_Remark as mr with (nolock) on b.matchid = mr.matchid
where
	b.CustID = @CustID and
	b.recommend=@AgID
	and b.transdate>=@FromDate and b.transdate<=@ToDate

UNION ALL
select 
	c.username,
	0 as sporttype,
	m.leagueID,
	convert(nvarchar(20),b.transid) AS refno,
	b.bettype,
	b.transid,
	m.matchcode,
	m.matchcode as indexname,
	m.teamid as homeID,	
	0 as awayID,
	convert(float, b.hdp1) as hdp1, 
	convert(float, b.hdp2) as hdp2, 
	b.odds,
	b.status,
	b.stake,
	b.transdate,
	dbo.f_GetChoice(b.betteam, b.bettype,@Language) betteam,
	b.comstatus,
	b.apositiontaking,
	b.discount as adiscount,
	b.liveindicator, 
	b.livehomescore, 
	b.liveawayscore, 
	case when b.currency = 4 then '' else b.IP end as IP,--Hide IP for TB currency 
	'' as betstatus,
	CONVERT(BIT,0) as IsNeutral
	
from 
	bettrans b with (nolock)
	INNER JOIN outright m with (nolock) ON b.matchid=m.orid
	INNER JOIN customer c with (nolock) ON b.custid=c.custid 	
where
	b.CustID = @CustID and
	b.recommend=@AgID
	and b.transdate>=@FromDate and b.transdate<=@ToDate

--MixParlay 
UNION ALL
select 
	c.username,
	0 as sporttype,
	0 as leagueID,	
	convert(nvarchar(20),b.transid) AS refno,
	b.bettype,
	b.transid,
	'' as matchcode,
	'' as indexname,
	0 as homeID,
	0 as awayID,
	convert(float, b.hdp1) as hdp1, 
	convert(float, b.hdp2) as hdp2, 
	b.odds,
	b.status, 	
	b.stake,
	b.transdate,
	dbo.f_GetChoice(b.betteam, b.bettype,@Language) betteam,
	b.comstatus,
	b.apositiontaking,	
	b.discount as adiscount,
	b.liveindicator, 
	b.livehomescore, 
	b.liveawayscore, 
	case when b.currency = 4 then '' else b.IP end as IP, --Hide IP for TB currency
	'' as betstatus,
	CONVERT(BIT,0) as IsNeutral
from 
	bettrans b with (nolock)	
	INNER JOIN customer c with (nolock) ON b.custid=c.custid 
where	
	b.CustID = @CustID and
	b.recommend=@AgID
	and b.transdate>=@FromDate and b.transdate<=@ToDate
	and b.bettype=9
order by 
	b.transid

GO

GRANT EXECUTE ON [dbo].[Age_BetList_SelAllByDate_Ag] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_BetList_SelAllByDate_Ag] TO [bodbDownlineNetView]
GO
GRANT VIEW DEFINITION ON [dbo].[Age_BetList_SelAllByDate_Ag] TO [vnteam]
