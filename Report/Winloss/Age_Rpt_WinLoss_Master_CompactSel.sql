/*<info serverAlias="DBAGE-bodb02" executers="wsv_alp,wsv_alpv" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Age_Rpt_WinLoss_Master_CompactSel]  
	@CustID 		INT, --srecommend
	@FromDate 		SMALLDATETIME,
	@ToDate 		SMALLDATETIME,
	@ProductIds		VARCHAR(MAX),
	@ProductDetails NVARCHAR(MAX) = 'All',
	@MoveBetsDay	SMALLDATETIME,
	@BalanceUpDay	SMALLDATETIME
AS  

/*  
	Created:20240219@Bobby
    Task: Alpha Winloss report - Apply CDC bettrans_compact
    DB: DBAGE/bodb_Age
	Original: Age_Rpt_WinLoss_Master
    
	Revisions:
		- 20240219@Bobby: Apply CDC bettrans_compact [RedmineID: #195357]
		- 20240125@Lewis: Show Archived User [RedmineID: #199410]
		- 20240320@Lewis: Change metadat wsv_alp,wsv_alpv [RedmineID: #201129]
	
	Param's Explanation:
	 @ProductDetails:		
			N'<ROOT>
                <ProductDetail ProductId="32" Sporttype="248" Bettype="0" LeagueGroupId="0" TicketType="0"/>
                <ProductDetail ProductId="32" Sporttype="248" Bettype="4297" LeagueGroupId="0" TicketType="0"/>
                <ProductDetail ProductId="32" Sporttype="248" Bettype="4298" LeagueGroupId="0" TicketType="0"/>
                <ProductDetail ProductId="45" Sporttype="243" Bettype="0" LeagueGroupId="0" TicketType="0"/>
                <ProductDetail ProductId="45" Sporttype="243" Bettype="3150" LeagueGroupId="0" TicketType="0"/>
                <ProductDetail ProductId="36" Sporttype="247" Bettype="0" LeagueGroupId="0" TicketType="0"/>
                <ProductDetail ProductId="36" Sporttype="247" Bettype="4599" LeagueGroupId="0" TicketType="0"/>
                <ProductDetail ProductId="36" Sporttype="247" Bettype="4600" LeagueGroupId="0" TicketType="0"/>
                <ProductDetail ProductId="21" Sporttype="211" Bettype="0" LeagueGroupId="0" TicketType="0"/>
                <ProductDetail ProductId="21" Sporttype="211" Bettype="2499" LeagueGroupId="0" TicketType="0"/>
                <ProductDetail ProductId="1" Sporttype="0" Bettype="0" LeagueGroupId="0" TicketType="0"/>
                <ProductDetail ProductId="1" Sporttype="0" Bettype="0" LeagueGroupId="0" TicketType="1"/>
                <ProductDetail ProductId="1" Sporttype="1" Bettype="0" LeagueGroupId="42" TicketType="0"/>
                <ProductDetail ProductId="1" Sporttype="1" Bettype="0" LeagueGroupId="74" TicketType="0"/>
                <ProductDetail ProductId="1" Sporttype="1" Bettype="0" LeagueGroupId="108" TicketType="0"/>
                <ProductDetail ProductId="1" Sporttype="2" Bettype="0" LeagueGroupId="42" TicketType="0"/>
                <ProductDetail ProductId="1" Sporttype="50" Bettype="0" LeagueGroupId="42" TicketType="0"/>
                <ProductDetail ProductId="1" Sporttype="1" Bettype="0" LeagueGroupId="113" TicketType="0"/>
                <ProductDetail ProductId="1" Sporttype="2" Bettype="0" LeagueGroupId="122" TicketType="0"/>
             </ROOT>'

	+ Note: Review index=IX_srecommend when modifying this SP   
*/  
 
