USE [bodb02]
GO
/****** Object:  StoredProcedure [dbo].[Age_BetList_SelAllByDate_Mem]    Script Date: 3/13/2014 9:51:53 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[Age_BetList_SelAllByDate_Mem]
	@custid int=null,
	@AgID int=0,
	@FromDate datetime,
	@ToDate datetime,
	@Language varchar(2) = 'E',
	@username varchar(50) = NULL, -- for API
	@ShowSB bit = 1,
	@ShowCasino bit = 0,
	@ShowP2P bit = 0,
	@ShowRB bit = 0,
	@ShowFI BIT = 0,
	@ShowNG bit = 0,
	@ShowBI bit = 0,	
	@ShowLiveCasino BIT = 0,
	@ShowVS BIT = 0,
	@ShowKeno BIT = 0
AS
SET NOCOUNT ON

/*
Created: 
Task : Bet List
DB: DB053.bodb02
Original BetsSelBetListEnglishAgent2
Revisions:
    - 20080707@Viet: Remove Teamname, Leaguename, Sportname, TypeName
    - 20081106@VinhTrinh: Get more result(Sporttype: Horseracing) for betlist
    - 20090226@Hiep: Get more result for Casino Integration	
    - 20090402@nqminh: add real_refno column
    - 20090406@HanhVu: - remove real_refno 
					   - change refno field instead of transid for mix parlay
					   - hardcode refno field for single bet
	- 20090415@HIepVo:	Create @BetListSelAllByDateMem temp table, add column BetID to temp table
	- 20090416@Minh: remove indexName
	- 20090421@[HiepVo]: Include more columns: comm, acomm, scomm, awinlost, mwinlost, swinlost
	- 20090505@HiepVo: Change formula of commission
	- 20090522@HiepVo: More filter: ShowHR, ShowFI. Add F.O Horse Racing bet type (split Sport Book); Get more data from bettransm for HR
	- 20090710@Phuc: unhide IP for TB currency.
	- 20090930@Phuc: Show the refunded tickets' status based on bettrans.status/ get oddstype.
	- 20100527@Henry: Change to use StatusID instead of Status in WHERE statement
	- 20100611@Henry: Change mix-parlay match from 0 to 9
	- 20100902@Kiwi: Add Number Game & IBCBet Bingo
	- 20101007@Henry: Change column transid from INT to BIGINT
	- 20110307@Lukas: change @ShowHR to @ShowRB & get more sporttype (152,153)
	- 20110408@Amy: Change function to get Odds value and showed odds type
					Display odds value and odds type for Number Game
	- 20110512@Johnson: change column bettype in temporary table from tinyint to smallint
	- 20110801@Sophia: change the range of number game's bettype from 81 to 120, add new bettype 29 for Combination Mix parlay
	- 20110809@Sophia: Not to use function f_GetChoice to get betteam (bettype <> 14, 16)
	- 20110811@Sophia: Add new columns actual_stake and modds 
	- 20111122@Sophia: Add Checktime and SecAcceptFlag to show status waiting or running
	- 20111216@Sophia: Remove function f_GetOddsByBettype , f_GetChoice , f_ShowOddsByBettype
	- 20120230@Sophia: Add new bettype: Live Casino , add showtime for Table - Shoe - Hand of LiveCasino 
	- 20120405@Hurri: Change bettype for P2P
	- 20120409@Sophia: Remove check checktime with CURRENT_TIMETAMP for Casino, P2P, Bingo
	- 20120419@Lukas: Show transid of main ticket for subticket of system parlay
	- 20120502@Johnson: Get session id(betcheck) for bets list P2P
	- 20120525@Johnson: correct sporttype for p2p
	- 20120626@Elodie: exclude outright, HR from sportbook ( in case of matchid = orid)
	- 20120629@Sophia: Show hdp1 for Number game
	- 20120705@Sophia: Get sporttype for outright
	- 20120807@Sophia:  . Add new parametter @showVS for Virtual Sports (sporttype = 180 for representing)
						. Remove Financial product
	- 20120926@Sophia: Get comstatus
	- 20130225@Elodie: Add bet list of Virtual HR
	- 20131003@Lukas: sort tickets by transid
	- 20140306@Patrick:	Add more Keno product
	- 20140310@Patrick:	Exclude keno from Sportbook
	- 20140907@Dom:	[Redmine #22012] remove duplicate VS transaction id in bet list feature
	- 20141103@Dom: Apply sport bettype matrix
*/


