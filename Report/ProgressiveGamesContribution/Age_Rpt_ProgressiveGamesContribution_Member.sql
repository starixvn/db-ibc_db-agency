/*<info serverAlias="DBAGE-bodb02" executers="bodbDownlineNet,bodbDownlineNetView" viewers="" isFunction="0" isNested="0"></info>*/
USE [bodb02]
GO

ALTER PROCEDURE [dbo].[Age_Rpt_ProgressiveGamesContribution_Member]
	@CustID			INT,
	@FromDate		SMALLDATETIME,
	@ToDate			SMALLDATETIME,
	@MoveBetsDay	SMALLDATETIME,
	@BalanceUpDay	SMALLDATETIME,
	@ProductIds		VARCHAR(MAX) = ''
AS

/*
	Created by Percy
	Date: 2018-02-05
	DB: DBAGE.bodb02
	Task: Progressive Games Contribution Report - Agent view

	Revisions:
		- 20180205@Percy: Initialize SP [RedmineID: #89117]
		- 20180420@Percy: Change stake to actual_stake for Contribution formula [RedmineID: #94025]
		- 20180529@Percy: Change Contribution formula [RedmineID: #96053]
		- 20180607@Percy: Change Contribution data type [RedmineID: #96053]
		- 20200809@Sophia: Add PP Jackpot contribution [Redmine: #138483]

	Param's Explanation:
		@BalanceUpDay: SP do not use, just support web's param (MB-BU)
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @SportBettypeMatrix TABLE (ProductId INT, bettype INT, ContributionBettype INT)

	INSERT INTO @SportBettypeMatrix (ProductId, bettype, ContributionBettype)
	SELECT ProductId, BetType, ContributionBettype FROM dbo.f_ProgressiveGamesContribution_Bettype_Sel(@ProductIds)

	DECLARE @FDate SMALLDATETIME, @TDate SMALLDATETIME

	CREATE TABLE #Contribution
	(
		ProductId INT, BetType INT, TurnOver MONEY,
		Contribution DECIMAL(19,8), ContributionAgent MONEY
	)

	IF @ToDate > @MoveBetsDay
	BEGIN
		SELECT	@TDate = @ToDate,
				@FDate = CASE WHEN @FromDate <= @MoveBetsDay THEN DATEADD(DAY, 1, @MoveBetsDay) ELSE @FromDate END

		IF EXISTS (SELECT val FROM strSplit (@ProductIds,',') WHERE val = 6) 
		INSERT INTO #Contribution (ProductId, BetType, TurnOver, Contribution, ContributionAgent)
		SELECT
			s.ProductId, s.Bettype,
			SUM(ISNULL(b.oddsspread, 0)),
			SUM(ISNULL(CONVERT(DECIMAL, b.betid)/100000000, 0)),
			SUM(ISNULL(b.awinlost, 0))
		FROM dbo.bettrans b WITH (NOLOCK)
			INNER JOIN @SportBettypeMatrix s ON b.bettype = s.ContributionBettype AND s.ProductID = 6
		WHERE b.recommend = @CustID
			AND b.winlostdate BETWEEN @FDate AND @TDate
			AND b.statusID IN (111, 112, 113)
		GROUP BY s.ProductId, s.bettype
		
		IF EXISTS (SELECT val FROM strSplit (@ProductIds,',') WHERE val = 32) 
		INSERT INTO #Contribution (ProductId, BetType, TurnOver, Contribution, ContributionMaster, ContributionAgent)
		SELECT
			sc.ProductId, bb.GameId,
			SUM(ISNULL(bc.BetStake, 0)),
			SUM(ISNULL(bc.ContributionStake3rd, 0)),
			SUM(ISNULL(bc.mwinlost, 0)),
			SUM(ISNULL(bc.awinlost, 0))
		FROM dbo.bettransRNG bc WITH (NOLOCK)
			INNER JOIN dbo.bettransRNG bb WITH (NOLOCK) ON bc.RefNo2 = bb.TransId
			CROSS APPLY (SELECT sc.ProductID FROM  @SportBettypeMatrix sc WHERE bb.GameId = sc.bettype AND sc.ProductID = 32 ) sc
			CROSS APPLY (SELECT sb.ProductID FROM  @SportBettypeMatrix sb WHERE bb.GameId = sb.bettype AND sb.ProductID = 32 ) sb
		WHERE bc.recommend = @CustID
			AND bc.winlostdate BETWEEN @FDate AND @TDate
			AND bc.statusID IN (111, 112, 113)
		GROUP BY sc.ProductId, bb.GameId
	END

	IF @FromDate <= @MoveBetsDay
	BEGIN
		SELECT  @FDate = @FromDate,
				@TDate = CASE WHEN @ToDate > @MoveBetsDay THEN @MoveBetsDay ELSE @ToDate END
		
		INSERT INTO #Contribution (ProductId, BetType, TurnOver, Contribution, ContributionAgent)
		SELECT
			s.ProductId, s.Bettype,
			SUM(ISNULL(rpt.Turnover, 0)),
			SUM(ISNULL(rpt.Contribution, 0)),
			SUM(ISNULL(rpt.ContributionA, 0))
		FROM bodb_Summary.dbo.rptProgressiveGamesContribution rpt WITH (NOLOCK)
			INNER JOIN @SportBettypeMatrix s ON rpt.gameId = s.ContributionBettype
		WHERE rpt.CustId = @CustID
			AND rpt.winlostdate BETWEEN @FDate AND @TDate
		GROUP BY s.ProductId, s.bettype
	END

	SELECT
		ProductId, BetType,
		SUM(TurnOver) AS TurnOver,
		SUM(Contribution) AS Contribution,
		SUM(ContributionAgent) AS ContributionAgent
	FROM #Contribution
	GROUP BY ProductId, BetType
	ORDER BY ProductId, BetType

	DROP TABLE #Contribution
END
GO