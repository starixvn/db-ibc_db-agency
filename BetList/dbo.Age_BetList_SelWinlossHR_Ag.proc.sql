ALTER PROCEDURE [dbo].[Age_BetList_SelWinlossHR_Ag]
	 @CustID int=null, --AgentID  
	 @Bettype int,  
	 @LeagueId int,  
	 @Race varchar(20),  
	 @FromDate smalldatetime,  
	 @ToDate smalldatetime,  
	 @Language varchar(2) = 'E',  
	 @MoveBetsDay smalldatetime  
AS  

/*
Created: 
Task : Betlist
DB: DB053.bodb02
Original:
Revisions:    
    - 20090407@[HanhVu]:- remove refno		
    - 20090421@[HiepVo]: Include more columns: comm, acomm, scomm, awinlost, mwinlost, swinlost					
    - 20090505@HiepVo: Change formula of commission
    - 20090530@HiepVo:  Get more data from bettransm for HR
    - 20090618@AnhPham: Remove 'Customer' table
	- 20090710@Phuc: unhide IP for TB currency.
	- 20091024@[MinhNguyen]: get modds, finalodds.
	- 20101007@Henry: Change column transid from INT to BIGINT
	- 20101224@Johnson: change type of bettype to smallint in temporary table
	- 20120927@Sophia: Get comstatus
	- 20130306@Elodie: Add bet list of Virtual HR
*/

SET NOCOUNT ON  
DECLARE @AgWinlossHR TABLE(  
	 sporttype smallint,  
	 username nvarchar(30),  
	 bettype smallint,    	 
	 transid bigint,  
	 race varchar(20),  
	 matchcode varchar(30),  
	 homeID int,  
	 awayID int,  
	 hdp1 smallmoney,  
	 hdp2 smallmoney,  
	 Modds smallmoney,
	 odds smallmoney,  
	 status nvarchar(10),  
	 stake money,  
	 winlost money,  
	 awinlost money,
	 mwinlost money,
	 swinlost money,
	 
	 playercomm money,  
	 comm money,
	 acomm money,
	 scomm money,
	 
	 transdate datetime,  
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
	 leagueID int,  
	 matchid int,   
	 IP varchar(20),  
	 betstatus varchar(20),  
	 isNeutral bit,
	 comstatus nvarchar(20), 
	 refno nvarchar(50),
	 showtime NVARCHAR(50)
)  
  
IF @Todate > @MoveBetsDay  
BEGIN  
	IF @Bettype IN (1231,1232,1233,1237,1238)	
		INSERT INTO @AgWinlossHR 
		SELECT  
			r.sporttype,  
			b.username,  
			b.bettype,    	   
			b.transid,  
			b.oddsid as race,  
			o.RacerNum matchcode,  
			o.RacerID homeid,  
			0 awayid,  
			b.hdp1,  
			b.hdp2,  
			modds,
			b.odds,  
			b.status,  
			b.stake,  
			(b.winlost-actual_stake),  
			b.awinlost,
			b.mwinlost,
			b.swinlost,
			b.playercomm,  
			(b.comm - b.playercomm) as comm,
			(b.acomm - b.comm) as acomm ,
			(b.scomm - b.acomm) as scomm,

			b.transdate,  
			'',  
			b.apositiontaking,
			b.mpositiontaking,
			b.spositiontaking, 
			b.discount,
			b.adiscount,
			b.sdiscount, 
			0,
			b.livehomescore,
			b.liveawayscore,  
			r.leagueID,  
			b.matchid,   
			b.IP as IP,
			NULL,  
			CONVERT(BIT,0) as IsNeutral,
			CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END AS comstatus,
			b.refno,
			r.EventTime as showtime
		FROM  
			bettrans b with (nolock)   
			inner join VSOutright o with (nolock) on b.oddsid=o.orid   
			inner join VSRaceInfo r with (nolock) on r.EventID = o.EventID
		WHERE  
			b.Recommend=@CustID AND  
			b.Winlostdate>=@FromDate AND  
			b.Winlostdate<=@ToDate AND  
			b.matchid = @Race AND  
			b.Bettype= @Bettype AND  
			b.Ruben=1  
	  ELSE	  
		INSERT INTO @AgWinlossHR 
		SELECT  
			  l.sporttype,  
			  b.username,  
			  b.bettype,    	   
			  b.transid,  
			  m.groupmatch as race,  
			  m.matchcode,  
			  m.teamID,  
			  0,  
			  b.hdp1,  
			  b.hdp2,  
			  modds,
			  b.odds,  
			  b.status,  
			  b.stake,  
			  (b.winlost-actual_stake),  
			  b.awinlost,
			  b.mwinlost,
			  b.swinlost,
			  b.playercomm,  
			  (b.comm - b.playercomm) as comm,
			  (b.acomm - b.comm) as acomm ,
			  (b.scomm - b.acomm) as scomm,
				
			  b.transdate,  
			  '',  
			  b.apositiontaking,
			  b.mpositiontaking,
			  b.spositiontaking, 
			  b.discount,
			  b.adiscount,
			  b.sdiscount, 
			  0,
			  b.livehomescore,
			  b.liveawayscore,  
			  l.leagueID,  
			  b.matchid,   
			  b.IP as IP,
  			  NULL,  
			  CONVERT(BIT,0) as IsNeutral,
			  CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END AS comstatus,
			  b.refno,
			  '' as showtime
		FROM  
			  bettrans b with (nolock)   
			  inner join outright m with (nolock) on b.matchid=m.orid   
			  inner join League l with (nolock) on m.leagueID=l.leagueID    
		WHERE  
			  b.Recommend=@CustID AND  
			  b.Winlostdate>=@FromDate AND  
			  b.Winlostdate<=@ToDate AND  
			  l.leagueid = @LeagueId And  
			  m.groupmatch = @Race AND  
			  b.Bettype= @Bettype AND  
			  b.Ruben=1 
