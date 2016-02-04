USE [bodb02]
GO
SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO
ALTER PROCEDURE [dbo].[Age_Rpt_WinLossDetail_MAg_New] 
	@custid			 INT = NULL --mrecommend
	,@FromDate       SMALLDATETIME
	,@ToDate         SMALLDATETIME
	,@showSB         BIT = 1
	,@showCasino     BIT = 0
	,@showP2P        BIT = 0
	,@showRB         BIT = 0
	,@showFI         BIT = 0
	,@showNG         BIT = 0
	,@showBI         BIT = 0
	,@showLiveCasino BIT = 0
	,@showVS         BIT = 0
	,@showKeno       BIT = 0
	,@showGD		 BIT = 0
	,@showCB		 BIT = 0
	,@showCF		 BIT = 0
	,@showAB			BIT = 0
	,@BalanceUpDay   SMALLDATETIME
	,@PageSize       INT = 0
	,@PageIndex      INT = 0
	,@TotalRows      INT = 0 OUTPUT
AS
/*
Created: 
Task : Agent Winloss Detail
DB: DBAGE/bodb02
Original SP:Rpt_AgentWinlostDetail
Revisions:
    - 20080629@Viet: Combine data with Archive DB (Viet)
    - 20090225@Tuan: For Casino (Tuan)
    - 20090331@Hiep: exclude GrossComm for Casino
	- 20090423@Phuc: Modify agenttotal = (awinlost + comm - playercomm)
	- 20090523@AnhPham: filtering data by HR, FI
    - 20090611@Phuc: exclude turnover in case place refund(for HR each way).
	- 20091019@Phuc: write log and move table Sum_WinLoss_Old to database bodb_Summary.
	- 20091117@Henry: optimize when joining with table sum_winloss and sum_winloss_old
	- 20091126@Jamie: Change the gross commission by level (super/master/agent)
			+ super  = scomm/(1 - tpos)
			+ master = acomm/(1 - apos - mpos)
			+ agent  = comm /(1 - apos)
		Applied on Dec 1, 2009 
	- 20091211@Jamie: Show Casino grosscomm instead of 0 
	- 20100118@Jamie: Remove @mrecommend and @srecommend 'coz of moving accounts 
	- 20100610@Henry: Change to use StatusID instead of Status in WHERE statement
	- 20100726@Don: paging
	- 20100902@Kiwi: Turn back to use bettype directly from bettrans rather than @TmpCond table
	- 20100904@Jacob: Add two parameters: @showBI, @showNG, calculate winloss base on bingo and number game
	- 20110308@Lukas: change @showHR -> @showRB
	- 20110801@Sophia: change the range of number game's bettype from 81 to 120
	- 20110822@Sophia: Count Negative stake as positive turnover
	- 20110907@Tom: Change range of bet type : 0->30, 
				apply new bet type 1st correct score on Sport Books		
	- 20110927@Tom: 1. Edit Winloss P2P Games Sport : 251->253 , Bettype: 72->1000	
					2. Remove parameter @ABSDate
	- 20111024@Lukas: add one case for checking Casino PT 
	- 20111130@Sophia: Change the range of Sport book bettype>=121 and bettype<=999
	- 20120112@Sophia: Add LiveCasino: Sporttype: 162, bettype: 1101 ->1199
	- 20120608@Elodie: Change the gross commission for P2P
	- 20120807@Sophia:  .Add new parametter @showVS for Virtual Sports (sporttype = 180 for representing)
							.Remove Financial product
	- 20121024@Johnson: Add new range bettypes for tennis (from 1301 to 1334)
	- 20130121@Dan: add linked server DBSUM for bodb_Summary
	- 20140303@Kathy: Apply Keno product (from 1501 -> 1599)[Redmine:#12691]
	- 20140509@Logan:	1.Add counting for number of tickets
	                    2.Code aligning
	- 20140925@Sophia: Expand the range of Sporting Solution (1301 -> 1399) [Redmine: #22640]
	- 20150306@Cody: Apply sport bettype matrix [Redmine: #30169]
	- 20150613@Francis: Change to use temporary table instead of table variable to improve performance
	- 20150615@Sophia: Apply Gold Deluxe [Redmine: #35278]
	- 20150831@Winnie: Include CB [Redmine: #42409]
	- 20151209@Percy: Add new bettype: Cock Fighting Sabong [Redmine: #48601]
	- 20151223@Percy: Support new bettype for RNG Casino [Redmine: #48283]
	- 20160201@Percy: Exclude bettype 500 when calculate betcount [Redmine: #50027]
	- 20160204@Percy: Support new product AllBet [Redmine: #50605]
	- 20160225@Sophia: Add new column TurnoverNoDraw [Redmine: #51427]
	- 20160308@Francis: Change to use inline function instead of table variable to enhance performance
	- 20160325@Francis: Use local variables to avoid parameter sniffing and sp recompilation
*/


