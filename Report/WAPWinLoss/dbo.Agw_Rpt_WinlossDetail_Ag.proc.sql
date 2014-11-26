ALTER PROCEDURE [Agw_Rpt_WinlossDetail_Ag]
	@Recommend int = NULL,
	@FromDate smalldatetime,
	@ToDate smalldatetime,
	@showSB bit=1,
	@showCasino bit=0,
	@showP2P bit=0,
	@showRB bit=0, -- Include RB information
	@showFI bit=0, -- Include FI information
	@showNG bit=0, -- Number game
	@showBI bit=0, -- Bingo
	@showLiveCasino BIT = 0,
	@showVS BIT = 0,
	@showKeno bit = 0,
	@BalanceUpDay SMALLDATETIME,
	@PageSize int=50,
	@PageIndex int=0,
	@TotalPages int=0 output,
	@TWinlost money=0 output, 
	@TComm money=0 output, 
	@TTotal money=0 output
AS
/*
Created:
Task:
DB: DBAGE/bodb02
Original: Age_Rpt_WinLossDetail_Ag_1
Revisions:
	- 20090418@Tuan: For Casino (Tuan)
	- 20090526@Lee: include argument for HR, FI
	- 20090604@Phuc: exclude 'Refund' bets.
	- 20091123@Kiwi: + Use another @TmpCondSumWL to optimize when joining with table sum_winloss/sum_winloss_old
					 + Amend to use bodb_Summary.dbo.Sum_WinLoss_Old instead of DB06.bodb_archive.dbo.Sum_Winloss_Old	
	- 20100118@Jamie: Remove @mrecommend and @srecommend 'coz of moving accounts 
	- 20100527@Henry: Change to use StatusID instead of Status in WHERE statement
	- 20100902@Kiwi: Turn back to use bettype directly from bettrans rather than @TmpCond table	
	- 20100921@Johnson : add two parameters @showNG, @showBI and calculate Winloss base on number game and bingo	
	- 20110310@Lukas: Change param: @ShowHR -> @ShowRB
	- 20110801@Sophia: change the range of number game's bettype from 81 to 120
	- 20110907@Tom: Change range of bet type : 0->30, 
				apply new bet type 1st correct score on Sport Books	
	- 20110928@Tom: Edit Report for P2P Games Sport : 251->253 , Bettype: 72->1000	
	- 20111130@Sophia: Change the range of Sport book bettype>=121 and bettype<=999		
	- 20120117@Sophia:  Add LiveCasino: Sporttype: 162, bettype: 1101 ->1199
	- 20120808@Sophia:  .Add Virtual Sports: sporttype=180 for representing, bettype: 1201->1299
						.Remove Financial product
	- 20121108@Johnson: Add new range bettype for tennis: 1301 -> 1334
	- 20130121@Dan: add linked server DBSUM for bodb_Summary
	- 20140303@Kathy: Apply Keno product (from 1501 -> 1599)[Redmine:#12691]
	- 20140926@Sophia:  Expand the range of Sporting Solution (1301 -> 1399)  [Redmine: #23446]
*/
SET NOCOUNT ON

DECLARE @AgWinLossDetails TABLE(CustID int, AgWinLost money, AgComm money, AgTotal money)
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
	--Sum_Winloss
	INSERT INTO @TmpCondSumWL(Sporttype, Bettype)
	VALUES(161,0)