END  
  
IF @Fromdate <= @MoveBetsDay  
BEGIN  
	IF @Bettype IN (1231,1232,1233,1237,1238)	
		INSERT INTO @AgWinlossHR 
		SELECT  
			r.sporttype,  
			b.username,  
			b.bettype,    	   
			b.transid,  
			b.oddsid as race,  
			o.RacerNum matchcode,  
			o.RacerID homeid,  
			0 awayid,  
			b.hdp1,  
			b.hdp2,  
			modds,
			b.odds,  
			b.status,  
			b.stake,  
			(b.winlost-actual_stake),  
			b.awinlost,
			b.mwinlost,
			b.swinlost,
			b.playercomm,  
			(b.comm - b.playercomm) as comm,
			(b.acomm - b.comm) as acomm ,
			(b.scomm - b.acomm) as scomm,

			b.transdate,  
			'',  
			b.apositiontaking,
			b.mpositiontaking,
			b.spositiontaking, 
			b.discount,
			b.adiscount,
			b.sdiscount, 
			0,
			b.livehomescore,
			b.liveawayscore,  
			r.leagueID,  
			b.matchid,   
			b.IP as IP,
			NULL,  
			CONVERT(BIT,0) as IsNeutral,
			CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END AS comstatus,
			b.refno,
			r.EventTime as showtime
		FROM  
			bettrans14 b with (nolock)   
			inner join VSOutright14 o with (nolock) on b.oddsid=o.orid   
			inner join VSRaceInfo r with (nolock) on r.EventID = o.EventID
		WHERE  
			b.Recommend=@CustID AND  
			b.Winlostdate>=@FromDate AND  
			b.Winlostdate<=@ToDate AND  
			b.matchid = @Race AND  
			b.Bettype= @Bettype AND  
			b.Ruben=1  
	ELSE
	 INSERT INTO @AgWinlossHR SELECT  
	  l.sporttype,  
	  b.username,  
	  b.bettype,    	    
	  b.transid,  
	  m.groupmatch as race,  
	  m.matchcode,  
	  m.teamID,  
	  0,  
	  b.hdp1,  
	  b.hdp2,  
	  modds,
	  b.odds,  
	  b.status,  
	  b.stake,  
	  (b.winlost-actual_stake),  
	  b.awinlost,
	  b.mwinlost,
	  b.swinlost,
	  
	  b.playercomm,  
	  (b.comm - b.playercomm) as comm,
	  (b.acomm - b.comm) as acomm ,
	  (b.scomm - b.acomm) as scomm,
	  b.transdate,  
	  '',  
	  b.apositiontaking,
	  b.mpositiontaking,
	  b.spositiontaking, 
	  b.discount,
	  b.adiscount,
	  b.sdiscount,
	  0,
	  b.livehomescore,
	  b.liveawayscore,    
	  l.leagueID,  
	  b.matchid,   
	  b.IP as IP,
	  NULL,  
	  CONVERT(BIT,0) as IsNeutral,
	  CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END AS comstatus,
	  b.refno,
	  '' as showtime
	 FROM  
	  bettrans14 b with (nolock)   
	  inner join outright14 m with (nolock) on b.matchid=m.orid   
	  inner join League l with (nolock) on m.leagueID=l.leagueID  
	 WHERE  
	  b.Recommend=@CustID AND  
	  b.Winlostdate>=@FromDate AND  
	  b.Winlostdate<=@ToDate AND  
	  l.leagueid = @LeagueId And  
	  m.groupmatch = @Race AND  
	  b.Bettype=@Bettype AND  
	  b.Ruben=1   
