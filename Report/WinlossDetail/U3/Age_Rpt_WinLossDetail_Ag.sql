/*<info serverAlias="DBAGE-bodb02" executers="bodbAdminNet,bodbDownlineNet,bodbDownlineNetView,bodbExtAccNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Age_Rpt_WinLossDetail_Ag]
	@CustID				INT = NULL --recommend
	,@FromDate			SMALLDATETIME
	,@ToDate			SMALLDATETIME
	,@showSB			BIT = 1
	,@showCasino		BIT = 0
	,@showP2P			BIT = 0	
	,@showRB			BIT = 0
	,@showFI			BIT = 0
	,@showNG			BIT = 0
	,@showBI			BIT = 0
	,@showLiveCasino	BIT = 0
	,@showVS			BIT = 0
	,@showKeno			BIT = 0
	,@showGD			BIT = 0
	,@showCB			BIT = 0
	,@showCF			BIT = 0
	,@showAB			BIT = 0
	,@showVB			BIT = 0
	,@showNG2			BIT = 0
	,@showFW			BIT = 0
	,@showLT			BIT = 0
	,@showLK3			BIT = 0
	,@BalanceUpDay		SMALLDATETIME
	,@PageSize			INT = 0
	,@PageIndex			INT = 0
	,@TotalRows			INT = 0 OUTPUT
AS

/*
	Created: 
	Task: Member Winloss Detail
	DB: DBAGE/bodb02
	Original SP:Rpt_MemberWinlostDetail

	Revisions:
		- 20070408@Joe: remove UNION, uses TEMP table instead (Joe) remove refno
		- 20080629@Viet: Combine data with Archive DB (Viet)
		- 20090225@Tuan: For Casino (Tuan)
		- 20090331@Hiep: exclude GrossComm for Casino
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
		-- 20100527@Henry: Change to use StatusID instead of Status in WHERE statement
		- 20100726@Don: paging
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
		- 20140303@Kathy: Apply Keno product (from 1501 -> 1599)
		- 20140509@Logan:	1.Add counting for number of tickets
							2.Code aligning
		- 20140925@Sophia: Expand the range of Sporting Solution (1301 -> 1399) [Redmine: #22640]
		- 20150306@Cody: Apply sport bettype matrix [Remine: #30169]
		- 20150507@Sophia: Apply Gold Deluxe [Redmine: #35278]
		- 20150831@Winnie: Include CB [Redmine: #42409]
		- 20151209@Percy: Add new bettype: Cock Fighting Sabong [Redmine: #48601]
		- 20151223@Percy: Support new bettype for RNG Casino [Redmine: #48283]
		- 20160201@Percy: Exclude bettype 500 when calculate betcount [Redmine: #50027]
		- 20160204@Percy: Support new product AllBet [Redmine: #50605]
		- 20160225@Sophia: Add new column TurnoverNoDraw [Redmine: #51427]
		- 20160308@Francis: Change to use inline function instead of table variable to enhance performance
		- 20160325@Francis: Use local variables to avoid parameter sniffing and sp recompilation
		- 20160413@Percy: Support Voidbridge single wallet [Redmine: #55259]
		- 20160607@Percy: Enhance Performance - using custInfo table instead of Customer table [Redmine: #58288]
		- 20160713@Sophia: Hide data before specific date of some specific accounts [Redmind: #60767]
		- 20160808@Johnson: Integrate NG2 [Redmine: #61397]
		- 20160809@Percy: Modify Net Turnover for Allbet [RedmineID: #61873]
		- 20161028@Percy: Support Fishing World [RedmineID: #65731]
		- 20170622@Percy: Combine Betradar Virtual Sports with Virtual Sports [RedmineID: #78339]
		- 20170808@Percy: Integrate Lucky 3 [RedmineID: #80219]
		- 20170705@Percy: Support Keno Lottery [RedmineID: #78064]
		- 20210823@Sol: Alpha - Allow more time to transfer (phase 2b) - [RedmineID: #160440]
		- 20211123@Percy: Fix divide by 0 [RedmineID: #164854]
*/
SET NOCOUNT ON

