/*<info serverAlias="DBAGE-bodb02" executers="wsv_alp,wsv_alpv" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Age_Rpt_API_WinLossDetail_Agent] 
	@CustID			 INT = NULL --mrecommend
	,@FromDate		 SMALLDATETIME
	,@ToDate		 SMALLDATETIME
	,@ProductIds	 VARCHAR(MAX)
	,@ProductDetails NVARCHAR(MAX) = 'All'
	,@BalanceUpDay	 SMALLDATETIME
	,@MoveBetsDay	 SMALLDATETIME
	,@LevelType		 TINYINT = 0
AS

/*
	Created: 20240321@Bobby
	Task : EXT-API - Change source bettrans to bettrans_compact
	DB: DBAGE/bodb02
	Original:Age_Rpt_API_WinLossDetail_Agent

	Revisions:
		- 20221128@Eddie: Change from SP "Age_Rpt_WinLossDetail_Agent" [RedmineID: #171247]
		- 20230511@Eddie: Enhance data range [RedmineID: #188033]
		- 20230707@Bobby: Support NetTO & GrossComm [RedmineID: #188035]
		- 20240321@Bobby: Change source bettrans to bettrans_compact [RedmineID: #202655]
		- 20240424@Lewis: Change old sql account [Redmine: #204021]
		- 20240918@Lewis: Rebate Retention - Reward [RedmineId: #208503]
		- 20241205@Lewis: Hotfix filter range bk [RedmineId: #214813]
		- 20241129@Lewis: Enhance Perf SabaWalletTicket [RedmineId: #214431]
		- 20241119@Lewis: Direct Member [RedmineId: #211969]
	
	Param's Explanation:
		- @LevelType:	0: All; 1: Master Agent/ Agent; 2: Direct Member
	
*/