if @custid is null
	select @custid = custid from customer with (nolock) where username = @username

Declare @Recommend int
	Select @Recommend = Recommend, @UserName = Username From custinfo With(NOLOCK) Where CustID=@CustID

DECLARE @SportBettype TABLE(ProductID INT, Bettype INT,EventType INT)
INSERT INTO @SportBettype
EXEC dbo.Acc_SportBettypeMatrix_Sel @mode=4

DECLARE @BetListSelAllByDateMem TABLE(
	Username nvarchar(30), 
	Sporttype smallint,
	Bettype smallint,
	refno nvarchar(20),
	TransID bigint,
	BetID bigint,
	MatchCode nvarchar(50),
	MatchID int,
	Race nvarchar(20),
	HomeID int,
	AwayID int, 
	hdp1 smallmoney, 
	hdp2 smallmoney, 
	Odds smallmoney, 
	Modds smallmoney, 
	Status nvarchar(10),
	Stake money, 
	actual_stake money,
	Winlost money,
	awinlost money,
	mwinlost money,
	swinlost money,
	
	PlayerComm money,
	comm money,
	acomm money,
	scomm money,
	
	Transdate datetime,
	Winlostdate datetime,
	Betteam nvarchar(20),
	APositiontaking smallmoney,
	MPositiontaking smallmoney,
	SPositiontaking smallmoney,
	Adiscount smallmoney,
	Mdiscount smallmoney,
	Sdiscount smallmoney,
	LeagueID int,
	Liveindicator bit,
	Livehomescore smallint,
	Liveawayscore smallint,
	IP nvarchar(15),
	Betstatus nvarchar(50),
	isNeutral bit,
	oddstype tinyint null,
	showtime nvarchar(50),
	BetCheck nvarchar(50),
	comstatus nvarchar(20)
)

DECLARE @BettransDetail TABLE(  
	 refno BIGINT,  
	 odds SMALLMONEY,  
	 stake MONEY,
	 status NVARCHAR(10),  
	 apositiontaking SMALLMONEY,  
	 mpositiontaking SMALLMONEY,  
	 spositiontaking SMALLMONEY,
	 bettype SMALLINT,
	 Betteam nvarchar(10)
 )   
 
