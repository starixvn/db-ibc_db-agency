/*<info serverAlias="DBAGE-bodb02" executers="bodbDownlineNet,bodbDownlineNetView" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Age_Rpt_WinLossByProduct_Master]
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
	
	Revisions:
		- 20161224@Paul: Create new [RedmineID: #70450]
		- 20170622@Percy: Combine Betradar Virtual Sports with Virtual Sports [RedmineID: #78339]
		- 20180419@Alvin: Combine Macau Games and Pragmatic [RedmineID: #92647]
		- 20180914@Percy: Poker Games - Modify GrossComm [RedmineID: #101550]
		- 20181003@Patrick: Index revolution [RedmineID: #101405]
		- 20190826@Percy: Remove inactive products [RedmineID: #118699]
		- 20191029@Percy: Integrate Spadegaming [RedmineID: #122353]
		- 20200622@Sol: Archive VSRaceInfo - changed to use VSRaceInfo14 [RedmineID: #135963]
		- 20200810@Sophia: Exclude these Products: Pragmatic, Card Club, Spadegaming of of Macau Games [Redmine: #137767]
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

	DECLARE @isTest BIT = 0;
	SELECT  @isTest = dbo.f_CheckSPVersion(@@PROCID);

	SELECT @ProductIds = dbo.f_AddRelatedProducts(@ProductIds);


	CREATE TABLE #SportBettype (ProductID TINYINT, Bettype SMALLINT, GroupTypeId INT, SportType SMALLINT, EventType TINYINT);

	INSERT INTO #SportBettype (ProductID, Bettype, GroupTypeId, SportType, EventType)
	SELECT ISNULL(p.GroupProductId, f.ProductID), f.Bettype, f.Bettype, s.SportType, f.EventType
	FROM dbo.f_SportBettypeMatrixByProduct_Sel (@ProductIds, @isTest) f
		LEFT JOIN dbo.SportBettypeMatrix s WITH(NOLOCK)
			ON f.ProductID = s.ProductID AND f.BetType = s.BetType AND s.ProductID IN (23)
		LEFT JOIN dbo.f_GroupProduct() p ON f.ProductID = p.ProductId
	WHERE f.bettype <> 2799; -- Mix parlay of BRVS

	UPDATE s
	SET GroupTypeId = f.GroupTypeId
	FROM #SportBettype s
		INNER JOIN dbo.f_GroupBettype() f ON s.Bettype = f.Bettype;

	CREATE CLUSTERED INDEX ix_SportBettype_cl ON #SportBettype(Bettype);

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
					CASE s.ProductID
						WHEN 5 THEN m.sporttype
						WHEN 22 THEN s.SportType
						WHEN 23 THEN s.SportType
					END AS SportType,
					CASE s.ProductID
						WHEN 3 THEN b.liveindicator
						ELSE 0
					END AS liveindicator,
					SUM(CASE WHEN tpositiontaking = 1 THEN 0 ELSE scomm / (1 - tpositiontaking) END) AS GrossComm,
					SUM(ABS(stake)) AS Turnover,
					SUM(mwinlost + awinlost + acomm + winlost - actual_stake) AS MAgTotal,
					SUM(swinlost) AS SAgWinloss,
					ISNULL(SUM(scomm), 0) - ISNULL(SUM(acomm), 0) AS SAgComm,
					COUNT(transid) AS NumberOfTickets
			FROM dbo.bettrans b WITH(NOLOCK)
				INNER JOIN #SportBettype s ON (b.bettype = s.Bettype AND (ProductID <> 5 OR EventType <> 3))
				LEFT JOIN dbo.match m WITH(NOLOCK) ON b.matchid = m.matchid AND s.ProductID = 5
			WHERE winlostdate BETWEEN @FDate AND @TDate
				AND statusID NOT IN (0, 1, 101, 102, 103)
				AND b.srecommend = @CustID
			GROUP BY s.ProductID, s.GroupTypeId,
					CASE s.ProductID
						WHEN 5 THEN m.sporttype
						WHEN 22 THEN s.SportType
						WHEN 23 THEN s.SportType
					END,
					CASE s.ProductID
						WHEN 3 THEN b.liveindicator
						ELSE 0 END;

			-- VS Outright
			IF EXISTS (SELECT ProductId FROM #SportBettype WHERE ProductID = 5 AND EventType = 3)
			BEGIN
				INSERT INTO #SAgWinLoss(ProductID, bettype, SportType, liveindicator, GrossComm, Turnover, MAgTotal, SAgWinloss, SAgComm, NumberOfTickets)
				SELECT
					5 AS ProductID,
					s.GroupTypeId,
					r.sporttype,
					0 AS liveindicator,
					SUM(CASE WHEN tpositiontaking = 1 THEN 0 ELSE ISNULL(scomm / (1 - tpositiontaking), 0) END) AS GrossComm,
					SUM(ABS(ISNULL(stake, 0))) AS TurnOver,
					SUM(ISNULL(winlost, 0) - ISNULL(actual_stake, 0) + ISNULL(mwinlost, 0) + ISNULL(awinlost, 0) + ISNULL(acomm, 0)) AS MAgTotal,
					SUM(ISNULL(swinlost, 0)) AS SAgWinloss,
					SUM(ISNULL(scomm, 0) - ISNULL(acomm, 0)) AS SAgComm,
					COUNT(transid) AS NumberOfTickets
				FROM dbo.bettrans b WITH (NOLOCK)
					INNER JOIN #SportBettype s ON b.bettype = s.Bettype AND s.ProductID = 5 AND s.EventType = 3
					INNER JOIN dbo.VSOutright o WITH(NOLOCK) ON b.oddsid = o.Orid
					INNER JOIN dbo.VSRaceInfo r WITH(NOLOCK) ON o.EventID = r.EventID
				WHERE winlostdate BETWEEN @FDate AND @TDate
					AND statusID NOT IN (101, 102, 103)
					AND b.ruben = 1
					AND b.srecommend = @CustID
				GROUP BY s.GroupTypeId, r.sporttype
			END
			
			-- Mix parlay of BRVS
			IF EXISTS (SELECT ProductId FROM #SportBettype WHERE ProductID = 5)
			BEGIN
				INSERT INTO #SAgWinLoss(ProductID, bettype, SportType, liveindicator, GrossComm, Turnover, MAgTotal, SAgWinloss, SAgComm, NumberOfTickets)
				SELECT
					5 AS ProductId,
					2799 AS bettype,
					s.sporttype,
					0 AS liveindicator,
					SUM(CASE WHEN tpositiontaking = 1 THEN 0 ELSE ISNULL(scomm / (1 - tpositiontaking), 0) END) AS GrossComm,
					SUM(ABS(ISNULL(stake, 0))) AS TurnOver,
					SUM(ISNULL(winlost, 0) - ISNULL(actual_stake, 0) + ISNULL(mwinlost, 0) + ISNULL(awinlost, 0) + ISNULL(acomm, 0)) AS MAgTotal,
					SUM(ISNULL(swinlost, 0)) AS SAgWinloss,
					SUM(ISNULL(scomm, 0) - ISNULL(acomm, 0)) AS SAgComm,
					COUNT(transid) AS NumberOfTickets
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
					AND b.srecommend = @CustID
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

			INSERT INTO #SAgWinLoss(ProductID, bettype, SportType, liveindicator, GrossComm, Turnover, MAgTotal, SAgWinloss, SAgComm, NumberOfTickets)
			SELECT  s.ProductID,
					s.GroupTypeId,
					CASE s.ProductID
						WHEN 5 THEN m.sporttype
						WHEN 22 THEN s.SportType
						WHEN 23 THEN s.SportType
					END AS SportType,
					CASE s.ProductID
						WHEN 3 THEN b.liveindicator
						ELSE 0
					END AS liveindicator,
					SUM(CASE WHEN tpositiontaking = 1 THEN 0 ELSE scomm / (1 - tpositiontaking) END) AS GrossComm,
					SUM(ABS(stake)) AS Turnover,
					SUM(mwinlost + awinlost + acomm + winlost - actual_stake) AS MAgTotal,
					SUM(swinlost) AS SAgWinloss,
					ISNULL(SUM(scomm), 0) - ISNULL(SUM(acomm), 0) AS SAgComm,
					COUNT(transid) AS NumberOfTickets
			FROM dbo.bettrans14 b WITH(NOLOCK)
				INNER JOIN #SportBettype s ON (b.bettype = s.Bettype AND (ProductID <> 5 OR EventType <> 3))
				LEFT JOIN dbo.match14 m WITH(NOLOCK) ON b.matchid = m.matchid AND s.ProductID = 5
			WHERE winlostdate BETWEEN @FDate AND @TDate
				AND statusID NOT IN (0, 1, 101, 102, 103)	
				AND b.ruben = 1			
				AND b.srecommend = @CustID
			GROUP BY s.ProductID, s.GroupTypeId,
					CASE s.ProductID
						WHEN 5 THEN m.sporttype
						WHEN 22 THEN s.SportType
						WHEN 23 THEN s.SportType
					END,
					CASE s.ProductID
						WHEN 3 THEN b.liveindicator
						ELSE 0 END;

			-- VS Outright
			IF EXISTS (SELECT ProductId FROM #SportBettype WHERE ProductID = 5 AND EventType = 3)
			BEGIN
				INSERT INTO #SAgWinLoss(ProductID, bettype, SportType, liveindicator, GrossComm, Turnover, MAgTotal, SAgWinloss, SAgComm, NumberOfTickets)
				SELECT
					5 AS ProductID,
					s.GroupTypeId,
					r.sporttype,
					0 AS liveindicator,
					SUM(CASE WHEN tpositiontaking = 1 THEN 0 ELSE ISNULL(scomm / (1 - tpositiontaking), 0) END) AS GrossComm,
					SUM(ABS(ISNULL(stake, 0))) AS TurnOver,
					SUM(ISNULL(winlost, 0) - ISNULL(actual_stake, 0) + ISNULL(mwinlost, 0) + ISNULL(awinlost, 0) + ISNULL(acomm, 0)) AS MAgTotal,
					SUM(ISNULL(swinlost, 0)) AS SAgWinloss,
					SUM(ISNULL(scomm, 0) - ISNULL(acomm, 0)) AS SAgComm,
					COUNT(transid) AS NumberOfTickets
				FROM dbo.bettrans14 b WITH (NOLOCK)
					INNER JOIN #SportBettype s ON b.bettype = s.Bettype AND s.ProductID = 5 AND s.EventType = 3
					INNER JOIN dbo.VSOutright14 o WITH(NOLOCK) ON b.oddsid = o.Orid
					INNER JOIN dbo.VSRaceInfo14 r WITH(NOLOCK) ON o.EventID = r.EventID
				WHERE winlostdate BETWEEN @FDate AND @TDate
					AND statusID NOT IN (101, 102, 103)
					AND b.ruben = 1
					AND b.srecommend = @CustID
				GROUP BY s.GroupTypeId, r.sporttype
			END
			
			-- Mix parlay of BRVS
			IF EXISTS (SELECT ProductId FROM #SportBettype WHERE ProductID = 5)
			BEGIN
				INSERT INTO #SAgWinLoss(ProductID, bettype, SportType, liveindicator, GrossComm, Turnover, MAgTotal, SAgWinloss, SAgComm, NumberOfTickets)
				SELECT
					5 AS ProductId,
					2799 AS bettype,
					s.sporttype,
					0 AS liveindicator,
					SUM(CASE WHEN tpositiontaking = 1 THEN 0 ELSE ISNULL(scomm / (1 - tpositiontaking), 0) END) AS GrossComm,
					SUM(ABS(ISNULL(stake, 0))) AS TurnOver,
					SUM(ISNULL(winlost, 0) - ISNULL(actual_stake, 0) + ISNULL(mwinlost, 0) + ISNULL(awinlost, 0) + ISNULL(acomm, 0)) AS MAgTotal,
					SUM(ISNULL(swinlost, 0)) AS SAgWinloss,
					SUM(ISNULL(scomm, 0) - ISNULL(acomm, 0)) AS SAgComm,
					COUNT(transid) AS NumberOfTickets
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
					AND b.srecommend = @CustID
				GROUP BY s.sporttype
			END
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
