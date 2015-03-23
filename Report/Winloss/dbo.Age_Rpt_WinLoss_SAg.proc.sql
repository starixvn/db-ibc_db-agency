ALTER PROCEDURE [Age_Rpt_WinLoss_SAg]  
 @CustID				INT --srecommend  
 ,@FromDate				SMALLDATETIME
 ,@ToDate				SMALLDATETIME  
 ,@showSB				BIT = 1
 ,@showCasino			BIT = 0
 ,@showP2P				BIT = 0
 ,@showRB				BIT = 0  
 ,@showFI				BIT = 0  
 ,@showNG				BIT = 0  
 ,@showBI				BIT = 0  
 ,@showLiveCasino		BIT = 0
 ,@showVS				BIT = 0
 ,@showProgressiveBonus BIT =0
 ,@showKeno				BIT = 0
 ,@BalanceUpDay			SMALLDATETIME  
  
WITH RECOMPILE  
  
AS  

/*  
 Created:   
 Task :   
 DB: DBAGE/bodb02
 Original SP: Rpt_MAgentWinlost  
 Revisions:  
  - UPDATED 2009-02-25: For Casino (Tuan)  
  - 20090523@AnhPham: filtering data by HR, FI  
  - 20090611@Phuc: exclude turnover in case place refund(for HR each way).          
  - 20090701@AnhPham: include gross commision for all bet types without casino bet types  
  - 20091019@Phuc: write log and move table Sum_WinLoss_Old to database bodb_Summary.  
  - 20091117@Henry: optimize when joining with table sum_winloss and sum_winloss_old  
  - 20091126@Jamie: Including Casino Grosscomm  
  -- 20100527@Henry: Change to use StatusID instead of Status in WHERE statement  
  - 20100617@Jamie: Use  new index hint index=IX_srecommend  
  - 2010-627@Thien: put WITH RECOMPILE  
  - 20100902@Kiwi: Turn back to use bettype directly from bettrans rather than @TmpCond table  
  - 20100904@Jacob: Add two parameters: @showBI, @showNG, calculate winloss base on bingo and number game
  - 20110303@Lukas: change param: @ShowHR -> @ShowRB
  - 20110801@Sophia: change the range of number game's bettype from 81 to 120
  - 20110822@Sophia: Count Negative stake as positive turnover  
  - 20110907@Tom: Change range of bet type : 0->30, 
				apply new bet type 1st correct score on Sport Books	  
  - 20110927@Tom: 1. Edit Report for P2P Games Sport : 251->253 , Bettype: 72->1000	
				  2. Remove parameter @ABSDate ('2011-09-01')
  - 20111130@Sophia: Change the range of Sport book bettype>=121 and bettype<=999			
  - 20120112@Sophia: Add LiveCasino: Sporttype: 162, bettype: 1101 ->1199
  - 20120608@Elodie: Change the gross commission for P2P
  - 20120807@Sophia:  .Add new parametter @showVS for Virtual Sports (sporttype = 180 for representing)
							.Remove Financial product
  - 20121024@Johnson: Add new range bettypes for tennis (from 1301 to 1334)
  - 20130121@Dan: add linked server DBSUM for bodb_Summary
  - 20130717@Kathy: Apply Progressive Bonus: add bettype 72 for Casino
  - 20140303@Kathy: Apply Keno product (from 1501 -> 1599)
  - 20140925@Sophia: Expand the range of Sporting Solution (1301 -> 1399)[Redmine: #22640]
  - 20150306@Cody: Apply sport bettype matrix [redmine: #30169]
  
 + Note: Review index=IX_srecommend when modifying this SP   
 */  
  
SET NOCOUNT ON  

 
DECLARE @SAgWinLoss TABLE(
				CustID		INT
				,TurnOver	MONEY
				,GrossComm	MONEY
				,MAgTotal	MONEY
				,SAgWinlost MONEY
				,Comm		MONEY
				,SAgTotal	MONEY
				,Company	MONEY
			)  
  
DECLARE @TmpCondSumWL TABLE(
				sporttype INT
				,bettype INT
			)
			  
IF @ShowSB = 1  
BEGIN  
	--Sum_winloss  
	INSERT INTO @TmpCondSumWL(sporttype, Bettype)  
	VALUES(0, 0)
END  
IF @ShowCasino = 1  
BEGIN  
	--Sum_winloss  
	INSERT INTO @TmpCondSumWL(sporttype, Bettype)  
	VALUES(251, 71)  
