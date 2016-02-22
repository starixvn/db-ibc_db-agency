ALTER PROCEDURE [dbo].[Age_Rpt_WinLossByBettype_MAg]
	@CustID INT,
	@FromDate SMALLDATETIME,
	@ToDate SMALLDATETIME,	
	@BalanceUpDay SMALLDATETIME
AS
/*
Created: 
Task : Report WinLoss
DB: DBAGE.bodb02
Revisions:
     - 20090321@Hiep: Get more result for Casino Integration	
     - 20090602@Kiwi: exclude "refund" tickets.
     - 20090702@AnhPham: include gross commission information for all bet types
     - 20090710@Phuc: exclude grosscomm for casino.
	 - 20091127@Jamie: Change the gross commission by level (super/master/agent)
			+ super  = scomm/(1 - tpos)
			+ master = acomm/(1 - apos - mpos)
			+ agent  = comm /(1 - apos)
		Applied on Dec 1, 2009 
	- 20091211@Jamie: Show Casino grosscomm instead of 0 
	- 20100515@Jamie: Exclude Refund for each way HR 
	- 20100610@Henry: Change to use StatusID instead of Status in WHERE statement
	- 20100619@Phuc: put index hint on bettrans14(index=IX_bettrans4)
	- 20110516@Johnson: Apply new arrange bettype
	- 20110802@Sophia: Add new column liveindicator to separate Fulltime or Deadball, but only for Number Game, if not Number Game not group by liveindicator and return 0 for liveindicator
	- 20110819@Sophia: Count Negative stake as positive turnover
	- 20120608@Elodie: Change the gross commission for P2P
					   Change DB053 server instead of DB052 server
    - 20140509@Logan:	Add counting for number of tickets - Code aligning
	- 20140926@Sophia:  Grouping duplicate bettypes of Sporting Solution and IBC [Redmine: #23444]
	- 20150331@Cody: Apply sport bettype matrix [Redmine: #30169]
	- 20160104@Percy: Include new bettype range into RNG Casino [Redmine: #48283]
*/
SET NOCOUNT ON
DECLARE @MAgWinLoss TABLE
(
	bettype int, 
	liveindicator int,
	GrossComm money,
	TurnOver money, 
	AgTotal money, 
	MAgWinlost money, 
	Comm money, 
	MAgTotal money, 
	Company money,
	NoOfTicket int
)

DECLARE @ABSDate DATETIME
SET @ABSDate = '2011-09-01'

DECLARE @SportBettype TABLE(
			ProductID INT
			,Bettype INT
			,EventType INT
		)
		
INSERT INTO @SportBettype
EXEC bodb02.dbo.Acc_SportBettypeMatrix_Sel @mode=4

