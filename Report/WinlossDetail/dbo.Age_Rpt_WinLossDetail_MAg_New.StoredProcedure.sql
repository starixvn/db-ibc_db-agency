ALTER PROCEDURE [dbo].[Age_Rpt_WinLossDetail_MAg_New]
	@custid         int = NULL,--mrecommend
	@FromDate       smalldatetime,
	@ToDate         smalldatetime,
	@showSB         bit=1,
	@showCasino     bit=0,
	@showP2P        bit=0,
	@showRB         bit=0,
	@showFI         bit=0,
	@showNG         BIT=0,
	@showBI         BIT=0,
	@showLiveCasino BIT = 0,
	@showVS         BIT = 0,
	@showKeno       BIT = 0,
	@BalanceUpDay   SMALLDATETIME,
	@PageSize       int=0,
	@PageIndex      int=0,
	@TotalRows      int=0 output
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
*/

SET NOCOUNT ON

DECLARE @RowStart int, @RowEnd int  
SELECT @PageIndex = @PageIndex - 1,
       @RowStart = @PageSize * @PageIndex + 1,
       @RowEnd = @RowStart + @PageSize - 1


DECLARE @MAgWinLossDetails TABLE
(
    CustID int, 
    TurnOver money, 
    GrossComm money, 
    MemberWinLost money, 
	PlayerComm money, 
	MemberTotal money, 
	AgWinLost money, 
	AgComm money, 
	AgTotal money, 
	MAgWinLost money, 
	MAgComm money, 
	MAgTotal money, 
	Company money,
	NoOfTicket int
)


DECLARE @TmpCondSumWL TABLE(sporttype INT, bettype INT)
IF @ShowSB = 1
BEGIN
	--Sum_winloss
	INSERT INTO @TmpCondSumWL(sporttype, Bettype)
	VALUES(0,0)	
END

IF @ShowCasino = 1
BEGIN
	--Sum_winloss
	INSERT INTO @TmpCondSumWL(sporttype, Bettype)
	VALUES(251,71)
END

IF @ShowP2P = 1
BEGIN
	--Sum_winloss
	INSERT INTO @TmpCondSumWL(sporttype, Bettype)
	VALUES(253,1000)
END

IF @ShowRB = 1
BEGIN
	--Sum_winloss
	INSERT INTO @TmpCondSumWL(Sporttype, Bettype)
	SELECT 151,0
END

IF @ShowNG = 1
BEGIN
	--Sum_winloss
	INSERT INTO @TmpCondSumWL(Sporttype, Bettype)
	VALUES(161,0)
END

IF @ShowBI = 1
BEGIN
	--Sum_winloss
	INSERT INTO @TmpCondSumWL(Sporttype, Bettype)
	VALUES(252,73)
END

IF @showLiveCasino = 1
BEGIN
 --Sum_winloss  
 INSERT INTO @TmpCondSumWL(Sporttype, Bettype)  
 VALUES(162,0) 
END

IF @showVS = 1
BEGIN
 --Sum_winloss  
 INSERT INTO @TmpCondSumWL(Sporttype, Bettype)  
 VALUES(180,0) 
END

IF @showKeno = 1
BEGIN
 --Sum_winloss  
 INSERT INTO @TmpCondSumWL(Sporttype, Bettype)  
 VALUES(202,0) 
END

