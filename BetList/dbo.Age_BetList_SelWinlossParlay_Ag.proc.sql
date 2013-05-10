ALTER PROCEDURE [dbo].[Age_BetList_SelWinlossParlay_Ag]
	@CustID int=null,
	@FromDate smalldatetime,
	@ToDate smalldatetime,
	@Language varchar(2) = 'E',
	@MoveBetsDay smalldatetime,
	@bettype smallint = 9
AS
/*
Created: 
Task : Betlist
DB: DB052.bodb02
Original:
Revisions:    
    - 20090407@[HanhVu]:- get refno field instead of transid
    - 20090421@[HiepVo]: Include more columns: comm, acomm, scomm, awinlost, mwinlost, swinlost			
    - 20090505@HiepVo: Change formula of commission
    - 20090618@AnhPham: Remove 'Customer' table
	- 20090710@Phuc: unhide IP for TB currency.
	- 20091202@Henry: add 1 more column: winlostdate for selecting mix parlay detail
	- 20091203@Jamie: Remove redundant variables 
	- 20100611@Henry: Change mix-parlay match from 0 to 9
	- 20101007@Henry: Change column transid from INT to BIGINT
	- 20101224@Johnson: change type of bettype to smallint in temporary table
	- 20110810@Sophia: Add new parametter @Bettype for Combination parlay
	- 20110811@Sophia: Add new columns actual_stake and modds
	- 20110829@Sophia: Add new columns BetID
	- 20111216@Sophia: Remove function f_GetChoice 
	- 20120419@Lukas: Show transid of main ticket for subticket of system parlay
	- 20120927@Sophia: Get comstatus
	- 20130410@Lukas: get custid field
*/
SET NOCOUNT ON
DECLARE @AgWinlossMP TABLE(	
	custid int,
	username nvarchar(30),
	bettype smallint,		
	refno nvarchar(30),		
	transid bigint,	
	hdp1 smallmoney,
	hdp2 smallmoney,
	odds smallmoney,
	modds smallmoney,
	status nvarchar(10),
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
	
	transdate datetime,
	winlostdate datetime,
	betteam nvarchar(25),
	apositiontaking smallmoney,
	mpositiontaking smallmoney,
	spositiontaking smallmoney,	
	adiscount smallmoney,
	mdiscount smallmoney,
	sdiscount smallmoney,	
	liveindicator bit,
	livehomescore smallint,
	liveawayscore smallint,
	IP varchar(20),
	isNeutral bit,
	BetID bigint,
	comstatus nvarchar(20)
)

IF @Todate > @MoveBetsDay
BEGIN
	INSERT INTO @AgWinlossMP SELECT
		b.custid,
		b.username,
		b.bettype,		
		convert(nvarchar,b.refno),		
		CASE WHEN ISNULL(b.betid,0) = 0 THEN b.transid ELSE b.betid END AS transid,		
		b.hdp1,
		b.hdp2,
		b.odds,
		b.modds,
		b.status,
		b.stake,
		b.actual_stake,
		(b.winlost-actual_stake),
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
		b.discount as adiscount,
		b.adiscount as mdiscount,
		b.sdiscount as sdiscount,	
		b.liveindicator,
		b.livehomescore,
		b.liveawayscore,
		b.IP as IP,
		CONVERT(BIT,0) as IsNeutral,
		b.betID,
		CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END AS comstatus
	FROM
		bettrans b with (nolock) 
	WHERE
		b.Recommend=@CustID AND
		b.Winlostdate>=@FromDate AND
		b.Winlostdate<=@ToDate AND
		b.Bettype = @bettype AND
		b.matchid = @bettype and
		b.Ruben=1  
END

IF @Fromdate <= @MoveBetsDay
BEGIN
	INSERT INTO @AgWinlossMP SELECT
		b.custid,
		b.username,
		b.bettype,		
		convert(nvarchar,b.refno),		
		CASE WHEN ISNULL(b.betid,0) = 0 THEN b.transid ELSE b.betid END AS transid,		
		b.hdp1,
		b.hdp2,
		b.odds,
		b.modds,
		b.status,
		b.stake,
		b.actual_stake,
		(b.winlost-actual_stake),
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
		b.discount as adiscount,
		b.adiscount as mdiscount,
		b.sdiscount as sdiscount,		
		b.liveindicator,
		b.livehomescore,
		b.liveawayscore,
		b.IP as IP,
		CONVERT(BIT,0) as IsNeutral,
		b.betID,
		CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END AS comstatus
	FROM
		bettrans14 b with (nolock) 	
	WHERE
		b.Recommend=@CustID AND
		b.Winlostdate>=@FromDate AND
		b.Winlostdate<=@ToDate AND
		b.Bettype = @bettype AND
		b.matchid = @bettype and
		b.Ruben=1	 
END

SELECT *,'' betstatus, '' matchcode, 0 homeid, 0 awayid, 0 leagueid, 0 matchid, 0 sporttype FROM @AgWinlossMP 

ORDER BY Status, Transid

		

GO
GRANT EXECUTE ON [dbo].[Age_BetList_SelWinlossParlay_Ag] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_BetList_SelWinlossParlay_Ag] TO [bodbDownlineNetView]
GO
GRANT VIEW DEFINITION ON [dbo].[Age_BetList_SelWinlossParlay_Ag] TO [vnteam]