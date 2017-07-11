USE [bodb02]
GO

ALTER PROCEDURE [dbo].[Age_Rpt_WinlossAnalysis_Agent]
	@CustID			INT, 
	@FromDate		SMALLDATETIME,  
	@ToDate			SMALLDATETIME,    
	@ProductIds		VARCHAR(MAX),
	@ReportType		TINYINT = 1,  
	@BalanceUpDay	SMALLDATETIME,
	@MoveBetsDay	SMALLDATETIME
AS  

/*
    Created: 
    Task : 
    DB: DBAGE/bodb02
    Original SP: Age_Rpt_WinlossAnalysis_MAg
				Change SP name suffix to match with web function
    Revisions:
        - 20170306@Paul: Create new [Redmine: #71891]
		- 20170622@Percy: Combine Betradar Virtual Sports with Virtual Sports [RedmineID: #78339]

*/

BEGIN
	SET NOCOUNT ON;
	
	CREATE TABLE #AgencyWinloss
	(
		WinlossDate		SMALLDATETIME,							
		ProductId		INT,
		Turnover		MONEY,
		MemberWinloss	MONEY,
		MemberComm		MONEY,
		AgWinloss		MONEY,
		AgComm			MONEY,
		MAgWinloss		MONEY,
		MAgComm			MONEY,
		BetCount		INT
	);

	CREATE TABLE #SportBettype (ProductID INT, Bettype INT);

	CREATE TABLE #TmpCondSumWL (ProductID INT, sporttype INT, bettype INT);
	
	DECLARE @isTest BIT = 0;
	SELECT  @isTest = dbo.f_CheckSPVersion(@@PROCID);

	SELECT @ProductIds = dbo.f_AddRelatedProducts(@ProductIds);

	INSERT INTO #SportBettype (ProductID, Bettype)
	SELECT ISNULL(p.GroupProductId, s.ProductID), Bettype
	FROM dbo.f_SportBettypeMatrixByProduct_Sel(@ProductIds, @isTest) s
		LEFT JOIN dbo.f_GroupProduct() p ON s.ProductID = p.ProductId;

	INSERT INTO #TmpCondSumWL(ProductID, sporttype, bettype)
	SELECT	ISNULL(p.GroupProductId, s.ProductID),
			SportType,
			BetType
	FROM dbo.f_SumWinloss_ConditionSel(@ProductIds) s
		LEFT JOIN dbo.f_GroupProduct() p ON s.ProductID = p.ProductId;
	
	------Get @Srecommend
	DECLARE @Srecommend int;

	SELECT @Srecommend =  Srecommend
	FROM dbo.CustInfo WITH(NOLOCK) 
	WHERE CustID = @CustID;

	-----Get Special Super to hide data of them before specific date 
	DECLARE @IsHide BIT = 0;
	
	IF EXISTS (SELECT 1 FROM dbo.f_SpecialSuper() WHERE Srecommend = @custid)
	BEGIN
		SELECT @IsHide = 1;
	END
		
	----Get Account Login to detect Interal or not
	DECLARE @LoginName NVARCHAR(128);
	SELECT @LoginName = SUSER_NAME();
	
	--Avoid Parameter Sniffing for bettrans and sum_winloss
	DECLARE @FDate		SMALLDATETIME,
			@TDate		SMALLDATETIME,
			@CID		INT;
	    
	SELECT @FDate = @FromDate, @TDate = @ToDate, @CID = @custid;
		
	IF @ToDate >= @BalanceUpDay
	BEGIN
		IF @FromDate <= @MoveBetsDay
		BEGIN
			SET @FDate = DATEADD(DD, 1, @MoveBetsDay);
		END

		INSERT INTO #AgencyWinloss(WinlossDate, ProductId, Turnover, MemberWinloss, MemberComm, AgWinloss, AgComm, MAgWinloss, MAgComm, BetCount)
		SELECT	winlostdate, 
				s.ProductID,
				SUM(CASE WHEN b.liveawayscore = 0 AND b.bettype IN (33,43) THEN ABS(b.stake)/2 ELSE ABS(b.stake) END) AS Turnover,
				SUM(winlost-actual_stake) AS MemberWinloss,
				SUM(playercomm) AS MemberComm,
				SUM(awinlost) AS AgWinloss,
				SUM(comm) AS AgComm,
				SUM(mwinlost) AS MAgWinloss,
				SUM(acomm) AS MAgComm,
				COUNT(CASE WHEN b.bettype = 500 THEN NULL ELSE transid END)  AS BetCount			
		FROM bettrans b WITH(NOLOCK) 
			INNER JOIN #SportBettype s ON b.bettype = s.bettype
		WHERE winlostdate BETWEEN @FDate AND @TDate
			AND mrecommend = @CID 
			AND StatusID NOT IN (0,1,101,102,103)			
		GROUP BY winlostdate, s.ProductID;

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
		
		INSERT INTO #AgencyWinloss(WinlossDate, ProductId, Turnover, MemberWinloss, MemberComm, AgWinloss, AgComm, MAgWinloss, MAgComm, BetCount)
		SELECT	winlostdate,
				t.ProductID,
				ABS(turnover),
				winlost,
				playercomm,
				awinlost,
				comm,
				mwinlost,
				acomm,
				betcount
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
			
		INSERT INTO #AgencyWinloss(WinlossDate, ProductId, Turnover, MemberWinloss, MemberComm, AgWinloss, AgComm, MAgWinloss, MAgComm, BetCount)
		SELECT	winlostdate, 
				t.ProductID,
				ABS(turnover),
				winlost,
				playercomm,
				awinlost,
				comm,
				mwinlost,
				acomm,
				betcount
		FROM bodb_Summary.dbo.Sum_WinLoss_Old b WITH(NOLOCK)
			INNER JOIN #TmpCondSumWL t ON b.sporttype = t.sporttype AND b.bettype = t.bettype  
		WHERE winlostdate BETWEEN @FDate AND @TDate
			AND Srecommend = @Srecommend    --- Add Srecommend to get the index seek 
			AND mrecommend = @CustID
			AND recommend = recommend
			AND roleid = 3;
	END

	SELECT	CASE WHEN @ReportType = 1 THEN CONVERT(VARCHAR(10), WinlossDate, 101)  
				 WHEN @ReportType = 2 THEN RIGHT(CONVERT(VARCHAR(10), WinlossDate, 103), 7)  
				 WHEN @ReportType = 3 THEN CONVERT(VARCHAR(10), ProductId)
				 ELSE '0' 
			END AS RollupKey,
			SUM(Turnover) AS Turnover,
			SUM(MemberWinloss) AS MemberWinloss,
			SUM(MemberComm) AS MemberComm,
			SUM(AgWinloss) AS AgWinloss,
			SUM(AgComm - MemberComm)	AS AgComm,
			SUM(MAgWinloss) AS MAgWinloss,
			SUM(MAgComm - AgComm) AS MAgComm,
			SUM(BetCount) AS BetCount
	FROM #AgencyWinloss
	GROUP BY CASE WHEN @ReportType = 1 THEN CONVERT(VARCHAR(10), WinlossDate, 101)  
				 WHEN @ReportType = 2 THEN RIGHT(CONVERT(VARCHAR(10), WinlossDate, 103), 7)  
				 WHEN @ReportType = 3 THEN CONVERT(VARCHAR(10), ProductId)
				 ELSE '0' 
			END;

	SET NOCOUNT OFF;
END
GO

GRANT EXECUTE ON [dbo].[Age_Rpt_WinlossAnalysis_Agent] TO [bodbDownlineNet] AS [dbo]
GO

GRANT EXECUTE ON [dbo].[Age_Rpt_WinlossAnalysis_Agent] TO [bodbDownlineNetView] AS [dbo]
GO

GRANT VIEW DEFINITION ON [dbo].[Age_Rpt_WinlossAnalysis_Agent] TO [vnteam] AS [dbo]
GO