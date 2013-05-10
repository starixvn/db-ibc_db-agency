ALTER PROCEDURE [dbo].[Age_BetList_SelAllByDate_MAg]
	@custid int,
	@MAgID int,
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
    - 20090326@Phuc: get indexname for FI
*/


if exists (select 1 from customer with (nolock) where custid = @custid and roleid = 2)
BEGIN
	select
		c.username,
		m.sporttype,
		b.bettype,
		m.leagueID,
		convert(nvarchar(20),b.transid) AS refno, 		
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
		b.mpositiontaking, 
		b.apositiontaking,	
		b.adiscount as mdiscount,
		b.discount as adiscount,	
		b.liveindicator, 
		b.livehomescore, 
		b.liveawayscore, 
		case when b.currency = 4 then '' else b.ip end as IP, 
		m.betstatus,
		isnull(m.isNeutral, CONVERT(BIT,0)) as IsNeutral
		
	from 
		bettrans b with (nolock)
		INNER JOIN match m with (nolock) ON b.matchid=m.matchid 
		INNER JOIN customer c with (nolock) ON b.custid=c.custid 			
	where
		b.recommend = @CustID and
		b.mrecommend=@MAgID  and b.status='running'
		and b.transdate>=@FromDate and b.transdate<=@ToDate
	UNION ALL
	select
		c.username,	
		0 as sporttype,
		b.bettype,		
		m.leagueID,
		convert(nvarchar(20),b.transid) AS refno, 		
		b.transid, 
		m.matchcode, 
		m.matchcode as indexname,
		m.teamID as homeID,
		0 as awayID,
		convert(float, b.hdp1) as hdp1, 
		convert(float, b.hdp2) as hdp2, 
		b.odds,
		b.status, 
		b.stake, 
		b.transdate, 
		dbo.f_GetChoice(b.betteam, b.bettype,@Language) betteam,
		b.comstatus, 
		b.mpositiontaking, 
		b.apositiontaking,
		b.adiscount as mdiscount,
		b.discount as adiscount,
		b.liveindicator, 
		b.livehomescore, 
		b.liveawayscore, 
		case when b.currency = 4 then '' else b.ip end as IP,--Hide IP for TB currency 
		'' as betstatus,
		CONVERT(BIT,0) as IsNeutral
	
	from 
		bettrans b with (nolock)
		INNER JOIN outright m with (nolock) ON b.matchid=m.orid
		INNER JOIN customer c with (nolock) ON b.custid=c.custid 		
	where
		b.recommend = @CustID and
		b.mrecommend=@MAgID and b.status='running'
		and b.transdate>=@FromDate and b.transdate<=@ToDate
	order by 
		b.transid
END
else
BEGIN
	select 
		c.username,
		m.sporttype,
		b.bettype,
		m.leagueID,
		convert(nvarchar(20),b.transid) AS refno, 		
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
		b.mpositiontaking, 
		b.apositiontaking,	
		b.adiscount as mdiscount,
		b.discount as adiscount,	
		b.liveindicator, 
		b.livehomescore, 
		b.liveawayscore, 
		case when b.currency = 4 then '' else b.ip end as IP, 
		m.betstatus,
		isnull(m.isNeutral, CONVERT(BIT,0)) as IsNeutral
		
	from 
		bettrans b with (nolock)	
		INNER JOIN match m with (nolock) ON b.matchid=m.matchid 
		INNER JOIN customer c with (nolock) ON b.custid=c.custid 			
	where
		b.custid = @CustID and
		b.mrecommend=@MAgID and b.status='running'
		and b.transdate>=@FromDate and b.transdate<=@ToDate
	UNION ALL
	select 
		c.username,	
		0 as sporttype,
		b.bettype,		
		m.leagueID,
		convert(nvarchar(20),b.transid) AS refno, 		
		b.transid, 
		m.matchcode,
		m.matchcode as indexname, 
		m.teamID as homeID,
		0 as awayID,
		convert(float, b.hdp1) as hdp1, 
		convert(float, b.hdp2) as hdp2, 
		b.odds,
		b.status, 
		b.stake, 
		b.transdate, 
		dbo.f_GetChoice(b.betteam, b.bettype,@Language) betteam,
		b.comstatus, 
		b.mpositiontaking, 
		b.apositiontaking,
		b.adiscount as mdiscount,
		b.discount as adiscount,	
		b.liveindicator, 
		b.livehomescore, 
		b.liveawayscore, 
		case when b.currency = 4 then '' else b.ip end as IP,--Hide IP for TB currency 
		'' as betstatus,
		CONVERT(BIT,0) as IsNeutral
		
	from 
		bettrans b with (nolock)
		INNER JOIN outright m with (nolock) ON b.matchid=m.orid
		INNER JOIN customer c with (nolock) ON b.custid=c.custid 		
	where
		b.custid = @CustID and
		b.mrecommend=@MAgID and b.status='running'
		and b.transdate>=@FromDate and b.transdate<=@ToDate
	order by 
		b.transid
END

GO

GRANT EXECUTE ON [dbo].[Age_BetList_SelAllByDate_MAg] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_BetList_SelAllByDate_MAg] TO [bodbDownlineNetView]
GO
GRANT VIEW DEFINITION ON [dbo].[Age_BetList_SelAllByDate_MAg] TO vnteam
