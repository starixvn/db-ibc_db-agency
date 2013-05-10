ALTER PROCEDURE [dbo].[Age_BettransSelBetSlip]
	@transid bigint,
	@Language varchar(2) = 'E'
AS
SET NOCOUNT ON
/*
Created: 
Task : Betlist
DB: DB06.bodb02
Original:BetTransSelBetSlip
Revisions:    
    - 20080104@Vinh:Change @refno to @transid
	- 20090104@Vinh:add select from bettrans14 --> fix return no data	
	- 20080709@Viet: Combine data from Archive DB, Remove Teamname
	- 20090710@Phuc: unhide IP for TB currency.
	- 20111229@Jim: remove function :f_GetOddsByBettype,f_ShowOddsByBettype,f_GetChoice
*/

IF exists(select 1 from bettrans where transid = @transid)	
BEGIN
	select 
		c.username,
		b.bettype,
		b.transid,
		m.matchcode, 
		m.homeID,
		m.awayID,		
		b.hdp1,
		b.hdp2,
		b.OddsType,
		--case dbo.f_ShowOddsByBettype(b.bettype,1) when 1 then b.OddsType else 0 end as OddsType, 
		b.odds,
		--dbo.f_GetOddsByBettype(b.odds,b.bettype,b.oddstype) as odds, 	
		b.transid as refno, 
		b.winlostdate,
		b.status,
		b.stake,
		b.transdate,
		b.betteam,
	--	dbo.f_GetChoice(b.betteam, b.bettype,@Language) betteam,
		b.livehomescore,
		b.liveawayscore,
		m.finalhomescore, 
		m.finalawayscore,
		m.hthomescore, 
		m.htawayscore, 
		b.winlost,
		b.liveindicator, 
		b.IP as IP,
		isnull(m.isNeutral, CONVERT(BIT,0)) as IsNeutral 
	from 	
		bettrans b with (nolock)
		INNER JOIN customer c with (nolock) ON b.custid=c.custid 
		LEFT OUTER JOIN match m with (nolock) ON b.matchid=m.matchid		
	where
		b.transid= @transid
	RETURN
END
IF exists(select 1 from bettrans14 where transid = @transid)	
BEGIN
	select 
		c.username,
		b.bettype,
		b.transid,
		m.matchcode, 
		m.homeID,
		m.awayID,		
		b.hdp1,
		b.hdp2,
		b.OddsType,
		--case dbo.f_ShowOddsByBettype(b.bettype,1) when 1 then b.OddsType else 0 end as OddsType, 
		b.odds,
		--dbo.f_GetOddsByBettype(b.odds,b.bettype,b.oddstype) as odds, 	
		b.transid as refno, 
		b.winlostdate,
		b.status,
		b.stake,
		b.transdate,
		b.betteam,
		--dbo.f_GetChoice(b.betteam, b.bettype,@Language) betteam,
		b.livehomescore,
		b.liveawayscore,
		m.finalhomescore, 
		m.finalawayscore,
		m.hthomescore, 
		m.htawayscore, 
		b.winlost,
		b.liveindicator, 
		b.IP as IP,
		isnull(m.isNeutral, CONVERT(BIT,0)) as IsNeutral 
	from 	
		bettrans14 b with (nolock)
		INNER JOIN customer c with (nolock) ON b.custid=c.custid 	
		LEFT OUTER JOIN match14 m with (nolock) ON b.matchid=m.matchid		
	where
		b.transid= @transid
	RETURN
END
-- else.. get data from db Archive
select 
	c.username,
	b.bettype,
	b.transid,
	m.matchcode, 
	m.homeID,
	m.awayID,		
	b.hdp1,
	b.hdp2,
	b.OddsType,
	--case dbo.f_ShowOddsByBettype(b.bettype,1) when 1 then b.OddsType else 0 end as OddsType, 
	b.odds,
	--dbo.f_GetOddsByBettype(b.odds,b.bettype,b.oddstype) as odds, 	
	b.transid as refno, 
	b.winlostdate,
	b.status,
	b.stake,
	b.transdate,
	b.betteam,
	--dbo.f_GetChoice(b.betteam, b.bettype,@Language) betteam,
	b.livehomescore,
	b.liveawayscore,
	m.finalhomescore, 
	m.finalawayscore,
	m.hthomescore, 
	m.htawayscore, 
	b.winlost,
	b.liveindicator, 
	b.IP as IP,
	isnull(m.isNeutral, CONVERT(BIT,0)) as IsNeutral 
from 	
	bodb_Archive.dbo.bettrans_bk b with (nolock)
	INNER JOIN customer c with (nolock) ON b.custid=c.custid 
	LEFT OUTER JOIN bodb_Archive.dbo.match_bk m with (nolock) ON b.matchid=m.matchid	
where
	b.transid= @transid



GO
GRANT EXECUTE ON [dbo].[Age_BettransSelBetSlip] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_BettransSelBetSlip] TO [bodbDownlineNetView]