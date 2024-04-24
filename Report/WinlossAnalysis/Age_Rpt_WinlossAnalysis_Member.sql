/*<info serverAlias="DBAGE-bodb02" executers="wsv_alp,wsv_alpv" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Age_Rpt_WinlossAnalysis_Member]
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
    
	Revisions:
        - 20170306@Paul: Create new [Redmine: #71891]
		- 20170622@Percy: Combine Betradar Virtual Sports with Virtual Sports [RedmineID: #78339]
		- 20180518@Sophia: WC2018 - Enhance Performance at Sum_winloss_old table [Redmind: #91107]
		- 20190826@Percy: Remove inactive products [RedmineID: #118699]
		- 20220420@Danny: Separate Saba Sport Performance [Redmine: #167177]
		- 20240424@Lewis: Change old sql account [Redmine: #204021]
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
	SELECT	DISTINCT ISNULL(p.GroupProductId, s.ProductID),
			SportType,
			BetType
	FROM dbo.f_SumWinloss_ConditionSel(@ProductIds) s
		LEFT JOIN dbo.f_GroupProduct() p ON s.ProductID = p.ProductId;	
	
	------Get @Srecommend
	DECLARE @Srecommend int,
			@mrecommend int;

	SELECT @Srecommend = Srecommend,
			@Mrecommend = Mrecommend
	FROM dbo.CustInfo WITH (NOLOCK)
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

		INSERT INTO #AgencyWinloss(WinlossDate, ProductId, Turnover, MemberWinloss, MemberComm, AgWinloss, AgComm, BetCount)
		SELECT	winlostdate,
				s.ProductID,
				SUM(ABS(b.stake)), 
				SUM(winlost - actual_stake) AS MemberWinloss,
				SUM(playercomm) AS MemberComm,
				SUM(awinlost) AS AgWinloss,
				SUM(comm) AS AgComm,
				COUNT(1) AS BetCount
		FROM bettrans b WITH(NOLOCK)
			INNER JOIN #SportBettype s ON b.bettype = s.bettype
		WHERE winlostdate BETWEEN @FDate AND @TDate
			AND recommend = @CID 
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
		
		INSERT INTO #AgencyWinloss(WinlossDate, ProductId, Turnover, MemberWinloss, MemberComm, AgWinloss, AgComm, BetCount)
		SELECT	winlostdate,
				t.ProductID,
				ABS(turnover),
				winlost,
				playercomm,
				awinlost,
				comm,
				betcount
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
		IF @ToDate >= DATEADD(dd, -1, @BalanceUpDay)
		BEGIN
			SELECT @TDate = DATEADD(dd, -1, @BalanceUpDay);
		END

			
		-- using cte to remove predicate when seek on sum_winloss_old
		;WITH CTE_Winlostdate (winlostdate, sporttype, bettype, productId) AS
		(
			SELECT @FDate AS winlostdate, SportType, BetType, productId
			FROM #TmpCondSumWL
			UNION ALL
			SELECT DATEADD(DAY, 1, winlostdate), SportType, BetType, productId
			FROM CTE_Winlostdate
			WHERE winlostdate < @TDate
		)
		INSERT INTO #AgencyWinloss(WinlossDate, ProductId, Turnover, MemberWinloss, MemberComm, AgWinloss, AgComm, BetCount)
		SELECT	b.winlostdate,
				w.ProductID,
				ABS(turnover),
				winlost,
				playercomm,
				awinlost,
				comm,
				betcount
		FROM bodb_Summary.dbo.Sum_WinLoss_Old b WITH(NOLOCK) --- Remove link server DBSUM 
			CROSS APPLY CTE_Winlostdate w
		WHERE b.winlostdate = w.winlostdate
			AND Srecommend = @Srecommend    --- Add Srecommend, Mrecommend to get the index seek 
			AND Mrecommend = @Mrecommend
			AND recommend = @CustID
			AND roleid = 2
			AND b.sporttype = w.sporttype
			AND b.bettype = w.bettype
		OPTION (MAXRECURSION 0);
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
			SUM(AgComm - MemberComm) AS AgComm,
			SUM(betcount) AS betcount
	FROM #AgencyWinloss
	GROUP BY CASE WHEN @ReportType = 1 THEN CONVERT(VARCHAR(10), WinlossDate, 101)  
				 WHEN @ReportType = 2 THEN RIGHT(CONVERT(VARCHAR(10), WinlossDate, 103), 7)  
				 WHEN @ReportType = 3 THEN CONVERT(VARCHAR(10), ProductId)
				 ELSE '0' 
			END;

	SET NOCOUNT OFF;
END
GO