DECLARE @moveBetsDay SMALLDATETIME
DECLARE @tblMoveBetBalanceUp AS TABLE (BalanceUpDay SMALLDATETIME, MoveBetsDay SMALLDATETIME)

INSERT INTO @tblMoveBetBalanceUp(BalanceUpDay,MoveBetsDay)
EXEC bodb02.dbo.Age_SelBalanceUpDay
	
SELECT @moveBetsDay = MoveBetsDay FROM @tblMoveBetBalanceUp

DECLARE @RowStart	INT
		,@RowEnd	INT 
		
SELECT @PageIndex = @PageIndex - 1
		,@RowStart = @PageSize * @PageIndex + 1
		,@RowEnd = @RowStart + @PageSize - 1
 
DECLARE @AgWinLossDetails TABLE
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
	VALUES(180, 0), (190,0)
END

IF @showKeno = 1
BEGIN
	--Sum_winloss  
	INSERT INTO @TmpCondSumWL(Sporttype, Bettype)  
	VALUES(202,	0) 
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
IF @showNG2 = 1
BEGIN 
	--Sum_winloss  
	INSERT INTO @TmpCondSumWL(Sporttype, Bettype)  
	VALUES(213, 0) 
END
IF @showFW = 1
BEGIN 
	--Sum_winloss  
	INSERT INTO @TmpCondSumWL(Sporttype, Bettype)  
	VALUES(219, 0) 
END
IF @showLT = 1
BEGIN 
	--Sum_winloss  
	INSERT INTO @TmpCondSumWL(Sporttype, Bettype)  
	VALUES(220, 0) 
END
IF @showLK3 = 1
BEGIN
	--Sum_winloss  
	INSERT INTO @TmpCondSumWL (Sporttype, Bettype)
	VALUES (160, 0)
END

DECLARE @isTest BIT = 0
SELECT  @isTest = dbo.f_CheckSPVersion(@@PROCID)

------Get @Srecommend
DECLARE @Srecommend int, @mrecommend int  
SELECT @Srecommend =  Srecommend, @Mrecommend =  Mrecommend FROM dbo.CustInfo WITH (NOLOCK) WHERE CustID = @CustID 

-----Get Special Super to hide data of them before specific date 
DECLARE @IsHide BIT = 0 

IF EXISTS (SELECT 1 FROM dbo.f_SpecialSuper() WHERE Srecommend = @Srecommend)
	SELECT @IsHide = 1 
		
----Get Account Login to detect Interal or not
DECLARE @LoginName NVARCHAR(128)
SELECT @LoginName = SUSER_NAME()


--Avoid Parameter Sniffing
DECLARE @FDate			SMALLDATETIME
		,@TDate			SMALLDATETIME
		,@BUDate		SMALLDATETIME
	    ,@CID			INT
	    
SELECT @FDate = @FromDate, @TDate = @ToDate, @BUDate = @BalanceUpDay, @CID = @custid

