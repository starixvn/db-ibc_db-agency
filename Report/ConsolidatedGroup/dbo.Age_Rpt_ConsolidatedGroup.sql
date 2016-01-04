ALTER PROCEDURE [dbo].[Age_Rpt_ConsolidatedGroup]
	@CustID			INT, 
	@Currency		INT,
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
	@showKeno		BIT = 0,
	@showGD			BIT = 0,
	@showCF			BIT = 0,
	@ReportType		TINYINT = 1,  
	@BalanceUpDate	SMALLDATETIME	
WITH RECOMPILE
AS  
/*	
	Created: Elodie
	Date: 2013-06-12
	Task : Consolidated Report
	DB: DBAGE/bodb02
	Original:  

	Revisions:   
		- 20140303@Kathy: Apply Keno product (from 1501 -> 1599)[Redmine:#12691]
		- 20150513@Sophia: Apply Gold Deluxe [Redmine: #35278] and support matrix Sporttype - Bettype
		- 20151110@Percy: Include CustID in select result [RedmineID: #47201]
		- 20151209@Percy: Add new bettype: Cock Fighting Sabong [Redmine: #48601]
		- 20160104@Percy: Include new bettype range into current RNG Casino [Redmine: #48283]
				
	Param's Explanation:
		. @ReportType:  1: Report by UserName
						2: Report by Daily
						3: Report by Sport
					
		. @Currency: If @Currency <> 0 then filter this @currency
					 If @Currency = 0 then show all currency	
	
	Example: EXEC Age_Rpt_ConsolidatedGroup_xpre @CustID=104769,@Currency=0,@FromDate='Jun  1 2013 12:00:00:000AM',@ToDate='Jun 12 2013 12:00:00:000AM',@showSB=1,@ShowRB=1,@ShowCasino=1,@ShowBI=default,@ShowNG=1,@showP2P=1,@showLiveCasino=1,@showVS=1,@ReportType=1,@BalanceUpDate='Jun  1 2013 12:00:00:000AM'

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
DECLARE @TmpCust TABLE(CustID INT, RoleID INT)

DECLARE	@isSAg	INT,
		@isMAg	INT,
		@isAg	INT,
		@isMem	INT

DECLARE @GroupID INT 
SELECT @GroupID = GRoupID FROM custAccount WITH (NOLOCK) WHERE CustID = @CustID AND IsGroupHeadLine = 1

SELECT	@isSAg = MAX(CASE WHEN RoleID = 4 THEN 1 ELSE 0 END),
		@isMAg = MAX(CASE WHEN RoleID = 3 THEN 1 ELSE 0 END),
		@isAg  = MAX(CASE WHEN RoleID = 2 THEN 1 ELSE 0 END),
		@isMem = MAX(CASE WHEN RoleID = 1 THEN 1 ELSE 0 END)
FROM	custAccount WITH (NOLOCK)
INNER JOIN custInfo c WITH (NOLOCK) ON c.custid = custAccount.custid
WHERE	GroupID = @GroupID 

INSERT INTO @TmpCust (CustID, RoleID)
SELECT c.custid, c.roleid
FROM custAccount WITH (NOLOCK)
INNER JOIN custInfo c WITH (NOLOCK) ON c.custid = custAccount.custid
WHERE groupID = @GroupID


DECLARE @SportBettype TABLE(ProductID INT,  Bettype INT, EventType INT)	
INSERT INTO @SportBettype
EXEC dbo.Acc_SportBettypeMatrix_Sel @mode = 4

IF @ShowSB = 1  
BEGIN  
	--bettrans
	--INSERT INTO @TmpCond(Sporttype, Bettype) 
	--SELECT 0 AS sporttype, typeid FROM bettype WITH(NOLOCK)
	--WHERE (typeid>0 and typeid<31) OR (typeid>=121 and typeid<=999)
	--	OR (typeid>=1301 and typeid<=1399)

	INSERT INTO @TmpCond(Sporttype, Bettype) 
	SELECT	0 AS sporttype, Bettype 
	FROM	@SportBettype  
	WHERE	ProductId = 1
					
	--Sum_winloss  
	INSERT INTO @TmpCondSumWL(sporttype, Bettype)  
	VALUES(0,0)   
END  
IF @ShowCasino = 1  
BEGIN  
	--bettrans
	--INSERT INTO @TmpCond(Sporttype, Bettype)  VALUES(251,71)

	INSERT INTO @TmpCond(Sporttype, Bettype) 
	SELECT	208 AS sporttype, Bettype 
	FROM	@SportBettype  
	WHERE	ProductId = 6 AND Bettype BETWEEN 2101 AND 2199
	UNION ALL
	SELECT	209 AS sporttype, Bettype 
	FROM	@SportBettype  
	WHERE	ProductId = 6 AND Bettype BETWEEN 2201 AND 2299
	UNION ALL
	SELECT	210 AS sporttype, Bettype 
	FROM	@SportBettype  
	WHERE	ProductId = 6 AND Bettype BETWEEN 2301 AND 2399
	UNION ALL
	SELECT  251 AS sporttype, 71 AS Bettype 
		
	--Sum_winloss  
	INSERT INTO @TmpCondSumWL(sporttype, Bettype)  
	VALUES  (208,0), (209,0), (210,0), (251,71)
END
IF @ShowRB = 1  
BEGIN  	
	--bettrans
	--INSERT INTO @TmpCond(Sporttype, Bettype)  
	--SELECT 151, 31
	--UNION ALL
	--SELECT 151, 32
	--UNION ALL
	--SELECT 151, 33

	INSERT INTO @TmpCond(Sporttype, Bettype) 
	SELECT	151 AS sporttype, Bettype 
	FROM	@SportBettype  
	WHERE	ProductId = 2
		
	-- sum_winloss
	INSERT INTO @TmpCondSumWL(Sporttype, Bettype)  
	SELECT 151,0
END
IF @ShowNG = 1  
BEGIN  	
	-- bettrans
	--INSERT INTO @TmpCond(Sporttype, Bettype) 
	--SELECT 161, typeid FROM bettype WITH(NOLOCK) WHERE typeid BETWEEN 81 AND 120

	INSERT INTO @TmpCond(Sporttype, Bettype) 
	SELECT	161 AS sporttype, Bettype 
	FROM	@SportBettype  
	WHERE	ProductId = 3

	-- sum_winloss
	INSERT INTO @TmpCondSumWL(Sporttype, Bettype)  
	VALUES(161,0)  
END  
IF @ShowBI = 1  
BEGIN  	
	-- bettrans
	--INSERT INTO @TmpCond(Sporttype, Bettype)  
	--SELECT 252, 73

	INSERT INTO @TmpCond(Sporttype, Bettype) 
	SELECT	252 AS sporttype, Bettype 
	FROM	@SportBettype  
	WHERE	ProductId = 7

	-- sum_winloss
	INSERT INTO @TmpCondSumWL(Sporttype, Bettype)  
	VALUES(252,73) 
END  
IF @ShowP2P = 1
BEGIN
	-- bettrans
	--INSERT INTO @TmpCond(Sporttype, Bettype)  
	--SELECT 253, 1000

	INSERT INTO @TmpCond(Sporttype, Bettype) 
	SELECT	253 AS sporttype, Bettype 
	FROM	@SportBettype  
	WHERE	ProductId = 9

	--Sum_winloss
	INSERT INTO @TmpCondSumWL(sporttype, Bettype)
	VALUES(253,1000)
END
	
IF @ShowLiveCasino = 1
BEGIN
-- bettrans
	--INSERT INTO @TmpCond(Sporttype, Bettype)  
	--SELECT 162 AS sporttype, typeid FROM bettype WITH(NOLOCK)
	--WHERE typeid between 1101 and 1199

	INSERT INTO @TmpCond(Sporttype, Bettype) 
	SELECT	162 AS sporttype, Bettype 
	FROM	@SportBettype  
	WHERE	ProductId = 4

	--Sum_winloss  
		INSERT INTO @TmpCondSumWL(Sporttype, Bettype)  
		VALUES(162,0)
END
	
IF @ShowVS = 1
BEGIN
-- bettrans
	--INSERT INTO @TmpCond(Sporttype, Bettype)  
	--SELECT 180 AS sporttype, typeid FROM bettype WITH(NOLOCK)
	--WHERE typeid between 1201 and 1299

	INSERT INTO @TmpCond(Sporttype, Bettype) 
	SELECT	180 AS sporttype, Bettype 
	FROM	@SportBettype  
	WHERE	ProductId = 5

	--Sum_winloss  
		INSERT INTO @TmpCondSumWL(Sporttype, Bettype)  
		VALUES(180,0)
END

IF @ShowKeno = 1
BEGIN
-- bettrans
	--INSERT INTO @TmpCond(Sporttype, Bettype)  
	--SELECT 202 AS sporttype, typeid FROM bettype WITH(NOLOCK)
	--WHERE typeid between 1501 and 1599

	INSERT INTO @TmpCond(Sporttype, Bettype) 
	SELECT	202 AS sporttype, Bettype 
	FROM	@SportBettype  
	WHERE	ProductId = 8

	--Sum_winloss  
		INSERT INTO @TmpCondSumWL(Sporttype, Bettype)  
		VALUES(202,0)
END
	
IF @showGD = 1
BEGIN
	-- bettrans
	INSERT INTO @TmpCond(Sporttype, Bettype) 
	SELECT	255 AS sporttype, Bettype 
	FROM	@SportBettype  
	WHERE	ProductId = 12

	--Sum_winloss
	INSERT INTO @TmpCondSumWL(sporttype, bettype)
	VALUES(255, 0)
END	

IF @showCF = 1
BEGIN
	-- bettrans
	INSERT INTO @TmpCond(Sporttype, Bettype) 
	SELECT	206 AS sporttype, Bettype 
	FROM	@SportBettype  
	WHERE	ProductId = 19

	--Sum_winloss
	INSERT INTO @TmpCondSumWL(sporttype, bettype)
	VALUES(206, 1003)
END	
		
IF @tdate >= @BalanceUpDate
BEGIN
	IF @isSAg = 1 
	BEGIN 
		---Super agent 
		INSERT INTO @AgencyWinloss
		SELECT b.winlostdate, b.srecommend, t.sporttype, 4 RoleID
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
				AND srecommend IN (SELECT CustID FROM @TmpCust WHERE roleID = 4)	
		GROUP BY 
				b.srecommend, b.winlostdate, t.sporttype

	END

	IF @isMAg = 1 
	BEGIN
		--- Master agent 
		INSERT INTO @AgencyWinloss
		SELECT b.winlostdate, b.mrecommend, t.sporttype, 3 RoleID 
			,SUM(case when b.liveawayscore = 0 and b.bettype in(33,43) then ABS(b.stake)/2 else ABS(b.stake) end) as TurnOver
			,SUM(winlost-actual_stake) winlost
			,SUM(playercomm) playercomm
			,SUM((case when b.liveawayscore = 0 and b.bettype in(33,43) then ABS(b.stake)/2 else ABS(b.stake) end)*mpositiontaking) ownerturnover
			,SUM(mwinlost) ownerwinlost
			,SUM(acomm) ownercomm 
			,SUM(comm) precomm
			,SUM(ISNULL(awinlost,0)) + SUM(ISNULL(mwinlost,0)) + SUM(ISNULL(acomm,0)) + SUM(ISNULL(winlost,0)-ISNULL(actual_stake,0)) company
			,COUNT(transid) betcount
		FROM	bettrans b WITH(NOLOCK) 
				INNER JOIN @TmpCond t ON b.bettype = t.bettype
		WHERE	winlostdate BETWEEN @fdate AND @tdate
				AND StatusID NOT IN (0,1,101,102,103) 
				AND mrecommend IN (SELECT CustID FROM @TmpCust WHERE roleID = 3)		
		GROUP BY 
			b.mrecommend, b.winlostdate, t.sporttype 
	END

	IF @isAg = 1
	BEGIN
		--- Agent 
		INSERT INTO @AgencyWinloss
		SELECT b.winlostdate,  b.recommend, t.sporttype, 2 RoleID
			,SUM(case when b.liveawayscore = 0 and b.bettype in(33,43) then ABS(b.stake)/2 else ABS(b.stake) end) as TurnOver
			,SUM(winlost-actual_stake) winlost
			,SUM(playercomm) playercomm
			,SUM((case when b.liveawayscore = 0 and b.bettype in(33,43) then ABS(b.stake)/2 else ABS(b.stake) end)*apositiontaking) ownerturnover
			,SUM(awinlost) ownerwinlost
			,SUM(comm) ownercomm
			,SUM(playercomm) precomm
			,SUM(ISNULL(awinlost,0)) + SUM(ISNULL(comm,0)) + SUM(ISNULL(winlost,0)-ISNULL(actual_stake,0)) company
			,COUNT(transid) betcount
		FROM	bettrans b WITH(NOLOCK) 
				INNER JOIN @TmpCond t ON b.bettype = t.bettype
		WHERE	b.winlostdate BETWEEN @fdate AND @tdate
				AND b.StatusID NOT IN (0,1,101,102,103) 
				AND recommend IN (SELECT CustID FROM @TmpCust WHERE roleID = 2)
		GROUP BY 
			b.recommend, b.winlostdate, t.sporttype
	END

	IF @isMem = 1
	BEGIN
		--- member
		INSERT INTO @AgencyWinloss
		SELECT b.winlostdate, b.CustID, t.sporttype, 1 RoleID 
			,SUM(case when b.liveawayscore = 0 and b.bettype in(33,43) then ABS(b.stake)/2 else ABS(b.stake) end) as TurnOver
			,0 as winlost
			,0 as playercomm
			,SUM(case when b.liveawayscore = 0 and b.bettype in(33,43) then ABS(b.stake)/2 else ABS(b.stake) end) as ownerturnover
			,SUM(winlost-actual_stake) ownerwinlost
			,SUM(playercomm) as ownercomm
			,0 as precomm
			,SUM(ISNULL(winlost,0)-ISNULL(actual_stake,0)) +SUM(playercomm) company
			,COUNT(transid) betcount
		FROM	bettrans b WITH(NOLOCK) 
				INNER JOIN @TmpCond t ON b.bettype = t.bettype
		WHERE	winlostdate BETWEEN @fdate AND @tdate
				AND StatusID NOT IN (0,1,101,102,103) 
				AND b.custid IN (SELECT CustID FROM @TmpCust WHERE roleID = 1)
		GROUP BY 
			b.CustID, b.winlostdate, t.sporttype 
	END


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
			AND custid IN (SELECT custid fROM @TmpCust)

	---Super  
	IF @isSAg = 1
	BEGIN
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
				AND b.roleid = 4
	END 
	
	---Master 
	IF @isMAg = 1 
	BEGIN
		INSERT INTO @AgencyWinloss
		SELECT b.winlostdate, b.custid, b.sporttype, b.RoleID
			,b.turnover
			,winlost
			,playercomm		
			,isnull(netTurnover,0) as ownerturnover
			,mwinlost as ownerwinlost 
			,acomm as ownercomm
			,comm as precomm
			,awinlost + mwinlost + acomm + winlost
			,betcount
		FROM #Tmpsum_winloss b WITH(NOLOCK) 							 
		WHERE b.winlostdate BETWEEN @BalanceUpDate AND @tdate AND b.roleid = 3
	END	 
	---Agent  
	IF @isAg =1 
	BEGIN
		INSERT INTO @AgencyWinloss
		SELECT b.winlostdate, b.custid, b.sporttype, b.RoleID
			,b.turnover
			,winlost
			,playercomm		
			,isnull(netTurnover,0) as ownerturnover
			,awinlost as ownerwinlost 
			,comm as ownercomm
			,playercomm as precomm
			,awinlost + comm + winlost
			,betcount
		FROM #Tmpsum_winloss b WITH(NOLOCK)  							 
		WHERE b.winlostdate BETWEEN @BalanceUpDate AND @tdate AND b.roleid = 2
	END		 

	---member  
	IF @isMem =1
	BEGIN
		INSERT INTO @AgencyWinloss
		SELECT b.winlostdate, b.custid, b.sporttype, b.RoleID
			,b.turnover
			,0 as winlost
			,0 as playercomm	
			,isnull(b.turnover,0) as ownerturnover
			,winlost as ownerwinlost 
			,playercomm as ownercomm
			,0 as precomm
			,winlost + playercomm
			,betcount
		FROM #Tmpsum_winloss b WITH(NOLOCK) 						 
		WHERE b.winlostdate BETWEEN @BalanceUpDate AND @tdate AND b.roleid = 1
	END
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
			AND custid IN (SELECT custid fROM @TmpCust)

--Super	
	IF @isSAg = 1
	BEGIN
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
				AND b.roleid = 4
	END
		 
--Master
	IF @isMAg = 1	
	BEGIN
		INSERT INTO @AgencyWinloss
		SELECT winlostdate, b.custid, b.sporttype,b.RoleID
			,b.turnover
			,winlost
			,playercomm
			,isnull(netTurnover,0) as ownerturnover
			,mwinlost as ownerwinlost 
			,acomm as ownercomm
			,comm as precomm
			,awinlost + mwinlost + acomm + winlost
			,betcount
		FROM	#TmpSum_WinLoss_Old b WITH(NOLOCK) 
		WHERE	winlostdate BETWEEN @fdate AND @tdate	
				AND b.roleid = 3
	END
--Agent	
	IF @isAg = 1
	BEGIN 
		INSERT INTO @AgencyWinloss
		SELECT winlostdate, b.custid, b.sporttype,b.RoleID
			,b.turnover
			,winlost
			,playercomm
			,isnull(netTurnover,0) as ownerturnover
			,awinlost as ownerwinlost 
			,comm as ownercomm
			,playercomm as precomm
			,awinlost + comm + winlost
			,betcount
		FROM	#TmpSum_WinLoss_Old b WITH(NOLOCK) 
		WHERE	winlostdate BETWEEN @fdate AND @tdate	
				AND b.roleid = 2
	END 
--Member	
	IF @isMem = 1
	BEGIN
		INSERT INTO @AgencyWinloss
		SELECT winlostdate, b.custid, b.sporttype,b.RoleID
			,b.turnover
			,0 as winlost
			,0 as playercomm
			,isnull(b.turnover,0) as ownerturnover
			,winlost as ownerwinlost 
			,playercomm as ownercomm
			,0 as precomm
			,winlost + playercomm
			,betcount
		FROM #TmpSum_WinLoss_Old b WITH(NOLOCK) 
		WHERE winlostdate BETWEEN @fdate AND @tdate	AND b.roleid = 1

	END
	DROP TABLE #TmpSum_WinLoss_Old


END

SELECT	CASE WHEN @ReportType = 1 THEN custID  
			 WHEN @ReportType = 2 THEN CONVERT(VARCHAR(8),winlostdate,112)  
			 WHEN @ReportType = 3 THEN sporttype
			 ELSE '0' 
		END AS breakdown
		,custID 
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
	WHERE	C.currency = CASE WHEN @currency = 0 THEN C.Currency ELSE @currency END 
) A
GROUP BY 
		CASE WHEN @ReportType = 1 THEN custID
			 WHEN @ReportType = 2 THEN CONVERT(VARCHAR(8),winlostdate,112)  
			 WHEN @ReportType = 3 THEN sporttype
			 ELSE '0' 
		END 
		,custID, username, currency, roleid


GO

SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO


GO 
 GRANT VIEW DEFINITION ON [dbo].[Age_Rpt_ConsolidatedGroup] TO [vnteam]
GO 
 GRANT EXECUTE ON [dbo].[Age_Rpt_ConsolidatedGroup] TO [bodbDownlineNetView]
GO 
 GRANT EXECUTE ON [dbo].[Age_Rpt_ConsolidatedGroup] TO [bodbDownlineNet]
GO 
