USE [bodb02]
GO

ALTER PROCEDURE [dbo].[Age_Chart_WinlossAnalysis_Agent]
	@CustID			INT,	
	@FromDate		SMALLDATETIME,
	@ToDate			SMALLDATETIME,	
	@ProductIds		VARCHAR(MAX),
	@BalanceUpDay	SMALLDATETIME,
	@MoveBetsDay	SMALLDATETIME
AS	

/*
	Created: Paul
	Task: Win Loss Analysis Chart
	DB: DBAGE.bodb02
	Original: Age_Chart_WinlossAnalysis_MAg
	Revisions:
		- 20170503@Paul: Create new [RedmineID: #75425]
*/

BEGIN
	SET NOCOUNT ON;
	
	CREATE TABLE #AgencyWinloss
	(
		winlossdate SMALLDATETIME,																											
		turnover	MONEY,																				
		winloss		MONEY
	);

	CREATE TABLE #TmpCondSumWL (sporttype INT, bettype INT);

	DECLARE @Srecommend int;

	SELECT @Srecommend =  Srecommend
	FROM custInfo WITH(NOLOCK)
	WHERE custID = @CustID;
	
	DECLARE @isTest BIT = 0;

	SELECT  @isTest = dbo.f_CheckSPVersion(@@PROCID);

	CREATE TABLE #SportBettype (ProductID TINYINT, Bettype SMALLINT);

	INSERT INTO #SportBettype (ProductID, Bettype)
	SELECT ProductID, Bettype
	FROM dbo.f_SportBettypeMatrixByProduct_Sel(@ProductIds, @isTest);
	
	INSERT INTO #TmpCondSumWL(sporttype, bettype)
	SELECT	SportType,
			BetType
	FROM dbo.f_SumWinloss_ConditionSel(@ProductIds);	

	-----Get Special Super to hide data of them before specific date 
	DECLARE @IsHide BIT = 0;
	
	IF EXISTS (SELECT 1 FROM dbo.f_SpecialSuper() WHERE Srecommend = @Srecommend)
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
	    
	SELECT @FDate = @FromDate, @TDate = @ToDate, @CID = @CustID;
	
	IF @ToDate >= @BalanceUpDay
	BEGIN
		IF @FromDate <= @MoveBetsDay
		BEGIN
			SET @FDate = DATEADD(DD, 1, @MoveBetsDay);
		END

		INSERT INTO #AgencyWinloss(winlossdate, turnover, winloss)
		SELECT	winlostdate,
				SUM(CASE WHEN b.liveawayscore = 0 AND b.bettype IN(33,43) THEN ABS(b.stake)/2 ELSE ABS(b.stake) END) AS turnover,
				SUM(mwinlost + acomm - comm) AS winloss			
		FROM bettrans b WITH(NOLOCK) 
			INNER JOIN #SportBettype s ON b.bettype = s.bettype
		WHERE winlostdate BETWEEN @FDate AND @TDate
			AND mrecommend = @CID 
			AND StatusID NOT IN (0,1,101,102,103)			
		GROUP BY winlostdate;
		
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
		
		INSERT INTO #AgencyWinloss(winlossdate, turnover, winloss)
		SELECT	winlostdate,
				ABS(turnover) AS turnover,
				mwinlost + acomm - comm AS winloss
		FROM sum_winloss b WITH(NOLOCK) 
			INNER JOIN #TmpCondSumWL t ON b.sporttype = t.sporttype AND b.bettype = t.bettype  
		WHERE winlostdate BETWEEN @FDate AND @TDate
			AND mrecommend = @CID
			AND roleid = 3;
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
		
		INSERT INTO #AgencyWinloss(winlossdate, turnover, winloss)
		SELECT	winlostdate,
				ABS(turnover) AS turnover,
				mwinlost + acomm - comm AS winloss
		FROM bodb_Summary.dbo.Sum_WinLoss_Old b WITH(NOLOCK) 
			INNER JOIN #TmpCondSumWL t ON b.sporttype = t.sporttype AND b.bettype = t.bettype  
		WHERE winlostdate BETWEEN @FDate AND @TDate
			AND srecommend = @Srecommend
			AND mrecommend = @CID
			AND recommend = recommend
			AND b.sporttype = b.sporttype
			AND b.bettype = b.bettype
			AND roleid = 3;
	END
	
	SELECT	CONVERT(VARCHAR(7), winlossdate, 120) AS winlossdate,
			SUM(turnover) AS turnover,
			SUM(winloss) AS winloss			
	FROM #AgencyWinloss
	GROUP BY CONVERT(VARCHAR(7), winlossdate, 120)
	ORDER BY CONVERT(VARCHAR(7), winlossdate, 120) ASC;

	SET NOCOUNT OFF;
END
GO

GRANT EXECUTE ON [dbo].[Age_Chart_WinlossAnalysis_Agent] TO [bodbDownlineNet] AS [dbo]
GO

GRANT EXECUTE ON [dbo].[Age_Chart_WinlossAnalysis_Agent] TO [bodbDownlineNetView] AS [dbo]
GO

GRANT VIEW DEFINITION ON [dbo].[Age_Chart_WinlossAnalysis_Agent] TO [vnteam] AS [dbo]
GO