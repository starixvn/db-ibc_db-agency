/*<info serverAlias="DBAGE-bodb02" executers="wsv_alp,wsv_alpv" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Age_Rpt_WinlossDetail_WeekDataSel]
	@CustID			INT = NULL, --SMA
	@FromDate		SMALLDATETIME,
	@ToDate			SMALLDATETIME,
	@ProductIds		VARCHAR(MAX),
	@ProductDetails NVARCHAR(MAX) = 'All',
	@BalanceUpDay	SMALLDATETIME,
	@MoveBetsDay	SMALLDATETIME,
	@UserName		VARCHAR(30) = ''

AS

/*
Created: 20240211@Bobby
Task : Renovate Week data range - Win Loss Detail Report
DB: DBAGE/bodb02

Revisions:
	- 20240211@Bobby: Init [RedmineID: #202084]
	- 20240625@Lewis: Change custinfo into customer [RedmineID: #207026]
	
	Param's Explanation:
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
	DECLARE @srecommend INT, @mrecommend INT, @recommend INT, @roleId INT
		, @downlineId INT, @downlineRoleId INT;

	--Avoid Parameter Sniffing for bettrans and sum_winloss
	DECLARE @FDate	SMALLDATETIME,
			@TDate	SMALLDATETIME,
			@CID	INT;

	SELECT TOP(1)
		@srecommend		= srecommend 
		,@mrecommend	= mrecommend 
		,@recommend		= recommend 
		,@roleId		= roleId
		,@CID			= CustID
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

		--CHECK direct downline
		SELECT @downlineId = IIF(@CID IN (@srecommend, @mrecommend, @recommend), @downlineId, NULL)

		IF @downlineId IS NULL GOTO RS_OUTPUT;
		--print concat(@downlineId, '---', @downlineRoleId, ', @roleId=', @roleId, ',@recommend=',@recommend)
	END

	SELECT	@FDate	= @FromDate,
			@TDate	= @ToDate, 
			@CID	= ISNULL(@downlineId, @CID),
			@roleId = IIF(@downlineId IS NULL, @roleId, @downlineRoleId);

	--TODO: Check OUTPUT
	IF @CID IS NULL GOTO RS_OUTPUT;

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
	IF @ToDate > @MoveBetsDay
	BEGIN 	
		SELECT @FDate	= IIF(@FromDate <= @MoveBetsDay, DATEADD(DD, 1, @MoveBetsDay), @FromDate)
			,@TDate		= @ToDate

		-- TODO: get data from bettrans_compact
		INSERT INTO #WeekRange(winlostdate)
		SELECT DISTINCT b.winlostdate
		FROM bodb_Age.dbo.bettrans_compact b WITH(NOLOCK)
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
		WHERE b.custid = @CID
			AND b.winlostdate BETWEEN @FDate AND @TDate
		
	END

	--TODO: sum_winloss range
	IF @FromDate <= @MoveBetsDay
	BEGIN
		SELECT @FDate	= IIF(@FromDate >= @BalanceUpDay, @FromDate, @BalanceUpDay)
			, @TDate	= IIF(@ToDate >= @MoveBetsDay, @MoveBetsDay, @ToDate);

		INSERT INTO #WeekRange(winlostdate)
		SELECT DISTINCT b.winlostdate
		FROM dbo.SUM_winloss b WITH(NOLOCK)
			INNER JOIN #TmpCondSumWL t ON b.sporttype = t.sporttype AND b.bettype = t.bettype AND ISNULL(b.leagueGroupID,0) = t.LeagueGroupID AND ISNULL(b.ticketType,0) = t.TicketType
		WHERE b.winlostdate BETWEEN @FDate AND @TDate			
			AND b.srecommend	= @srecommend
			AND b.mrecommend	= @mrecommend
			AND b.recommend		= @recommend
			AND	b.roleId		= @roleId
			AND b.custid		= @CID
	END

	--TODO: sum_winloss_old range
	IF @FromDate < @BalanceUpDay 
	BEGIN
		SELECT @FDate	= @FromDate
			,@TDate		= IIF(@ToDate >= @BalanceUpDay, DATEADD(DD, -1, @BalanceUpDay), @ToDate);

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
		WHERE b.winlostdate		= w.winlostdate
			AND b.srecommend	= @srecommend
			AND b.mrecommend	= @mrecommend
			AND b.recommend		= @recommend
			AND	b.roleId		= @roleId
			AND b.custid		= @CID
			AND b.sporttype		= w.sporttype
			AND b.bettype		= w.bettype
			AND ISNULL(b.leagueGroupID,0) = w.leagueGroupID
			AND ISNULL(b.ticketType,0) = w.ticketType
		OPTION (MAXRECURSION 0);
	END	

	--TODO: Return
	RS_OUTPUT:
	;WITH CTE_WeekRange AS (
		SELECT 
			IIF(DATEPART(WEEKDAY, cte.winlostdate) = 1, DATEADD(DAY, -6, cte.winlostdate), DATEADD(DAY, 2-DATEPART(WEEKDAY,cte.winlostdate),cte.winlostdate)) AS StartOfWeek
			, IIF(DATEPART(WEEKDAY, cte.winlostdate) = 1, cte.winlostdate, DATEADD(DAY, 7-DATEPART(WEEKDAY,cte.winlostdate) + 1,cte.winlostdate)) AS EndOfWeek
		from #WeekRange cte
	)
	SELECT DISTINCT DATEPART(WEEK, StartOfWeek) AS WeekOfYear
		, IIF(StartOfWeek <= @FromDate, @FromDate, StartOfWeek) AS StartOfWeek
		, IIF(EndOfWeek >= @ToDate, @ToDate, EndOfWeek) AS EndOfWeek
	FROM CTE_WeekRange
END