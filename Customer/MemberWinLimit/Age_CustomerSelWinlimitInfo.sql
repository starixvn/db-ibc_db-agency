USE custdb
GO 
ALTER PROCEDURE dbo.Age_CustomerSelWinlimitInfo @CustId INT
	, @BetType SMALLINT
	, @mrecommend INT = 0
	, @recommend INT = 0
	
	, @PageSize INT = 500
	, @PageIndex INT = 1
	
	, @TotalRows INT = 0 OUTPUT
AS
/*
Create: 20150715@Patrick
Task: Member win limit of Super
DB: DBTXN.custdb
Original: Age_CustomerSelCreditBalanceList_SAg

Revisions:

Param's Explanation:
• @CustID: SAgentID
*/
BEGIN

	SET NOCOUNT ON

	DECLARE @RoleId TINYINT, @RowCount INT, @RowStart INT, @RowEnd INT, @srecommend INT
	SELECT @PageIndex = @PageIndex - 1
		, @RowStart = @PageSize * @PageIndex + 1
		, @RowEnd = @RowStart + @PageSize - 1

	CREATE TABLE #MemberBalance (CustId INT, Balance MONEY)

	SELECT @RoleId = RoleId, @srecommend = srecommend
	FROM dbo.CustInfo c WITH(NOLOCK)
	WHERE CustId = @CustId
	 
	IF @RoleId = 4
	BEGIN
		INSERT INTO #MemberBalance(CustId, Balance)
		SELECT c.custid, ISNULL(SUM(winlost - actual_stake + playercomm), 0) AS Balance
		FROM dbo.CustInfo c WITH(NOLOCK)
			LEFT JOIN bodb02.dbo.bettrans b WITH(NOLOCK) ON c.CustId = b.CustId
		WHERE c.srecommend = @CustId
			AND roleid = 1
			AND c.mrecommend = @mrecommend
			AND (@recommend = 0 OR (@recommend <> 0 AND c.recommend = @recommend))
		GROUP BY c.custid
	END
	ELSE IF @RoleId = 3
	BEGIN
		INSERT INTO #MemberBalance(CustId, Balance)
		SELECT c.custid, ISNULL(SUM(winlost - actual_stake + playercomm), 0) AS Balance
		FROM dbo.CustInfo c WITH(NOLOCK)
			LEFT JOIN bodb02.dbo.bettrans b WITH(NOLOCK) ON c.CustId = b.CustId
		WHERE c.mrecommend = @CustId
			AND roleid = 1
			AND c.srecommend = @srecommend 
			AND c.recommend = @recommend
		GROUP BY c.custid
	END
	ELSE IF @RoleId = 2
	BEGIN
		INSERT INTO #MemberBalance(CustId, Balance)
		SELECT c.custid, ISNULL(SUM(winlost - actual_stake + playercomm), 0) AS Balance
		FROM dbo.CustInfo c WITH(NOLOCK)
			LEFT JOIN bodb02.dbo.bettrans b WITH(NOLOCK) ON c.CustId = b.CustId
		WHERE c.recommend = @CustId
			AND roleid = 1
			AND c.srecommend = @srecommend
		GROUP BY c.custid
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
			, b.Balance
		FROM #MemberBalance b
			INNER JOIN dbo.custInfo c WITH(NOLOCK) ON b.CustId = c.CustId
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