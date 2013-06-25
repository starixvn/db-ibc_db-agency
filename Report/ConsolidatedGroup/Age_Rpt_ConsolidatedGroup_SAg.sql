ALTER PROCEDURE [dbo].[Age_Rpt_ConsolidatedGroup_SAg]
	@CustID			INT, 	
	@FromDate		SMALLDATETIME,  
	@ToDate			SMALLDATETIME,   
	@showSB			BIT = 1,  
	@ShowRB			BIT = 0,  
	@ShowCasino		BIT = 0,
	@ShowBI			BIT = 0,
	@ShowNG			BIT = 0,	
	@showP2P		BIT = 0,
	@showLiveCasino BIT = 0,
	@showVS			BIT = 0,
	@ReportType		TINYINT = 1,  
	@BalanceUpDate	SMALLDATETIME	
AS  
/*	
	Created: Elodie
	Date: 2013-06-13
	Task : Consolidated Report for super
	DB: DBAGE/bodb02
	Original:  

	Revisions:    
				
	Param's Explanation:
		. @ReportType:  1: Report by UserName
						2: Report by Daily
						3: Report by Sport							
	
	Example: EXEC Age_Rpt_ConsolidatedGroup_SAg @CustID=1867721,@RoleID=4,@FromDate='Jun  1 2013 12:00:00:000AM',@ToDate='Jun 12 2013 12:00:00:000AM',@showSB=1,@ShowRB=1,@ShowCasino=1,@ShowBI=default,@ShowNG=1,@showP2P=1,@showLiveCasino=1,@showVS=1,@ReportType=1,@BalanceUpDate='Jun  1 2013 12:00:00:000AM'

*/  
SET NOCOUNT ON
	
DECLARE @fdate SMALLDATETIME, @tdate SMALLDATETIME
SELECT @fdate = @FromDate, @tdate = @ToDate

DECLARE @AgencyWinloss AS TABLE (
									winlostdate DATETIME,
									custid		INT,										
									sporttype	INT,
									RoleID		INT,
									turnover	MONEY,
									winlost		MONEY,
									playercomm	MONEY,
									ownerturnover MONEY,
									ownerwinlost	MONEY,
									ownercomm		MONEY,
									precomm		MONEY,
									company		MONEY,
									betcount	INT
								)

DECLARE @TmpCond TABLE(sporttype INT, bettype INT)
DECLARE @TmpCondSumWL TABLE(sporttype INT, bettype INT)

IF @ShowSB = 1  
	BEGIN  
		--bettrans
		INSERT INTO @TmpCond(Sporttype, Bettype) 
		SELECT 0 AS sporttype, typeid FROM bettype WITH(NOLOCK)
		WHERE (typeid>0 and typeid<31) OR (typeid>=121 and typeid<=999) OR (typeid between 1301 and 1334)

		--Sum_winloss  
		INSERT INTO @TmpCondSumWL(sporttype, Bettype)  
		VALUES(0,0)   
	END  
IF @ShowCasino = 1  
	BEGIN  
		--bettrans
		INSERT INTO @TmpCond(Sporttype, Bettype)  VALUES(251,71)
		
		--Sum_winloss  
		INSERT INTO @TmpCondSumWL(sporttype, Bettype)  
		VALUES(251,71)  
	END
IF @ShowRB = 1  
	BEGIN  	
		--bettrans
		INSERT INTO @TmpCond(Sporttype, Bettype)  
		SELECT 151, 31
		UNION ALL
		SELECT 151, 32
		UNION ALL
		SELECT 151, 33
		
		-- sum_winloss
		INSERT INTO @TmpCondSumWL(Sporttype, Bettype)  
		SELECT 151,0
	END  	
IF @ShowNG = 1  
	BEGIN  	
		-- bettrans
		INSERT INTO @TmpCond(Sporttype, Bettype) 
		SELECT 161, typeid FROM bettype WITH(NOLOCK) WHERE typeid BETWEEN 81 AND 120
		-- sum_winloss
		INSERT INTO @TmpCondSumWL(Sporttype, Bettype)  
		VALUES(161,0)  
	END  
IF @ShowBI = 1  
	BEGIN  	
		-- bettrans
		INSERT INTO @TmpCond(Sporttype, Bettype)  
		SELECT 252, 73
		-- sum_winloss
		INSERT INTO @TmpCondSumWL(Sporttype, Bettype)  
		VALUES(252,73) 
	END  