IF @Todate >= @BalanceUpDay
BEGIN 
    INSERT INTO @MAgWinLossDetails
	    SELECT Recommend,			
			   SUM(case when b.liveawayscore = 0 and b.bettype in (33, 43) then ABS(b.stake)/2 else ABS(b.stake) end) as TurnOver, 
		    --SUM(acomm/(1-apositiontaking-mpositiontaking)) as GrossComm,
			---- @Lukas20111024: hot fix - casino only
			   SUM(case when b.bettype = 1000 then oddsspread else case when (apositiontaking + mpositiontaking = 1) then 0 else acomm/(1 - apositiontaking - mpositiontaking) end end) as GrossComm,
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
	     WHERE 1 = 1
		   and (bettype < case when @showSB = 1 then 31 else 0 end
				OR bettype between 121 and case when @showSB = 1 then 999 else 0 end
				OR bettype between 1301 and case when @showSB = 1 then 1399 else 0 end
				OR bettype between 31 and case when @ShowRB = 1 then 49 else 0 end
				OR bettype = case when @showCasino = 1 then 71 else 0 end
				OR bettype = case when @showP2P = 1 then 1000 else 0 end
				OR bettype BETWEEN 81 AND (CASE WHEN @showNG = 1 THEN 120 ELSE 0 END)
				OR bettype = (CASE WHEN @showBI = 1 THEN 73 ELSE 0 END)
				OR bettype BETWEEN 1101 AND (CASE WHEN @showLiveCasino = 1 THEN 1199 ELSE 0 END) 
				OR bettype BETWEEN 1201 AND (CASE WHEN @showVS = 1 THEN 1299 ELSE 0 END)
				OR b.bettype BETWEEN 1501 AND CASE WHEN @showKeno = 1 then 1599 ELSE 0 END
			   )
		   and winlostdate between @FromDate and @todate
		    --status not in ('running','waiting','VOID', 'REJECT', 'Refund') and
		   and statusID not in (101, 102, 103)
		   and ruben = 1
		   and mrecommend = @custid
	  GROUP BY Recommend, b.bettype
		
	if @BalanceUpDay < @FromDate
	    select @BalanceUpDay=@FromDate
	
    INSERT INTO @MAgWinLossDetails
	    SELECT CustID,			
		       SUM(ABS(TurnOver)) as TurnOver,
		       SUM(grosscomm) as GrossComm,
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
		   and winlostdate between @BalanceUpDay and @todate			
		   and MRecommend = @custid
		   and RoleID = 2
	  GROUP BY CustID
END

IF @FromDate < @BalanceUpDay 
BEGIN
	if @ToDate >= DATEADD(dd, -1, @BalanceUpDay)
		select @ToDate = DATEADD(dd, -1, @BalanceUpDay)
	
    INSERT INTO @MAgWinLossDetails
	    SELECT CustID,			
		       SUM(ABS(TurnOver)) as TurnOver,
		       SUM(grosscomm) as GrossComm,
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
		   and winlostdate between @fromdate and @ToDate			
		   and MRecommend = @custid
		   and RoleID = 2
	  GROUP BY CustID
END	


IF ((@PageSize <= 0) AND (@PageIndex <= 0))
BEGIN
    SELECT w.CustID, 
	       c.UserName, 
	       SUM(TurnOver) as TurnOver,
	       SUM(GrossComm) as GrossComm,
	       SUM(MemberWinLost) as MemberWinlost,
	       SUM(PlayerComm) as PlayerComm,
	       SUM(MemberTotal) as MemberTotal,
	       SUM(AgWinlost) as AgWinlost,
	       SUM(AgComm) as AgComm,
	       SUM(AgTotal) as AgTotal,
	       SUM(MAgWinlost) as MAgWinlost,
	       SUM(MAgComm) as MAgComm,
	       SUM(MAgTotal) as MAgTotal,
	       SUM(Company) as Company,
	       SUM(NoOfTicket) as NoOfTicket
      FROM @MAgWinLossDetails w INNER JOIN Customer c WITH(NOLOCK)
        ON w.CustID = c.CustID 
  Group by w.CustID, c.UserName
  order by c.Username

    RETURN
END


IF @TotalRows = 0  
BEGIN  
    SELECT @TotalRows = count(tmp.CustID)
      FROM (SELECT CustID
              FROM @MAgWinLossDetails
          Group by CustID
           ) tmp
 
END

SELECT wl.*
  FROM (SELECT w.CustID, 
	           c.UserName, 
	           SUM(TurnOver) as TurnOver,
	           SUM(GrossComm) as GrossComm,
	           SUM(MemberWinLost) as MemberWinlost,
	           SUM(PlayerComm) as PlayerComm,
	           SUM(MemberTotal) as MemberTotal,
	           SUM(AgWinlost) as AgWinlost,
	           SUM(AgComm) as AgComm,
	           SUM(AgTotal) as AgTotal,
	           SUM(MAgWinlost) as MAgWinlost,
	           SUM(MAgComm) as MAgComm,
	           SUM(MAgTotal) as MAgTotal,
	           SUM(Company) as Company,
	           SUM(NoOfTicket) as NoOfTicket,
	           ROW_NUMBER() over (order by c.UserName) as RowNum
          FROM @MAgWinLossDetails w INNER JOIN Customer c WITH(NOLOCK)
            ON w.CustID = c.CustID 
      Group by w.CustID, c.UserName
       ) wl
    
 WHERE 1 = 1
   and wl.RowNum between @RowStart and @RowEnd


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