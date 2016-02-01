ALTER PROCEDURE [dbo].[Age_Rpt_WinLossByBettype_Ag]
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
	- 20100617@Thien: put index hint on Bettrans14(index=bettrans143) to ensure correct index used.
	- 20110516@Johnson: Apply new arrange bettype
	- 20110802@Sophia: Add new column liveindicator to separate Fulltime or Deadball, but only for Number Game, if not Number Game not group by liveindicator and return 0 for liveindicator
	- 20110819@Sophia: Count Negative stake as positive turnover
	- 20120608@Elodie: Change the gross commission for P2P
					   Change DB053 server instead of DB052 server
	- 20140509@Logan:	Add counting for number of tickets
	- 20140926@Sophia:  Grouping duplicate bettypes of Sporting Solution and IBC [Redmine: #23444]
	- 20150331@Cody: Apply sport bettype matrix [Redmine: #30169]
	- 20160104@Percy: Include new bettype range into RNG Casino [Redmine: #48283]
	- 20160201@Percy: Exclude bettype 500 when calculate betcount [Redmine: #50027]
*/
SET NOCOUNT ON
DECLARE @AgWinLoss TABLE
(
	bettype int, 
	liveindicator int,
	GrossComm money,
	TurnOver money, 
	MemberWinLost money, 
	AgWinLost money, 
	PlayerComm money, 
	AgComm money, 
	MemberTotal money, 
	AgTotal money, 
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
	INSERT INTO @AgWinLoss
		SELECT b.bettype,
			   liveindicator,
			   SUM(comm/(1 - apositiontaking)) as GrossComm,
			   SUM(CASE WHEN winlostdate >= @ABSDate  
				THEN CASE WHEN b.bettype in (33, 43) AND liveawayscore = 0 THEN ABS(stake)/2 ELSE ABS(stake) END
				ELSE CASE WHEN b.bettype in (33, 43) AND liveawayscore = 0 THEN stake/2 ELSE stake END
				END
				) as TurnOver,
			   SUM(winlost - actual_stake),
			   SUM(awinlost),
			   SUM(playercomm),
			   SUM(comm - playercomm),
			   isnull(SUM(winlost - actual_stake), 0) + isnull(SUM(playercomm), 0) as MemberTotal,
			   isnull(SUM(awinlost), 0) + isnull(SUM(comm - playercomm), 0) as AgTotal,
		       -SUM(winlost - actual_stake + awinlost + comm),
			   COUNT(CASE WHEN b.bettype = 500 THEN NULL ELSE transid END) as NoOfTicket
         FROM Bettrans b WITH(NOLOCK)
			INNER JOIN @SportBettype s ON(b.bettype = s.Bettype)
		 WHERE 1 = 1
		   and winlostdate between @FromDate and @ToDate
		   and ruben = 1
			--status not in ('VOID', 'REJECT', 'Refund')  and
		   and statusID not in (101, 102, 103)
		   and recommend = @custid
		   --and bettype < 19001
		   --AND bettype BETWEEN 81 AND 120
		   AND  s.ProductID = 3
		GROUP BY b.bettype, liveindicator
		
		UNION ALL -- RNG Casino not group by bettype
		SELECT 71 AS bettype,
			   0 AS liveindicator,
			   SUM(comm/(1 - apositiontaking)) as GrossComm,
			   SUM(CASE WHEN winlostdate >= @ABSDate THEN ABS(stake) ELSE stake END) as TurnOver,
			   SUM(winlost - actual_stake),
			   SUM(awinlost),
			   SUM(playercomm),
			   SUM(comm - playercomm),
			   isnull(SUM(winlost - actual_stake), 0) + isnull(SUM(playercomm), 0) as MemberTotal,
			   isnull(SUM(awinlost), 0) + isnull(SUM(comm - playercomm), 0) as AgTotal,
		       -SUM(winlost - actual_stake + awinlost + comm),
			   COUNT(CASE WHEN b.bettype = 500 THEN NULL ELSE transid END) as NoOfTicket
         FROM Bettrans b WITH(NOLOCK)
			INNER JOIN @SportBettype s ON(b.bettype = s.Bettype)
		 WHERE winlostdate between @FromDate and @ToDate
		   and ruben = 1
		   and statusID not in (101, 102, 103)
		   and recommend = @custid
		   AND  s.ProductID = 6
		
	    UNION ALL --- Not number Game not group by liveindicator
		SELECT 
			   CASE WHEN ISNULL(f.bettype,0) = 0 THEN b.bettype ELSE f.GroupTypeId END AS bettype,
			   0 as liveindicator,
		       SUM(case when b.bettype = 1000 then oddsspread else comm/(1 - apositiontaking) end) as GrossComm,
		       SUM( CASE WHEN winlostdate >= @ABSDate
				THEN CASE WHEN  b.bettype in (33, 43) AND liveawayscore = 0 THEN ABS(stake)/2 ELSE ABS(stake) END
				ELSE CASE WHEN  b.bettype in (33, 43) AND liveawayscore = 0 THEN stake/2 ELSE stake END
				END
				) as TurnOver,
			   SUM(winlost - actual_stake),
			   SUM(awinlost),
			   SUM(playercomm),
			   SUM(comm-playercomm),
			   isnull(SUM(winlost - actual_stake), 0) + isnull(SUM(playercomm), 0) as MemberTotal,
			   isnull(SUM(awinlost), 0) + isnull(SUM(comm - playercomm), 0) as AgTotal,
			   -SUM(winlost - actual_stake + awinlost + comm),
			   COUNT(CASE WHEN b.bettype = 500 THEN NULL ELSE transid END) as NoOfTicket
		 FROM Bettrans b WITH(NOLOCK)
			LEFT JOIN (SELECT * FROM [dbo].[f_GroupBettype]()) f ON f.bettype = b.bettype
			INNER JOIN @SportBettype s ON(b.bettype = s.Bettype)
		 WHERE 1 = 1
		   and winlostdate between @FromDate and @ToDate
		   and ruben = 1
			--status not in ('VOID', 'REJECT', 'Refund')  and
		   and statusID not in (101, 102, 103)
		   and recommend = @custid
		   --and b.bettype < 19001
		   --AND b.bettype NOT BETWEEN 81 AND 120
		   AND s.ProductID NOT IN (3, 6)
		 GROUP BY CASE WHEN ISNULL(f.bettype,0) = 0 THEN b.bettype ELSE f.GroupTypeId END


	INSERT INTO @AgWinLoss
		SELECT b.bettype,
		       liveindicator,
		       SUM(comm/(1 - apositiontaking)) as GrossComm,
		       SUM( CASE WHEN winlostdate >= @ABSDate
				THEN CASE WHEN b.bettype in (33, 43) AND liveawayscore = 0 THEN ABS(stake)/2 ELSE ABS(stake) END
				ELSE CASE WHEN b.bettype in (33, 43) AND liveawayscore = 0 THEN stake/2 ELSE stake END
				END
				) as TurnOver,
			   SUM(winlost - actual_stake),
			   SUM(awinlost),
			   SUM(playercomm),
			   SUM(comm - playercomm),
			   isnull(SUM(winlost - actual_stake), 0) + isnull(SUM(playercomm), 0) as MemberTotal,
			   isnull(SUM(awinlost), 0) + isnull(SUM(comm - playercomm), 0) as AgTotal,
			   -SUM(winlost - actual_stake + awinlost + comm),
			   COUNT(CASE WHEN b.bettype = 500 THEN NULL ELSE transid END) as NoOfTicket
		 FROM Bettrans14 b WITH(NOLOCK, index = bettrans143)
			INNER JOIN @SportBettype s ON(b.bettype = s.Bettype)
		 WHERE 1 = 1
		   and winlostdate between @FromDate and @ToDate
		   and ruben = 1
			--status not in ('VOID', 'REJECT', 'Refund')  and
		   and statusID not in (101, 102, 103)
		   and recommend = @custid
		   --and bettype < 19001
		   --AND bettype BETWEEN 81 AND 120
		   AND s.ProductID = 3
		 GROUP BY b.bettype, liveindicator
         UNION ALL
		 SELECT 71 AS bettype,
		       0 AS liveindicator,
		       SUM(comm/(1 - apositiontaking)) as GrossComm,
		       SUM(CASE WHEN winlostdate >= @ABSDate THEN ABS(stake) ELSE stake END) as TurnOver,
			   SUM(winlost - actual_stake),
			   SUM(awinlost),
			   SUM(playercomm),
			   SUM(comm - playercomm),
			   isnull(SUM(winlost - actual_stake), 0) + isnull(SUM(playercomm), 0) as MemberTotal,
			   isnull(SUM(awinlost), 0) + isnull(SUM(comm - playercomm), 0) as AgTotal,
			   -SUM(winlost - actual_stake + awinlost + comm),
			   COUNT(CASE WHEN b.bettype = 500 THEN NULL ELSE transid END) as NoOfTicket
		 FROM Bettrans14 b WITH(NOLOCK, index = bettrans143)
			INNER JOIN @SportBettype s ON(b.bettype = s.Bettype)
		 WHERE winlostdate between @FromDate and @ToDate
		   and ruben = 1
		   and statusID not in (101, 102, 103)
		   and recommend = @custid
		   AND s.ProductID = 6
         UNION ALL
		 SELECT 
			  CASE WHEN ISNULL(f.bettype,0) = 0 THEN b.bettype ELSE f.GroupTypeId END AS bettype,
		       0 as liveindicator,
		       SUM(case when b.bettype = 1000 then oddsspread else comm/(1 - apositiontaking) end) as GrossComm,
		       SUM( CASE WHEN winlostdate >= @ABSDate
				THEN CASE WHEN b.bettype in (33, 43) AND liveawayscore = 0 THEN ABS(stake)/2 ELSE ABS(stake) END
				ELSE CASE WHEN b.bettype in (33, 43) AND liveawayscore = 0 THEN stake/2 ELSE stake END
				END
				) as TurnOver,
			   SUM(winlost - actual_stake),
			   SUM(awinlost),
			   SUM(playercomm),
			   SUM(comm - playercomm),
			   isnull(SUM(winlost-actual_stake), 0) + isnull(SUM(playercomm), 0) as MemberTotal,
			   isnull(SUM(awinlost), 0) + isnull(SUM(comm-playercomm), 0) as AgTotal,
			   -SUM(winlost - actual_stake + awinlost+comm),
			   COUNT(CASE WHEN b.bettype = 500 THEN NULL ELSE transid END) as NoOfTicket
		 FROM Bettrans14 b WITH(NOLOCK, index = bettrans143)
			LEFT JOIN (SELECT * FROM [dbo].[f_GroupBettype]()) f ON f.bettype = b.bettype
			INNER JOIN @SportBettype s ON(b.bettype = s.Bettype)
		 WHERE 1 = 1
		   and winlostdate between @FromDate and @ToDate
		   and ruben = 1
			--status not in ('VOID', 'REJECT', 'Refund')  and
		   and statusID not in (101, 102, 103)
		   and recommend = @custid
		   --and b.bettype < 19001
		   --AND b.bettype NOT BETWEEN 81 AND 120
		   AND s.ProductID NOT IN (3, 6)
		 GROUP BY CASE WHEN ISNULL(f.bettype,0) = 0 THEN b.bettype ELSE f.GroupTypeId END

END

SELECT bettype,
       liveindicator,
       SUM(GrossComm) as GrossComm,
       SUM(TurnOver) as TurnOver,
       SUM(MemberWinLost) as MemberWinLost,
       SUM(playercomm) as PlayerComm,
       SUM(MemberTotal) as MemberTotal,
       SUM(AgWinLost) as AgWinLost,
       SUM(AgComm) as AgComm,
       SUM(AgTotal) as AgTotal,
       SUM(company) as Company,
       SUM(NoOfTicket) as NoOfTicket
 FROM @AgWinLoss
 GROUP BY bettype, liveindicator
 ORDER BY bettype, liveindicator

GO
GRANT EXECUTE ON [dbo].[Age_Rpt_WinLossByBettype_Ag] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_Rpt_WinLossByBettype_Ag] TO [bodbDownlineNetView]
GO
GRANT EXECUTE ON [dbo].[Age_Rpt_WinLossByBettype_Ag] TO [vnteam]
