ALTER PROCEDURE [dbo].[Age_BetList_SelByDayAll_Mem]
	@custid		int,
	@fromdate	smalldatetime,
	@transtype	int = 0, --VinhTrinh Add new parameter.
	@language	nvarchar(2) = 'en'
AS

/*
Created: 
Task : Bet List for Daily Statement
DB: DB053.bodb02
Original:Acc_BetListByDayAll_1
Revisions:
    - 20081030@QuangVinh: Add more result for Horseracing,TransType: 0: all bets, 1: bets settled, 2: void and cancelled, 3: running and waiting
    - 20090326@Phuc: get indexname for FI
    - 20090407@[HanhVu]:- get refno for Mix parlay	
						- remove INNER JOIN bettype table for Mix parlay
	- 20090414@[HanhVu]:- get more field betid for Casino						
	- 20090416@Minh: remove indexName
	- 20090421@[HiepVo]: Include more columns: comm, acomm, scomm, awinlost, mwinlost, swinlost
	- 20090505@HiepVo: Change formula of commission
	- 20090528@Hiep: get more result for Horse racing fix odds;Get more data from bettransm,bettransm14 for HR
	- 20090618@AnhPham: Remove 'Customer' table
	- 20090630@AnhPham: Remove 'creator' field from table variable and insert statement 
	- 20090710@Phuc: unhide IP for TB currency.
	- 20090930@Phuc: Show the refunded tickets' status based on bettrans.status.
	- 20091024@[MinhNguyen]: get modds, finalodds.
	- 20100318@Jamie: Remove input param @transid and enhance checking the group of bet tickets 
	- 20100610@Henry: Change to use StatusID instead of Status in WHERE statement
	- 20100611@Henry: Change mix-parlay match from 0 to 9
	- 20100902@Kiwi: Add IBCBet Bingo
	- 20101007@Henry: Change column transid from INT to BIGINT
	- 20110113@Jamie: Put index hint on bettransm & bettransm14 
	- 20110114@Thien: Put index hint on bettrans/bettrans14
	- 20110408@Amy: Change function to get Odds value and showed odds type
	- 20110512@Johnson: Apply new arrange bettype
	- 20110620@Johnson: change column commission to playercomm
	- 20110725@Lukas: Get refund tickets when transtype = 1
	- 20110825@Sophia: Edit betID not hard code bettype = 87, and show BetID for every bettype. If Deadball (liveindicator = 0) , web code will hide BetID.
	- 20110826@Sophia: Add Bettype = 29, add column Actual_stake, show Betteam for System Parlay
	- 20110826@Jamie: Get modds as winning odds for system parlay
	- 20110829@Sophia: Get BetID for Parlay
	- 20111122@Sophia: Add Checktime and SecAcceptFlag to show status waiting or running
	- 20111216@Sophia: Remove function f_GetOddsByBettype , f_GetChoice , f_ShowOddsByBettype
	- 20120112@Sophia: Add showtime for Table - Shoe - Hand of LiveCasino
					   Add Sub table for Live Casino
	- 20120405@Hurri:	+ Exclude bettype 72 and 23101 in the calculation of Casino
						+ Get more data of P2P (bettype: 1000, 23102)
	- 20120309@Sophia: Not to use Checktime and SecAcceptFlag showing waiting or running status for Casino, Bingo, P2P, Outright, Mix parlay 
	- 20120410@Hurri: change matchid 0 -> 1000 for bettype 1000
	- 20120426@Lukas: show transid of mainticket for all sub-tickets of system parlay
	- 20120502@Johnson: Get session id(betcheck) for bets list P2P
	- 20120626@Elodie: exclude outright, HR from sportbook ( in case of matchid = orid)
	- 20120927@Sophia: Get comstatus
	- 20130225@Elodie: Add bet list of Virtual Horse Racing
	- 20130401@Lukas: fix bugs - wrong selected table
	- 20130705@Kathy: Update matchid for RnG Casino (71) and Bingo (73)
Param's Explanation: 
	+ @transtype: 1-Betting Statement; 2-VOID/Cancelled Bet; 3-Outstanding Bet 
*/

SET NOCOUNT ON

DECLARE @IsBet14 bit
/*
WON: 112   LOSE: 113   DRAW: 111
VOID: 102	REJECT: 101
RUNNING: 0  WAITING: 1
*/

