USE [bodb02]
GO

/****** Object:  StoredProcedure [dbo].[Age_Rpt_WinLossByGameType_Member]    Script Date: 2/9/2017 9:46:44 AM ******/
DROP PROCEDURE [dbo].[Age_Rpt_WinLossByGameType_Member]
GO

/****** Object:  StoredProcedure [dbo].[Age_Rpt_WinLossByGameType_Member]    Script Date: 2/9/2017 9:46:44 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[Age_Rpt_WinLossByGameType_Member]
	@ProductID		TINYINT,
	@CustID 		INT,
	@FromDate 		SMALLDATETIME,
	@ToDate 		SMALLDATETIME,	
	@BalanceUpDay	SMALLDATETIME,
	@MoveBetsDay		SMALLDATETIME
AS

/*
	Created: 
	Task: 
	DB: DBAGE.bodb02
	Original: Age_Rpt_WinLossByBettype_Details
	Revisions:
		- 20170206@Paul: Create new [RedmineID: #70450]

*/

BEGIN
	SET NOCOUNT ON;

	DECLARE @WinLoss TABLE
	(
		sporttype		INT DEFAULT 0,
		bettype			INT DEFAULT 0,
		Turnover		MONEY DEFAULT 0,
		-- member --
		MemberWinLoss	MONEY DEFAULT 0,
		MemberComm		MONEY DEFAULT 0,
		-- agent --
		AgentWinLoss	MONEY DEFAULT 0,
		AgentComm		MONEY DEFAULT 0
	);

	DECLARE @ABSDate DATETIME;

	SET @ABSDate = '2011-09-01';

	DECLARE @isTest BIT = 0;

	SELECT  @isTest = dbo.f_CheckSPVersion(@@PROCID);

	CREATE TABLE #SportBettype (ProductID INT, Bettype INT, Sporttype INT);

	CREATE CLUSTERED INDEX ix_SportBettype_cl ON #SportBettype(bettype);

	INSERT INTO #SportBettype (ProductID, Bettype, Sporttype)
	SELECT DISTINCT t.ProductID, t.Bettype, s.Sporttype
	FROM dbo.f_SportBettypeMatrixByProduct_Sel (@ProductID, @isTest) t
		INNER JOIN SportBettypeMatrix s WITH(NOLOCK) ON t.ProductID = s.ProductID AND t.BetType = s.BetType;

	DECLARE @FDate SMALLDATETIME, @TDate SMALLDATETIME;

	SELECT  @FDate = @FromDate, @TDate = @ToDate;

	IF @Todate >= @BalanceUpDay 
	BEGIN
		IF @ToDate > @MoveBetsDay
		BEGIN
			IF @FromDate <= @MoveBetsDay
			BEGIN
				SET @FDate = DATEADD(DD, 1, @MoveBetsDay);
			END

			INSERT INTO @WinLoss
			(	sporttype, bettype, Turnover,
				MemberWinLoss, MemberComm,
				AgentWinLoss, AgentComm
			)
			SELECT	s.sporttype,
					b.bettype,
					SUM(CASE WHEN winlostdate >= @ABSDate THEN ABS(stake) ELSE stake END) AS TurnOver,
					SUM(winlost - actual_stake) AS MemberWinLoss,
					SUM(playercomm) AS MemberRolling,
					SUM(awinlost) AS AgentWinLoss,		   
					SUM(comm - playercomm) AS AgentRolling
			FROM dbo.bettrans b WITH(NOLOCK)
				INNER JOIN #SportBettype s ON b.bettype = s.Bettype
			WHERE winlostdate BETWEEN @FDate AND @TDate
				AND ruben = 1
				AND statusID NOT IN (101, 102, 103)
				AND recommend = @custid
			GROUP BY s.sporttype,b.bettype;
		END
		
		SET @FDate = @FromDate;
		
		IF @FromDate <= @MoveBetsDay
		BEGIN
			IF @ToDate > @MoveBetsDay
			BEGIN
				SET @TDate = @MoveBetsDay;
			END

			INSERT INTO @WinLoss
			(	sporttype, bettype, Turnover,
				MemberWinLoss, MemberComm,
				AgentWinLoss, AgentComm
			)
			SELECT  s.sporttype,
					b.bettype,
					SUM(CASE WHEN winlostdate >= @ABSDate THEN ABS(stake) ELSE stake END) AS TurnOver,
					SUM(winlost - actual_stake) AS MemberWinLoss,
					SUM(playercomm) AS MemberRolling,
					SUM(awinlost) AS AgentWinLoss,		   
					SUM(comm - playercomm) AS AgentRolling
			FROM dbo.bettrans14 b WITH(NOLOCK)
				INNER JOIN #SportBettype s ON b.bettype = s.Bettype
			WHERE winlostdate BETWEEN @FDate AND @TDate
				AND ruben = 1
				AND statusID NOT IN (101, 102, 103)
				AND recommend = @custid
			GROUP BY s.sporttype,b.bettype;
		END
	END

	SELECT  A.sporttype,
			A.bettype AS GameTypeID,
			t.typenamee AS [GameTypeName],
			t.typenamee AS [GameTypeName_En],
			t.typenamec_uni AS [GameTypeName_Ct],
			t.typenamecn AS [GameTypeName_Cs],
			t.typenamej AS [GameTypeName_Jp],
			t.typenameit AS [GameTypeName_It],
			t.typenameth AS [GameTypeName_Th],
			t.typenameko AS [GameTypeName_Ko],
			A.Turnover,
			A.MemberWinLoss,
			A.MemberComm,
			A.AgentWinLoss AS AgWinLoss,
			A.AgentComm AS AgComm
	FROM bettype t
		INNER JOIN (
			SELECT  sporttype,
					bettype,
					SUM(Turnover) AS TurnOver,
					-- member --
					SUM(MemberWinLoss) AS MemberWinLoss,
					SUM(MemberComm)	AS MemberComm,
					-- agent --
					SUM(AgentWinLoss) AS AgentWinLoss,
					SUM(AgentComm) AS AgentComm
			FROM @WinLoss
			GROUP BY sporttype, bettype
		) AS A ON t.typeid = A.bettype;

	SET NOCOUNT OFF;
END


GO

GRANT EXECUTE ON [dbo].[Age_Rpt_WinLossByGameType_Member] TO [bodbDownlineNet] AS [dbo]
GO

GRANT EXECUTE ON [dbo].[Age_Rpt_WinLossByGameType_Member] TO [bodbDownlineNetView] AS [dbo]
GO

GRANT EXECUTE ON [dbo].[Age_Rpt_WinLossByGameType_Member] TO [vnteam] AS [dbo]
GO


