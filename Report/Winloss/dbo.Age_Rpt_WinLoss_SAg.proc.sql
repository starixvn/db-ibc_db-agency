USE [bodb02]
GO

ALTER PROCEDURE [dbo].[Age_Rpt_WinLoss_SAg]  
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
 ,@showProgressiveBonus BIT = 0
 ,@showKeno				BIT = 0
 ,@showGD				BIT = 0
 ,@showCB				BIT = 0
 ,@showCF				BIT = 0
 ,@showAB				BIT = 0
 ,@showVB				BIT = 0
 ,@showNG2				BIT = 0
 ,@BalanceUpDay			SMALLDATETIME  
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
  - 20150507@Sophia: Apply Gold Deluxe [Redmine: #35278]
  - 20150831@Winnie: Include CB [Redmine: #42409
  - 20151209@Percy: Add new bettype: Cock Fighting Sabong [Redmine: #48601]
  - 20151223@Percy: Support new bettype for RNG Casino [Redmine: #48283]
  - 20160204@Percy: Support new product AllBet [Redmine: #50605]
  - 20160413@Percy: Support Voidbridge single wallet [Redmine: #55259]
  - 20160607@Percy: Enhance Performance - Remove WITH RECOMPILE, link-server DBSUM [Redmine: #58288]
  - 20160713@Sophia: Hide data before specific date of some specific accounts [Redmind: #60767]
  - 20160808@Johnson: Integrate NG2 [Redmine: #61397]

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
	VALUES(251, 71), (208, 0), (209, 0), (210, 0)
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
IF @showKeno = 1
BEGIN
	--Sum_winloss 
	INSERT INTO @TmpCondSumWL (sporttype, bettype)
	VALUES(202, 0)
END 
IF @showGD = 1
BEGIN 
	--Sum_winloss  
	INSERT INTO @TmpCondSumWL(Sporttype, Bettype)  
	VALUES(255, 0) 
END
IF @showCB = 1
BEGIN 
	--Sum_winloss  
	INSERT INTO @TmpCondSumWL(Sporttype, Bettype)  
	VALUES(204, 0) 
END
IF @showCF = 1
BEGIN 
	--Sum_winloss  
	INSERT INTO @TmpCondSumWL(Sporttype, Bettype)  
	VALUES(206, 1003) 
END
IF @showAB = 1
BEGIN 
	--Sum_winloss  
	INSERT INTO @TmpCondSumWL(Sporttype, Bettype)  
	VALUES(211, 0) 
END
IF @showVB = 1
BEGIN 
	--Sum_winloss  
	INSERT INTO @TmpCondSumWL(Sporttype, Bettype)  
	VALUES(212, 0) 
END
IF @showNG2 =1 
BEGIN
	--Sum_winloss  
	INSERT INTO @TmpCondSumWL(Sporttype, Bettype)  
	VALUES(213, 0)
END

DECLARE @isTest BIT = 0
SELECT  @isTest = dbo.f_CheckSPVersion(@@PROCID)

-----Get Special Super to hide data of them before specific date 
DECLARE @IsHide BIT = 0 

IF EXISTS (SELECT 1 FROM dbo.f_SpecialSuper() WHERE Srecommend = @CustId)
	SELECT @IsHide = 1 

----Get Account Login to detect Interal or not
DECLARE @LoginName NVARCHAR(128)
SELECT @LoginName = SUSER_NAME()


--Avoid Parameter Sniffing for bettrans and sum_winloss
DECLARE @FDate			SMALLDATETIME
		,@TDate			SMALLDATETIME
		,@BUDate		SMALLDATETIME
	    ,@CID			INT    	    
SELECT @FDate = @FromDate, @TDate = @ToDate, @BUDate = @BalanceUpDay, @CID = @custid

IF @TDate >= @BUDate   
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
		INNER JOIN dbo.f_SportBettypeMatrix_Sel(0, 0, 0, 2, '', '', @isTest) s ON b.bettype = s.Bettype
      WHERE  
			1 = 1 				
				AND (  s.ProductID = CASE WHEN @showSB         = 1 THEN 1  ELSE 0 END
					OR s.ProductID = CASE WHEN @ShowRB         = 1 THEN 2  ELSE 0 END
					OR s.ProductID = CASE WHEN @showCasino     = 1 THEN 6  ELSE 0 END
					OR s.ProductID = CASE WHEN @showP2P        = 1 THEN 9  ELSE 0 END
					OR s.ProductID = CASE WHEN @showNG         = 1 THEN 3  ELSE 0 END
					OR s.ProductID = CASE WHEN @showBI         = 1 THEN 7  ELSE 0 END
					OR s.ProductID = CASE WHEN @showLiveCasino = 1 THEN 4  ELSE 0 END
					OR s.ProductID = CASE WHEN @showVS         = 1 THEN 5  ELSE 0 END
					OR s.ProductID = CASE WHEN @showKeno       = 1 THEN 8  ELSE 0 END
					OR s.ProductID = CASE WHEN @showGD         = 1 THEN 12 ELSE 0 END
					OR s.ProductID = CASE WHEN @showCB         = 1 THEN 15 ELSE 0 END
					OR s.ProductID = CASE WHEN @showCF         = 1 THEN 19 ELSE 0 END
					OR s.ProductID = CASE WHEN @showAB         = 1 THEN 21 ELSE 0 END
					OR s.ProductID = CASE WHEN @showVB         = 1 THEN 22 ELSE 0 END
					OR s.ProductID = CASE WHEN @showNG2        = 1 THEN 23 ELSE 0 END
				)
		AND SRecommend = @CID 
		AND  winlostdate BETWEEN @FDate AND @TDate 
		AND  b.statusID NOT IN (0, 1, 101, 102, 103)   
		--AND ruben = 1
      GROUP BY mrecommend, b.bettype  
   
	IF @BUDate < @FDate 
		SELECT @BUDate = @FDate 
  
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
		winlostdate BETWEEN @BUDate AND @TDate
		AND Srecommend = @CID
		AND roleid = 3  
     GROUP BY custid  
END  
IF @FromDate < @BalanceUpDay   
BEGIN  
	IF @ToDate >= DATEADD(dd, -1, @BalanceUpDay)  
		SELECT @ToDate = DATEADD(dd, -1, @BalanceUpDay)  
   

	IF @FromDate < '2016-06-01' AND @IsHide = 1 AND @LoginName <> 'bodbDownlineNetView' --- acc internal login 
		SELECT @FromDate = '2016-06-01'
			

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
		bodb_Summary.dbo.Sum_WinLoss_Old b WITH(NOLOCK) 
		INNER JOIN @TmpCondSumWL t ON b.sporttype = t.sporttype AND b.bettype = t.bettype  
     WHERE  
		Winlostdate BETWEEN @FromDate AND @ToDate  
		AND SRecommend = @CustID  
		AND mrecommend = mrecommend
		AND recommend = recommend
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

GRANT EXECUTE ON [dbo].[Age_Rpt_WinLoss_SAg] TO [bodbDownlineNet] AS [dbo]
GO

GRANT EXECUTE ON [dbo].[Age_Rpt_WinLoss_SAg] TO [bodbDownlineNetView] AS [dbo]
GO

GRANT VIEW DEFINITION ON [dbo].[Age_Rpt_WinLoss_SAg] TO [vnteam] AS [dbo]
GO