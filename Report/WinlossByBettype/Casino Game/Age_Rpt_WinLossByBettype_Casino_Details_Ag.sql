ALTER PROCEDURE [dbo].[Age_Rpt_WinLossByBettype_Casino_Details_Ag]
	@CustID 	INT,
	@FromDate 	SMALLDATETIME,
	@ToDate 	SMALLDATETIME,	
	@BalanceUpDay SMALLDATETIME	
AS

/*
Created: 
Task : Report WinLoss
DB: DBAGE.bodb02
Revisions:
*/

BEGIN
SET NOCOUNT ON
DECLARE @AgWinLoss TABLE
(
	bettype int,
	TurnOver money, 
	MemberWinLost money, 
	AgWinLost money, 
	PlayerComm money, 
	AgComm money, 
	MemberTotal money, 
	AgTotal money, 
	Company money
)
DECLARE @ABSDate DATETIME
SET @ABSDate = '2011-09-01'

DECLARE @SportBettype TABLE(
	ProductID INT
	,Bettype INT
	,EventType INT
)

INSERT INTO @SportBettype
EXEC dbo.Acc_SportBettypeMatrix_Sel @mode = 4

IF @Todate >= @BalanceUpDay 
BEGIN
	
	INSERT INTO @AgWinLoss
	SELECT b.bettype,
		   SUM(CASE WHEN winlostdate >= @ABSDate THEN ABS(stake) ELSE stake END) as TurnOver,
		   SUM(winlost - actual_stake),
		   SUM(awinlost),
		   SUM(playercomm),
		   SUM(comm - playercomm),
		   isnull(SUM(winlost - actual_stake), 0) + isnull(SUM(playercomm), 0) as MemberTotal,
		   isnull(SUM(awinlost), 0) + isnull(SUM(comm - playercomm), 0) as AgTotal,
		   -SUM(winlost - actual_stake + awinlost + comm)
	FROM Bettrans b WITH(NOLOCK)
		INNER JOIN @SportBettype s ON(b.bettype = s.Bettype)
	WHERE winlostdate between @FromDate and @ToDate
	   and ruben = 1
	   and statusID not in (101, 102, 103)
	   and recommend = @custid
	   AND  s.ProductID = 6
	GROUP BY b.bettype
	UNION ALL
	SELECT b.bettype,
		   SUM(CASE WHEN winlostdate >= @ABSDate THEN ABS(stake) ELSE stake END) as TurnOver,
		   SUM(winlost - actual_stake),
		   SUM(awinlost),
		   SUM(playercomm),
		   SUM(comm - playercomm),
		   isnull(SUM(winlost - actual_stake), 0) + isnull(SUM(playercomm), 0) as MemberTotal,
		   isnull(SUM(awinlost), 0) + isnull(SUM(comm - playercomm), 0) as AgTotal,
		   -SUM(winlost - actual_stake + awinlost + comm)
	FROM Bettrans14 b WITH(NOLOCK)
		INNER JOIN @SportBettype s ON(b.bettype = s.Bettype)
	WHERE winlostdate between @FromDate and @ToDate
	   and ruben = 1
	   and statusID not in (101, 102, 103)
	   and recommend = @custid
	   AND  s.ProductID = 6
	GROUP BY b.bettype
END

SELECT bettype,
       SUM(TurnOver) as TurnOver,
       SUM(MemberWinLost) as MemberWinLost,
       SUM(playercomm) as PlayerComm,
       SUM(MemberTotal) as MemberTotal,
       SUM(AgWinLost) as AgWinLost,
       SUM(AgComm) as AgComm,
       SUM(AgTotal) as AgTotal,
       SUM(company) as Company
 FROM @AgWinLoss
 GROUP BY bettype
 ORDER BY bettype

END

GO
GRANT EXECUTE ON [dbo].[Age_Rpt_WinLossByBettype_Casino_Details_Ag] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_Rpt_WinLossByBettype_Casino_Details_Ag] TO [bodbDownlineNetView]
GO
GRANT EXECUTE ON [dbo].[Age_Rpt_WinLossByBettype_Casino_Details_Ag] TO [vnteam]
GO