END  
IF @ShowP2P = 1  
BEGIN  
	--Sum_winloss  
	INSERT INTO @TmpCondSumWL(sporttype, Bettype)  
	VALUES(253, 1000)  
END  
IF @ShowRB = 1  
BEGIN  
	--Sum_winloss  
	INSERT INTO @TmpCondSumWL(Sporttype, Bettype)  
	SELECT 151, 0
END  
IF @ShowNG = 1  
BEGIN  
	--Sum_winloss  
	INSERT INTO @TmpCondSumWL(Sporttype, Bettype)  
	VALUES(161, 0)  
END  
IF @ShowBI = 1  
BEGIN  
	--Sum_winloss  
	INSERT INTO @TmpCondSumWL(Sporttype, Bettype)  
	VALUES(252, 73)  
END  
IF @showLiveCasino = 1
BEGIN
	--Sum_winloss  
	INSERT INTO @TmpCondSumWL(Sporttype, Bettype)  
	VALUES(162, 0) 
END
IF @showVS = 1
BEGIN
	--Sum_winloss  
	INSERT INTO @TmpCondSumWL(Sporttype, Bettype)  
	VALUES(180, 0) 
END
IF @showProgressiveBonus = 1
BEGIN
	--Sum_winloss  
	INSERT INTO @TmpCondSumWL(Sporttype, Bettype)  
	VALUES(251, 72) 
END
--Sum_winloss 
IF @showKeno = 1
BEGIN
	INSERT INTO @TmpCondSumWL (sporttype, bettype)
	VALUES(202, 0)
END 

DECLARE @SportBettype TABLE(
	ProductID INT
	,Bettype INT
	,EventType INT
)

INSERT INTO @SportBettype
EXEC dbo.Acc_SportBettypeMatrix_Sel @mode = 4

IF @Todate >= @BalanceUpDay   
BEGIN   
     INSERT INTO @SAgWinLoss  
      SELECT  
       mrecommend
	   ,SUM(CASE WHEN b.liveawayscore = 0 AND b.bettype IN(33,43) THEN ABS(b.stake)/2 ELSE ABS(b.stake) END)
	   ,SUM(CASE WHEN b.bettype = 1000 THEN oddsspread ELSE CASE WHEN tpositiontaking = 1 THEN 0 ELSE scomm/(1 - tpositiontaking) END END) AS GrossComm
       ,SUM(mwinlost + awinlost + acomm + winlost - actual_stake)
       ,SUM(swinlost)
       ,ISNULL(SUM(scomm), 0) - ISNULL(SUM(acomm), 0)
       ,ISNULL(SUM(swinlost), 0) + ISNULL(SUM(scomm), 0) - SUM(acomm)
       ,-(ISNULL(SUM(swinlost), 0) + ISNULL(SUM(awinlost), 0) + ISNULL(SUM(mwinlost), 0) + ISNULL(SUM(scomm), 0) + ISNULL(SUM(winlost - actual_stake), 0))     
      FROM   
		dbo.bettrans b WITH (NOLOCK, index = IX_srecommend)  
		INNER JOIN @SportBettype s ON(b.bettype = s.Bettype)
      WHERE  
			
  --  (  
  --   bettype < case when @showSB=1 then 31 else 0 end  
  --   OR bettype between 121 and case when @showSB=1 then 999 else 0 end
  --   OR bettype between 1301 and case when @showSB=1 then 1399 else 0 end
  --   OR bettype between 31 and case when @ShowRB=1 then 49 else 0 end  
  --   OR bettype = case when @showCasino=1 then 71 else 0 end  
  --   OR bettype = case when @showP2P=1 then 1000 else 0 end  
  --   OR bettype BETWEEN 81 AND (CASE WHEN @showNG=1 THEN 120 ELSE 0 END)  
  --   OR bettype = (CASE WHEN @showBI =1 THEN 73 ELSE 0 END)  
	 --OR bettype BETWEEN 1101 AND (CASE WHEN @showLiveCasino =1 THEN 1199 ELSE 0 END)  
	 --OR bettype BETWEEN 1201 AND (CASE WHEN @showVS=1 THEN 1299 ELSE 0 END)
	 --OR bettype = CASE WHEN @showProgressiveBonus =1 then 72 else 0 end
	 --OR b.bettype BETWEEN 1501 AND CASE WHEN @showKeno = 1 then 1599 ELSE 0 END 
  --  ) AND
		s.ProductID IN (1, 2, 3, 4, 5, 6, 7)
		AND SRecommend = @CustID 
		AND  winlostdate BETWEEN @FromDate AND @ToDate 
		--AND  status NOT IN ('VOID', 'REJECT', 'Refund') 
		AND  b.statusID NOT IN (0,1,101, 102, 103)   
		AND ruben = 1
      GROUP BY mrecommend, b.bettype  
   
 IF @BalanceUpDay < @FromDate  
  SELECT @BalanceUpDay=@FromDate  
  
    INSERT INTO @SAgWinLoss  
     SELECT     
		CustID
		,SUM(ABS(TurnOver))
		,SUM(ISNULL(grosscomm, 0)) AS GrossComm
		,SUM(mwinlost + awinlost + acomm + winlost)  
		,SUM(swinlost)
		,ISNULL(SUM(scomm), 0) - ISNULL(SUM(acomm), 0)
		,ISNULL(SUM(swinlost), 0) + ISNULL(SUM(scomm), 0) - SUM(acomm)
		,-(ISNULL(SUM(swinlost), 0) + ISNULL(SUM(awinlost), 0) + ISNULL(SUM(mwinlost), 0) + ISNULL(SUM(scomm), 0) + ISNULL(SUM(winlost), 0))     
     FROM
		dbo.sum_winloss b WITH (NOLOCK) 
		INNER JOIN @TmpCondSumWL t ON b.sporttype = t.sporttype AND b.bettype = t.bettype  
     WHERE  
		winlostdate BETWEEN @BalanceUpDay AND @todate  
		AND Srecommend = @custid
		AND roleid = 3  
     GROUP BY custid  
