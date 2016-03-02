ALTER PROCEDURE [dbo].[Age_CustomerSelCreditBalanceList_MAg]
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
Task : Credit/Balance of Master Agent
DB: DB052.bodb02
Original: CustAccountSelCreditList_MAg_1

Revisions:
    - 20060222: remove refno  
	- 20060320: split table Customer
	- 20080102@Vinh: add yesterday balance column
	- 20090212@Phuc: paging
	- 20090214@AnhPham: added getting data by username and status
	- 20090710@Phuc: unhide IP for TB currency.
	- 20090812@Phuc: add new filter enabled.
	- 20110516@Johnson: Apply new arrange bettype
	- 20110617@Amy: modify to convert NULL for lastlogged
	- 20110823@Sophia: Count Negative stake as positive turnover
	- 20140304@Kathy: modify formula of Outstanding amount to be calculated based on table Bettrans and TransLog [Redmine:#11550]
	- 20150707@Jim: exclude Metric Gaming running ticket from bettrans (Feature #38789)
	- 20151222@Percy: exclude Cockfighting running ticket from bettrans [Redmine: #48601]
	- 20160112@Percy: Expand new bettype for RNG Casino [Redmine: #48283]
	
Param's Explanation:
• @CustID: MAgentID
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
	[lastlogged] smalldatetime null
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
		recommend as custid,
		ISNULL(SUM(case when ruben=0 then CASE WHEN winlostdate >= @ABSDate THEN ABS(actual_stake) ELSE actual_stake END * apositiontaking else 0 end),0) AS outstanding, 
		ISNULL(SUM(case when custid=recommend then winlost-actual_stake else awinlost+comm-playercomm end),0) AS balance,
		ISNULL(SUM(case when matchid > 0 then CASE WHEN winlostdate >= @ABSDate THEN ABS(actual_stake) ELSE actual_stake END else 0 end), 0) as turnover
	FROM bettrans with (NOLOCK)
	WHERE mrecommend=@CustID
		AND (
				(bettrans.bettype NOT IN (801,802,803,804,805,806,1003) AND bettype NOT BETWEEN 2101 AND 2399 AND ruben =0)
				OR ruben <> 0
			)
		AND (
				(CONVERT(DATE, winlostdate) >= @yesterday AND bettype NOT BETWEEN 2101 AND 2399)
				OR CONVERT(DATE, winlostdate) < @yesterday
			)
	GROUP BY recommend
	UNION ALL
	SELECT recommend as custid,
		ISNULL(SUM(CASE WHEN winlostdate >= @ABSDate THEN ABS(actual_stake) ELSE actual_stake END * apositiontaking),0) AS outstanding, 
		0 balance,
		0 turnover
	from translog with(NOLOCK)
	WHERE statusid = 0
	and mrecommend=@CustID
	GROUP BY recommend
	UNION ALL
	SELECT
		recommend as custid,
		ISNULL(SUM(case when statusID IN (0, 1) then actual_stake * apositiontaking else 0 end),0) outstanding, 
		ISNULL(SUM(case when CONVERT(DATE, winlostdate) >= @yesterday THEN CASE WHEN custid=recommend then winlost-actual_stake else awinlost+comm-playercomm end ELSE 0 END),0) AS balance,
		ISNULL(SUM(CASE WHEN CONVERT(DATE, winlostdate) >= @yesterday THEN actual_stake ELSE 0 END), 0) as turnover
	FROM bettransRNG with (NOLOCK)
	WHERE mrecommend=@CustID
		AND gameID BETWEEN 2101 AND 2399
	GROUP BY recommend
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
		recommend as custid,
		sum(awinlost+comm-playercomm) AS balance
	FROM bettrans with (NOLOCK)
	WHERE mrecommend=@CustID AND ruben = 1 AND bettype < 19001 AND bettype NOT BETWEEN 2101 AND 2399
		AND CONVERT(DATE, winlostdate) = @today
	GROUP BY recommend
	UNION ALL
	SELECT
		recommend as custid,
		sum(awinlost+comm-playercomm) AS balance
	FROM bettransRNG with (NOLOCK)
	WHERE mrecommend=@CustID AND statusID NOT IN (0, 1, 101, 102) AND gameID BETWEEN 2101 AND 2399
		AND CONVERT(DATE, winlostdate) = @today
	GROUP BY recommend
) AS A
GROUP BY custid

SET @Username = isnull(@Username, '')
--Filter user
IF @Username = ''
	INSERT INTO #tmp_customer 
	SELECT 
		c.custid, ci.enabled, c.username, c.iplogin, ci.closed, isnull(ci.reject,0) as suspended, c.firstname, c.lastname, ci.credit, c.lastlogged		
	FROM
		CustInfo as ci with (NOLOCK,index=ix_custinfo) inner join Customer c (nolock) on ci.custid = c.custid
	WHERE 
		ci.roleid=2 and ci.mrecommend=@CustID 
		AND enabled = case when coalesce(@Closed,@Suspended) is not null then 1 else coalesce(@enabled, enabled) end
		and	isnull(ci.closed,0) = case when @Suspended = 1 then 0 else coalesce(@closed, isnull(ci.closed, 0)) end
		and isnull(ci.reject,0) = case when @Closed = 0 then 0 else coalesce(@Suspended, isnull(ci.reject, 0))end
ELSE
	INSERT INTO #tmp_customer 
	SELECT 
		c.custid, ci.enabled, c.username, c.iplogin, ci.closed, isnull(ci.reject,0) as suspended, c.firstname, c.lastname, ci.credit, c.lastlogged		
	FROM
		CustInfo as ci with (NOLOCK,index=ix_custinfo) inner join Customer c (nolock) on ci.custid = c.custid
	WHERE 
		ci.roleid=2 and ci.mrecommend=@CustID and ci.username like '%' + @Username + '%' 
		AND enabled = case when coalesce(@Closed,@Suspended) is not null then 1 else coalesce(@enabled, enabled) end
		and	isnull(ci.closed,0) = case when @Suspended = 1 then 0 else coalesce(@closed, isnull(ci.closed, 0)) end
		and isnull(ci.reject,0) = case when @Closed = 0 then 0 else coalesce(@Suspended, isnull(ci.reject, 0))end

IF @TotalPages = 0
BEGIN
	SELECT 
		@TotalPages = count(1),@TotalPages=@TotalPages/@PageSize + case when @TotalPages%@PageSize>0 then 1 else 0 end
	FROM
		#tmp_customer
END

SELECT * FROM 
(
	SELECT ROW_NUMBER() OVER (ORDER BY c.enabled desc, c.closed, suspended, c.username) as RowNumber,
		c.username,c.enabled,
		isnull(c.iplogin, '')as iplogin, 
		c.custid, 		
		c.closed closed,		
		suspended,
		c.firstname, 
		c.lastname, 
		isnull(balance.outstanding,0) AS outstanding, 
		isnull(balance.balance,0) AS balance, 
		isnull(balance.balance,0) - isnull(today_balance.balance,0) yesterday_balance,
		isnull(balance.balance,0) + isnull(c.credit,0) - isnull(balance.outstanding,0) betCredit,
		isnull(balance.turnover,0) AS turnover,
		isnull(c.credit,0) credit,		
		CONVERT(nvarchar(30), c.lastlogged, 121) as lastlogged
	FROM #tmp_customer c
		LEFT JOIN #balance AS balance ON c.custid = balance.custid 
		LEFT JOIN #today_balance AS today_balance on c.custid = today_balance.custid 
		--Members'Bet is settled today @Phuong20080930 
)a
WHERE a.RowNumber BETWEEN @RowStart AND @RowEND

drop table #balance
drop table #today_balance
drop table #tmp_customer
GO
GRANT EXECUTE ON [dbo].[Age_CustomerSelCreditBalanceList_MAg] TO [bodbDownlineNet] AS [dbo]
GO
GRANT EXECUTE ON [dbo].[Age_CustomerSelCreditBalanceList_MAg] TO [bodbDownlineNetView] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[Age_CustomerSelCreditBalanceList_MAg] TO [vnteam] AS [dbo]
GO