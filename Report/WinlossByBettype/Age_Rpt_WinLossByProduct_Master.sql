USE [bodb02]
GO

/****** Object:  StoredProcedure [dbo].[Age_Rpt_WinLossByProduct_Master]    Script Date: 2/9/2017 9:47:53 AM ******/
DROP PROCEDURE [dbo].[Age_Rpt_WinLossByProduct_Master]
GO

/****** Object:  StoredProcedure [dbo].[Age_Rpt_WinLossByProduct_Master]    Script Date: 2/9/2017 9:47:53 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[Age_Rpt_WinLossByProduct_Master]
	@CustID			INT,
	@FromDate		SMALLDATETIME,
	@ToDate			SMALLDATETIME,	
	@BalanceUpDay	SMALLDATETIME,
	@MoveBetsDay	SMALLDATETIME,
	@ProductIds		VARCHAR(MAX)
AS

/*
	Created: 
	Task: 
	DB: DBAGE.bodb02
	Original: Age_Rpt_WinLossByBettype_SAg
	Revisions:
		- 20161224@Paul: Create new [RedmineID: #70450]

*/

BEGIN
	SET NOCOUNT ON;

	CREATE TABLE #SAgWinLoss
	(
		ProductID		TINYINT,
		bettype			INT, 
		SportType		SMALLINT,
		liveindicator	INT, 
		GrossComm		MONEY,
		Turnover		MONEY, 
		MAgTotal		MONEY, 
		SAgWinloss		MONEY, 
		SAgComm			MONEY, 
		NumberOfTickets INT
	);

	DECLARE @ABSDate DATETIME;
	SET @ABSDate = '2011-09-01';

	DECLARE @isTest BIT = 0;
	SELECT  @isTest = dbo.f_CheckSPVersion(@@PROCID);

	CREATE TABLE #SportBettype (ProductID TINYINT, Bettype SMALLINT, GroupTypeId INT, SportType SMALLINT);

	INSERT INTO #SportBettype (ProductID, Bettype, GroupTypeId, SportType)
	SELECT f.ProductID, f.Bettype, f.Bettype, s.SportType
	FROM dbo.f_SportBettypeMatrixByProduct_Sel (@ProductIds, @isTest) f
		LEFT JOIN dbo.SportBettypeMatrix s WITH(NOLOCK)
			ON f.ProductID = s.ProductID AND f.BetType = s.BetType AND s.ProductID = 23;

	UPDATE s
	SET GroupTypeId = f.GroupTypeId
	FROM #SportBettype s
		INNER JOIN dbo.f_GroupBettype() f ON s.Bettype = f.Bettype;

	CREATE CLUSTERED INDEX ix_SportBettype_cl ON #SportBettype(Bettype);

	DECLARE @recommend TABLE (recommend INT);

	INSERT INTO @recommend (recommend)
	SELECT custID FROM custInfo (NOLOCK) WHERE srecommend = @CustID AND roleID = 2;

	DECLARE @FDate SMALLDATETIME, @TDate SMALLDATETIME;

	SELECT  @FDate = @FromDate, @TDate = @ToDate;

	IF @ToDate >= @BalanceUpDay 
	BEGIN
		IF @ToDate > @MoveBetsDay
		BEGIN
			IF @FromDate <= @MoveBetsDay
			BEGIN
				SET @FDate = DATEADD(DD, 1, @MoveBetsDay);
			END

			INSERT INTO #SAgWinLoss(ProductID, bettype, SportType, liveindicator, GrossComm, Turnover, MAgTotal, SAgWinloss, SAgComm, NumberOfTickets)
			SELECT  s.ProductID,
					s.GroupTypeId,
					s.SportType,
					CASE s.ProductID
						WHEN 3 THEN b.liveindicator
						ELSE 0
					END AS liveindicator,
					SUM(CASE WHEN b.bettype = 1000 THEN oddsspread
							ELSE ISNULL(scomm / (1 - tpositiontaking), 0)
						END) AS GrossComm,
					SUM(CASE WHEN winlostdate >= @ABSDate THEN 
								CASE WHEN b.bettype IN (33, 43) AND liveawayscore = 0 THEN ABS(stake) / 2
									ELSE ABS(stake) END
							ELSE 
								CASE WHEN b.bettype IN (33, 43) AND liveawayscore = 0 THEN stake / 2
									ELSE stake END
						END) AS Turnover,
					SUM(mwinlost + awinlost + acomm + winlost - actual_stake) AS MAgTotal,
					SUM(swinlost) AS SAgWinloss,
					ISNULL(SUM(scomm), 0) - ISNULL(SUM(acomm), 0) AS SAgComm,
					COUNT(transid) AS NumberOfTickets
			FROM dbo.bettrans b WITH(NOLOCK)
				INNER JOIN #SportBettype s ON (b.bettype = s.Bettype)
			WHERE winlostdate BETWEEN @FDate AND @TDate
				AND statusID NOT IN (0, 1, 101, 102, 103)
				AND EXISTS(
					SELECT 1
					FROM @recommend r
					WHERE b.recommend = r.recommend
				)
			GROUP BY s.ProductID, s.GroupTypeId, s.SportType,
					CASE s.ProductID
						WHEN 3 THEN b.liveindicator
						ELSE 0 END;
		END

		SET @FDate = @FromDate;
		
		IF @FromDate <= @MoveBetsDay
		BEGIN
			IF @ToDate > @MoveBetsDay
			BEGIN
				SET @TDate = @MoveBetsDay;
			END

			INSERT INTO #SAgWinLoss(ProductID, bettype, SportType, liveindicator, GrossComm, Turnover, MAgTotal, SAgWinloss, SAgComm, NumberOfTickets)
			SELECT  s.ProductID,
					s.GroupTypeId,
					s.SportType,
					CASE s.ProductID
						WHEN 3 THEN b.liveindicator
						ELSE 0
					END AS liveindicator,
					SUM(CASE WHEN b.bettype = 1000 THEN oddsspread
							ELSE ISNULL(scomm / (1 - tpositiontaking), 0)
						END) AS GrossComm,
					SUM(CASE WHEN winlostdate >= @ABSDate THEN 
								CASE WHEN b.bettype IN (33, 43) AND liveawayscore = 0 THEN ABS(stake) / 2
									ELSE ABS(stake) END
							ELSE 
								CASE WHEN b.bettype IN (33, 43) AND liveawayscore = 0 THEN stake / 2
									ELSE stake END
						END) AS Turnover,
					SUM(mwinlost + awinlost + acomm + winlost - actual_stake) AS MAgTotal,
					SUM(swinlost) AS SAgWinloss,
					ISNULL(SUM(scomm), 0) - ISNULL(SUM(acomm), 0) AS SAgComm,
					COUNT(transid) AS NumberOfTickets
			FROM dbo.bettrans14 b WITH(NOLOCK)
				INNER JOIN #SportBettype s ON (b.bettype = s.Bettype)
			WHERE winlostdate BETWEEN @FDate AND @TDate
				AND statusID NOT IN (0, 1, 101, 102, 103)	
				AND ruben = 1			
				AND EXISTS(
					SELECT 1
					FROM @recommend r
					WHERE b.recommend = r.recommend
				)
			GROUP BY s.ProductID, s.GroupTypeId, s.SportType,
					CASE s.ProductID
						WHEN 3 THEN b.liveindicator
						ELSE 0 END;
		END
	END

	SELECT	t.bettype,
			t.ProductID,
			t.SportType,
			liveindicator,
			SUM(GrossComm) AS GrossComm,
			SUM(TurnOver) AS Turnover,	
			SUM(MAgTotal) AS MAgTotal,
			SUM(SAgWinloss) AS SAgWinloss,
			SUM(SAgComm) AS SAgComm,
			SUM(NumberOfTickets) AS NumberOfTickets
	FROM #SAgWinLoss t
	GROUP BY t.bettype, t.ProductID, t.SportType, liveindicator
	ORDER BY t.bettype, t.ProductID, t.SportType, liveindicator;

	SET NOCOUNT OFF;
END

GO

GRANT EXECUTE ON [dbo].[Age_Rpt_WinLossByProduct_Master] TO [bodbDownlineNet] AS [dbo]
GO

GRANT EXECUTE ON [dbo].[Age_Rpt_WinLossByProduct_Master] TO [bodbDownlineNetView] AS [dbo]
GO

GRANT EXECUTE ON [dbo].[Age_Rpt_WinLossByProduct_Master] TO [vnteam] AS [dbo]
GO


