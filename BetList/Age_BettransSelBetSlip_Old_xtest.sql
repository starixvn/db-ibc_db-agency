 ALTER PROCEDURE [dbo].[Age_BettransSelBetSlip_Old]
	@transid bigint,
	@Language varchar(2) = 'E'
AS
/*
Created: 20080104@[creator]
Task : 
DB: DBARC/bodb_archive
Original: BetTransSelBetSlip

Revisions:
    - 20080104@[Vinh]: --Change @refno to @transid
					   --add select from bettrans14 --> fix return no data
	- 20080709@[Viet]: Combine data from Archive DB, Remove Teamname	
	- 20090407@[HanhVu]: remove redundant transid field	
	- 20090416@Minh: remove indexName
	- 20090710@Phuc: unhide IP for TB currency.
	- 20090930@Phuc: Show the refunded tickets' status based on bettrans.status.
	- 20100206@Kiwi: compute winlost amount (winlost - actual_stake).
	- 20110408@Amy: Change function to get Odds value and showed odds type
	- 20111216@Sophia: Remove function f_GetOddsByBettype , f_GetChoice , f_ShowOddsByBettype	
	- 20130225@Elodie: Add bet list of Virtual Horse Racing
*/

SET NOCOUNT ON
DECLARE @Bettype INT
SELECT @Bettype = bettype FROM bodb_Archive.dbo.bettrans_bk WITH (NOLOCK) WHERE transid = @transid
IF @Bettype IN (1231,1232,1233,1237,1238)
	select 
		c.username,
		b.bettype,
		b.transid,
		o.RacerNum as matchcode,
		b.matchid,
		o.RacerID as homeID,
		0 as awayID,		
		b.hdp1,
		b.hdp2,
		b.betid,
		0 as OddsType, 
		b.odds, 	
		b.winlostdate,
		b.status,
		b.stake,
		b.transdate,
		'' as betteam,
		b.livehomescore,
		b.liveawayscore,
		0 as finalhomescore, 
		0 as finalawayscore,
		0 as hthomescore, 
		0 as htawayscore, 
		(b.winlost-actual_stake) as winlost,
		0 as liveindicator, 
		IP as IP,
		CONVERT(BIT,0) as IsNeutral
	from 	
		bodb_Archive.dbo.bettrans_bk b with (nolock)
		INNER JOIN bodb_Archive.dbo.VSOutright_bk o with (NOLOCK) ON b.oddsid=o.Orid
		INNER JOIN bodb02.dbo.VSRaceInfo r WITH (NOLOCK) ON r.EventID = o.EventID
		INNER JOIN bodb02.dbo.custinfo c with (nolock) ON b.custid=c.custid 
	where
		b.transid= @transid
ELSE
	select 
		c.username,
		b.bettype,
		b.transid,
		m.matchcode, 
		m.matchid, 
		m.homeID,
		m.awayID,		
		b.hdp1,
		b.hdp2,
		b.betid,
		b.OddsType, 
		b.odds, 	
		b.winlostdate,
		b.status as Status,
		b.stake,
		b.transdate,
		b.betteam,
		b.livehomescore,
		b.liveawayscore,
		m.finalhomescore, 
		m.finalawayscore,
		m.hthomescore, 
		m.htawayscore, 
		(b.winlost-actual_stake) as winlost,
		b.liveindicator, 
		IP as IP,
		isnull(m.isNeutral, CONVERT(BIT,0)) as IsNeutral
	from 	
		bodb_Archive.dbo.bettrans_bk b with (nolock)
		INNER JOIN bodb02.dbo.custinfo c with (nolock) ON b.custid=c.custid 
		LEFT OUTER JOIN bodb_Archive.dbo.match_bk m with (nolock) ON b.matchid=m.matchid	
	where
		b.transid= @transid
		
GO
GRANT EXECUTE ON [dbo].[Age_BettransSelBetSlip_Old] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_BettransSelBetSlip_Old] TO [bodbDownlineNetView]
GO
GRANT VIEW DEFINITION ON [dbo].[Age_BettransSelBetSlip_Old] TO [VNTeam]