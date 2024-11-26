/*<info serverAlias="DBAGE-bodb02" executers="wsv_alp,wsv_alpv" isFunction="0" isNested="0"></info>*/
CREATE PROCEDURE [dbo].[Age_Rpt_API_WinLossDetail_Member]
	@CustID			 INT = NULL --recommend
	,@FromDate		 SMALLDATETIME
	,@ToDate		 SMALLDATETIME
	,@ProductIds	 VARCHAR(MAX)
	,@ProductDetails NVARCHAR(MAX) = 'All'
	,@BalanceUpDay	 SMALLDATETIME
	,@MoveBetsDay	 SMALLDATETIME
AS
/*
	Created: 20240321@Bobby
	Task : EXT-API - Change source bettrans to bettrans_compact
	DB: DBAGE/bodb02
	Original:Age_Rpt_API_WinLossDetail_Member

	Revisions:
		- 20221128@Eddie: Change from SP "Age_Rpt_WinLossDetail_Member" [RedmineID: #171247]
		- 20230511@Eddie: Enhance data range [RedmineID: #188033]
		- 20230707@Bobby: Support NetTO & GrossComm [RedmineID: #188035]
		- 20240321@Bobby: Change source bettrans to bettrans_compact [RedmineID: #202655]
		- 20240424@Lewis: Change old sql account [Redmine: #204021]
		- 20240918@Lewis: Rebate Retention - Reward [RedmineId: #208503]
	
	Param's Explanation:
	
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

	DROP TABLE IF EXISTS #AgWinLossDetails
	DROP TABLE IF EXISTS #TmpCondSumWL
	DROP TABLE IF EXISTS #GrossComm

	CREATE TABLE #AgWinLossDetails(
		CustID			INT
		,TurnOver		MONEY
		,TurnoverNoDraw	MONEY
		,GrossComm		MONEY
		,MemberWinLost	MONEY
		,PlayerComm		MONEY
		,AgWinLost		MONEY
		,AgComm			MONEY
		,NoOfTicket		INT
		,RewardAmount	MONEY
	)

	CREATE TABLE #TmpCondSumWL(
		SportType		INT
		,BetType		INT
		,LeagueGroupID	SMALLINT
		,TicketType		TINYINT
	)

	CREATE TABLE #GrossComm (CustId INT, TurnoverNoDraw MONEY, GrossComm MONEY);

	DECLARE @ExistingProductDetails TABLE (ProductId INT, Sporttype INT, Bettype INT, LeagueGroupID SMALLINT, TicketType TINYINT)
	DECLARE @isTest BIT = 0, @__ProductDetails XML

	SELECT  @isTest = dbo.f_CheckSPVersion(@@PROCID)

	SELECT @ProductIds = dbo.f_AddRelatedProducts(@ProductIds)
	SELECT @__ProductDetails = CONVERT(XML, @ProductDetails)

	DECLARE @SeparateSabaSport_Cutoff SMALLDATETIME 

	SELECT @SeparateSabaSport_Cutoff = CutoffDate
	FROM dbo.f_GetCutoffDate()
	WHERE TypeName = 'SabaSport'

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
	DECLARE @Srecommend INT, @Mrecommend INT
	  
	SELECT	@Srecommend  =  Srecommend
			,@Mrecommend =  Mrecommend 
	FROM dbo.CustInfo WITH(NOLOCK) 
	WHERE CustID = @CustID

	-----Get Special Super to hide data of them before specific date 
	DECLARE @IsHide BIT = 0

	IF EXISTS (SELECT 1 FROM dbo.f_SpecialSuper() WHERE Srecommend = @Srecommend)
	BEGIN
		SELECT @IsHide = 1
	END
		
	----Get Account Login to detect Interal or not
	DECLARE @LoginName NVARCHAR(128)
	SELECT @LoginName = SUSER_NAME()

	--Avoid Parameter Sniffing
	DECLARE @FDate SMALLDATETIME, @TDate SMALLDATETIME, @CID INT
	    
	SELECT	@FDate  = @FromDate
			,@TDate = @ToDate
			,@CID   = @custid
			

				

	--TODO: bettrans range
	IF @ToDate > @MoveBetsDay
	BEGIN 	
		SELECT @FDate	= IIF(@FromDate <= @MoveBetsDay, DATEADD(DD, 1, @MoveBetsDay), @FromDate)
			,@TDate		= @ToDate

		;WITH CTE_Member AS (
			SELECT custid
			FROM dbo.Customer WITH(NOLOCK)
			WHERE recommend = @CID
				AND RoleId = 1
		)
		INSERT INTO #AgWinLossDetails(CustID, TurnOver, TurnoverNoDraw, GrossComm, MemberWinLost, PlayerComm, AgWinLost, AgComm, NoOfTicket)
		SELECT	b.CustID,
			SUM(b.TurnOver) AS TurnOver,
			SUM(b.TurnoverNoDraw) AS TurnoverNoDraw,
			SUM(b.GrossComm) AS GrossComm,
			SUM(b.winlost) AS MemberWinLost,
			SUM(b.playercomm) AS PlayerComm,
			SUM(b.awinlost) AS AgWinLost,
			SUM(b.comm - b.playercomm) AS AgComm,
			SUM(b.betcount) AS NoOfTicket
		FROM bodb_AGE.dbo.bettrans_compact b WITH(NOLOCK)
		INNER JOIN CTE_Member m ON m.custid = b.custid
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
			AND recommend = @CID
		GROUP BY b.CustId

		-- bettransLC
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
	IF @FromDate <= @MoveBetsDay
	BEGIN
		SELECT @FDate	= IIF(@FromDate >= @BalanceUpDay, @FromDate, @BalanceUpDay)
			, @TDate	= IIF(@ToDate >= @MoveBetsDay, @MoveBetsDay, @ToDate);
		
		--TODO: Optimize CIX-Index Seek instead of IX-Index Seek & Key Lookup
		WITH CTE_Winlostdate AS (
			SELECT @FDate AS Winlostdate
			UNION ALL 
			SELECT DATEADD(DAY, 1, Winlostdate)
			FROM CTE_Winlostdate
			WHERE Winlostdate < @TDate
		), 
		CTE_Winloss AS (
			SELECT	b.custid, sporttype,bettype,leagueGroupID,ticketType
					,SUM(ABS(b.turnover)) 		AS TurnOver
					,SUM(b.TunroverNoDraw)		AS TunroverNoDraw
					,SUM(b.GrossComm)			AS GrossComm
					,SUM(b.winlost) 			AS MemberWinLost
					,SUM(b.playercomm) 			AS PlayerComm
					,SUM(b.awinlost) 			AS AgWinLost
					,SUM(b.comm - b.playercomm) AS AgComm
					,SUM(b.BetCount) 			AS NoOfTicket
			FROM CTE_Winlostdate wld 
			CROSS APPLY (
				SELECT custid,sporttype,bettype,leagueGroupID,ticketType,turnover,TunroverNoDraw,GrossComm,winlost,awinlost,comm,playercomm,BetCount
				FROM dbo.sum_winloss b WITH (NOLOCK) 
				WHERE b.winlostdate = wld.Winlostdate		
					AND b.srecommend = @Srecommend
					AND b.mrecommend = @Mrecommend
					AND b.recommend = @CID
					AND b.roleid = 1
			) AS b
			GROUP BY b.custid, sporttype,bettype,leagueGroupID,ticketType
		)
		INSERT INTO #AgWinLossDetails(CustID, TurnOver, TurnoverNoDraw, GrossComm, MemberWinLost, PlayerComm, AgWinLost, AgComm, NoOfTicket)
		SELECT b.custid
			,SUM(ABS(b.turnover)) 		AS TurnOver
			,SUM(b.TunroverNoDraw)		AS TurnoverNoDraw
			,SUM(b.GrossComm)			AS GrossComm
			,SUM(b.MemberWinLost) 		AS MemberWinLost
			,SUM(b.playercomm) 			AS PlayerComm
			,SUM(b.AgWinLost) 			AS AgWinLost
			,SUM(b.AgComm)				AS AgComm
			,SUM(b.NoOfTicket) 			AS NoOfTicket
		FROM CTE_Winloss b
		INNER JOIN #TmpCondSumWL t ON b.sporttype = t.sporttype AND b.bettype = t.bettype AND ISNULL(b.leagueGroupID,0) = t.LeagueGroupID AND ISNULL(b.ticketType,0) = t.TicketType
		GROUP BY custid
	END

	--TODO: sum_winloss_old range
	IF @FromDate < @BalanceUpDay 
	BEGIN
		SELECT @FDate	= @FromDate
			,@TDate		= IIF(@ToDate >= @BalanceUpDay, DATEADD(DD, -1, @BalanceUpDay), @ToDate);
	


		-- using cte to remove predicate when seek on sum_winloss_old
		;WITH CTE_Winlostdate (winlostdate) AS
		(
			SELECT @FDate AS winlostdate
			UNION ALL
			SELECT DATEADD(DAY, 1, winlostdate)
			FROM CTE_Winlostdate
			WHERE winlostdate < @TDate
		), CTE_Winloss AS (
			SELECT b.custid, sporttype,bettype,leagueGroupID,ticketType
				,SUM(ABS(b.turnover)) 		AS TurnOver
				,SUM(TunroverNoDraw)		AS TurnoverNoDraw
				,SUM(GrossComm)				AS GrossComm
				,SUM(b.winlost) 			AS MemberWinLost
				,SUM(b.playercomm) 			AS PlayerComm
				,SUM(b.awinlost) 			AS AgWinLost
				,SUM(b.comm - b.playercomm) AS AgComm
				,SUM(b.BetCount) 			AS NoOfTicket
			FROM CTE_Winlostdate w
			CROSS APPLY (
				SELECT custid,sporttype,bettype,leagueGroupID,ticketType,turnover,TunroverNoDraw,GrossComm,winlost,awinlost,comm,playercomm,BetCount
				FROM bodb_Summary.dbo.Sum_WinLoss_Old b WITH(NOLOCK)  
				WHERE b.winlostdate = w.Winlostdate		
					AND b.srecommend = @Srecommend
					AND b.mrecommend = @Mrecommend
					AND b.recommend = @CID
					AND b.roleid = 1
			) AS b
			GROUP BY b.custid, sporttype,bettype,leagueGroupID,ticketType
		)
		INSERT INTO #AgWinLossDetails(CustID, TurnOver, TurnoverNoDraw, GrossComm, MemberWinLost, PlayerComm, AgWinLost, AgComm, NoOfTicket)
		SELECT b.custid
			,SUM(b.turnover) 			AS TurnOver
			,SUM(b.TurnoverNoDraw)		AS TurnoverNoDraw
			,SUM(b.GrossComm)			AS GrossComm
			,SUM(b.MemberWinLost) 		AS MemberWinLost
			,SUM(b.playercomm) 			AS PlayerComm
			,SUM(b.AgWinLost) 			AS AgWinLost
			,SUM(b.AgComm)				AS AgComm
			,SUM(b.NoOfTicket) 			AS NoOfTicket
		FROM CTE_Winloss b
		INNER JOIN #TmpCondSumWL t ON b.sporttype = t.sporttype AND b.bettype = t.bettype AND ISNULL(b.leagueGroupID,0) = t.LeagueGroupID AND ISNULL(b.ticketType,0) = t.TicketType
		GROUP BY custid
		OPTION (MAXRECURSION 0)
	END

	--TODO: SabaWalletTicket
	SELECT @FDate = @FromDate , @TDate = @ToDate

	INSERT INTO #AgWinLossDetails(CustID,RewardAmount)
	SELECT CustID,SUM(Amount)
	FROM SabaWalletTicket b WITH (NOLOCK)
	WHERE b.winlostdate BETWEEN @FDate AND @TDate
		AND b.WalletID= 2
		AND b.Recommend = @CID
	GROUP BY CustID

	--TODO: Result
	SELECT 
		wl.CustId
		, wl.CustName
		, wl.Turnover
		, wl.TurnoverNoDraw
		, wl.GrossComm
		, wl.MemberWinLoss
		, wl.MemberComm
		, wl.AgWinLoss
		, wl.AgComm
		, wl.RewardAmount
		, wl.RewardCurrency
		, wl.NumberOfTickets
		, wl.RowNum
	FROM (
		SELECT w.CustID 			AS CustId
			   ,c.UserName 			AS CustName
			   ,SUM(TurnOver) 		AS Turnover
			   ,SUM(TurnoverNoDraw)	AS TurnoverNoDraw
			   ,SUM(GrossComm)		AS GrossComm
			   ,SUM(MemberWinLost) 	AS MemberWinLoss
			   ,SUM(PlayerComm) 	AS MemberComm
			   ,SUM(AgWinlost) 		AS AgWinLoss
			   ,SUM(AgComm) 		AS AgComm
			   ,SUM(RewardAmount) 	AS RewardAmount
			   ,e.Code				AS RewardCurrency
			   ,SUM(NoOfTicket) 	AS NumberOfTickets
			   ,ROW_NUMBER() OVER (ORDER BY c.UserName) AS RowNum	
		FROM #AgWinLossDetails w 
			INNER JOIN dbo.custInfo c WITH(NOLOCK) ON w.CustID = c.CustID 
			INNER JOIN dbo.Exchange e WITH(NOLOCK) ON c.currency = e.ExchangeId
		GROUP BY w.CustID, c.UserName, e.Code	
	) wl

	SELECT NULL 				AS CustId
		   ,'Total' 			AS CustName
		   ,SUM(TurnOver) 		AS Turnover
		   ,SUM(TurnoverNoDraw)	AS TurnoverNoDraw
		   ,SUM(GrossComm)		AS GrossComm
		   ,SUM(MemberWinLost) 	AS MemberWinLoss
		   ,SUM(PlayerComm) 	AS MemberComm
		   ,SUM(AgWinlost) 		AS AgWinLoss
		   ,SUM(AgComm) 		AS AgComm
		   ,SUM(RewardAmount) 	AS RewardAmount
		   ,e.Code				AS RewardCurrency
		   ,SUM(NoOfTicket) 	AS NumberOfTickets
	FROM #AgWinLossDetails w
		INNER JOIN dbo.custInfo c WITH(NOLOCK) ON w.CustID = c.CustID 
		INNER JOIN dbo.Exchange e WITH(NOLOCK) ON c.currency = e.ExchangeId
	GROUP BY e.Code
END 
GO