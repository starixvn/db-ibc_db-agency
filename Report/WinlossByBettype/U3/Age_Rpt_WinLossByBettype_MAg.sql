/*<info serverAlias="DBAGE-bodb02" executers="bodbDownlineNet,bodbDownlineNetView" viewers="" isFunction="0" isNested="0"></info>*/
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
	- 20160413@Percy: Support Voidbridge single wallet [Redmine: #55259]
	- 20160607@Percy: Enhance Performance - Using index recommend on bettrans table [Redmine: #58268]
	- 20160809@Johnson: Integrate NG2 [Redmine: #61397]
	- 20161020@Francis: Revise SP to aggregate data querying from bettrans/bettrans14 to enhance performance [Redmine: #58268]
	- 20181003@Helen: Modify code to adapt indexes changed on DB053 [Redmine:101405]
*/
BEGIN
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

	DECLARE @isTest BIT = 0
	SELECT  @isTest = dbo.f_CheckSPVersion(@@PROCID)

	DECLARE @SportBettype TABLE (ProductID INT, Bettype INT, Parent_Bettype INT)
	INSERT INTO @SportBettype (ProductID, Bettype, Parent_Bettype)
	SELECT ProductID, Bettype, Bettype FROM dbo.f_SportBettypeMatrix_Sel (0, 0, 0, 2, '', '', @isTest)

	UPDATE s
	SET Parent_Bettype = f.GroupTypeId
	FROM @SportBettype s
		INNER JOIN dbo.f_GroupBettype() f ON s.Bettype = f.Bettype

	UPDATE @SportBettype SET Parent_Bettype = 71 WHERE ProductID = 6 -- Casino Game
	UPDATE @SportBettype SET Parent_Bettype = 4001 WHERE ProductID = 22 -- Voidbrigde
	UPDATE @SportBettype SET Parent_Bettype = 2502 WHERE ProductID = 23 -- NG2

	DECLARE @recommend TABLE (recommend INT)
	INSERT INTO @recommend (recommend)
	SELECT custID FROM custInfo (NOLOCK) WHERE mrecommend = @CustID AND roleID = 2

	DECLARE @FDate SMALLDATETIME, @TDate SMALLDATETIME, @BUDate SMALLDATETIME, @MoveBetDay SMALLDATETIME
	SELECT  @FDate = @FromDate, @TDate = @ToDate, @BUDate = @BalanceUpDay

	DECLARE @MoveBetTable AS TABLE (BalanceUpDay SMALLDATETIME, MoveBetDay SMALLDATETIME)
	INSERT INTO @MoveBetTable (BalanceUpDay, MoveBetDay)
	EXEC bodb02.dbo.Age_SelBalanceUpDay

	SELECT TOP 1 @MoveBetDay = MoveBetDay
	FROM @MoveBetTable

	IF @TDate >= @BUDate 
	BEGIN
		IF @TDate > @MoveBetDay
		BEGIN
			INSERT INTO @MAgWinLoss (bettype, liveindicator, GrossComm, TurnOver, AgTotal, MAgWinlost, Comm, MAgTotal, Company,	NoOfTicket)
			SELECT s.Parent_Bettype
				, CASE s.ProductID
					WHEN 3 THEN b.liveindicator
					ELSE 0 END AS liveindicator
				,SUM(CASE 
						WHEN b.bettype = 1000 THEN oddsspread
						ELSE acomm / (1 - apositiontaking - mpositiontaking)
						END) AS GrossComm
				,SUM(CASE 
						WHEN winlostdate >= @ABSDate THEN CASE 
								WHEN b.bettype IN (33, 43)
									AND liveawayscore = 0  
									AND s.ProductID = 3	THEN ABS(stake) / 2
								ELSE ABS(stake)
								END
						ELSE CASE 
								WHEN b.bettype IN (33, 43)
									AND liveawayscore = 0 
									AND s.ProductID = 3 THEN stake / 2
								ELSE stake
								END
						END) AS TurnOver
				,ISNULL(SUM(winlost - actual_stake), 0) + ISNULL(SUM(awinlost), 0) + ISNULL(SUM(comm), 0) AS AgTotal
				,SUM(mwinlost) AS MAgWinlost
				,ISNULL(SUM(acomm), 0) - ISNULL(SUM(comm), 0) AS Comm
				,ISNULL(SUM(mwinlost), 0) + ISNULL(SUM(acomm), 0) - SUM(comm) AS MAgTotal
				,- (ISNULL(SUM(awinlost), 0) + ISNULL(SUM(mwinlost), 0) + ISNULL(SUM(acomm), 0) + ISNULL(SUM(winlost - actual_stake), 0)) AS Company
				,COUNT(transid) AS NoOfTicket
			FROM dbo.bettrans b WITH (NOLOCK)
				INNER JOIN @SportBettype s ON(b.bettype = s.Bettype)
				INNER JOIN @recommend r ON b.recommend = r.recommend
			WHERE winlostdate BETWEEN @FDate AND @TDate
				AND statusID NOT IN (101, 102, 103)
				AND ruben = 1
			GROUP BY s.Parent_Bettype
					, CASE s.ProductID
					WHEN 3 THEN b.liveindicator
					ELSE 0 END
		END
		
		IF @FDate <= @MoveBetDay
		BEGIN
			INSERT INTO @MAgWinLoss (bettype, liveindicator, GrossComm, TurnOver, AgTotal, MAgWinlost, Comm, MAgTotal, Company,	NoOfTicket)
			SELECT s.Parent_Bettype
				, CASE s.ProductID
					WHEN 3 THEN b.liveindicator
					ELSE 0 END AS liveindicator
				,SUM(acomm / (1 - apositiontaking - mpositiontaking)) AS GrossComm
				,SUM(CASE 
						WHEN winlostdate >= @ABSDate THEN CASE 
								WHEN b.bettype IN (33, 43)
									AND liveawayscore = 0  
									AND s.ProductID = 3	THEN ABS(stake) / 2
								ELSE ABS(stake)
								END
						ELSE CASE 
								WHEN b.bettype IN (33, 43)
									AND liveawayscore = 0 
									AND s.ProductID = 3 THEN stake / 2
								ELSE stake
								END
						END) AS TurnOver
				,ISNULL(SUM(winlost - actual_stake), 0) + ISNULL(SUM(awinlost), 0) + ISNULL(SUM(comm), 0) AS AgTotal
				,SUM(mwinlost) AS MAgWinlost
				,ISNULL(SUM(acomm), 0) - ISNULL(SUM(comm), 0) AS Comm
				,ISNULL(SUM(mwinlost), 0) + ISNULL(SUM(acomm), 0) - SUM(comm) AS MAgTotal
				,- (ISNULL(SUM(awinlost), 0) + ISNULL(SUM(mwinlost), 0) + ISNULL(SUM(acomm), 0) + ISNULL(SUM(winlost - actual_stake), 0)) AS Company
				,COUNT(transid) AS NoOfTicket
			FROM dbo.bettrans14 b WITH (NOLOCK)
				INNER JOIN @SportBettype s ON b.bettype = s.Bettype
			WHERE winlostdate BETWEEN @FDate AND @TDate
				AND mrecommend = @CustID
				AND statusID NOT IN (101, 102, 103)
				AND ruben = 1
			GROUP BY s.Parent_Bettype
					, CASE s.ProductID
					WHEN 3 THEN b.liveindicator
					ELSE 0 END
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
	 GROUP BY bettype, liveindicator
	 ORDER BY bettype, liveindicator
	
	END
END
GO