/*<info serverAlias="DBAGE-bodb02" executers="wsv_alp,wsv_alpv" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Age_Rpt_WinLoss_Agent]
	@CustID 		INT, --mrecommend
	@FromDate 		SMALLDATETIME,
	@ToDate 		SMALLDATETIME,
	@ProductIds		VARCHAR(MAX),
	@ProductDetails NVARCHAR(MAX) = 'All',
	@MoveBetsDay	SMALLDATETIME,
	@BalanceUpDay	SMALLDATETIME,
	@LevelType		TINYINT = 0,
	@DownlineID		INT = NULL -- for chatbot
AS

/*
    Created:20240219@Bobby
    Task: Alpha Winloss report - Apply CDC bettrans_compact
    DB: DBAGE/bodb_Age
	Original: Age_Rpt_WinLoss_Agent
    
	Revisions:
		- 20161111@Paul: Microsite for Report - [Redmine: #66991]
		- 20170622@Percy: Combine Betradar Virtual Sports with Virtual Sports [RedmineID: #78339]
		- 20180518@Sophia: WC2018 - Enhance Performance at Sum_winloss_old table [Redmind: #91107]
		- 20180914@Percy: Poker Games - Modify GrossComm [RedmineID: #101550]
		- 20181003@Helen: Modify code to adapt indexes changed on DB053 [Redmine:101405]
		- 20190826@Percy: Remove inactive products [RedmineID: #118699]
		- 20200909@Malcolm : Report Enhancement for Jackpot Product [RedmineID : #139575]
		- 20211122@Percy: Enhance gross comm formula [RedmineID: #164479]
		- 20220208@Danny: Separate Saba Sport Performance [Redmine: #167177]
		- 20221207@Eddie: Add New SABA ESports PinGoal [RedmineID: #181383]
		- 20230104@Bobby: Enhance GrossComm figure [RedmineID: #182155]
		- 20230328@Malcolm: Add firstname, lastname [RedmineId: #185313]   
		- 20230630@Lewis: Add Saba Tennis [RedmineID: #190459]
		- 20240125@Lewis: Show Archived User [RedmineID: #199410]
		- 20240320@Lewis: Change metadat wsv_alp,wsv_alpv [RedmineID: #201129]
		- 20240306@Lewis: Add Virtual Ice Hockey [RedmineID: #201129]
		- 20240515@Lewis: Add SABA Kabaddi [RedmineID: #203763]
		- 20240424@Lewis: Change old sql account [Redmine: #204021]
		- 20241205@Lewis: Change data source bettrans_compact [Redmine: #214836]
		- 20241119@Lewis: Direct Member [RedmineId: #211969]   
		- 20250529@Dave: Add Reward column [RedmineId: #228972]
		- 20250619@Virgil: Agency Cash Service - Billing service and Report changes - Sprint 4 [RedmineId: #229883]  
	
	Param's Explanation:
		- @ProductDetails:		
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

		- @LevelType:	0: All; 1: Master Agent/ Agent; 2: Direct Member
*/