END  
  
SELECT * FROM @AgWinlossHR ORDER BY Status, Transid  

DECLARE @Bettransm TABLE(  
	 refno bigint,  
	 finalodds smallmoney,
	 odds smallmoney,  
	 status nvarchar(10),  
	 apositiontaking smallmoney,  
	 mpositiontaking smallmoney,  
	 spositiontaking smallmoney,
	 bettype smallint
	 )   
--get data from bettransm for bettype 33,43
IF @Bettype = 33 OR @Bettype =43
BEGIN	  
	IF @Todate > @MoveBetsDay 
	BEGIN
		INSERT INTO @Bettransm
		SELECT 
			BM.refno, 
			BM.finalodds,
			BM.odds, 
			BM.status, 
			BM.apositiontaking, 
			BM.mpositiontaking, 
			BM.spositiontaking,
			BM.bettype  
		FROM bettransm BM with (NOLOCK)
		INNER JOIN @AgWinlossHR B ON BM.refno = B.transid
		WHERE B.Bettype = @Bettype
	END
		
	IF @Fromdate <= @MoveBetsDay
	BEGIN
		INSERT INTO @Bettransm
		SELECT 
			BM.refno, 
			BM.finalodds,
			BM.odds, 
			BM.status, 
			BM.apositiontaking, 
			BM.mpositiontaking, 
			BM.spositiontaking,
			BM.bettype  
		FROM bettransm14 BM with (NOLOCK)
		INNER JOIN @AgWinlossHR B ON BM.refno = B.transid
		WHERE B.Bettype = @Bettype
	END	
	
	SELECT * FROM @Bettransm ORDER BY RefNo,Bettype
	
END

IF @Bettype = 1233
BEGIN	  
	IF @Todate > @MoveBetsDay 
	BEGIN
		INSERT INTO @Bettransm
		SELECT 
			BM.refno, 
			BM.finalodds,
			BM.odds, 
			BM.status, 
			BM.apositiontaking, 
			BM.mpositiontaking, 
			BM.spositiontaking,
			BM.bettype  
		FROM bettransm BM with (NOLOCK)
		INNER JOIN @AgWinlossHR B ON BM.refno = B.refno
		WHERE B.Bettype = @Bettype
	END
		
	IF @Fromdate <= @MoveBetsDay
	BEGIN
		INSERT INTO @Bettransm
		SELECT 
			BM.refno, 
			BM.finalodds,
			BM.odds, 
			BM.status, 
			BM.apositiontaking, 
			BM.mpositiontaking, 
			BM.spositiontaking,
			BM.bettype  
		FROM bettransm14 BM with (NOLOCK)
		INNER JOIN @AgWinlossHR B ON BM.refno = B.refno
		WHERE B.Bettype = @Bettype
	END	
	
	SELECT * FROM @Bettransm ORDER BY RefNo,Bettype
	
END
	
GO
GRANT EXECUTE ON [dbo].[Age_BetList_SelWinlossHR_Ag] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_BetList_SelWinlossHR_Ag] TO [bodbDownlineNetView]
GO
GRANT VIEW DEFINITION ON [dbo].[Age_BetList_SelWinlossHR_Ag] TO [vnteam]