IF @ShowP2P = 1
	BEGIN
		-- bettrans
		INSERT INTO @TmpCond(Sporttype, Bettype)  
		SELECT 253, 1000
		--Sum_winloss
		INSERT INTO @TmpCondSumWL(sporttype, Bettype)
		VALUES(253,1000)
	END

IF @ShowLiveCasino = 1
	BEGIN
	-- bettrans
		INSERT INTO @TmpCond(Sporttype, Bettype)  
		SELECT 162 AS sporttype, typeid FROM bettype WITH(NOLOCK)
		WHERE typeid between 1101 and 1199
	 --Sum_winloss  
		 INSERT INTO @TmpCondSumWL(Sporttype, Bettype)  
		 VALUES(162,0)
	END
	
IF @ShowVS = 1
	BEGIN
	-- bettrans
		INSERT INTO @TmpCond(Sporttype, Bettype)  
		SELECT 180 AS sporttype, typeid FROM bettype WITH(NOLOCK)
		WHERE typeid between 1201 and 1299
	 --Sum_winloss  
		 INSERT INTO @TmpCondSumWL(Sporttype, Bettype)  
		 VALUES(180,0)
	END
		
IF @tdate >= @BalanceUpDate
BEGIN	
	INSERT INTO @AgencyWinloss
	SELECT b.winlostdate
		,b.mrecommend			
		,t.sporttype, 3
		,SUM(case when b.liveawayscore = 0 and b.bettype in(33,43) then ABS(b.stake)/2 else ABS(b.stake) end) as TurnOver
		,SUM(winlost-actual_stake) winlost
		,SUM(playercomm) playercomm
		,SUM((case when b.liveawayscore = 0 and b.bettype in(33,43) then ABS(b.stake)/2 else ABS(b.stake) end)*spositiontaking) ownerturnover
		,SUM(swinlost) ownerwinlost
		,SUM(scomm) ownercomm
		,SUM(acomm) precomm
		,SUM(ISNULL(awinlost,0)) + SUM(ISNULL(mwinlost,0)) + SUM(ISNULL(swinlost,0)) + SUM(ISNULL(scomm,0)) + SUM(ISNULL(winlost,0)-ISNULL(actual_stake,0)) company
		,COUNT(transid) betcount
	FROM	bettrans b WITH(NOLOCK) 
			INNER JOIN @TmpCond t ON b.bettype = t.bettype
	WHERE	winlostdate BETWEEN @fdate AND @tdate
			AND StatusID NOT IN (0,1,101,102,103) 
			AND @CustID = b.srecommend									 
	GROUP BY 
			b.mrecommend					
			,b.winlostdate, t.sporttype

	--**** get data from sum_winloss
	IF @BalanceUpDate < @fdate --if this case occurs then there is no data from sum_winloss_old
		SELECT @BalanceUpDate = @fdate

	---Insert tmptable
	CREATE TABLE #Tmpsum_winloss ( winlostdate Datetime, custid int, RoleID int, 
							  sporttype smallint, bettype smallint, BetCount int,
							  turnover Money, playercomm Money, scomm Money, acomm Money, Comm Money,
							  awinlost Money, mwinlost Money, swinlost Money, winlost Money, netTurnover Money
							)

	INSERT INTO #Tmpsum_winloss
	SELECT      b.winlostdate, b.custid,  b.RoleID, 
				b.sporttype, b.bettype, b.betCount,
				ABS(b.turnover) as turnover, b.playercomm, b.scomm, b.acomm, b.Comm,
				b.awinlost, b.mwinlost, b.swinlost, b.winlost, ABS(b.netTurnover) as netTurnover
	FROM	sum_winloss b WITH(NOLOCK) 		
			INNER JOIN @TmpCondSumWL t ON b.sporttype = t.sporttype AND b.bettype = t.bettype  
	WHERE	winlostdate BETWEEN @fdate AND @tdate
			AND @CustID = b.srecommend								
			AND roleid = 3

	INSERT INTO @AgencyWinloss
	SELECT b.winlostdate, b.custid, b.sporttype, b.RoleID
		,b.turnover
		,winlost
		,playercomm		
		,isnull(netTurnover,0) as ownerturnover
		,swinlost as ownerwinlost 
		,scomm as ownercomm
		,acomm as precomm
		,awinlost + mwinlost + swinlost + scomm + winlost
		,betcount
	FROM #Tmpsum_winloss b WITH(NOLOCK) 
	WHERE b.winlostdate BETWEEN @BalanceUpDate AND @tdate		

	DROP TABLE #TmpSum_WinLoss