DECLARE	@tmpStatus TABLE ([statusID] tinyint)
IF(@transtype = 1) 
BEGIN
	INSERT INTO @tmpStatus([statusID])
	SELECT 111 UNION ALL SELECT 112 UNION ALL SELECT 113 UNION ALL SELECT 103
END
ELSE IF(@transtype = 2)
BEGIN
	INSERT INTO @tmpStatus([statusID])
	SELECT 101 UNION ALL SELECT 102
END 
ELSE IF(@transtype = 3)
BEGIN
	INSERT INTO @tmpStatus([statusID])
	SELECT 0 UNION ALL SELECT 1
END

Declare @Data TABLE (
	sporttype int, 
	leagueid int, 
	homeid int, 
	awayid int, 
	bettype smallint,	
	matchcode nvarchar(50),
	race nvarchar(20),
	matchid int, 
	transid bigint, 
	transdate datetime, 
	winlostdate datetime,
	refno nvarchar(50), 
	betid bigint,
	oddsid int, 	
	hdp1 smallmoney, 
	hdp2 smallmoney, 
	Modds smallmoney,
	oddstype tinyint,
	odds smallmoney, 
	betteam nvarchar(10), 
	status nvarchar(50), 
	betstatus nvarchar(50), 
	stake money, 
	actual_stake money,
	winlost money,
	awinlost money,
	mwinlost money,
	swinlost money,
	 
	playercomm money,
	comm money,
	acomm money,
	scomm money,
	
	livehomescore smallint, 
	liveawayscore smallint, 
	liveindicator bit,
	finalhomescore smallint, 
	finalawayscore smallint, 
	hthomescore smallint, 
	htawayscore smallint, 
	--creator varchar(50), 
	ip nvarchar(15), 
	username nvarchar(30),
	isNeutral bit,
	showtime NVARCHAR(50),
	betcheck nvarchar(50),
	comstatus nvarchar(20)
)

IF EXISTS (SELECT TOP 1 1 FROM match14 (nolock) WHERE eventdate = @fromdate)
	Select @IsBet14 = 1
ELSE 
	Select @IsBet14 = 0

