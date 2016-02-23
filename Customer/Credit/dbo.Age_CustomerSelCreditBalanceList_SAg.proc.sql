ALTER PROCEDURE [dbo].[Age_CustomerSelCreditBalanceList_SAg]
	@CustID int,
	@PageSize int=500,
	@PageIndex int=1,
	@Username varchar(30)=null,
	@Enabled bit = null,
	@Closed bit=null,
	@Suspended bit=null,
	@TotalPages int=0 OUTPUT
AS
/*
Task : Credit/Balance of SAgent
DB: DB052.bodb02
Original: CustAccountSelCreditList_SAg_1

Revisions:
    - 20060222: remove refno  
	- 20060320: split table Customer
	- 20080102@Vinh: add yesterday balance column
	- 20090212@Phuc: paging
	- 20090217@AnhPham: added getting data by username and status
	- 20090710@Phuc: unhide IP for TP currency.
	- 20090812@Phuc: add new filter enabled.
	- 20110516@Johnson: Apply new arrange bettype 
	- 20110617@Amy: modify to convert NULL for lastlogged
	- 20110823@Sophia: Count Negative stake as positive turnover
	- 20140304@Kathy: modify formula of Outstanding amount to be calculated based on table Bettrans and TransLog [Redmine:#11550]
	- 20150707@Jim: exclude Metric Gaming running ticket from bettrans (Feature #38789)
	- 20151222@Percy: exclude Cockfighting running ticket from bettrans [Redmine: #48601]
	- 20160112@Percy: Expand new bettype for RNG Casino [Redmine: #48283]
	- 20160222@Percy: Change formula when calculating bet credit [Redmine: #52653]

Param's Explanation:
• @CustID: SAgentID
*/

SET NOCOUNT ON

DECLARE @ABSDate DATETIME,
		@today DATE,
		@yesterday DATE

SET @ABSDate = '2011-09-01'
SELECT @today = CONVERT(DATE, GETDATE())
SELECT @yesterday = DATEADD(DD, -1, @today)	

DECLARE @RowCount int, @RowStart int, @RowEnd int
SELECT @PageIndex = @PageIndex - 1, @RowStart = @PageSize * @PageIndex + 1, @RowEnd = @RowStart + @PageSize - 1 

CREATE TABLE #tmp_customer
(
	[custid] int primary key,
	[enabled] bit,
	[username] varchar(30),
	[iplogin] nvarchar(20) null,
	[closed] bit,
	[suspended] bit,
	[firstname] nvarchar(50) null,
	[lastname] nvarchar(50) null,
	[credit] money null,
	[lastlogged] smalldatetime null,
	[usedCredit] money null
)


CREATE TABLE #balance  
(
	custid int primary key,
	outstanding money,		
	balance money,
	turnover money
)

;WITH rt
as (
	SELECT
		mrecommend
			AS custid,
		ISNULL(sum(case when ruben=0 then CASE WHEN winlostdate >= @ABSDate THEN ABS(actual_stake) ELSE actual_stake END * mpositiontaking else 0 end),0)
			AS outstanding,
		ISNULL(sum(case when custid=mrecommend then winlost-actual_stake else mwinlost+acomm-comm end),0)
			AS balance, 
		ISNULL(sum(case when matchid > 0 then CASE WHEN winlostdate >= @ABSDate THEN ABS(actual_stake) ELSE actual_stake END else 0 end), 0)
			AS turnover
	FROM bettrans with (NOLOCK)
	WHERE srecommend = @CustID
		AND (
				(ruben = 0 AND bettype NOT IN (801,802,803,804,805,806,1003) AND bettype NOT BETWEEN 2101 AND 2399)
				OR ruben <> 0
			)
		AND (
				(CONVERT(DATE, winlostdate) >= @yesterday AND bettype NOT BETWEEN 2101 AND 2399)
				OR CONVERT(DATE, winlostdate) < @yesterday
			)
		AND (
				(matchid > 0 AND matchid NOT IN (208, 209, 210))
				OR matchid <= 0
			)
	GROUP BY mrecommend
	UNION ALL
	SELECT
		mrecommend
			AS custid,
		ISNULL(SUM(CASE WHEN winlostdate >=@ABSDate THEN ABS(actual_stake) ELSE actual_stake end * mpositiontaking),0)
			AS outstanding,
		0	AS balance, 
		0	AS turnover
	from translog with(NOLOCK)
	WHERE statusid = 0
		AND srecommend = @CustID
	GROUP BY mrecommend
	UNION ALL
	SELECT
		mrecommend as custid,
		ISNULL(sum(case when statusID IN (0, 1) then actual_stake * mpositiontaking else 0 end),0) outstanding,
		ISNULL(sum(case when CONVERT(DATE, winlostdate) >= @yesterday then case when custid=mrecommend then winlost-actual_stake else mwinlost+acomm-comm end else 0 end),0) AS balance, 
		ISNULL(sum(case when CONVERT(DATE, winlostdate) >= @yesterday then actual_stake else 0 end), 0) as turnover
	FROM bettransRNG with (NOLOCK)
	WHERE srecommend = @CustID
		AND gameID BETWEEN 2101 AND 2399
	GROUP BY mrecommend
)
INSERT INTO #balance
SELECT custid,
	sum(outstanding),
	sum(balance),
	sum(turnover)
FROM rt
GROUP BY custid