END
	 
IF @fdate < @BalanceUpDate
BEGIN

	IF @tdate >= DATEADD(dd, -1, @BalanceUpDate)
	BEGIN
		SELECT @tdate = DATEADD(dd, -1, @BalanceUpDate)
	END

	---Insert tmptable
	CREATE TABLE #TmpSum_WinLoss_Old ( winlostdate Datetime, custid int, RoleID int, 
								  sporttype smallint, bettype smallint, BetCount int,
								  turnover Money, playercomm Money, scomm Money, acomm Money, Comm Money,
								  awinlost Money, mwinlost Money, swinlost Money, winlost Money, netTurnover Money
								)

	INSERT INTO #TmpSum_WinLoss_Old
	SELECT      b.winlostdate, b.custid,  b.RoleID, 
				b.sporttype, b.bettype, b.betCount,
				ABS(b.turnover) as turnover, b.playercomm, b.scomm, b.acomm, b.Comm,
				b.awinlost, b.mwinlost, b.swinlost, b.winlost, ABS(b.netTurnover) as netTurnover
	FROM	DBSUM.bodb_Summary.dbo.Sum_WinLoss_Old b WITH(NOLOCK) 		
			INNER JOIN @TmpCondSumWL t ON b.sporttype = t.sporttype AND b.bettype = t.bettype  
	WHERE	winlostdate BETWEEN @fdate AND @tdate
			AND @CustID = b.srecommend								
			AND roleid = 3
	
	INSERT INTO @AgencyWinloss
	SELECT b.winlostdate, b.custid, b.sporttype,b.RoleID
		,b.turnover
		,winlost
		,playercomm
		,isnull(netTurnover,0) as ownerturnover
		,swinlost as ownerwinlost 
		,scomm as ownercomm
		,acomm as precomm
		,awinlost + mwinlost + swinlost + scomm + winlost
		,betcount
	FROM	#TmpSum_WinLoss_Old b WITH(NOLOCK) 	   
	WHERE	b.winlostdate BETWEEN @fdate AND @tdate 

	DROP TABLE #TmpSum_WinLoss_Old
END

SELECT	CASE WHEN @ReportType = 1 THEN custID  
			 WHEN @ReportType = 2 THEN CONVERT(VARCHAR(8),winlostdate,112)  
			 WHEN @ReportType = 3 THEN sporttype
			 ELSE '0' 
		END AS breakdown
		,username
		,currency
		,roleid
		
		,SUM(turnover) AS turnover
		,SUM(member_winlost) AS member_winlost
		,SUM(member_comm) AS member_comm
		,SUM(member_total) AS member_total
		,SUM(owner_turnover) AS owner_turnover	
		,SUM(owner_winlost) AS owner_winlost
		,SUM(owner_comm ) AS owner_comm
		,SUM(owner_total) AS owner_total
		,-SUM(company) AS company
		,SUM(betcount) AS betcount 

FROM	(SELECT   
		C.custID, C.username, C.currency, winlostdate , sporttype, c.RoleID
		
		,turnover AS turnover
		,winlost AS member_winlost
		,playercomm AS member_comm
		,winlost + playercomm AS member_total
		,ownerturnover AS owner_turnover		
		,ownerwinlost AS owner_winlost
		,ownercomm - precomm AS owner_comm
		,ownerwinlost + ownercomm - precomm AS owner_total
		,company  AS company
		,betcount AS betcount
		
	FROM @AgencyWinloss A
	INNER JOIN	Customer C WITH (NOLOCK) ON A.CustID = C.CustID	
) A
GROUP BY 
		CASE WHEN @ReportType = 1 THEN custID
			 WHEN @ReportType = 2 THEN CONVERT(VARCHAR(8),winlostdate,112)  
			 WHEN @ReportType = 3 THEN sporttype
			 ELSE '0' 
		END 
		,username, currency, roleid	

GO
GRANT EXECUTE ON [dbo].[Age_Rpt_ConsolidatedGroup_SAg] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_Rpt_ConsolidatedGroup_SAg] TO [bodbDownlineNetView]
GO
GRANT VIEW DEFINITION ON [dbo].[Age_Rpt_ConsolidatedGroup_SAg] TO [vnteam] 