IF @ShowSB = 1
BEGIN
	INSERT INTO @BetListSelAllByDateMem
	--Single bets
	SELECT 
		@UserName as UserName,
		m.sporttype,
		b.bettype,
		'' AS refno,		
		b.transid,
		isnull(b.BetID,0),
		m.matchcode, 
		m.matchid,
		'' as Race, 
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
		(winlost-actual_stake) winlost,
		b.awinlost,
		b.mwinlost,
		b.swinlost,
		
		(playercomm) AS playercomm,
		(b.comm - b.playercomm) as comm,
		(b.acomm - b.comm) as acomm ,
		(b.scomm - b.acomm) as scomm,
		
		b.transdate,
		b.winlostdate,
		b.betteam,
		b.apositiontaking,
		b.mpositiontaking,
		b.spositiontaking,
		b.discount as adiscount,
		b.adiscount as mdiscount,
		b.sdiscount as sdiscount,
		m.leagueID,
		b.liveindicator, 
		b.livehomescore, 
		b.liveawayscore, 
		b.IP as IP,
		m.betstatus,
		isnull(m.isNeutral, CONVERT(BIT,0)) as IsNeutral,
		b.OddsType as OddsType,
		m.showtime,
		'' as betcheck,
		CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END AS comstatus
	FROM 
		bettrans b with (nolock)
		INNER JOIN match m with (nolock) ON b.matchid=m.matchid		
		INNER JOIN @SportBettype s ON s.Bettype = b.bettype
	WHERE
		b.CustID = @CustID
		AND b.recommend=@Recommend  
		AND b.transdate>=@FromDate 
		AND b.transdate<=@ToDate
		--AND b.bettype NOT IN (51,52,53,54,55,56,61,62,63,64,65,66,10,31,32,33,41,42,43) --20120626@Elodie: exclude outright, HR from sportbook
		--AND b.bettype NOT BETWEEN 81 AND 120  --- Change arrange of Numbergame from 81 to 120
		--AND b.bettype NOT BETWEEN 1101 AND 1199  --- Change arrange of Numbergame from 1101 to 1199
		--AND b.bettype NOT BETWEEN 1201 AND 1299		
		--AND b.bettype NOT BETWEEN 1501 AND 1599 -- exclude Keno
		AND s.ProductID = 1 
		AND s.EventType = 1 
				
	-- OutRight tickets
	INSERT INTO @BetListSelAllByDateMem
	select 
		@UserName,
		l.sporttype,
		b.bettype,
		'' AS refno,		
		b.transid,
		isnull(b.BetID,0),
		m.matchcode,
		b.matchid,
		m.GroupMatch as Race,
		m.teamID as homeID,
		0 as awayID,
		convert(float, b.hdp1) as hdp1, 
		convert(float, b.hdp2) as hdp2, 
		b.odds,
		b.modds,
		b.status,    
		b.stake,
		b.actual_stake,
		(winlost-actual_stake)  winlost,
		b.awinlost,
		b.mwinlost,
		b.swinlost,
		
		(playercomm) AS playercomm,
		(b.comm - b.playercomm) as comm,
		(b.acomm - b.comm) as acomm ,
		(b.scomm - b.acomm) as scomm,
		
		b.transdate,
		b.winlostdate,
		'' as Betteam,    
		b.apositiontaking,	
		b.mpositiontaking,	
		b.spositiontaking,	
		b.discount as adiscount,
		b.adiscount as mdiscount,
		b.sdiscount as sdiscount,
		m.leagueID,
		0 as liveindicator , 
		b.livehomescore, 
		b.liveawayscore, 
		b.IP as IP, 
		'' betstatus,
		CONVERT(BIT,0) as IsNeutral,
		0 as OddsType,
		'' as showtime,
		'' as betcheck,
		CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END AS comstatus
	from
		bettrans b with (nolock)
		INNER JOIN outright m with (nolock) ON b.matchid=m.orid
		INNER JOIN league l with (nolock) on m.leagueid = l.leagueid		
	where
		b.CustID = @CustID and
		b.recommend=@Recommend
		and b.transdate>=@FromDate and b.transdate<=@ToDate
		and b.bettype = 10

	--MixParlay 
	INSERT INTO @BetListSelAllByDateMem
	select 
		@UserName as UserName,
		0 as sporttype,
		b.bettype,
		convert(nvarchar(20),b.refno) AS refno,		
		CASE WHEN ISNULL(b.betID,0) = 0 THEN b.transid ELSE b.betID END AS transid,
		isnull(b.BetID,0),
		'' as matchcode, 
		b.matchid,
		'' as Race, 
		0 as homeID,
		0 as awayID,
		convert(float, b.hdp1) as hdp1, 
		convert(float, b.hdp2) as hdp2, 
		b.odds,
		b.modds, 
		b.status,    
		b.stake,
		b.actual_stake,
		(winlost-actual_stake) winlost,
		b.awinlost,
		b.mwinlost,
		b.swinlost,
		
		(playercomm) AS playercomm,
		(b.comm - b.playercomm) as comm,
		(b.acomm - b.comm) as acomm ,
		(b.scomm - b.acomm) as scomm,
		
		b.transdate,
		b.winlostdate,
		b.betteam,
		b.apositiontaking,
		b.mpositiontaking,
		b.spositiontaking,
		b.discount as adiscount,
		b.adiscount as mdiscount,
		b.sdiscount as sdiscount,
		0 as leagueID,
		b.liveindicator, 
		b.livehomescore, 
		b.liveawayscore, 
		b.IP as IP,
		'' as betstatus,
		CONVERT(BIT,0) as IsNeutral,
		0 as OddsType,
		'' as showtime,
		'' as betcheck,
		CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END AS comstatus
	from 
		bettrans b with (nolock)	
	where
		b.CustID = @CustID and
		b.recommend=@Recommend  
		and b.transdate>=@FromDate and b.transdate<=@ToDate
		--and b.matchid = 0
		and b.matchid IN (9,29)
		and b.bettype IN (9,29)
			
END

