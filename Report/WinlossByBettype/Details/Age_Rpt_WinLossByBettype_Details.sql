ALTER PROCEDURE [dbo].[Age_Rpt_WinLossByBettype_Details]
	@ProductID		TINYINT,
	@CustID 		INT,
	@RoleID			INT,
	@FromDate 		SMALLDATETIME,
	@ToDate 		SMALLDATETIME,	
	@BalanceUpDay	SMALLDATETIME	
AS

/*
	Creator: Percy
	Date: 2016-04-13
	Task : Report WinLoss by Bettype Detail
	DB: DBAGE.bodb02
	
	Revisions:
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @WinLoss TABLE
	(
		bettype			INT DEFAULT 0,
		TurnOver		MONEY DEFAULT 0,
		-- member --
		MemberWinLoss	MONEY DEFAULT 0,
		MemberRolling	MONEY DEFAULT 0,
		MemberTotal		MONEY DEFAULT 0,
		-- agent --
		AgentWinLoss	MONEY DEFAULT 0,
		AgentRolling	MONEY DEFAULT 0,
		AgentTotal		MONEY DEFAULT 0,
		-- master --
		MasterWinLoss	MONEY DEFAULT 0,
		MasterRolling	MONEY DEFAULT 0,
		MasterTotal		MONEY DEFAULT 0,
		-- supper --
		SuperWinLoss	MONEY DEFAULT 0,
		SuperRolling	MONEY DEFAULT 0,
		SuperTotal		MONEY DEFAULT 0,
		-- company --
		Company			MONEY DEFAULT 0
	)
	DECLARE @ABSDate DATETIME
	SET @ABSDate = '2011-09-01'

	DECLARE @isTest BIT = 0
	SELECT  @isTest = dbo.f_CheckSPVersion(@@PROCID)

	DECLARE @SportBettype TABLE (ProductID INT, Bettype INT)
	INSERT INTO @SportBettype (ProductID, Bettype)
	SELECT ProductID, Bettype FROM dbo.f_SportBettypeMatrix_Sel (@ProductID, 0, 0, 2, '', '', @isTest)

	IF @Todate >= @BalanceUpDay 
	BEGIN
		IF @RoleID = 2
		BEGIN
			INSERT INTO @WinLoss
			(	bettype, TurnOver,
				MemberWinLoss, MemberRolling, MemberTotal,
				AgentWinLoss, AgentRolling, AgentTotal,
				Company
			)
			SELECT
				b.bettype,
				SUM(CASE WHEN winlostdate >= @ABSDate THEN ABS(stake) ELSE stake END) AS TurnOver,
				SUM(winlost - actual_stake) AS MemberWinLoss,
				SUM(playercomm) AS MemberRolling,
				ISNULL(SUM(winlost - actual_stake), 0) + ISNULL(SUM(playercomm), 0) AS MemberTotal,
				SUM(awinlost) AS AgentWinLoss,		   
				SUM(comm - playercomm) AS AgentRolling,
				ISNULL(SUM(awinlost), 0) + ISNULL(SUM(comm - playercomm), 0) AS AgentTotal,
				-SUM(winlost - actual_stake + awinlost + comm) AS Company
			FROM
				dbo.bettrans b WITH(NOLOCK)
				INNER JOIN @SportBettype s ON b.bettype = s.Bettype
			WHERE
				winlostdate BETWEEN @FromDate AND @ToDate
				AND ruben = 1
				AND statusID NOT IN (101, 102, 103)
				AND recommend = @custid
			GROUP BY b.bettype
			UNION ALL
			SELECT
				b.bettype,
				SUM(CASE WHEN winlostdate >= @ABSDate THEN ABS(stake) ELSE stake END) AS TurnOver,
				SUM(winlost - actual_stake) AS MemberWinLoss,
				SUM(playercomm) AS MemberRolling,
				ISNULL(SUM(winlost - actual_stake), 0) + ISNULL(SUM(playercomm), 0) AS MemberTotal,
				SUM(awinlost) AS AgentWinLoss,		   
				SUM(comm - playercomm) AS AgentRolling,
				ISNULL(SUM(awinlost), 0) + ISNULL(SUM(comm - playercomm), 0) AS AgentTotal,
				-SUM(winlost - actual_stake + awinlost + comm) AS Company
			FROM
				dbo.bettrans14 b WITH(NOLOCK)
				INNER JOIN @SportBettype s ON b.bettype = s.Bettype
			WHERE
				winlostdate BETWEEN @FromDate AND @ToDate
				AND ruben = 1
				AND statusID NOT IN (101, 102, 103)
				AND recommend = @custid
			GROUP BY b.bettype
		END
		ELSE IF @RoleID = 3
		BEGIN
			INSERT INTO @WinLoss
			(	bettype, TurnOver,
				AgentTotal,
				MasterWinLoss, MasterRolling, MasterTotal,
				Company
			)			 
			SELECT
				b.bettype,
				SUM(CASE WHEN winlostdate >= @ABSDate THEN ABS(stake) ELSE stake END) AS TurnOver,
				ISNULL(SUM(winlost - actual_stake), 0) + ISNULL(SUM(awinlost), 0) + ISNULL(SUM(comm), 0) AS AgentTotal,
				SUM(mwinlost) AS MasterWinLoss,
				ISNULL(SUM(acomm), 0) - ISNULL(SUM(comm), 0) AS MasterRolling,
				ISNULL(SUM(mwinlost), 0) + ISNULL(SUM(acomm), 0) - SUM(comm) AS MasterTotal,
				- (ISNULL(SUM(awinlost), 0) + ISNULL(SUM(mwinlost), 0) + ISNULL(SUM(acomm), 0) + ISNULL(SUM(winlost - actual_stake), 0)) AS Company
			FROM
				dbo.bettrans b WITH (NOLOCK)
				INNER JOIN @SportBettype s ON b.bettype = s.Bettype
			WHERE
				winlostdate BETWEEN @FromDate AND @ToDate
				AND statusID NOT IN (101, 102, 103)
				AND ruben = 1
				AND mrecommend = @CustID
			GROUP BY b.bettype
			UNION
			SELECT
				b.bettype,
				SUM(CASE WHEN winlostdate >= @ABSDate THEN ABS(stake) ELSE stake END) AS TurnOver,
				ISNULL(SUM(winlost - actual_stake), 0) + ISNULL(SUM(awinlost), 0) + ISNULL(SUM(comm), 0) AS AgentTotal,
				SUM(mwinlost) AS MasterWinLoss,
				ISNULL(SUM(acomm), 0) - ISNULL(SUM(comm), 0) AS MasterRolling,
				ISNULL(SUM(mwinlost), 0) + ISNULL(SUM(acomm), 0) - SUM(comm) AS MasterTotal,
				- (ISNULL(SUM(awinlost), 0) + ISNULL(SUM(mwinlost), 0) + ISNULL(SUM(acomm), 0) + ISNULL(SUM(winlost - actual_stake), 0)) AS Company
			FROM
				dbo.bettrans14 b WITH (NOLOCK)
				INNER JOIN @SportBettype s ON b.bettype = s.Bettype
			WHERE
				winlostdate BETWEEN @FromDate AND @ToDate
				AND statusID NOT IN (101, 102, 103)
				AND ruben = 1
				AND mrecommend = @CustID
			GROUP BY b.bettype
		END
		ELSE IF @RoleID = 4
		BEGIN
			INSERT INTO @WinLoss
			(	bettype, TurnOver,
				MasterTotal,
				SuperWinLoss, SuperRolling, SuperTotal,
				Company
			)
			SELECT
				b.bettype,
				SUM(CASE WHEN winlostdate >= @ABSDate THEN ABS(stake) ELSE stake END) AS TurnOver,
				SUM(mwinlost + awinlost + acomm + winlost - actual_stake) AS MasterTotal,
				SUM(swinlost) AS SuperWinLoss,
				ISNULL(SUM(scomm), 0) - ISNULL(SUM(acomm), 0) AS SuperRolling,
				ISNULL(SUM(swinlost), 0) + ISNULL(SUM(scomm), 0) - SUM(acomm) AS SuperTotal,
				- (ISNULL(SUM(swinlost), 0) + ISNULL(SUM(awinlost), 0) + ISNULL(SUM(mwinlost), 0) + ISNULL(SUM(scomm), 0) + ISNULL(SUM(winlost - actual_stake), 0))AS Company
			FROM
				dbo.bettrans b WITH (NOLOCK, INDEX = IX_srecommend)
				INNER JOIN @SportBettype s ON b.bettype = s.Bettype
			WHERE
				winlostdate BETWEEN @FromDate AND @ToDate
				AND statusID NOT IN (0, 1, 101, 102, 103)
				AND SRecommend = @CustID
			GROUP BY b.bettype
			UNION ALL
			SELECT
				b.bettype,
				SUM(CASE WHEN winlostdate >= @ABSDate THEN ABS(stake) ELSE stake END) AS TurnOver,
				SUM(mwinlost + awinlost + acomm + winlost - actual_stake) AS MasterTotal,
				SUM(swinlost) AS SuperWinLoss,
				ISNULL(SUM(scomm), 0) - ISNULL(SUM(acomm), 0) AS SuperRolling,
				ISNULL(SUM(swinlost), 0) + ISNULL(SUM(scomm), 0) - SUM(acomm) AS SuperTotal,
				- (ISNULL(SUM(swinlost), 0) + ISNULL(SUM(awinlost), 0) + ISNULL(SUM(mwinlost), 0) + ISNULL(SUM(scomm), 0) + ISNULL(SUM(winlost - actual_stake), 0))AS Company
			FROM
				dbo.bettrans14 b WITH(NOLOCK)
				INNER JOIN @SportBettype s ON b.bettype = s.Bettype
			WHERE
				winlostdate BETWEEN @FromDate AND @ToDate
				AND statusID NOT IN (0, 1, 101, 102, 103)
				AND SRecommend = @CustID
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
			A.AgentWinLoss,
			A.AgentRolling,
			A.AgentTotal,
			A.MasterWinLoss,
			A.MasterRolling,
			A.MasterTotal,
			A.SuperWinLoss,
			A.SuperRolling,
			A.SuperTotal,
			A.Company
	FROM bettype t
		INNER JOIN (
			SELECT
				bettype,
				SUM(TurnOver)		AS TurnOver,
				-- member --
				SUM(MemberWinLoss)	AS MemberWinLoss,
				SUM(MemberRolling)	AS MemberRolling,
				SUM(MemberTotal)	AS MemberTotal,
				-- agent --
				SUM(AgentWinLoss)	AS AgentWinLoss,
				SUM(AgentRolling)	AS AgentRolling,
				SUM(AgentTotal)		AS AgentTotal,
				-- master --
				SUM(MasterWinLoss)	AS MasterWinLoss,
				SUM(MasterRolling)	AS MasterRolling,
				SUM(MasterTotal)	AS MasterTotal,
				-- super --
				SUM(SuperWinLoss)	AS SuperWinLoss,
				SUM(SuperRolling)	AS SuperRolling,
				SUM(SuperTotal)		AS SuperTotal,
				-- company --
				SUM(company)		AS Company
			FROM @WinLoss
			GROUP BY bettype
		) AS A 
	ON t.typeid = A.bettype
END

GO

GRANT EXECUTE ON [dbo].[Age_Rpt_WinLossByBettype_Details] TO [bodbDownlineNet] AS [dbo]
GO

GRANT EXECUTE ON [dbo].[Age_Rpt_WinLossByBettype_Details] TO [bodbDownlineNetView] AS [dbo]
GO

GRANT EXECUTE ON [dbo].[Age_Rpt_WinLossByBettype_Details] TO [vnteam] AS [dbo]
GO