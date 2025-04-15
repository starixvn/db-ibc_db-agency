/*<info serverAlias="DBAGE-bodb02" executers="wsv_alp,wsv_alpv" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Age_Rpt_WinlossDetail_WeekDataSel]
	@CustID			INT = NULL, --SMA
	@FromDate		SMALLDATETIME,
	@ToDate			SMALLDATETIME,
	@ProductIds		VARCHAR(MAX),
	@ProductDetails NVARCHAR(MAX) = 'All',
	@BalanceUpDay	SMALLDATETIME,
	@MoveBetsDay	SMALLDATETIME,
	@UserName		VARCHAR(30) = '',
	@IsReward		BIT = 1,
	@LevelType		TINYINT = 0
AS

/*
Created: 20240211@Bobby
Task : Renovate Week data range - Win Loss Detail Report
DB: DBAGE/bodb02

Revisions:
	- 20240211@Bobby: Init [RedmineID: #202084]
	- 20240625@Lewis: Change custinfo into customer [RedmineID: #207026]
    - 20240918@Lewis: Rebate Retention - Reward [RedmineId: #208503]
	- 20241129@Lewis: Enhance Perf SabaWalletTicket [RedmineId: #214431]
	- 20241119@Lewis: Direct Member [RedmineId: #211969]
	
	Param's Explanation:
	- @LevelType : 0: All; 1: Master Agent/ Agent; 2: Direct Member

*/