BEGIN
	SET NOCOUNT ON
	
	DECLARE @DateLimit SMALLDATETIME, @CurrentDate SMALLDATETIME
	SET @CurrentDate = CAST(GETDATE() AS DATE)
	
	SELECT @DateLimit = ISNULL(MinDate, DATEADD(DAY, - 1 * LimitDays, @CurrentDate))
	FROM dbo.Age_CustDateLimit l WITH (NOLOCK)
		INNER JOIN dbo.custInfo c WITH (NOLOCK) ON l.CustId = c.srecommend
	WHERE c.custId = @CustID
	
	IF @FromDate < @DateLimit
	BEGIN
		SELECT @FromDate = @DateLimit
	END

	DROP TABLE IF EXISTS #MAgWinLossDetails
	DROP TABLE IF EXISTS #TmpCondSumWL

	CREATE TABLE #MAgWinLossDetails
	(
		CustID			INT
		,TurnOver		MONEY
		,TurnoverNoDraw	MONEY
		,GrossComm		MONEY
		,MemberWinLost	MONEY
		,PlayerComm		MONEY
		,AgWinLost		MONEY
		,AgComm			MONEY
		,MAgWinLost		MONEY
		,MAgComm		MONEY
		,NoOfTicket		INT
		,RewardAmount	MONEY
		,WalletType		TINYINT DEFAULT(0)
	)

	CREATE TABLE #TmpCondSumWL(
		SportType		INT
		,BetType		INT
		,LeagueGroupID	SMALLINT
		,TicketType		TINYINT
	)

	DROP TABLE IF EXISTS #GrossComm;
	CREATE TABLE #GrossComm (CustId INT, TurnoverNoDraw MONEY, GrossComm MONEY);

	DECLARE @ExistingProductDetails TABLE (ProductId INT,Sporttype INT,Bettype INT, LeagueGroupID SMALLINT, TicketType TINYINT)
	DECLARE @isTest BIT, @__ProductDetails XML
	
	SELECT  @isTest = dbo.f_CheckSPVersion(@@PROCID)	

	SELECT @ProductIds = dbo.f_AddRelatedProducts(@ProductIds)
	SELECT @__ProductDetails = CONVERT(XML, @ProductDetails)

	INSERT INTO @ExistingProductDetails(ProductId, Sporttype, Bettype, LeagueGroupID, TicketType)
	SELECT ProductId, Sporttype, Bettype, LeagueGroupID, TicketType
	FROM dbo.f_ProductDetail_ConditionSel(@ProductDetails, @__ProductDetails)

	IF @FromDate <= @MoveBetsDay
	BEGIN
		INSERT INTO #TmpCondSumWL(SportType, BetType, LeagueGroupID, TicketType) 
		SELECT f.SportType, f.BetType, f.LeagueGroupID, f.TicketType
		FROM dbo.f_SumWinloss_ConditionSel(@ProductIds) f
			LEFT JOIN @ExistingProductDetails e ON f.ProductID = e.ProductId 
		WHERE e.ProductId IS NULL OR (e.Bettype = f.BetType AND e.Sporttype = f.SportType AND e.TicketType = f.TicketType AND e.LeagueGroupID = f.LeagueGroupID AND e.ProductID = f.ProductId)
	END

	------Get @Srecommend
	DECLARE @Srecommend int, @CurrencyCode VARCHAR(12);

	SELECT @Srecommend = Srecommend,
		   @CurrencyCode	= e.Code
	FROM dbo.CustInfo c WITH (NOLOCK)
	INNER JOIN dbo.Exchange e WITH(NOLOCK) ON c.currency = e.ExchangeId
	WHERE c.CustID = @CustID


	--Avoid Parameter Sniffing for bettrans and sum_winloss
	DECLARE @FDate SMALLDATETIME, @TDate SMALLDATETIME, @CID INT
	    
	SELECT @CID   = @custid

	--DownlineList
	DECLARE @totalDownline INT, @downlineIds VARCHAR(MAX)
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

	--TODO: bettrans range
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
		INSERT INTO #MAgWinLossDetails(CustID, TurnOver, TurnoverNoDraw, GrossComm, MemberWinLost, PlayerComm, AgWinLost, AgComm, MAgWinLost, MAgComm, NoOfTicket)
		SELECT	b.CustID,
			SUM(b.TurnOver) AS TurnOver,
			SUM(b.TurnoverNoDraw) AS TurnoverNoDraw,
			SUM(b.GrossComm) AS GrossComm,
			SUM(b.winlost) AS MemberWinLost,
			SUM(b.playercomm) AS PlayerComm,
			SUM(b.awinlost) AS AgWinLost,
			SUM(b.comm - b.playercomm) AS AgComm,
			SUM(b.mwinlost) AS MAgWinLost, 
			SUM(b.acomm - b.comm) AS MAgComm, 
			SUM(b.betcount) AS NoOfTicket
		FROM bodb_AGE.dbo.bettrans_compact b WITH(NOLOCK)
			INNER JOIN CTE_Downline m ON m.custid = b.custid
			INNER JOIN (
				SELECT f.ProductID, f.BetType, f.RefTable
				FROM (	
					SELECT DISTINCT ma.ProductID, ma.BetType, ma.RefTable
					FROM  dbo.SportBettypeMatrix ma WITH(NOLOCK)
					WHERE ',' + @ProductIDs + ',' LIKE '%,' + cast(ma.ProductID as varchar(3)) + ',%'
							AND (ma.IsTest = 0 OR ma.IsTest = @IsTest)
					) f
			) s ON b.bettype = s.bettype
		WHERE 
			b.winlostdate BETWEEN @FDate AND @TDate
		GROUP BY b.custid;

		-- bettransRnG
		INSERT INTO #GrossComm (CustId, TurnoverNoDraw, GrossComm)
		SELECT CASE WHEN b.recommend = -3 THEN b.custid ELSE b.recommend END AS CustId
			,SUM(CASE WHEN cont.ContributionBettype IS NULL THEN b.BetStake ELSE 0 END) AS TurnoverNoDraw
			,SUM(b.BetStake * b.adiscount) AS GrossComm
		FROM dbo.bettransRnG b WITH(NOLOCK)
		INNER JOIN (
			SELECT	ISNULL(p.GroupProductId, f.ProductID) AS ProductID, f.BetType
			FROM (	
					SELECT DISTINCT ma.ProductID, ma.BetType, ma.RefTable
					FROM  dbo.SportBettypeMatrix ma WITH(NOLOCK)
					WHERE ',' + @ProductIDs + ',' LIKE '%,' + cast(ma.ProductID as varchar(3)) + ',%'
							AND (ma.IsTest = 0 OR ma.IsTest = @IsTest) 	AND ma.RefTable = 1
					) f
				LEFT JOIN dbo.f_GroupProduct() p ON f.ProductID = p.ProductId
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
			AND mrecommend = @CID
		GROUP BY CASE WHEN b.recommend = -3 THEN b.custid ELSE b.recommend END
		
		-- bettransLC
		INSERT INTO #GrossComm (CustId, TurnoverNoDraw, GrossComm)
		SELECT CASE WHEN b.recommend = -3 THEN b.custid ELSE b.recommend END AS CustId
			,SUM(CASE WHEN cont.ContributionBettype IS NULL THEN b.NetStake ELSE 0 END) AS TurnoverNoDraw
			,SUM(b.NetStake * b.adiscount) AS GrossComm
		FROM dbo.bettransLC b WITH(NOLOCK)
		INNER JOIN (
			SELECT	ISNULL(p.GroupProductId, f.ProductID) AS ProductID, f.BetType
			FROM (	
					SELECT DISTINCT ma.ProductID, ma.BetType, ma.RefTable
					FROM  dbo.SportBettypeMatrix ma WITH(NOLOCK)
					WHERE ',' + @ProductIDs + ',' LIKE '%,' + cast(ma.ProductID as varchar(3)) + ',%'
							AND (ma.IsTest = 0 OR ma.IsTest = @IsTest) 	AND ma.RefTable = 2
					) f
				LEFT JOIN dbo.f_GroupProduct() p ON f.ProductID = p.ProductId
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
		INSERT INTO #MAgWinLossDetails(CustID, TurnOver, TurnoverNoDraw, GrossComm, MemberWinLost, PlayerComm, AgWinLost, AgComm, MAgWinLost, MAgComm, NoOfTicket)
		SELECT	b.CustID,			
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
		INSERT INTO #MAgWinLossDetails(CustID, TurnOver, TurnoverNoDraw, GrossComm, MemberWinLost, PlayerComm, AgWinLost, AgComm, MAgWinLost, MAgComm, NoOfTicket)
		SELECT	b.CustID,			
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
	INSERT INTO #MAgWinLossDetails(CustID, RewardAmount, WalletType)
	SELECT CustID, RewardAmount, WalletType
	FROM (
			SELECT CASE WHEN swt.Recommend = -3 THEN swt.CustID ELSE swt.Recommend END AS CustID, SUM(Amount) AS RewardAmount, 2 AS WalletType
			FROM SabaWalletTicket swt WITH (NOLOCK)
			INNER JOIN CTE_TransId cte ON swt.TransId = cte.TransId
			WHERE swt.WalletID = 2
			GROUP BY CASE WHEN swt.Recommend = -3 THEN swt.CustID ELSE swt.Recommend END
		) a
	WHERE EXISTS (SELECT TOP 1 1 FROM CTE_Downline cte WHERE cte.custid = a.CustID)

	--TODO: Result
	;WITH CTE_Reward AS (
		SELECT CustID, RewardAmount
		FROM #MAgWinLossDetails
		WHERE WalletType = 2
	)
	, CTE_Winloss AS (
		SELECT 
			CustID
			,SUM(TurnOver) AS TurnOver
			,SUM(TurnoverNoDraw) AS TurnoverNoDraw
			,SUM(GrossComm) AS GrossComm
			,SUM(MemberWinLost) AS MemberWinLost
			,SUM(PlayerComm) AS PlayerComm
			,SUM(AgWinlost) AS AgWinlost
			,SUM(AgComm) AS AgComm
			,SUM(MAgWinlost) AS MAgWinlost
			,SUM(MAgComm) AS MAgComm
			,SUM(NoOfTicket) AS NoOfTicket
		FROM #MAgWinLossDetails
		WHERE WalletType = 0
		GROUP BY CustID
	)
	SELECT	ISNULL(w.CustID,r.CustID)				 AS CustId
			,c.UserName 							 AS CustName
			,TurnOver								 AS Turnover
			,TurnoverNoDraw							 AS TurnoverNoDraw
			,GrossComm								 AS GrossComm
			,MemberWinLost							 AS MemberWinLoss
			,PlayerComm 							 AS MemberComm
			,AgWinlost								 AS AgWinLoss
			,AgComm									 AS AgComm
			,MAgWinlost 							 AS MAgWinLoss
			,MAgComm								 AS MAgComm
			,r.RewardAmount							 AS RewardAmount
			,@CurrencyCode							 AS RewardCurrency
			,NoOfTicket								 AS NumberOfTickets
			,ROW_NUMBER() OVER (ORDER BY c.UserName) AS RowNum
			,CASE WHEN c.roleid = 1 THEN 1 ELSE 0 END AS IsDirectMember
	FROM CTE_Winloss w
		FULL JOIN CTE_Reward r ON r.CustID = w.CustID
		INNER JOIN dbo.custInfo c WITH(NOLOCK) ON c.CustID = ISNULL(w.CustID,r.CustID)

	SELECT	NULL 				AS CustId
			,'Total' 			AS CustName
			,SUM(TurnOver) 		AS Turnover
			,SUM(TurnoverNoDraw)AS TurnoverNoDraw
			,SUM(GrossComm)		AS GrossComm
			,SUM(MemberWinLost) AS MemberWinLoss
			,SUM(PlayerComm)  	AS MemberComm
			,SUM(AgWinlost) 	AS AgWinLoss
			,SUM(AgComm) 		AS AgComm
			,SUM(MAgWinlost) 	AS MAgWinLoss
			,SUM(MAgComm) 		AS MAgComm
			,SUM(RewardAmount)	AS RewardAmount
			,@CurrencyCode		AS RewardCurrency
			,SUM(NoOfTicket) 	AS NumberOfTickets
	FROM #MAgWinLossDetails w
	HAVING SUM(TurnOver) > 0 OR SUM(RewardAmount) > 0
END
GO