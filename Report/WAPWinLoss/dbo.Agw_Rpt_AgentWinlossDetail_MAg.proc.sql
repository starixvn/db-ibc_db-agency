ALTER PROCEDURE [dbo].[Agw_Rpt_AgentWinlossDetail_MAg]	
	@MRecommend int = NULL,
	@FromDate smalldatetime,
	@ToDate smalldatetime,
	@showSB bit=1,
	@showCasino bit=0,
	@showRB bit=0, -- Include RB information
	@showFI bit=0, -- Include FI information
	@showP2P bit=0,
	@showNG bit=0, -- Number game
	@showBI bit = 0, --Bingo
	@showLiveCasino BIT = 0,
	@showVS BIT = 0,
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
DB: DBAGE/BODB02
Original: Age_Rpt_WinLossDetail_MAg
Revisions:
	- 20090418@Tuan: For Casino (Tuan)
	- 20090526@Lee: include argument for HR, FI
	- 20090604@Phuc: exclude 'Refund' bets.
	- 20091123@Kiwi: + Use another @TmpCondSumWL to optimize when joining with table sum_winloss/sum_winloss_old
					 + Amend to use bodb_Summary.dbo.Sum_WinLoss_Old instead of DB06.bodb_archive.dbo.Sum_Winloss_Old
	- 20100118@Jamie: Remove @mrecommend and @srecommend 'coz of moving accounts 
	- 20100527@Henry: Change to use StatusID instead of Status in WHERE statement
	- 20100902@Kiwi: Turn back to use bettype directly from bettrans rather than @TmpCond table
	- 20100922@Johnson: add two parameters @showNG and @showBI
	- 20110310@Lukas: add more sporttype 151, 152 & change param @ShowHR -> @ShowRB
	- 20110801@Sophia: change the range of number game's bettype from 81 to 120
	- 20110907@Tom: Change range of bet type : 0->30, apply new bet type 1st correct score on Sport Books
	- 20110928@Tom: Edit Report for P2P Games Sport : 251->253 , Bettype: 72->1000	
	- 20111130@Sophia:  . Change the range of Sport book bettype>=121 and bettype<=999
						. Fix AgComm
	- 20120117@Sophia:  Add LiveCasino: Sporttype: 162, bettype: 1101 ->1199
	- 20120803@Sophia:  .Add Virtual Sports: sporttype=180 for representing, bettype: 1201->1299
						.Remove Financial product
	- 20121108@Johnson: Add new range bettype for tennis: 1301 -> 1334
	- 20130121@Dan: add linked server DBSUM for bodb_Summary
*/
SET NOCOUNT ON

DECLARE @MAgWinLossDetails TABLE(CustID int, AgWinLost money, AgComm money, AgTotal money)

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
IF @showNG = 1
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

IF @Todate >= @BalanceUpDay
BEGIN 
	INSERT INTO @MAgWinLossDetails
		SELECT
			Recommend,						
			sum(awinlost), -- AgWinlost
			sum(comm-playercomm), --AgComm
			isnull(sum(winlost-actual_stake), 0)+isnull(sum(awinlost), 0) + isnull(sum(comm), 0) --AgTotal						
		FROM
			dbo.Bettrans b WITH (NOLOCK)
		WHERE
			(
				bettype < case when @showSB=1 then 31  else 0 end
				OR bettype between 121 and case when @showSB=1 then 999 else 0 end				
				OR bettype between 1301 and case when @showSB = 1 then 1334 else 0 end
				OR bettype between 31 and case when @ShowRB=1 then 49 else 0 end
				OR bettype = case when @showCasino=1 then 71 else 0 end
				OR bettype = case when @showP2P=1 then 1000 else 0 end
				OR bettype between 81 and (case when @showNG = 1 then 120 else 0 end)
				OR bettype = case when @showBI = 1 then 73 else 0 end
				OR bettype BETWEEN 1101 AND (CASE WHEN @showLiveCasino =1 THEN 1199 ELSE 0 END)  
				OR bettype BETWEEN 1201 AND (CASE WHEN @showVS =1 THEN 1299 ELSE 0 END)  
			) AND 
			mrecommend=@MRecommend  
			and winlostdate between @FromDate and @todate
			--and status not in ('VOID','REJECT','Refund')  
			and ruben=1  
			and b.statusID not in (101, 102, 103) 			
		GROUP BY Recommend	
	
	if @BalanceUpDay < @FromDate
		select @BalanceUpDay=@FromDate
		
	INSERT INTO @MAgWinLossDetails
		SELECT
			CustID,			
			sum(awinlost), -- AgWinlost
			sum(comm-playercomm), --AgComm
			isnull(sum(winlost), 0)+isnull(sum(awinlost), 0) + isnull(sum(comm), 0) --AgTotal
		FROM
			dbo.Sum_Winloss b with (nolock) INNER JOIN @TmpCondSumWL t on b.sporttype = t.sporttype and b.bettype = t.bettype
		WHERE
			winlostdate between @BalanceUpDay and @todate
			and MRecommend = @MRecommend
			and RoleID = 2
		GROUP BY CustID			
END

IF @FromDate < @BalanceUpDay 
BEGIN
	if @ToDate >= DATEADD(dd, -1, @BalanceUpDay)
		select @ToDate = DATEADD(dd, -1, @BalanceUpDay)
		
	INSERT INTO @MAgWinLossDetails
		SELECT
			CustID,			
			sum(awinlost), -- AgWinlost
			sum(comm-playercomm), --AgComm
			isnull(sum(winlost), 0)+isnull(sum(awinlost), 0) + isnull(sum(comm), 0) --AgTotal			
		FROM
			DBSUM.bodb_Summary.dbo.Sum_WinLoss_Old b with (nolock) INNER JOIN @TmpCondSumWL t on b.sporttype = t.sporttype and b.bettype = t.bettype
		WHERE
			winlostdate between @fromdate and @ToDate			
			and MRecommend = @MRecommend
			and RoleID = 2
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
		FROM @MAgWinLossDetails w INNER JOIN custinfo c WITH(NOLOCK) ON w.CustID = c.CustID 
		Group by w.CustID
	) as c
END

SELECT custid, username, Winlost, Comm, Total FROM
(

SELECT
	w.CustID, 
	c.UserName, 
	sum(AgWinlost) as Winlost, --AgWinlost
	sum(AgComm) as Comm, --AgComm
	sum(AgTotal) as Total, --AgTotal
	ROW_NUMBER() over (order by c.username) as RowNum 
FROM @MAgWinLossDetails w INNER JOIN custinfo c WITH(NOLOCK) ON w.CustID = c.CustID 
Group by w.CustID, c.UserName

)as c

WHERE RowNum between @RowStart and @RowEnd


GO
GRANT EXECUTE ON [dbo].[Agw_Rpt_AgentWinlossDetail_MAg] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Agw_Rpt_AgentWinlossDetail_MAg] TO [bodbDownlineNetView]
GO
GRANT VIEW DEFINITION ON [dbo].[Agw_Rpt_AgentWinlossDetail_MAg] TO [vnteam]