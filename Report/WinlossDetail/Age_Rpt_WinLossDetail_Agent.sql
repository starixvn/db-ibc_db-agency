/*<info serverAlias="DBAGE-bodb02" executers="wsv_alp,wsv_alpv" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Age_Rpt_WinLossDetail_Agent]
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
	@IsReward		BIT = 1,
	@LevelType		TINYINT = 0
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
    - 20240918@Lewis: Rebate Retention - Reward [RedmineId: #208503]
	- 20241129@Lewis: Enhance Perf SabaWalletTicket [RedmineId: #214431]
	- 20241119@Lewis: Direct Member [RedmineId: #211969]
	- 20250506@Bobby: Tuning perf IO on custinfo [RedmineId: #226284]
	- 20250605@Virgil: Cash Service - Billing service and Report changes [RedmineId: #227984]
	- 20250718@Virgil: Cash Service Billing - Sprint 6 - Enhance code [RedmineId: #231700]
	- 20250904@Virgil: Replace Task_sum_winloss with bettrans_compact [RedmineId: #235369]	
	- 20250924@Bobby: Enhance report for f_SportBettype_SumWinloss [RedmineId: #235369]	
	- 20251031@Bobby: Tuning IO for ExtraInfo [RedmineId: #243155]
	
	
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

	DECLARE @RowStart	INT,
			@RowEnd		INT;
		
	SELECT	@PageIndex = @PageIndex - 1,
			@RowStart = @PageSize * @PageIndex + 1,
			@RowEnd = @RowStart + @PageSize - 1;
	
	DROP TABLE IF EXISTS #MAgWinLossDetails;
	DROP TABLE IF EXISTS #TmpCondSumWL;
	DROP TABLE IF EXISTS #GrossComm;

	CREATE TABLE #MAgWinLossDetails
	(
		CustID			INT,
		TurnOver		MONEY,
		TurnoverNoDraw	MONEY,
		GrossComm		MONEY,
		MemberWinLost	MONEY,
		PlayerComm		MONEY,
		AgWinLost		MONEY,
		AgComm			MONEY,
		MAgWinLost		MONEY,
		MAgComm			MONEY,
		NoOfTicket		INT,
		RewardAmount	MONEY
	)

	CREATE TABLE #GrossComm (CustId INT, TurnoverNoDraw MONEY, GrossComm MONEY)

	CREATE TABLE #TmpCondSumWL(
		ProductID		TINYINT,
		SportType		INT,
		BetType			INT,
		LeagueGroupID	SMALLINT, 
		TicketType		TINYINT
	);

	DECLARE @ExistingProductDetails TABLE (ProductId INT,Sporttype INT,Bettype INT, LeagueGroupID SMALLINT, TicketType TINYINT)
	DECLARE @isTest BIT, @__ProductDetails XML;
	SELECT  @isTest = dbo.f_CheckSPVersion(@@PROCID);	

	SELECT @ProductIds = dbo.f_AddRelatedProducts(@ProductIds);
	SELECT @__ProductDetails = CONVERT(XML, @ProductDetails)

	INSERT INTO @ExistingProductDetails(ProductId,Sporttype,Bettype,LeagueGroupID,TicketType)
	SELECT ProductId,Sporttype,Bettype,LeagueGroupID,TicketType
	FROM dbo.f_ProductDetail_ConditionSel(@ProductDetails, @__ProductDetails)

	IF (@FromDate <= @MoveBetsDay OR CHARINDEX('111', @ProductIds) > 0)
	BEGIN
		INSERT INTO #TmpCondSumWL(ProductID, SportType, BetType, LeagueGroupID, TicketType) 
		SELECT sp.ProductID,
				ISNULL(e.SportType, sp.SportTypeRef) AS SportType,
				ISNULL(e.Bettype, sp.BetTypeRef) AS BetType,
				ISNULL(e.LeagueGroupID, sp.LeagueGroupID) AS LeagueGroupID,
				ISNULL(e.TicketType, sp.TicketType) AS TicketType
		FROM dbo.f_SportBettypeRefByProduct_Sel(@ProductIds) sp
			LEFT JOIN @ExistingProductDetails e ON e.ProductId = sp.ProductID
		WHERE e.ProductId IS NULL 
			OR (
				e.Bettype = sp.BetTypeRef 
				AND e.Sporttype = sp.SportTypeRef 
				AND e.TicketType = sp.TicketType 
				AND e.LeagueGroupID = sp.LeagueGroupID 
			)
	END

	------Get @Srecommend
	DECLARE @Srecommend int;
	DECLARE @CurrencyCode VARCHAR(12);

	SELECT @Srecommend = c.Srecommend,
		   @CurrencyCode = e.Code
	FROM dbo.CustInfo c WITH(NOLOCK)
	INNER JOIN dbo.Exchange e WITH (NOLOCK)
		ON c.currency = e.ExchangeId
	WHERE c.CustID = @CustID;

	--Avoid Parameter Sniffing for bettrans and sum_winloss
	DECLARE @FDate	SMALLDATETIME,
			@TDate	SMALLDATETIME,
			@CID	INT;
	    
	SELECT	@CID = @custid;

	--TODO: Search downline by username
	DECLARE @UserName_CustId INT,
		@totalDownline INT, 
		@downlineIds VARCHAR(MAX)

	IF ISNULL(@Username,'') <> ''	--@USERNAME IS NOT NULL		=> -1: No Data || >0: Exactly Username
	BEGIN
		SET @UserName_CustId = ISNULL((SELECT Custid FROM dbo.Customer WITH (NOLOCK) WHERE username = @UserName),-1)
		IF @UserName_CustId = -1
			GOTO OUTPUT_RESULT;

		WITH cte_downline AS(
			SELECT ci.custid
			FROM dbo.Customer ci WITH(NOLOCK)
			WHERE ci.custid = @UserName_CustId
				AND mrecommend = @CID
				AND ci.RoleId = 2
				AND @LevelType IN (0,1)

			UNION ALL

			SELECT ci.custid
			FROM dbo.Customer ci WITH(NOLOCK)
			WHERE ci.custid = @UserName_CustId
				AND mrecommend = @CID
				AND ci.RoleId = 1
				AND ci.recommend = -3
				AND @LevelType IN (0,2)
		)
		SELECT 
			@totalDownline	= COUNT(1), 
			@downlineIds	= STRING_AGG(CAST(cte.custid AS VARCHAR(MAX)), ',')
		FROM cte_downline cte
	END
	ELSE 
	BEGIN
		WITH cte_downline AS(
			SELECT ci.custid
			FROM dbo.Customer ci WITH(NOLOCK)
			WHERE mrecommend = @CID
				AND ci.RoleId = 2
				AND @LevelType IN (0,1)

			UNION ALL

			SELECT ci.custid
			FROM dbo.Customer ci WITH(NOLOCK)
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
		)
		INSERT INTO #MAgWinLossDetails(CustID, TurnOver, TurnoverNoDraw, GrossComm, MemberWinLost, PlayerComm, AgWinLost, AgComm, MAgWinLost, MAgComm, NoOfTicket)
		SELECT	b.custid,			
				SUM(b.turnover) AS TurnOver, 
				SUM(b.TurnoverNoDraw) AS TurnoverNoDraw,
				SUM(b.GrossComm) AS GrossComm,
				SUM(b.winlost) AS MemberWinlost,
				SUM(b.playercomm) AS PlayerComm,
				SUM(b.awinlost) AS AgWinlost,
				SUM(b.comm - b.playercomm) AS AgComm,
				SUM(b.mwinlost) AS MAgWinlost,
				SUM(b.acomm - b.comm) AS MAgComm,
				SUM(b.betcount) AS NoOfTicket
		FROM bodb_Age.dbo.bettrans_compact b WITH (NOLOCK)
		INNER JOIN CTE_Downline m ON m.custid = b.custid
		INNER JOIN (
			SELECT ISNULL(p.GroupProductId, f.ProductID) AS ProductID, f.BetType, ISNULL(e.LeagueGroupID,0) AS LeagueGroupID, ISNULL(e.TicketType,0) AS TicketType, ISNULL(e.SportType,0) AS SportType
			FROM (	
					SELECT DISTINCT ma.ProductID, ma.BetType, ma.BettypeRef
					FROM dbo.f_SportBettype_SumWinloss_Sel(@ProductIds, @isTest, NULL) ma
				) f
				LEFT JOIN dbo.f_GroupProduct() p ON f.ProductID = p.ProductId
				LEFT JOIN @ExistingProductDetails e ON e.ProductId = f.ProductID 
			WHERE e.ProductId IS NULL 
				OR e.Bettype = f.BetType 
				OR (e.Bettype = 0 AND (e.ProductId = 1 OR f.BettypeRef = 0))
		) s ON b.bettype = s.bettype 
			AND (s.ProductID <> 1 OR (s.ProductID = 1 AND b.sporttype = s.SportType AND b.LeagueGroupID = s.LeagueGroupID AND b.TicketType = s.TicketType))
		WHERE	b.winlostdate BETWEEN @FDate AND @TDate
		GROUP BY b.custid;

		-- Cash Service Billing 
		IF ',' + @ProductIDs + ',' LIKE '%,111,%'
		BEGIN
			;WITH CTE_Downline AS (
				SELECT TOP(@totalDownline) CAST([value] AS INT) AS custid
				FROM STRING_SPLIT(@downlineIds, ',') AS c
			)
			INSERT INTO #MAgWinLossDetails(CustID, TurnOver, TurnoverNoDraw, GrossComm, MemberWinLost, PlayerComm, AgWinLost, AgComm, MAgWinLost, MAgComm, NoOfTicket)
			SELECT tr.CustId,
					0 AS TurnOver, 
					0 AS TurnoverNoDraw,
					0 AS GrossComm,
					0 AS MemberWinlost,
					0 AS PlayerComm,
					SUM(WinLost-Actual_Stake) AS AgWinlost,
					0 AS AgComm,
					0 AS MAgWinlost,
					0 AS MAgComm,
					0 AS NoOfTicket
			FROM dbo.Transfer tr (NOLOCK)
				INNER JOIN CTE_Downline m ON m.custid = tr.custid
				INNER JOIN #TmpCondSumWL f ON tr.Bettype = f.BetType AND f.ProductID = 111
			WHERE tr.winlostdate BETWEEN @FDate AND @TDate
			GROUP BY tr.CustId;
		END

		-- bettransRnG
		INSERT INTO #GrossComm (CustId, TurnoverNoDraw, GrossComm)
		SELECT CASE WHEN b.recommend = -3 THEN b.custid ELSE b.recommend END AS CustId
			,SUM(CASE WHEN s.ContributionBettype IS NULL THEN b.BetStake ELSE 0 END) AS TurnoverNoDraw
			,SUM(b.BetStake * b.adiscount) AS GrossComm
		FROM dbo.bettransRnG b WITH(NOLOCK)
			INNER JOIN (
				SELECT	ISNULL(p.GroupProductId, f.ProductID) AS ProductID, f.BetType
					, IIF(f.BettypeGroup='Contribution', f.BetType, NULL) AS ContributionBettype
				FROM (	
						SELECT DISTINCT ma.ProductID, ma.BetType, ma.BettypeRef, ma.BettypeGroup
						FROM dbo.f_SportBettype_SumWinloss_Sel(@ProductIds, @isTest, 1) ma
					) f
					LEFT JOIN dbo.f_GroupProduct() p ON f.ProductID = p.ProductId
					LEFT JOIN @ExistingProductDetails e ON e.ProductId = f.ProductID 
				WHERE e.ProductId IS NULL 
					OR e.Bettype = f.BetType
					OR (e.Bettype = 0 AND (e.ProductId = 1 OR f.BettypeRef = 0))
			) s ON b.gameID = s.Bettype

		WHERE winlostdate BETWEEN @FDate AND @TDate
			AND statusID IN (111, 112, 113) 
			AND mrecommend = @CID
		GROUP BY CASE WHEN b.recommend = -3 THEN b.custid ELSE b.recommend END
		
		-- bettransLC
		INSERT INTO #GrossComm (CustId, TurnoverNoDraw, GrossComm)
		SELECT CASE WHEN b.recommend = -3 THEN b.custid ELSE b.recommend END AS CustId
			,SUM(CASE WHEN s.ContributionBettype IS NULL THEN b.NetStake ELSE 0 END) AS TurnoverNoDraw
			,SUM(b.NetStake * b.adiscount) AS GrossComm
		FROM dbo.bettransLC b WITH(NOLOCK)
			INNER JOIN (
				SELECT	DISTINCT ISNULL(p.GroupProductId, f.ProductID) AS ProductID, f.BetType
					, IIF(f.BettypeGroup='Contribution', f.BetType, NULL) AS ContributionBettype
				FROM (	
						SELECT DISTINCT ma.ProductID, ma.BetType, ma.BettypeRef, ma.BettypeGroup
						FROM dbo.f_SportBettype_SumWinloss_Sel(@ProductIds, @isTest, 2) ma
					) f
					LEFT JOIN dbo.f_GroupProduct() p ON f.ProductID = p.ProductId
					LEFT JOIN @ExistingProductDetails e ON e.ProductId = f.ProductID 
				WHERE e.ProductId IS NULL 
					OR e.Bettype = f.BetType
					OR (e.Bettype = 0 AND (e.ProductId = 1 OR f.BettypeRef = 0))
				
			) s ON b.gameID = s.Bettype

		WHERE winlostdate BETWEEN @FDate AND @TDate
			AND statusID IN (111, 112, 113) 
			AND mrecommend = @CID
		GROUP BY CASE WHEN b.recommend = -3 THEN b.custid ELSE b.recommend END

		IF EXISTS (SELECT 1 FROM #GrossComm)
		BEGIN
			UPDATE t
			SET t.TurnoverNoDraw = ISNULL(t.TurnoverNoDraw, 0) + ISNULL(c.TurnoverNoDraw, 0)
				,t.GrossComm = ISNULL(t.GrossComm, 0) + ISNULL(c.GrossComm, 0)
			FROM #MAgWinLossDetails t
				INNER JOIN (
					SELECT CustId, SUM(GrossComm) AS GrossComm, SUM(TurnoverNoDraw) AS TurnoverNoDraw FROM #GrossComm GROUP BY CustId
				) c ON t.CustId = c.CustId
		END
	END		
	
	--TODO: sum_winloss range
	SELECT @FDate = NULL, @TDate = NULL
	SELECT @FDate = FromDate , @TDate = ToDate
	FROM dbo.f_MBU_RangeDate(@FromDate, @ToDate, @BalanceUpDay, @MoveBetsDay)
	WHERE RangeType = 2;
	
	-- Get total sportbettype condition
	DECLARE @top_sportbettype INT;
    SELECT @top_sportbettype = COUNT(1) FROM #TmpCondSumWL;

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
		INSERT INTO #MAgWinLossDetails(CustID, TurnOver, TurnoverNoDraw, GrossComm, MemberWinLost, PlayerComm, AgWinLost, AgComm, MAgWinLost, MAgComm, NoOfTicket)
		SELECT	cte.CustID,			
				SUM(ABS(TurnOver)) AS TurnOver,
				SUM(ABS(TunroverNoDraw)) as TurnoverNoDraw,
				SUM(grosscomm) AS GrossComm,
				SUM(winlost) AS MemberWinlost,
				SUM(playercomm) AS PlayerComm,
				SUM(awinlost) AS AgWinlost,
				ISNULL(SUM(comm - playercomm), 0) AS AgComm,
				SUM(mwinlost) AS MAgWinlost,
				SUM(acomm) - SUM(comm) AS MAgComm,
				SUM(betcount) AS NoOfTicket
		FROM CTE_Downline cte
		CROSS APPLY
        (
            SELECT TOP(@top_sportbettype) b.TurnOver, b.TunroverNoDraw, b.grosscomm, b.winlost, b.playercomm, b.awinlost, b.comm, b.mwinlost, b.acomm, b.betcount
            FROM dbo.sum_winloss_compact b WITH(NOLOCK)
            INNER JOIN #TmpCondSumWL t 
              ON (
                b.sporttype = t.sporttype
                AND b.bettype = t.bettype 
                AND ISNULL(b.leagueGroupID,0) = t.LeagueGroupID 
                AND ISNULL(b.ticketType,0) = t.TicketType
              )
            WHERE b.winlostdate = cte.winlostdate
              AND b.srecommend = cte.srecommend
              AND b.mrecommend = cte.mrecommend 
              AND b.recommend = cte.recommend
              AND b.RoleID = cte.roleId
              AND b.custid = cte.custid      
        ) AS b
		GROUP BY cte.CustID
		OPTION (MAXRECURSION 0);

		-- Cash Service Billing 
		IF ',' + @ProductIDs + ',' LIKE '%,111,%'
		BEGIN
			;WITH CTE_Downline AS (
				SELECT TOP(@totalDownline) CAST([value] AS INT) AS custid
				FROM STRING_SPLIT(@downlineIds, ',') AS c
			)
			INSERT INTO #MAgWinLossDetails(CustID, TurnOver, TurnoverNoDraw, GrossComm, MemberWinLost, PlayerComm, AgWinLost, AgComm, MAgWinLost, MAgComm, NoOfTicket)
			SELECT tr.CustId,
					0 AS TurnOver, 
					0 AS TurnoverNoDraw,
					0 AS GrossComm,
					0 AS MemberWinlost,
					0 AS PlayerComm,
					SUM(WinLost-Actual_Stake) AS AgWinlost,
					0 AS AgComm,
					0 AS MAgWinlost,
					0 AS MAgComm,
					0 AS NoOfTicket
			FROM dbo.Transfer tr (NOLOCK)
				INNER JOIN CTE_Downline m ON m.custid = tr.custid
				INNER JOIN #TmpCondSumWL f ON tr.Bettype = f.BetType AND f.ProductID = 111
			WHERE tr.winlostdate BETWEEN @FDate AND @TDate
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
		INSERT INTO #MAgWinLossDetails(CustID, TurnOver, TurnoverNoDraw, GrossComm, MemberWinLost, PlayerComm, AgWinLost, AgComm, MAgWinLost, MAgComm, NoOfTicket)
		SELECT	b.CustID,			
				SUM(ABS(TurnOver)) AS TurnOver,
				SUM(ABS(TunroverNoDraw)) as TurnoverNoDraw,
				SUM(grosscomm) AS GrossComm,
				SUM(IIF(bt.ProductID = 111, 0, winlost)) AS MemberWinlost,
				SUM(playercomm) AS PlayerComm,
				SUM(IIF(bt.ProductID = 111, winlost, awinlost)) AS AgWinlost,
				ISNULL(SUM(comm - playercomm), 0) AS AgComm,
				SUM(mwinlost) AS MAgWinlost,
				SUM(acomm) - SUM(comm) AS MAgComm,
				SUM(betcount) AS NoOfTicket
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

	--TODO: SabaWalletTicket
	IF @IsReward = 1
	BEGIN
		SELECT @FDate = @FromDate, @TDate = @ToDate
		
		;WITH CTE_TransId AS (
			SELECT TransId 
			FROM SabaWalletTicket WITH (NOLOCK) 
			WHERE Mrecommend = @CID 
				AND WinlostDate BETWEEN @FDate AND @TDate
		), CTE_Downline AS (
			SELECT TOP(@totalDownline) CAST([value] AS INT) AS custid
			FROM STRING_SPLIT(@downlineIds, ',') AS c
		)
		INSERT INTO #MAgWinLossDetails(CustID,RewardAmount)
		SELECT CustID, RewardAmount
		FROM (
				SELECT CASE WHEN swt.Recommend = -3 THEN swt.CustID ELSE swt.Recommend END AS CustID, SUM(Amount) AS RewardAmount
				FROM SabaWalletTicket swt WITH (NOLOCK)
				INNER JOIN CTE_TransId cte ON swt.TransId = cte.TransId
				WHERE swt.WalletID = 2
				GROUP BY CASE WHEN swt.Recommend = -3 THEN swt.CustID ELSE swt.Recommend END
			) a
		WHERE EXISTS (SELECT TOP 1 1 FROM CTE_Downline cte WHERE cte.custid = a.CustID)
	END
	
	--TODO: Result
	OUTPUT_RESULT:
	IF ((@PageSize <= 0) AND (@PageIndex <= 0))
	BEGIN
		IF @IsReward = 1
		BEGIN
			SELECT	c.CustID AS CustId, 
					c.UserName AS CustName, 
					c.FirstName,
					c.LastName,
					SUM(TurnOver) AS Turnover,
					SUM(TurnoverNoDraw) as NetTurnover,
					SUM(GrossComm) AS GrossComm,
					--mem
					SUM(MemberWinLost) AS MemberWinLoss,
					SUM(PlayerComm) AS MemberComm,
					--agent
					SUM(AgWinlost) AS AgWinLoss,
					SUM(AgComm) AS AgComm,
					--master
					SUM(MAgWinlost) AS MAgWinLoss,
					SUM(MAgComm) AS MAgComm,
					SUM(NoOfTicket) AS NumberOfTickets,
					SUM(w.RewardAmount) AS RewardAmount,
					@CurrencyCode AS RewardCurrency,
					CASE WHEN c.roleid = 1 THEN 1 ELSE 0 END AS IsDirectMember
			FROM #MAgWinLossDetails w 
				LEFT JOIN dbo.Customer c WITH(NOLOCK) ON w.CustID = c.CustID
			GROUP BY c.CustID, c.UserName, c.FirstName, c.LastName, CASE WHEN c.roleid = 1 THEN 1 ELSE 0 END
			ORDER BY IIF(c.Username IS NULL,1,0) ASC, c.Username ASC;

			SELECT	NULL AS CustId,
					'Total' AS CustName,
					SUM(TurnOver) AS Turnover,
					SUM(TurnoverNoDraw) as NetTurnover,
					SUM(GrossComm) AS GrossComm,
					--mem
					SUM(MemberWinLost) AS MemberWinLoss,
					SUM(PlayerComm) AS MemberComm,
					--agent
					SUM(AgWinlost) AS AgWinLoss,
					SUM(AgComm) AS AgComm,
					--master
					SUM(MAgWinlost) AS MAgWinLoss,
					SUM(MAgComm) AS MAgComm,
					SUM(NoOfTicket) AS NumberOfTickets,
					SUM(RewardAmount) AS RewardAmount,
					@CurrencyCode AS RewardCurrency
			FROM #MAgWinLossDetails w;
		END
		ELSE
		BEGIN
			SELECT	c.CustID AS CustId, 
					c.UserName AS CustName, 
					c.FirstName,
					c.LastName,
					SUM(TurnOver) AS Turnover,
					SUM(TurnoverNoDraw) as NetTurnover,
					SUM(GrossComm) AS GrossComm,
					--mem
					SUM(MemberWinLost) AS MemberWinLoss,
					SUM(PlayerComm) AS MemberComm,
					--agent
					SUM(AgWinlost) AS AgWinLoss,
					SUM(AgComm) AS AgComm,
					--master
					SUM(MAgWinlost) AS MAgWinLoss,
					SUM(MAgComm) AS MAgComm,
					SUM(NoOfTicket) AS NumberOfTickets,
					CASE WHEN c.roleid = 1 THEN 1 ELSE 0 END AS IsDirectMember
			FROM #MAgWinLossDetails w 
				LEFT JOIN dbo.Customer c WITH(NOLOCK) ON w.CustID = c.CustID
			GROUP BY c.CustID, c.UserName, c.FirstName, c.LastName, CASE WHEN c.roleid = 1 THEN 1 ELSE 0 END
			ORDER BY IIF(c.Username IS NULL,1,0) ASC, c.Username ASC;

			SELECT	NULL AS CustId,
					'Total' AS CustName,
					SUM(TurnOver) AS Turnover,
					SUM(TurnoverNoDraw) as NetTurnover,
					SUM(GrossComm) AS GrossComm,
					SUM(MemberWinLost) AS MemberWinLoss,
					SUM(PlayerComm) AS MemberComm,
					SUM(AgWinlost) AS AgWinLoss,
					SUM(AgComm) AS AgComm,
					SUM(MAgWinlost) AS MAgWinLoss,
					SUM(MAgComm) AS MAgComm,
					SUM(NoOfTicket) AS NumberOfTickets
			FROM #MAgWinLossDetails
		END
	END
	ELSE
	BEGIN
		IF @TotalRecords = 0  
		BEGIN  
			SELECT @TotalRecords = count(tmp.CustID)
			FROM (
				SELECT CustID
				FROM #MAgWinLossDetails
				GROUP BY CustID
			) tmp; 
		END

		IF @IsReward = 1
		BEGIN
			SELECT wl.CustId, wl.CustName, wl.FirstName, wl.LastName, wl.Turnover, wl.NetTurnover, wl.GrossComm,
				   wl.MemberWinLoss, wl.MemberComm, wl.AgWinLoss, wl.AgComm, wl.MAgWinLoss, wl.MAgComm, wl.NumberOfTickets,
				   wl.RewardAmount, wl.RewardCurrency, wl.RowNum, wl.IsDirectMember
			FROM (
				SELECT	c.CustID AS CustId, 
						c.UserName AS CustName, 
						c.FirstName,
						c.LastName,
						SUM(TurnOver) AS Turnover,
						SUM(TurnoverNoDraw) AS NetTurnover,
						SUM(GrossComm) AS GrossComm,
						SUM(MemberWinLost) AS MemberWinLoss,
						SUM(PlayerComm) AS MemberComm,
						SUM(AgWinlost) AS AgWinLoss,
						SUM(AgComm) AS AgComm,
						SUM(MAgWinlost) AS MAgWinLoss,
						SUM(MAgComm) AS MAgComm,
						SUM(NoOfTicket) AS NumberOfTickets,
						SUM(w.RewardAmount) AS RewardAmount,
						@CurrencyCode AS RewardCurrency,
						ROW_NUMBER() OVER (ORDER BY IIF(c.Username IS NULL,1,0) ASC, c.UserName ASC) AS RowNum,
						CASE WHEN c.roleid = 1 THEN 1 ELSE 0 END AS IsDirectMember
				FROM #MAgWinLossDetails w
					LEFT JOIN dbo.Customer c WITH(NOLOCK) ON w.CustID = c.CustID
				GROUP BY c.CustID, c.UserName, c.FirstName, c.LastName, CASE WHEN c.roleid = 1 THEN 1 ELSE 0 END
			) wl
			WHERE wl.RowNum BETWEEN @RowStart AND @RowEnd;

			SELECT	NULL AS CustId,
					'Total' AS CustName,
					SUM(TurnOver) AS Turnover,
					SUM(TurnoverNoDraw) as NetTurnover,
					SUM(GrossComm) AS GrossComm,
					SUM(MemberWinLost) AS MemberWinLoss,
					SUM(PlayerComm) AS MemberComm,
					SUM(AgWinlost) AS AgWinLoss,
					SUM(AgComm) AS AgComm,
					SUM(MAgWinlost) AS MAgWinLoss,
					SUM(MAgComm) AS MAgComm,
					SUM(NoOfTicket) AS NumberOfTickets,
					SUM(RewardAmount) AS RewardAmount,
					@CurrencyCode AS RewardCurrency
			FROM #MAgWinLossDetails;
		END
		ELSE
		BEGIN
			SELECT wl.CustId, wl.CustName, wl.FirstName, wl.LastName, wl.Turnover, wl.NetTurnover, wl.GrossComm,
				   wl.MemberWinLoss, wl.MemberComm, wl.AgWinLoss, wl.AgComm, wl.MAgWinLoss, wl.MAgComm, wl.NumberOfTickets,
				   wl.RowNum, wl.IsDirectMember
			FROM (
				SELECT	c.CustID AS CustId, 
						c.UserName AS CustName, 
						c.FirstName,
						c.LastName,
						SUM(TurnOver) AS Turnover,
						SUM(TurnoverNoDraw) AS NetTurnover,
						SUM(GrossComm) AS GrossComm,
						SUM(MemberWinLost) AS MemberWinLoss,
						SUM(PlayerComm) AS MemberComm,
						SUM(AgWinlost) AS AgWinLoss,
						SUM(AgComm) AS AgComm,
						SUM(MAgWinlost) AS MAgWinLoss,
						SUM(MAgComm) AS MAgComm,
						SUM(NoOfTicket) AS NumberOfTickets,
						ROW_NUMBER() OVER (ORDER BY IIF(c.Username IS NULL,1,0) ASC, c.UserName ASC) AS RowNum,
						CASE WHEN c.roleid = 1 THEN 1 ELSE 0 END AS IsDirectMember
				FROM #MAgWinLossDetails w
					LEFT JOIN dbo.Customer c WITH(NOLOCK) ON w.CustID = c.CustID
				GROUP BY c.CustID, c.UserName, c.FirstName, c.LastName, CASE WHEN c.roleid = 1 THEN 1 ELSE 0 END
			) wl
			WHERE wl.RowNum BETWEEN @RowStart AND @RowEnd;

			SELECT	NULL AS CustId,
					'Total' AS CustName,
					SUM(TurnOver) AS Turnover,
					SUM(TurnoverNoDraw) as NetTurnover,
					SUM(GrossComm) AS GrossComm,
					SUM(MemberWinLost) AS MemberWinLoss,
					SUM(PlayerComm) AS MemberComm,
					SUM(AgWinlost) AS AgWinLoss,
					SUM(AgComm) AS AgComm,
					SUM(MAgWinlost) AS MAgWinLoss,
					SUM(MAgComm) AS MAgComm,
					SUM(NoOfTicket) AS NumberOfTickets
			FROM #MAgWinLossDetails;
		END
	END
END
GO
