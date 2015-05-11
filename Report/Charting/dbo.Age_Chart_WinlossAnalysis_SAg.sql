  ALTER PROCEDURE [Age_Chart_WinlossAnalysis_SAg]
	@agentID		INT,	
	@fromdate		DATETIME,
	@todate			DATETIME,	
	@ShowSB			BIT = 1,
	@showCasino		BIT = 0,
	@showRB			BIT = 0,
	@showNG			BIT = 0,
	@showBI			BIT = 0,
	@showP2P		BIT = 0,
	@showLiveCasino BIT = 0,
	@showVS			BIT = 0,
	@showKeno		BIT = 0,
	@showGD			BIT = 0,
	@BalanceUpDate	DATETIME
AS	
/*
	Created: Johnson
	Date: 11Nov2011
	Task: get report winloss by month for charting
	DB: DBAGE/BODB02
	
	Revisions:
		- 20111129@Sophia: Change the range of Sport book typeid>=121 and typeid<=999
		- 20120120@Sophia: Add show time for LiveCasino: Sporttype: 162, bettype: 1101 ->1199
		- 20120801@Sophia: Add Virtual Sports (sporttype = 180 for representing), bettype : 1201 -> 1299
		- 20121010@Johnson: Add new range bettypes for tennis (from 1301 to 1334)
		- 20130121@Dan: add linked server DBSUM for bodb_Summary
		- 20140303@Kathy: Apply Keno product (from 1501 -> 1599)
		- 20140925@Sophia: Expand the range of Sporting Solution (1301 -> 1399)[Redmine: #22640]
		- 20150511@Sophia: Apply Gold Deluxe [Redmine: #35278] and support matrix Sporttype - Bettype


	Parameters Explanation:
*/
SET NOCOUNT ON
	
	DECLARE @AgencyWinloss AS TABLE (
										winlostdate DATETIME,																											
										turnover	MONEY,																				
										winlost	MONEY
									)

	--DECLARE @TmpCond TABLE(sporttype INT, bettype INT)
	DECLARE @TmpCondSumWL TABLE(sporttype INT, bettype INT)

	DECLARE @SportBettype TABLE(ProductID INT, Sporttype INT DEFAULT (0) , Bettype INT, EventType INT, SubProduct VARCHAR(500) DEFAULT ('') )	
	DECLARE @ProductPrefix VARCHAR(100) = '-'
	
	IF @ShowSB = 1  
	BEGIN  
		--bettrans
		--INSERT INTO @TmpCond(Sporttype, Bettype) 
		--SELECT 0 AS sporttype, typeid FROM bettype WITH(NOLOCK)
		--WHERE (typeid>0 and typeid<31) OR (typeid>=121 and typeid<=999)
		--OR (typeid >= 1301 and typeid <= 1399)

		INSERT INTO @SportBettype (ProductID, Bettype, EventType)
		EXEC dbo.Acc_SportBettypeMatrix_Sel @mode = 4, @ProductPrefix = 'SB'


		--Sum_winloss  
		INSERT INTO @TmpCondSumWL(sporttype, Bettype)  
		VALUES(0,0)   
	END  
	IF @ShowCasino = 1  
	BEGIN  
		--bettrans
		--INSERT INTO @TmpCond(Sporttype, Bettype)  VALUES(251,71)

		SET @ProductPrefix = @ProductPrefix + ',CS'
		
		--Sum_winloss  
		INSERT INTO @TmpCondSumWL(sporttype, Bettype)  
		VALUES(251,71)  
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

		SET @ProductPrefix = @ProductPrefix + ',RB'
		
		-- sum_winloss
		INSERT INTO @TmpCondSumWL(Sporttype, Bettype)  
		SELECT 151,0
	END
	IF @ShowNG = 1  
	BEGIN  	
		-- bettrans
		--INSERT INTO @TmpCond(Sporttype, Bettype) 
		--SELECT 161, typeid FROM bettype WITH(NOLOCK) WHERE typeid BETWEEN 81 AND 120

		SET @ProductPrefix = @ProductPrefix + ',NG'

		-- sum_winloss
		INSERT INTO @TmpCondSumWL(Sporttype, Bettype)  
		VALUES(161,0)  
	END  
	IF @ShowBI = 1  
	BEGIN  	
		-- bettrans
		--INSERT INTO @TmpCond(Sporttype, Bettype)  
		--SELECT 252, 73

		SET @ProductPrefix = @ProductPrefix + ',BG'

		-- sum_winloss
		INSERT INTO @TmpCondSumWL(Sporttype, Bettype)  
		VALUES(252,73) 
	END  
	IF @ShowP2P = 1
	BEGIN
		-- bettrans
		--INSERT INTO @TmpCond(Sporttype, Bettype)  
		--SELECT 253, 1000

		SET @ProductPrefix = @ProductPrefix + ',P2P'

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

		SET @ProductPrefix = @ProductPrefix + ',LC'

	 --Sum_winloss  
		 INSERT INTO @TmpCondSumWL(Sporttype, Bettype)  
		 VALUES(162,0)
	END
	
	IF @ShowVS = 1
	BEGIN
	---- bettrans
	--	INSERT INTO @TmpCond(Sporttype, Bettype)  
	--	SELECT 180 AS sporttype, typeid FROM bettype WITH(NOLOCK)
	--	WHERE typeid between 1201 and 1299

	SET @ProductPrefix = @ProductPrefix + ',VS'

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

		SET @ProductPrefix = @ProductPrefix + ',KN'

	 --Sum_winloss  
		 INSERT INTO @TmpCondSumWL(Sporttype, Bettype)  
		 VALUES(202,0)
	END

	IF @showGD = 1
	BEGIN
		-- bettrans
		SET @ProductPrefix = @ProductPrefix + ',GD'

		--Sum_winloss
		INSERT INTO @TmpCondSumWL(sporttype, bettype)
		VALUES(255, 0)
	END

	---insert data to table Sporttype - bettype
	INSERT INTO @SportBettype (ProductID, Sporttype, Bettype, EventType, SubProduct)
	EXEC dbo.Acc_SportBettypeMatrix_Sel @mode = 2, @ProductPrefix = @ProductPrefix
	
		
	IF @ToDate >= @BalanceUpDate
	BEGIN
		INSERT INTO @AgencyWinloss
		SELECT winlostdate
			,SUM(CASE WHEN b.liveawayscore = 0 AND b.bettype IN(33,43) THEN ABS(b.stake)/2 ELSE ABS(b.stake) END) 			
			,SUM(swinlost + scomm - acomm) winlost			
		FROM bettrans b WITH(NOLOCK) 
			INNER JOIN @SportBettype t ON b.bettype = t.bettype
		WHERE winlostdate BETWEEN @FromDate AND @ToDate
			AND srecommend = @AgentID 
			AND StatusID NOT IN (0,1,101,102,103)			
		GROUP BY winlostdate
		
		-- get data from sum_winloss
		IF @BalanceUpDate < @FromDate --if this case occurs then there is no data from sum_winloss_old
			SELECT @BalanceUpDate=@FromDate
		
		INSERT INTO @AgencyWinloss
		SELECT winlostdate
			,ABS(turnover)		
			,swinlost + scomm - acomm
		FROM sum_winloss b WITH(NOLOCK) 
			INNER JOIN @TmpCondSumWL t ON b.sporttype = t.sporttype AND b.bettype = t.bettype  
		WHERE winlostdate BETWEEN @BalanceUpDate AND @ToDate
			AND srecommend = @AgentID
			AND roleid = 4
	END
	
	IF @FromDate < @BalanceUpDate
	BEGIN
		IF @Todate >= DATEADD(dd, -1, @BalanceUpDate)		
			SELECT @ToDate = DATEADD(dd, -1, @BalanceUpDate)
		
		
		INSERT INTO @AgencyWinloss
		SELECT winlostdate
			,ABS(turnover)
			,swinlost + scomm - acomm
		FROM DBSUM.bodb_Summary.dbo.Sum_WinLoss_Old b WITH(NOLOCK) 
			INNER JOIN @TmpCondSumWL t ON b.sporttype = t.sporttype AND b.bettype = t.bettype  
		WHERE winlostdate BETWEEN @FromDate AND @ToDate
			AND srecommend = @AgentID  
			AND mrecommend = mrecommend  
			AND recommend = recommend  
			AND b.sporttype = b.sporttype  
			AND b.bettype= b.bettype 
			AND roleid = 4
	END
	
	SELECT	CONVERT(VARCHAR(6),winlostdate,112) as winlostdate
			,SUM(turnover) AS turnover			
			,SUM(winlost) AS winlost			
	FROM @AgencyWinloss
	GROUP BY CONVERT(VARCHAR(6),winlostdate,112)
	ORDER BY CONVERT(VARCHAR(6),winlostdate,112) ASC
			 
	
		 
	
GO
GRANT VIEW DEFINITION ON [dbo].[Age_Chart_WinlossAnalysis_SAg] TO [vnteam]
GO
GRANT EXECUTE ON [dbo].[Age_Chart_WinlossAnalysis_SAg] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_Chart_WinlossAnalysis_SAg] TO [bodbDownlineNetView]