BEGIN
	SET NOCOUNT ON;

	DROP TABLE IF EXISTS #WeekRange;
	DROP TABLE IF EXISTS #TmpCondSumWL;

	CREATE TABLE #WeekRange (winlostdate SMALLDATETIME);
	CREATE TABLE #TmpCondSumWL(
		SportType		INT,
		BetType			INT,
		LeagueGroupID	SMALLINT, 
		TicketType		TINYINT
	);

	DECLARE @ExistingProductDetails TABLE (ProductId INT,Sporttype INT,Bettype INT, LeagueGroupID SMALLINT, TicketType TINYINT)
	DECLARE @isTest BIT, @__ProductDetails XML;
	SELECT  @isTest = dbo.f_CheckSPVersion(@@PROCID);

	--TODO: SMA's info
	DECLARE @srecommend INT, @mrecommend INT, @recommend INT, @roleid TINYINT, @downlineId INT, @downlineRoleId INT;

	--Avoid Parameter Sniffing for bettrans and sum_winloss
	DECLARE @FDate	SMALLDATETIME,
			@TDate	SMALLDATETIME,
			@CID	INT;

	SELECT TOP(1)
		@srecommend		= srecommend 
		,@mrecommend	= mrecommend 
		,@recommend		= recommend
		,@CID			= CustID
		,@roleid		= roleid
	FROM dbo.CustInfo WITH(NOLOCK)
	WHERE CustID = @CustID;

	--TOTO: @UserName IS NOT NULL		=> -1: No Data || >0: Exactly Username
	IF @CID > 0 AND LEN(ISNULL(@Username,'')) > 0	
	BEGIN
		SELECT TOP(1) @downlineId = Custid
			,@downlineRoleId = roleId
			,@srecommend	= srecommend 
			,@mrecommend	= mrecommend 
			,@recommend		= recommend
		FROM dbo.Customer WITH (NOLOCK) 
		WHERE username = @UserName;
		
		--CHECK @LevelType
		IF @LevelType IN (1,2) AND @roleid NOT IN (3,4) GOTO RS_OUTPUT;

		IF @roleid <> @downlineRoleId 
		BEGIN
			SELECT @LevelType = 0
		END
		
		--CHECK direct downline
		SELECT @downlineId = IIF(@CID IN (@srecommend, @mrecommend, @recommend), @downlineId, NULL)

		IF @downlineId IS NULL GOTO RS_OUTPUT;
		--print concat(@downlineId, '---', @downlineRoleId, ', @roleId=', @roleId, ',@recommend=',@recommend)
	END

	SELECT	@CID	= ISNULL(@downlineId, @CID),
			@roleId = IIF(@downlineId IS NULL, @roleId, @downlineRoleId);

	--TODO: Check OUTPUT
	IF @CID IS NULL GOTO RS_OUTPUT;
	
	
	
	--TODO: Sports, Bettypes
	SELECT @ProductIds = dbo.f_AddRelatedProducts(@ProductIds);
	SELECT @__ProductDetails = CONVERT(XML, @ProductDetails)

	INSERT INTO @ExistingProductDetails(ProductId,Sporttype,Bettype,LeagueGroupID,TicketType)
	SELECT ProductId,Sporttype,Bettype,LeagueGroupID,TicketType
	FROM dbo.f_ProductDetail_ConditionSel(@ProductDetails, @__ProductDetails)

	IF @FromDate <= @MoveBetsDay
	BEGIN
		INSERT INTO #TmpCondSumWL(SportType, BetType, LeagueGroupID, TicketType) 
		SELECT f.SportType, f.BetType, f.LeagueGroupID, f.TicketType
		FROM dbo.f_SumWinloss_ConditionSel(@ProductIds) f
			LEFT JOIN @ExistingProductDetails e ON f.ProductID = e.ProductId 
		WHERE e.ProductId IS NULL OR (e.Bettype = f.BetType AND e.Sporttype = f.SportType AND e.TicketType = f.TicketType AND e.LeagueGroupID = f.LeagueGroupID AND e.ProductID = f.ProductId)
	END

	--TODO: bettrans range
	SELECT @FDate = FromDate , @TDate = ToDate
	FROM dbo.f_MBU_RangeDate(@FromDate, @ToDate, @BalanceUpDay, @MoveBetsDay)
	WHERE RangeType = 1

	IF @FDate IS NOT NULL
	BEGIN 	

		DECLARE @totalDownline INT, @Downlinelist VARCHAR(MAX)

		IF @roleid = 4
		BEGIN
			;WITH cte_Downline AS(
				SELECT ci.custid
				FROM dbo.custinfo ci WITH(NOLOCK)
				WHERE srecommend = @srecommend
					AND ci.RoleId = 3
					AND @LevelType IN (0,1)

				UNION ALL

				SELECT ci.custid
				FROM dbo.custinfo ci WITH(NOLOCK)
				WHERE srecommend = @srecommend
					AND ci.RoleId = 1
					AND mrecommend = -4
					AND @LevelType IN (0,2)
			)
			SELECT 
				@totalDownline	= COUNT(1), 
				@Downlinelist	= STRING_AGG(CAST(cte.custid AS VARCHAR(MAX)), ',')
			FROM cte_Downline cte
		END

		IF @roleid = 3
		BEGIN
			;WITH cte_Downline AS(
				SELECT ci.custid
				FROM dbo.custinfo ci WITH(NOLOCK)
				WHERE mrecommend = @mrecommend
					AND ci.RoleId = 2
					AND @LevelType IN (0,1)

				UNION ALL

				SELECT ci.custid
				FROM dbo.custinfo ci WITH(NOLOCK)
				WHERE mrecommend = @mrecommend
					AND ci.RoleId = 1
					AND recommend = -3
					AND @LevelType IN (0,2)
			)
			SELECT 
				@totalDownline	= COUNT(1), 
				@Downlinelist	= STRING_AGG(CAST(cte.custid AS VARCHAR(MAX)), ',')
			FROM cte_Downline cte 
		END

		IF @roleid = 2
		BEGIN
			SELECT 
				@totalDownline	= COUNT(1), 
				@Downlinelist	= STRING_AGG(CAST(ci.custid AS VARCHAR(MAX)), ',')
			FROM dbo.custinfo ci WITH (NOLOCK) 
			WHERE recommend = @recommend
				AND RoleId = 1
		END

		IF @roleid = 1
		BEGIN
			SELECT 
				@totalDownline	= COUNT(1), 
				@Downlinelist	= STRING_AGG(CAST(ci.custid AS VARCHAR(MAX)), ',')
			FROM dbo.custinfo ci WITH (NOLOCK) 
			WHERE custid = @CID
		END

		-- TODO: get data from bettrans_compact
		;WITH cte_Downline AS (
			SELECT TOP(@totalDownline) CAST([value] AS INT) AS custid
			FROM STRING_SPLIT(@Downlinelist, ',') AS c
		)
		INSERT INTO #WeekRange(winlostdate)
		SELECT DISTINCT b.winlostdate
		FROM bodb_Age.dbo.bettrans_compact b WITH(NOLOCK)
		INNER JOIN cte_Downline cte ON b.custid = cte.custid
		INNER JOIN (
			SELECT ISNULL(p.GroupProductId, f.ProductID) AS ProductID, f.BetType, f.RefTable, ISNULL(e.LeagueGroupID,0) AS LeagueGroupID, ISNULL(e.TicketType,0) AS TicketType, ISNULL(SportType,0) AS SportType
			FROM (	
				SELECT DISTINCT ma.ProductID, ma.BetType, ma.RefTable
				FROM  dbo.SportBettypeMatrix ma WITH(NOLOCK)
				WHERE ',' + @ProductIDs + ',' LIKE '%,' + cast(ma.ProductID as varchar(3)) + ',%'
						AND (ma.IsTest = 0 OR ma.IsTest = @IsTest)
			) f
			LEFT JOIN dbo.f_GroupProduct() p ON f.ProductID = p.ProductId
			LEFT JOIN @ExistingProductDetails e ON e.ProductId = f.ProductID 
			WHERE EXISTS(SELECT 1 WHERE e.ProductId IS NULL 
				OR (
					e.Bettype = f.BetType 
					OR (
							e.Bettype = 0 AND (e.ProductId = 1 OR  f.BetType NOT IN (SELECT g.Bettype FROM f_GetProductDetail() g WHERE g.ProductId <> 1) )
						)
					)
				)
		) s ON b.bettype = s.bettype AND (s.ProductID <> 1 OR (s.ProductID = 1 AND b.sporttype = s.SportType AND b.LeagueGroupID = s.LeagueGroupID AND b.TicketType = s.TicketType))
		WHERE b.winlostdate BETWEEN @FDate AND @TDate
		
	END

	--TODO: sum_winloss range
	SELECT @FDate = NULL, @TDate = NULL
	SELECT @FDate = FromDate , @TDate = ToDate
	FROM dbo.f_MBU_RangeDate(@FromDate, @ToDate, @BalanceUpDay, @MoveBetsDay)
	WHERE RangeType = 2

	IF @FDate IS NOT NULL
	BEGIN
		IF @LevelType = 0
		BEGIN
			INSERT INTO #WeekRange(winlostdate)
			SELECT DISTINCT b.winlostdate
			FROM dbo.SUM_winloss b WITH(NOLOCK)
				INNER JOIN #TmpCondSumWL t ON b.sporttype = t.sporttype AND b.bettype = t.bettype AND ISNULL(b.leagueGroupID,0) = t.LeagueGroupID AND ISNULL(b.ticketType,0) = t.TicketType
			WHERE b.winlostdate BETWEEN @FDate AND @TDate			
				AND b.srecommend = @srecommend 
				AND b.mrecommend = @mrecommend 
				AND b.recommend = @recommend 
				AND b.roleId = @roleId 
				AND b.custid = @CID
		END

		IF @LevelType = 1
		BEGIN
			INSERT INTO #WeekRange(winlostdate)
			SELECT DISTINCT b.winlostdate
			FROM dbo.SUM_winloss b WITH(NOLOCK)
				INNER JOIN #TmpCondSumWL t ON b.sporttype = t.sporttype AND b.bettype = t.bettype AND ISNULL(b.leagueGroupID,0) = t.LeagueGroupID AND ISNULL(b.ticketType,0) = t.TicketType
			WHERE b.winlostdate BETWEEN @FDate AND @TDate			
				AND b.srecommend = @srecommend
				AND 1 = CASE 
							WHEN @roleId = 4 AND b.mrecommend > 0 AND b.recommend = 0 THEN 1
							WHEN @roleId = 3 AND b.mrecommend = @mrecommend AND b.recommend > 0 THEN 1
							ELSE 0
						END
				AND b.roleId = @roleid - 1
				--AND b.custid = @CID
		END

		IF @LevelType = 2
		BEGIN
			INSERT INTO #WeekRange(winlostdate)
			SELECT DISTINCT b.winlostdate
			FROM dbo.SUM_winloss b WITH(NOLOCK)
				INNER JOIN #TmpCondSumWL t ON b.sporttype = t.sporttype AND b.bettype = t.bettype AND ISNULL(b.leagueGroupID,0) = t.LeagueGroupID AND ISNULL(b.ticketType,0) = t.TicketType
			WHERE b.winlostdate BETWEEN @FDate AND @TDate			
				AND b.srecommend = @srecommend 
				AND b.mrecommend = IIF(@roleId = 4, -4, @mrecommend) 
				AND b.recommend = IIF(@roleId = 4, -4, -3)
				AND b.roleId = 1
				--AND b.custid = @CID
		END
	END

	--TODO: sum_winloss_old range
	SELECT @FDate = NULL, @TDate = NULL
	SELECT @FDate = FromDate , @TDate = ToDate
	FROM dbo.f_MBU_RangeDate(@FromDate, @ToDate, @BalanceUpDay, @MoveBetsDay)
	WHERE RangeType = 3

	IF @FDate IS NOT NULL
	BEGIN
		IF @LevelType = 0
		BEGIN
			-- using cte to remove predicate when seek on sum_winloss_old
			;WITH CTE_Winlostdate (winlostdate, sporttype, bettype, leagueGroupID, ticketType) AS
			(
				SELECT @FDate AS winlostdate, SportType, BetType, leagueGroupID, ticketType
				FROM #TmpCondSumWL
				UNION ALL
				SELECT DATEADD(DAY, 1, winlostdate), SportType, BetType, leagueGroupID, ticketType
				FROM CTE_Winlostdate
				WHERE winlostdate < @TDate
			)
			INSERT INTO #WeekRange(winlostdate)
			SELECT DISTINCT b.winlostdate
			FROM bodb_Summary.dbo.Sum_WinLoss_Old b WITH(NOLOCK) 
				CROSS APPLY CTE_Winlostdate w
			WHERE b.winlostdate	= w.winlostdate
				AND b.srecommend = @srecommend 
				AND b.mrecommend = @mrecommend 
				AND b.recommend = @recommend 
				AND b.roleId = @roleId 
				AND b.custid = @CID 
				AND b.sporttype	= w.sporttype
				AND b.bettype = w.bettype
				AND ISNULL(b.leagueGroupID,0) = w.leagueGroupID
				AND ISNULL(b.ticketType,0) = w.ticketType
			OPTION (MAXRECURSION 0);
		END

		IF @LevelType = 1
		BEGIN
			-- using cte to remove predicate when seek on sum_winloss_old
			;WITH CTE_Winlostdate (winlostdate, sporttype, bettype, leagueGroupID, ticketType) AS
			(
				SELECT @FDate AS winlostdate, SportType, BetType, leagueGroupID, ticketType
				FROM #TmpCondSumWL
				UNION ALL
				SELECT DATEADD(DAY, 1, winlostdate), SportType, BetType, leagueGroupID, ticketType
				FROM CTE_Winlostdate
				WHERE winlostdate < @TDate
			)
			INSERT INTO #WeekRange(winlostdate)
			SELECT DISTINCT b.winlostdate
			FROM bodb_Summary.dbo.Sum_WinLoss_Old b WITH(NOLOCK) 
				CROSS APPLY CTE_Winlostdate w
			WHERE b.winlostdate	= w.winlostdate
				AND b.srecommend = @srecommend 
				AND 1 = CASE 
							WHEN @roleId = 4 AND b.mrecommend > 0 AND b.recommend = 0 THEN 1
							WHEN @roleId = 3 AND b.mrecommend = @mrecommend AND b.recommend > 0 THEN 1
							ELSE 0
						END
				AND b.roleId = @roleid - 1
				--AND b.custid = @CID
				AND b.sporttype	= w.sporttype
				AND b.bettype = w.bettype
				AND ISNULL(b.leagueGroupID,0) = w.leagueGroupID
				AND ISNULL(b.ticketType,0) = w.ticketType
			OPTION (MAXRECURSION 0);
		END

		IF @LevelType = 2
		BEGIN
			-- using cte to remove predicate when seek on sum_winloss_old
			;WITH CTE_Winlostdate (winlostdate, sporttype, bettype, leagueGroupID, ticketType) AS
			(
				SELECT @FDate AS winlostdate, SportType, BetType, leagueGroupID, ticketType
				FROM #TmpCondSumWL
				UNION ALL
				SELECT DATEADD(DAY, 1, winlostdate), SportType, BetType, leagueGroupID, ticketType
				FROM CTE_Winlostdate
				WHERE winlostdate < @TDate
			)
			INSERT INTO #WeekRange(winlostdate)
			SELECT DISTINCT b.winlostdate
			FROM bodb_Summary.dbo.Sum_WinLoss_Old b WITH(NOLOCK) 
				CROSS APPLY CTE_Winlostdate w
			WHERE b.winlostdate	= w.winlostdate
				AND b.srecommend = @srecommend 
				AND b.mrecommend = IIF(@roleId = 4, -4, @mrecommend) 
				AND b.recommend = IIF(@roleId = 4, -4, -3)
				AND b.roleId = 1
				--AND b.custid = @CID		
				AND b.sporttype	= w.sporttype
				AND b.bettype = w.bettype
				AND ISNULL(b.leagueGroupID,0) = w.leagueGroupID
				AND ISNULL(b.ticketType,0) = w.ticketType
			OPTION (MAXRECURSION 0);
		END
	END	
	

	--TODO: SabaWalletTicket
	IF @IsReward = 1
	BEGIN
		
		SELECT	@FDate	= @FromDate,
				@TDate	= @ToDate;

		IF @roleId = 1
		BEGIN
			INSERT INTO #WeekRange(winlostdate)
			SELECT DISTINCT b.winlostdate
			FROM SabaWalletTicket b WITH (NOLOCK)
			WHERE b.CustID = @CID
				AND b.winlostdate BETWEEN @FDate AND @TDate
				AND WalletID = 2
		END
		ELSE IF @roleId = 2
		BEGIN
			INSERT INTO #WeekRange(winlostdate)
			SELECT DISTINCT b.winlostdate
			FROM SabaWalletTicket b WITH (NOLOCK)
			WHERE b.Recommend = @CID
				AND b.winlostdate BETWEEN @FDate AND @TDate
				AND WalletID = 2
		END
		ELSE IF @roleId = 3
		BEGIN
			INSERT INTO #WeekRange(winlostdate)
			SELECT DISTINCT b.winlostdate
			FROM SabaWalletTicket b WITH (NOLOCK)
			WHERE b.Mrecommend = @CID
				AND b.winlostdate BETWEEN @FDate AND @TDate
				AND WalletID = 2
				AND @LevelType IN (0,1) 
				AND b.Recommend <> -3
			UNION ALL
			SELECT DISTINCT b.winlostdate
			FROM SabaWalletTicket b WITH (NOLOCK)
			WHERE b.Mrecommend = @CID
				AND b.winlostdate BETWEEN @FDate AND @TDate
				AND WalletID = 2
				AND @LevelType IN (0,2) 
				AND b.Recommend = -3 
		END
		ELSE IF @roleId = 4
		BEGIN
			INSERT INTO #WeekRange(winlostdate)
			SELECT DISTINCT b.winlostdate
			FROM SabaWalletTicket b WITH (NOLOCK)
			WHERE b.Srecommend = @CID
				AND b.winlostdate BETWEEN @FDate AND @TDate
				AND WalletID = 2
				AND @LevelType IN (0,1) 
				AND b.Recommend <> -4
			UNION ALL
			SELECT DISTINCT b.winlostdate
			FROM SabaWalletTicket b WITH (NOLOCK)
			WHERE b.Srecommend = @CID
				AND b.winlostdate BETWEEN @FDate AND @TDate
				AND WalletID = 2
				AND @LevelType IN (0,2) 
				AND b.Recommend = -4
		END
	END
	
	--TODO: Return
	RS_OUTPUT:
	;WITH CTE_WeekRange AS (
		SELECT 
			IIF( DATEPART(WEEKDAY, cte.winlostdate) = 1
				, DATEADD(DAY, -6, cte.winlostdate)
				, DATEADD(DAY, 2-DATEPART(WEEKDAY,cte.winlostdate),cte.winlostdate))
																						AS StartOfWeek --Monday
			, IIF( DATEPART(WEEKDAY, cte.winlostdate) = 1
			   , cte.winlostdate
			   , DATEADD(DAY, 7-DATEPART(WEEKDAY,cte.winlostdate) + 1,cte.winlostdate))
																						AS EndOfWeek --Sunday
		FROM #WeekRange cte
	)
	SELECT DISTINCT DATEPART(WEEK, StartOfWeek) AS WeekOfYear
		, IIF(StartOfWeek <= @FromDate, @FromDate, StartOfWeek) AS StartOfWeek
		, IIF(EndOfWeek >= @ToDate, @ToDate, EndOfWeek) AS EndOfWeek
	FROM CTE_WeekRange
END