IF @TDate >= @BUDate
BEGIN 
	IF @FromDate <= @MoveBetsDay
	BEGIN
		SET @FDate = DATEADD(DD, 1, @MoveBetsDay);
	END

    INSERT INTO @AgWinLossDetails
	    SELECT CustID,
			   SUM(CASE WHEN b.liveawayscore = 0 AND b.bettype in (33, 43) THEN ABS(b.stake)/2 ELSE ABS(b.stake) END) AS TurnOver
			   ,SUM(CASE WHEN b.liveawayscore = 0 and b.bettype in(33,43) THEN ABS(b.stake)/2 
					WHEN b.StatusID IN (112,113) AND b.MOdds IN (-0.25, 0.25) AND s.ProductId = 1 THEN ABS(b.stake)/2
					WHEN b.StatusID = 111 AND s.ProductId = 1 THEN 0 
					WHEN s.ProductID = 21 THEN b.oddsspread -- Allbet
					ELSE ABS(b.stake) 
					END) AS TurnoverNoDraw
		       ,SUM(CASE WHEN b.bettype = 1000 THEN oddsspread ELSE CASE WHEN apositiontaking = 1 THEN 0 ELSE comm/(1 - apositiontaking) END END) AS GrossComm
		       ,SUM(winlost - actual_stake) --MemberWinlost
		       ,SUM(playercomm) -- PlayerComm
		       ,ISNULL(SUM(winlost - actual_stake), 0) + ISNULL(SUM(playercomm), 0) --MemberTotal
		       ,SUM(awinlost) -- AgWinlost
		       ,SUM(comm - playercomm) --AgComm
		       ,ISNULL(SUM(awinlost), 0) + ISNULL(SUM(comm - playercomm), 0) --AgTotal
		       ,-ISNULL(SUM(winlost - actual_stake + awinlost + comm), 0) --Company
		       ,COUNT(CASE WHEN b.bettype = 500 THEN NULL ELSE b.transid END) --NoOfTicket
	    FROM dbo.bettrans b WITH(NOLOCK)
			INNER JOIN (
				SELECT
					CASE WHEN ProductID = 27 THEN 5 ELSE ProductID END AS ProductID,
					bettype
				FROM dbo.f_SportBettypeMatrix_Sel(0, 0, 0, 2, '', '', @IsTest) 
			) s ON b.bettype = s.Bettype
	     WHERE 1 = 1 
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
					OR s.ProductID = CASE WHEN @showVB			= 1 THEN 22 ELSE 0 END
					OR s.ProductID = CASE WHEN @showNG2			= 1 THEN 23 ELSE 0 END
					OR s.ProductID = CASE WHEN @showFW          = 1 THEN 24 ELSE 0 END
					OR s.ProductID = CASE WHEN @showLT          = 1 THEN 28 ELSE 0 END
					OR s.ProductID = CASE WHEN @showLK3      = 1 THEN 26 ELSE 0 END
				)
		   AND winlostdate BETWEEN @FDate AND @TDate
		   AND b.statusID NOT IN (101, 102, 103)
		   AND Recommend = @CID
		   AND ruben = 1 
	  GROUP BY CustID, b.bettype

	IF @BalanceUpDay < @FromDate
	BEGIN
		SET @FDate = @FromDate;
	END
	ELSE
	BEGIN
		SET @FDate = @BalanceUpDay;
	END
		
	IF @ToDate > @MoveBetsDay
	BEGIN
		SET @TDate = @MoveBetsDay;
	END
		
    INSERT INTO @AgWinLossDetails
	    SELECT CustID,			
		       SUM(ABS(TurnOver)) AS TurnOver
			   ,SUM(ABS(TunroverNoDraw)) as TurnoverNoDraw
		       ,SUM(grosscomm) AS GrossComm
		       ,SUM(winlost) --MemberWinlost
		       ,SUM(playercomm) -- PlayerComm
		       ,ISNULL(SUM(winlost), 0) + ISNULL(SUM(playercomm), 0) --MemberTotal
		       ,SUM(awinlost) -- AgWinlost
		       ,SUM(comm - playercomm) --AgComm
		       ,ISNULL(SUM(awinlost), 0) + ISNULL(SUM(comm - playercomm), 0) --AgTotal
		       ,-ISNULL(SUM(winlost + awinlost + comm), 0) --Company
		       ,SUM(betcount) --NoOfTicket
	      FROM dbo.sum_winloss b WITH (NOLOCK) INNER JOIN @TmpCondSumWL t
	        ON b.sporttype = t.sporttype
	       AND b.bettype = t.bettype
	     WHERE 1 = 1
		   AND winlostdate BETWEEN @FDate AND @TDate			
		   AND recommend = @CID
		   AND RoleID = 1
	  GROUP BY CustID
END

