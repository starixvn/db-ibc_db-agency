/*<info serverAlias="DBAGE-bodb02" executers="wsv_alp,wsv_alpv" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Age_Rpt_WinLossDetail_Member]
	@CustID			INT = NULL, --recommend
	@FromDate		SMALLDATETIME,
	@ToDate			SMALLDATETIME,
	@ProductIds		VARCHAR(MAX),
	@ProductDetails NVARCHAR(MAX) = 'All',
	@BalanceUpDay	SMALLDATETIME,
	@MoveBetsDay	SMALLDATETIME,
	@PageSize		INT = 0,
	@PageIndex		INT = 0,
	@TotalRecords	INT = 0 OUTPUT,
	@UserName		VARCHAR(30) = '',
	@IsReward		BIT = 1
AS

/*
Created: 
Task : Smartphone friendly - Win Loss Detail Report
DB: DBAGE/bodb02

Revisions:
	- 20161024@Paul: Smartphone Friendly UI for Microsite Report [RedmineID: #61531]
	- 20170110@Paul: Use new functions to get sum_winloss condition and SportBettypeMatrix [RedmineID: #69515]
	- 20170622@Percy: Combine Betradar Virtual Sports with Virtual Sports [RedmineID: #78339]
	- 20170914@Percy: Enhance performance on sum_winloss_old [RedmineID: #83171]
	- 20180913@Percy: Bullfighting - Add data into TurnoverNoDraw column [RedmineID: #101288]
	- 20180914@Percy: Poker Games - Modify GrossComm [RedmineID: #101550]
	- 20190826@Percy: Remove inactive products [RedmineID: #118699]
	- 20200410@Sophia: Add BBIN, Sexy Gaming, SA Gaming [RedmineId: #131358]
	- 20200422@Sophia: Add IBCBet Live Casino [RedmineId: #130693]
	- 20200521@Sophia: Enhance SP due to bot attack [redmind: #134415]
	- 20200527@Sophia: Add ION [Redmine: #132325]
	- 20200528@Sophia: Add RNG War [Redmine: #132013]
	- 20200909@Malcolm: Report Enhancement for Jackpot Product [RedmineID : #139575]
	- 20200915@Malcolm: Add WM Live Casino [Redmine : #131584]
	- 20201201@Malcolm : Add Gold Diamond Gaming [Redmine : #144110]
	- 20201210@Malcolm: Add Big Gaming [RedmineId : #142459]
	- 20210310@Malcolm: Add Pragmatic Live Casino [RedmineId : #133717]
	- 20210617@Sol: changed how to calc net turn over - [RedmineId : #156653]
	- 20211122@Percy: Enhance gross comm formula [RedmineID: #164479]
	- 20220208@Danny: Separate Saba Sport Performance [Redmine: #167177]
	- 20221207@Eddie: Add New SABA ESports PinGoal [RedmineID: #181383]
	- 20221229@Bobby: Enhance GrossComm figure [RedmineID: #182155]
	- 20230331@Malcolm: Add first name, last name [RedmineID : #184752]
	- 20230526@Lewis: Add Search by Username [RedmineID : #184752 - Phase 2]
	- 20230630@Lewis: Add Saba Tennis [RedmineID: #190459]
	- 20240125@Lewis: Show Archived User [RedmineID: #199410]
	- 20240306@Lewis: Add Virtual Ice Hockey [RedmineID: #201129]
	- 20240515@Lewis: Add SABA Kabaddi [RedmineID: #203763]
	- 20240424@Lewis: Change old sql account [Redmine: #204021]
	- 20240703@Lewis: Switch data source - from bettrans to bettranscompact [Redmine: #207517]
	- 20240715@Kelvin: Alpha - Link WL Detail to My Watchlist [Redmine:#201733]
    - 20240918@Lewis: Rebate Retention - Reward [RedmineId: #208503]
	- 20241129@Lewis: Enhance Perf SabaWalletTicket [RedmineId: #214431]
	- 20241119@Lewis: Direct Member [RedmineId: #211969]
	- 20250506@Bobby: Tuning perf IO on custinfo [RedmineId: #226284]
	- 20250529@Virgil: Cash Service - Billing service and Report changes [RedmineId: #227984]
	- 20250718@Virgil: Cash Service Billing - Sprint 6 - Enhance code [RedmineId: #231700]
	- 20250904@Virgil: Replace Task_sum_winloss with bettrans_compact [RedmineId: #235369]		
	- 20250924@Virgil: Enhance report for f_SportBettype_SumWinloss [RedmineId: #235369]	
	- 20251031@Bobby: Tuning IO for ExtraInfo [RedmineId: #243155]
	- 20251105@Bobby: Minimize IO for ExtraInfo [RedmineId: #243476]
	
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
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @RowStart	INT,
			@RowEnd		INT;
		
	SELECT	@PageIndex = @PageIndex - 1,
			@RowStart = @PageSize * @PageIndex + 1,
			@RowEnd = @RowStart + @PageSize - 1;

	DROP TABLE IF EXISTS #AgWinLossDetails;
	DROP TABLE IF EXISTS #TmpCondSumWL;
	DROP TABLE IF EXISTS #GrossComm;

	CREATE TABLE #AgWinLossDetails(
		CustID			INT,
		TurnOver		MONEY,
		TurnoverNoDraw	MONEY,
		GrossComm		MONEY,
		MemberWinLost	MONEY,
		PlayerComm		MONEY,
		AgWinLost		MONEY,
		AgComm			MONEY,
		NoOfTicket		INT,
		RewardAmount	MONEY
	);

	CREATE TABLE #GrossComm (CustId INT, TurnoverNoDraw MONEY, GrossComm MONEY)

	CREATE TABLE #TmpCondSumWL(
		ProductID		TINYINT,
		SportType		INT,
		BetType			INT,
		BettypeGroup	VARCHAR(20),
		LeagueGroupID	SMALLINT, 
		TicketType		TINYINT,
		PRIMARY KEY CLUSTERED (BetType, SportType, ProductID, BettypeGroup, LeagueGroupID, TicketType)
	);

	DECLARE @ExistingProductDetails TABLE (ProductId INT,Sporttype INT,Bettype INT, LeagueGroupID SMALLINT, TicketType TINYINT)
	DECLARE @isTest BIT = 0, @__ProductDetails XML;

	SELECT  @isTest = dbo.f_CheckSPVersion(@@PROCID);	

	SELECT @ProductIds = dbo.f_AddRelatedProducts(@ProductIds);
	SELECT @__ProductDetails = CONVERT(XML, @ProductDetails)

	INSERT INTO @ExistingProductDetails(ProductId,Sporttype,Bettype,LeagueGroupID,TicketType)
	SELECT ProductId,Sporttype,Bettype,LeagueGroupID,TicketType
	FROM dbo.f_ProductDetail_ConditionSel(@ProductDetails, @__ProductDetails);
	-- Get TmpCondSumWL from ExtraInfo
	WITH CTE_SportRef AS (
		SELECT DISTINCT ProductID, SportTypeRef AS SportType, BettypeRef AS Bettype, BettypeGroup, 0 AS LeagueGroupID, 0 AS TicketType
		FROM [dbo].[vw_SportBettype_ExtraInfo] ck WITH (NOLOCK)
		WHERE ',' + @ProductIDs + ',' LIKE '%,' + CAST(ck.ProductID AS VARCHAR(3)) + ',%'
		UNION ALL 
		SELECT ProductID, SportType, Bettype, '', LeagueGroupID, TicketType
		FROM dbo.f_GetSabaSportTypeRef() saba
		WHERE ',' + @ProductIDs + ',' LIKE '%,' + CAST(saba.ProductID AS VARCHAR(3)) + ',%'
	)
    INSERT INTO #TmpCondSumWL(ProductID, SportType, BetType, BettypeGroup, LeagueGroupID, TicketType) 
	SELECT DISTINCT f.ProductId, f.SportType, f.BetType, f.BettypeGroup, ISNULL(e.LeagueGroupID, 0), ISNULL(e.TicketType, 0)
	FROM CTE_SportRef f
		LEFT JOIN @ExistingProductDetails e ON f.ProductID = e.ProductId 
	WHERE 
		e.ProductId IS NULL 
		OR (
			e.Bettype = f.BetType 
			AND e.Sporttype = f.SportType 
			AND e.TicketType = f.TicketType 
			AND e.LeagueGroupID = f.LeagueGroupID 
			AND e.ProductID = f.ProductId
		);

	------Get @Srecommend
	DECLARE @Srecommend int, @mrecommend int, @CurrencyCode VARCHAR(12);
	  
	SELECT	@Srecommend =  Srecommend,
			@Mrecommend =  Mrecommend,
			@CurrencyCode	= e.Code
	FROM dbo.CustInfo c WITH(NOLOCK) 
	INNER JOIN dbo.Exchange e WITH(NOLOCK) ON c.currency = e.ExchangeId
	WHERE c.CustID = @CustID; 

	--Avoid Parameter Sniffing
	DECLARE @FDate	SMALLDATETIME,
			@TDate	SMALLDATETIME,
			@CID	INT;
	    
	SELECT	@CID = @custid;

	DECLARE @UserName_CustId INT,
		@totalDownline INT, 
		@downlineIds VARCHAR(MAX);

	IF ISNULL(@Username,'') <> ''	--@USERNAME IS NOT NULL		=> -1: No Data || >0: Exactly Username
	BEGIN
		SET @UserName_CustId = ISNULL((SELECT Custid FROM dbo.Customer WITH (NOLOCK) WHERE username = @UserName),-1)
		IF @UserName_CustId = -1
			GOTO OUTPUT_RESULT;
			
		SELECT 
			@totalDownline	= COUNT(1), 
			@downlineIds	= STRING_AGG(CAST(custid AS VARCHAR(MAX)), ',')
		FROM dbo.Customer c WITH(NOLOCK)
		WHERE c.custid = @UserName_CustId
			AND recommend = @CID
			AND RoleId = 1
			
	END
	ELSE	
	BEGIN
		SET @UserName_CustId = 0; --> suport archived members
		SELECT 
			@totalDownline	= COUNT(1), 
			@downlineIds	= STRING_AGG(CAST(custid AS VARCHAR(MAX)), ',')
		FROM dbo.Customer c WITH(NOLOCK)
		WHERE recommend = @CID
			AND RoleId = 1
	END

	--TODO: bettrans range
	SELECT @FDate = FromDate , @TDate = ToDate
	FROM dbo.f_MBU_RangeDate(@FromDate, @ToDate, @BalanceUpDay, @MoveBetsDay)
	WHERE RangeType = 1
	
	IF @FDate IS NOT NULL
	BEGIN
		-- TODO: get data from bettrans_compact
		;WITH CTE_Downline AS (
			SELECT TOP(@totalDownline) CAST([value] AS INT) AS custid
			FROM STRING_SPLIT(@downlineIds, ',') AS c
		),
		CTE_BettypeRef AS (
			SELECT DISTINCT Bettype, BettypeGroup
			FROM #TmpCondSumWL AS ref
			WHERE ref.Bettype > 0 AND ProductId <> 1
		)
		INSERT INTO #AgWinLossDetails(CustID, TurnOver, TurnoverNoDraw, GrossComm, MemberWinLost, PlayerComm, AgWinLost, AgComm, NoOfTicket)
		SELECT	b.custid,
				SUM(b.turnover) AS TurnOver,
				SUM(b.TurnoverNoDraw) AS TurnoverNoDraw,
				SUM(b.GrossComm) AS GrossComm,
				SUM(b.winlost) AS MemberWinLost,
				SUM(b.playercomm) AS PlayerComm,
				SUM(b.awinlost) AS AgWinlost,
				SUM(b.comm - b.playercomm) AS AgComm,
				SUM(b.betcount) AS NoOfTicket
		FROM bodb_Age.dbo.bettrans_compact b WITH (NOLOCK)
		INNER JOIN CTE_Downline m ON m.custid = b.custid
		INNER JOIN (
			SELECT	ISNULL(p.GroupProductId, f.ProductID) AS ProductID, f.BetType, f.RefTable, ISNULL(e.LeagueGroupID,0) AS LeagueGroupID, ISNULL(e.TicketType,0) AS TicketType, ISNULL(SportType,0) AS SportType
			FROM (	
					SELECT DISTINCT ma.ProductID, ma.BetType, ma.RefTable
					FROM  dbo.SportBettypeMatrix ma WITH(NOLOCK)
					WHERE ',' + @ProductIDs + ',' LIKE '%,' + cast(ma.ProductID as varchar(3)) + ',%'
						AND (ma.IsTest = 0 OR ma.IsTest = @IsTest)
				) f
				LEFT JOIN dbo.f_GroupProduct() p ON f.ProductID = p.ProductId
				LEFT JOIN @ExistingProductDetails e ON e.ProductId = f.ProductID 
			WHERE e.ProductId IS NULL 
				OR e.Bettype = f.BetType 
				OR (e.Bettype = 0 AND (e.ProductId = 1 OR f.Bettype NOT IN(SELECT Bettype FROM CTE_BettypeRef)))
		) s ON b.bettype = s.bettype 
			AND (s.ProductID <> 1 OR (s.ProductID = 1 AND b.sporttype = s.SportType AND b.LeagueGroupID = s.LeagueGroupID AND b.TicketType = s.TicketType))
		WHERE winlostdate BETWEEN @FDate AND @TDate
		GROUP BY b.custid;

		-- Cash Service Billing 
		IF ',' + @ProductIDs + ',' LIKE '%,111,%'
		BEGIN
			INSERT INTO #AgWinLossDetails(CustID, TurnOver, TurnoverNoDraw, GrossComm, MemberWinLost, PlayerComm, AgWinLost, AgComm, NoOfTicket)
			SELECT tr.CustId,
					0 AS TurnOver,
					0 AS TurnoverNoDraw,
					0 AS GrossComm,
					0 AS MemberWinLost,
					0 AS PlayerComm, 
					SUM(WinLost-Actual_Stake) AS AgWinLost,
					0 AS AgComm, 
					0 AS NoOfTicket
			FROM dbo.Transfer tr (NOLOCK)
			INNER JOIN #TmpCondSumWL f ON tr.Bettype = f.BetType AND f.ProductId = 111
			WHERE tr.winlostdate BETWEEN @FDate AND @TDate
				AND tr.CustId = @CID
			GROUP BY tr.CustId;
		END

		-- bettransRnG
		;WITH CTE_BettypeRef AS (
			SELECT DISTINCT Bettype, BettypeGroup
			FROM #TmpCondSumWL AS ref
			WHERE ref.Bettype > 0 AND ProductId <> 1
		)
		INSERT INTO #GrossComm (CustId, TurnoverNoDraw, GrossComm)
		SELECT b.CustId
			,SUM(CASE WHEN cont.ContributionBettype IS NULL THEN b.BetStake ELSE 0 END) AS TurnoverNoDraw
			,SUM(b.BetStake * b.discount) AS GrossComm
		FROM dbo.bettransRnG b WITH(NOLOCK)
			INNER JOIN (
				SELECT	ISNULL(p.GroupProductId, f.ProductID) AS ProductID, f.BetType
				FROM (	
						SELECT DISTINCT ma.ProductID, ma.BetType, ma.RefTable
						FROM  dbo.SportBettypeMatrix ma WITH(NOLOCK)
						WHERE ',' + @ProductIDs + ',' LIKE '%,' + cast(ma.ProductID as varchar(3)) + ',%'
								AND (ma.IsTest = 0 OR ma.IsTest = @IsTest) AND ma.RefTable = 1
						) f
					LEFT JOIN dbo.f_GroupProduct() p ON f.ProductID = p.ProductId
					LEFT JOIN @ExistingProductDetails e ON e.ProductId = f.ProductID 
				WHERE e.ProductId IS NULL 
					OR e.Bettype = f.BetType 
					OR (e.Bettype = 0 AND (e.ProductId = 1 OR f.Bettype NOT IN(SELECT Bettype FROM CTE_BettypeRef)))
					
			) s ON b.gameID = s.Bettype
			OUTER APPLY 
			(
				SELECT ck.Bettype AS ContributionBettype
				FROM CTE_BettypeRef ck
				WHERE ck.BettypeGroup = 'Contribution'
					AND ck.Bettype = b.gameID
			) cont
		WHERE winlostdate BETWEEN @FDate AND @TDate
			AND statusID IN (111, 112, 113) 
			AND recommend = @CID
		GROUP BY b.CustId

		-- bettransLC
		;WITH CTE_BettypeRef AS (
			SELECT DISTINCT Bettype, BettypeGroup
			FROM #TmpCondSumWL AS ref
			WHERE ref.Bettype > 0 AND ProductId <> 1
		)
		INSERT INTO #GrossComm (CustId, TurnoverNoDraw, GrossComm)
		SELECT b.CustId
			,SUM(CASE WHEN cont.ContributionBettype IS NULL THEN b.NetStake ELSE 0 END) AS TurnoverNoDraw
			,SUM(b.NetStake * b.discount) AS GrossComm
		FROM dbo.bettransLC b WITH(NOLOCK)
			INNER JOIN (
				SELECT	ISNULL(p.GroupProductId, f.ProductID) AS ProductID, f.BetType
				FROM (	
						SELECT DISTINCT ma.ProductID, ma.BetType, ma.RefTable
						FROM  dbo.SportBettypeMatrix ma WITH(NOLOCK)
						WHERE ',' + @ProductIDs + ',' LIKE '%,' + cast(ma.ProductID as varchar(3)) + ',%'
								AND (ma.IsTest = 0 OR ma.IsTest = @IsTest) AND ma.RefTable = 2
						) f
					LEFT JOIN dbo.f_GroupProduct() p ON f.ProductID = p.ProductId
					LEFT JOIN @ExistingProductDetails e ON e.ProductId = f.ProductID 
					WHERE e.ProductId IS NULL 
						OR e.Bettype = f.BetType 
						OR (e.Bettype = 0 AND (e.ProductId = 1 OR f.Bettype NOT IN (SELECT Bettype FROM CTE_BettypeRef)))
					
			) s ON b.gameID = s.Bettype
			OUTER APPLY 
			(
				SELECT ck.Bettype AS ContributionBettype
				FROM CTE_BettypeRef ck
				WHERE ck.BettypeGroup = 'Contribution'
					AND ck.Bettype = b.gameID
			) cont
		WHERE winlostdate BETWEEN @FDate AND @TDate
			AND statusID IN (111, 112, 113) 
			AND recommend = @CID
		GROUP BY b.CustId

		IF EXISTS (SELECT 1 FROM #GrossComm)
		BEGIN
			UPDATE t
			SET t.TurnoverNoDraw = ISNULL(t.TurnoverNoDraw, 0) + ISNULL(c.TurnoverNoDraw, 0)
				,t.GrossComm = ISNULL(t.GrossComm, 0) + ISNULL(c.GrossComm, 0)
			FROM #AgWinLossDetails t
				INNER JOIN (
					SELECT CustId, SUM(GrossComm) AS GrossComm, SUM(TurnoverNoDraw) AS TurnoverNoDraw FROM #GrossComm GROUP BY CustId
				) c ON t.CustId = c.CustId
		END
	END	
	
	--TODO: sum_winloss range
	SELECT @FDate = NULL, @TDate = NULL
	SELECT @FDate = FromDate , @TDate = ToDate
	FROM dbo.f_MBU_RangeDate(@FromDate, @ToDate, @BalanceUpDay, @MoveBetsDay)
	WHERE RangeType = 2
	
	IF @FDate IS NOT NULL
	BEGIN
		WITH CTE_Winlostdate (winlostdate, srecommend, mrecommend, recommend) AS
		(
			SELECT @FDate AS winlostdate, @Srecommend AS srecommend, @mrecommend AS mrecommend, @CID AS recommend
			UNION ALL	
			SELECT DATEADD(DAY, 1, winlostdate), srecommend, mrecommend, recommend
			FROM CTE_Winlostdate
			WHERE winlostdate < @TDate
		)
		INSERT INTO #AgWinLossDetails(CustID, TurnOver, TurnoverNoDraw, GrossComm, MemberWinLost, PlayerComm, AgWinLost, AgComm, NoOfTicket)
		SELECT	CustID,			
				SUM(ABS(TurnOver)) AS TurnOver,
				SUM(ABS(TunroverNoDraw)) AS TurnoverNoDraw,
				SUM(grosscomm) AS GrossComm,
				SUM(winlost) AS MemberWinLost,
				SUM(playercomm) AS PlayerComm,
				SUM(awinlost) AS AgWinLost,
				SUM(comm - playercomm) AS AgComm,
				SUM(betcount) AS NoOfTicket
		FROM dbo.sum_winloss_compact b WITH (NOLOCK) 
			CROSS APPLY CTE_Winlostdate cte
			INNER JOIN (
				SELECT	DISTINCT sporttype, bettype, leagueGroupID, ticketType
				FROM #TmpCondSumWL
			) t 
				ON b.sporttype = t.sporttype AND b.bettype = t.bettype AND ISNULL(b.leagueGroupID,0) = t.LeagueGroupID AND ISNULL(b.ticketType,0) = t.TicketType
			WHERE b.winlostdate = cte.winlostdate	
				AND b.srecommend = cte.srecommend
				AND b.mrecommend = cte.mrecommend
				AND b.recommend =  cte.recommend
				AND b.RoleID = 1
		GROUP BY CustID;

		-- Cash Service Billing 
		IF ',' + @ProductIDs + ',' LIKE '%,111,%'
		BEGIN
			INSERT INTO #AgWinLossDetails(CustID, TurnOver, TurnoverNoDraw, GrossComm, MemberWinLost, PlayerComm, AgWinLost, AgComm, NoOfTicket)
			SELECT tr.CustId,
					0 AS TurnOver,
					0 AS TurnoverNoDraw,
					0 AS GrossComm,
					0 AS MemberWinLost,
					0 AS PlayerComm, 
					SUM(WinLost-Actual_Stake) AS AgWinLost,
					0 AS AgComm, 
					0 AS NoOfTicket
			FROM dbo.Transfer tr (NOLOCK)
			INNER JOIN #TmpCondSumWL f ON tr.Bettype = f.BetType AND f.ProductId = 111
			WHERE tr.winlostdate BETWEEN @FDate AND @TDate
				AND tr.CustId = @CID
			GROUP BY tr.CustId;
		END
	END

	--TODO: sum_winloss_old range
	SELECT @FDate = NULL, @TDate = NULL
	SELECT @FDate = FromDate , @TDate = ToDate
	FROM dbo.f_MBU_RangeDate(@FromDate, @ToDate, @BalanceUpDay, @MoveBetsDay)
	WHERE RangeType = 3
	
	IF @FDate IS NOT NULL
	BEGIN
		-- using cte to remove predicate when seek on sum_winloss_old
		;WITH CTE_TmpCondSumWL AS (
			SELECT DISTINCT SportType, BetType, leagueGroupID, ticketType
			FROM #TmpCondSumWL
		),
		CTE_Winlostdate (winlostdate, sporttype, bettype, leagueGroupID, ticketType) AS
		(
			SELECT @FDate AS winlostdate, SportType, BetType, leagueGroupID, ticketType
			FROM CTE_TmpCondSumWL
			UNION ALL
			SELECT DATEADD(DAY, 1, winlostdate), SportType, BetType, leagueGroupID, ticketType
			FROM CTE_Winlostdate
			WHERE winlostdate < @TDate
		)
		INSERT INTO #AgWinLossDetails(CustID, TurnOver, TurnoverNoDraw, GrossComm, MemberWinLost, PlayerComm, AgWinLost, AgComm, NoOfTicket)
		SELECT CustID,			
				SUM(ABS(TurnOver)) AS TurnOver,
				SUM(ABS(TunroverNoDraw)) AS TurnoverNoDraw,
				SUM(grosscomm) AS GrossComm,
				SUM(winlost) AS MemberWinLost,
				SUM(playercomm) AS PlayerComm, 
				SUM(awinlost) AS AgWinLost,
				SUM(comm - playercomm) AS AgComm, 
				SUM(betcount) AS NoOfTicket
		FROM bodb_Summary.dbo.Sum_WinLoss_Old b WITH(NOLOCK) 
			CROSS APPLY CTE_Winlostdate w
		WHERE b.winlostdate = w.winlostdate
			AND srecommend = @srecommend
			AND mrecommend = @mrecommend
			AND recommend = @custid
			AND RoleID = 1
			AND b.sporttype = w.sporttype
			AND b.bettype = w.bettype
			AND ISNULL(b.leagueGroupID,0) = w.leagueGroupID
			AND ISNULL(b.ticketType,0) = w.ticketType
		GROUP BY CustID
		OPTION (MAXRECURSION 0);

		-- Cash Service Billing 
		IF ',' + @ProductIDs + ',' LIKE '%,111,%'
		BEGIN
			INSERT INTO #AgWinLossDetails(CustID, TurnOver, TurnoverNoDraw, GrossComm, MemberWinLost, PlayerComm, AgWinLost, AgComm, NoOfTicket)
			SELECT b.CustId,
					0 AS TurnOver,
					0 AS TurnoverNoDraw,
					0 AS GrossComm,
					0 AS MemberWinLost,
					0 AS PlayerComm, 
					SUM(WinLost) AS AgWinLost,
					0 AS AgComm, 
					0 AS NoOfTicket
			FROM bodb_Summary.dbo.Sum_WinLoss_Old b WITH(NOLOCK)
			INNER JOIN #TmpCondSumWL f 
				ON b.Bettype = f.BetType
				AND b.SportType = f.SportType
				AND f.ProductId = 111
			WHERE b.winlostdate BETWEEN @FDate AND @TDate
				AND srecommend = @srecommend
				AND mrecommend = @mrecommend
				AND recommend = @custid
				AND RoleID = 2
			GROUP BY b.CustID
		END
	END

	--TODO: SabaWalletTicket
	IF @IsReward = 1
	BEGIN
		SELECT @FDate = @FromDate, @TDate = @ToDate

		;WITH CTE_Downline AS (
			SELECT TOP(@totalDownline) CAST([value] AS INT) AS custid
			FROM STRING_SPLIT(@downlineIds, ',') AS c
		)
		INSERT INTO #AgWinLossDetails(CustID,RewardAmount)
		SELECT b.CustID,SUM(Amount)
		FROM SabaWalletTicket b WITH (NOLOCK)
		INNER JOIN CTE_Downline cte ON cte.custid = b.CustID
		WHERE b.winlostdate BETWEEN @FDate AND @TDate
			AND b.WalletID = 2
		GROUP BY b.CustID
	END

	--TODO: Result
	OUTPUT_RESULT:
	IF ((@PageSize <= 0) AND (@PageIndex <= 0))
	BEGIN
		IF @IsReward = 1
		BEGIN
			SELECT	c.CustID AS CustId, 
					CASE WHEN c.CustID = @CID THEN 'CASH SERVICE BILLING' ELSE c.UserName END AS CustName,
					CASE WHEN c.CustID != @CID THEN c.FirstName ELSE '' END AS FirstName, 
					CASE WHEN c.CustID != @CID THEN c.LastName ELSE '' END AS LastName,
					ISNULL(wl.IsExistedWatchList,0) IsExistedWatchList,
					SUM(TurnOver) AS Turnover,
					SUM(TurnoverNoDraw) AS NetTurnover,
					SUM(GrossComm) AS GrossComm,
					SUM(MemberWinLost) AS MemberWinLoss,
					SUM(PlayerComm) AS MemberComm,
					SUM(AgWinlost) AS AgWinLoss,
					SUM(AgComm) AS AgComm,
					SUM(NoOfTicket) AS NumberOfTickets,
					SUM(w.RewardAmount) AS RewardAmount,
					@CurrencyCode AS RewardCurrency,
					CASE WHEN c.CustID = @CID THEN 1 ELSE 0 END AS IsCashServiceBilling
			FROM #AgWinLossDetails w 
				LEFT JOIN dbo.Customer c WITH(NOLOCK) ON w.CustID = c.CustID 
				OUTER APPLY (SELECT 1 AS IsExistedWatchList FROM WLMonitored_Player wl WITH (NOLOCK) WHERE wl.CustID = w.custid AND wl.Sporttype = 0) AS wl	
			WHERE @UserName_CustId = 0 OR w.custid = @UserName_CustId
			GROUP BY c.CustID, c.UserName, c.FirstName, c.LastName,ISNULL(wl.IsExistedWatchList,0)
			ORDER BY IsCashServiceBilling ASC, IIF(c.Username IS NULL,1,0) ASC, c.Username ASC;

			SELECT	NULL AS CustId,
				'Total' AS CustName,
				SUM(TurnOver) AS Turnover,
				SUM(TurnoverNoDraw) AS NetTurnover,
				SUM(GrossComm) AS GrossComm,
				SUM(MemberWinLost) AS MemberWinLoss,
				SUM(PlayerComm) AS MemberComm,
				SUM(AgWinlost) AS AgWinLoss,
				SUM(AgComm) AS AgComm,
				SUM(NoOfTicket) AS NumberOfTickets,
				SUM(RewardAmount) AS RewardAmount,
				@CurrencyCode AS RewardCurrency
			FROM #AgWinLossDetails
			WHERE @UserName_CustId = 0 OR custid = @UserName_CustId;
		END
		ELSE
		BEGIN
			SELECT	c.CustID AS CustId, 
					CASE WHEN c.CustID = @CID THEN 'CASH SERVICE BILLING' ELSE c.UserName END AS CustName,
					CASE WHEN c.CustID != @CID THEN c.FirstName ELSE '' END AS FirstName, 
					CASE WHEN c.CustID != @CID THEN c.LastName ELSE '' END AS LastName,
					ISNULL(wl.IsExistedWatchList,0) IsExistedWatchList,
					SUM(TurnOver) AS Turnover,
					SUM(TurnoverNoDraw) AS NetTurnover,
					SUM(GrossComm) AS GrossComm,
					SUM(MemberWinLost) AS MemberWinLoss,
					SUM(PlayerComm) AS MemberComm,
					SUM(AgWinlost) AS AgWinLoss,
					SUM(AgComm) AS AgComm,
					SUM(NoOfTicket) AS NumberOfTickets,
					CASE WHEN c.CustID = @CID THEN 1 ELSE 0 END AS IsCashServiceBilling
			FROM #AgWinLossDetails w 
				LEFT JOIN dbo.Customer c WITH(NOLOCK) ON w.CustID = c.CustID 
				OUTER APPLY (SELECT 1 AS IsExistedWatchList FROM WLMonitored_Player wl WITH (NOLOCK) WHERE wl.CustID = w.custid AND wl.Sporttype = 0) AS wl	
			WHERE @UserName_CustId = 0 OR w.custid = @UserName_CustId
			GROUP BY c.CustID, c.UserName, c.FirstName, c.LastName,ISNULL(wl.IsExistedWatchList,0)
			ORDER BY IsCashServiceBilling ASC, IIF(c.Username IS NULL,1,0) ASC, c.Username ASC;

			SELECT	NULL AS CustId,
				'Total' AS CustName,
				SUM(TurnOver) AS Turnover,
				SUM(TurnoverNoDraw) AS NetTurnover,
				SUM(GrossComm) AS GrossComm,
				SUM(MemberWinLost) AS MemberWinLoss,
				SUM(PlayerComm) AS MemberComm,
				SUM(AgWinlost) AS AgWinLoss,
				SUM(AgComm) AS AgComm,
				SUM(NoOfTicket) AS NumberOfTickets
		FROM #AgWinLossDetails
		WHERE @UserName_CustId = 0 OR custid = @UserName_CustId;
	END
	END
	ELSE
	BEGIN
		IF @TotalRecords = 0  
		BEGIN  
			SELECT @TotalRecords = COUNT(tmp.CustID)
			FROM (
				SELECT CustID
				FROM #AgWinLossDetails
				WHERE @UserName_CustId = 0 OR custid = @UserName_CustId
				GROUP BY CustID
			) tmp;
		END

		IF @IsReward = 1
		BEGIN
			SELECT wl.CustId, wl.CustName, wl.FirstName, wl.LastName, wl.IsExistedWatchList,
				wl.Turnover, wl.NetTurnover, wl.GrossComm, wl.MemberWinLoss, wl.MemberComm, wl.AgWinLoss, wl.AgComm, wl.NumberOfTickets,
				wl.RewardAmount, wl.RewardCurrency, wl.RowNum, wl.IsCashServiceBilling
			FROM (
				SELECT	c.CustID AS CustId,
						CASE WHEN c.CustID = @CID THEN 'CASH SERVICE BILLING' ELSE c.UserName END AS CustName,
						CASE WHEN c.CustID != @CID THEN c.FirstName ELSE '' END AS FirstName, 
						CASE WHEN c.CustID != @CID THEN c.LastName ELSE '' END AS LastName,
						ISNULL(wl.IsExistedWatchList,0) IsExistedWatchList,
						SUM(TurnOver) AS Turnover,
						SUM(TurnoverNoDraw) AS NetTurnover,
						SUM(GrossComm) AS GrossComm,
						SUM(MemberWinLost) AS MemberWinLoss,
						SUM(PlayerComm) AS MemberComm,
						SUM(AgWinlost) AS AgWinLoss,
						SUM(AgComm) AS AgComm,
						SUM(NoOfTicket) AS NumberOfTickets,
						SUM(w.RewardAmount) AS RewardAmount,
						@CurrencyCode AS RewardCurrency,
						ROW_NUMBER() OVER (ORDER BY IIF(c.Username IS NULL,1,0) ASC, c.UserName ASC) AS RowNum,
						CASE WHEN c.CustID = @CID THEN 1 ELSE 0 END AS IsCashServiceBilling
				FROM #AgWinLossDetails w 
					LEFT JOIN dbo.Customer c WITH(NOLOCK) ON w.CustID = c.CustID 
					OUTER APPLY (SELECT 1 AS IsExistedWatchList FROM WLMonitored_Player wl WITH (NOLOCK) WHERE wl.CustID = w.custid AND wl.Sporttype = 0) AS wl
				WHERE @UserName_CustId = 0 OR w.custid = @UserName_CustId
				GROUP BY c.CustID, c.UserName, c.FirstName, c.LastName, ISNULL(wl.IsExistedWatchList,0)
			) wl
			WHERE wl.RowNum BETWEEN @RowStart AND @RowEnd
			ORDER BY wl.IsCashServiceBilling ASC, wl.RowNum ASC;

			SELECT	NULL AS CustId,
				'Total' AS CustName,
				SUM(TurnOver) AS Turnover,
				SUM(TurnoverNoDraw) AS NetTurnover,
				SUM(GrossComm) AS GrossComm,
				SUM(MemberWinLost) AS MemberWinLoss,
				SUM(PlayerComm) AS MemberComm,
				SUM(AgWinlost) AS AgWinLoss,
				SUM(AgComm) AS AgComm,
				SUM(NoOfTicket) AS NumberOfTickets,
				SUM(RewardAmount) AS RewardAmount,
				@CurrencyCode AS RewardCurrency
			FROM #AgWinLossDetails
			WHERE @UserName_CustId = 0 OR custid = @UserName_CustId;
		END
		ELSE
		BEGIN
			SELECT wl.CustId, wl.CustName, wl.FirstName, wl.LastName, wl.IsExistedWatchList,
				wl.Turnover, wl.NetTurnover, wl.GrossComm, wl.MemberWinLoss, wl.MemberComm, wl.AgWinLoss, wl.AgComm, wl.NumberOfTickets,
				wl.RowNum, wl.IsCashServiceBilling
			FROM (
				SELECT	c.CustID AS CustId,
						CASE WHEN c.CustID = @CID THEN 'CASH SERVICE BILLING' ELSE c.UserName END AS CustName,
						CASE WHEN c.CustID != @CID THEN c.FirstName ELSE '' END AS FirstName, 
						CASE WHEN c.CustID != @CID THEN c.LastName ELSE '' END AS LastName,
						ISNULL(wl.IsExistedWatchList,0) IsExistedWatchList,
						SUM(TurnOver) AS Turnover,
						SUM(TurnoverNoDraw) AS NetTurnover,
						SUM(GrossComm) AS GrossComm,
						SUM(MemberWinLost) AS MemberWinLoss,
						SUM(PlayerComm) AS MemberComm,
						SUM(AgWinlost) AS AgWinLoss,
						SUM(AgComm) AS AgComm,
						SUM(NoOfTicket) AS NumberOfTickets,
						ROW_NUMBER() OVER (ORDER BY IIF(c.Username IS NULL,1,0) ASC, c.UserName ASC) AS RowNum,
						CASE WHEN c.CustID = @CID THEN 1 ELSE 0 END AS IsCashServiceBilling
				FROM #AgWinLossDetails w 
					LEFT JOIN dbo.Customer c WITH(NOLOCK) ON w.CustID = c.CustID 
					OUTER APPLY (SELECT 1 AS IsExistedWatchList FROM WLMonitored_Player wl WITH (NOLOCK) WHERE wl.CustID = w.custid AND wl.Sporttype = 0) AS wl
				WHERE @UserName_CustId = 0 OR w.custid = @UserName_CustId
				GROUP BY c.CustID, c.UserName, c.FirstName, c.LastName, ISNULL(wl.IsExistedWatchList,0)
			) wl
			WHERE wl.RowNum BETWEEN @RowStart AND @RowEnd
			ORDER BY wl.IsCashServiceBilling ASC, wl.RowNum ASC;

				SELECT	NULL AS CustId,
					'Total' AS CustName,
					SUM(TurnOver) AS Turnover,
					SUM(TurnoverNoDraw) AS NetTurnover,
					SUM(GrossComm) AS GrossComm,
					SUM(MemberWinLost) AS MemberWinLoss,
					SUM(PlayerComm) AS MemberComm,
					SUM(AgWinlost) AS AgWinLoss,
					SUM(AgComm) AS AgComm,
					SUM(NoOfTicket) AS NumberOfTickets
			FROM #AgWinLossDetails
			WHERE @UserName_CustId = 0 OR custid = @UserName_CustId;
		END
	END	
END
GO