SET NOCOUNT ON

DECLARE @RowStart	INT
		,@RowEnd	INT
		  
SELECT @PageIndex = @PageIndex - 1
       ,@RowStart = @PageSize * @PageIndex + 1
       ,@RowEnd = @RowStart + @PageSize - 1


--DECLARE @MAgWinLossDetails TABLE
--(
--    CustID			INT
--    ,TurnOver		MONEY
--    ,GrossComm		MONEY
--    ,MemberWinLost	MONEY
--	,PlayerComm		MONEY
--	,MemberTotal	MONEY
--	,AgWinLost		MONEY
--	,AgComm			MONEY
--	,AgTotal		MONEY
--	,MAgWinLost		MONEY
--	,MAgComm		MONEY
--	,MAgTotal		MONEY
--	,Company		MONEY
--	,NoOfTicket		INT
--)


CREATE TABLE #MAgWinLossDetails
(
    CustID			INT
    ,TurnOver		MONEY
	,TurnoverNoDraw	MONEY
    ,GrossComm		MONEY
    ,MemberWinLost	MONEY
	,PlayerComm		MONEY
	,MemberTotal	MONEY
	,AgWinLost		MONEY
	,AgComm			MONEY
	,AgTotal		MONEY
	,MAgWinLost		MONEY
	,MAgComm		MONEY
	,MAgTotal		MONEY
	,Company		MONEY
	,NoOfTicket		INT
)


DECLARE @TmpCondSumWL TABLE(sporttype INT, bettype INT)

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

IF @showKeno = 1
BEGIN
	--Sum_winloss  
	INSERT INTO @TmpCondSumWL(Sporttype, Bettype)  
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


DECLARE @isTest BIT,@SQL NVARCHAR(100) = OBJECT_NAME(@@PROCID)

IF  (@SQL like '%_xtest%' OR @SQL like '%_xpre%' OR @SQL like '%_UAT1%' OR @SQL like '%_UAT2%' OR @SQL like '%_UAT3%' OR @SQL like '%_UAT4%')
BEGIN
	SELECT @isTest = 1
END
ELSE
BEGIN
	SELECT @isTest = 0
END

--Avoid Parameter Sniffing
DECLARE @FDate			SMALLDATETIME
		,@TDate			SMALLDATETIME
		,@BUDate		SMALLDATETIME
	    ,@CID			INT
	    
SELECT @FDate = @FromDate, @TDate = @ToDate, @BUDate = @BalanceUpDay, @CID = @custid

