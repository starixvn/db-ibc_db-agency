ALTER PROCEDURE	dbo.Age_CustomerSelWinlimitInfo
					@CustId			INT
				,	@BetType		SMALLINT
				,	@mrecommend		INT				= 0
				,	@recommend		INT				= 0
				,	@username		NVARCHAR(50)	= ''
				,	@PageSize		INT				= 500
				,	@PageIndex		INT				= 1
				,	@TotalRows		INT				= 0			OUTPUT
AS
/*
	Create:		20150715@Patrick
	Task:		Member win limit of Super
	DB:			DBTXN/CustDB
	Original:	Age_CustomerSelCreditBalanceList_SAg
	
	Revisions:
		- 20160118@Patrick:	inlcude ticket from bettransRnG table
		- 20160219@Billy:	Add filter by username - apply for AllBet - [Redmine: #52268]
		- 20160318@Billy:	Include tickets from [bettransLC] table - [Redmine: #54306]
	
	Param's Explanation:
		- @CustID: SAgentID
*/
BEGIN

	SET NOCOUNT ON

	DECLARE @RoleId TINYINT, @RowCount INT, @RowStart INT, @RowEnd INT, @srecommend INT
		, @yesterday SMALLDATETIME

	SELECT @PageIndex = @PageIndex - 1
		, @RowStart = @PageSize * @PageIndex + 1
		, @RowEnd = @RowStart + @PageSize - 1

	IF	@username = ''
		SELECT	@username = NULL

	CREATE TABLE #MemberBalance (CustId INT, Balance MONEY)

	SELECT @RoleId = RoleId, @srecommend = srecommend
	FROM dbo.CustInfo c WITH(NOLOCK)
	WHERE CustId = @CustId

	SELECT @yesterday = CAST(DATEADD(dd, -1, GETDATE()) AS DATE)
	 
	IF @RoleId = 4
	BEGIN
		INSERT INTO #MemberBalance(CustId, Balance)
		SELECT c.custid, ISNULL(SUM(CASE WHEN b.bettype BETWEEN 2101 AND 2399 AND winlostdate >= @yesterday THEN 0
										ELSE winlost - actual_stake + playercomm END), 0) AS Balance
		FROM dbo.CustInfo c WITH(NOLOCK)
			LEFT JOIN bodb02.dbo.bettrans b WITH(NOLOCK) ON c.CustId = b.CustId
		WHERE c.srecommend = @CustId
			AND roleid = 1
			AND c.mrecommend = @mrecommend
			AND (@recommend = 0 OR (@recommend <> 0 AND c.recommend = @recommend))
			AND b.statusID NOT IN (0,1,101,102)
			AND	c.username LIKE '%' + ISNULL(@username, c.username) + '%'
		GROUP BY c.custid

		--get data from bettransRnG table within 2 days: today & yesterday
		UNION ALL
		SELECT c.custid, ISNULL(SUM(winlost - actual_stake + playercomm), 0) AS Balance
		FROM dbo.CustInfo c WITH(NOLOCK)
			LEFT JOIN bodb02.dbo.bettransRNG b WITH(NOLOCK) ON c.CustId = b.CustId
		WHERE c.srecommend = @CustId
			AND roleid = 1
			AND c.mrecommend = @mrecommend
			AND (@recommend = 0 OR (@recommend <> 0 AND c.recommend = @recommend))
			AND b.statusID NOT IN (0,1,101,102)
			AND winlostdate >= @yesterday
			AND	c.username LIKE '%' + ISNULL(@username, c.username) + '%'
		GROUP BY c.custid
		
		-- 20160318@Billy: Get tickets from [bettransLC] table within 2 days: today & yesterday
		UNION ALL
		SELECT	ci.custid, ISNULL(SUM(blc.winlost - blc.actual_stake + blc.playercomm), 0) AS Balance
		FROM		dbo.custInfo AS ci WITH (NOLOCK)
		LEFT JOIN	bodb02.dbo.bettransLC AS blc WITH (NOLOCK)
				ON	blc.custid = ci.custid
		WHERE	ci.srecommend = @CustId
			AND	ci.roleid = 1
			AND	ci.mrecommend = @mrecommend
			AND	(@recommend = 0 OR (@recommend <> 0 AND ci.recommend = @recommend))
			AND	blc.statusID NOT IN (0, 1, 101, 102)
			AND	blc.winlostdate >= @yesterday
			AND	ci.username LIKE '%' + ISNULL(@username, ci.username) + '%'
		GROUP BY ci.custid
	END
	ELSE IF @RoleId = 3
	BEGIN
		INSERT INTO #MemberBalance(CustId, Balance)
		SELECT c.custid, ISNULL(SUM(CASE WHEN b.bettype BETWEEN 2101 AND 2399 AND winlostdate >= @yesterday THEN 0
										ELSE winlost - actual_stake + playercomm END), 0) AS Balance
		FROM dbo.CustInfo c WITH(NOLOCK)
			LEFT JOIN bodb02.dbo.bettrans b WITH(NOLOCK) ON c.CustId = b.CustId
		WHERE c.mrecommend = @CustId
			AND roleid = 1
			AND c.srecommend = @srecommend 
			AND c.recommend = @recommend
			AND b.statusID NOT IN (0,1,101,102)
			AND	c.username LIKE '%' + ISNULL(@username, c.username) + '%'
		GROUP BY c.custid

		--get data from bettransRnG table within 2 days: today & yesterday
		UNION ALL
		SELECT c.custid, ISNULL(SUM(winlost - actual_stake + playercomm), 0) AS Balance
		FROM dbo.CustInfo c WITH(NOLOCK)
			LEFT JOIN bodb02.dbo.bettransRNG b WITH(NOLOCK) ON c.CustId = b.CustId
		WHERE c.mrecommend = @CustId
			AND roleid = 1
			AND c.srecommend = @srecommend 
			AND c.recommend = @recommend
			AND b.statusID NOT IN (0,1,101,102)
			AND winlostdate >= @yesterday
			AND	c.username LIKE '%' + ISNULL(@username, c.username) + '%'
		GROUP BY c.custid
		
		-- 20160318@Billy: Get tickets from [bettransLC] table within 2 days: today & yesterday
		UNION ALL
		SELECT	ci.custid, ISNULL(SUM(blc.winlost - blc.actual_stake + blc.playercomm), 0) AS Balance
		FROM		dbo.custInfo AS ci WITH (NOLOCK)
		LEFT JOIN	bodb02.dbo.bettransLC AS blc WITH (NOLOCK)
				ON	blc.custid = ci.custid
		WHERE	ci.mrecommend = @CustId
			AND	ci.roleid = 1
			AND	ci.srecommend = @srecommend
			AND	ci.recommend = @recommend
			AND	blc.statusID NOT IN (0, 1, 101, 102)
			AND	blc.winlostdate >= @yesterday
			AND	ci.username LIKE '%' + ISNULL(@username, ci.username) + '%'
		GROUP BY ci.custid
	END
	ELSE IF @RoleId = 2
	BEGIN
		INSERT INTO #MemberBalance(CustId, Balance)
		SELECT c.custid, ISNULL(SUM(CASE WHEN b.bettype BETWEEN 2101 AND 2399 AND winlostdate >= @yesterday THEN 0
										ELSE winlost - actual_stake + playercomm END), 0) AS Balance
		FROM dbo.CustInfo c WITH(NOLOCK)
			LEFT JOIN bodb02.dbo.bettrans b WITH(NOLOCK) ON c.CustId = b.CustId
		WHERE c.recommend = @CustId
			AND roleid = 1
			AND c.srecommend = @srecommend
			AND b.statusID NOT IN (0,1,101,102)
			AND	c.username LIKE '%' + ISNULL(@username, c.username) + '%'
		GROUP BY c.custid

		--get data from bettransRnG table within 2 days: today & yesterday
		UNION ALL
		SELECT c.custid, ISNULL(SUM(winlost - actual_stake + playercomm), 0) AS Balance
		FROM dbo.CustInfo c WITH(NOLOCK)
			LEFT JOIN bodb02.dbo.bettransRNG b WITH(NOLOCK) ON c.CustId = b.CustId
		WHERE c.recommend = @CustId
			AND roleid = 1
			AND c.srecommend = @srecommend
			AND b.statusID NOT IN (0,1,101,102)
			AND winlostdate >= @yesterday
			AND	c.username LIKE '%' + ISNULL(@username, c.username) + '%'
		GROUP BY c.custid
		
		-- 20160318@Billy: Get tickets from [bettransLC] table within 2 days: today & yesterday
		UNION ALL
		SELECT	ci.custid, ISNULL(SUM(blc.winlost - blc.actual_stake + blc.playercomm), 0) AS Balance
		FROM		dbo.custInfo AS ci WITH (NOLOCK)
		LEFT JOIN	bodb02.dbo.bettransLC AS blc WITH (NOLOCK)
				ON	blc.custid = ci.custid
		WHERE	ci.recommend = @CustId
			AND	ci.roleid = 1
			AND	ci.srecommend = @srecommend
			AND	blc.statusID NOT IN (0, 1, 101, 102)
			AND	blc.winlostdate >= @yesterday
			AND	ci.username LIKE '%' + ISNULL(@username, ci.username) + '%'
		GROUP BY ci.custid
	END
	
	--Calc total rows
	SELECT @TotalRows = COUNT(1)
	FROM #MemberBalance

	CREATE TABLE #TempData(RowNumber INT, CustId INT, Balance MONEY)
	INSERT INTO #TempData(RowNumber, CustId, Balance)
	SELECT RowNumber, CustId, Balance
	FROM (
		SELECT ROW_NUMBER() OVER (ORDER BY c.enabled DESC, c.closed, ISNULL(c.reject, 0), c.username) AS RowNumber
			, b.CustId
			, SUM(b.Balance) AS Balance
		FROM #MemberBalance b
			INNER JOIN dbo.custInfo c WITH(NOLOCK) ON b.CustId = c.CustId
		GROUP BY b.CustId, c.enabled, c.closed, ISNULL(c.reject, 0), c.username
	)tmp
	WHERE tmp.RowNumber BETWEEN @RowStart AND @RowEnd

	SELECT bc.RowNumber, bc.Balance, bc.CustId, CreditBalance, DebitBalance
	FROM (
		SELECT d.RowNumber, d.CustId, d.Balance
			, SUM(ISNULL(bc.Balance, 0)) AS CreditBalance
		FROM #TempData d
			LEFT JOIN bodb02.dbo.BalanceCreditGame bc WITH(NOLOCK) ON d.CustId = bc.custid AND bc.bettype = @BetType
		GROUP BY d.RowNumber, d.CustId, d.Balance
	)bc
	INNER JOIN (
		SELECT d.RowNumber, d.CustId, d.Balance
			, SUM(ISNULL(bd.Balance, 0)) AS DebitBalance
		FROM #TempData d
			LEFT JOIN bodb02.dbo.BalanceDebitGame bd WITH(NOLOCK) ON d.CustId = bd.custid AND bd.bettype = @BetType
		GROUP BY d.RowNumber, d.CustId, d.Balance
	)bd ON bc.CustId = bd.CustId
	ORDER BY RowNumber

	DROP TABLE #MemberBalance
	DROP TABLE #TempData
END


GO
GRANT EXECUTE ON [dbo].[Age_CustomerSelWinlimitInfo] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_CustomerSelWinlimitInfo] TO [bodbDownlineNetView]
GO
GRANT VIEW DEFINITION ON [dbo].[Age_CustomerSelWinlimitInfo] TO vnteam