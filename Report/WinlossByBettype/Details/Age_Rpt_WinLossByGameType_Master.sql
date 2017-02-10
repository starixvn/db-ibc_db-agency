USE [bodb02]
GO

/****** Object:  StoredProcedure [dbo].[Age_Rpt_WinLossByGameType_Master]    Script Date: 2/9/2017 9:46:30 AM ******/
DROP PROCEDURE [dbo].[Age_Rpt_WinLossByGameType_Master]
GO

/****** Object:  StoredProcedure [dbo].[Age_Rpt_WinLossByGameType_Master]    Script Date: 2/9/2017 9:46:30 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[Age_Rpt_WinLossByGameType_Master]
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
		MasterTotal		MONEY DEFAULT 0,
		-- supper --
		SuperWinLoss	MONEY DEFAULT 0,
		SuperComm		MONEY DEFAULT 0
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
		DECLARE @recommend TABLE (recommend INT);

		INSERT INTO @recommend (recommend)
		SELECT custID FROM custInfo (NOLOCK)
		WHERE srecommend = @CustID AND roleID = 2;

		IF @ToDate > @MoveBetsDay
		BEGIN
			IF @FromDate <= @MoveBetsDay
			BEGIN
				SET @FDate = DATEADD(DD, 1, @MoveBetsDay);
			END

			INSERT INTO @WinLoss
			(	sporttype, bettype, Turnover,
				MasterTotal,
				SuperWinLoss, SuperComm
			)
			SELECT  s.sporttype,
					b.bettype,
					SUM(CASE WHEN winlostdate >= @ABSDate THEN ABS(stake) ELSE stake END) AS Turnover,
					SUM(mwinlost + awinlost + acomm + winlost - actual_stake) AS MasterTotal,
					SUM(swinlost) AS SuperWinLoss,
					ISNULL(SUM(scomm), 0) - ISNULL(SUM(acomm), 0) AS SuperComm
			FROM dbo.bettrans b WITH (NOLOCK, INDEX = IX_srecommend)
				INNER JOIN #SportBettype s ON b.bettype = s.Bettype
			WHERE winlostdate BETWEEN @FDate AND @TDate
				AND statusID NOT IN (0, 1, 101, 102, 103)
				AND SRecommend = @CustID
			GROUP BY s.sporttype, b.bettype;
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
				MasterTotal,
				SuperWinLoss, SuperComm
			)
			SELECT  s.sporttype,
					b.bettype,
					SUM(CASE WHEN winlostdate >= @ABSDate THEN ABS(stake) ELSE stake END) AS Turnover,
					SUM(mwinlost + awinlost + acomm + winlost - actual_stake) AS MasterTotal,
					SUM(swinlost) AS SuperWinLoss,
					ISNULL(SUM(scomm), 0) - ISNULL(SUM(acomm), 0) AS SuperComm
			FROM dbo.bettrans14 b WITH(NOLOCK)
				INNER JOIN #SportBettype s ON b.bettype = s.Bettype
				INNER JOIN @recommend r ON b.recommend = r.recommend
			WHERE winlostdate BETWEEN @FDate AND @TDate
				AND statusID NOT IN (0, 1, 101, 102, 103)
			GROUP BY s.sporttype, b.bettype;
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
			A.MasterTotal AS MAgTotal,
			A.SuperWinLoss AS SAgWinLoss,
			A.SuperComm AS SAgComm
	FROM bettype t
		INNER JOIN (
			SELECT  sporttype,
					bettype,
					SUM(Turnover) AS TurnOver,
					SUM(MasterTotal) AS MasterTotal,
					-- super --
					SUM(SuperWinLoss) AS SuperWinLoss,
					SUM(SuperComm) AS SuperComm
			FROM @WinLoss
			GROUP BY sporttype, bettype
		) AS A ON t.typeid = A.bettype;

	SET NOCOUNT OFF;
END


GO

GRANT EXECUTE ON [dbo].[Age_Rpt_WinLossByGameType_Master] TO [bodbDownlineNet] AS [dbo]
GO

GRANT EXECUTE ON [dbo].[Age_Rpt_WinLossByGameType_Master] TO [bodbDownlineNetView] AS [dbo]
GO

GRANT EXECUTE ON [dbo].[Age_Rpt_WinLossByGameType_Master] TO [vnteam] AS [dbo]
GO