--Horse Racing
IF @ShowRB = 1
BEGIN
	INSERT INTO @BetListSelAllByDateMem
	select 
		@UserName,
		l.sporttype,
		b.bettype,
		'' AS refno,		
		b.transid,
		isnull(b.BetID,0),
		m.matchcode,
		b.matchid,
		m.GroupMatch as Race,
		m.teamID as homeID,
		0 as awayID,
		convert(float, b.hdp1) as hdp1, 
		convert(float, b.hdp2) as hdp2, 
		b.odds,
		b.modds,
		b.status,    
		b.stake,
		b.actual_stake,
		(winlost-actual_stake)  winlost,
		b.awinlost,
		b.mwinlost,
		b.swinlost,
		
		(playercomm) AS playercomm,
		(b.comm - b.playercomm) as comm,
		(b.acomm - b.comm) as acomm ,
		(b.scomm - b.acomm) as scomm,
		
		b.transdate,
		b.winlostdate,
		'' as Betteam,    
		b.apositiontaking,	
		b.mpositiontaking,	
		b.spositiontaking,	
		b.discount as adiscount,
		b.adiscount as mdiscount,
		b.sdiscount as sdiscount,
		m.leagueID,
		0 as liveindicator , 
		b.livehomescore, 
		b.liveawayscore, 
		b.IP as IP, 
		'' betstatus,
		CONVERT(BIT,0) as IsNeutral,
		0 as oddstype,
		'' as showtime,
		'' as betcheck,
		CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END AS comstatus
	from
		bettrans b with (nolock)
		INNER JOIN outright m with (nolock) ON b.matchid=m.orid	
		INNER JOIN league l WITH(NOLOCK) ON l.leagueid = m.leagueid	
		INNER JOIN @SportBettype s ON s.Bettype = b.bettype
	where
		b.CustID = @CustID
		AND b.recommend=@Recommend
		AND b.transdate>=@FromDate 
		AND b.transdate<=@ToDate	
		AND s.ProductID = 2
		--and b.bettype in (31, 32, 33,41,42,43)
END

IF @ShowCasino=1
BEGIN
	--Casino
	INSERT INTO @BetListSelAllByDateMem
	select 
		@UserName,
		251 as sporttype,
		b.bettype,
		convert(nvarchar(20),b.refno) AS refno,				
		b.transid,
		isnull(b.BetID,0),
		'' as matchcode,
		b.matchid,
		'' as Race,
		0 as homeID,
		0 as awayID,
		0 as hdp1, 
		0 as hdp2,
		0 as odds,
		0 as modds,
		b.status,    
		b.stake,
		b.actual_stake,
		case when (b.bettype=71 ) then (winlost-actual_stake) else 0 end  as winlost,
		b.awinlost,
		b.mwinlost,
		b.swinlost,
		
		(playercomm) AS playercomm,
		(b.comm - b.playercomm) as comm,
		(b.acomm - b.comm) as acomm ,
		(b.scomm - b.acomm) as scomm,
		
		b.transdate,
		b.winlostdate,
		'' as Betteam,    
		b.apositiontaking,	
		b.mpositiontaking,	
		b.spositiontaking,	
		b.discount as adiscount,
		b.adiscount as mdiscount,
		b.sdiscount as sdiscount,
		0 as leagueID,
		0 as liveindicator , 
		0 as livehomescore, 
		0 as liveawayscore,
		b.IP as IP,
		'' betstatus,
		CONVERT(BIT,0) as IsNeutral,
		0 as oddstype,
		'' as showtime,
		'' as betcheck,
		CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END AS comstatus
	from
		bettrans b with (nolock)
	where
		b.CustID = @CustID and
		b.recommend=@Recommend
		--and b.status in ('WON','LOSE','RUNNING')
		and bettype IN (71,23002)
		and b.statusID IN (112,113,0)
		and b.transdate>=@FromDate and b.transdate<=@ToDate
		
END