CREATE TABLE #today_balance
(
	custid int primary key,
	balance money
)
INSERT INTO #today_balance
SELECT custid, SUM(balance) AS balance FROM (
SELECT
	custid,
	SUM(balance) AS balance
FROM (
	SELECT 
		mrecommend as custid,
		isnull(sum(mwinlost+acomm-comm), 0) AS balance
	FROM bettrans with (NOLOCK)
	WHERE srecommend = @CustID AND ruben = 1 AND bettype < 19001 AND bettype NOT BETWEEN 2101 AND 2399
		AND CONVERT(DATE, winlostdate) = @today
	GROUP BY mrecommend
	UNION ALL
	SELECT 
		mrecommend as custid,
		isnull(sum(mwinlost+acomm-comm), 0)AS balance
	FROM bettransRNG with (NOLOCK)
	WHERE srecommend = @CustID AND statusID NOT IN (0, 1) AND gameID BETWEEN 2101 AND 2399
		AND CONVERT(DATE, winlostdate) = @today
	GROUP BY mrecommend
	) AS A
GROUP BY custid
	    
SET @Username = isnull(@Username, '')

--Filter user
IF @Username = ''
	INSERT INTO #tmp_customer 
	SELECT 
		c.custid, ci.enabled, c.username, c.iplogin, ci.closed, isnull(ci.reject,0) as suspended, c.firstname, c.lastname, ci.credit, c.lastlogged, (SELECT SUM(credit) FROM custInfo WITH(NOLOCK) WHERE roleid = 2 AND mrecommend = ci.custid) AS usedCredit
		(SELECT SUM(credit) FROM custInfo WITH(NOLOCK) WHERE roleid = 2 AND mrecommend = ci.custid) AS usedCredit
	FROM 
		CustInfo ci with (NOLOCK) inner join Customer c (nolock) on ci.custid = c.custid
	WHERE 
		c.roleid=3 AND c.srecommend=@CustID 
		AND enabled = case when coalesce(@Closed,@Suspended) is not null then 1 else coalesce(@enabled, enabled) end
		AND isnull(closed,0) = case when @Suspended = 1 then 0 else coalesce(@closed, isnull(closed, 0)) end
		AND isnull(reject,0) = case when @Closed = 0 then 0 else coalesce(@Suspended, isnull(reject, 0))end
ELSE
	INSERT INTO #tmp_customer 
	SELECT 
		c.custid, ci.enabled, c.username, c.iplogin, ci.closed, isnull(ci.reject,0) as suspended, c.firstname, c.lastname, ci.credit, c.lastlogged, (SELECT SUM(credit) FROM custInfo WITH(NOLOCK) WHERE roleid = 2 AND mrecommend = ci.custid) AS usedCredit
		(SELECT SUM(credit) FROM custInfo WITH(NOLOCK) WHERE roleid = 2 AND mrecommend = ci.custid) AS usedCredit
	FROM 
		CustInfo ci with (NOLOCK) inner join Customer c (nolock) on ci.custid = c.custid
	WHERE 
		c.roleid=3 AND c.srecommend=@CustID and c.username like '%' + @Username + '%'  
		AND enabled = case when coalesce(@Closed,@Suspended) is not null then 1 else coalesce(@enabled, enabled) end
		AND isnull(closed,0) = case when @Suspended = 1 then 0 else coalesce(@closed, isnull(closed, 0)) end  
		AND isnull(reject,0) = case when @Closed = 0 then 0 else coalesce(@Suspended, isnull(reject, 0))end

--Calc total pages
IF @TotalPages = 0
BEGIN
		SELECT 
			@TotalPages = count(1),@TotalPages=@TotalPages/@PageSize + case when @TotalPages%@PageSize>0 then 1 else 0 end
		FROM 
			#tmp_customer
END

SELECT * FROM 
(
	SELECT ROW_NUMBER() OVER (ORDER BY c.enabled desc, c.closed, c.suspended, c.username) as RowNumber,
		c.username,c.enabled,
		isnull(c.iplogin, '')as iplogin, 
		c.custid, 
		c.closed, 		
		c.suspended,
		c.firstname, 
		c.lastname, 
		isnull(balance.outstanding,0) AS outstanding, 
		isnull(balance.balance,0) AS balance,
		isnull(balance.balance,0) - isnull(today_balance.balance,0) yesterday_balance,
		isnull(c.credit,0) - isnull(c.usedCredit,0) betCredit,
		isnull(balance.turnover,0) AS turnover,
		isnull(c.credit,0) credit,		
		CONVERT(nvarchar(30), c.lastlogged, 121) as lastlogged
	FROM #tmp_customer c 
		LEFT JOIN #balance AS balance ON c.custid = balance.custid 
		LEFT JOIN #today_balance AS today_balance ON c.custid = today_balance.custid 
)a
WHERE a.RowNumber BETWEEN @RowStart AND @RowEND

drop table #balance
drop table #today_balance
drop table #tmp_customer
GO

GRANT EXECUTE ON [dbo].[Age_CustomerSelCreditBalanceList_SAg] TO [bodbDownlineNet] AS [dbo]
GO

GRANT EXECUTE ON [dbo].[Age_CustomerSelCreditBalanceList_SAg] TO [bodbDownlineNetView] AS [dbo]
GO

GRANT VIEW DEFINITION ON [dbo].[Age_CustomerSelCreditBalanceList_SAg] TO [vnteam] AS [dbo]
GO