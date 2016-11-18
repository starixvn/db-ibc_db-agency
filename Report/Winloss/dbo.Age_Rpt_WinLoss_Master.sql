USE [bodb02]
GO

CREATE PROCEDURE [dbo].[Age_Rpt_WinLoss_Master]  
	@CustID 		INT, --srecommend
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
	Original SP: Age_Rpt_WinLoss_SAg  
				Change SP name suffix to match with web function
	Revisions:  
		- 20161111@Paul: Microsite for Report - [Redmine: #66991]

	+ Note: Review index=IX_srecommend when modifying this SP   
*/  
 
BEGIN
	SET NOCOUNT ON;
 
	CREATE TABLE #SAgWinLoss(
		CustID		INT,
		TurnOver	MONEY,
		GrossComm	MONEY,
		MAgTotal	MONEY,
		SAgWinlost	MONEY,
		Comm		MONEY
	);
  
	CREATE TABLE #SelectedProducts(
		ProductID TINYINT
	);

	CREATE TABLE #TmpCondSumWL(
		ProductID	TINYINT,
		SportType	INT,
		BetType		INT
	);	

	INSERT INTO #SelectedProducts(ProductID)
	SELECT CAST(Val AS TINYINT)
	FROM dbo.Age_f_SplitString(@ProductIds, ',');

	INSERT INTO #TmpCondSumWL(ProductID, SportType, BetType) VALUES
	(1, 0, 0), --Sportsbook
	(6, 251, 71), (6, 208, 0), (6, 209, 0), (6, 210, 0), --RNG Casino
	(2, 151, 0), --Racing
	(3, 161, 0), --Number Game
	(4, 162, 0), --Live Casino
	(5, 180, 0), --Virtual Sports
	(8, 202, 0), --Keno
	(12, 255, 0), --Gold Deluxe
	(15, 204, 0), --Colossus Bets
	(21, 211, 0), --Allbet
	(22, 212, 0); --Macau Games

	DELETE tmp
	FROM #TmpCondSumWL tmp
		LEFT JOIN #SelectedProducts sp ON tmp.ProductID = sp.ProductID
	WHERE sp.ProductID IS NULL;

	DECLARE @isTest BIT = 0;
	SELECT  @isTest = dbo.f_CheckSPVersion(@@PROCID);

	-----Get Special Super to hide data of them before specific date 
	DECLARE @IsHide BIT = 0;

	IF EXISTS (	SELECT 1
				FROM dbo.f_SpecialSuper()
				WHERE Srecommend = @CustId)
	BEGIN
		SELECT @IsHide = 1;
	END

	----Get Account Login to detect Interal or not
	DECLARE @LoginName NVARCHAR(128);
	SELECT @LoginName = SUSER_NAME();

	--Avoid Parameter Sniffing for bettrans and sum_winloss
	DECLARE @FDate	SMALLDATETIME,
			@TDate	SMALLDATETIME,
			@CID	INT;
			    	    
	SELECT	@FDate = @FromDate,
			@TDate = @ToDate,
			@CID = @custid;

	DECLARE @SportBettypeMatrix TABLE(
		ProductID	tinyint,
		BetType	smallint,
		EventType	tinyint,
		SubProduct	varchar(500),
		RefTable	tinyint,
		CasinoType	tinyint
	);

	INSERT INTO @SportBettypeMatrix(
		ProductID,
		BetType,
		EventType,
		SubProduct,
		RefTable,
		CasinoType
	)
	SELECT	s.ProductID,
			BetType,
			EventType,
			SubProduct,
			RefTable,
			CasinoType
	FROM dbo.f_SportBettypeMatrix_Sel(0, 0, 0, 2, '', '', @IsTest) s
		INNER JOIN #SelectedProducts p on p.ProductID = s.ProductID;

	IF @ToDate >= @BalanceUpDay
	BEGIN
		IF @FromDate <= @MoveBetsDay
		BEGIN
			SET @FDate = DATEADD(DD, 1, @MoveBetsDay);
		END

		INSERT INTO #SAgWinLoss(CustID, TurnOver, GrossComm, MAgTotal, SAgWinlost, Comm)
		SELECT  mrecommend AS CustID,
				SUM(CASE WHEN b.liveawayscore = 0 AND b.bettype IN(33,43) THEN ABS(b.stake)/2 ELSE ABS(b.stake) END) AS TurnOver,
				SUM(CASE WHEN b.bettype = 1000 THEN oddsspread ELSE CASE WHEN tpositiontaking = 1 THEN 0 ELSE scomm/(1 - tpositiontaking) END END) AS GrossComm,
				SUM(mwinlost + awinlost + acomm + winlost - actual_stake) AS MAgTotal,
				SUM(swinlost) AS SAgWinlost,
				ISNULL(SUM(scomm), 0) - ISNULL(SUM(acomm), 0) AS Comm
		FROM dbo.bettrans b WITH (NOLOCK, index = IX_srecommend)  
			INNER JOIN @SportBettypeMatrix s ON b.bettype = s.Bettype
		WHERE SRecommend = @CID 
			AND  winlostdate BETWEEN @FDate AND @TDate 
			AND  b.statusID NOT IN (0, 1, 101, 102, 103)  
		GROUP BY mrecommend, b.bettype;
   
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
  
		INSERT INTO #SAgWinLoss(CustID, TurnOver, GrossComm, MAgTotal, SAgWinlost, Comm)
		SELECT  CustID,
				SUM(ABS(TurnOver)) AS TurnOver,
				SUM(ISNULL(grosscomm, 0)) AS GrossComm,
				SUM(mwinlost + awinlost + acomm + winlost) AS MAgTotal,
				SUM(swinlost) AS SAgWinlost,
				ISNULL(SUM(scomm), 0) - ISNULL(SUM(acomm), 0) AS Comm
		FROM dbo.sum_winloss b WITH (NOLOCK) 
			INNER JOIN #TmpCondSumWL t ON b.sporttype = t.sporttype AND b.bettype = t.bettype  
		WHERE winlostdate BETWEEN @FDate AND @TDate
			AND Srecommend = @CID
			AND roleid = 3  
		GROUP BY custid;  
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

		INSERT INTO #SAgWinLoss(CustID, TurnOver, GrossComm, MAgTotal, SAgWinlost, Comm)
		SELECT  CustID,
				SUM(ABS(TurnOver)) AS TurnOver,
				SUM(ISNULL(grosscomm,0)) AS GrossComm,
				SUM(mwinlost + awinlost + acomm + winlost) AS MAgTotal,
				SUM(swinlost) AS SAgWinlost,
				ISNULL(SUM(scomm), 0) - ISNULL(SUM(acomm), 0) AS Comm
		FROM bodb_Summary.dbo.Sum_WinLoss_Old b WITH(NOLOCK) 
			INNER JOIN #TmpCondSumWL t ON b.sporttype = t.sporttype AND b.bettype = t.bettype  
		WHERE b.Winlostdate BETWEEN @FDate AND @TDate  
			AND SRecommend = @CustID  
			AND mrecommend = mrecommend
			AND recommend = recommend
			AND RoleID = 3  
		GROUP BY CustID;
	END  
  
	SELECT	w.CustID AS CustId,
			c.UserName AS CustName,
			SUM(TurnOver) AS Turnover,
			SUM(GrossComm) AS GrossComm,
			SUM(MAgTotal) AS MAgTotal,
			SUM(SAgWinlost) AS SAgWinLoss,
			SUM(Comm) AS SAgComm  
	FROM #SAgWinLoss w 
		INNER JOIN Customer c WITH(NOLOCK) ON w.CustID = c.CustID   
	GROUP BY w.CustID, c.UserName  
	ORDER BY c.Username;

	SET NOCOUNT OFF;
END
GO

GRANT EXECUTE ON [dbo].[Age_Rpt_WinLoss_Master] TO [bodbDownlineNet] AS [dbo]
GO

GRANT EXECUTE ON [dbo].[Age_Rpt_WinLoss_Master] TO [bodbDownlineNetView] AS [dbo]
GO