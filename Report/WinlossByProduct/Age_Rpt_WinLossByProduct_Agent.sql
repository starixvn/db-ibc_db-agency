/*<info serverAlias="DBAGE-bodb02" executers="bodbDownlineNet,bodbDownlineNetView" viewers="vnteam" isFunction="0" isNested="0"></info>*/
USE [bodb02]
GO

ALTER PROCEDURE [dbo].[Age_Rpt_WinLossByProduct_Agent]
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
		- 20170622@Percy: Combine Betradar Virtual Sports with Virtual Sports [RedmineID: #78339]

*/

BEGIN
	SET NOCOUNT ON;

	CREATE TABLE #MAgWinLoss
	(
		ProductID		TINYINT,
		bettype			INT, 
		SportType		SMALLINT,
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

	SELECT @ProductIds = dbo.f_AddRelatedProducts(@ProductIds);

	CREATE TABLE #SportBettype (ProductID TINYINT, Bettype SMALLINT, GroupTypeId INT, SportType SMALLINT, EventType TINYINT);

	INSERT INTO #SportBettype (ProductID, Bettype, GroupTypeId, SportType, EventType)
	SELECT ISNULL(p.GroupProductId, f.ProductID), f.Bettype, f.Bettype, s.SportType, f.EventType
	FROM dbo.f_SportBettypeMatrixByProduct_Sel (@ProductIds, @isTest) f
		LEFT JOIN dbo.SportBettypeMatrix s WITH(NOLOCK)
			ON f.ProductID = s.ProductID AND f.BetType = s.BetType AND s.ProductID IN (23,5,27)
		LEFT JOIN dbo.f_GroupProduct() p ON f.ProductID = p.ProductId
	WHERE f.bettype <> 2799; -- Mix parlay of BRVS

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

			INSERT INTO #MAgWinLoss (ProductID, bettype, SportType, liveindicator, GrossComm, TurnOver, AgTotal, MAgWinloss, MAgComm, NumberOfTickets)
			SELECT	s.ProductID,
					s.GroupTypeId,
					CASE s.ProductID
						WHEN 5 THEN m.sporttype
						WHEN 23 THEN s.SportType
					END AS SportType,
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
									AND b.liveawayscore = 0 THEN ABS(stake) / 2
								ELSE ABS(stake)
								END
						ELSE CASE 
								WHEN b.bettype IN (33, 43)
									AND b.liveawayscore = 0 THEN stake / 2
								ELSE stake
								END
						END) AS TurnOver,
					ISNULL(SUM(winlost - actual_stake), 0) + ISNULL(SUM(awinlost), 0) + ISNULL(SUM(comm), 0) AS AgTotal,
					SUM(mwinlost) AS MAgWinlost,
					ISNULL(SUM(acomm), 0) - ISNULL(SUM(comm), 0) AS Comm,
					COUNT(transid) AS NoOfTicket
			FROM dbo.bettrans b WITH (NOLOCK)
				INNER JOIN #SportBettype s ON (b.bettype = s.Bettype AND (ProductID <> 5 OR EventType <> 3))
				LEFT JOIN dbo.match m WITH(NOLOCK) ON b.matchid = m.matchid AND s.ProductID = 5 AND s.EventType = 1
			WHERE winlostdate BETWEEN @FDate AND @TDate
				AND statusID NOT IN (101, 102, 103)
				AND b.ruben = 1
				AND EXISTS(
					SELECT 1
					FROM @recommend r
					WHERE b.recommend = r.recommend
				)
			GROUP BY s.ProductID, s.GroupTypeId,
					CASE s.ProductID
						WHEN 5 THEN m.sporttype
						WHEN 23 THEN s.SportType
					END,
					CASE s.ProductID
						WHEN 3 THEN b.liveindicator
						ELSE 0 END;

			-- VS Outright
			IF EXISTS (SELECT ProductId FROM #SportBettype WHERE ProductID = 5 AND EventType = 3)
			BEGIN
				INSERT INTO #MAgWinLoss (ProductID, bettype, SportType, liveindicator, GrossComm, TurnOver, AgTotal, MAgWinloss, MAgComm, NumberOfTickets)
				SELECT
					5 AS ProductID,
					s.GroupTypeId,
					r.sporttype,
					0 AS liveindicator,
					SUM(ISNULL(acomm / (1 - apositiontaking - mpositiontaking), 0)) AS GrossComm,
					SUM(ABS(ISNULL(stake, 0))) AS TurnOver,
					SUM(ISNULL(winlost, 0) - ISNULL(actual_stake, 0) + ISNULL(awinlost, 0) + ISNULL(comm, 0)) AS AgTotal,
					SUM(ISNULL(mwinlost, 0)) AS MAgWinlost,
					SUM(ISNULL(acomm, 0) - ISNULL(comm, 0)) AS Comm,
					COUNT(transid) AS NoOfTicket
				FROM dbo.bettrans b WITH (NOLOCK)
					INNER JOIN #SportBettype s ON b.bettype = s.Bettype AND s.ProductID = 5 AND s.EventType = 3
					INNER JOIN dbo.VSOutright o WITH(NOLOCK) ON b.oddsid = o.Orid
					INNER JOIN dbo.VSRaceInfo r WITH(NOLOCK) ON o.EventID = r.EventID
				WHERE winlostdate BETWEEN @FDate AND @TDate
					AND statusID NOT IN (101, 102, 103)
					AND b.ruben = 1
					AND EXISTS(
						SELECT 1
						FROM @recommend r
						WHERE b.recommend = r.recommend
					)
				GROUP BY s.GroupTypeId, r.sporttype
			END
			
			-- Mix parlay of BRVS
			IF EXISTS (SELECT ProductId FROM #SportBettype WHERE ProductID = 5)
			BEGIN
				INSERT INTO #MAgWinLoss (ProductID, bettype, SportType, liveindicator, GrossComm, TurnOver, AgTotal, MAgWinloss, MAgComm, NumberOfTickets)
				SELECT
					5 AS ProductId,
					2799 AS bettype,
					s.sporttype,
					0 AS liveindicator,
					SUM(ISNULL(acomm / (1 - apositiontaking - mpositiontaking), 0)) AS GrossComm,
					SUM(ABS(ISNULL(stake, 0))) AS TurnOver,
					SUM(ISNULL(winlost, 0) - ISNULL(actual_stake, 0) + ISNULL(awinlost, 0) + ISNULL(comm, 0)) AS AgTotal,
					SUM(ISNULL(mwinlost, 0)) AS MAgWinlost,
					SUM(ISNULL(acomm, 0) - ISNULL(comm, 0)) AS Comm,
					COUNT(transid) AS NoOfTicket
				FROM dbo.bettrans b WITH (NOLOCK)
				CROSS APPLY (
					SELECT TOP 1 m.sporttype
					FROM dbo.bettransm bm WITH (NOLOCK)
						INNER JOIN dbo.match m WITH (NOLOCK) ON bm.matchid = m.matchid
						INNER JOIN #SportBettype s ON bm.bettype = s.Bettype AND s.ProductID = 5
					WHERE bm.refno = b.refno
				) AS s
				WHERE b.matchid = 2799 AND b.bettype = 2799
					AND winlostdate BETWEEN @FDate AND @TDate
					AND statusID NOT IN (101, 102, 103)
					AND b.ruben = 1
					AND EXISTS(
						SELECT 1
						FROM @recommend r
						WHERE b.recommend = r.recommend
					)
				GROUP BY s.sporttype
			END
		END

		SET @FDate = @FromDate;
		
		IF @FromDate <= @MoveBetsDay
		BEGIN
			IF @ToDate > @MoveBetsDay
			BEGIN
				SET @TDate = @MoveBetsDay;
			END

			INSERT INTO #MAgWinLoss (ProductID, bettype, SportType, liveindicator, GrossComm, TurnOver, AgTotal, MAgWinloss, MAgComm, NumberOfTickets)
			SELECT	s.ProductID,
					s.GroupTypeId,
					CASE s.ProductID
						WHEN 5 THEN m.sporttype
						WHEN 23 THEN s.SportType
					END AS SportType,
					CASE s.ProductID
						WHEN 3 THEN b.liveindicator
						ELSE 0
					END AS liveindicator,
					SUM(acomm / (1 - apositiontaking - mpositiontaking)) AS GrossComm,
					SUM(CASE 
						WHEN winlostdate >= @ABSDate THEN CASE 
								WHEN b.bettype IN (33, 43)
									AND b.liveawayscore = 0 THEN ABS(stake) / 2
								ELSE ABS(stake)
								END
						ELSE CASE 
								WHEN b.bettype IN (33, 43)
									AND b.liveawayscore = 0 THEN stake / 2
								ELSE stake
								END
						END) AS TurnOver,
					ISNULL(SUM(winlost - actual_stake), 0) + ISNULL(SUM(awinlost), 0) + ISNULL(SUM(comm), 0) AS AgTotal,
					SUM(mwinlost) AS MAgWinlost,
					ISNULL(SUM(acomm), 0) - ISNULL(SUM(comm), 0) AS Comm,
					COUNT(transid) AS NoOfTicket
			FROM dbo.bettrans14 b WITH (NOLOCK, INDEX = IX_bettrans4)
				INNER JOIN #SportBettype s ON (b.bettype = s.Bettype AND (ProductID <> 5 OR EventType <> 3))
				LEFT JOIN dbo.match14 m WITH(NOLOCK) ON b.matchid = m.matchid AND s.ProductID = 5
			WHERE winlostdate BETWEEN @FDate AND @TDate
				AND mrecommend = @CustID
				AND statusID NOT IN (101, 102, 103)
				AND b.ruben = 1
			GROUP BY s.ProductID, s.GroupTypeId,
					CASE s.ProductID
						WHEN 5 THEN m.sporttype
						WHEN 23 THEN s.SportType
					END,
					CASE s.ProductID
						WHEN 3 THEN b.liveindicator
						ELSE 0 END;

			-- VS Outright
			IF EXISTS (SELECT ProductId FROM #SportBettype WHERE ProductID = 5 AND EventType = 3)
			BEGIN
				INSERT INTO #MAgWinLoss (ProductID, bettype, SportType, liveindicator, GrossComm, TurnOver, AgTotal, MAgWinloss, MAgComm, NumberOfTickets)
				SELECT
					5 AS ProductID,
					s.GroupTypeId,
					r.sporttype,
					0 AS liveindicator,
					SUM(ISNULL(acomm / (1 - apositiontaking - mpositiontaking), 0)) AS GrossComm,
					SUM(ABS(ISNULL(stake, 0))) AS TurnOver,
					SUM(ISNULL(winlost, 0) - ISNULL(actual_stake, 0) + ISNULL(awinlost, 0) + ISNULL(comm, 0)) AS AgTotal,
					SUM(ISNULL(mwinlost, 0)) AS MAgWinlost,
					SUM(ISNULL(acomm, 0) - ISNULL(comm, 0)) AS Comm,
					COUNT(transid) AS NoOfTicket
				FROM dbo.bettrans14 b WITH (NOLOCK)
					INNER JOIN #SportBettype s ON b.bettype = s.Bettype AND s.ProductID = 5 AND s.EventType = 3
					INNER JOIN dbo.VSOutright14 o WITH(NOLOCK) ON b.oddsid = o.Orid
					INNER JOIN dbo.VSRaceInfo r WITH(NOLOCK) ON o.EventID = r.EventID
				WHERE winlostdate BETWEEN @FDate AND @TDate
					AND statusID NOT IN (101, 102, 103)
					AND b.ruben = 1
					AND EXISTS(
						SELECT 1
						FROM @recommend r
						WHERE b.recommend = r.recommend
					)
				GROUP BY s.GroupTypeId, r.sporttype
			END
			
			-- Mix parlay of BRVS
			IF EXISTS (SELECT ProductId FROM #SportBettype WHERE ProductID = 5)
			BEGIN
				INSERT INTO #MAgWinLoss (ProductID, bettype, SportType, liveindicator, GrossComm, TurnOver, AgTotal, MAgWinloss, MAgComm, NumberOfTickets)
				SELECT
					5 AS ProductId,
					2799 AS bettype,
					s.sporttype,
					0 AS liveindicator,
					SUM(ISNULL(acomm / (1 - apositiontaking - mpositiontaking), 0)) AS GrossComm,
					SUM(ABS(ISNULL(stake, 0))) AS TurnOver,
					SUM(ISNULL(winlost, 0) - ISNULL(actual_stake, 0) + ISNULL(awinlost, 0) + ISNULL(comm, 0)) AS AgTotal,
					SUM(ISNULL(mwinlost, 0)) AS MAgWinlost,
					SUM(ISNULL(acomm, 0) - ISNULL(comm, 0)) AS Comm,
					COUNT(transid) AS NoOfTicket
				FROM dbo.bettrans14 b WITH (NOLOCK)
				CROSS APPLY (
					SELECT TOP 1 m.sporttype
					FROM dbo.bettransm14 bm WITH (NOLOCK)
						INNER JOIN dbo.match14 m WITH (NOLOCK) ON bm.matchid = m.matchid
						INNER JOIN #SportBettype s ON bm.bettype = s.Bettype AND s.ProductID = 5
					WHERE bm.refno = b.refno
				) AS s
				WHERE b.matchid = 2799 AND b.bettype = 2799
					AND winlostdate BETWEEN @FDate AND @TDate
					AND statusID NOT IN (101, 102, 103)
					AND b.ruben = 1
					AND EXISTS(
						SELECT 1
						FROM @recommend r
						WHERE b.recommend = r.recommend
					)
				GROUP BY s.sporttype
			END
		END	
	END
	
	SELECT	t.bettype,
			t.ProductID,
			t.SportType,
			liveindicator,
			SUM(GrossComm) AS GrossComm,
			SUM(TurnOver) AS TurnOver,	
			SUM(AgTotal) AS AgTotal,
			SUM(MAgWinloss) AS MAgWinloss,
			SUM(MAgComm) AS MAgComm,
			SUM(NumberOfTickets) AS NumberOfTickets
	FROM #MAgWinLoss t
	GROUP BY t.bettype, t.ProductID, t.SportType, liveindicator
	ORDER BY t.bettype, t.ProductID, t.SportType, liveindicator;

	SET NOCOUNT OFF;
END

GO

GRANT EXECUTE ON [dbo].[Age_Rpt_WinLossByProduct_Agent] TO [bodbDownlineNet] AS [dbo]
GO

GRANT EXECUTE ON [dbo].[Age_Rpt_WinLossByProduct_Agent] TO [bodbDownlineNetView] AS [dbo]
GO

GRANT EXECUTE ON [dbo].[Age_Rpt_WinLossByProduct_Agent] TO [vnteam] AS [dbo]
GO


