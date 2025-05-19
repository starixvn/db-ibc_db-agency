/*<info serverAlias="DBAGE-bodb02" executers="wsv_alp,wsv_alpv" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Age_Rpt_WinLossDetail_Master]
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
	- 20181003@Patrick: Index revolution [RedmineID: #101405]
	- 20190826@Percy: Remove inactive products [RedmineID: #118699]
	- 20200410@Sophia: Add BBIN, Sexy Gaming, SA Gaming [RedmineId: #131358]
	- 20200422@Sophia: Add IBCBet Live Casino [RedmineId: #130693]
	- 20200521@Patrick: Enhance SP due to bot attack [redmind: #134415]
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
	- 20241127@Bobby: Enhance Perf bettrans_compact [RedmineId: #214299]
	- 20241129@Lewis: Enhance Perf SabaWalletTicket [RedmineId: #214431]
	- 20241119@Lewis: Direct Member [RedmineId: #211969]
	- 20250506@Bobby: Tuning perf IO on custinfo [RedmineId: #226284]
	
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
			@RowEnd		INT

	SELECT	@PageIndex = @PageIndex - 1,
			@RowStart = @PageSize * @PageIndex + 1,
			@RowEnd = @RowStart + @PageSize - 1;

	DROP TABLE IF EXISTS #SAgWinLossDetails;
	DROP TABLE IF EXISTS #TmpCondSumWL;
	DROP TABLE IF EXISTS #GrossComm;

	CREATE TABLE #SAgWinLossDetails
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
		SAgWinLost		MONEY,
		SAgComm			MONEY,
		NoOfTicket		INT,
		RewardAmount	MONEY
	);

	CREATE TABLE #GrossComm (CustId INT, TurnoverNoDraw MONEY, GrossComm MONEY)

	CREATE TABLE #TmpCondSumWL(
		SportType		INT,
		BetType			INT,
		LeagueGroupID	SMALLINT,
		TicketType		TINYINT
	);

	DECLARE @ExistingProductDetails TABLE (ProductId INT,Sporttype SMALLINT,Bettype INT, LeagueGroupID SMALLINT, TicketType TINYINT)
	DECLARE @isTest BIT, @__ProductDetails XML;

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

	--Avoid Parameter Sniffing for bettrans and sum_winloss
	DECLARE @FDate	SMALLDATETIME,
			@TDate	SMALLDATETIME,
			@CID	INT;
	    
	SELECT	@CID = @custid;
	
	DECLARE @CurrencyCode VARCHAR(12);
	SELECT @CurrencyCode = e.Code
	FROM dbo.custInfo c WITH (NOLOCK)
	INNER JOIN dbo.Exchange e WITH (NOLOCK) 
		ON c.currency = e.ExchangeId
	WHERE c.custid = @CID

	--Usernames
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
				AND srecommend = @CID
				AND ci.RoleId = 3
				AND @LevelType IN (0,1)

			UNION ALL

			SELECT ci.custid
			FROM dbo.Customer ci WITH(NOLOCK)
			WHERE ci.custid = @UserName_CustId
				AND srecommend = @CID
				AND ci.RoleId = 1
				AND mrecommend = -4
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
			WHERE srecommend = @CID
				AND ci.RoleId = 3
				AND @LevelType IN (0,1)

			UNION ALL

			SELECT ci.custid
			FROM dbo.Customer ci WITH(NOLOCK)
			WHERE srecommend = @CID
				AND ci.RoleId = 1
				AND mrecommend = -4
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
		INSERT INTO #SAgWinLossDetails(CustID, TurnOver, TurnoverNoDraw, GrossComm, MemberWinLost, PlayerComm, AgWinLost, AgComm, MAgWinLost, MAgComm, SAgWinLost, SAgComm, NoOfTicket)
		SELECT	b.custid,
				SUM(b.turnover) as TurnOver,
				SUM(b.TurnoverNoDraw) AS TurnoverNoDraw,
				SUM(b.GrossComm) AS GrossComm,
				SUM(b.winlost) AS MemberWinlost,
				SUM(b.playercomm) AS PlayerComm,
				SUM(b.awinlost) AS AgWinlost,
				SUM(b.comm - b.playercomm) AS AgComm,
				SUM(b.mwinlost) AS MAgWinlost,
				SUM(b.acomm - b.comm) AS MAgComm,
				SUM(b.swinlost) AS SAgWinlost,
				SUM(b.scomm - b.acomm) AS SAgComm,
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
			WHERE EXISTS( SELECT 1 WHERE e.ProductId IS NULL 
						OR (
							e.Bettype = f.BetType 
							OR (
								e.Bettype = 0  AND  (e.ProductId = 1 OR  f.BetType NOT IN (SELECT g.Bettype FROM f_GetProductDetail() g WHERE g.ProductId <> 1) )
								)
							)
						)
		) s ON b.bettype = s.bettype AND (s.ProductID <> 1 OR (s.ProductID = 1 AND b.sporttype = s.SportType AND b.LeagueGroupID = s.LeagueGroupID AND b.TicketType = s.TicketType))
		WHERE winlostdate BETWEEN @FDate AND @TDate
		GROUP BY b.custid;
		
		-- bettransRnG
		INSERT INTO #GrossComm (CustId, TurnoverNoDraw, GrossComm)
		SELECT CASE WHEN b.mrecommend = -4 THEN b.custid ELSE b.mrecommend END AS CustId
			,SUM(CASE WHEN cont.ContributionBettype IS NULL THEN b.BetStake ELSE 0 END) AS TurnoverNoDraw
			,SUM(b.BetStake * b.sdiscount) AS GrossComm
		FROM dbo.bettransRnG b WITH(NOLOCK)
			INNER JOIN (
							SELECT	ISNULL(p.GroupProductId, f.ProductID) AS ProductID, f.BetType, f.RefTable, ISNULL(e.LeagueGroupID,0) AS LeagueGroupID, ISNULL(e.TicketType,0) AS TicketType, ISNULL(SportType,0) AS SportType
							FROM (	
									SELECT DISTINCT ma.ProductID, ma.BetType, ma.RefTable
									FROM  dbo.SportBettypeMatrix ma WITH(NOLOCK)
									WHERE ',' + @ProductIDs + ',' LIKE '%,' + cast(ma.ProductID as varchar(3)) + ',%'
											AND (ma.IsTest = 0 OR ma.IsTest = @IsTest) AND ma.RefTable = 1
								 ) f
								LEFT JOIN dbo.f_GroupProduct() p ON f.ProductID = p.ProductId
								LEFT JOIN @ExistingProductDetails e ON e.ProductId = f.ProductID 
							WHERE EXISTS(SELECT 1 WHERE e.ProductId IS NULL 
										OR 
											(
												e.Bettype = f.BetType 
														OR (
																e.Bettype = 0  AND  (e.ProductId = 1 OR  f.BetType NOT IN (SELECT g.Bettype FROM f_GetProductDetail() g WHERE g.ProductId <> 1) )
															)
											)
										)
									
						) s ON b.gameID = s.Bettype
			OUTER APPLY 
			(
				SELECT f.Bettype AS ContributionBettype
				FROM dbo.f_BettypePrizeGroup() f
				WHERE f.BettypeGroup = 'Contribution'
					AND f.Bettype = b.gameID
			) cont
		WHERE winlostdate BETWEEN @FDate AND @TDate
			AND statusID IN (111, 112, 113) 
			AND srecommend = @CID
		GROUP BY CASE WHEN b.mrecommend = -4 THEN b.custid ELSE b.mrecommend END

		-- bettransLC
		INSERT INTO #GrossComm (CustId, TurnoverNoDraw, GrossComm)
		SELECT CASE WHEN b.mrecommend = -4 THEN b.custid ELSE b.mrecommend END AS CustId
			,SUM(CASE WHEN cont.ContributionBettype IS NULL THEN b.NetStake ELSE 0 END) AS TurnoverNoDraw
			,SUM(b.NetStake * b.sdiscount) AS GrossComm
		FROM dbo.bettransLC b WITH(NOLOCK)
			INNER JOIN (
							SELECT	ISNULL(p.GroupProductId, f.ProductID) AS ProductID, f.BetType, f.RefTable, ISNULL(e.LeagueGroupID,0) AS LeagueGroupID, ISNULL(e.TicketType,0) AS TicketType, ISNULL(SportType,0) AS SportType
							FROM (	
									SELECT DISTINCT ma.ProductID, ma.BetType, ma.RefTable
									FROM  dbo.SportBettypeMatrix ma WITH(NOLOCK)
									WHERE ',' + @ProductIDs + ',' LIKE '%,' + cast(ma.ProductID as varchar(3)) + ',%'
											AND (ma.IsTest = 0 OR ma.IsTest = @IsTest) AND ma.RefTable = 2
								 ) f
								LEFT JOIN dbo.f_GroupProduct() p ON f.ProductID = p.ProductId
								LEFT JOIN @ExistingProductDetails e ON e.ProductId = f.ProductID 
							WHERE EXISTS(SELECT 1 WHERE e.ProductId IS NULL 
										OR 
											(
												e.Bettype = f.BetType 
														OR (
																e.Bettype = 0  AND  (e.ProductId = 1 OR  f.BetType NOT IN (SELECT g.Bettype FROM f_GetProductDetail() g WHERE g.ProductId <> 1) )
															)
											)
										)
									
						) s ON b.gameID = s.Bettype
			OUTER APPLY 
			(
				SELECT f.Bettype AS ContributionBettype
				FROM dbo.f_BettypePrizeGroup() f
				WHERE f.BettypeGroup = 'Contribution'
					AND f.Bettype = b.gameID
			) cont
		WHERE winlostdate BETWEEN @FDate AND @TDate
			AND statusID IN (111, 112, 113) 
			AND srecommend = @CID
		GROUP BY CASE WHEN b.mrecommend = -4 THEN b.custid ELSE b.mrecommend END

		IF EXISTS (SELECT 1 FROM #GrossComm)
		BEGIN
			UPDATE t
			SET t.TurnoverNoDraw = ISNULL(t.TurnoverNoDraw, 0) + ISNULL(c.TurnoverNoDraw, 0)
				,t.GrossComm = ISNULL(t.GrossComm, 0) + ISNULL(c.GrossComm, 0)
			FROM #SAgWinLossDetails t
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
		INSERT INTO #SAgWinLossDetails(CustID, TurnOver, TurnoverNoDraw, GrossComm, MemberWinLost, PlayerComm, AgWinLost, AgComm, MAgWinLost, MAgComm, SAgWinLost, SAgComm, NoOfTicket)
		SELECT	b.CustID,			
				SUM(ABS(TurnOver)) AS TurnOver,
				SUM(ABS(TunroverNoDraw)) AS TurnoverNoDraw,
				SUM(grosscomm) AS GrossComm,
				SUM(winlost) AS MemberWinlost,
				SUM(playercomm) AS PlayerComm,
				SUM(awinlost) AS AgWinlost,
				ISNULL(SUM(comm - playercomm),0) AS AgComm,
				SUM(mwinlost) AS MAgWinlost,
				SUM(acomm) - SUM(comm) AS MAgComm,
				SUM(swinlost) AS SAgWinlost,
				ISNULL(SUM(scomm),0) - ISNULL(SUM(acomm),0) AS SAgComm,
				SUM(betcount) AS NoOfTicket
		FROM dbo.SUM_winloss b WITH(NOLOCK)
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
		INSERT INTO #SAgWinLossDetails(CustID, TurnOver, TurnoverNoDraw, GrossComm, MemberWinLost, PlayerComm, AgWinLost, AgComm, MAgWinLost, MAgComm, SAgWinLost, SAgComm, NoOfTicket)
		SELECT	b.CustID,			
				SUM(ABS(TurnOver)) AS TurnOver,
				SUM(ABS(TunroverNoDraw)) AS TurnoverNoDraw,
				SUM(grosscomm) AS GrossComm,
				SUM(winlost) AS MemberWinlost,
				SUM(playercomm) AS PlayerComm,
				SUM(awinlost) AS AgWinlost,
				ISNULL(SUM(comm - playercomm),0) AS AgComm,
				SUM(mwinlost) AS MAgWinlost,
				SUM(acomm) - SUM(comm) AS MAgComm,
				SUM(swinlost) AS SAgWinlost,
				ISNULL(SUM(scomm),0) - ISNULL(SUM(acomm),0) AS SAgComm,
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
			WHERE Srecommend = @CID 
				AND WinlostDate BETWEEN @FDate AND @TDate
		), CTE_Downline AS (
			SELECT TOP(@totalDownline) CAST([value] AS INT) AS custid
			FROM STRING_SPLIT(@downlineIds, ',') AS c
		)
		INSERT INTO #SAgWinLossDetails(CustID,RewardAmount)
		SELECT CustID,RewardAmount 
		FROM (
				SELECT CASE WHEN swt.Mrecommend = - 4 THEN swt.CustID ELSE swt.Mrecommend END AS CustID ,SUM(Amount) AS RewardAmount
				FROM SabaWalletTicket swt WITH (NOLOCK) 
				INNER JOIN CTE_TransId cte ON swt.TransId = cte.TransId
				WHERE WalletID = 2
				GROUP BY CASE WHEN swt.Mrecommend = - 4 THEN swt.CustID ELSE swt.Mrecommend END 
			) a
		WHERE EXISTS (SELECT TOP 1 1 FROM CTE_Downline cte WHERE cte.custid = a.CustID)		
	END

	--TODO: Result
	OUTPUT_RESULT:
	IF ((@PageSize <= 0) AND (@PageIndex <= 0))
	BEGIN
		IF @IsReward =1
		BEGIN
			SELECT	c.CustID AS CustId, 
				c.UserName AS CustName, 
				c.FirstName,
				c.LastName,
				SUM(TurnOver) as Turnover,
				SUM(TurnoverNoDraw) as NetTurnover,
				SUM(GrossComm) as GrossComm,
				--mem
				SUM(MemberWinLost) as MemberWinLoss,
				SUM(PlayerComm) as MemberComm,
				--agent
				SUM(AgWinlost) as AgWinLoss,
				SUM(AgComm) as AgComm,
				--master
				SUM(MAgWinlost) as MAgWinLoss,
				SUM(MAgComm) as MAgComm,
				--super
				SUM(SAgWinlost) as SAgWinLoss,
				SUM(SAgComm) as SAgComm,
				SUM(NoOfTicket) as NumberOfTickets,
				SUM(w.RewardAmount) AS RewardAmount,
				@CurrencyCode AS RewardCurrency,
				CASE WHEN c.roleid = 1 THEN 1 ELSE 0 END AS IsDirectMember
			FROM #SAgWinLossDetails w 
				LEFT JOIN dbo.Customer c WITH(NOLOCK) ON w.CustID = c.CustID
			GROUP BY c.CustID, c.UserName, c.FirstName, c.LastName, CASE WHEN c.roleid = 1 THEN 1 ELSE 0 END
			ORDER BY IIF(c.Username IS NULL,1,0),c.Username;

			SELECT	NULL AS CustId,
				'Total' AS CustName,
				SUM(TurnOver) as Turnover,
				SUM(TurnoverNoDraw) as NetTurnover,
				SUM(GrossComm) as GrossComm,
				--mem
				SUM(MemberWinLost) as MemberWinLoss,
				SUM(PlayerComm) as MemberComm,
				--agent
				SUM(AgWinlost) as AgWinLoss,
				SUM(AgComm) as AgComm,
				--master
				SUM(MAgWinlost) as MAgWinLoss,
				SUM(MAgComm) as MAgComm,
				--super
				SUM(SAgWinlost) as SAgWinLoss,
				SUM(SAgComm) as SAgComm,
				SUM(NoOfTicket) as NumberOfTickets,
				SUM(RewardAmount) AS RewardAmount,
				@CurrencyCode AS RewardCurrency
			FROM #SAgWinLossDetails w;
		END
		ELSE
		BEGIN
			SELECT	c.CustID AS CustId, 
				c.UserName AS CustName, 
				c.FirstName,
				c.LastName,
				SUM(TurnOver) as Turnover,
				SUM(TurnoverNoDraw) as NetTurnover,
				SUM(GrossComm) as GrossComm,
				--mem
				SUM(MemberWinLost) as MemberWinLoss,
				SUM(PlayerComm) as MemberComm,
				--agent
				SUM(AgWinlost) as AgWinLoss,
				SUM(AgComm) as AgComm,
				--master
				SUM(MAgWinlost) as MAgWinLoss,
				SUM(MAgComm) as MAgComm,
				--super
				SUM(SAgWinlost) as SAgWinLoss,
				SUM(SAgComm) as SAgComm,
				SUM(NoOfTicket) as NumberOfTickets,
				CASE WHEN c.roleid = 1 THEN 1 ELSE 0 END AS IsDirectMember
			FROM #SAgWinLossDetails w 
				LEFT JOIN dbo.Customer c WITH(NOLOCK) ON w.CustID = c.CustID
			GROUP BY c.CustID, c.UserName, c.FirstName, c.LastName, CASE WHEN c.roleid = 1 THEN 1 ELSE 0 END
			ORDER BY IIF(c.Username IS NULL,1,0),c.Username;

			SELECT	NULL AS CustId,
					'Total' AS CustName,
					SUM(TurnOver) as Turnover,
					SUM(TurnoverNoDraw) as NetTurnover,
					SUM(GrossComm) as GrossComm,
					--mem
					SUM(MemberWinLost) as MemberWinLoss,
					SUM(PlayerComm) as MemberComm,
					--agent
					SUM(AgWinlost) as AgWinLoss,
					SUM(AgComm) as AgComm,
					--master
					SUM(MAgWinlost) as MAgWinLoss,
					SUM(MAgComm) as MAgComm,
					--super
					SUM(SAgWinlost) as SAgWinLoss,
					SUM(SAgComm) as SAgComm,
					SUM(NoOfTicket) as NumberOfTickets
			FROM #SAgWinLossDetails w;
		END
	END
	ELSE
	BEGIN
		IF @TotalRecords = 0  
		BEGIN  
			SELECT @TotalRecords = count(tmp.CustID)
			FROM (
				SELECT CustID
				FROM #SAgWinLossDetails
				GROUP BY CustID
			) tmp;
		END

		IF @IsReward = 1
		BEGIN
			SELECT wl.*
			FROM (
				SELECT	c.CustID AS CustId, 
						c.UserName AS CustName, 
						c.FirstName,
						c.LastName,
						SUM(TurnOver) as Turnover,
						SUM(TurnoverNoDraw) as NetTurnover,
						SUM(GrossComm) as GrossComm,
						--mem
						SUM(MemberWinLost) as MemberWinLoss,
						SUM(PlayerComm) as MemberComm,
						--agent
						SUM(AgWinlost) as AgWinLoss,
						SUM(AgComm) as AgComm,
						--master
						SUM(MAgWinlost) as MAgWinLoss,
						SUM(MAgComm) as MAgComm,
						--super
						SUM(SAgWinlost) as SAgWinLoss,
						SUM(SAgComm) as SAgComm,
						SUM(NoOfTicket) as NumberOfTickets,
						SUM(w.RewardAmount) as RewardAmount,
						@CurrencyCode AS RewardCurrency,
						ROW_NUMBER() over(order by IIF(c.Username IS NULL,1,0),c.UserName) as RowNum,
						CASE WHEN c.roleid = 1 THEN 1 ELSE 0 END AS IsDirectMember
				FROM #SAgWinLossDetails w 
					LEFT JOIN dbo.Customer c WITH(NOLOCK) ON w.CustID = c.CustID
				GROUP BY c.CustID, c.UserName, c.FirstName, c.LastName, CASE WHEN c.roleid = 1 THEN 1 ELSE 0 END
			) wl
			WHERE wl.RowNum BETWEEN @RowStart AND @RowEnd;

			SELECT	NULL AS CustId,
					'Total' AS CustName,
					SUM(TurnOver) as Turnover,
					SUM(TurnoverNoDraw) as NetTurnover,
					SUM(GrossComm) as GrossComm,
					--mem
					SUM(MemberWinLost) as MemberWinLoss,
					SUM(PlayerComm) as MemberComm,
					--agent
					SUM(AgWinlost) as AgWinLoss,
					SUM(AgComm) as AgComm,
					--master
					SUM(MAgWinlost) as MAgWinLoss,
					SUM(MAgComm) as MAgComm,
					--super
					SUM(SAgWinlost) as SAgWinLoss,
					SUM(SAgComm) as SAgComm,
					SUM(NoOfTicket) as NumberOfTickets,
					SUM(RewardAmount) as RewardAmount,
					@CurrencyCode AS RewardCurrency
			FROM #SAgWinLossDetails w;
		END
		ELSE
		BEGIN
			SELECT wl.*
			FROM (
				SELECT	c.CustID AS CustId, 
						c.UserName AS CustName, 
						c.FirstName,
						c.LastName,
						SUM(TurnOver) as Turnover,
						SUM(TurnoverNoDraw) as NetTurnover,
						SUM(GrossComm) as GrossComm,
						--mem
						SUM(MemberWinLost) as MemberWinLoss,
						SUM(PlayerComm) as MemberComm,
						--agent
						SUM(AgWinlost) as AgWinLoss,
						SUM(AgComm) as AgComm,
						--master
						SUM(MAgWinlost) as MAgWinLoss,
						SUM(MAgComm) as MAgComm,
						--super
						SUM(SAgWinlost) as SAgWinLoss,
						SUM(SAgComm) as SAgComm,
						SUM(NoOfTicket) as NumberOfTickets,
						ROW_NUMBER() over(order by IIF(c.Username IS NULL,1,0),c.UserName) as RowNum,
						CASE WHEN c.roleid = 1 THEN 1 ELSE 0 END AS IsDirectMember
				FROM #SAgWinLossDetails w 
					LEFT JOIN dbo.Customer c WITH(NOLOCK) ON w.CustID = c.CustID
				GROUP BY c.CustID, c.UserName, c.FirstName, c.LastName, CASE WHEN c.roleid = 1 THEN 1 ELSE 0 END
			) wl
			WHERE wl.RowNum BETWEEN @RowStart AND @RowEnd;

			SELECT	NULL AS CustId,
					'Total' AS CustName,
					SUM(TurnOver) as Turnover,
					SUM(TurnoverNoDraw) as NetTurnover,
					SUM(GrossComm) as GrossComm,
					--mem
					SUM(MemberWinLost) as MemberWinLoss,
					SUM(PlayerComm) as MemberComm,
					--agent
					SUM(AgWinlost) as AgWinLoss,
					SUM(AgComm) as AgComm,
					--master
					SUM(MAgWinlost) as MAgWinLoss,
					SUM(MAgComm) as MAgComm,
					--super
					SUM(SAgWinlost) as SAgWinLoss,
					SUM(SAgComm) as SAgComm,
					SUM(NoOfTicket) as NumberOfTickets
			FROM #SAgWinLossDetails;
		END
	END
END

GO