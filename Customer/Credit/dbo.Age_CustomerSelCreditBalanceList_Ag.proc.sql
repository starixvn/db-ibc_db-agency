ALTER PROCEDURE [Age_CustomerSelCreditBalanceList_Ag] @CustID INT
	,@PageSize INT = 500
	,@PageIndex INT = 1
	,@Username VARCHAR(30) = NULL
	,@Enabled BIT = NULL
	,@Closed BIT = NULL
	,@Suspended BIT = NULL
	,@TotalPages INT = 0 OUTPUT
AS
/*

Task : Credit/Balance of Agent

DB: DBAGE/bodb02

Original: CustAccountSelCreditList_Ag_1



Revisions:

    - 20060222: remove refno  
	- 20060320: split table Customer
	- 20080102@Vinh: add yesterday balance column
	- 20090212@Phuc: paging
	- 20090214@AnhPham: added getting data by username and status
	- 20090710@Phuc: unhide IP for TB currency.
	- 20090812@Phuc: add new filter enabled.
	- 20110516@Johnson: apply new arrange bettype
	- 20110617@Amy: modify to convert NULL for lastlogged
	- 20110823@Sophia: Count Negative stake as positive turnover
	- 20140304@Kathy: modify formula of Outstanding amount to be calculated based on table Bettrans and TransLog [Redmine:#11550]
	- 20150707@Jim: exclude Metric Gaming running ticket from bettrans (Feature #38789)
	- 20151222@Percy: exclude Cockfighting running ticket from bettrans [Redmine: #48601]

Param's Explanation:

• @CustID: AgentID

*/
SET NOCOUNT ON

DECLARE @ABSDate DATETIME

SET @ABSDate = '2011-09-01'

DECLARE @RowCount INT
	,@RowStart INT
	,@RowEnd INT

SELECT @PageIndex = @PageIndex - 1
	,@RowStart = @PageSize * @PageIndex + 1
	,@RowEnd = @RowStart + @PageSize - 1

SET @Username = isnull(@Username, '')

--SET @Username = @Username + '%'
CREATE TABLE #tmp_customer (
	[custid] INT PRIMARY KEY
	,[enabled] BIT
	,[username] VARCHAR(30)
	,[iplogin] NVARCHAR(20) NULL
	,[closed] BIT
	,[suspended] BIT
	,[firstname] NVARCHAR(50) NULL
	,[lastname] NVARCHAR(50) NULL
	,[credit] MONEY NULL
	,[lastlogged] SMALLDATETIME NULL
	)

CREATE TABLE #balance (
	custid INT PRIMARY KEY
	,outstanding MONEY
	,balance MONEY
	,turnover MONEY
	);

WITH rt
AS (
	SELECT custid
		,ISNULL(sum(CASE 
					WHEN ruben = 0 THEN CASE 
							WHEN winlostdate >= @ABSDate THEN ABS(actual_stake)
							ELSE actual_stake
							END
					ELSE 0
					END), 0) outstanding
		,ISNULL(sum(CASE 
					WHEN ruben = 1 THEN winlost - actual_stake + playercomm
					ELSE 0
					END), 0) balance
		,IsNull(sum(CASE 
					WHEN matchid > 0 THEN CASE 
							WHEN winlostdate >= @ABSDate THEN ABS(actual_stake)
							ELSE actual_stake
							END
					ELSE 0
					END), 0) AS turnover
	FROM bettrans WITH (NOLOCK)
	WHERE recommend = @custid
		AND (
			(bettrans.bettype NOT IN (801,802,803,804,805,806,1003)
			AND ruben =0)
			OR ruben <> 0
			)
	GROUP BY custid
	
	UNION ALL
	SELECT custid
		,ISNULL(sum(CASE 
					WHEN winlostdate >= @ABSDate THEN ABS(actual_stake)
					ELSE actual_stake
					END), 0) outstanding
		,0 AS balance
		,0 AS turnover
	FROM translog WITH (NOLOCK)
	WHERE statusid = 0 AND recommend = @custid
	GROUP BY custid
	)
INSERT INTO #balance
SELECT custid
	,sum(outstanding)
	,sum(balance)
	,sum(turnover)
FROM rt
GROUP BY custid

CREATE TABLE #today_balance (
	custid INT PRIMARY KEY
	,balance MONEY
	)

INSERT INTO #today_balance
SELECT custid
	,sum(winlost - actual_stake + playercomm) balance
