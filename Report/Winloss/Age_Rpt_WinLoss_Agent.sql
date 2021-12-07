/*<info serverAlias="DBAGE-bodb02" executers="bodbDownlineNet,bodbDownlineNetView" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Age_Rpt_WinLoss_Agent]
	@CustID 		INT, --mrecommend
	@FromDate 		SMALLDATETIME,
	@ToDate 		SMALLDATETIME,
	@ProductIds		VARCHAR(MAX),
	@ProductDetails NVARCHAR(MAX) = 'All',
	@MoveBetsDay	SMALLDATETIME,
	@BalanceUpDay	SMALLDATETIME	
AS

/*
    Created: 
    Task : 
    DB: DBAGE/bodb02
    
	Revisions:
        - 20161111@Paul: Microsite for Report - [Redmine: #66991]
		- 20170622@Percy: Combine Betradar Virtual Sports with Virtual Sports [RedmineID: #78339]
		- 20180518@Sophia: WC2018 - Enhance Performance at Sum_winloss_old table [Redmind: #91107]
		- 20180914@Percy: Poker Games - Modify GrossComm [RedmineID: #101550]
		- 20181003@Helen: Modify code to adapt indexes changed on DB053 [Redmine:101405]
		- 20190826@Percy: Remove inactive products [RedmineID: #118699]
		- 20200909@Malcolm : Report Enhancement for Jackpot Product [RedmineID : #139575]
		- 20211122@Percy: Enhance gross comm formula [RedmineID: #164479]
	
	Param's Explanation:
	 @ProductDetails:		
		<ROOT>
				<ProductDetail ProductId = "32" Sporttype = "248" Bettype = "0"/>
				<ProductDetail ProductId = "32" Sporttype = "248" Bettype = "4298"/>
		</ROOT>
*/

