ALTER PROCEDURE [dbo].[Age_Rpt_WinLossByBettype_Casino_Details]
	@CustID 	INT,
	@RoleID		INT,
	@FromDate 	SMALLDATETIME,
	@ToDate 	SMALLDATETIME,	
	@BalanceUpDay SMALLDATETIME	
AS

/*
	Creator: Percy
	Date: 2016-01-05
	Task : Report WinLoss RNG Casino Detail [#48283]
	DB: DBAGE.bodb02
	
	Revisions:
*/

BEGIN
SET NOCOUNT ON
DECLARE @WinLoss TABLE
(
	bettype int default 0,
	TurnOver money default 0,
	
	MemberWinLoss money default 0,
	MemberRolling money default 0,
	MemberTotal money default 0,
	
	AgentWinLoss money default 0,
	AgentRolling money default 0,
	AgentTotal money default 0,
	
	MasterWinLoss money default 0,
	MasterRolling money default 0,
	MasterTotal money default 0,
	
	SuperWinLoss money default 0,
	SuperRolling money default 0,
	SuperTotal money default 0,
	
	Company money default 0
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
	IF @RoleID = 2
	BEGIN
		INSERT INTO @WinLoss
			(bettype, TurnOver,
			 MemberWinLoss, MemberRolling, MemberTotal,
			 AgentWinLoss, AgentRolling, AgentTotal,
			 Company)
		SELECT b.bettype,
			   SUM(CASE WHEN winlostdate >= @ABSDate THEN ABS(stake) ELSE stake END) AS TurnOver,
			   SUM(winlost - actual_stake) AS MemberWinLoss,
			   SUM(playercomm) AS MemberRolling,
			   isnull(SUM(winlost - actual_stake), 0) + isnull(SUM(playercomm), 0) as MemberTotal,
			   SUM(awinlost) AS AgentWinLoss,		   
			   SUM(comm - playercomm) AS AgentRolling,
			   isnull(SUM(awinlost), 0) + isnull(SUM(comm - playercomm), 0) as AgentTotal,
			   -SUM(winlost - actual_stake + awinlost + comm) AS Company
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
			   SUM(CASE WHEN winlostdate >= @ABSDate THEN ABS(stake) ELSE stake END) AS TurnOver,
			   SUM(winlost - actual_stake) AS MemberWinLoss,
			   SUM(playercomm) AS MemberRolling,
			   isnull(SUM(winlost - actual_stake), 0) + isnull(SUM(playercomm), 0) as MemberTotal,
			   SUM(awinlost) AS AgentWinLoss,		   
			   SUM(comm - playercomm) AS AgentRolling,
			   isnull(SUM(awinlost), 0) + isnull(SUM(comm - playercomm), 0) as AgentTotal,
			   -SUM(winlost - actual_stake + awinlost + comm) AS Company
		FROM Bettrans14 b WITH(NOLOCK)
			INNER JOIN @SportBettype s ON(b.bettype = s.Bettype)
		WHERE winlostdate between @FromDate and @ToDate
		   and ruben = 1
		   and statusID not in (101, 102, 103)
		   and recommend = @custid
		   AND  s.ProductID = 6
		GROUP BY b.bettype
	END
	ELSE IF @RoleID = 3
	BEGIN
		INSERT INTO @WinLoss
			(bettype, TurnOver,
			 AgentTotal,
			 MasterWinLoss, MasterRolling, MasterTotal,
			 Company)			 
		SELECT b.bettype,
			   SUM(CASE WHEN winlostdate >= @ABSDate THEN ABS(stake) ELSE stake END) AS TurnOver,
			   isnull(SUM(winlost - actual_stake), 0) + isnull(SUM(awinlost), 0) + isnull(SUM(comm), 0) AS AgentTotal,
			   SUM(mwinlost) AS MasterWinLoss,
			   isnull(SUM(acomm), 0) - isnull(SUM(comm), 0) AS MasterRolling,
			   isnull(SUM(mwinlost), 0) + isnull(SUM(acomm), 0) - SUM(comm) AS MasterTotal,
			   - (isnull(SUM(awinlost), 0) + isnull(SUM(mwinlost), 0) + isnull(SUM(acomm), 0) + isnull(SUM(winlost - actual_stake), 0)) AS Company
		FROM dbo.bettrans b WITH (NOLOCK)
			INNER JOIN @SportBettype s ON(b.bettype = s.Bettype)
		WHERE winlostdate BETWEEN @FromDate AND @ToDate
			AND statusID NOT IN (101, 102, 103)
			AND ruben = 1
			AND mrecommend = @CustID
			AND s.ProductID = 6
		GROUP BY b.bettype
		UNION
		SELECT b.bettype,
			   SUM(CASE WHEN winlostdate >= @ABSDate THEN ABS(stake) ELSE stake END) AS TurnOver,
			   isnull(SUM(winlost - actual_stake), 0) + isnull(SUM(awinlost), 0) + isnull(SUM(comm), 0) AS AgentTotal,
			   SUM(mwinlost) AS MasterWinLoss,
			   isnull(SUM(acomm), 0) - isnull(SUM(comm), 0) AS MasterRolling,
			   isnull(SUM(mwinlost), 0) + isnull(SUM(acomm), 0) - SUM(comm) AS MasterTotal,
			   - (isnull(SUM(awinlost), 0) + isnull(SUM(mwinlost), 0) + isnull(SUM(acomm), 0) + isnull(SUM(winlost - actual_stake), 0)) AS Company
		FROM dbo.bettrans14 b WITH (NOLOCK)
			INNER JOIN @SportBettype s ON(b.bettype = s.Bettype)
		WHERE winlostdate BETWEEN @FromDate AND @ToDate
			AND statusID NOT IN (101, 102, 103)
			AND ruben = 1
			AND mrecommend = @CustID
			AND s.ProductID = 6
		GROUP BY b.bettype
	END
	ELSE IF @RoleID = 4
	BEGIN
		INSERT INTO @WinLoss
			(bettype, TurnOver,
			 MasterTotal,
			 SuperWinLoss, SuperRolling, SuperTotal,
			 Company)
		SELECT b.bettype,
		       SUM(CASE WHEN winlostdate >= @ABSDate THEN ABS(stake) ELSE stake END) AS TurnOver,
			   SUM(mwinlost + awinlost + acomm + winlost - actual_stake) AS MasterTotal,
			   SUM(swinlost) AS SuperWinLoss,
			   isnull(SUM(scomm), 0) - isnull(SUM(acomm), 0) AS SuperRolling,
			   isnull(SUM(swinlost), 0) + isnull(SUM(scomm), 0) - SUM(acomm) AS SuperTotal,
			   - (isnull(SUM(swinlost), 0) + isnull(SUM(awinlost), 0) + isnull(SUM(mwinlost), 0) + isnull(SUM(scomm), 0) + isnull(SUM(winlost - actual_stake), 0))AS Company
		FROM dbo.bettrans b WITH(NOLOCK, INDEX = IX_srecommend)
			INNER JOIN @SportBettype s ON (b.bettype = s.Bettype)
		WHERE winlostdate BETWEEN @FromDate AND @ToDate
			AND statusID NOT IN (0, 1, 101, 102, 103)
			AND SRecommend = @CustID
			AND s.ProductID = 6
		GROUP BY b.bettype
		UNION ALL
		SELECT b.bettype,
		       SUM(CASE WHEN winlostdate >= @ABSDate THEN ABS(stake) ELSE stake END) AS TurnOver,
			   SUM(mwinlost + awinlost + acomm + winlost - actual_stake) AS MasterTotal,
			   SUM(swinlost) AS SuperWinLoss,
			   isnull(SUM(scomm), 0) - isnull(SUM(acomm), 0) AS SuperRolling,
			   isnull(SUM(swinlost), 0) + isnull(SUM(scomm), 0) - SUM(acomm) AS SuperTotal,
			   - (isnull(SUM(swinlost), 0) + isnull(SUM(awinlost), 0) + isnull(SUM(mwinlost), 0) + isnull(SUM(scomm), 0) + isnull(SUM(winlost - actual_stake), 0))AS Company
		FROM dbo.bettrans14 b WITH(NOLOCK, INDEX = IX_srecommend)
			INNER JOIN @SportBettype s ON (b.bettype = s.Bettype)
		WHERE winlostdate BETWEEN @FromDate AND @ToDate
			AND statusID NOT IN (0, 1, 101, 102, 103)
			AND SRecommend = @CustID
			AND s.ProductID = 6
		GROUP BY b.bettype
	END
END


SELECT  A.bettype AS GameTypeID,
		t.typenamee AS [GameTypeName],
		t.typenamee AS [GameTypeName_En],
		t.typenamec_uni AS [GameTypeName_Ct],
		t.typenamecn AS [GameTypeName_Cs],
		t.typenamej AS [GameTypeName_Jp],
		t.typenameit AS [GameTypeName_It],
		t.typenameth AS [GameTypeName_Th],
		t.typenameko AS [GameTypeName_Ko],
		A.TurnOver,
		A.MemberWinLoss,
		A.MemberRolling,
		A.MemberTotal,
		A.MasterWinLoss,
		A.MasterRolling,
		A.MasterTotal,
		A.SuperWinLoss,
		A.SuperRolling,
		A.SuperTotal,
		A.Company
FROM bettype t
	INNER JOIN (
		SELECT bettype,
				SUM(TurnOver) as TurnOver,
				   
				SUM(MemberWinLoss) as MemberWinLoss,
				SUM(MemberRolling) as MemberRolling,
				SUM(MemberTotal) as MemberTotal,
				   
				SUM(MasterWinLoss) as MasterWinLoss,
				SUM(MasterRolling) as MasterRolling,
				SUM(MasterTotal) as MasterTotal,
				   
				SUM(SuperWinLoss) as SuperWinLoss,
				SUM(SuperRolling) as SuperRolling,
				SUM(SuperTotal) as SuperTotal,
				   
				SUM(company) as Company
			FROM @WinLoss
			GROUP BY bettype
		) AS A 
	ON t.typeid = A.bettype	

END

GO
GRANT EXECUTE ON [dbo].[Age_Rpt_WinLossByBettype_Casino_Details] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_Rpt_WinLossByBettype_Casino_Details] TO [bodbDownlineNetView]
GO
GRANT EXECUTE ON [dbo].[Age_Rpt_WinLossByBettype_Casino_Details] TO [vnteam]
GO