IF @TDate >= @BUDate
BEGIN 
    INSERT INTO #MAgWinLossDetails
	    SELECT Recommend,			
			   SUM(CASE WHEN b.liveawayscore = 0 AND b.bettype IN (33, 43) THEN ABS(b.stake)/2 ELSE ABS(b.stake) END) AS TurnOver, 
			   SUM(CASE WHEN b.liveawayscore = 0 and b.bettype in(33,43) THEN ABS(b.stake)/2 
					WHEN b.StatusID IN (112,113) AND b.MOdds IN (-0.25, 0.25) AND s.ProductId = 1 THEN ABS(b.stake)/2
					WHEN b.StatusID = 111 AND s.ProductId = 1 THEN 0 
					ELSE ABS(b.stake) 
					END) AS TurnoverNoDraw,
		    --SUM(acomm/(1-apositiontaking-mpositiontaking)) as GrossComm,
			---- @Lukas20111024: hot fix - casino only
			   SUM(CASE WHEN b.bettype = 1000 THEN oddsspread ELSE CASE WHEN (apositiontaking + mpositiontaking = 1) THEN 0 ELSE acomm/(1 - apositiontaking - mpositiontaking) END END) AS GrossComm,
		       SUM(winlost - actual_stake), --MemberWinlost
		       SUM(playercomm), -- PlayerComm
		       ISNULL(SUM(winlost - actual_stake), 0) + ISNULL(SUM(playercomm), 0), --MemberTotal
		       SUM(awinlost), -- AgWinlost
		       ISNULL(SUM(comm - playercomm), 0), --AgComm
		       ISNULL(SUM(awinlost), 0) + ISNULL(SUM(comm - playercomm), 0), --AgTotal
		       SUM(mwinlost), -- MAgWinlost
		       SUM(acomm) - SUM(comm), --MAgComm
		       ISNULL(SUM(mwinlost), 0) + ISNULL(SUM(acomm), 0) - SUM(comm), --MAgTotal
		       -(ISNULL(SUM(awinlost), 0) + ISNULL(SUM(mwinlost), 0) + ISNULL(SUM(acomm), 0) + ISNULL(SUM(winlost - actual_stake), 0)),--Company
		       COUNT(CASE WHEN b.bettype = 500 THEN NULL ELSE b.transid END) --No Of Ticket
	    FROM dbo.bettrans b WITH(NOLOCK)
				--INNER JOIN @SportBettype s ON(b.bettype = s.Bettype)
				cross apply dbo.f_SportBettypeMatrix_Sel_Mode4(0, 0, 0, 2, '', '', @IsTest) s -- ON b.bettype = s.Bettype
		WHERE 
				1 = 1
				AND b.bettype = s.Bettype
				AND (  s.ProductID = CASE WHEN @showSB			= 1 THEN 1 ELSE 0 END
					OR s.ProductID = CASE WHEN @ShowRB			= 1 THEN 2 ELSE 0 END
					OR s.ProductID = CASE WHEN @showCasino		= 1 THEN 6 ELSE 0 END
					OR s.ProductID = CASE WHEN @showP2P			= 1 THEN 9 ELSE 0 END
					OR s.ProductID = CASE WHEN @showNG			= 1 THEN 3 ELSE 0 END
					OR s.ProductID = CASE WHEN @showBI			= 1 THEN 7 ELSE 0 END
					OR s.ProductID = CASE WHEN @showLiveCasino	= 1 THEN 4 ELSE 0 END
					OR s.ProductID = CASE WHEN @showVS			= 1 THEN 5 ELSE 0 END
					OR s.ProductID = CASE WHEN @showKeno		= 1 THEN 8 ELSE 0 END
					OR s.ProductID = CASE WHEN @showGD			= 1 THEN 12 ELSE 0 END
					OR s.ProductID = CASE WHEN @showCB			= 1 THEN 15 ELSE 0 END
					OR s.ProductID = CASE WHEN @showCF			= 1 THEN 19 ELSE 0 END
					OR s.ProductID = CASE WHEN @showAB			= 1 THEN 21 ELSE 0 END
				)
			AND winlostdate BETWEEN @FDate AND @TDate
			--status not in ('running','waiting','VOID', 'REJECT', 'Refund') and
			AND statusID NOT IN (101, 102, 103)
			AND ruben = 1
			AND mrecommend = @CID
	  GROUP BY Recommend, b.bettype
		
	IF @BUDate < @FDate
	    SELECT @BUDate = @FDate
	
    INSERT INTO #MAgWinLossDetails
	    SELECT CustID,			
		       SUM(ABS(TurnOver)) AS TurnOver,
			   SUM(ABS(TunroverNoDraw)) as TurnoverNoDraw,
		       SUM(grosscomm) AS GrossComm,
		       SUM(winlost), --MemberWinlost
		       SUM(playercomm), -- PlayerComm
		       ISNULL(SUM(winlost), 0) + ISNULL(SUM(playercomm), 0), --MemberTotal
		       SUM(awinlost), -- AgWinlost
		       ISNULL(SUM(comm - playercomm), 0), --AgComm
		       ISNULL(SUM(awinlost), 0) + ISNULL(SUM(comm - playercomm), 0), --AgTotal
		       SUM(mwinlost), -- MAgWinlost
		       SUM(acomm) - SUM(comm), --MAgComm
		       ISNULL(SUM(mwinlost), 0) + ISNULL(SUM(acomm), 0) - SUM(comm), --MAgTotal
		       -(ISNULL(SUM(awinlost), 0) + ISNULL(SUM(mwinlost), 0) + ISNULL(SUM(acomm), 0) + ISNULL(SUM(winlost), 0)),--Company
		       SUM(betcount) --NoOfTicket
	      FROM dbo.SUM_winloss b WITH(NOLOCK) INNER JOIN @TmpCondSUMWL t
	        ON b.sporttype = t.sporttype
	       AND b.bettype = t.bettype
	     WHERE 1 = 1
		   AND winlostdate BETWEEN @BUDate AND @Tdate			
		   AND MRecommend = @CID
		   AND RoleID = 2
	  GROUP BY CustID
END

