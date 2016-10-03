USE [bodb02]
GO

ALTER PROCEDURE [dbo].[Age_Rpt_WinLossByBettype_SAg]
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
     - 20090702@AnhPham: include gross commission information for all bet types.
     - 20090710@Phuc: exclude grosscomm for casino.
	 - 20091127@Jamie: Including GrossComm Casino
	 - 20100515@Jamie: Exclude Refund for each way HR 
	 - 20100610@Henry: Change to use StatusID instead of Status in WHERE statement
	 - 20100617@Jamie: Use  new index hint index=IX_srecommend 
	 - 20110516@Johnson: Apply new arrange bettype
	 - 20110802@Sophia: Add new column liveindicator to separate Fulltime or Deadball, but only for Number Game, if not Number Game not group by liveindicator and return 0 for liveindicator
	 - 20110819@Sophia: Count Negative stake as positive turnover
  	 - 20120608@Elodie: Change the gross commission for P2P
						Change DB053 server instead of DB052 server
    - 20140509@Logan:	Add counting for number of tickets - Code aligning			
	- 20140926@Sophia:  Grouping duplicate bettypes of Sporting Solution and IBC [Redmine: #23444]
	- 20150331@Cody: Apply sport bettype matrix	[Redmine: #30169]
	- 20160104@Percy: Include new bettype range into RNG Casino [Redmine: #48283]
	- 20160413@Percy: Support Voidbridge single wallet [Redmine: #55259]
	- 20160607@Percy: Enhance Performance - Using index recommend on bettrans table [Redmine: #58268]

+ Note: Review index=IX_srecommend when modifying this SP 
*/
SET NOCOUNT ON

DECLARE @SAgWinLoss TABLE
(
	bettype int, 
	liveindicator  int, 
	GrossComm money,
	TurnOver money, 
	MAgTotal money, 
	SAgWinlost money, 
	Comm money, 
	SAgTotal money, 
	Company money,
	NoOfTicket int
)

DECLARE @ABSDate DATETIME
SET @ABSDate = '2011-09-01'

DECLARE @isTest BIT = 0
SELECT  @isTest = dbo.f_CheckSPVersion(@@PROCID)

DECLARE @SportBettype TABLE (ProductID INT, Bettype INT)
INSERT INTO @SportBettype (ProductID, Bettype)
SELECT ProductID, Bettype FROM dbo.f_SportBettypeMatrix_Sel (0, 0, 0, 2, '', '', @isTest)

DECLARE @recommend TABLE (recommend INT)
INSERT INTO @recommend (recommend)
SELECT custID FROM custInfo (NOLOCK) WHERE srecommend = @CustID AND roleID = 2

DECLARE @FDate SMALLDATETIME, @TDate SMALLDATETIME, @BUDate SMALLDATETIME
SELECT  @FDate = @FromDate, @TDate = @ToDate, @BUDate = @BalanceUpDay

IF @TDate >= @BUDate 
BEGIN	
	INSERT INTO @SAgWinLoss
	SELECT b.bettype
		,liveindicator
		,SUM(isnull(scomm / (1 - tpositiontaking), 0)) AS GrossComm
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
		,SUM(mwinlost + awinlost + acomm + winlost - actual_stake)
		,SUM(swinlost)
		,isnull(SUM(scomm), 0) - isnull(SUM(acomm), 0)
		,isnull(SUM(swinlost), 0) + isnull(SUM(scomm), 0) - SUM(acomm)
		,- (isnull(SUM(swinlost), 0) + isnull(SUM(awinlost), 0) + isnull(SUM(mwinlost), 0) + isnull(SUM(scomm), 0) + isnull(SUM(winlost - actual_stake), 0))
		,COUNT(transid) AS NoOfTicket
	FROM dbo.bettrans b WITH(NOLOCK)--, INDEX = IX_srecommend)
		INNER JOIN @SportBettype s ON (b.bettype = s.Bettype)
		INNER JOIN @recommend r ON b.recommend = r.recommend
	WHERE 1 = 1
		AND winlostdate BETWEEN @FDate
			AND @TDate
				--status not in ('running','waiting','VOID', 'REJECT', 'Refund')  and
		AND statusID NOT IN (0, 1, 101, 102, 103)
		--ruben=1 and 
		--AND SRecommend = @CustID
		--AND bettype < 19001
		--AND bettype BETWEEN 81 AND 120
		AND s.ProductID = 3
	GROUP BY b.bettype, liveindicator
	
	UNION ALL -- RNG Casino, Voidbridge not group by bettype
	SELECT
		CASE s.ProductID
			WHEN 6  THEN 71
			WHEN 22 THEN 4001
			ELSE 0 END AS bettype
		,0 AS liveindicator
		,SUM(isnull(scomm / (1 - tpositiontaking), 0)) AS GrossComm
		,SUM(CASE WHEN winlostdate >= @ABSDate THEN ABS(stake) ELSE stake END) AS TurnOver
		,SUM(mwinlost + awinlost + acomm + winlost - actual_stake)
		,SUM(swinlost)
		,isnull(SUM(scomm), 0) - isnull(SUM(acomm), 0)
		,isnull(SUM(swinlost), 0) + isnull(SUM(scomm), 0) - SUM(acomm)
		,- (isnull(SUM(swinlost), 0) + isnull(SUM(awinlost), 0) + isnull(SUM(mwinlost), 0) + isnull(SUM(scomm), 0) + isnull(SUM(winlost - actual_stake), 0))
		,COUNT(transid) AS NoOfTicket
	FROM dbo.bettrans b WITH(NOLOCK)--, INDEX = IX_srecommend)
		INNER JOIN @SportBettype s ON (b.bettype = s.Bettype)
		INNER JOIN @recommend r ON b.recommend = r.recommend
	WHERE winlostdate BETWEEN @FDate AND @TDate
		AND statusID NOT IN (0, 1, 101, 102, 103)
		--AND SRecommend = @CustID
		AND s.ProductID IN (6, 22)
	GROUP BY
		CASE s.ProductID
			WHEN 6  THEN 71
			WHEN 22 THEN 4001
			ELSE 0 END

	UNION ALL --- Not number Game not group by liveindicator
	SELECT 
		CASE WHEN ISNULL(f.bettype,0) = 0 THEN b.bettype ELSE f.GroupTypeId END AS bettype
		,0 AS liveindicator
		,SUM(CASE 
				WHEN b.bettype = 1000 THEN oddsspread
				ELSE isnull(scomm / (1 - tpositiontaking), 0)
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
		,SUM(mwinlost + awinlost + acomm + winlost - actual_stake)
		,SUM(swinlost)
		,isnull(SUM(scomm), 0) - isnull(SUM(acomm), 0)
		,isnull(SUM(swinlost), 0) + isnull(SUM(scomm), 0) - SUM(acomm)
		,- (isnull(SUM(swinlost), 0) + isnull(SUM(awinlost), 0) + isnull(SUM(mwinlost), 0) + isnull(SUM(scomm), 0) + isnull(SUM(winlost - actual_stake), 0))
		,COUNT(transid) AS NoOfTicket
	FROM dbo.bettrans b WITH (NOLOCK)--, INDEX = IX_srecommend)
		LEFT JOIN (SELECT * FROM [dbo].[f_GroupBettype]()) f ON f.bettype = b.bettype
		INNER JOIN @SportBettype s ON (b.bettype = s.Bettype)
		INNER JOIN @recommend r ON b.recommend = r.recommend
	WHERE 1 = 1
		AND winlostdate BETWEEN @FDate
			AND @TDate
				--status not in ('running','waiting','VOID', 'REJECT', 'Refund')  and
		AND statusID NOT IN (0, 1, 101, 102, 103)
		--ruben=1 and 
		--AND SRecommend = @CustID
		--AND b.bettype < 19001
		--AND b.bettype NOT BETWEEN 81 AND 120
		AND s.ProductID NOT IN (3, 6, 22)
	GROUP BY CASE WHEN ISNULL(f.bettype,0) = 0 THEN b.bettype ELSE f.GroupTypeId END

	INSERT INTO @SAgWinLoss
	SELECT b.bettype
		,liveindicator
		,SUM(isnull(scomm / (1 - tpositiontaking), 0)) AS GrossComm
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
		,SUM(mwinlost + awinlost + acomm + winlost - actual_stake)
		,SUM(swinlost)
		,isnull(SUM(scomm), 0) - isnull(SUM(acomm), 0)
		,isnull(SUM(swinlost), 0) + isnull(SUM(scomm), 0) - SUM(acomm)
		,- (isnull(SUM(swinlost), 0) + isnull(SUM(awinlost), 0) + isnull(SUM(mwinlost), 0) + isnull(SUM(scomm), 0) + isnull(SUM(winlost - actual_stake), 0))
		,COUNT(transid) AS NoOfTicket
	FROM dbo.bettrans14 b WITH (NOLOCK)
		INNER JOIN @SportBettype s ON(b.bettype = s.bettype)
		INNER JOIN @recommend r ON b.recommend = r.recommend
	WHERE 1 = 1
		AND winlostdate BETWEEN @FDate AND @TDate
				--status not in ('running','waiting','VOID', 'REJECT', 'Refund')  and
		AND statusID NOT IN (101, 102, 103)
		AND ruben = 1
		--AND SRecommend = @CustID
		--AND bettype < 19001
		--AND bettype BETWEEN 81 AND 120
		AND s.ProductID = 3
	GROUP BY b.bettype, liveindicator
	
	UNION ALL -- RNG Casino, Voidbridge not group by bettype
	SELECT
		CASE s.ProductID
			WHEN 6  THEN 71
			WHEN 22 THEN 4001
			ELSE 0 END AS bettype
		,0 AS liveindicator
		,SUM(isnull(scomm / (1 - tpositiontaking), 0)) AS GrossComm
		,SUM(CASE WHEN winlostdate >= @ABSDate THEN ABS(stake) ELSE stake END) AS TurnOver
		,SUM(mwinlost + awinlost + acomm + winlost - actual_stake)
		,SUM(swinlost)
		,isnull(SUM(scomm), 0) - isnull(SUM(acomm), 0)
		,isnull(SUM(swinlost), 0) + isnull(SUM(scomm), 0) - SUM(acomm)
		,- (isnull(SUM(swinlost), 0) + isnull(SUM(awinlost), 0) + isnull(SUM(mwinlost), 0) + isnull(SUM(scomm), 0) + isnull(SUM(winlost - actual_stake), 0))
		,COUNT(transid) AS NoOfTicket
	FROM dbo.bettrans14 b WITH (NOLOCK)
		INNER JOIN @SportBettype s ON(b.bettype = s.bettype)
		INNER JOIN @recommend r ON b.recommend = r.recommend
	WHERE winlostdate BETWEEN @FDate AND @TDate
		AND statusID NOT IN (101, 102, 103)
		AND ruben = 1
		--AND SRecommend = @CustID
		AND s.ProductID IN (6, 22)
	GROUP BY
		CASE s.ProductID
			WHEN 6  THEN 71
			WHEN 22 THEN 4001
			ELSE 0 END

	UNION ALL --- Not number Game not group by liveindicator
	SELECT 
		 CASE WHEN ISNULL(f.bettype,0) = 0 THEN b.bettype ELSE f.GroupTypeId END AS bettype
		,0 AS liveindicator
		,SUM(CASE 
				WHEN b.bettype = 1000 THEN oddsspread
				ELSE isnull(scomm / (1 - tpositiontaking), 0)
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
		,SUM(mwinlost + awinlost + acomm + winlost - actual_stake)
		,SUM(swinlost)
		,isnull(SUM(scomm), 0) - isnull(SUM(acomm), 0)
		,isnull(SUM(swinlost), 0) + isnull(SUM(scomm), 0) - SUM(acomm)
		,- (isnull(SUM(swinlost), 0) + isnull(SUM(awinlost), 0) + isnull(SUM(mwinlost), 0) + isnull(SUM(scomm), 0) + isnull(SUM(winlost - actual_stake), 0))
		,COUNT(transid) AS NoOfTicket
	FROM dbo.bettrans14 b WITH (NOLOCK)
		LEFT JOIN (SELECT * FROM [dbo].[f_GroupBettype]()) f ON f.bettype = b.bettype
		INNER JOIN @SportBettype s ON(b.bettype = s.bettype)
		INNER JOIN @recommend r ON b.recommend = r.recommend
	WHERE 1 = 1
		AND winlostdate BETWEEN @FDate AND @TDate
				--status not in ('running','waiting','VOID', 'REJECT', 'Refund')  and
		AND statusID NOT IN (101, 102, 103)
		AND ruben = 1
		--AND SRecommend = @CustID
		--AND b.bettype < 19001
		--AND b.bettype NOT BETWEEN 81 AND 120
		AND s.ProductID NOT IN (3, 6, 22)
	GROUP BY CASE WHEN ISNULL(f.bettype,0) = 0 THEN b.bettype ELSE f.GroupTypeId END
END


SELECT bettype,
       liveindicator,
	   SUM(GrossComm) as GrossComm,
	   SUM(TurnOver) as TurnOver,	
	   SUM(MAgTotal) as MAgTotal,
	   SUM(SAgWinlost) as SAgWinlost,
	   SUM(Comm) as Comm,
	   SUM(SAgTotal) as SAgTotal,
	   SUM(Company) as Company,
       SUM(NoOfTicket) as NoOfTicket
  FROM @SAgWinLoss 
 Group by bettype, liveindicator
 ORDER BY bettype, liveindicator

GO

GRANT EXECUTE ON [dbo].[Age_Rpt_WinLossByBettype_SAg] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_Rpt_WinLossByBettype_SAg] TO [bodbDownlineNetView]
GO
GRANT EXECUTE ON [dbo].[Age_Rpt_WinLossByBettype_SAg] TO [vnteam]
GO