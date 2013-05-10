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
	@ReportType		TINYINT = 1,  
	@BalanceUpDate	SMALLDATETIME	
WITH RECOMPILE
AS  
/*	
Created: Sophia
Date: 2011-07-14
Task : Consolidated Report
DB: DBAGE/bodb_AGE
Original:  

Revisions:    
	- 20110819@Sophia: Count Negative stake as positive turnover
	- 20111129@Sophia:  .Change the range of Sport book typeid>=121 and typeid<=999
						.Add P2P
	- 20120112@Sophia: Add LiveCasino: Sporttype: 162, bettype: 1101 ->1199
	- 20120801@Sophia: Add Virtual Sports (sporttype = 180 for representing), bettype : 1201 -> 1299
	- 20121029@Johnson: Add new range bettype for sporting solutions : 1301 -> 1334
	- 20130121@Dan: Move sp from DB053/bodb02 to DBAGE/bodb_AGE, add linked server DBSUM for bodb_Summary
	- 20130201@Dan: merge from production --> change to use ExchangeDailyOanda instead of ExchangeDaily
	- 20130308@Elodie: Get new field netTurnover
	
Param's Explanation:
. @Currency: If @Currency <> 0, -2, -3 (RM, US$) then filter this @currency
			 If @Currency = 0, - 2, -3 (RM, US$) then show all currency, then convert to Base currency RM and USD

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
DECLARE	@isSAg	INT,
		@isMAg	INT,
		@isAg	INT,
		@isMem	INT

DECLARE @GroupID INT 
SELECT @GroupID = GRoupID FROM Age_CustGroup WITH (NOLOCK) WHERE CustID = @CustID AND isHeader = 1

SELECT	@isSAg = MAX(CASE WHEN RoleID = 4 THEN 1 ELSE 0 END),
		@isMAg = MAX(CASE WHEN RoleID = 3 THEN 1 ELSE 0 END),
		@isAg  = MAX(CASE WHEN RoleID = 2 THEN 1 ELSE 0 END),
		@isMem = MAX(CASE WHEN RoleID = 1 THEN 1 ELSE 0 END)
FROM	Age_CustGroup WITH (NOLOCK)
WHERE	GroupID = @GroupID 

IF @ShowSB = 1  
	BEGIN  
		--bettrans
		INSERT INTO @TmpCond(Sporttype, Bettype) 
		SELECT 0 AS sporttype, typeid FROM bodb02.dbo.bettype WITH(NOLOCK)
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
		SELECT 161, typeid FROM bodb02.dbo.bettype WITH(NOLOCK) WHERE typeid BETWEEN 81 AND 120
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
		SELECT 162 AS sporttype, typeid FROM bodb02.dbo.bettype WITH(NOLOCK)
		WHERE typeid between 1101 and 1199
	 --Sum_winloss  
		 INSERT INTO @TmpCondSumWL(Sporttype, Bettype)  
		 VALUES(162,0)
	END
	
IF @ShowVS = 1
	BEGIN
	-- bettrans
		INSERT INTO @TmpCond(Sporttype, Bettype)  
		SELECT 180 AS sporttype, typeid FROM bodb02.dbo.bettype WITH(NOLOCK)
		WHERE typeid between 1201 and 1299
	 --Sum_winloss  
		 INSERT INTO @TmpCondSumWL(Sporttype, Bettype)  
		 VALUES(180,0)
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
		FROM	bodb02.dbo.bettrans b WITH(NOLOCK) 
				INNER JOIN @TmpCond t ON b.bettype = t.bettype
		WHERE	winlostdate BETWEEN @fdate AND @tdate
				AND StatusID NOT IN (0,1,101,102,103) 
				AND srecommend IN (SELECT CustID FROM Age_CustGroup WITH (NOLOCK) WHERE GroupID = @GroupID  AND roleID = 4 )	
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
		FROM	bodb02.dbo.bettrans b WITH(NOLOCK) 
				INNER JOIN @TmpCond t ON b.bettype = t.bettype
				INNER JOIN Age_CustGroup d WITH (NOLOCK) ON d.CustID = b.mrecommend AND d.roleID = 3 
		WHERE	winlostdate BETWEEN @fdate AND @tdate
				AND StatusID NOT IN (0,1,101,102,103) 
				AND d.GroupID = @GroupID		
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
		FROM	bodb02.dbo.bettrans b WITH(NOLOCK) 
				INNER JOIN @TmpCond t ON b.bettype = t.bettype
		WHERE	b.winlostdate BETWEEN @fdate AND @tdate
				AND b.StatusID NOT IN (0,1,101,102,103) 
				AND b.recommend IN (SELECT CustID FROM Age_CustGroup WITH (NOLOCK) WHERE GroupID = @GroupID  AND roleID = 2 )				
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
		FROM	bodb02.dbo.bettrans b WITH(NOLOCK) 
				INNER JOIN @TmpCond t ON b.bettype = t.bettype
		WHERE	winlostdate BETWEEN @fdate AND @tdate
				AND StatusID NOT IN (0,1,101,102,103) 
				AND b.custID IN (SELECT CustID FROM Age_CustGroup WITH (NOLOCK) WHERE GroupID = @GroupID  AND roleID = 1 )					
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
	FROM	bodb02.dbo.sum_winloss b WITH(NOLOCK) 		
			INNER JOIN @TmpCondSumWL t ON b.sporttype = t.sporttype AND b.bettype = t.bettype  
	WHERE	winlostdate BETWEEN @fdate AND @tdate
			AND custid IN (SELECT custid fROM Age_CustGroup  WITH (NOLOCK) WHERE GroupID = @GroupID)

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
			AND custid IN (SELECT custid fROM Age_CustGroup  WITH (NOLOCK) WHERE GroupID = @GroupID)

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
				--INNER JOIN @TmpCondSumWL t ON b.sporttype = t.sporttype AND b.bettype = t.bettype 
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
				--INNER JOIN @TmpCondSumWL t ON b.sporttype = t.sporttype AND b.bettype = t.bettype 
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
				--INNER JOIN @TmpCondSumWL t ON b.sporttype = t.sporttype AND b.bettype = t.bettype 
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
			--	INNER JOIN @TmpCondSumWL t ON b.sporttype = t.sporttype AND b.bettype = t.bettype 
		WHERE winlostdate BETWEEN @fdate AND @tdate	AND b.roleid = 1

	END
	DROP TABLE #TmpSum_WinLoss_Old


END

SELECT	CASE WHEN @ReportType = 1 THEN CONVERT(VARCHAR(8),winlostdate,112)  
			 WHEN @ReportType = 2 THEN CONVERT(VARCHAR(6),winlostdate,112)  
			 WHEN @ReportType = 3 THEN sporttype
			 ELSE '0' 
		END AS breakdown
		,username
		,currency
		,roleid
		
		,SUM(turnover) AS turnover
		,SUM(RMturnover) AS RMturnover
		,SUM(USDturnover) AS USDturnover

		,SUM(member_winlost) AS member_winlost
		,SUM(RMmember_winlost) AS RMmember_winlost
		,SUM(USDmember_winlost) AS USDmember_winlost

		,SUM(member_comm) AS member_comm
		,SUM(RMmember_comm) AS RMmember_comm
		,SUM(USDmember_comm) AS USDmember_comm

		,SUM(member_total) AS member_total
		,SUM(RMmember_total) AS RMmember_total
		,SUM(USDmember_total) AS USDmember_total

		,SUM(owner_turnover) AS owner_turnover
		,SUM(RMowner_turnover) AS RMowner_turnover
		,SUM(USDowner_turnover) AS USDowner_turnover
	
		,SUM(owner_winlost) AS owner_winlost
		,SUM(RMowner_winlost) AS RMowner_winlost
		,SUM(USDowner_winlost) AS USDowner_winlost

		,SUM(owner_comm ) AS owner_comm
		,SUM(RMowner_comm ) AS RMowner_comm
		,SUM(USDowner_comm ) AS USDowner_comm

		,SUM(owner_total) AS owner_total
		,SUM(RMowner_total) AS RMowner_total
		,SUM(USDowner_total) AS USDowner_total

		,-SUM(company) AS company
		,-SUM(RMcompany) AS RMcompany
		,-SUM(USDcompany) AS USDcompany

		,SUM(betcount) AS betcount 

FROM	(SELECT   
		C.username, C.currency, winlostdate , sporttype, c.RoleID
		
		,turnover AS turnover
		,turnover * E.MYR AS RMturnover
		,turnover * E.USD AS USDturnover

		,winlost AS member_winlost
		,winlost * E.MYR AS RMmember_winlost
		,winlost * E.USD AS USDmember_winlost

		,playercomm AS member_comm
		,playercomm * E.MYR AS RMmember_comm
		,playercomm * E.USD AS USDmember_comm

		,winlost + playercomm AS member_total
		,(winlost + playercomm) * E.MYR AS RMmember_total
		,(winlost + playercomm) * E.USD AS USDmember_total

		,ownerturnover AS owner_turnover
		,ownerturnover * E.MYR AS RMowner_turnover
		,ownerturnover * E.USD AS USDowner_turnover
		
		,ownerwinlost AS owner_winlost
		,ownerwinlost * E.MYR AS RMowner_winlost
		,ownerwinlost * E.USD AS USDowner_winlost

		,ownercomm - precomm AS owner_comm
		,(ownercomm - precomm) * E.MYR	AS RMowner_comm
		,(ownercomm - precomm )* E.USD	AS USDowner_comm

		,ownerwinlost + ownercomm - precomm AS owner_total
		,(ownerwinlost + ownercomm - precomm )* E.MYR AS RMowner_total
		,(ownerwinlost + ownercomm - precomm) * E.USD AS USDowner_total

		, company  AS company
		, company * E.MYR  AS RMcompany
		, company * E.USD  AS USDcompany

		,betcount AS betcount
		
	FROM @AgencyWinloss A
	INNER JOIN	bodb02.dbo.Customer C WITH (NOLOCK) 
			ON	A.CustID = C.CustID
	INNER JOIN  bodb02.dbo.ExchangeDailyOanda E WITH (NOLOCK) 	
			ON	E.ExchangeDate = A.winlostdate AND E.ExchangeId = C.currency
	WHERE	C.currency = CASE WHEN @currency IN (0, -2, -3 ) THEN C.Currency ELSE @currency END 
) A
GROUP BY 
		CASE WHEN @ReportType = 1 THEN CONVERT(VARCHAR(8),winlostdate,112)  
			 WHEN @ReportType = 2 THEN CONVERT(VARCHAR(6),winlostdate,112)  
			 WHEN @ReportType = 3 THEN sporttype
			 ELSE '0' 
		END 
		,username, currency, roleid

GO
GRANT EXECUTE ON [dbo].[Age_Rpt_ConsolidatedGroup] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_Rpt_ConsolidatedGroup] TO [bodbDownlineNetView]
GO
GRANT VIEW DEFINITION ON [dbo].[Age_Rpt_ConsolidatedGroup] TO [vnteam]