END
IF @showBI = 1
BEGIN
	--Sum_Winloss
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
	INSERT INTO @AgWinLossDetails
		SELECT
			CustID,						
			sum(awinlost), -- AgWinlost
			sum(comm-playercomm), --AgComm
			isnull(sum(awinlost), 0) + isnull(sum(comm-playercomm), 0) --AgTotal			
		FROM
			dbo.Bettrans b with (nolock)
		WHERE
			(
				bettype < case when @showSB=1 then 31  else 0 end
				OR bettype between 121 and case when @showSB=1 then 999 else 0 end
				OR bettype between 1301 and case when @showSB=1 then 1399 else 0 end
				OR bettype between 31 and case when @ShowRB=1 then 49 else 0 end
				OR bettype = case when @showCasino=1 then 71 else 0 end
				OR bettype = case when @showP2P=1 then 1000 else 0 end
				OR bettype BETWEEN 81 and (case when @showNG = 1 then 120 else 0 end)
				OR bettype = case when @showBI = 1 then 73 else 0 end
				OR bettype BETWEEN 1101 AND (CASE WHEN @showLiveCasino =1 THEN 1199 ELSE 0 END)  
				OR bettype BETWEEN 1201 AND (CASE WHEN @showVS =1 THEN 1299 ELSE 0 END)  
				OR b.bettype BETWEEN 1501 AND CASE WHEN @showKeno = 1 THEN 1599 ELSE 0 END   
			) AND
			winlostdate between @FromDate and @todate
			and Recommend=@Recommend
			and ruben=1 
			--and status not in ('VOID','REJECT','Refund')
			and b.statusID not in (101, 102, 103)
			
		GROUP BY CustID
		
	if @BalanceUpDay < @FromDate
		select @BalanceUpDay=@FromDate	
		
	INSERT INTO @AgWinLossDetails
		SELECT
			CustID,						
			sum(awinlost), -- AgWinlost
			sum(comm-playercomm), --AgComm
			isnull(sum(awinlost), 0) + isnull(sum(comm-playercomm), 0) --AgTotal			
		FROM dbo.Sum_WinLoss b with (nolock) 
			INNER JOIN @TmpCondSumWL t on b.sporttype = t.sporttype and b.bettype = t.bettype
		WHERE
			winlostdate between @BalanceUpDay and @todate			
			and recommend = @Recommend
			and RoleID = 1
		GROUP BY CustID		
END

IF @FromDate < @BalanceUpDay 
BEGIN
	if @ToDate >= DATEADD(dd, -1, @BalanceUpDay)
		select @ToDate = DATEADD(dd, -1, @BalanceUpDay)
		
	INSERT INTO @AgWinLossDetails
		SELECT
			CustID,						
			sum(awinlost), -- AgWinlost
			sum(comm-playercomm), --AgComm
			isnull(sum(awinlost), 0) + isnull(sum(comm-playercomm), 0) --AgTotal			
		FROM DBSUM.bodb_Summary.dbo.Sum_WinLoss_Old b with (nolock) 
			INNER JOIN @TmpCondSumWL t on b.sporttype = t.sporttype and b.bettype = t.bettype
		WHERE
			winlostdate between @fromdate and @ToDate			
			and recommend=@Recommend
			and RoleID=1
		GROUP BY CustID	
END

DECLARE @RowCount int, @RowStart int, @RowEnd int  
SELECT @PageIndex = @PageIndex - 1, @RowStart = @PageSize * @PageIndex + 1, @RowEnd = @RowStart + @PageSize - 1  


IF @TotalPages = 0  
BEGIN  
 SELECT @TotalPages = count(c.custid),@TotalPages=@TotalPages/@PageSize + case when @TotalPages%@PageSize > 0 then 1 else 0 end  
		,@TWinlost = sum(c.Winlost), @TComm = sum(c.Comm), @TTotal = sum(c.Total) 
 FROM
	(
		SELECT
			w.CustID, 	
			sum(AgWinlost) as Winlost, --AgWinlost
			sum(AgComm) as Comm, --AgComm
			sum(AgTotal) as Total --AgTotal
		FROM @AgWinLossDetails w 
			INNER JOIN custinfo c WITH(NOLOCK) ON w.CustID = c.CustID 
		Group by w.CustID
	) as c
	
END


SELECT custid, username, Winlost, Comm, Total FROM
(

SELECT
	w.CustID as custid, 
	c.UserName as username, 	
	sum(AgWinlost) as Winlost, --AgWinlost
	sum(AgComm) as Comm, --AgComm
	sum(AgTotal) as Total, --AgTotal
	ROW_NUMBER() over (order by c.username) as RowNum 
FROM @AgWinLossDetails w INNER JOIN custinfo c WITH(NOLOCK) ON w.CustID = c.CustID 
Group by w.CustID, c.UserName

)as c

WHERE RowNum between @RowStart and @RowEnd





GO
GRANT EXECUTE ON [dbo].[Agw_Rpt_WinlossDetail_Ag] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Agw_Rpt_WinlossDetail_Ag] TO [bodbDownlineNetView]
GO
GRANT VIEW DEFINITION ON [dbo].[Agw_Rpt_WinlossDetail_Ag] TO [vnteam]