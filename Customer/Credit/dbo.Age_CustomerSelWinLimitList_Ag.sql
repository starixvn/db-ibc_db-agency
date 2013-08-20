ALTER PROCEDURE [dbo].[Age_CustomerSelWinLimitList_Ag]
	@CustID int,
	@PageSize int=500,
	@PageIndex int=1,
	@Username varchar(30)=null,
	@Enabled bit = null,
	@Closed bit=null,
	@Suspended bit = null	
AS

/*
Created By: Dan
Created Date: 2012-09-27 
Task : Win Limit of members
DB: DBTRANS.bodb02
Original: [Age_CustomerSelCreditBalanceList_Ag]

Revisions:	
	- 20121026@Jamie: Set WinLimit = 0 in case Credit = 0 
	- 20130708@Viet: create new param @_username to resolve parameter sniffing's issue.
	
Param's Explanation:
• @CustID: AgentID
*/
--return 
SET NOCOUNT ON

DECLARE @RowCount int, @RowStart int, @RowEnd int
SELECT @PageIndex = @PageIndex - 1, @RowStart = @PageSize * @PageIndex + 1, @RowEnd = @RowStart + @PageSize - 1 

DECLARE @_Username varchar(30)
SET @_Username = isnull(@Username, '')

CREATE TABLE #tmp_customer
(
	[custid] int primary key,		
	[username] varchar(30),
	[enabled] bit,
	[closed] bit,
	[suspended] bit,
	[MaxWinLiveCasino] smallmoney,
	[MaxWinLimit] money	
)

CREATE TABLE #GameBalance  
(
	custid int primary key,	
	balance money	
)

INSERT INTO #GameBalance  
SELECT credit.custid, ISNULL(credit.Balance,0) - ISNULL(debit.Balance,0) as Balance
FROM 
(
	SELECT
		ci.custid,  SUM(b.balance) as Balance		
	FROM custinfo ci WITH (NOLOCK) 
		LEFT JOIN BalanceCreditGame b WITH (NOLOCK) ON b.custid=ci.custid	
	WHERE recommend=@CustID and roleid=1
	GROUP BY ci.custid
) credit 
JOIN 
(
	SELECT
		ci.custid,  SUM(b.balance) as Balance		
	FROM custinfo ci WITH (NOLOCK) 
		LEFT JOIN BalanceDebitGame b WITH (NOLOCK) ON b.custid=ci.custid
	WHERE recommend=@CustID and roleid=1
	GROUP BY ci.custid
) Debit ON credit.custid=debit.custid

--Filter user
IF @_Username = ''
	INSERT INTO #tmp_customer 
	SELECT	ci.custid, ci.username, ci.enabled, ci.closed, isnull(ci.reject,0) as suspended, ci.MaxWinLiveCasino, 
			CASE WHEN ci.credit = 0 THEN 1 ELSE ci.MaxWinLiveCasino*ci.credit END		--MaxWinLimit 
	FROM CustInfo as ci with (NOLOCK) 
	WHERE ci.roleid = 1 AND @CustID = ci.recommend
		AND enabled = case when coalesce(@Closed,@Suspended) is not null then 1 else coalesce(@enabled, enabled) end
		AND isnull(ci.closed,0) = case when @suspended = 1 then 0 else coalesce(@closed, isnull(ci.closed, 0)) end
		AND isnull(ci.reject,0) = case when @Closed = 0 then 0 else coalesce(@suspended, isnull(ci.reject, 0))end			
ELSE
	INSERT INTO #tmp_customer 
	SELECT	ci.custid, ci.username, ci.enabled, ci.closed, isnull(ci.reject,0) as suspended, ci.MaxWinLiveCasino, 
			CASE WHEN ci.credit = 0 THEN 1 ELSE ci.MaxWinLiveCasino*ci.credit END		--MaxWinLimit 	
	FROM CustInfo as ci with (NOLOCK) 
	WHERE ci.roleid = 1 AND @CustID = ci.recommend
		AND ci.username like '%' + @_Username + '%'  
		AND enabled = case when coalesce(@Closed,@Suspended) is not null then 1 else coalesce(@enabled, enabled) end
		AND isnull(ci.closed,0) = case when @suspended = 1 then 0 else coalesce(@closed, isnull(ci.closed, 0)) end
		AND isnull(ci.reject,0) = case when @Closed = 0 then 0 else coalesce(@suspended, isnull(ci.reject, 0))end			

SELECT * FROM 
(
	SELECT ROW_NUMBER() OVER (ORDER BY c.enabled desc, c.closed, c.suspended, c.username) as RowNumber,
		c.custid, c.username, 
		case when c.MaxWinLiveCasino = 0 then -1 -- unlimited
		else case when gamebalance.Balance > 0 then gamebalance.Balance*100/c.MaxWinLimit
				else 0 end
		end as LCSWinPercent
	FROM #tmp_customer c 		
		LEFT JOIN #GameBalance AS gamebalance ON c.custid = gamebalance.custid 				
)a 
WHERE a.RowNumber BETWEEN @RowStart AND @RowEND

drop table #GameBalance
drop table #tmp_customer

GO
GRANT EXECUTE ON [dbo].[Age_CustomerSelWinLimitList_Ag] TO [bodbDownlineNet] AS [dbo]
GO
GRANT EXECUTE ON [dbo].[Age_CustomerSelWinLimitList_Ag] TO [bodbDownlineNetView] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[Age_CustomerSelWinLimitList_Ag] TO [vnteam] AS [dbo]