END  
IF @FromDate < @BalanceUpDay   
BEGIN  
 IF @ToDate >= DATEADD(dd, -1, @BalanceUpDay)  
  SELECT @ToDate = DATEADD(dd, -1, @BalanceUpDay)  
   
    INSERT INTO @SAgWinLoss  
     SELECT     
		CustID          
		,SUM(ABS(TurnOver))
		,SUM(ISNULL(grosscomm,0)) AS GrossComm
		,SUM(mwinlost + awinlost + acomm + winlost)  
		,SUM(swinlost)
		,ISNULL(SUM(scomm), 0) - ISNULL(SUM(acomm), 0)
		,ISNULL(SUM(swinlost), 0) + ISNULL(SUM(scomm), 0) - SUM(acomm)
		,-(ISNULL(SUM(swinlost), 0) + ISNULL(SUM(awinlost), 0) + ISNULL(SUM(mwinlost), 0) + ISNULL(SUM(scomm), 0) + ISNULL(SUM(winlost), 0))     
     FROM   
		DBSUM.bodb_Summary.dbo.Sum_WinLoss_Old b WITH(NOLOCK) 
		INNER JOIN @TmpCondSumWL t ON b.sporttype = t.sporttype AND b.bettype = t.bettype  
     WHERE  
		Winlostdate BETWEEN @FromDate AND @ToDate  
		AND SRecommend = @CustID  
		AND RoleID = 3  
     GROUP BY CustID  
  
        --Write log to monitor performance on DB06  
--     EXEC bodb_CustomerLog.dbo.WriteLog_userlog_sumwinloss_old   
--   @CustID = @CustID,  
--   @SpName = 'Age_Rpt_WinLoss_SAg'  
END  
  
SELECT  
	w.CustID   
	,c.UserName
	,SUM(TurnOver) AS TurnOver
	,SUM(GrossComm) AS GrossComm
	,SUM(MAgTotal) AS MAgTotal 
	,SUM(SAgWinlost) AS SAgWinlost
	,SUM(Comm) AS Comm
	,SUM(SAgTotal) AS SAgTotal
	,SUM(Company) AS Company  
FROM 
	@SAgWinLoss w 
	INNER JOIN Customer c WITH(NOLOCK) ON w.CustID = c.CustID   
GROUP BY w.CustID, c.UserName  
ORDER BY c.Username

GO
GRANT EXECUTE ON [dbo].[Age_Rpt_WinLoss_SAg] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_Rpt_WinLoss_SAg] TO [bodbDownlineNetView]
GO
GRANT VIEW DEFINITION ON [dbo].[Age_Rpt_WinLoss_SAg] TO [vnteam]