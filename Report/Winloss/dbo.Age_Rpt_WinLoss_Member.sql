USE [bodb02]
GO

ALTER PROCEDURE [dbo].[Age_Rpt_WinLoss_Member]
	@CustID 		INT, --recommend
	@FromDate 		SMALLDATETIME,
	@ToDate 		SMALLDATETIME,
	@ProductIds		VARCHAR(MAX),
	@MoveBetsDay	SMALLDATETIME,
	@BalanceUpDay	SMALLDATETIME	
AS

/*
    Created: 
    Task : 
    DB: DBAGE/bodb02
    Original SP: Age_Rpt_WinLoss_Ag
				Change SP name suffix to match with web function
    Revisions:
        - 20161111@Paul: Microsite for Report - [Redmine: #66991]
*/
    
BEGIN
	SET NOCOUNT ON;

	CREATE TABLE #AgWinLoss(
		CustID			INT,
		TurnOver		MONEY,
		GrossComm		MONEY,
		MemberWinLost	MONEY,
		AgWinLost		MONEY,
		PlayerComm		MONEY,
		AgComm			MONEY
	);

	CREATE TABLE #TmpCondSumWL(
		ProductID	TINYINT,
		SportType	INT,
		BetType		INT
	);

	DECLARE @isTest BIT = 0;
	SELECT  @isTest = dbo.f_CheckSPVersion(@@PROCID);	

	INSERT INTO #TmpCondSumWL(ProductID, SportType, BetType) 
	SELECT ProductID, SportType, BetType
	FROM dbo.f_SumWinloss_ConditionSel(@ProductIds);

	------Get @Srecommend
	DECLARE @Srecommend int, @mrecommend int;

	SELECT	@Srecommend =  Srecommend,
			@Mrecommend =  Mrecommend 
	FROM dbo.CustInfo WITH (NOLOCK)
	WHERE CustID = @CustID;

	-----Get Special Super to hide data of them before specific date 
	DECLARE @IsHide BIT = 0;

	IF EXISTS (	SELECT 1 
				FROM dbo.f_SpecialSuper()
				WHERE Srecommend = @Srecommend)
	BEGIN
		SELECT @IsHide = 1;
	END

	----Get Account Login to detect Interal or not
	DECLARE @LoginName NVARCHAR(128);
	SELECT @LoginName = SUSER_NAME();

	--Avoid Parameter Sniffing
	DECLARE @FDate	SMALLDATETIME,
			@TDate	SMALLDATETIME,
			@CID	INT;

	SELECT	@FDate = @FromDate,
			@TDate = @ToDate,
			@CID = @custid;

	DECLARE @SportBettypeMatrix TABLE(
		ProductID	tinyint,
		BetType	smallint
	);

	INSERT INTO @SportBettypeMatrix(
		ProductID,
		BetType
	)
	SELECT	ProductID,
			BetType
	FROM dbo.f_SportBettypeMatrixByProduct_Sel(@ProductIds, @IsTest);

	IF @ToDate >= @BalanceUpDay
	BEGIN 
		IF @FromDate <= @MoveBetsDay
		BEGIN
			SET @FDate = DATEADD(DD, 1, @MoveBetsDay);
		END

		INSERT INTO #AgWinLoss(CustID, TurnOver, GrossComm, MemberWinLost, AgWinLost, PlayerComm, AgComm)
		SELECT	CustID,
		   		SUM(CASE WHEN b.liveawayscore = 0 AND b.bettype IN(33,43) THEN ABS(b.stake)/2 ELSE ABS(b.stake) END) AS TurnOver,
				SUM(CASE WHEN b.bettype = 1000 THEN oddsspread ELSE comm/(1 - apositiontaking) END) AS GrossComm,
				SUM(winlost - actual_stake) AS MemberWinLost,
				SUM(awinlost) AS AgWinLost,
				SUM(playercomm) AS PlayerComm,
				SUM(comm - playercomm) AS AgComm
		FROM Bettrans b WITH(NOLOCK)
			INNER JOIN @SportBettypeMatrix s ON b.bettype = s.Bettype
		WHERE recommend = @CID
			AND winlostdate BETWEEN @FDate AND @TDate
			AND ruben = 1
			AND b.statusID NOT IN (101, 102, 103)
		GROUP BY CustID, b.bettype;
		    
		IF @BalanceUpDay < @FromDate
		BEGIN
			SET @FDate = @FromDate;
		END
		ELSE
		BEGIN
			SET @FDate = @BalanceUpDay;
		END
		
		IF @ToDate > @MoveBetsDay
		BEGIN
			SET @TDate = @MoveBetsDay;
		END

		INSERT INTO #AgWinLoss(CustID, TurnOver, GrossComm, MemberWinLost, AgWinLost, PlayerComm, AgComm)
		SELECT	CustID,
				SUM(ABS(TurnOver)) AS TurnOver,
				SUM(grosscomm) AS GrossComm,
				SUM(winlost) AS MemberWinLost,
				SUM(awinlost) AS AgWinLost,
				SUM(playercomm) AS PlayerComm,
				SUM(comm - playercomm) AS AgComm
		FROM  DBO.Sum_WinLoss b WITH(NOLOCK) 
			INNER JOIN #TmpCondSumWL t ON b.sporttype = t.sporttype AND b.bettype = t.bettype
		WHERE recommend = @CID
			AND Winlostdate BETWEEN @FDate AND @TDate
			AND roleID = 1
		GROUP BY CustID;
	END

	SELECT	@FDate = @FromDate,
			@TDate = @ToDate;

	IF @FromDate < @BalanceUpDay 
	BEGIN
		IF @ToDate >= DATEADD(dd, -1, @BalanceUpDay)
		BEGIN
			SELECT @TDate = DATEADD(dd, -1, @BalanceUpDay);
		END
	
		IF @FromDate < '2016-06-01' AND @IsHide = 1 AND @LoginName <> 'bodbDownlineNetView' --- acc internal login 
		BEGIN
			SELECT @FDate = '2016-06-01';	
		END
		
		INSERT INTO #AgWinLoss(CustID, TurnOver, GrossComm, MemberWinLost, AgWinLost, PlayerComm, AgComm)
		SELECT	CustID,
				SUM(ABS(TurnOver)) AS TurnOver,
				SUM(grosscomm) AS GrossComm,
				SUM(winlost) AS MemberWinLost,
				SUM(awinlost) AS AgWinLost,
				SUM(playercomm) AS PlayerComm,
				SUM(comm - playercomm) AS AgComm
		FROM  bodb_Summary.dbo.Sum_WinLoss_Old b WITH(NOLOCK) 
			INNER JOIN #TmpCondSumWL t ON b.sporttype = t.sporttype AND b.bettype = t.bettype
		WHERE recommend = @CustID 
			AND srecommend = @Srecommend   --- Add Srecommend, Mrecommend to get the index seek 
			AND mrecommend = @mrecommend
			AND roleID = 1
			AND Winlostdate BETWEEN @FDate AND @TDate
		GROUP BY CustID;
	END

	SELECT	w.CustID AS CustId,
			c.UserName AS CustName,
			SUM(TurnOver) AS Turnover,
			SUM(GrossComm) AS GrossComm,
			SUM(MemberWinLost) AS MemberWinLoss,
			SUM(playercomm) AS MemberComm,
			SUM(AgWinLost) AS AgWinLoss,
			SUM(AgComm) AS AgComm
	FROM #AgWinLoss w 
		INNER JOIN dbo.custInfo c WITH(NOLOCK) ON w.CustID = c.CustID 
	GROUP BY w.CustID, c.UserName
	ORDER BY c.Username;

	SET NOCOUNT OFF;
END
GO

GRANT EXECUTE ON [dbo].[Age_Rpt_WinLoss_Member] TO [bodbDownlineNet] AS [dbo]
GO

GRANT EXECUTE ON [dbo].[Age_Rpt_WinLoss_Member] TO [bodbDownlineNetView] AS [dbo]
GO