IF @IsBet14 = 1
BEGIN
	-- single bet
	INSERT INTO @Data SELECT
		m.sporttype, 
		m.leagueid,
		m.homeID,
		m.awayID,
		b.bettype,
		m.matchcode,
		'' as race,
		m.matchid, 
		b.transid, 
		b.transdate, 
		b.winlostdate,
		b.refno, 
		--case when b.bettype = 87 then b.betid else 0 end, --- 87- High Low for NG: Current Live Ball 
		b.betid,
		b.oddsid, 
		b.hdp1, 
		b.hdp2,
		modds, 
		b.oddstype as OddsType, 
		b.odds, 	
		b.betteam,
		b.status as status,
		m.betstatus, 
		b.stake, 
		b.actual_stake,
		(b.winlost-b.actual_stake) as winlost, 
		b.awinlost,
		b.mwinlost,
		b.swinlost,
		
		b.playercomm,
		(b.comm - b.playercomm) as comm,
		(b.acomm - b.comm) as acomm ,
		(b.scomm - b.acomm) as scomm,
		
		b.livehomescore, 
		b.liveawayscore, 
		b.liveindicator, 
		m.finalhomescore, 
		m.finalawayscore,
		m.hthomescore, 
		m.htawayscore,
		--b.username, 
		b.IP as IP,
		b.Username,
		isnull(m.isNeutral, CONVERT(BIT,0)) as IsNeutral,
		m.showtime,
		'' as betcheck,
		CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END AS comstatus
	from 
		dbo.bettrans14 b with (nolock, index=IX_bettrans14)
		INNER JOIN dbo.match14 m with (nolock) ON b.matchid = m.matchid		
	where
		b.custid=@custid 		
		AND b.winlostdate=@fromdate AND b.bettype<= 19000 
		and b.bettype not in (10,31,32,33,41,42,43,1231,1232,1233,1237,1238) --20120626@Elodie: exclude outright, HR from sportbook
		AND b.statusID IN (SELECT [statusID] FROM @tmpStatus)

	-- Virtual HR
	INSERT INTO @Data 
	SELECT
		r.sporttype, 
		r.leagueid,
		o.RacerID as HomeID,
		0 as AwayID, 
		b.bettype,
		o.RacerNum as Matchcode, 
		b.oddsid as Race,
		b.matchid, 
		b.transid, 
		b.transdate, 
		b.winlostdate,
		b.refno, 
		b.betid,
		b.oddsid, 
		b.hdp1, 
		b.hdp2,
		modds, 
		0 as OddsType, 
		b.odds, 	
		'' as betteam,
		b.status as status,
		'' as betstatus, 
		b.stake, 
		b.actual_stake,
		(b.winlost-b.actual_stake) as winlost, 
		b.awinlost,
		b.mwinlost,
		b.swinlost,
		
		b.playercomm,
		(b.comm - b.playercomm) as comm,
		(b.acomm - b.comm) as acomm ,
		(b.scomm - b.acomm) as scomm,
		
		b.livehomescore, 
		b.liveawayscore, 
		0 as liveindicator, 
		0 as finalhomescore, 
		0 as finalawayscore,
		0 as hthomescore, 
		0 as htawayscore,
		b.IP as IP,
		b.Username,
		CONVERT(BIT,0) as IsNeutral,
		r.eventTime as showtime,
		'' as betcheck,
		CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END AS comstatus
	from 
		dbo.bettrans14 b with (nolock, index=IX_bettrans14)
		INNER JOIN VSOutright14 o with (NOLOCK) ON b.oddsid=o.Orid
		INNER JOIN VSRaceInfo r WITH (NOLOCK) ON r.EventID = o.EventID
	where
		b.custid=@custid 		
		AND b.winlostdate=@fromdate AND b.bettype in (1231, 1232, 1233, 1237, 1238)
		AND b.statusID IN (SELECT [statusID] FROM @tmpStatus)
		
	-- CASINO
	INSERT INTO @Data 
	SELECT
		251, --m.sporttype, 
		0, --m.leagueid,
		0, --m.homeID,
		0, --m.awayID,
		b.bettype,
		'', --m.matchcode,
		'' as race,
		0, --m.matchid, 
		b.betid, 
		b.transdate, 
		b.winlostdate,
		b.refno, 
		isnull(b.betID,0),
		b.oddsid, 
		b.hdp1, 
		b.hdp2,
		0 as modds,
		0 as OddsType, 
		b.odds, 
	    b.betteam, 
		b.status, 
		b.actual_stake,
		'', --m.betstatus, 
		b.stake, 
		(b.winlost-b.actual_stake) as winlost, 
		b.awinlost,
		b.mwinlost,
		b.swinlost,
		
		b.playercomm,
		(b.comm - b.playercomm) as comm,
		(b.acomm - b.comm) as acomm ,
		(b.scomm - b.acomm) as scomm,
		
		b.livehomescore, 
		b.liveawayscore, 
		b.liveindicator, 
		0, --m.finalhomescore, 
		0, --m.finalawayscore,
		0, --m.hthomescore, 
		0, --m.htawayscore,
		--b.username, 
		b.IP as IP,
		b.Username,
		0 as IsNeutral,
		'' as showtime,
		'' as betcheck,
		CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END AS comstatus
	from 
		dbo.bettrans14 b with (nolock, index=IX_bettrans14)		
	where
		b.custid=@custid 		
		AND b.winlostdate=@fromdate 
		AND b.bettype in (71,23002)	--20120405@Hurri
		AND b.matchID in (0, 71)
		AND b.statusID IN (SELECT [statusID] FROM @tmpStatus)
		
		-- P2P -- 20120405@Hurri
	INSERT INTO @Data 
	SELECT
		253, --m.sporttype, 
		0, --m.leagueid,
		0, --m.homeID,
		0, --m.awayID,
		b.bettype,
		'', --m.matchcode,
		'' as race,
		0, --m.matchid, 
		b.transid, 
		b.transdate, 
		b.winlostdate,
		b.refno, 
		isnull(b.betID,0),
		b.oddsid, 
		b.hdp1, 
		b.hdp2,
		0 as modds,
		0 as OddsType, 
		b.odds, 
	    b.betteam, 
		b.status, 
		b.actual_stake,
		'', --m.betstatus, 
		b.stake, 
		(b.winlost-b.actual_stake) as winlost, 
		b.awinlost,
		b.mwinlost,
		b.swinlost,
		
		b.playercomm,
		(b.comm - b.playercomm) as comm,
		(b.acomm - b.comm) as acomm ,
		(b.scomm - b.acomm) as scomm,
		
		b.livehomescore, 
		b.liveawayscore, 
		b.liveindicator, 
		0, --m.finalhomescore, 
		0, --m.finalawayscore,
		0, --m.hthomescore, 
		0, --m.htawayscore,
		--b.username, 
		b.IP as IP,
		b.Username,
		0 as IsNeutral,
		'' as showtime,
		b.betcheck as sessionID,
		CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END AS comstatus
	from 
		dbo.bettrans14 b with (nolock, index=IX_bettrans14)		
	where
		b.custid=@custid 		
		AND b.winlostdate=@fromdate 
		AND b.bettype in (1000,23102)	
		AND b.matchID in(0, 1000)
		AND b.statusID IN (SELECT [statusID] FROM @tmpStatus)

	-- IBCBET Bingo
	INSERT INTO @Data 
	SELECT
		252, --m.sporttype, 
		0, --m.leagueid,
		0, --m.homeID,
		0, --m.awayID,
		b.bettype,
		'', --m.matchcode,
		'' as race,
		0, --m.matchid, 
		b.betid, 
		b.transdate, 
		b.winlostdate,
		b.refno, 
		isnull(b.betID,0),
		b.oddsid, 
		0 as hdp1, 
		0 as hdp2,
		0 as modds,
		0 as OddsType, 
		b.odds, 
		b.betteam, 
		b.status, 
		'', --m.betstatus, 
		b.stake, 
		b.actual_stake,
		(b.winlost-b.actual_stake) as winlost, 
		b.awinlost,
		b.mwinlost,
		b.swinlost,
		
		b.playercomm,
		(b.comm - b.playercomm) as comm,
		(b.acomm - b.comm) as acomm ,
		(b.scomm - b.acomm) as scomm,
		
		0 as livehomescore, 
		0 as liveawayscore, 
		0 as liveindicator, 
		0, --m.finalhomescore, 
		0, --m.finalawayscore,
		0, --m.hthomescore, 
		0, --m.htawayscore,
		--b.username, 
		b.IP as IP,
		b.Username,
		0 as IsNeutral,
		'' as showtime,
		'' as betcheck,
		CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END AS comstatus
	from 
		dbo.bettrans14 b with (nolock, index=IX_bettrans14)		
	where
		b.custid=@custid 		
		AND b.winlostdate=@fromdate 
		AND b.bettype in (73,23202)
		AND b.matchID in (0, 73)
		AND b.statusID IN (SELECT [statusID] FROM @tmpStatus)
	
	-- mix parlay
	INSERT INTO @Data SELECT
		0,
		0, 
		0, 
		0, 
		b.bettype,		
		'', 
		'' as race, 
		0, 
		CASE WHEN ISNULL(b.betID,0) = 0 THEN b.transid ELSE b.betID END AS transid, 
		b.transdate, 
		b.winlostdate, 
		b.refno,
		isnull(b.betID,0),
		0, 
		0, 
		0, 
		modds,
		0 as OddsType,
		b.odds, 
		b.betteam,
		b.status, 
		'' betstatus, 
		b.stake, 
		b.actual_stake,
		(b.winlost-b.actual_stake) as winlost, 
		b.awinlost,
		b.mwinlost,
		b.swinlost,
		
		b.playercomm,
		(b.comm - b.playercomm) as comm,
		(b.acomm - b.comm) as acomm ,
		(b.scomm - b.acomm) as scomm,
		
		0, 
		0, 
		0, 
		0, 
		0, 
		0, 
		0,
		--b.username creator, 
		b.IP as IP,
		b.Username,
		CONVERT(BIT,0) as IsNeutral,
		'' as showtime,
		'' as betcheck,
		CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END AS comstatus
	from 
		dbo.bettrans14 b with (nolock, index=IX_bettrans14)		
	where
		b.custid=@custid
		and b.winlostdate=@fromdate
		--and b.matchid=0 
		and b.matchid IN (9, 29)
		and b.bettype IN (9, 29)
		AND b.statusID IN (SELECT [statusID] FROM @tmpStatus)


	-- outright
	INSERT INTO @Data SELECT
		l.sporttype,
		m.leagueID,
		m.teamID as homeid,
		0 as awayid,
		bettype, 
		m.matchcode,
		m.groupmatch as race, 
		m.orid, 
		b.transid, 
		b.transdate, 
		b.winlostdate, 
		b.transid,
		isnull(b.betID,0),
		10, 
		b.hdp1, 
		b.hdp2, 
		modds,
		0 as OddsType,
		b.odds, 
		'',
		b.status, 
		'', 
		b.stake, 
		b.actual_stake,
		(b.winlost-b.actual_stake) as winlost,
		b.awinlost,
		b.mwinlost,
		b.swinlost,
		 
		b.playercomm,
		(b.comm - b.playercomm) as comm,
		(b.acomm - b.comm) as acomm ,
		(b.scomm - b.acomm) as scomm,
		
		b.livehomescore, 
		b.liveawayscore, 
		0, 
		0, 
		0, 
		0, 
		0,
		--b.username creator,
		b.IP as IP,
		b.Username,
		CONVERT(BIT,0) as IsNeutral,
		'' as showtime,
		'' as betcheck,
		CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END AS comstatus
	from 
		dbo.bettrans14 b with (nolock, index=IX_bettrans14)
		inner join dbo.outright14 m with (nolock) on b.matchid = m.orid	
		inner join dbo.league l with (nolock) on m.leagueid = l.leagueid
	where
		b.custid=@custid AND b.bettype in (10,31,32,33,41,42,43)
		AND b.winlostdate = @fromdate
		AND b.statusID IN (SELECT [statusID] FROM @tmpStatus)

