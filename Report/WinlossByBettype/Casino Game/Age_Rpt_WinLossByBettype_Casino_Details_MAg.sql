ALTER PROCEDURE [dbo].[Age_Rpt_WinLossByBettype_Casino_Details_MAg]
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
DECLARE @MAgWinLoss TABLE
(
	bettype int,
	TurnOver money, 
	AgTotal money, 
	MAgWinlost money, 
	Comm money, 
	MAgTotal money, 
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
	INSERT INTO @MAgWinLoss
	SELECT b.bettype
			,SUM(CASE WHEN winlostdate >= @ABSDate THEN ABS(stake) ELSE stake END) AS TurnOver
			,isnull(SUM(winlost - actual_stake), 0) + isnull(SUM(awinlost), 0) + isnull(SUM(comm), 0)
			,SUM(mwinlost)
			,isnull(SUM(acomm), 0) - isnull(SUM(comm), 0)
			,isnull(SUM(mwinlost), 0) + isnull(SUM(acomm), 0) - SUM(comm)
			,- (isnull(SUM(awinlost), 0) + isnull(SUM(mwinlost), 0) + isnull(SUM(acomm), 0) + isnull(SUM(winlost - actual_stake), 0))
	FROM dbo.bettrans b WITH (NOLOCK)
		INNER JOIN @SportBettype s ON(b.bettype = s.Bettype)
	WHERE winlostdate BETWEEN @FromDate AND @ToDate
		AND statusID NOT IN (101, 102, 103)
		AND ruben = 1
		AND mrecommend = @CustID
		AND s.ProductID = 6
	GROUP BY b.bettype		
	UNION ALL
	SELECT b.bettype
			,SUM(CASE WHEN winlostdate >= @ABSDate THEN ABS(stake) ELSE stake END) AS TurnOver
			,isnull(SUM(winlost - actual_stake), 0) + isnull(SUM(awinlost), 0) + isnull(SUM(comm), 0)
			,SUM(mwinlost)
			,isnull(SUM(acomm), 0) - isnull(SUM(comm), 0)
			,isnull(SUM(mwinlost), 0) + isnull(SUM(acomm), 0) - SUM(comm)
			,- (isnull(SUM(awinlost), 0) + isnull(SUM(mwinlost), 0) + isnull(SUM(acomm), 0) + isnull(SUM(winlost - actual_stake), 0))
	FROM dbo.bettrans14 b WITH (NOLOCK)
		INNER JOIN @SportBettype s ON(b.bettype = s.Bettype)
	WHERE winlostdate BETWEEN @FromDate AND @ToDate
		AND statusID NOT IN (101, 102, 103)
		AND ruben = 1
		AND mrecommend = @CustID
		AND s.ProductID = 6
	GROUP BY b.bettype
END

SELECT bettype,
	   SUM(TurnOver) as TurnOver,	
	   SUM(AgTotal) as AgTotal,
	   SUM(MAgWinlost) as MAgWinlost,
	   SUM(Comm) as Comm,
	   SUM(MAgTotal) as MAgTotal,
	   SUM(Company) as Company
  FROM @MAgWinLoss 
 Group by bettype
 ORDER BY bettype

END
GO
GRANT EXECUTE ON [dbo].[Age_Rpt_WinLossByBettype_Casino_Details_MAg] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_Rpt_WinLossByBettype_Casino_Details_MAg] TO [bodbDownlineNetView]
GO
GRANT EXECUTE ON [dbo].[Age_Rpt_WinLossByBettype_Casino_Details_MAg] TO [vnteam]
GO