BEGIN
	SET NOCOUNT ON;

	CREATE TABLE #MAgWinLoss(
		CustID		INT,
		TurnOver	MONEY,
		GrossComm	MONEY,
		AgTotal		MONEY,
		MAgWinlost	MONEY,
		Comm		MONEY
	);

	CREATE TABLE #GrossComm (CustId INT, GrossComm MONEY)

	CREATE TABLE #TmpCondSumWL(
		SportType	INT,
		BetType		INT
	);
	DECLARE @ExistingProductDetails TABLE (ProductId INT,Sporttype INT,Bettype INT)
	DECLARE @isTest BIT = 0, @__ProductDetails XML;
	SELECT  @isTest = dbo.f_CheckSPVersion(@@PROCID);

	SELECT @ProductIds = dbo.f_AddRelatedProducts(@ProductIds);

	IF ISNULL(@ProductDetails,'') = ''
	BEGIN 
		INSERT INTO @ExistingProductDetails
		(
			ProductId
			,Sporttype
			,Bettype
		)
		VALUES(NULL, NULL, NULL)
	END
	ELSE IF ISNULL(@ProductDetails,'')  = 'All'
	BEGIN
		INSERT INTO @ExistingProductDetails
		(
			ProductId
			,Sporttype
			,Bettype
		)
		SELECT 
			ProductId
			,Sporttype
			,Bettype
		FROM dbo.f_GetProductDetail() f
	END
	ELSE 		
	BEGIN	
		SELECT @__ProductDetails = CONVERT(XML, @ProductDetails)

		INSERT INTO @ExistingProductDetails
		(
			ProductId
			,Sporttype
			,Bettype
		)
		SELECT 
			t.c.value('(@ProductId)[1]', 'SMALLINT') AS ProductID
			, t.c.value('(@Sporttype)[1]', 'SMALLINT') AS Sporttype
			, t.c.value('(@Bettype)[1]', 'SMALLINT') AS Bettype
		FROM @__ProductDetails.nodes('ROOT/ProductDetail') t(c)
	END

	INSERT INTO #TmpCondSumWL(SportType, BetType) 
	SELECT f.SportType, f.BetType
	FROM dbo.f_SumWinloss_ConditionSel(@ProductIds) f
		LEFT JOIN @ExistingProductDetails e ON f.ProductID = e.ProductId
	WHERE e.ProductId IS NULL OR (e.Bettype = f.BetType)

	------Get @Srecommend
	DECLARE @Srecommend int;
	 
	SELECT @Srecommend = Srecommend
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

	--Avoid Parameter Sniffing for bettrans and sum_winloss
	DECLARE @FDate	SMALLDATETIME,
			@TDate	SMALLDATETIME,
			@CID	INT    	  
			  
	SELECT	@FDate = @FromDate,
			@TDate = @ToDate,
			@CID = @custid;

	DECLARE @SportBettypeMatrix TABLE (BetType SMALLINT, RefTable TINYINT);

	INSERT INTO @SportBettypeMatrix (BetType, RefTable)
	SELECT f.BetType, f.RefTable FROM dbo.f_SportBettypeMatrixByProduct_Sel(@ProductIds, @IsTest) f
		LEFT JOIN @ExistingProductDetails e ON e.ProductId = f.ProductID
	WHERE EXISTS(SELECT 1
				 WHERE e.ProductId IS NULL 
					OR 
						(
							e.Bettype = f.BetType 
							OR (e.Bettype = 0 AND f.BetType NOT IN (SELECT g.Bettype FROM f_GetProductDetail() g))
						)
				 )

	IF @ToDate >= @BalanceUpDay
	BEGIN
		IF @FromDate <= @MoveBetsDay
		BEGIN
			SET @FDate = DATEADD(DD, 1, @MoveBetsDay);
		END

		INSERT INTO #MAgWinLoss(CustID, TurnOver, GrossComm, AgTotal, MAgWinlost, Comm)
		SELECT	recommend AS CustID,
				SUM(ABS(b.stake)) AS TurnOver,
				SUM(CASE
						WHEN s.RefTable IN (1, 2) THEN 0
						WHEN apositiontaking + mpositiontaking = 1 THEN 0
						ELSE acomm/(1-apositiontaking - mpositiontaking)
					END) AS GrossComm,
				ISNULL(SUM(winlost - actual_stake), 0) + ISNULL(SUM(awinlost), 0) + ISNULL(SUM(comm), 0) AS AgTotal,
				SUM(mwinlost) AS MAgWinlost,
				ISNULL(SUM(acomm), 0) - ISNULL(SUM(comm), 0) AS Comm
		FROM dbo.bettrans b WITH (NOLOCK)
			INNER JOIN @SportBettypeMatrix s ON b.bettype = s.Bettype
		WHERE mrecommend = @CID 
			AND winlostdate BETWEEN @FDate AND @TDate
			AND b.statusID IN (111, 112, 113)
		GROUP BY recommend;

		IF EXISTS (SELECT 1 FROM @SportBettypeMatrix WHERE RefTable = 1) -- bettransRnG
		BEGIN
			INSERT INTO #GrossComm (CustId, GrossComm)
			SELECT b.recommend AS CustId, SUM(b.BetStake * b.adiscount) AS GrossComm
			FROM dbo.bettransRnG b WITH (NOLOCK)
				INNER JOIN @SportBettypeMatrix s ON b.gameId = s.Bettype AND s.RefTable = 1
			WHERE b.mrecommend = @CID 
				AND b.winlostdate BETWEEN @FDate AND @TDate
				AND b.statusID IN (111, 112, 113)
			GROUP BY b.recommend
		END

		IF EXISTS (SELECT 1 FROM @SportBettypeMatrix WHERE RefTable = 2) -- bettransLC
		BEGIN
			INSERT INTO #GrossComm (CustId, GrossComm)
			SELECT b.recommend AS CustId, SUM(b.NetStake * b.adiscount) AS GrossComm
			FROM dbo.bettransLC b WITH (NOLOCK)
				INNER JOIN @SportBettypeMatrix s ON b.gameId = s.Bettype AND s.RefTable = 2
			WHERE b.mrecommend = @CID 
				AND b.winlostdate BETWEEN @FDate AND @TDate
				AND b.statusID IN (111, 112, 113)
			GROUP BY b.recommend
		END

		IF EXISTS (SELECT 1 FROM #GrossComm)
		BEGIN
			UPDATE t
			SET t.GrossComm = ISNULL(t.GrossComm, 0) + ISNULL(c.GrossComm, 0)
			FROM #MAgWinLoss t
				INNER JOIN (
					SELECT CustId, SUM(GrossComm) AS GrossComm FROM #GrossComm GROUP BY CustId
				) c ON t.CustId = c.CustId
		END
		
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
		
		INSERT INTO #MAgWinLoss(CustID, TurnOver, GrossComm, AgTotal, MAgWinlost, Comm)
		SELECT	CustID,
				SUM(ABS(TurnOver)) AS TurnOver,
				SUM(grosscomm) AS GrossComm,
				ISNULL(SUM(winlost),0) + ISNULL(SUM(awinlost), 0) + ISNULL(SUM(comm), 0) AS AgTotal,
				SUM(mwinlost) AS MAgWinlost,
				ISNULL(SUM(acomm), 0) - ISNULL(SUM(comm), 0) AS Comm
		FROM  dbo.sum_winloss b WITH (NOLOCK) 
			INNER JOIN #TmpCondSumWL t ON b.sporttype = t.sporttype AND b.bettype = t.bettype
		WHERE winlostdate BETWEEN @FDate AND @TDate
			AND mrecommend = @CID
			AND roleid = 2
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
				

		-- using cte to remove predicate when seek on sum_winloss_old
		;WITH CTE_Winlostdate (winlostdate, sporttype, bettype) AS
		(
			SELECT @FDate AS winlostdate, SportType, BetType
			FROM #TmpCondSumWL
			UNION ALL
			SELECT DATEADD(DAY, 1, winlostdate), SportType, BetType
			FROM CTE_Winlostdate
			WHERE winlostdate < @TDate
		)		
		INSERT INTO #MAgWinLoss(CustID, TurnOver, GrossComm, AgTotal, MAgWinlost, Comm)
		SELECT	CustID,
				SUM(ABS(TurnOver)) AS TurnOver,
				SUM(grosscomm) AS GrossComm,
				ISNULL(SUM(winlost), 0) + ISNULL(SUM(awinlost), 0) + ISNULL(SUM(comm), 0) AS AgTotal,
				SUM(mwinlost) AS MAgWinlost,
				ISNULL(SUM(acomm), 0) - ISNULL(SUM(comm), 0) AS Comm
		FROM bodb_Summary.dbo.Sum_WinLoss_Old b WITH(NOLOCK) 
			CROSS APPLY CTE_Winlostdate w
		WHERE b.Winlostdate = w.winlostdate
			AND Srecommend = @Srecommend   --- Add Srecommend, recommend to get the index seek 
			AND MRecommend = @CustID
			AND recommend = recommend
			AND RoleID = 2 
			AND b.sporttype = w.sporttype
			AND b.bettype = w.bettype		
		GROUP BY CustID
		OPTION (MAXRECURSION 0)
	END

	SELECT	w.CustID AS CustId,
			c.UserName AS CustName,
			SUM(TurnOver) AS Turnover,
			SUM(GrossComm) AS GrossComm,
			SUM(AgTotal) AS AgTotal,
			SUM(MAgWinlost) AS MAgWinLoss,
			SUM(Comm) AS MAgComm
	FROM  #MAgWinLoss w 
		INNER JOIN Customer c WITH(NOLOCK) ON w.CustID = c.CustID 
	GROUP BY w.CustID, c.UserName
	ORDER BY c.Username;

	DROP TABLE #GrossComm
	DROP TABLE #MAgWinLoss
	DROP TABLE #TmpCondSumWL

	SET NOCOUNT OFF;
END
GO