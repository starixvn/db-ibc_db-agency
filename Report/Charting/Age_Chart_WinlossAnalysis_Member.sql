/*<info serverAlias="DBAGE-bodb02" executers="bodbDownlineNet,bodbDownlineNetView" viewers="vnteam" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Age_Chart_WinlossAnalysis_Member]
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
	Original: Age_Chart_WinlossAnalysis_Ag
	Revisions:
		- 20170503@Paul: Create new [RedmineID: #75425]
		- 20170622@Percy: Combine Betradar Virtual Sports with Virtual Sports [RedmineID: #78339]
		- 20170728@Paul: Return 0 if that month has no data [RedmineID: #80779]
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

	CREATE TABLE #Result
	(
		winlossdate VARCHAR(7),																											
		turnover	MONEY,																				
		winloss		MONEY
	);

	DECLARE @Srecommend INT,
			@mrecommend INT,
			@NumOfMonths TINYINT,
			@i TINYINT = 0,
			@TempDate SMALLDATETIME;

	SELECT	@Srecommend = Srecommend,
			@Mrecommend = Mrecommend 
	FROM custInfo WITH(NOLOCK)
	WHERE custID = @CustID;
  
	SET @NumOfMonths = DATEDIFF(M, @FromDate, @ToDate) + 1;

	DECLARE @isTest BIT = 0;
	SELECT  @isTest = dbo.f_CheckSPVersion(@@PROCID);

	SELECT @ProductIds = dbo.f_AddRelatedProducts(@ProductIds);

	CREATE TABLE #SportBettype (Bettype SMALLINT);

	INSERT INTO #SportBettype (Bettype)
	SELECT Bettype 
	FROM dbo.f_SportBettypeMatrixByProduct_Sel(@ProductIds, @isTest);

	INSERT INTO #TmpCondSumWL(sporttype, bettype)
	SELECT	SportType,
			BetType
	FROM dbo.f_SumWinloss_ConditionSel(@ProductIds);

	WHILE @i < @NumOfMonths
	BEGIN
		SET @TempDate = DATEADD(M, @i, @FromDate);

		INSERT INTO #Result(winlossdate, winloss, turnover)
		VALUES(CONVERT(VARCHAR(7), @TempDate, 120), 0, 0);

		SET @i = @i + 1;
	END

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
				SUM(CASE WHEN b.liveawayscore = 0 AND b.bettype IN(33, 43) THEN ABS(b.stake)/2 ELSE ABS(b.stake) END) AS turnover,			
				SUM(awinlost + comm - playercomm) AS winloss			
		FROM bettrans b WITH(NOLOCK) 
			INNER JOIN #SportBettype s ON b.bettype = s.bettype
		WHERE winlostdate BETWEEN @FDate AND @TDate
			AND recommend = @CID 
			AND StatusID NOT IN (0, 1, 101, 102, 103)			
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
				awinlost + comm - playercomm AS winloss
		FROM sum_winloss b WITH(NOLOCK) 
			INNER JOIN #TmpCondSumWL t ON b.sporttype = t.sporttype AND b.bettype = t.bettype  
		WHERE winlostdate BETWEEN @FDate AND @TDate
			AND recommend = @CID
			AND roleid = 2;
	END
	
	SELECT	@FDate = @FromDate,
			@TDate = @ToDate;

	IF @FromDate < @BalanceUpDay 
	BEGIN
		IF @ToDate >= DATEADD(DD, -1, @BalanceUpDay)
		BEGIN
			SELECT @TDate = DATEADD(DD, -1, @BalanceUpDay);
		END
	
		IF @FromDate < '2016-06-01' AND @IsHide = 1 AND @LoginName <> 'bodbDownlineNetView' --- acc internal login 
		BEGIN
			SELECT @FDate = '2016-06-01';	
		END
			
		INSERT INTO #AgencyWinloss(winlossdate, turnover, winloss)
		SELECT	winlostdate,
				ABS(turnover) AS turnover,
				awinlost + comm - playercomm AS winloss
		FROM bodb_Summary.dbo.Sum_WinLoss_Old b WITH(NOLOCK)
			INNER JOIN #TmpCondSumWL t ON b.sporttype = t.sporttype AND b.bettype = t.bettype  
		WHERE winlostdate BETWEEN @FDate AND @TDate
			AND srecommend = @Srecommend  
			AND mrecommend = @mrecommend 
			AND recommend = @CID   
			AND b.sporttype = b.sporttype
			AND b.bettype = b.bettype
			AND roleid = 2;
	END

	UPDATE r
	SET r.winloss = d.winloss,
		r.turnover = d.turnover
	FROM #Result r
		JOIN (
			SELECT	CONVERT(VARCHAR(7), winlossdate, 120) AS winlossdate,
					SUM(turnover) AS turnover,
					SUM(winloss) AS winloss			
			FROM #AgencyWinloss
			GROUP BY CONVERT(VARCHAR(7), winlossdate, 120)
		) d ON r.winlossdate = d.winlossdate;

	SELECT	winlossdate,
			turnover,
			winloss
	FROM #Result
	ORDER BY winlossdate;

	DROP TABLE #AgencyWinloss
	DROP TABLE #TmpCondSumWL
	DROP TABLE #SportBettype

	SET NOCOUNT OFF;
END
GO