FROM bettrans WITH (NOLOCK)
WHERE recommend = @CustID AND ruben = 1 AND bettype < 19001 AND winlostdate >= convert(VARCHAR(10), current_timestamp, 120)
	 
GROUP BY custid

--Filter user
IF @Username = ''
	INSERT INTO #tmp_customer
	SELECT c.custid
		,ci.enabled
		,c.username
		,c.iplogin
		,ci.closed
		,isnull(ci.reject, 0) AS suspended
		,c.firstname
		,c.lastname
		,ci.credit
		,c.lastlogged
	FROM CustInfo AS ci WITH (NOLOCK, INDEX = ix_custinfo_1)
		INNER JOIN Customer c(NOLOCK) ON ci.custid = c.custid
	WHERE 1 = ci.roleid AND @CustID = ci.recommend AND enabled = CASE 
			WHEN coalesce(@Closed, @Suspended) IS NOT NULL THEN 1
			ELSE coalesce(@enabled, enabled)
			END AND isnull(ci.closed, 0) = CASE 
			WHEN @suspended = 1 THEN 0
			ELSE coalesce(@closed, isnull(ci.closed, 0))
			END AND isnull(ci.reject, 0) = CASE 
			WHEN @Closed = 0 THEN 0
			ELSE coalesce(@suspended, isnull(ci.reject, 0))
			END
ELSE
	INSERT INTO #tmp_customer
	SELECT c.custid
		,ci.enabled
		,c.username
		,c.iplogin
		,ci.closed
		,isnull(ci.reject, 0) AS suspended
		,c.firstname
		,c.lastname
		,ci.credit
		,c.lastlogged
	FROM CustInfo AS ci WITH (NOLOCK, INDEX = ix_custinfo_1)
		INNER JOIN Customer c(NOLOCK) ON ci.custid = c.custid
	WHERE 1 = ci.roleid AND @CustID = ci.recommend AND ci.username LIKE '%' + @Username + '%' AND enabled = CASE 
			WHEN coalesce(@Closed, @Suspended) IS NOT NULL THEN 1
			ELSE coalesce(@enabled, enabled)
			END AND isnull(ci.closed, 0) = CASE 
			WHEN @suspended = 1 THEN 0
			ELSE coalesce(@closed, isnull(ci.closed, 0))
			END AND isnull(ci.reject, 0) = CASE 
			WHEN @Closed = 0 THEN 0
			ELSE coalesce(@suspended, isnull(ci.reject, 0))
			END

IF @TotalPages = 0
BEGIN
	SELECT @TotalPages = count(1)
		,@TotalPages = @TotalPages / @PageSize + CASE 
			WHEN @TotalPages % @PageSize > 0 THEN 1
			ELSE 0
			END
	FROM #tmp_customer
END

SELECT *
FROM (
	SELECT ROW_NUMBER() OVER (
			ORDER BY c.enabled DESC
				,c.closed
				,c.suspended
				,c.username
			) AS RowNumber
		,c.username
		,c.enabled
		,isnull(c.iplogin, '') AS iplogin
		,c.custid
		,c.closed closed
		,c.suspended
		,c.firstname
		,c.lastname
		,isnull(balance.outstanding, 0) outstanding
		,isnull(balance.balance, 0) balance
		,isnull(balance.balance, 0) - isnull(today_balance.balance, 0) yesterday_balance
		,isnull(balance.balance, 0) + isnull(c.credit, 0) - isnull(balance.outstanding, 0) betCredit
		,isnull(balance.turnover, 0) AS turnover
		,isnull(c.credit, 0) AS credit
		,CONVERT(NVARCHAR(30), c.lastlogged, 121) AS lastlogged
	FROM #tmp_customer c
		LEFT JOIN #balance AS balance ON c.custid = balance.custid
		LEFT JOIN #today_balance AS today_balance ON c.custid = today_balance.custid
		--Members'Bet is settled today @Phuong20080930
	) a
WHERE a.RowNumber BETWEEN @RowStart AND @RowEND

DROP TABLE #balance

DROP TABLE #today_balance

DROP TABLE #tmp_customer


GO
GRANT EXECUTE ON [dbo].[Age_CustomerSelCreditBalanceList_Ag] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_CustomerSelCreditBalanceList_Ag] TO [bodbDownlineNetView]
GO
GRANT VIEW DEFINITION ON [dbo].[Age_CustomerSelCreditBalanceList_Ag] TO [vnteam]
GO
