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
*/


SET NOCOUNT ON

DECLARE @RowStart	INT
		,@RowEnd	INT
		  
SELECT @PageIndex = @PageIndex - 1
       ,@RowStart = @PageSize * @PageIndex + 1
       ,@RowEnd = @RowStart + @PageSize - 1


DECLARE @MAgWinLossDetails TABLE
(
    CustID			INT
    ,TurnOver		MONEY
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

IF @showKeno = 1
BEGIN
	--Sum_winloss  
	INSERT INTO @TmpCondSumWL(Sporttype, Bettype)  
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
    INSERT INTO @MAgWinLossDetails
	    SELECT Recommend,			
			   SUM(CASE WHEN b.liveawayscore = 0 AND b.bettype IN (33, 43) THEN ABS(b.stake)/2 ELSE ABS(b.stake) END) AS TurnOver, 
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
		       COUNT(b.transid) --No Of Ticket
	    FROM dbo.bettrans b WITH(NOLOCK)
				INNER JOIN @SportBettype s ON(b.bettype = s.Bettype)
		WHERE 
				-- and (bettype < case when @showSB = 1 then 31 else 0 end
				--OR bettype between 121 and case when @showSB = 1 then 999 else 0 end
				--OR bettype between 1301 and case when @showSB = 1 then 1399 else 0 end
				--OR bettype between 31 and case when @ShowRB = 1 then 49 else 0 end
				--OR bettype = case when @showCasino = 1 then 71 else 0 end
				--OR bettype = case when @showP2P = 1 then 1000 else 0 end
				--OR bettype BETWEEN 81 AND (CASE WHEN @showNG = 1 THEN 120 ELSE 0 END)
				--OR bettype = (CASE WHEN @showBI = 1 THEN 73 ELSE 0 END)
				--OR bettype BETWEEN 1101 AND (CASE WHEN @showLiveCasino = 1 THEN 1199 ELSE 0 END) 
				--OR bettype BETWEEN 1201 AND (CASE WHEN @showVS = 1 THEN 1299 ELSE 0 END)
				--OR b.bettype BETWEEN 1501 AND CASE WHEN @showKeno = 1 then 1599 ELSE 0 END
			 --  )
			1 = 1
			AND s.ProductID IN (1, 2, 3, 4, 5, 6, 7)
			AND winlostdate BETWEEN @FromDate AND @todate
			--status not in ('running','waiting','VOID', 'REJECT', 'Refund') and
			AND statusID NOT IN (101, 102, 103)
			AND ruben = 1
			AND mrecommend = @custid
	  GROUP BY Recommend, b.bettype
		
	IF @BalanceUpDay < @FromDate
	    SELECT @BalanceUpDay = @FromDate
	
    INSERT INTO @MAgWinLossDetails
	    SELECT CustID,			
		       SUM(ABS(TurnOver)) AS TurnOver,
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
		   AND winlostdate BETWEEN @BalanceUpDay AND @todate			
		   AND MRecommend = @custid
		   AND RoleID = 2
	  GROUP BY CustID
END

IF @FromDate < @BalanceUpDay 
BEGIN
	IF @ToDate >= DATEADD(dd, -1, @BalanceUpDay)
		SELECT @ToDate = DATEADD(dd, -1, @BalanceUpDay)
	
    INSERT INTO @MAgWinLossDetails
	    SELECT CustID,			
		       SUM(ABS(TurnOver)) AS TurnOver,
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
      FROM @MAgWinLossDetails w INNER JOIN Customer c WITH(NOLOCK)
        ON w.CustID = c.CustID 
  GROUP BY w.CustID, c.UserName
  ORDER BY c.Username

    RETURN
END


IF @TotalRows = 0  
BEGIN  
    SELECT @TotalRows = count(tmp.CustID)
      FROM (SELECT CustID
              FROM @MAgWinLossDetails
          GROUP BY CustID
           ) tmp
 
END

SELECT wl.*
  FROM (SELECT w.CustID, 
	           c.UserName, 
	           SUM(TurnOver) AS TurnOver,
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
          FROM @MAgWinLossDetails w INNER JOIN Customer c WITH(NOLOCK)
            ON w.CustID = c.CustID 
      GROUP BY w.CustID, c.UserName
       ) wl
 WHERE 1 = 1
   AND wl.RowNum BETWEEN @RowStart AND @RowEnd


GO
GRANT EXECUTE ON [dbo].[Age_Rpt_WinLossDetail_MAg_New] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_Rpt_WinLossDetail_MAg_New] TO [bodbDownlineNetView]
GO
GRANT VIEW DEFINITION ON [dbo].[Age_Rpt_WinLossDetail_MAg_New] TO [vnteam]
GO
GRANT EXECUTE ON [dbo].[Age_Rpt_WinLossDetail_MAg_New] TO [bodbAdminNet]
GO
GRANT EXECUTE ON [dbo].[Age_Rpt_WinLossDetail_MAg_New] TO [bodbExtAccNet]