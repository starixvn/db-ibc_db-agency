ALTER PROCEDURE [dbo].[Age_BetList_SelAllByDate_SAg]
	@custid int,
	@SAgID int,
	@FromDate datetime,
	@ToDate datetime,
	@Language varchar(2) = 'E'	
AS
SET NOCOUNT ON

/*
Created: 
Task : Betlist
DB: DB05.bodb02
Original:agentsite\customer\betlist.asp
Revisions:
    - 20060222: remove refno
    - 20060222: remove odds depend
    - 20071211@Phuc: calling from API
    - 20090326@Phuc: get indexname for FI
*/

Declare @roleid int
select @roleid = roleid  from custinfo with (nolock) where custid = @custid
if @roleid = 3
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
		b.spositiontaking,
		b.mpositiontaking, 
		b.apositiontaking,	
		b.discount as adiscount,
		b.adiscount as mdiscount,
		b.sdiscount as sdiscount,	
		b.liveindicator, 
		b.livehomescore, 
		b.liveawayscore, 
		case when b.currency = 4 then '' else b.ip end as IP, --Hide IP for TB currency
		m.betstatus,
		isnull(m.isNeutral, CONVERT(BIT,0)) as IsNeutral
	from 
		bettrans b with (nolock)	
		INNER JOIN match m with (nolock) ON b.matchid=m.matchid 
		INNER JOIN customer c with (nolock) ON b.custid=c.custid 	
	where
		b.mrecommend = @CustID and
		b.srecommend=@SAgID and b.status='running'
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
		'' as indexname,
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
		b.spositiontaking, 
		b.mpositiontaking, 
		b.apositiontaking,
		b.discount as adiscount,
		b.adiscount as mdiscount,
		b.sdiscount as sdiscount,
		b.liveindicator, 
		b.livehomescore, 
		b.liveawayscore, 
		case when b.currency = 4 then '' else b.ip end as IP, 
		'' as betstatus,
		CONVERT(BIT,0) as IsNeutral
	from 
		bettrans b with (nolock)
		INNER JOIN outright m with (nolock) ON b.matchid=m.orid
		INNER JOIN customer c with (nolock) ON b.custid=c.custid 		
	where
		b.mrecommend = @CustID and
		b.srecommend=@SAgID and b.status='running'
		and b.transdate>=@FromDate and b.transdate<=@ToDate
	order by 
		b.transid
END
else if @roleid = 2
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
		b.spositiontaking,
		b.mpositiontaking, 
		b.apositiontaking,
		b.discount as adiscount,
		b.adiscount as mdiscount,
		b.sdiscount as sdiscount,		
		b.liveindicator, 
		b.livehomescore, 
		b.liveawayscore, 
		case when b.currency = 4 then '' else b.ip end as IP,--Hide IP for TB currency 
		m.betstatus,
		isnull(m.isNeutral, CONVERT(BIT,0)) as IsNeutral
	from 
		bettrans b with (nolock)	
		INNER JOIN match m with (nolock) ON b.matchid=m.matchid 
		INNER JOIN customer c with (nolock) ON b.custid=c.custid 			
	where
		b.recommend = @CustID and
		b.srecommend=@SAgID and b.status='running'
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
		'' as indexname,
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
		b.spositiontaking, 
		b.mpositiontaking, 
		b.apositiontaking,
		b.discount as adiscount,
		b.adiscount as mdiscount,
		b.sdiscount as sdiscount,
		b.liveindicator, 
		b.livehomescore, 
		b.liveawayscore, 
		case when b.currency = 4 then '' else b.ip end as IP, --Hide IP for TB currency
		'' as betstatus,
		CONVERT(BIT,0) as IsNeutral
	from 
		bettrans b with (nolock)
		INNER JOIN outright m with (nolock) ON b.matchid=m.orid
		INNER JOIN customer c with (nolock) ON b.custid=c.custid 		
	where
		b.recommend = @CustID and
		b.srecommend=@SAgID and b.status='running'
		and b.transdate>=@FromDate and b.transdate<=@ToDate
	order by 
		b.transid
END
else if @roleid = 1
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
		b.spositiontaking,
		b.mpositiontaking, 
		b.apositiontaking,
		b.discount as adiscount,
		b.adiscount as mdiscount,
		b.sdiscount as sdiscount,		
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
		b.srecommend=@SAgID and b.status='running'
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
		'' as indexname,
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
		b.spositiontaking, 
		b.mpositiontaking, 
		b.apositiontaking,
		b.discount as adiscount,
		b.adiscount as mdiscount,
		b.sdiscount as sdiscount,
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
		b.srecommend=@SAgID and b.status='running'
		and b.transdate>=@FromDate and b.transdate<=@ToDate
	order by 
		b.transid
END

GO
GRANT EXECUTE ON [dbo].[Age_BetList_SelAllByDate_SAg] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_BetList_SelAllByDate_SAg] TO [bodbDownlineNetView]
GO
GRANT VIEW DEFINITION ON [dbo].[Age_BetList_SelAllByDate_SAg] TO vnteam