BEGIN
	SET NOCOUNT ON;

	DROP TABLE IF EXISTS #GrossComm;
	DROP TABLE IF EXISTS #MAgWinLoss;
	DROP TABLE IF EXISTS #TmpCondSumWL;

	CREATE TABLE #MAgWinLoss(
		CustID			INT,
		TurnOver		MONEY,
		GrossComm		MONEY,
		DownlineTotal	MONEY,
		MAgWinlost		MONEY,
		Comm			MONEY,
		RewardAmount	MONEY DEFAULT 0
	);

	CREATE TABLE #GrossComm (CustId INT, GrossComm MONEY)

	CREATE TABLE #TmpCondSumWL(
		SportType		SMALLINT,
		BetType			INT,
		LeagueGroupID	SMALLINT,
		TicketType		TINYINT
	);
	
	DECLARE @ExistingProductDetails TABLE (ProductId INT,Sporttype SMALLINT, Bettype INT,LeagueGroupID SMALLINT, TicketType TINYINT)
	DECLARE @isTest BIT = 0, @__ProductDetails XML;
	SELECT  @isTest = dbo.f_CheckSPVersion(@@PROCID);

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

	------Get @Srecommend
	DECLARE @Srecommend int;
	DECLARE @CurrencyCode VARCHAR(12);
	 
	SELECT @Srecommend = c.Srecommend,
			@CurrencyCode = e.Code
	FROM dbo.CustInfo c WITH (NOLOCK)
	INNER JOIN dbo.Exchange e WITH (NOLOCK)
		ON c.currency = e.ExchangeId
	WHERE c.CustID = @CustID;

	--Avoid Parameter Sniffing for bettrans and sum_winloss
	DECLARE @FDate	SMALLDATETIME,
			@TDate	SMALLDATETIME,
			@CID	INT    	  
			  
	SELECT  @CID = @custid;

	DECLARE @SportBettypeMatrix TABLE (BetType SMALLINT, RefTable TINYINT, SportType SMALLINT, LeagueGroupID SMALLINT, ticketType TINYINT, ProductID INT);

	INSERT INTO @SportBettypeMatrix (BetType, RefTable, LeagueGroupID, ticketType, SportType, ProductID)
	SELECT f.BetType, f.RefTable, ISNULL(e.LeagueGroupID,0) AS LeagueGroupID, ISNULL(e.TicketType,0) AS TicketType, ISNULL(SportType,0) AS SportType, f.ProductID
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

	--DownlineList
	DECLARE @totalDownline INT, @downlineIds VARCHAR(MAX)
	IF @DownlineID IS NULL
	BEGIN
		;WITH cte_downline AS(
			SELECT ci.custid
			FROM dbo.custinfo ci WITH(NOLOCK)
			WHERE mrecommend = @CID
				AND ci.RoleId = 2
				AND @LevelType IN (0,1)

			UNION ALL

			SELECT ci.custid
			FROM dbo.custinfo ci WITH(NOLOCK)
			WHERE mrecommend = @CID
				AND ci.RoleId = 1
				AND recommend = -3
				AND @LevelType IN (0,2)
		)
		SELECT 
			@totalDownline	= COUNT(1), 
			@downlineIds	= STRING_AGG(CAST(cte.custid AS VARCHAR(MAX)), ',')
		FROM cte_downline cte
	END
	ELSE
	BEGIN
		SELECT 
			@totalDownline	= COUNT(1), 
			@downlineIds	= STRING_AGG(CAST(c.custid AS VARCHAR(MAX)), ',')
		FROM Customer c WITH(NOLOCK)
		WHERE c.custid = @DownlineID
	END

	--TODO: range bettrans
	SELECT @FDate = FromDate , @TDate = ToDate
	FROM dbo.f_MBU_RangeDate(@FromDate, @ToDate, @BalanceUpDay, @MoveBetsDay)
	WHERE RangeType = 1

	IF @FDate IS NOT NULL
	BEGIN
		--TODO: bettrans_compact
		;WITH CTE_Downline AS (
			SELECT TOP(@totalDownline) CAST([value] AS INT) AS custid
			FROM STRING_SPLIT(@downlineIds, ',') AS c
		)
		INSERT INTO #MAgWinLoss(CustID, TurnOver, GrossComm, DownlineTotal, MAgWinlost, Comm)
		SELECT	b.CustID,
			SUM(TurnOver) AS TurnOver,
			SUM(GrossComm) AS GrossComm,
			SUM(winlost+ awinlost+ comm) AS DownlineTotal,
			SUM(mwinlost) AS MAgWinlost,
			SUM(acomm-comm) AS Comm
		FROM bodb_AGE.dbo.bettrans_compact b WITH(NOLOCK)
			INNER JOIN CTE_Downline m ON m.custid = b.custid
			INNER JOIN @SportBettypeMatrix s ON b.bettype = s.bettype 
				AND (s.ProductID <> 1 OR (s.ProductID = 1 AND b.sporttype = s.SportType AND b.LeagueGroupID = s.LeagueGroupID AND b.TicketType = s.TicketType))
		WHERE 
			b.winlostdate BETWEEN @FDate AND @TDate
		GROUP BY b.custid;

		-- Cash Service Billing 
		IF ',' + @ProductIDs + ',' LIKE '%,111,%'
		BEGIN
			;WITH CTE_Downline AS (
				SELECT TOP(@totalDownline) CAST([value] AS INT) AS custid
				FROM STRING_SPLIT(@downlineIds, ',') AS c
			)
			INSERT INTO #MAgWinLoss(CustID, TurnOver, GrossComm, DownlineTotal, MAgWinlost, Comm)
			SELECT tr.CustID,
					0 AS TurnOver,
					0 AS GrossComm,
					SUM(WinLost-Actual_Stake) AS DownlineTotal,
					0 AS MAgWinlost,
					0 AS Comm
			FROM dbo.Transfer tr (NOLOCK)
			INNER JOIN CTE_Downline m ON m.custid = tr.custid
			INNER JOIN (	
						SELECT DISTINCT ma.ProductID, ma.BetType
						FROM  dbo.SportBettypeMatrix ma WITH(NOLOCK)
						WHERE ma.ProductID = 111
							AND (ma.IsTest = 0 OR ma.IsTest = @IsTest)
							AND ma.RefTable = 4
							AND ma.BetType IN (31003,31004,31005)
						) f ON tr.Bettype = f.BetType
			WHERE tr.winlostdate BETWEEN @FDate AND @TDate
			GROUP BY tr.CustId;
		END

		 -- bettransRnG
		IF EXISTS (SELECT 1 FROM @SportBettypeMatrix WHERE RefTable = 1)
		BEGIN
			INSERT INTO #GrossComm (CustId, GrossComm)
			SELECT CASE WHEN b.recommend = -3 THEN b.custid ELSE b.recommend END AS CustId, SUM(b.BetStake * b.adiscount) AS GrossComm
			FROM dbo.bettransRnG b WITH (NOLOCK)
				INNER JOIN @SportBettypeMatrix s ON b.gameId = s.Bettype AND s.RefTable = 1
			WHERE b.mrecommend = @CID 
				AND b.winlostdate BETWEEN @FDate AND @TDate
				AND b.statusID IN (111, 112, 113)
			GROUP BY CASE WHEN b.recommend = -3 THEN b.custid ELSE b.recommend END
		END

		-- bettransLC
		IF EXISTS (SELECT 1 FROM @SportBettypeMatrix WHERE RefTable = 2)
		BEGIN
			INSERT INTO #GrossComm (CustId, GrossComm)
			SELECT CASE WHEN b.recommend = -3 THEN b.custid ELSE b.recommend END AS CustId, SUM(b.NetStake * b.adiscount) AS GrossComm
			FROM dbo.bettransLC b WITH (NOLOCK)
				INNER JOIN @SportBettypeMatrix s ON b.gameId = s.Bettype AND s.RefTable = 2
			WHERE b.mrecommend = @CID 
				AND b.winlostdate BETWEEN @FDate AND @TDate
				AND b.statusID IN (111, 112, 113)
			GROUP BY CASE WHEN b.recommend = -3 THEN b.custid ELSE b.recommend END
		END

		-- update grosscomm
		IF EXISTS (SELECT 1 FROM #GrossComm)
		BEGIN
			UPDATE t
			SET t.GrossComm = ISNULL(t.GrossComm, 0) + ISNULL(c.GrossComm, 0)
			FROM #MAgWinLoss t
				INNER JOIN (
					SELECT CustId, SUM(GrossComm) AS GrossComm FROM #GrossComm GROUP BY CustId
				) c ON t.CustId = c.CustId
		END
	END	

	--TODO: range 14
	SELECT @FDate = NULL, @TDate = NULL
	SELECT @FDate = FromDate , @TDate = ToDate
	FROM dbo.f_MBU_RangeDate(@FromDate, @ToDate, @BalanceUpDay, @MoveBetsDay)
	WHERE RangeType = 2

	IF @FDate IS NOT NULL
	BEGIN
		;WITH CTE_Winlostdate (winlostdate) AS
		(
			SELECT @FDate AS winlostdate
			UNION ALL
			SELECT DATEADD(DAY, 1, winlostdate)
			FROM CTE_Winlostdate
			WHERE winlostdate < @TDate
		), CTE_Downline AS (
			SELECT TOP (@totalDownline * (DATEDIFF(DAY,@FDate,@TDate) + 1))
				ci.custid AS custid
				,ci.srecommend
				,ci.mrecommend
				,ci.recommend
				,ci.roleid
				,w.winlostdate
			FROM STRING_SPLIT(@downlineIds, ',') AS c
			INNER JOIN custInfo ci WITH (NOLOCK) ON CAST(c.[value] AS INT) = ci.custid
			CROSS APPLY CTE_Winlostdate w
		)
		INSERT INTO #MAgWinLoss(CustID, TurnOver, GrossComm, DownlineTotal, MAgWinlost, Comm)
		SELECT	b.CustID,
				SUM(ABS(TurnOver)) AS TurnOver,
				SUM(grosscomm) AS GrossComm,
				ISNULL(SUM(winlost),0) + ISNULL(SUM(awinlost), 0) + ISNULL(SUM(comm), 0) AS DownlineTotal,
				SUM(mwinlost) AS MAgWinlost,
				ISNULL(SUM(acomm), 0) - ISNULL(SUM(comm), 0) AS Comm
		FROM  dbo.sum_winloss b WITH (NOLOCK) 
		INNER JOIN CTE_Downline cte 
			ON  b.winlostdate = cte.winlostdate
			AND b.srecommend = cte.srecommend
			AND b.mrecommend = cte.mrecommend 
			AND b.recommend = cte.recommend 
			AND b.RoleID = cte.roleid
			AND b.Custid = cte.Custid
		INNER JOIN #TmpCondSumWL t 
			ON b.sporttype = t.sporttype
			AND b.bettype = t.bettype 
			AND ISNULL(b.leagueGroupID,0) = t.LeagueGroupID 
			AND ISNULL(b.ticketType,0) = t.TicketType
		GROUP BY b.CustID
		OPTION (MAXRECURSION 0);

		-- Cash Service Billing 
		IF ',' + @ProductIDs + ',' LIKE '%,111,%'
		BEGIN
			;WITH CTE_Downline AS (
				SELECT TOP(@totalDownline) CAST([value] AS INT) AS custid
				FROM STRING_SPLIT(@downlineIds, ',') AS c
			)
			INSERT INTO #MAgWinLoss(CustID, TurnOver, GrossComm, DownlineTotal, MAgWinlost, Comm)
			SELECT tr.CustID,
					0 AS TurnOver,
					0 AS GrossComm,
					SUM(WinLost-Actual_Stake) AS DownlineTotal,
					0 AS MAgWinlost,
					0 AS Comm
			FROM dbo.Transfer tr (NOLOCK)
			INNER JOIN CTE_Downline m ON m.custid = tr.custid
			INNER JOIN (	
						SELECT DISTINCT ma.ProductID, ma.BetType
						FROM  dbo.SportBettypeMatrix ma WITH(NOLOCK)
						WHERE ma.ProductID = 111
							AND (ma.IsTest = 0 OR ma.IsTest = @IsTest)
							AND ma.RefTable = 4
							AND ma.BetType IN (31003,31004,31005)
						) f ON tr.Bettype = f.BetType
			WHERE tr.winlostdate BETWEEN @FDate AND @TDate
			GROUP BY tr.CustId;
		END
	END
	
	--TODO: range Sum_WinLoss_Old
	SELECT @FDate = NULL, @TDate = NULL
	SELECT @FDate = FromDate , @TDate = ToDate
	FROM dbo.f_MBU_RangeDate(@FromDate, @ToDate, @BalanceUpDay, @MoveBetsDay)
	WHERE RangeType = 3

	IF @FDate IS NOT NULL
	BEGIN
		-- using cte to remove predicate when seek on sum_winloss_old
		;WITH CTE_Winlostdate (winlostdate) AS
		(
			SELECT @FDate AS winlostdate
			UNION ALL
			SELECT DATEADD(DAY, 1, winlostdate)
			FROM CTE_Winlostdate
			WHERE winlostdate < @TDate
		), CTE_Downline AS (
			SELECT TOP (@totalDownline * (DATEDIFF(DAY,@FDate,@TDate) + 1))
				ci.custid AS custid
				,ci.srecommend
				,ci.mrecommend
				,ci.recommend
				,ci.roleid
				,w.winlostdate
			FROM STRING_SPLIT(@downlineIds, ',') AS c
			INNER JOIN custInfo ci WITH (NOLOCK) ON CAST(c.[value] AS INT) = ci.custid
			CROSS APPLY CTE_Winlostdate w
		)
		INSERT INTO #MAgWinLoss(CustID, TurnOver, GrossComm, DownlineTotal, MAgWinlost, Comm)
		SELECT	b.CustID,
				SUM(ABS(TurnOver)) AS TurnOver,
				SUM(grosscomm) AS GrossComm,
				ISNULL(SUM(winlost), 0) + ISNULL(SUM(awinlost), 0) + ISNULL(SUM(comm), 0) AS DownlineTotal,
				SUM(mwinlost) AS MAgWinlost,
				ISNULL(SUM(acomm), 0) - ISNULL(SUM(comm), 0) AS Comm
		FROM bodb_Summary.dbo.Sum_WinLoss_Old b WITH(NOLOCK)
		INNER JOIN CTE_Downline cte 
			ON  b.winlostdate = cte.winlostdate
			AND b.srecommend = cte.srecommend
			AND b.mrecommend = cte.mrecommend 
			AND b.recommend = cte.recommend 
			AND b.RoleID = cte.roleid
			AND b.Custid = cte.Custid
		INNER JOIN #TmpCondSumWL bt 
			ON b.sporttype = bt.sporttype
			AND b.bettype = bt.bettype
			AND ISNULL(b.LeagueGroupID,0) = bt.LeagueGroupID
			AND ISNULL(b.TicketType,0) = bt.TicketType
		GROUP BY b.CustID
		OPTION (MAXRECURSION 0);

	END

	SELECT @FDate = @FromDate, @TDate = @ToDate;
		
	WITH CTE_TransId AS (
		SELECT TransId 
		FROM SabaWalletTicket WITH (NOLOCK) 
		WHERE Mrecommend = @CID 
			AND WinlostDate BETWEEN @FDate AND @TDate
	), CTE_Downline AS (
		SELECT TOP(@totalDownline) CAST([value] AS INT) AS custid
		FROM STRING_SPLIT(@downlineIds, ',') AS c
	)
	INSERT INTO #MAgWinLoss(CustID,RewardAmount)
	SELECT CustID, RewardAmount
	FROM (
			SELECT CASE WHEN swt.Recommend = -3 THEN swt.CustID ELSE swt.Recommend END AS CustID, SUM(Amount) AS RewardAmount
			FROM SabaWalletTicket swt WITH (NOLOCK)
			INNER JOIN CTE_TransId cte ON swt.TransId = cte.TransId
			WHERE swt.WalletID = 2
			GROUP BY CASE WHEN swt.Recommend = -3 THEN swt.CustID ELSE swt.Recommend END
		) a
	WHERE EXISTS (SELECT TOP 1 1 FROM CTE_Downline cte WHERE cte.custid = a.CustID);

	--TODO: Result
	SELECT	c.CustID AS CustId,
			c.UserName AS CustName,
			c.FirstName,
			c.LastName,
			CASE WHEN c.recommend = -3 THEN 1 ELSE 0 END AS IsDirectMember,
			SUM(TurnOver) AS Turnover,
			SUM(GrossComm) AS GrossComm,
			SUM(DownlineTotal) AS DownlineTotal,
			SUM(MAgWinlost) AS MAgWinLoss,
			SUM(Comm) AS MAgComm,
			SUM(RewardAmount) AS RewardAmount,
			@CurrencyCode AS RewardCurrency
	FROM  #MAgWinLoss w 
		LEFT JOIN Customer c WITH(NOLOCK) ON w.CustID = c.CustID 
	GROUP BY c.CustID, c.UserName, c.FirstName, c.LastName, CASE WHEN c.recommend = -3 THEN 1 ELSE 0 END
	ORDER BY IIF(c.Username IS NULL,1,0),c.Username;

	SET NOCOUNT OFF;
END
GO