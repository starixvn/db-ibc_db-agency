USE bodb02
GO

ALTER PROCEDURE [dbo].[Age_BetList_SelWinlossByBettypeMatch_MAg]
	@matchid int,
	@custid int=null, --masterID
	@bettype int,
	@Language varchar(2) = 'E',
	@username varchar(50) = NULL, -- for API	
	@liveindicator int = 0
AS
/*
Created: 
Task : Betlist
DB: DBAGE.bodb02
Original:BetsSelBetListMatchWinLoss_MAg
Revisions:
    - 20071211@Phuc: For API
    - 20080108: add leaguename,typenamee2,sportname
    - 20080407@Phuc: Add matchid
    - 20080629@Viet: Remove Teamname, Leaguename, Sportname, TypeName
    - 20090326@Phuc: get indexname for FI
    - 20090406@HanhVu: remove refno
    - 20090416@Minh: remove indexName
    - 20090421@[HiepVo]: Include more columns: comm, acomm, scomm, awinlost, mwinlost, swinlost
    - 20090505@HiepVo: Change formula of commission
    - 20090618@AnhPham: Remove 'Customer' table
	- 20090710@Phuc: unhide IP for TB currency.
	- 20101123@Jacob: Add column betid in select clause
	- 20110408@Amy: Change function to get Odds value and showed odds type
	- 20110809@Sophia: Add a new parametter @liveindicator
	- 20110811@Sophia: Add new columns actual_stake and modds 
	- 20111216@Sophia: Remove function f_GetOddsByBettype , f_GetChoice , f_ShowOddsByBettype
	- 20120112@Sophia:  Add refno, showtime for Table - Shoe - Hand of LiveCasino 
						Add Sub table for Live Casino
	- 20120927@Sophia: Get comstatus]
	- 20141016@Sophia: support Sporting solution-grouped bettype 
	- 20150209@Tom: Support 60 BetRadar (27218) Show betcheck coloum on Bettype 216,217 
	- 20150331@Cody: Apply sport bettype matrix [Remine: #30169]
*/

SET NOCOUNT ON
if @custid is null
	select @custid = custid from customer with (nolock) where username = @username

IF exists(SELECT TOP 1 1 FROM Match WITH(NOLOCK) WHERE MatchID=@MatchID)
BEGIN	
	SELECT
		m.sporttype,
		b.username,
		b.bettype,
		m.leagueID,		
		b.transid,
		m.matchcode,
		m.homeID,
		m.awayID,
		convert(float, b.hdp1) as hdp1, 
		convert(float, b.hdp2) as hdp2, 
		b.odds,
		b.modds,
		b.status,
		b.stake,
		b.actual_stake,
		(b.winlost-actual_stake) winlost,
		b.awinlost,
		b.mwinlost,
		b.swinlost,
		
		b.playercomm,
		(b.comm - b.playercomm) as comm,
		(b.acomm - b.comm) as acomm ,
		(b.scomm - b.acomm) as scomm,
		
		b.transdate,
		b.winlostdate,
		b.betteam,
		b.apositiontaking,
		b.mpositiontaking,
		b.spositiontaking,	
		b.discount as Adiscount,
		b.adiscount as Mdiscount,
		b.sdiscount as Sdiscount,	
		b.liveindicator,
		b.livehomescore,
		b.liveawayscore,
		b.matchid, 
		b.IP as IP,
		m.betstatus,
		isnull(m.isNeutral, CONVERT(BIT,0)) as IsNeutral,
		b.OddsType,
		b.betid,
		m.showtime,
		b.refno,
		b.betcheck,
		CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END AS comstatus
	FROM
		bettrans b with (nolock) 
		inner join match m with (nolock) on b.matchid=m.matchid 
		LEFT JOIN (SELECT Bettype, GroupTypeId FROM [dbo].[f_GroupBettype_xtest]()) f ON f.bettype = b.bettype
	WHERE
		b.matchid=@matchid and 
		b.mrecommend=@custid  and 		
		(b.bettype=@bettype OR GroupTypeId = @bettype) and
		b.Liveindicator = CASE WHEN m.sporttype = 161 THEN @liveindicator ELSE b.liveindicator END 
	ORDER BY
		b.status, b.transid
		
	--IF @bettype between 1101 and 1199
	IF EXISTS(SELECT TOP 1 1 FROM SportBettypeMatrix WITH(NOLOCK) WHERE ProductID = 4 AND bettype = @bettype)
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
		FROM bettransg bg with (NOLOCK)
		INNER JOIN bettrans B ON bg.refno = B.refno
		WHERE	bg.matchid=@matchid and 
				b.mrecommend=@custid  and 		
				b.bettype=@bettype 
	END
END
ELSE
BEGIN	
	SELECT
		m.sporttype,
		b.username,
		b.bettype,
		m.leagueID,			
		b.transid,
		m.matchcode,
		m.homeID,
		m.awayID,
		convert(float, b.hdp1) as hdp1, 
		convert(float, b.hdp2) as hdp2, 
		b.odds,
		b.modds,
		b.status,
		b.stake,
		b.actual_stake,
		(b.winlost-actual_stake) winlost,
		b.awinlost,
		b.mwinlost,
		b.swinlost,
		
		b.playercomm,
		(b.comm - b.playercomm) as comm,
		(b.acomm - b.comm) as acomm ,
		(b.scomm - b.acomm) as scomm,
		
		b.transdate,
		b.winlostdate,
		b.betteam,
		b.apositiontaking,
		b.mpositiontaking,
		b.spositiontaking,	
		b.discount as Adiscount,
		b.adiscount as Mdiscount,
		b.sdiscount as Sdiscount,		
		b.liveindicator,
		b.livehomescore,
		b.liveawayscore,
		b.matchid, 
		b.IP as IP,
		m.betstatus,
		isnull(m.isNeutral, CONVERT(BIT,0)) as IsNeutral,
		b.OddsType,
		b.betid,
		m.showtime,
		b.refno,
		b.betcheck,
		CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END AS comstatus
	FROM
		bettrans14 b with (nolock) 
		inner join match14 m with (nolock) on b.matchid=m.matchid 		
		LEFT JOIN (SELECT Bettype, GroupTypeId FROM [dbo].[f_GroupBettype_xtest]()) f ON f.bettype = b.bettype
	WHERE
		b.matchid=@matchid and 
		b.mrecommend=@custid  and 		
		(b.bettype=@bettype OR GroupTypeId = @bettype) and
		b.Liveindicator = CASE WHEN m.sporttype = 161 THEN @liveindicator ELSE b.liveindicator END 
	ORDER BY
		b.status, b.transid		
		
	--IF @bettype between 1101 and 1199
	IF EXISTS(SELECT TOP 1 1 FROM SportBettypeMatrix WITH(NOLOCK) WHERE ProductID = 4 AND bettype = @bettype)
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
		FROM bettransg14 bg with (NOLOCK)
		INNER JOIN bettrans14 B ON bg.refno = B.refno
		WHERE	bg.matchid=@matchid and 
				b.mrecommend=@custid  and 		
				b.bettype=@bettype 
	END
END



GO
GRANT EXECUTE ON [dbo].[Age_BetList_SelWinlossByBettypeMatch_MAg] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_BetList_SelWinlossByBettypeMatch_MAg] TO [bodbDownlineNetView]
GO
GRANT VIEW DEFINITION ON [dbo].[Age_BetList_SelWinlossByBettypeMatch_MAg] TO vnteam