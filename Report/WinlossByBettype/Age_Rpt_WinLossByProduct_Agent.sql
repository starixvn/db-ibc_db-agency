USE [bodb02]
GO

/****** Object:  StoredProcedure [dbo].[Age_Rpt_WinLossByProduct_Agent]    Script Date: 2/9/2017 9:47:07 AM ******/
DROP PROCEDURE [dbo].[Age_Rpt_WinLossByProduct_Agent]
GO

/****** Object:  StoredProcedure [dbo].[Age_Rpt_WinLossByProduct_Agent]    Script Date: 2/9/2017 9:47:07 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[Age_Rpt_WinLossByProduct_Agent]
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
	Original: Age_Rpt_WinLossByBettype_MAg
	Revisions:
		- 20161224@Paul: Create new [RedmineID: #70450]

*/

BEGIN
	SET NOCOUNT ON;

	CREATE TABLE #MAgWinLoss
	(
		ProductID		TINYINT,
		bettype			INT, 
		liveindicator	INT,
		GrossComm		MONEY,
		TurnOver		MONEY, 
		AgTotal			MONEY, 
		MAgWinloss		MONEY, 
		MAgComm			MONEY, 
		NumberOfTickets	INT
	);

	DECLARE @ABSDate DATETIME;
	SET @ABSDate = '2011-09-01';

	DECLARE @isTest BIT = 0;
	SELECT  @isTest = dbo.f_CheckSPVersion(@@PROCID);

	CREATE TABLE #SportBettype (ProductID TINYINT, Bettype SMALLINT, GroupTypeId INT);

	INSERT INTO #SportBettype (ProductID, Bettype, GroupTypeId)
	SELECT ProductID, Bettype, Bettype
	FROM dbo.f_SportBettypeMatrixByProduct_Sel (@ProductIds, @isTest);

	UPDATE s
	SET GroupTypeId = f.GroupTypeId
	FROM #SportBettype s
		INNER JOIN dbo.f_GroupBettype() f ON s.Bettype = f.Bettype;

	CREATE CLUSTERED INDEX ix_SportBettype_cl ON #SportBettype(Bettype);

	DECLARE @recommend TABLE (recommend INT);

	INSERT INTO @recommend (recommend)
	SELECT custID FROM custInfo (NOLOCK) WHERE mrecommend = @CustID AND roleID = 2;

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

			INSERT INTO #MAgWinLoss (ProductID, bettype, liveindicator, GrossComm, TurnOver, AgTotal, MAgWinloss, MAgComm, NumberOfTickets)
			SELECT	s.ProductID,
					s.GroupTypeId,
					CASE s.ProductID
						WHEN 3 THEN b.liveindicator
						ELSE 0
					END AS liveindicator,
					SUM(CASE 
						WHEN b.bettype = 1000 THEN oddsspread
						ELSE acomm / (1 - apositiontaking - mpositiontaking)
						END) AS GrossComm,
					SUM(CASE 
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
						END) AS TurnOver,
					ISNULL(SUM(winlost - actual_stake), 0) + ISNULL(SUM(awinlost), 0) + ISNULL(SUM(comm), 0) AS AgTotal,
					SUM(mwinlost) AS MAgWinlost,
					ISNULL(SUM(acomm), 0) - ISNULL(SUM(comm), 0) AS Comm,
					COUNT(transid) AS NoOfTicket
			FROM dbo.bettrans b WITH (NOLOCK)
				INNER JOIN #SportBettype s ON b.bettype = s.Bettype
			WHERE winlostdate BETWEEN @FDate AND @TDate
				AND statusID NOT IN (101, 102, 103)
				AND ruben = 1
				AND EXISTS(
					SELECT 1
					FROM @recommend r
					WHERE b.recommend = r.recommend
				)
			GROUP BY s.ProductID, s.GroupTypeId,
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

			INSERT INTO #MAgWinLoss (ProductID, bettype, liveindicator, GrossComm, TurnOver, AgTotal, MAgWinloss, MAgComm, NumberOfTickets)
			SELECT	s.ProductID,
					s.GroupTypeId,
					CASE s.ProductID
						WHEN 3 THEN b.liveindicator
						ELSE 0
					END AS liveindicator,
					SUM(acomm / (1 - apositiontaking - mpositiontaking)) AS GrossComm,
					SUM(CASE 
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
						END) AS TurnOver,
					ISNULL(SUM(winlost - actual_stake), 0) + ISNULL(SUM(awinlost), 0) + ISNULL(SUM(comm), 0) AS AgTotal,
					SUM(mwinlost) AS MAgWinlost,
					ISNULL(SUM(acomm), 0) - ISNULL(SUM(comm), 0) AS Comm,
					COUNT(transid) AS NoOfTicket
			FROM dbo.bettrans14 b WITH (NOLOCK, INDEX = IX_bettrans4)
				INNER JOIN #SportBettype s ON b.bettype = s.Bettype
			WHERE winlostdate BETWEEN @FDate AND @TDate
				AND mrecommend = @CustID
				AND statusID NOT IN (101, 102, 103)
				AND ruben = 1
			GROUP BY s.ProductID, s.GroupTypeId,
					CASE s.ProductID
						WHEN 3 THEN b.liveindicator
						ELSE 0 END;
		END	
	END
	
	SELECT	t.bettype,
			t.ProductID,
			liveindicator,
			SUM(GrossComm) as GrossComm,
			SUM(TurnOver) as TurnOver,	
			SUM(AgTotal) as AgTotal,
			SUM(MAgWinloss) as MAgWinloss,
			SUM(MAgComm) as MAgComm,
			SUM(NumberOfTickets) as NumberOfTickets
	FROM #MAgWinLoss t
	GROUP BY t.bettype, t.ProductID, liveindicator
	ORDER BY t.bettype, t.ProductID, liveindicator;

	SET NOCOUNT OFF;
END

GO

GRANT EXECUTE ON [dbo].[Age_Rpt_WinLossByProduct_Agent] TO [bodbDownlineNet] AS [dbo]
GO

GRANT EXECUTE ON [dbo].[Age_Rpt_WinLossByProduct_Agent] TO [bodbDownlineNetView] AS [dbo]
GO

GRANT EXECUTE ON [dbo].[Age_Rpt_WinLossByProduct_Agent] TO [vnteam] AS [dbo]
GO


