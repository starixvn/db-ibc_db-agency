ALTER PROCEDURE [dbo].[Age_Rpt_WinLossByBettype_Casino_Details_SAg]
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

DECLARE @SAgWinLoss TABLE
(
	bettype int,
	TurnOver money, 
	MAgTotal money, 
	SAgWinlost money, 
	Comm money, 
	SAgTotal money, 
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

	INSERT INTO @SAgWinLoss
	SELECT b.bettype
			,SUM(CASE WHEN winlostdate >= @ABSDate THEN ABS(stake) ELSE stake END) AS TurnOver
			,SUM(mwinlost + awinlost + acomm + winlost - actual_stake)
			,SUM(swinlost)
			,isnull(SUM(scomm), 0) - isnull(SUM(acomm), 0)
			,isnull(SUM(swinlost), 0) + isnull(SUM(scomm), 0) - SUM(acomm)
			,- (isnull(SUM(swinlost), 0) + isnull(SUM(awinlost), 0) + isnull(SUM(mwinlost), 0) + isnull(SUM(scomm), 0) + isnull(SUM(winlost - actual_stake), 0))
		FROM dbo.bettrans b WITH(NOLOCK, INDEX = IX_srecommend)
			INNER JOIN @SportBettype s ON (b.bettype = s.Bettype)
		WHERE winlostdate BETWEEN @FromDate AND @ToDate
			AND statusID NOT IN (0, 1, 101, 102, 103)
			AND SRecommend = @CustID
			AND s.ProductID = 6
		GROUP BY b.bettype
	UNION ALL
	SELECT b.bettype
			,SUM(CASE WHEN winlostdate >= @ABSDate THEN ABS(stake) ELSE stake END) AS TurnOver
			,SUM(mwinlost + awinlost + acomm + winlost - actual_stake)
			,SUM(swinlost)
			,isnull(SUM(scomm), 0) - isnull(SUM(acomm), 0)
			,isnull(SUM(swinlost), 0) + isnull(SUM(scomm), 0) - SUM(acomm)
			,- (isnull(SUM(swinlost), 0) + isnull(SUM(awinlost), 0) + isnull(SUM(mwinlost), 0) + isnull(SUM(scomm), 0) + isnull(SUM(winlost - actual_stake), 0))
		FROM dbo.bettrans14 b WITH(NOLOCK)
			INNER JOIN @SportBettype s ON (b.bettype = s.Bettype)
		WHERE winlostdate BETWEEN @FromDate AND @ToDate
			AND statusID NOT IN (0, 1, 101, 102, 103)
			AND SRecommend = @CustID
			AND s.ProductID = 6
		GROUP BY b.bettype
END

SELECT bettype,
	   SUM(TurnOver) as TurnOver,	
	   SUM(MAgTotal) as MAgTotal,
	   SUM(SAgWinlost) as SAgWinlost,
	   SUM(Comm) as Comm,
	   SUM(SAgTotal) as SAgTotal,
	   SUM(Company) as Company
  FROM @SAgWinLoss 
 GROUP BY bettype
 ORDER BY bettype

END

GO
GRANT EXECUTE ON [dbo].[Age_Rpt_WinLossByBettype_Casino_Details_SAg] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_Rpt_WinLossByBettype_Casino_Details_SAg] TO [bodbDownlineNetView]
GO
GRANT EXECUTE ON [dbo].[Age_Rpt_WinLossByBettype_Casino_Details_SAg] TO [vnteam]
GO