END
ELSE
BEGIN
	-- single bet
	INSERT INTO @Data SELECT
		m.sporttype, 
		m.leagueid,
		m.homeID,
		m.awayID,
		b.bettype,
		m.matchcode, 
		'' as race,
		m.matchid, 
		b.transid, 
		b.transdate, 
		b.winlostdate,
		b.refno , 
		--case when b.bettype = 87 then b.betid else 0 end,
		b.betid,
		b.oddsid, 
		b.hdp1, 
		b.hdp2, 
		modds,
		b.oddstype as OddsType, 
		b.odds, 	
		b.betteam,
		CASE WHEN b.status = 'running' AND IsNull(b.SecAcceptFlag, 0) = 1 and IsNull(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
				 ELSE b.status 
				 END as status,
		m.betstatus, 
		b.stake, 
		b.actual_stake,
		(b.winlost-b.actual_stake) as winlost, 
		b.awinlost,
		b.mwinlost,
		b.swinlost,
		
		b.playercomm,
		(b.comm - b.playercomm) as comm,
		(b.acomm - b.comm) as acomm ,
		(b.scomm - b.acomm) as scomm,
		
		b.livehomescore, 
		b.liveawayscore, 
		b.liveindicator, 
		m.finalhomescore, 
		m.finalawayscore,
		m.hthomescore, 
		m.htawayscore,
		--b.username, 
		b.IP as IP,
		b.Username,
		isnull(m.isNeutral, CONVERT(BIT,0)) as IsNeutral,
		m.showtime,
		'' as betcheck,
		CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END AS comstatus
	from 
		dbo.bettrans b with (nolock, index=IX_custid_matchid_bettype)
		INNER JOIN dbo.match m with (nolock) ON b.matchid = m.matchid		
	where
		b.custid=@custid 		
		AND b.winlostdate=@fromdate AND b.bettype<= 19000 
		and b.bettype not in (10,31,32,33,41,42,43,1231,1232,1233,1237,1238) --20120626@Elodie: exclude outright, HR from sportbook
		AND b.statusID IN (SELECT [statusID] FROM @tmpStatus)

	-- Virtual HR
	INSERT INTO @Data 
	SELECT
		r.sporttype, 
		r.leagueid,
		o.RacerID as HomeID,
		0 as AwayID, 
		b.bettype,
		o.RacerNum as Matchcode, 
		b.oddsid as Race,
		b.matchid, 
		b.transid, 
		b.transdate, 
		b.winlostdate,
		b.refno, 
		b.betid,
		b.oddsid, 
		b.hdp1, 
		b.hdp2,
		modds, 
		0 as OddsType, 
		b.odds, 	
		'' as betteam,
		b.status as status,
		'' as betstatus, 
		b.stake, 
		b.actual_stake,
		(b.winlost-b.actual_stake) as winlost, 
		b.awinlost,
		b.mwinlost,
		b.swinlost,
		
		b.playercomm,
		(b.comm - b.playercomm) as comm,
		(b.acomm - b.comm) as acomm ,
		(b.scomm - b.acomm) as scomm,
		
		b.livehomescore, 
		b.liveawayscore, 
		0 as liveindicator, 
		0 as finalhomescore, 
		0 as finalawayscore,
		0 as hthomescore, 
		0 as htawayscore,
		b.IP as IP,
		b.Username,
		CONVERT(BIT,0) as IsNeutral,
		r.EventTime as showtime,
		'' as betcheck,
		CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END AS comstatus
	from 
		dbo.bettrans b with (nolock, index=IX_custid_matchid_bettype)
		INNER JOIN VSOutright o with (NOLOCK) ON b.oddsid=o.Orid
		INNER JOIN VSRaceInfo r WITH (NOLOCK) ON r.EventID = o.EventID
	where
		b.custid=@custid 		
		AND b.winlostdate=@fromdate AND b.bettype in (1231, 1232, 1233, 1237, 1238)
		AND b.statusID IN (SELECT [statusID] FROM @tmpStatus)
		
	-- CASINO
	INSERT INTO @Data 
	SELECT
		251, --m.sporttype, 
		0, --m.leagueid,
		0, --m.homeID,
		0, --m.awayID,
		b.bettype,
		'', --m.matchcode,
		'' as race,
		0, --m.matchid, 
		b.betid, 
		b.transdate, 
		b.winlostdate,
		b.refno, 
		b.betid, 
		b.oddsid, 
		b.hdp1, 
		b.hdp2,
		0 as modds,
		0 as OddsType, 
		b.odds, 
		b.betteam,
		b.status,
		'', --m.betstatus, 
		b.stake,
		b.actual_stake, 
		(b.winlost-b.actual_stake) as winlost, 
		b.awinlost,
		b.mwinlost,
		b.swinlost,
		
		b.playercomm,
		(b.comm - b.playercomm) as comm,
		(b.acomm - b.comm) as acomm ,
		(b.scomm - b.acomm) as scomm,
		
		b.livehomescore, 
		b.liveawayscore, 
		b.liveindicator, 
		0, --m.finalhomescore, 
		0, --m.finalawayscore,
		0, --m.hthomescore, 
		0, --m.htawayscore,
		--b.username, 
		b.IP as IP,
		b.Username,
		0 as IsNeutral,
		'' as showtime,
		'' as betcheck,
		CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END AS comstatus
	from 
		dbo.bettrans b with (nolock, index=IX_custid_matchid_bettype)		
	where
		b.custid=@custid 		
		AND b.winlostdate=@fromdate 
		AND b.bettype in (71,23002)	--20120405@Hurri
		AND b.matchID in (0, 71)
		AND b.statusID IN (SELECT [statusID] FROM @tmpStatus)
		
		-- P2P -- 20120405@Hurri
	INSERT INTO @Data 
	SELECT
		253, --m.sporttype, 
		0, --m.leagueid,
		0, --m.homeID,
		0, --m.awayID,
		b.bettype,
		'', --m.matchcode,
		'' as race,
		0, --m.matchid, 
		b.transid, 
		b.transdate, 
		b.winlostdate,
		b.refno, 
		b.betid, 
		b.oddsid, 
		b.hdp1, 
		b.hdp2,
		0 as modds,
		0 as OddsType, 
		b.odds, 
		b.betteam,
		b.status,
		'', --m.betstatus, 
		b.stake,
		b.actual_stake, 
		(b.winlost-b.actual_stake) as winlost, 
		b.awinlost,
		b.mwinlost,
		b.swinlost,
		
		b.playercomm,
		(b.comm - b.playercomm) as comm,
		(b.acomm - b.comm) as acomm ,
		(b.scomm - b.acomm) as scomm,
		
		b.livehomescore, 
		b.liveawayscore, 
		b.liveindicator, 
		0, --m.finalhomescore, 
		0, --m.finalawayscore,
		0, --m.hthomescore, 
		0, --m.htawayscore,
		--b.username, 
		b.IP as IP,
		b.Username,
		0 as IsNeutral,
		'' as showtime,
		b.betcheck as sessionID,
		CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END AS comstatus
	from 
		dbo.bettrans b with (nolock, index=IX_custid_matchid_bettype)		
	where
		b.custid=@custid 		
		AND b.winlostdate=@fromdate 
		AND b.bettype in (1000,23102)	
		AND b.matchID in(0, 1000)
		AND b.statusID IN (SELECT [statusID] FROM @tmpStatus)
		
	-- IBCBET BINGO
	INSERT INTO @Data 
	SELECT
		252, --m.sporttype, 
		0, --m.leagueid,
		0, --m.homeID,
		0, --m.awayID,
		b.bettype,
		'', --m.matchcode,
		'' as race,
		0, --m.matchid, 
		b.betid, 
		b.transdate, 
		b.winlostdate,
		b.refno, 
		b.betid, 
		b.oddsid, 
		0 AS hdp1, 
		0 AS hdp2,
		0 as modds,
		0 as OddsType, 
		b.odds, 
		b.betteam,
		b.status,
		'', --m.betstatus, 
		b.stake, 
		b.actual_stake,
		(b.winlost-b.actual_stake) as winlost, 
		b.awinlost,
		b.mwinlost,
		b.swinlost,
		
		b.playercomm,
		(b.comm - b.playercomm) as comm,
		(b.acomm - b.comm) as acomm ,
		(b.scomm - b.acomm) as scomm,
		
		0 AS livehomescore, 
		0 AS liveawayscore, 
		0 AS liveindicator, 
		0, --m.finalhomescore, 
		0, --m.finalawayscore,
		0, --m.hthomescore, 
		0, --m.htawayscore,
		--b.username, 
		b.IP as IP,
		b.Username,
		0 as IsNeutral,
		'' as showtime,
		'' as betcheck,
		CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END AS comstatus
	from 
		dbo.bettrans b with (nolock, index=IX_custid_matchid_bettype)		
	where
		b.custid=@custid 		
		AND b.winlostdate=@fromdate 
		AND b.bettype in (73,23202)
		AND b.matchID in (0, 73)
		AND b.statusID IN (SELECT [statusID] FROM @tmpStatus)
			
	-- mixed parlay
	INSERT INTO @Data SELECT
		0, 
		0, 
		0, 
		0, 
		b.bettype,		
		'', 
		'', 
		0, 
		CASE WHEN ISNULL(b.betID,0) = 0 THEN b.transid ELSE b.betID END AS transid, 
		b.transdate, 
		b.winlostdate, 
		b.refno,
		isnull(b.betID,0),
		0, 
		0, 
		0, 
		modds,
		0 as OddsType,
		b.odds, 
		b.betteam,
		b.status,
		'' betstatus, 
		b.stake, 
		b.actual_stake,
		(b.winlost-b.actual_stake) as winlost,
		b.awinlost,
		b.mwinlost,
		b.swinlost,
		
		b.playercomm,
		(b.comm - b.playercomm) as comm,
		(b.acomm - b.comm) as acomm ,
		(b.scomm - b.acomm) as scomm,
		
		0, 
		0, 
		0, 
		0, 
		0, 
		0, 
		0,
		--b.username creator, 
		b.IP as IP,
		b.Username,
		CONVERT(BIT,0) as IsNeutral,
		'' as showtime,
		'' as betcheck,
		CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END AS comstatus
	from 
		dbo.bettrans b with (nolock, index=IX_custid_matchid_bettype)		
	where
		b.custid=@custid
		and b.winlostdate=@fromdate
		--and b.matchid=0 
		and b.matchid IN (9, 29)
		and b.bettype IN (9, 29)
		AND b.statusID IN (SELECT [statusID] FROM @tmpStatus)


	-- outright
	INSERT INTO @Data SELECT
		l.sporttype,
		m.leagueID,
		m.teamID as homeid,
		0 as awayid,
		b.bettype, 
		m.matchcode, 
		m.groupmatch as race, 
		m.orid, 
		b.transid, 
		b.transdate, 
		b.winlostdate, 
		b.transid,
		isnull(b.betID,0),
		10, 
		b.hdp1, 
		b.hdp2, 
		modds,
		0 as OddsType,
		b.odds, 
		'',
		b.status,
		'', 
		b.stake, 
		b.actual_stake,
		(b.winlost-b.actual_stake) as winlost,
		b.awinlost,
		b.mwinlost,
		b.swinlost,
		
		b.playercomm,
		(b.comm - b.playercomm) as comm,
		(b.acomm - b.comm) as acomm ,
		(b.scomm - b.acomm) as scomm,
		
		b.livehomescore, 
		b.liveawayscore, 
		0, 
		0, 
		0, 
		0, 
		0,
		--b.username creator, 
		b.IP as IP,
		b.Username,
		CONVERT(BIT,0) as IsNeutral,
		'' as showtime,
		'' as betcheck,
		CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END AS comstatus
	from 
		dbo.bettrans b with (nolock, index=IX_custid_matchid_bettype)
		inner join dbo.outright m with (nolock) on b.matchid = m.orid	
		inner join dbo.league l with (nolock) on m.leagueid = l.leagueid
	where
		b.custid=@custid AND b.bettype in (10,31,32,33,41,42,43)
		AND b.winlostdate = @fromdate
		AND b.statusID IN (SELECT [statusID] FROM @tmpStatus)

END

SELECT * FROM @Data 
ORDER BY transid, refno

IF @IsBet14 = 1
BEGIN
	--get data from bettransm14 for bettype 33,43
	SELECT 
		BM.refno, 
		BM.Stake, 
		BM.finalodds,
		BM.odds, 
		BM.status, 
		BM.bettype,
		BM.Betteam  
	FROM bettransm14 BM with (NOLOCK, INDEX =IX_bettransm14 )
	INNER JOIN @Data B ON BM.refno = B.transid
	WHERE B.Bettype IN (33,43)
	
	UNION ALL
	--get data from bettransm14 for bettype 1233
	SELECT 
		BM.refno, 
		BM.Stake, 
		BM.finalodds,
		BM.odds, 
		BM.status, 
		BM.bettype,
		BM.Betteam  
	FROM bettransm14 BM with (NOLOCK, INDEX =IX_bettransm14 )
	INNER JOIN @Data B ON BM.refno = B.refno
	WHERE B.Bettype = 1233
	
	UNION ALL
	-- Get data form Live Casino
	SELECT 
		BG.refno, 
		BG.Stake, 
		0 as finalodds,
		BG.odds, 
		BG.status, 
		BG.bettype,
		BG.Betteam  
	FROM bettransg14 BG with (NOLOCK, INDEX =IX_bettransg14 )
	INNER JOIN @Data B ON BG.refno = B.refno
	WHERE B.Bettype  BETWEEN 1101 AND 1199

END	
ELSE
BEGIN
	--get data from bettransm for bettype 33,43
	SELECT 
		BM.refno, 
		BM.Stake, 
		BM.finalodds,
		BM.odds, 
		BM.status, 
		BM.bettype,
		BM.Betteam  
	FROM bettransm BM with (NOLOCK,INDEX =IX_bettransm_2 )
	INNER JOIN @Data B ON BM.refno = B.transid
	WHERE B.Bettype IN (33,43)

	UNION ALL
	--get data from bettransm14 for bettype 1233
	SELECT 
		BM.refno, 
		BM.Stake, 
		BM.finalodds,
		BM.odds, 
		BM.status, 
		BM.bettype,
		BM.Betteam  
	FROM bettransm BM with (NOLOCK, INDEX =IX_bettransm_2 )
	INNER JOIN @Data B ON BM.refno = B.refno
	WHERE B.Bettype = 1233
	
	UNION ALL
	-- Get data form Live Casino
	SELECT 
		BG.refno, 
		BG.Stake, 
		0 finalodds,
		BG.odds, 
		BG.status, 
		BG.bettype,
		BG.Betteam  
	FROM bettransg BG with (NOLOCK, INDEX =IX_bettransg_2 )
	INNER JOIN @Data B ON BG.refno = B.refno
	WHERE B.Bettype  BETWEEN 1101 AND 1199

END

GO
GRANT EXECUTE ON [dbo].[Age_BetList_SelByDayAll_Mem] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_BetList_SelByDayAll_Mem] TO [bodbDownlineNetView]
GO
GRANT VIEW DEFINITION ON [dbo].[Age_BetList_SelByDayAll_Mem] TO [vnteam]