IF @FromDate < @BalanceUpDay 
BEGIN
	SELECT @FDate = @FromDate, @TDate = @ToDate

	IF @ToDate >= DATEADD(dd, -1, @BalanceUpDay)
		SELECT @TDate = DATEADD(dd, -1, @BalanceUpDay)
	
	IF @FromDate < '2016-06-01' AND @IsHide = 1 AND @LoginName <> 'bodbDownlineNetView' --- acc internal login 
		SELECT @FDate = '2016-06-01'	
		
    INSERT INTO @AgWinLossDetails
	    SELECT CustID,			
		       SUM(ABS(TurnOver)) AS TurnOver
			   ,SUM(ABS(TunroverNoDraw)) as TurnoverNoDraw
		       ,SUM(grosscomm) AS GrossComm
		       ,SUM(winlost) --MemberWinlost
		       ,SUM(playercomm) -- PlayerComm
		       ,ISNULL(SUM(winlost), 0) + ISNULL(SUM(playercomm), 0) --MemberTotal
		       ,SUM(awinlost) -- AgWinlost
		       ,SUM(comm - playercomm) --AgComm
		       ,ISNULL(SUM(awinlost), 0) + ISNULL(SUM(comm - playercomm), 0) --AgTotal
		       ,-ISNULL(SUM(winlost + awinlost + comm), 0) --Company
		       ,SUM(betcount) --NoOfTicket
	      FROM bodb_Summary.dbo.Sum_WinLoss_Old b WITH(NOLOCK) INNER JOIN @TmpCondSumWL t
	        ON b.sporttype = t.sporttype
	       AND b.bettype = t.bettype
	     WHERE 1 = 1
	       AND winlostdate BETWEEN @FDate AND @TDate
		   AND srecommend = @Srecommend   --- Add Srecommend, Mrecommend to get the index seek 
		   AND mrecommend = @mrecommend
		   AND recommend = @custid		   
		   AND RoleID = 1
	  GROUP BY CustID
END

IF ((@PageSize <= 0) AND (@PageIndex <= 0))
BEGIN
    SELECT w.CustID 
	       ,c.UserName 
	       ,SUM(TurnOver) AS TurnOver
		   ,SUM(TurnoverNoDraw) AS TurnoverNoDraw
	       ,SUM(GrossComm) AS GrossComm
	       ,SUM(MemberWinLost) AS MemberWinlost
	       ,SUM(PlayerComm) AS PlayerComm
	       ,SUM(MemberTotal) AS MemberTotal
	       ,SUM(AgWinlost) AS AgWinlost
	       ,SUM(AgComm) AS AgComm
	       ,SUM(AgTotal) AS AgTotal
	       ,SUM(Company) AS Company
	       ,SUM(NoOfTicket) AS NoOfTicket
      FROM @AgWinLossDetails w INNER JOIN dbo.custInfo c WITH(NOLOCK)
        ON w.CustID = c.CustID 
  GROUP BY w.CustID, c.UserName
  ORDER BY c.Username

    RETURN
END

IF @TotalRows = 0  
BEGIN  
    SELECT @TotalRows = count(tmp.CustID)
      FROM (SELECT CustID
              FROM @AgWinLossDetails
          GROUP BY CustID
           ) tmp
END


SELECT wl.*
  FROM (SELECT w.CustID
               ,c.UserName
               ,SUM(TurnOver) AS TurnOver
			   ,SUM(TurnoverNoDraw) AS TurnoverNoDraw
               ,SUM(GrossComm) AS GrossComm
               ,SUM(MemberWinLost) AS MemberWinlost
               ,SUM(PlayerComm) AS PlayerComm
               ,SUM(MemberTotal) AS MemberTotal
               ,SUM(AgWinlost) AS AgWinlost
               ,SUM(AgComm) AS AgComm
               ,SUM(AgTotal) AS AgTotal
               ,SUM(Company) AS Company
               ,SUM(NoOfTicket) AS NoOfTicket
               ,ROW_NUMBER() OVER (ORDER BY c.UserName) AS RowNum	
          FROM @AgWinLossDetails w INNER JOIN Customer c WITH(NOLOCK)
            ON w.CustID = c.CustID 
      GROUP BY w.CustID, c.UserName
       ) wl
 WHERE wl.RowNum BETWEEN @RowStart AND @RowEnd
 GO