ALTER PROCEDURE [Age_Rpt_WinlossAnalysis_SAg]
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
	@showKeno		BIT = 0,
	@showGD			BIT = 0,
	@showCB 		BIT = 0,
	@ReportType		TINYINT = 1,  
	@BalanceUpDate	SMALLDATETIME	
AS  
/*  Created: Lukas  
	Date: 2011-05-23 
    Task : Super Winloss analysis Report 
    DB: DBAGE/bodb02
   
    Revisions:  
    - 20110801@Sophia: change the range of number game's bettype from 81 to 120
    - 20110805@Sophia: Calculate betcount for Combination MixParlay only for BetID = 0 (main ticket)
    - 20110819@Sophia: Count Negative stake as positive turnover
	- 20110927@Tom: 1. Add Report for P2P Games Sport : 251->253 , Bettype: 72->1000	
					2. Remove parameter @ABSDate ('2011-09-01')
	- 20111130@Sophia: Change the range of Sport book bettype>=121 and bettype<=999				
	- 20120112@Sophia: Add LiveCasino: Sporttype: 162, bettype: 1101 ->1199
	- 20120801@Sophia: Add Virtual Sports (sporttype = 180 for representing), bettype : 1201 -> 1299
	- 20121010@Johnson: Add new range bettype for tennis (from 1301 to 1334) 
	- 20130121@Dan: add linked server DBSUM for bodb_Summary
	- 20140303@Kathy: Apply Keno product (from 1501 -> 1599)
	- 20140925@Sophia: Expand the range of Sporting Solution (1301 -> 1399)[Redmine: #22640]
	- 20150513@Sophia: Apply Gold Deluxe [Redmine: #35278] and support matrix Sporttype - Bettype
	- 20150831@Winnie: Include CB [Redmine: #42409]

	Param's Explanation:
		+ @ReportType: 1-Daily; 2-Monthly; 3-Sports
		+ @CustID SuperID	
*/  
BEGIN
	SET NOCOUNT ON
	
	DECLARE @AgencyWinloss AS TABLE (
										winlostdate DATETIME,
										custid		INT,										
										sporttype	INT,
										turnover	MONEY,
										winlost		MONEY,
										playercomm	MONEY,
										awinlost	MONEY,
										comm		MONEY,
										mwinlost	MONEY,
										acomm		MONEY,
										swinlost	MONEY,
										scomm		MONEY,
										company		MONEY,
										betcount	INT
									)

	DECLARE @TmpCond TABLE(sporttype INT, bettype INT)
	DECLARE @TmpCondSumWL TABLE(sporttype INT, bettype INT)
	
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
		SELECT	251 AS sporttype, Bettype 
		FROM	@SportBettype  
		WHERE	ProductId = 6
		
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

	IF @showCB = 1
	BEGIN
		-- bettrans
		INSERT INTO @TmpCond(Sporttype, Bettype) 
		SELECT	204 AS sporttype, Bettype 
		FROM	@SportBettype  
		WHERE	ProductId = 15

		--Sum_winloss
		INSERT INTO @TmpCondSumWL(sporttype, bettype)
		VALUES(204, 0)
	END	

	IF @ToDate >= @BalanceUpDate
	BEGIN
		INSERT INTO @AgencyWinloss
		SELECT winlostdate, srecommend, t.sporttype
			,SUM(case when b.liveawayscore = 0 and b.bettype in(33,43) then ABS(b.stake)/2 else ABS(b.stake) end)
			,SUM(winlost-actual_stake) winlost
			,SUM(playercomm) playercomm
			,SUM(awinlost) awinlost
			,SUM(comm) comm
			,SUM(mwinlost) mwinlost
			,SUM(acomm) acomm
			,SUM(swinlost) swinlost
			,SUM(scomm) scomm
			,SUM(ISNULL(awinlost,0)) + SUM(ISNULL(mwinlost,0)) + SUM(ISNULL(swinlost,0)) + SUM(ISNULL(scomm,0)) + SUM(ISNULL(winlost,0)-ISNULL(actual_stake,0)) company
			,COUNT(transid) betcount
		FROM bettrans b WITH(NOLOCK) INNER JOIN @TmpCond t ON b.bettype = t.bettype
		WHERE winlostdate BETWEEN @FromDate AND @ToDate
			AND srecommend = @CustID 
			AND StatusID NOT IN (0,1,101,102,103)			
		GROUP BY 
			srecommend, winlostdate, t.sporttype
		
		-- get data from sum_winloss
		IF @BalanceUpDate < @FromDate --if this case occurs then there is no data from sum_winloss_old
		SELECT @BalanceUpDate = @FromDate
		
		INSERT INTO @AgencyWinloss
		SELECT winlostdate, custid, b.sporttype
			,ABS(turnover)
			,winlost
			,playercomm
			,awinlost
			,comm
			,mwinlost
			,acomm
			,swinlost
			,scomm
			,awinlost + mwinlost + swinlost + scomm + winlost
			,betcount
		FROM sum_winloss b WITH(NOLOCK) INNER JOIN @TmpCondSumWL t ON b.sporttype = t.sporttype AND b.bettype = t.bettype  
		WHERE winlostdate BETWEEN @BalanceUpDate AND @ToDate
			AND srecommend = @CustID
			AND roleid = 4

	END
	IF @FromDate < @BalanceUpDate
	BEGIN
	
		IF @Todate >= DATEADD(dd, -1, @BalanceUpDate)
		BEGIN
			SELECT @ToDate = DATEADD(dd, -1, @BalanceUpDate)
		END
		
		INSERT INTO @AgencyWinloss
		SELECT winlostdate, custid, b.sporttype
			,ABS(turnover)
			,winlost
			,playercomm
			,awinlost
			,comm
			,mwinlost
			,acomm
			,swinlost
			,scomm
			,awinlost + mwinlost + swinlost + scomm + winlost
			,betcount
		FROM DBSUM.bodb_Summary.dbo.Sum_WinLoss_Old b WITH(NOLOCK) INNER JOIN @TmpCondSumWL t ON b.sporttype = t.sporttype AND b.bettype = t.bettype  
		WHERE winlostdate BETWEEN @FromDate AND @ToDate
			AND srecommend = @CustID
			AND roleid = 4
	END

	SELECT	CASE WHEN @ReportType = 1 THEN CONVERT(VARCHAR(8),winlostdate,112)  
				 WHEN @ReportType = 2 THEN CONVERT(VARCHAR(6),winlostdate,112)  
				 WHEN @ReportType = 3 THEN sporttype
				 ELSE '0' 
			END AS breakdown
			,SUM(turnover) AS turnover
			,SUM(winlost) AS member_winlost
			,SUM(playercomm) AS member_comm
			,SUM(winlost + playercomm) AS member_total
			,SUM(awinlost) AS agent_winlost
			,SUM(comm - playercomm)	AS agent_comm
			,SUM(awinlost + comm - playercomm) AS agent_total
			,SUM(mwinlost) AS master_winlost
			,SUM(acomm - comm) AS master_comm
			,SUM(mwinlost + acomm - comm) master_total
			,SUM(swinlost) AS super_winlost
			,SUM(scomm - acomm) super_comm			
			,SUM(swinlost + scomm - acomm) AS super_total
			,-SUM(company) AS company
			,SUM(betcount) AS betcount
	FROM @AgencyWinloss
	GROUP BY 
			CASE WHEN @ReportType = 1 THEN CONVERT(VARCHAR(8),winlostdate,112)  
				 WHEN @ReportType = 2 THEN CONVERT(VARCHAR(6),winlostdate,112)  
				 WHEN @ReportType = 3 THEN sporttype
				 ELSE '0' 
			END 
END




GO
GRANT EXECUTE ON [dbo].[Age_Rpt_WinlossAnalysis_SAg] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_Rpt_WinlossAnalysis_SAg] TO [bodbDownlineNetView]
GO
GRANT VIEW DEFINITION ON [dbo].[Age_Rpt_WinlossAnalysis_SAg] TO [vnteam] 