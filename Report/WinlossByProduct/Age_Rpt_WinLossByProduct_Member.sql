USE [bodb02]
GO

ALTER PROCEDURE [dbo].[Age_Rpt_WinLossByProduct_Member]
	@CustID 		INT,
	@FromDate 		SMALLDATETIME,
	@ToDate			SMALLDATETIME,	
	@BalanceUpDay	SMALLDATETIME, 
	@MoveBetsDay	SMALLDATETIME,
	@ProductIds		VARCHAR(MAX)
AS

/*
	Created: 
	Task: 
	DB: DBAGE.bodb02
	Original: Age_Rpt_WinLossByBettype_Ag
	Revisions:
		- 20161224@Paul: Create new [RedmineID: #70450]
		- 20170622@Percy: Combine Betradar Virtual Sports with Virtual Sports [RedmineID: #78339]

*/

BEGIN
	SET NOCOUNT ON;

	CREATE TABLE #AgWinLoss(
		ProductID		TINYINT,
		bettype			INT, 
		SportType		SMALLINT,
		liveindicator	INT,
		GrossComm		MONEY,
		Turnover		MONEY, 
		MemberWinLoss	MONEY, 
		AgWinLoss		MONEY, 
		MemberComm		MONEY, 
		AgComm			MONEY, 
		NumberOfTickets INT
	);

	DECLARE @ABSDate DATETIME;
	SET @ABSDate = '2011-09-01';

	DECLARE @isTest BIT = 0;
	SELECT  @isTest = dbo.f_CheckSPVersion(@@PROCID);

	SELECT @ProductIds = dbo.f_AddRelatedProducts(@ProductIds);

	CREATE TABLE #SportBettype (ProductID TINYINT, Bettype SMALLINT, GroupTypeId INT, SportType SMALLINT);

	INSERT INTO #SportBettype (ProductID, Bettype, GroupTypeId, SportType)
	SELECT ISNULL(p.GroupProductId, f.ProductID), f.Bettype, f.Bettype, s.SportType
	FROM dbo.f_SportBettypeMatrixByProduct_Sel (@ProductIds, @isTest) f
		LEFT JOIN dbo.SportBettypeMatrix s WITH(NOLOCK)
			ON f.ProductID = s.ProductID AND f.BetType = s.BetType AND s.ProductID IN (23,5,27)
		LEFT JOIN dbo.f_GroupProduct() p ON f.ProductID = p.ProductId;

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

			INSERT INTO #AgWinLoss(ProductID, bettype, SportType, liveindicator, GrossComm, Turnover, MemberWinLoss, AgWinLoss, MemberComm, AgComm, NumberOfTickets)
			SELECT	s.ProductID,
					s.GroupTypeId,
					s.SportType,
					CASE s.ProductID
						WHEN 3 THEN b.liveindicator
						ELSE 0 
					END AS liveindicator,
					SUM(CASE WHEN b.bettype = 1000 THEN oddsspread ELSE comm/(1 - apositiontaking) END) AS GrossComm,
					SUM(CASE WHEN winlostdate >= @ABSDate THEN 
								CASE WHEN b.bettype in (33, 43) AND liveawayscore = 0 THEN ABS(stake)/2 ELSE ABS(stake) END
							ELSE CASE WHEN b.bettype in (33, 43) AND liveawayscore = 0 THEN stake/2 ELSE stake END
					END
					) AS Turnover,
					SUM(winlost - actual_stake) AS MemberWinLoss,
					SUM(awinlost) AS AgWinLoss,
					SUM(playercomm) AS MemberComm,
					SUM(comm - playercomm) AS AgComm,
					COUNT(transid) AS NumberOfTickets
			FROM Bettrans b WITH(NOLOCK)
				INNER JOIN #SportBettype s ON(b.bettype = s.Bettype)
			WHERE winlostdate BETWEEN @FDate AND @TDate
				AND ruben = 1
				AND statusID NOT IN (101, 102, 103)
				AND recommend = @custid
			GROUP BY s.ProductID, s.GroupTypeId, s.SportType,
					CASE s.ProductID
						WHEN 3 THEN b.liveindicator
						ELSE 0
					END;
		END

		SET @FDate = @FromDate;
		
		IF @FromDate <= @MoveBetsDay
		BEGIN
			IF @ToDate > @MoveBetsDay
			BEGIN
				SET @TDate = @MoveBetsDay;
			END

			INSERT INTO #AgWinLoss(ProductID, bettype, SportType, liveindicator, GrossComm, Turnover, MemberWinLoss, AgWinLoss, MemberComm, AgComm, NumberOfTickets)
			SELECT  s.ProductID,
					s.GroupTypeId,
					s.SportType,
					CASE s.ProductID
						WHEN 3 THEN b.liveindicator
						ELSE 0 
					END AS liveindicator,
					SUM(CASE WHEN b.bettype = 1000 THEN oddsspread ELSE comm/(1 - apositiontaking) END) AS GrossComm,
					SUM(CASE WHEN winlostdate >= @ABSDate THEN 
								CASE WHEN b.bettype in (33, 43) AND liveawayscore = 0 THEN ABS(stake)/2 ELSE ABS(stake) END
							ELSE CASE WHEN b.bettype in (33, 43) AND liveawayscore = 0 THEN stake/2 ELSE stake END
					END
					) AS Turnover,
					SUM(winlost - actual_stake) AS MemberWinLoss,
					SUM(awinlost) AS AgWinLoss,
					SUM(playercomm) AS MemberComm,
					SUM(comm - playercomm) AS AgComm,
					COUNT(transid) AS NumberOfTickets
			FROM Bettrans14 b WITH(NOLOCK)
				INNER JOIN #SportBettype s ON(b.bettype = s.Bettype)
			WHERE winlostdate BETWEEN @FDate AND @TDate
				AND ruben = 1
				AND statusID NOT IN (101, 102, 103)
				AND recommend = @custid
			GROUP BY s.ProductID, s.GroupTypeId, s.SportType,
					CASE s.ProductID
						WHEN 3 THEN b.liveindicator
						ELSE 0
					END;
		END
	END

	SELECT	t.bettype,
			t.ProductID,
			t.SportType,
			liveindicator,
			SUM(GrossComm) AS GrossComm,
			SUM(TurnOver) AS Turnover,
			SUM(MemberWinLoss) AS MemberWinLoss,
			SUM(MemberComm) AS MemberComm,
			SUM(AgWinLoss) AS AgWinLoss,
			SUM(AgComm) AS AgComm,
			SUM(NumberOfTickets) AS NumberOfTickets
	FROM #AgWinLoss t
	GROUP BY t.bettype, t.ProductID, t.SportType, liveindicator
	ORDER BY t.bettype, t.ProductID, t.SportType, liveindicator;

	SET NOCOUNT OFF;
END

GO

GRANT EXECUTE ON [dbo].[Age_Rpt_WinLossByProduct_Member] TO [bodbDownlineNet] AS [dbo]
GO

GRANT EXECUTE ON [dbo].[Age_Rpt_WinLossByProduct_Member] TO [bodbDownlineNetView] AS [dbo]
GO

GRANT EXECUTE ON [dbo].[Age_Rpt_WinLossByProduct_Member] TO [vnteam] AS [dbo]
GO