IF @Todate >= @BalanceUpDay 
BEGIN
		INSERT INTO @MAgWinLoss
		SELECT b.bettype
			,liveindicator
			,SUM(acomm / (1 - apositiontaking - mpositiontaking)) AS GrossComm
			,SUM(CASE 
					WHEN winlostdate >= @ABSDate THEN CASE 
							WHEN b.bettype IN (33, 43)
								AND liveawayscore = 0 THEN ABS(stake) / 2
							ELSE ABS(stake)
							END
					ELSE CASE 
							WHEN b.bettype IN (33, 43)
								AND liveawayscore = 0 THEN stake / 2
							ELSE stake
							END
					END) AS TurnOver
			,isnull(SUM(winlost - actual_stake), 0) + isnull(SUM(awinlost), 0) + isnull(SUM(comm), 0)
			,SUM(mwinlost)
			,isnull(SUM(acomm), 0) - isnull(SUM(comm), 0)
			,isnull(SUM(mwinlost), 0) + isnull(SUM(acomm), 0) - SUM(comm)
			,- (isnull(SUM(awinlost), 0) + isnull(SUM(mwinlost), 0) + isnull(SUM(acomm), 0) + isnull(SUM(winlost - actual_stake), 0))
			,COUNT(transid) AS NoOfTicket
		FROM dbo.bettrans b WITH (NOLOCK)
			INNER JOIN @SportBettype s ON(b.bettype = s.Bettype)
		WHERE 1 = 1
			AND winlostdate BETWEEN @FromDate AND @ToDate
			AND statusID NOT IN (101, 102, 103)
			--status not in ('VOID', 'REJECT', 'Refund')  and
			AND ruben = 1
			AND mrecommend = @CustID
			--AND bettype < 19001
			--AND bettype BETWEEN 81 AND 120
			AND s.ProductID = 3
		GROUP BY b.bettype,liveindicator
		
		UNION ALL -- RNG Casino not group by bettype
		SELECT 71 AS bettype
			,0 AS liveindicator
			,SUM(acomm / (1 - apositiontaking - mpositiontaking)) AS GrossComm
			,SUM(CASE WHEN winlostdate >= @ABSDate THEN ABS(stake) ELSE stake END) AS TurnOver
			,isnull(SUM(winlost - actual_stake), 0) + isnull(SUM(awinlost), 0) + isnull(SUM(comm), 0)
			,SUM(mwinlost)
			,isnull(SUM(acomm), 0) - isnull(SUM(comm), 0)
			,isnull(SUM(mwinlost), 0) + isnull(SUM(acomm), 0) - SUM(comm)
			,- (isnull(SUM(awinlost), 0) + isnull(SUM(mwinlost), 0) + isnull(SUM(acomm), 0) + isnull(SUM(winlost - actual_stake), 0))
			,COUNT(transid) AS NoOfTicket
		FROM dbo.bettrans b WITH (NOLOCK)
			INNER JOIN @SportBettype s ON(b.bettype = s.Bettype)
		WHERE winlostdate BETWEEN @FromDate AND @ToDate
			AND statusID NOT IN (101, 102, 103)
			AND ruben = 1
			AND mrecommend = @CustID
			AND s.ProductID = 6
		GROUP BY s.ProductID

		UNION ALL --- Not number Game not group by liveindicator
		SELECT
			CASE WHEN ISNULL(f.bettype,0) = 0 THEN b.bettype ELSE f.GroupTypeId END AS bettype
			,0 AS liveindicator
			,SUM(CASE 
					WHEN b.bettype = 1000 THEN oddsspread
					ELSE acomm / (1 - apositiontaking - mpositiontaking)
					END) AS GrossComm
			,SUM(CASE 
					WHEN winlostdate >= @ABSDate THEN CASE 
							WHEN b.bettype IN (33, 43)
								AND liveawayscore = 0 THEN ABS(stake) / 2
							ELSE ABS(stake)
							END
					ELSE CASE 
							WHEN b.bettype IN (33, 43)
								AND liveawayscore = 0 THEN stake / 2
							ELSE stake
							END
					END) AS TurnOver
			,isnull(SUM(winlost - actual_stake), 0) + isnull(SUM(awinlost), 0) + isnull(SUM(comm), 0)
			,SUM(mwinlost)
			,isnull(SUM(acomm), 0) - isnull(SUM(comm), 0)
			,isnull(SUM(mwinlost), 0) + isnull(SUM(acomm), 0) - SUM(comm)
			,- (isnull(SUM(awinlost), 0) + isnull(SUM(mwinlost), 0) + isnull(SUM(acomm), 0) + isnull(SUM(winlost - actual_stake), 0))
			,COUNT(transid) AS NoOfTicket
		FROM dbo.bettrans b WITH (NOLOCK)
			LEFT JOIN (SELECT * FROM [dbo].[f_GroupBettype]()) f ON f.bettype = b.bettype
			INNER JOIN @SportBettype s ON b.bettype = s.Bettype
		WHERE 1 = 1
			AND winlostdate BETWEEN @FromDate AND @ToDate
					--status not in ('VOID', 'REJECT', 'Refund')  and
			AND statusID NOT IN (101, 102, 103)
			AND ruben = 1
			AND mrecommend = @CustID
			--AND b.bettype < 19001
			--AND b.bettype NOT BETWEEN 81 AND 120
			AND s.ProductID NOT IN (3, 6)
		GROUP BY CASE WHEN ISNULL(f.bettype,0) = 0 THEN b.bettype ELSE f.GroupTypeId END

		INSERT INTO @MAgWinLoss
		SELECT b.bettype
			,liveindicator
			,SUM(acomm / (1 - apositiontaking - mpositiontaking)) AS GrossComm
			,SUM(CASE 
					WHEN winlostdate >= @ABSDate THEN CASE 
							WHEN b.bettype IN (33, 43)
								AND liveawayscore = 0 THEN ABS(stake) / 2
							ELSE ABS(stake)
							END
					ELSE CASE 
							WHEN b.bettype IN (33, 43)
								AND liveawayscore = 0 THEN stake / 2
							ELSE stake
							END
					END) AS TurnOver
			,isnull(SUM(winlost - actual_stake), 0) + isnull(SUM(awinlost), 0) + isnull(SUM(comm), 0)
			,SUM(mwinlost)
			,isnull(SUM(acomm), 0) - isnull(SUM(comm), 0)
			,isnull(SUM(mwinlost), 0) + isnull(SUM(acomm), 0) - SUM(comm)
			,- (isnull(SUM(awinlost), 0) + isnull(SUM(mwinlost), 0) + isnull(SUM(acomm), 0) + isnull(SUM(winlost - actual_stake), 0))
			,COUNT(transid) AS NoOfTicket
		FROM dbo.bettrans14 b WITH (NOLOCK, INDEX = IX_bettrans4)
			INNER JOIN @SportBettype s ON b.bettype = s.Bettype
		WHERE 1 = 1
			AND winlostdate BETWEEN @FromDate AND @ToDate
					--status not in ('VOID', 'REJECT', 'Refund')  and
			AND statusID NOT IN (101, 102, 103)
			AND ruben = 1
			AND mrecommend = @CustID
			--AND bettype < 19001
			--AND bettype BETWEEN 81 AND 120
			AND S.ProductID = 3
		GROUP BY B.bettype
			,liveindicator
			
		UNION ALL
		SELECT 71 AS bettype
			,0 AS liveindicator
			,SUM(acomm / (1 - apositiontaking - mpositiontaking)) AS GrossComm
			,SUM(CASE WHEN winlostdate >= @ABSDate THEN ABS(stake) ELSE stake END) AS TurnOver
			,isnull(SUM(winlost - actual_stake), 0) + isnull(SUM(awinlost), 0) + isnull(SUM(comm), 0)
			,SUM(mwinlost)
			,isnull(SUM(acomm), 0) - isnull(SUM(comm), 0)
			,isnull(SUM(mwinlost), 0) + isnull(SUM(acomm), 0) - SUM(comm)
			,- (isnull(SUM(awinlost), 0) + isnull(SUM(mwinlost), 0) + isnull(SUM(acomm), 0) + isnull(SUM(winlost - actual_stake), 0))
			,COUNT(transid) AS NoOfTicket
		FROM dbo.bettrans14 b WITH (NOLOCK, INDEX = IX_bettrans4)
			INNER JOIN @SportBettype s ON b.bettype = s.Bettype
		WHERE winlostdate BETWEEN @FromDate AND @ToDate
			AND statusID NOT IN (101, 102, 103)
			AND ruben = 1
			AND mrecommend = @CustID
			AND S.ProductID = 6
		GROUP BY s.ProductID

		UNION ALL
		SELECT 
			CASE WHEN ISNULL(f.bettype,0) = 0 THEN b.bettype ELSE f.GroupTypeId END AS bettype
			,0 AS liveindicator
			,SUM(CASE 
					WHEN b.bettype = 1000 THEN oddsspread
					ELSE acomm / (1 - apositiontaking - mpositiontaking)
					END) AS GrossComm
			,SUM(CASE 
					WHEN winlostdate >= @ABSDate THEN CASE 
							WHEN b.bettype IN (33, 43)
								AND liveawayscore = 0 THEN ABS(stake) / 2
							ELSE ABS(stake)
							END
					ELSE CASE 
							WHEN b.bettype IN (33, 43)
								AND liveawayscore = 0 THEN stake / 2
							ELSE stake
							END
					END) AS TurnOver
			,isnull(SUM(winlost - actual_stake), 0) + isnull(SUM(awinlost), 0) + isnull(SUM(comm), 0)
			,SUM(mwinlost)
			,isnull(SUM(acomm), 0) - isnull(SUM(comm), 0)
			,isnull(SUM(mwinlost), 0) + isnull(SUM(acomm), 0) - SUM(comm)
			,- (isnull(SUM(awinlost), 0) + isnull(SUM(mwinlost), 0) + isnull(SUM(acomm), 0) + isnull(SUM(winlost - actual_stake), 0))
			,COUNT(transid) AS NoOfTicket
		FROM dbo.bettrans14 b WITH (NOLOCK, INDEX = IX_bettrans4)
			LEFT JOIN (SELECT * FROM [dbo].[f_GroupBettype]()) f ON f.bettype = b.bettype
			INNER JOIN @SportBettype s ON b.bettype = s.Bettype
		WHERE 1 = 1
			AND winlostdate BETWEEN @FromDate AND @ToDate
					--status not in ('VOID', 'REJECT', 'Refund')  and
			AND statusID NOT IN (101, 102, 103)
			AND ruben = 1
			AND mrecommend = @CustID
			--AND b.bettype < 19001
			--AND b.bettype NOT BETWEEN 81 AND 120
			AND s.ProductID NOT IN (3, 6)
		GROUP BY CASE WHEN ISNULL(f.bettype,0) = 0 THEN b.bettype ELSE f.GroupTypeId END
 
END

SELECT bettype, liveindicator,
       SUM(GrossComm) as GrossComm,
	   SUM(TurnOver) as TurnOver,	
	   SUM(AgTotal) as AgTotal,
	   SUM(MAgWinlost) as MAgWinlost,
	   SUM(Comm) as Comm,
	   SUM(MAgTotal) as MAgTotal,
	   SUM(Company) as Company,
       SUM(NoOfTicket) as NoOfTicket
  FROM @MAgWinLoss 
 Group by bettype, liveindicator
 ORDER BY bettype, liveindicator

GO
GRANT EXECUTE ON [dbo].[Age_Rpt_WinLossByBettype_MAg] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_Rpt_WinLossByBettype_MAg] TO [bodbDownlineNetView]
GO
GRANT EXECUTE ON [dbo].[Age_Rpt_WinLossByBettype_MAg] TO [vnteam]
GO
GRANT VIEW DEFINITION ON [dbo].[Age_Rpt_WinLossByBettype_MAg] TO [vnteam]