IF @ShowP2P = 1
BEGIN
	INSERT INTO @BetListSelAllByDateMem
	select 
		@UserName,
		253 as sporttype,
		b.bettype,
		convert(nvarchar(20),b.refno) AS refno,				
		b.transid,
		isnull(b.BetID,0),
		'' as matchcode,
		b.matchid,
		'' as Race,
		0 as homeID,
		0 as awayID,
		0 as hdp1, 
		0 as hdp2,
		0 as odds,
		0 as modds,
		b.status,    
		b.stake,
		b.actual_stake,
		case when (b.bettype=1000) then (winlost-actual_stake) else 0 end  as winlost,	--20120405@Hurri
		b.awinlost,
		b.mwinlost,
		b.swinlost,
		
		(playercomm) AS playercomm,
		(b.comm - b.playercomm) as comm,
		(b.acomm - b.comm) as acomm ,
		(b.scomm - b.acomm) as scomm,
		
		b.transdate,
		b.winlostdate,
		'' as Betteam,    
		b.apositiontaking,	
		b.mpositiontaking,	
		b.spositiontaking,	
		b.discount as adiscount,
		b.adiscount as mdiscount,
		b.sdiscount as sdiscount,
		0 as leagueID,
		0 as liveindicator , 
		0 as livehomescore, 
		0 as liveawayscore,
		b.IP as IP,
		'' betstatus,
		CONVERT(BIT,0) as IsNeutral,
		0 as oddstype,
		'' as showtime,
		b.betcheck as SessionID,
		CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END AS comstatus
	from
		bettrans b with (nolock)
	where
		b.CustID = @CustID and
		b.recommend=@Recommend
		--and b.status in ('WON','LOSE','RUNNING')
		and bettype in (1000,23102)						--20120405@Hurri: old values (72,23101)
		and b.statusID IN (112,113,0)
		and b.transdate>=@FromDate and b.transdate<=@ToDate
		