IF @FromDate < @BalanceUpDay 
BEGIN
	IF @ToDate >= DATEADD(dd, -1, @BalanceUpDay)
		SELECT @ToDate = DATEADD(dd, -1, @BalanceUpDay)
	
    INSERT INTO #MAgWinLossDetails
	    SELECT CustID,			
		       SUM(ABS(TurnOver)) AS TurnOver,
			   SUM(ABS(TunroverNoDraw)) as TurnoverNoDraw,
		       SUM(grosscomm) AS GrossComm,
		       SUM(winlost), --MemberWinlost
		       SUM(playercomm), -- PlayerComm
		       ISNULL(SUM(winlost), 0) + ISNULL(SUM(playercomm), 0), --MemberTotal
		       SUM(awinlost), -- AgWinlost
		       ISNULL(SUM(comm - playercomm), 0), --AgComm
		       ISNULL(SUM(awinlost), 0) + ISNULL(SUM(comm - playercomm), 0), --AgTotal
		       SUM(mwinlost), -- MAgWinlost
		       SUM(acomm) - SUM(comm), --MAgComm
		       ISNULL(SUM(mwinlost), 0) + ISNULL(SUM(acomm), 0) - SUM(comm), --MAgTotal
		       -(ISNULL(SUM(awinlost), 0) + ISNULL(SUM(mwinlost), 0) + ISNULL(SUM(acomm), 0) + ISNULL(SUM(winlost), 0)),--Company
		       SUM(betcount) --NoOfTicket
	      FROM DBSUM.bodb_Summary.dbo.Sum_WinLoss_Old b WITH(NOLOCK) INNER JOIN @TmpCondSumWL t
	        ON b.sporttype = t.sporttype
	       AND b.bettype = t.bettype
	     WHERE 1 = 1
		   AND winlostdate BETWEEN @fromdate AND @ToDate			
		   AND MRecommend = @custid
		   AND RoleID = 2
	  GROUP BY CustID
END	


IF ((@PageSize <= 0) AND (@PageIndex <= 0))
BEGIN
    SELECT w.CustID, 
	       c.UserName, 
	       SUM(TurnOver) AS TurnOver,
		   SUM(TurnoverNoDraw) as TurnoverNoDraw,
	       SUM(GrossComm) AS GrossComm,
	       SUM(MemberWinLost) AS MemberWinlost,
	       SUM(PlayerComm) AS PlayerComm,
	       SUM(MemberTotal) AS MemberTotal,
	       SUM(AgWinlost) AS AgWinlost,
	       SUM(AgComm) AS AgComm,
	       SUM(AgTotal) AS AgTotal,
	       SUM(MAgWinlost) AS MAgWinlost,
	       SUM(MAgComm) AS MAgComm,
	       SUM(MAgTotal) AS MAgTotal,
	       SUM(Company) AS Company,
	       SUM(NoOfTicket) AS NoOfTicket
      FROM #MAgWinLossDetails w INNER JOIN Customer c WITH(NOLOCK)
        ON w.CustID = c.CustID 
  GROUP BY w.CustID, c.UserName
  ORDER BY c.Username

    RETURN
END


IF @TotalRows = 0  
BEGIN  
    SELECT @TotalRows = count(tmp.CustID)
      FROM (SELECT CustID
              FROM #MAgWinLossDetails
          GROUP BY CustID
           ) tmp
 
END

SELECT wl.*
  FROM (SELECT w.CustID, 
	           c.UserName, 
	           SUM(TurnOver) AS TurnOver,
			   SUM(TurnoverNoDraw) AS TurnoverNoDraw,
	           SUM(GrossComm) AS GrossComm,
	           SUM(MemberWinLost) AS MemberWinlost,
	           SUM(PlayerComm) AS PlayerComm,
	           SUM(MemberTotal) AS MemberTotal,
	           SUM(AgWinlost) AS AgWinlost,
	           SUM(AgComm) AS AgComm,
	           SUM(AgTotal) AS AgTotal,
	           SUM(MAgWinlost) AS MAgWinlost,
	           SUM(MAgComm) AS MAgComm,
	           SUM(MAgTotal) AS MAgTotal,
	           SUM(Company) AS Company,
	           SUM(NoOfTicket) AS NoOfTicket,
	           ROW_NUMBER() OVER (ORDER BY c.UserName) AS RowNum
          FROM #MAgWinLossDetails w INNER JOIN Customer c WITH(NOLOCK)
            ON w.CustID = c.CustID 
      GROUP BY w.CustID, c.UserName
       ) wl
 WHERE 1 = 1
   AND wl.RowNum BETWEEN @RowStart AND @RowEnd

DROP TABLE #MAgWinLossDetails

GO
GRANT EXECUTE ON [dbo].[Age_Rpt_WinLossDetail_MAg_New] TO [bodbAdminNet] AS [dbo]
GO
GRANT EXECUTE ON [dbo].[Age_Rpt_WinLossDetail_MAg_New] TO [bodbDownlineNet] AS [dbo]
GO
GRANT EXECUTE ON [dbo].[Age_Rpt_WinLossDetail_MAg_New] TO [bodbDownlineNetView] AS [dbo]
GO
GRANT EXECUTE ON [dbo].[Age_Rpt_WinLossDetail_MAg_New] TO [bodbExtAccNet] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[Age_Rpt_WinLossDetail_MAg_New] TO [vnteam] AS [dbo]