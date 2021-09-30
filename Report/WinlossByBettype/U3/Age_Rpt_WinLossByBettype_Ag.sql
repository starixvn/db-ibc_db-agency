/*<info serverAlias="DBAGE-bodb02" executers="bodbDownlineNet,bodbDownlineNetView" viewers="" isFunction="0" isNested="0"></info>*/
USE bodb02
GO

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
	- 20160413@Percy: Support Voidbridge single wallet [Redmine: #55259]
	- 20160607@Percy: Enhance Performance - Using index recommend on bettrans table [Redmine: #58268]
	- 20160809@Johnson: Integrate NG2 [Redmine: #61397]
	- 20210823@Sol: Alpha - Allow more time to transfer (phase 2b) - [RedmineID: #160440]
*/
SET NOCOUNT ON

DECLARE @moveBetsDay SMALLDATETIME
DECLARE @tblMoveBetBalanceUp AS TABLE (BalanceUpDay SMALLDATETIME, MoveBetsDay SMALLDATETIME)

INSERT INTO @tblMoveBetBalanceUp(BalanceUpDay,MoveBetsDay)
EXEC bodb02.dbo.Age_SelBalanceUpDay
	
SELECT @moveBetsDay = MoveBetsDay FROM @tblMoveBetBalanceUp

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

DECLARE @isTest BIT = 0
SELECT  @isTest = dbo.f_CheckSPVersion(@@PROCID)

DECLARE @SportBettype TABLE (ProductID INT, Bettype INT)
INSERT INTO @SportBettype (ProductID, Bettype)
SELECT ProductID, Bettype FROM dbo.f_SportBettypeMatrix_Sel (0, 0, 0, 2, '', '', @isTest)

DECLARE @FDate SMALLDATETIME, @TDate SMALLDATETIME, @BUDate SMALLDATETIME
SELECT  @FDate = @FromDate, @TDate = @ToDate, @BUDate = @BalanceUpDay

IF @TDate >= @BUDate
BEGIN 
	IF @FromDate <= @MoveBetsDay
	BEGIN
		SET @FDate = DATEADD(DD, 1, @MoveBetsDay);
	END

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
			   COUNT(transid) as NoOfTicket
         FROM Bettrans b WITH(NOLOCK)
			INNER JOIN @SportBettype s ON(b.bettype = s.Bettype)
		 WHERE 1 = 1
		   and winlostdate between @FDate and @TDate
		   and ruben = 1
		   and statusID not in (101, 102, 103)
		   and recommend = @custid
		   AND  s.ProductID = 3
		GROUP BY b.bettype, liveindicator
		
		UNION ALL -- RNG Casino, Voidbridge not group by bettype
		SELECT
			   CASE s.ProductID
					WHEN 6  THEN 71
					WHEN 22 THEN 4001
					WHEN 23 THEN 2502
					ELSE 0 END AS bettype,
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
			   COUNT(transid) as NoOfTicket
         FROM Bettrans b WITH(NOLOCK)
			INNER JOIN @SportBettype s ON(b.bettype = s.Bettype)
		 WHERE winlostdate between @FDate and @TDate
		   and ruben = 1
		   and statusID not in (101, 102, 103)
		   and recommend = @custid
		   AND  s.ProductID IN (6, 22, 23)
		GROUP BY
			CASE s.ProductID
				WHEN 6  THEN 71
				WHEN 22 THEN 4001
				WHEN 23 THEN 2502
				ELSE 0 END
		
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
			   COUNT(transid) as NoOfTicket
		 FROM Bettrans b WITH(NOLOCK)
			LEFT JOIN (SELECT * FROM [dbo].[f_GroupBettype]()) f ON f.bettype = b.bettype
			INNER JOIN @SportBettype s ON(b.bettype = s.Bettype)
		 WHERE 1 = 1
		   and winlostdate between @FDate and @TDate
		   and ruben = 1
		   and statusID not in (101, 102, 103)
		   and recommend = @custid
		   AND s.ProductID NOT IN (3, 6, 22, 23)
		 GROUP BY CASE WHEN ISNULL(f.bettype,0) = 0 THEN b.bettype ELSE f.GroupTypeId END

	--bettrans14
	IF @FromDate <= @MoveBetsDay
	BEGIN
		IF @BalanceUpDay < @FromDate
		BEGIN
			SET @FDate = @FromDate;
		END
		ELSE
		BEGIN
			SET @FDate = @BalanceUpDay;
		END
		
		IF @ToDate > @MoveBetsDay
		BEGIN
			SET @TDate = @MoveBetsDay;
		END

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
			   COUNT(transid) as NoOfTicket
		 FROM Bettrans14 b WITH(NOLOCK)--, index = bettrans143)
			INNER JOIN @SportBettype s ON(b.bettype = s.Bettype)
		 WHERE 1 = 1
		   and winlostdate between @FDate and @TDate
		   and ruben = 1
		   and statusID not in (101, 102, 103)
		   and recommend = @custid
		   AND s.ProductID = 3
		 GROUP BY b.bettype, liveindicator
         UNION ALL
		 SELECT
			   CASE s.ProductID
					WHEN 6  THEN 71
					WHEN 22 THEN 4001
					WHEN 23 THEN 2502
					ELSE 0 END AS bettype,
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
			   COUNT(transid) as NoOfTicket
		 FROM Bettrans14 b WITH(NOLOCK)--, index = bettrans143)
			INNER JOIN @SportBettype s ON(b.bettype = s.Bettype)
		 WHERE winlostdate between @FDate and @TDate
		   and ruben = 1
		   and statusID not in (101, 102, 103)
		   and recommend = @custid
		   AND s.ProductID IN (6, 22, 23)
		GROUP BY
			CASE s.ProductID
				WHEN 6  THEN 71
				WHEN 22 THEN 4001
				WHEN 23 THEN 2502
				ELSE 0 END

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
			   COUNT(transid) as NoOfTicket
		 FROM Bettrans14 b WITH(NOLOCK)--, index = bettrans143)
			LEFT JOIN (SELECT * FROM [dbo].[f_GroupBettype]()) f ON f.bettype = b.bettype
			INNER JOIN @SportBettype s ON(b.bettype = s.Bettype)
		 WHERE 1 = 1
		   and winlostdate between @FDate and @TDate
		   and ruben = 1
		   and statusID not in (101, 102, 103)
		   and recommend = @custid
		   AND s.ProductID NOT IN (3, 6, 22, 23)
		 GROUP BY CASE WHEN ISNULL(f.bettype,0) = 0 THEN b.bettype ELSE f.GroupTypeId END
	END

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