BEGIN
	SET NOCOUNT ON;
	
	DROP TABLE IF EXISTS #GrossComm;
	DROP TABLE IF EXISTS #SAgWinLoss;
	DROP TABLE IF EXISTS #TmpCondSumWL;

	CREATE TABLE #SAgWinLoss(
		CustID		INT,
		TurnOver	MONEY,
		GrossComm	MONEY,
		MAgTotal	MONEY,
		SAgWinlost	MONEY,
		Comm		MONEY
	);

	CREATE TABLE #GrossComm (CustId INT, GrossComm MONEY)
  
	CREATE TABLE #TmpCondSumWL(
		SportType		INT,
		BetType			INT,
		LeagueGroupID	SMALLINT,
		TicketType		TINYINT
	);

	DECLARE @ExistingProductDetails TABLE (ProductId INT,Sporttype INT,Bettype INT,LeagueGroupID SMALLINT, TicketType TINYINT)
	DECLARE @isTest BIT = 0, @__ProductDetails XML;
	SELECT  @isTest = dbo.f_CheckSPVersion(@@PROCID);	

	DECLARE @SeparateSabaSport_Cutoff SMALLDATETIME 

	SELECT @SeparateSabaSport_Cutoff = CutoffDate
	FROM dbo.f_GetCutoffDate()
	WHERE TypeName = 'SabaSport'

	SELECT @ProductIds = dbo.f_AddRelatedProducts(@ProductIds);
	SELECT @__ProductDetails = CONVERT(XML, @ProductDetails)

	INSERT INTO @ExistingProductDetails(ProductId,Sporttype,Bettype,LeagueGroupID,TicketType)
	SELECT ProductId,Sporttype,Bettype,LeagueGroupID,TicketType
	FROM dbo.f_ProductDetail_ConditionSel(@ProductDetails, @__ProductDetails)

	IF (@FromDate <= @MoveBetsDay)
	BEGIN
		INSERT INTO #TmpCondSumWL(SportType, BetType, LeagueGroupID, TicketType) 
		SELECT f.SportType, f.BetType, f.LeagueGroupID, f.TicketType
		FROM dbo.f_SumWinloss_ConditionSel(@ProductIds) f
			LEFT JOIN @ExistingProductDetails e ON f.ProductID = e.ProductId 
		WHERE e.ProductId IS NULL OR (e.Bettype = f.BetType AND e.Sporttype = f.SportType AND e.TicketType = f.TicketType AND e.LeagueGroupID = f.LeagueGroupID AND e.ProductID = f.ProductId)
	END

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

	DECLARE @SportBettypeMatrix TABLE (BetType SMALLINT, RefTable TINYINT, SportType SMALLINT, 	LeagueGroupID SMALLINT, TicketType TINYINT, ProductID INT);

	INSERT INTO @SportBettypeMatrix (BetType, RefTable, SportType, LeagueGroupID, TicketType, ProductID)
	SELECT f.BetType, f.RefTable , ISNULL(e.SportType,0), ISNULL(e.LeagueGroupID,0), ISNULL(e.TicketType,0), f.ProductID
	FROM dbo.f_SportBettypeMatrixByProduct_Sel(@ProductIds, @IsTest) f
		LEFT JOIN @ExistingProductDetails e ON e.ProductId = f.ProductID
	WHERE EXISTS(SELECT 1
				 WHERE e.ProductId IS NULL 
					OR 
						(
							e.Bettype = f.BetType 
								OR (
										e.Bettype = 0  AND  (e.ProductId = 1 OR  f.BetType NOT IN (SELECT g.Bettype FROM f_GetProductDetail() g WHERE g.ProductId <> 1) )
									)
						)
				 )

	IF @ToDate >= @BalanceUpDay
	BEGIN
		IF @FromDate <= @MoveBetsDay
		BEGIN
			SET @FDate = DATEADD(DD, 1, @MoveBetsDay);
		END

		--TODO: bettrans_compact
		;WITH CTE_Master AS (
			SELECT custid
			FROM dbo.Customer WITH(NOLOCK)
			WHERE srecommend = @CID
				AND RoleId = 3
		)
		INSERT INTO #SAgWinLoss(CustID, TurnOver, GrossComm, MAgTotal, SAgWinlost, Comm)
		SELECT  b.CustID,
			SUM(TurnOver) AS TurnOver,
			SUM(GrossComm) AS GrossComm,
			SUM(mwinlost + awinlost + acomm + winlost) AS MAgTotal,
			SUM(swinlost) AS SAgWinlost,
			SUM(scomm-acomm) AS Comm
		FROM bodb_AGE.dbo.bettrans_compact b WITH(NOLOCK)
			INNER JOIN CTE_Master m ON m.custid = b.custid
			INNER JOIN @SportBettypeMatrix s ON b.bettype = s.bettype 
				AND (s.ProductID <> 1 OR (s.ProductID = 1 AND b.sporttype = s.SportType AND b.LeagueGroupID = s.LeagueGroupID AND b.TicketType = s.TicketType))
		WHERE 
			b.winlostdate BETWEEN @FDate AND @TDate
		GROUP BY b.custid;

		IF EXISTS (SELECT 1 FROM @SportBettypeMatrix WHERE RefTable = 1) -- bettransRnG
		BEGIN
			INSERT INTO #GrossComm (CustId, GrossComm)
			SELECT b.mrecommend AS CustId, SUM(b.BetStake * b.sdiscount) AS GrossComm
			FROM dbo.bettransRnG b WITH (NOLOCK)
				INNER JOIN @SportBettypeMatrix s ON b.gameId = s.Bettype AND s.RefTable = 1
			WHERE b.srecommend = @CID 
				AND b.winlostdate BETWEEN @FDate AND @TDate
				AND b.statusID IN (111, 112, 113)
			GROUP BY b.mrecommend
		END

		IF EXISTS (SELECT 1 FROM @SportBettypeMatrix WHERE RefTable = 2) -- bettransLC
		BEGIN
			INSERT INTO #GrossComm (CustId, GrossComm)
			SELECT b.mrecommend AS CustId, SUM(b.NetStake * b.sdiscount) AS GrossComm
			FROM dbo.bettransLC b WITH (NOLOCK)
				INNER JOIN @SportBettypeMatrix s ON b.gameId = s.Bettype AND s.RefTable = 2
			WHERE b.srecommend = @CID 
				AND b.winlostdate BETWEEN @FDate AND @TDate
				AND b.statusID IN (111, 112, 113)
			GROUP BY b.mrecommend
		END

		IF EXISTS (SELECT 1 FROM #GrossComm)
		BEGIN
			UPDATE t
			SET t.GrossComm = ISNULL(t.GrossComm, 0) + ISNULL(c.GrossComm, 0)
			FROM #SAgWinLoss t
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
  
		INSERT INTO #SAgWinLoss(CustID, TurnOver, GrossComm, MAgTotal, SAgWinlost, Comm)
		SELECT  CustID,
				SUM(ABS(TurnOver)) AS TurnOver,
				SUM(ISNULL(grosscomm, 0)) AS GrossComm,
				SUM(mwinlost + awinlost + acomm + winlost) AS MAgTotal,
				SUM(swinlost) AS SAgWinlost,
				ISNULL(SUM(scomm), 0) - ISNULL(SUM(acomm), 0) AS Comm
		FROM dbo.sum_winloss b WITH (NOLOCK) 
			INNER JOIN #TmpCondSumWL t ON b.sporttype = t.sporttype AND b.bettype = t.bettype  AND ISNULL(b.leagueGroupID,0) = t.LeagueGroupID AND ISNULL(b.ticketType,0) = t.TicketType
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

		-- using cte to remove predicate when seek on sum_winloss_old
		;WITH CTE_Winlostdate (winlostdate, sporttype, bettype, LeagueGroupID, TicketType) AS
		(
			SELECT @FDate AS winlostdate, SportType, BetType, LeagueGroupID, TicketType
			FROM #TmpCondSumWL
			UNION ALL
			SELECT DATEADD(DAY, 1, winlostdate), SportType, BetType, LeagueGroupID, TicketType
			FROM CTE_Winlostdate
			WHERE winlostdate < @TDate
		)		
		INSERT INTO #SAgWinLoss(CustID, TurnOver, GrossComm, MAgTotal, SAgWinlost, Comm)
		SELECT  CustID,
				SUM(ABS(TurnOver)) AS TurnOver,
				SUM(ISNULL(grosscomm,0)) AS GrossComm,
				SUM(mwinlost + awinlost + acomm + winlost) AS MAgTotal,
				SUM(swinlost) AS SAgWinlost,
				ISNULL(SUM(scomm), 0) - ISNULL(SUM(acomm), 0) AS Comm
		FROM bodb_Summary.dbo.Sum_WinLoss_Old b WITH(NOLOCK) 
			CROSS APPLY CTE_Winlostdate w
		WHERE b.winlostdate = w.winlostdate 
			AND SRecommend = @CustID  
			AND mrecommend = mrecommend
			AND recommend = recommend
			AND RoleID = 3  
			AND b.sporttype = w.sporttype
			AND b.bettype = w.bettype
			AND ISNULL(b.leagueGroupID,0) = w.LeagueGroupID
			AND ISNULL(b.ticketType,0) = w.TicketType
		GROUP BY CustID
		OPTION (MAXRECURSION 0)
	END  
  
	SELECT	c.CustID AS CustId,
			c.UserName AS CustName,
			c.FirstName,
			c.LastName,
			SUM(TurnOver) AS Turnover,
			SUM(GrossComm) AS GrossComm,
			SUM(MAgTotal) AS MAgTotal,
			SUM(SAgWinlost) AS SAgWinLoss,
			SUM(Comm) AS SAgComm  
	FROM #SAgWinLoss w 
		LEFT JOIN Customer c WITH(NOLOCK) ON w.CustID = c.CustID   
	GROUP BY c.CustID, c.UserName, c.FirstName, c.LastName
	ORDER BY IIF(c.Username IS NULL,1,0),c.Username;
	SET NOCOUNT OFF;
END
GO