END
--NUMBER GAME
IF @ShowNG = 1
BEGIN
	INSERT INTO @BetListSelAllByDateMem
	select 
		@UserName as UserName,
		m.sporttype,
		b.bettype,
		'' AS refno,		
		b.transid,
		isnull(b.BetID,0),
		m.matchcode, 
		m.matchid,
		'' as Race, 
		m.homeID,
		m.awayID,
		b.hdp1, 
		0 as hdp2, 
		b.odds,
		b.modds,
		CASE WHEN b.status = 'running' AND IsNull(b.SecAcceptFlag, 0) = 1 and IsNull(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
				 ELSE b.status 
				 END as status,    
		b.stake,
		b.actual_stake,
		(winlost-actual_stake) winlost,
		b.awinlost,
		b.mwinlost,
		b.swinlost,
		
		(playercomm) AS playercomm,
		(b.comm - b.playercomm) as comm,
		(b.acomm - b.comm) as acomm,
		(b.scomm - b.acomm) as scomm,
		
		b.transdate,
		b.winlostdate,
		b.betteam,
		b.apositiontaking,
		b.mpositiontaking,
		b.spositiontaking,
		b.discount as adiscount,
		b.adiscount as mdiscount,
		b.sdiscount as sdiscount,
		m.leagueID,
		b.liveindicator, 
		b.livehomescore, 
		b.liveawayscore,
		b.IP as IP,
		m.betstatus,
		CONVERT(BIT,0) as IsNeutral,
		b.OddsType as OddsType,
		m.showtime,
		'' as betcheck,
		CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END AS comstatus
	FROM 
		bettrans b with (nolock)
		INNER JOIN match m with (nolock) ON b.matchid=m.matchid		
		INNER JOIN @SportBettype s ON s.Bettype = b.bettype
	WHERE
		b.CustID = @CustID
		AND b.recommend=@Recommend  
		AND b.transdate>=@FromDate 
		AND b.transdate<=@ToDate
		AND s.ProductID = 3
		--AND b.bettype BETWEEN 81 AND 120
END
IF @ShowBI=1
BEGIN
	--IBCBET BINGO
	INSERT INTO @BetListSelAllByDateMem
	select 
		@UserName,
		252 as sporttype,
		bettype,
		convert(nvarchar(20),refno) AS refno,				
		transid,
		isnull(BetID,0),
		'' as matchcode,
		matchid,
		'' as Race,
		0 as homeID,
		0 as awayID,
		0 as hdp1, 
		0 as hdp2,
		0 as odds,
		0 as modds,
		b.status,    
		stake,
		b.actual_stake,
		case when (bettype=73) then (winlost-actual_stake) else 0 end  as winlost,
		awinlost,
		mwinlost,
		swinlost,
		
		(playercomm) AS playercomm,
		(comm - playercomm) as comm,
		(acomm - comm) as acomm ,
		(scomm - acomm) as scomm,
		
		transdate,
		winlostdate,
		'' as Betteam,    
		apositiontaking,	
		mpositiontaking,	
		spositiontaking,	
		discount as adiscount,
		adiscount as mdiscount,
		sdiscount as sdiscount,
		0 as leagueID,
		0 as liveindicator, 
		0 as livehomescore, 
		0 as liveawayscore,
		IP as IP,
		'' betstatus,
		CONVERT(BIT,0) as IsNeutral,
		0 as oddstype,
		'' as showtime,
		'' as betcheck,
		CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END AS comstatus
	from
		bettrans b with (nolock)
	where
		CustID = @CustID and
		recommend=@Recommend
		and bettype IN (73,23202)
		and statusID IN (112,113,0)
		and transdate>=@FromDate and transdate<=@ToDate		
END
---Live Casino
IF @ShowLiveCasino = 1
BEGIN
	INSERT INTO @BetListSelAllByDateMem
	select 
		@UserName as UserName,
		m.sporttype,
		b.bettype,
		b.refno,		
		b.transid,
		isnull(b.BetID,0),
		m.matchcode, 
		m.matchid,
		'' as Race, 
		m.homeID,
		m.awayID,
		0 as hdp1, 
		0 as hdp2, 
		b.odds,
		b.modds,
		CASE WHEN b.status = 'running' AND IsNull(b.SecAcceptFlag, 0) = 1 and IsNull(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
				 ELSE b.status 
				 END as status,    
		b.stake,
		b.actual_stake,
		(winlost-actual_stake) winlost,
		b.awinlost,
		b.mwinlost,
		b.swinlost,
		
		(playercomm) AS playercomm,
		(b.comm - b.playercomm) as comm,
		(b.acomm - b.comm) as acomm,
		(b.scomm - b.acomm) as scomm,
		
		b.transdate,
		b.winlostdate,
		b.betteam,
		b.apositiontaking,
		b.mpositiontaking,
		b.spositiontaking,
		b.discount as adiscount,
		b.adiscount as mdiscount,
		b.sdiscount as sdiscount,
		m.leagueID,
		b.liveindicator, 
		b.livehomescore, 
		b.liveawayscore,
		b.IP as IP,
		m.betstatus,
		CONVERT(BIT,0) as IsNeutral,
		b.OddsType as OddsType,
		m.showtime,
		'' as betcheck,
		CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END AS comstatus
	FROM 
		bettrans b with (nolock)
		INNER JOIN match m with (nolock) ON b.matchid=m.matchid		
		INNER JOIN @SportBettype s ON s.Bettype = b.bettype
	WHERE
		b.CustID = @CustID
		AND b.recommend=@Recommend  
		AND b.transdate>=@FromDate 
		AND b.transdate<=@ToDate
		AND s.ProductID = 4
		--AND b.bettype BETWEEN 1101 AND 1199
END

----Show Virtual Sports
IF @ShowVS = 1
BEGIN
	INSERT INTO @BetListSelAllByDateMem
	SELECT 
		@UserName as UserName,
		m.sporttype,
		b.bettype,
		'' AS refno,		
		b.transid,
		isnull(b.BetID,0),
		m.matchcode, 
		m.matchid,
		'' as Race, 
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
		(winlost-actual_stake) winlost,
		b.awinlost,
		b.mwinlost,
		b.swinlost,
		
		(playercomm) AS playercomm,
		(b.comm - b.playercomm) as comm,
		(b.acomm - b.comm) as acomm ,
		(b.scomm - b.acomm) as scomm,
		
		b.transdate,
		b.winlostdate,
		b.betteam,
		b.apositiontaking,
		b.mpositiontaking,
		b.spositiontaking,
		b.discount as adiscount,
		b.adiscount as mdiscount,
		b.sdiscount as sdiscount,
		m.leagueID,
		b.liveindicator, 
		b.livehomescore, 
		b.liveawayscore, 
		b.IP as IP,
		m.betstatus,
		isnull(m.isNeutral, CONVERT(BIT,0)) as IsNeutral,
		b.OddsType as OddsType,
		m.showtime,
		'' as betcheck,
		CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END AS comstatus
	FROM 
		bettrans b with (nolock)
		INNER JOIN match m with (nolock) ON b.matchid=m.matchid		
		INNER JOIN @SportBettype s ON s.BetType = b.BetType 
	WHERE
		b.CustID = @CustID
		AND b.recommend=@Recommend  
		AND b.transdate>=@FromDate 
		AND b.transdate<=@ToDate
		AND s.ProductID=5
		AND s.EventType=1
		--AND b.bettype BETWEEN 1201 AND 1299
		--AND b.bettype NOT IN (SELECT  bettype FROM dbo.f_VSHorseRacingByBettype())
	
	INSERT INTO @BetListSelAllByDateMem
	--Virtual HR
	SELECT 
		@UserName as UserName,
		r.SportType,
		b.bettype,
		convert(nvarchar(20),b.refno) AS refno,		
		b.transid,
		isnull(b.BetID,0),
		o.RacerNum as matchcode, 
		b.matchid,
		b.oddsid as Race, 
		o.RacerID as homeID,
		0 as awayID,
		convert(float, b.hdp1) as hdp1, 
		convert(float, b.hdp2) as hdp2, 
		b.odds,
		b.modds,
		b.status,
		b.stake,
		b.actual_stake,
		(winlost-actual_stake) winlost,
		b.awinlost,
		b.mwinlost,
		b.swinlost,
		
		(playercomm) AS playercomm,
		(b.comm - b.playercomm) as comm,
		(b.acomm - b.comm) as acomm ,
		(b.scomm - b.acomm) as scomm,
		
		b.transdate,
		b.winlostdate,
		'' as Betteam,
		b.apositiontaking,
		b.mpositiontaking,
		b.spositiontaking,
		b.discount as adiscount,
		b.adiscount as mdiscount,
		b.sdiscount as sdiscount,
		r.leagueID,
		0 as liveindicator , 
		b.livehomescore, 
		b.liveawayscore, 
		b.IP as IP,
		'' betstatus,
		CONVERT(BIT,0) as IsNeutral,
		0 as oddstype,
		r.EventTime as showtime,
		'' as betcheck,
		CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END AS comstatus
	FROM 
		bettrans b with (nolock)
		INNER JOIN VSOutright o with (nolock) ON b.oddsid=o.Orid
		INNER JOIN VSRaceInfo r WITH (NOLOCK) ON r.EventID = o.EventID
		INNER JOIN @SportBettype s ON s.BetType = b.BetType 
	WHERE
		b.CustID = @CustID and
		b.recommend=@Recommend  
		AND b.transdate>=@FromDate and b.transdate<=@ToDate		
		AND s.ProductID = 5
		AND s.EventType = 3
		--AND b.bettype in (/*1231, 1232, 1233, 1237, 1238*/SELECT  bettype FROM dbo.f_VSHorseRacingByBettype())
END

--Keno
IF @ShowKeno = 1
BEGIN
	--Tickets doesnt Waiting & Runing status
	INSERT INTO @BetListSelAllByDateMem
	SELECT
		@UserName as UserName,
		202 AS sporttype,
		b.bettype,
		b.refno,		
		b.transid,
		isnull(b.BetID, 0),
		'' AS matchcode, 
		fnc.GameId AS matchid,
		'' as Race, 
		0 AS homeID,
		0 AS awayID,
		0 as hdp1, 
		0 as hdp2, 
		b.odds,
		b.modds,
		b.[status],
		b.stake,
		b.actual_stake,
		(winlost-actual_stake) winlost,
		b.awinlost,
		b.mwinlost,
		b.swinlost,
		
		(playercomm) AS playercomm,
		(b.comm - b.playercomm) as comm,
		(b.acomm - b.comm) as acomm,
		(b.scomm - b.acomm) as scomm,
		
		b.transdate,
		b.winlostdate,
		fnc.ChoiceId AS betteam,
		b.apositiontaking,
		b.mpositiontaking,
		b.spositiontaking,
		b.discount as adiscount,
		b.adiscount as mdiscount,
		b.sdiscount as sdiscount,
		0 AS leagueID,
		b.liveindicator, 
		b.livehomescore, 
		b.liveawayscore,
		b.IP as IP,
		0 AS betstatus,
		CONVERT(BIT,0) as IsNeutral,
		b.OddsType as OddsType,
		'' AS showtime,
		'' as betcheck,
		CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END AS comstatus
	FROM
		dbo.bettrans AS b WITH (NOLOCK)
		INNER JOIN @SportBettype s ON s.Bettype = b.bettype
		CROSS APPLY dbo.f_ParseTransDesc(b.transdesc, b.bettype) fnc
	WHERE
		b.transdate BETWEEN @fromdate AND @todate AND
		b.recommend = @Recommend AND  
		b.custid = @CustID AND
		s.ProductID = 8 AND
		--b.bettype BETWEEN 1501 AND 1599 AND
		b.statusID NOT IN (0,1)	
		
	--Tickets only Waiting & Runing status
	INSERT INTO @BetListSelAllByDateMem
	SELECT
		@UserName as UserName,
		202 AS sporttype,
		b.GameId AS bettype,
		b.TransLogId AS refno,	
		b.TransLogId AS transid,
		0 AS BetID,
		'' AS matchcode, 
		fnc.GameId AS matchid,
		'' as Race, 
		0 AS homeID,
		0 AS awayID,
		0 as hdp1, 
		0 as hdp2, 
		b.odds,
		0 AS modds,
		b.[status],
		b.stake,
		b.actual_stake,
		0 AS winlost,
		0 AS awinlost,
		0 AS mwinlost,
		0 AS swinlost,
		
		0 AS playercomm,
		0 AS comm,
		0 AS acomm,
		0 AS scomm,
		
		b.transdate,
		b.winlostdate,
		fnc.ChoiceId AS betteam,
		b.apositiontaking,
		b.mpositiontaking,
		b.spositiontaking,
		b.discount as adiscount,
		b.adiscount as mdiscount,
		b.sdiscount as sdiscount,
		0 AS leagueID,
		0 AS liveindicator, 
		0 AS livehomescore, 
		0 AS liveawayscore,
		b.IP as IP,
		0 AS betstatus,
		CONVERT(BIT, 0) as IsNeutral,
		0 AS OddsType,
		'' AS showtime,
		'' as betcheck,
		0 AS comstatus
	FROM
		dbo.translog AS b WITH (NOLOCK)
		INNER JOIN @SportBettype s ON s.Bettype = b.gameID
		CROSS APPLY dbo.f_ParseTransDesc(b.transdesc, b.gameid) fnc
	WHERE
		b.transdate BETWEEN @fromdate AND @todate AND
		b.recommend = @Recommend AND  
		b.custid = @CustID AND
		s.ProductID = 8 AND
		--b.gameID BETWEEN 1501 AND 1599 AND
		b.statusID IN (0,1)					
END

SELECT * 
FROM @BetListSelAllByDateMem
ORDER BY TransID ASC 

if @ShowRB = 1
begin
	--get data from bettransm for bettype 33,43
	INSERT INTO @BettransDetail
	SELECT 
		BM.refno, 
		BM.odds, 
		BM.stake,
		BM.status,
		BM.apositiontaking, 
		BM.mpositiontaking, 
		BM.spositiontaking,
		BM.bettype ,
		BM.betteam
	FROM bettransm BM with (NOLOCK)
	INNER JOIN @BetListSelAllByDateMem B ON BM.refno = B.transid
	WHERE 
	
	B.Bettype IN (33,43)
end

if @ShowVS = 1
begin
	--get data from bettransm for bettype 1233
	INSERT INTO @BettransDetail
	SELECT 
		BM.refno, 
		BM.odds, 
		BM.stake,
		BM.status,
		BM.apositiontaking, 
		BM.mpositiontaking, 
		BM.spositiontaking,
		BM.bettype ,
		BM.betteam
	FROM bettransm BM with (NOLOCK)
	INNER JOIN @BetListSelAllByDateMem B ON BM.refno = B.refno
	WHERE B.Bettype = 1233
end

if @ShowLiveCasino = 1
begin
	--get data from bettransg for live casino
	INSERT INTO @BettransDetail
	SELECT 
		BG.refno, 
		BG.odds, 
		BG.stake,
		BG.status,
		BG.apositiontaking, 
		BG.mpositiontaking, 
		BG.spositiontaking,
		BG.bettype,
		BG.betteam  
	FROM bettransg BG with (NOLOCK)
	INNER JOIN @BetListSelAllByDateMem B ON BG.refno = B.refno
	WHERE B.Bettype between 1101 and 1199
end

SELECT * FROM @BettransDetail

GO
GRANT  EXECUTE  ON [dbo].[Age_BetList_SelAllByDate_Mem]  TO [bodbDownlineNet]
GO
GRANT  EXECUTE  ON [dbo].[Age_BetList_SelAllByDate_Mem]  TO [bodbDownlineNetView]
GO
GRANT VIEW DEFINITION ON [dbo].[Age_BetList_SelAllByDate_Mem] TO [vnteam]

