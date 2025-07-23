/*<info serverAlias="DBAGE-bodb02" executers="wsv_alp,wsv_alpv" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Age_Rpt_WinLoss_Member]
	@CustID 		INT, --recommend
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
	Original: Age_Rpt_WinLoss_Member
    
	Revisions:
		- 20161111@Paul: Microsite for Report - [Redmine: #66991]
		- 20170622@Percy: Combine Betradar Virtual Sports with Virtual Sports [RedmineID: #78339]
		- 20180518@Sophia: WC2018 - Enhance Performance at Sum_winloss_old table [Redmind: #91107]
		- 20180914@Percy: Poker Games - Modify GrossComm [RedmineID: #101550]
		- 20190826@Percy: Remove inactive products [RedmineID: #118699]
		- 20200909@Malcolm : Report Enhancement for Jackpot Product [RedmineID : #139575]
		- 20211122@Percy: Enhance gross comm formula [RedmineID: #164479]
		- 20220208@Danny: Separate Saba Sport Performance [Redmine: #167177]
		- 20221207@Eddie: Add New SABA ESports PinGoal [RedmineID: #181383]
		- 20230104@Bobby: Enhance GrossComm figure [RedmineID: #182155]
		- 20230328@Malcolm: Add firstname, lastname [RedmineId: #185313]  
		- 20230630@Lewis: Add Saba Tennis [RedmineID: #190459]
		- 20240219@Bobby: Apply CDC bettrans_compact [RedmineID: #195357]
		- 20240125@Lewis: Show Archived User [RedmineID: #199410]
		- 20240306@Lewis: Add Virtual Ice Hockey [RedmineID: #201129]
		- 20240515@Lewis: Add SABA Kabaddi [RedmineID: #203763]
		- 20240320@Lewis: Change metadat wsv_alp,wsv_alpv [RedmineID: #201129]
		- 20240424@Lewis: Change old sql account [Redmine: #204021]
		- 20241205@Lewis: Change data source bettrans_compact [Redmine: #214836]
		- 20241119@Lewis: Direct Member ==> Clean un-used code [RedmineId: #211969]  
		- 20250529@Dave: Add Reward column [RedmineId: #228972]
		- 20250619@Virgil: Agency Cash Service - Billing service and Report changes - Sprint 4 [RedmineId: #229883]  
	
	Param's Explanation:
	  @ProductDetails:		
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
*/
    
BEGIN
	SET NOCOUNT ON;

	DROP TABLE IF EXISTS #AgWinLoss;
	DROP TABLE IF EXISTS #GrossComm;
	DROP TABLE IF EXISTS #TmpCondSumWL;

	CREATE TABLE #AgWinLoss(
		CustID			INT,
		TurnOver		MONEY,
		GrossComm		MONEY,
		MemberWinLost	MONEY,
		AgWinLost		MONEY,
		PlayerComm		MONEY,
		AgComm			MONEY,
		RewardAmount	MONEY DEFAULT 0
	);

	CREATE TABLE #GrossComm (CustId INT, GrossComm MONEY)

	CREATE TABLE #TmpCondSumWL(
		ProductID	TINYINT,
		SportType	SMALLINT,
		BetType		INT,
		LeagueGroupID SMALLINT, 
		TicketType TINYINT
	);

	DECLARE @ExistingProductDetails TABLE (ProductId INT,Sporttype SMALLINT,Bettype INT, LeagueGroupID SMALLINT, TicketType TINYINT)
	DECLARE @isTest BIT = 0, @__ProductDetails XML;
	SELECT  @isTest = dbo.f_CheckSPVersion(@@PROCID);	

	SELECT @ProductIds = dbo.f_AddRelatedProducts(@ProductIds);
	SELECT @__ProductDetails = CONVERT(XML, @ProductDetails)

	INSERT INTO @ExistingProductDetails(ProductId,Sporttype,Bettype,LeagueGroupID,TicketType)
	SELECT ProductId,Sporttype,Bettype,LeagueGroupID,TicketType
	FROM dbo.f_ProductDetail_ConditionSel(@ProductDetails, @__ProductDetails)

	IF (@FromDate <= @MoveBetsDay)
	BEGIN
		INSERT INTO #TmpCondSumWL(ProductID, SportType, BetType, LeagueGroupID, TicketType) 
		SELECT f.ProductID, f.SportType, f.BetType, f.LeagueGroupID, f.TicketType
		FROM dbo.f_SumWinloss_ConditionSel(@ProductIds) f
			LEFT JOIN @ExistingProductDetails e ON f.ProductID = e.ProductId 
		WHERE e.ProductId IS NULL OR (e.Bettype = f.BetType AND e.Sporttype = f.SportType AND e.TicketType = f.TicketType AND e.LeagueGroupID = f.LeagueGroupID AND e.ProductID = f.ProductId)
	END

	------Get @Srecommend
	DECLARE @Srecommend int, @mrecommend int;
	DECLARE @CurrencyCode VARCHAR(12);

	SELECT	@Srecommend =  c.Srecommend,
			@Mrecommend =  c.Mrecommend,
			@CurrencyCode = e.Code
	FROM dbo.CustInfo c WITH (NOLOCK)
	INNER JOIN dbo.Exchange e WITH (NOLOCK)
		ON c.currency = e.ExchangeId
	WHERE c.CustID = @CustID;

	--Avoid Parameter Sniffing
	DECLARE @FDate	SMALLDATETIME,
			@TDate	SMALLDATETIME,
			@CID	INT;

	SELECT	@CID = @custid;

	DECLARE @SportBettypeMatrix TABLE (BetType SMALLINT, RefTable TINYINT,  LeagueGroupID SMALLINT, TicketType TINYINT, SportType SMALLINT, ProductID INT);

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

	--TODO: range bettrans
	SELECT @FDate = FromDate , @TDate = ToDate
	FROM dbo.f_MBU_RangeDate(@FromDate, @ToDate, @BalanceUpDay, @MoveBetsDay)
	WHERE RangeType = 1

	IF @FDate IS NOT NULL
	BEGIN
		--TODO: bettrans_compact
		;WITH CTE_Member AS (
			SELECT custid
			FROM dbo.Customer WITH(NOLOCK)
			WHERE recommend = @CID
				AND RoleId = 1
		)
		INSERT INTO #AgWinLoss(CustID, TurnOver, GrossComm, MemberWinLost, AgWinLost, PlayerComm, AgComm)
		SELECT	b.CustID,
		   		SUM(b.TurnOver) AS TurnOver,
				SUM(b.GrossComm) AS GrossComm,
				SUM(b.winlost) AS MemberWinLost,
				SUM(b.awinlost) AS AgWinLost,
				SUM(b.playercomm) AS PlayerComm,
				SUM(b.comm - b.playercomm) AS AgComm
		FROM bodb_AGE.dbo.bettrans_compact b WITH(NOLOCK)
			INNER JOIN CTE_Member m ON m.custid = b.custid
			INNER JOIN @SportBettypeMatrix s ON b.bettype = s.bettype 
				AND (s.ProductID <> 1 OR (s.ProductID = 1 AND b.sporttype = s.SportType AND b.LeagueGroupID = s.LeagueGroupID AND b.TicketType = s.TicketType))
		WHERE 
			b.winlostdate BETWEEN @FDate AND @TDate
		GROUP BY 
			b.custid;

		-- Cash Service Billing 
		IF ',' + @ProductIDs + ',' LIKE '%,111,%'
		BEGIN
			INSERT INTO #AgWinLoss(CustID, TurnOver, GrossComm, MemberWinLost, AgWinLost, PlayerComm, AgComm)
			SELECT tr.CustId,
                    0 AS TurnOver,
                    0 AS GrossComm,
                    0 AS MemberWinLost,
                    SUM(WinLost-Actual_Stake) AS AgWinLost,
                    0 AS PlayerComm,
                    0 AS AgComm
			FROM dbo.Transfer tr (NOLOCK)
			INNER JOIN (	
						SELECT DISTINCT ma.ProductID, ma.BetType
						FROM  dbo.SportBettypeMatrix ma WITH(NOLOCK)
						WHERE ma.ProductID = 111
							AND (ma.IsTest = 0 OR ma.IsTest = @IsTest) 
							AND ma.RefTable = 4
							AND ma.BetType IN (31003,31004,31005)
						) f ON tr.Bettype = f.BetType
			WHERE tr.winlostdate BETWEEN @FDate AND @TDate
				AND tr.CustId = @CID
			GROUP BY tr.CustId;
		END

		IF EXISTS (SELECT 1 FROM @SportBettypeMatrix WHERE RefTable = 1) -- bettransRnG
		BEGIN
			INSERT INTO #GrossComm (CustId, GrossComm)
			SELECT b.CustId, SUM(b.BetStake * b.discount) AS GrossComm
			FROM dbo.bettransRnG b WITH (NOLOCK)
				INNER JOIN @SportBettypeMatrix s ON b.gameId = s.Bettype AND s.RefTable = 1
			WHERE b.recommend = @CID 
				AND b.winlostdate BETWEEN @FDate AND @TDate
				AND b.statusID IN (111, 112, 113)
			GROUP BY b.CustId
		END

		IF EXISTS (SELECT 1 FROM @SportBettypeMatrix WHERE RefTable = 2) -- bettransLC
		BEGIN
			INSERT INTO #GrossComm (CustId, GrossComm)
			SELECT b.CustId, SUM(b.NetStake * b.discount) AS GrossComm
			FROM dbo.bettransLC b WITH (NOLOCK)
				INNER JOIN @SportBettypeMatrix s ON b.gameId = s.Bettype AND s.RefTable = 2
			WHERE b.recommend = @CID 
				AND b.winlostdate BETWEEN @FDate AND @TDate
				AND b.statusID IN (111, 112, 113)
			GROUP BY b.CustId
		END

		IF EXISTS (SELECT 1 FROM #GrossComm)
		BEGIN
			UPDATE t
			SET t.GrossComm = ISNULL(t.GrossComm, 0) + ISNULL(c.GrossComm, 0)
			FROM #AgWinLoss t
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
		INSERT INTO #AgWinLoss(CustID, TurnOver, GrossComm, MemberWinLost, AgWinLost, PlayerComm, AgComm)
		SELECT	CustID,
				SUM(ABS(TurnOver)) AS TurnOver,
				SUM(grosscomm) AS GrossComm,
				SUM(winlost) AS MemberWinLost,
				SUM(awinlost) AS AgWinLost,
				SUM(playercomm) AS PlayerComm,
				SUM(comm - playercomm) AS AgComm
		FROM  dbo.Sum_WinLoss b WITH(NOLOCK) 
			INNER JOIN #TmpCondSumWL t ON b.sporttype = t.sporttype AND b.bettype = t.bettype AND ISNULL(b.leagueGroupID,0) = t.LeagueGroupID AND ISNULL(b.ticketType,0) = t.TicketType
		WHERE recommend = @CID
			AND Winlostdate BETWEEN @FDate AND @TDate
			AND roleID = 1
		GROUP BY CustID;

		-- Cash Service Billing 
		IF ',' + @ProductIDs + ',' LIKE '%,111,%'
		BEGIN
			INSERT INTO #AgWinLoss(CustID, TurnOver, GrossComm, MemberWinLost, AgWinLost, PlayerComm, AgComm)
			SELECT tr.CustId,
                    0 AS TurnOver,
                    0 AS GrossComm,
                    0 AS MemberWinLost,
                    SUM(WinLost-Actual_Stake) AS AgWinLost,
                    0 AS PlayerComm,
                    0 AS AgComm
			FROM dbo.Transfer tr (NOLOCK)
			INNER JOIN (	
						SELECT DISTINCT ma.ProductID, ma.BetType
						FROM  dbo.SportBettypeMatrix ma WITH(NOLOCK)
						WHERE ma.ProductID = 111
							AND (ma.IsTest = 0 OR ma.IsTest = @IsTest) 
							AND ma.RefTable = 4
							AND ma.BetType IN (31003,31004,31005)
						) f ON tr.Bettype = f.BetType
			WHERE tr.winlostdate BETWEEN @FDate AND @TDate
				AND tr.CustId = @CID
			GROUP BY tr.CustId;
		END
	END

	SELECT	@FDate = @FromDate,
			@TDate = @ToDate;

	--TODO: range bk
	SELECT @FDate = NULL, @TDate = NULL
	SELECT @FDate = FromDate , @TDate = ToDate
	FROM dbo.f_MBU_RangeDate(@FromDate, @ToDate, @BalanceUpDay, @MoveBetsDay)
	WHERE RangeType = 3

	IF @FDate IS NOT NULL
	BEGIN
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
		INSERT INTO #AgWinLoss(CustID, TurnOver, GrossComm, MemberWinLost, AgWinLost, PlayerComm, AgComm)
		SELECT	CustID,
				SUM(ABS(TurnOver)) AS TurnOver,
				SUM(grosscomm) AS GrossComm,
				SUM(winlost) AS MemberWinLost,
				SUM(awinlost) AS AgWinLost,
				SUM(playercomm) AS PlayerComm,
				SUM(comm - playercomm) AS AgComm
		FROM  bodb_Summary.dbo.Sum_WinLoss_Old b WITH(NOLOCK) 
			CROSS APPLY CTE_Winlostdate w
		WHERE b.winlostdate = w.winlostdate 
			AND recommend = @CustID 
			AND srecommend = @Srecommend   --- Add Srecommend, Mrecommend to get the index seek 
			AND mrecommend = @mrecommend
			AND roleID = 1
			AND b.sporttype = w.sporttype
			AND b.bettype = w.bettype 
			AND ISNULL(b.leagueGroupID,0) = w.LeagueGroupID
			AND ISNULL(b.ticketType,0) = w.TicketType
		GROUP BY CustID
		OPTION (MAXRECURSION 0);

		-- Cash Service Billing 
		IF ',' + @ProductIDs + ',' LIKE '%,111,%'
		BEGIN
			INSERT INTO #AgWinLoss(CustID, TurnOver, GrossComm, MemberWinLost, AgWinLost, PlayerComm, AgComm)
			SELECT b.CustID,
                    0 AS TurnOver,
                    0 AS GrossComm,
                    0 AS MemberWinLost,
                    SUM(WinLost) AS AgWinLost,
                    0 AS PlayerComm,
                    0 AS AgComm
			FROM bodb_Summary.dbo.Sum_WinLoss_Old b WITH(NOLOCK)
			INNER JOIN #TmpCondSumWL bt ON b.sporttype = bt.sporttype AND b.bettype = bt.bettype AND bt.ProductID = 111
			WHERE b.winlostdate BETWEEN @FDate AND @TDate
				AND srecommend = @srecommend
				AND mrecommend = @mrecommend
				AND recommend = @custid
				AND RoleID = 2
			GROUP BY b.CustID
		END
	END

	SELECT @FDate = @FromDate, @TDate = @ToDate;
	INSERT INTO #AgWinLoss(CustID,RewardAmount)
	SELECT CustID, SUM(Amount) AS RewardAmount
	FROM SabaWalletTicket WITH (NOLOCK) 
	WHERE recommend = @CustID 
		AND WinlostDate BETWEEN @FDate AND @TDate
		AND WalletID = 2
	GROUP BY CustID;


	SELECT	c.CustID AS CustId,
			CASE WHEN c.CustID = @CID THEN 'CASH SERVICE BILLING' ELSE c.UserName END AS CustName,
            CASE WHEN c.CustID != @CID THEN c.FirstName ELSE '' END AS FirstName, 
            CASE WHEN c.CustID != @CID THEN c.LastName ELSE '' END AS LastName,
			SUM(TurnOver) AS Turnover,
			SUM(GrossComm) AS GrossComm,
			SUM(MemberWinLost) AS MemberWinLoss,
			SUM(playercomm) AS MemberComm,
			SUM(AgWinLost) AS AgWinLoss,
			SUM(AgComm) AS AgComm,
			SUM(RewardAmount) AS RewardAmount,
			@CurrencyCode AS RewardCurrency,
            CASE WHEN c.CustID = @CID THEN 1 ELSE 0 END AS IsCashServiceBilling
	FROM #AgWinLoss w 
		LEFT JOIN dbo.Customer c WITH(NOLOCK) ON w.CustID = c.CustID 
	GROUP BY c.CustID, c.UserName, c.FirstName, c.LastName
	ORDER BY IsCashServiceBilling, IIF(c.Username IS NULL,1,0), c.Username;

END
GO