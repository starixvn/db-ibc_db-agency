ALTER PROCEDURE [dbo].[Age_Statement_Rpt_Ag]
@custid int=null,
@fromdate 	DATETIME,
@todate 	DATETIME,
@username varchar(50) = NULL, -- for API
@BalanceUpDay	DATETIME ,
@PageSize int=0,
@PageIndex int=0,
@TotalRows int=0 output,
@SumOfTotalAmt money=0 output

/*
Created: 
Task : Statement Report of Agent
DB: DBAGE/bodb02
Original: SP:RptAllStatement

Revisions:
    - Henry@20100820: Provide Agent Historical Statement Report
    - Don@20100915: Add @SumOfTotalAmt to sum of total amount through begin to current page index
	- 20101224@Johnson: Apply new arrange of bettype
	- 20130121@Dan: change linked server DB06 to DBRPT
	- 20130715@Johnson: fix report in case of @fromdate > BUDate (should get from @fromdate not BUDate)	
Param's Explanation:

*/

AS

SET NOCOUNT ON

DECLARE @RowStart int, @RowEnd int  
SELECT @PageIndex = @PageIndex - 1, @RowStart = @PageSize * @PageIndex + 1, @RowEnd = @RowStart + @PageSize - 1

DECLARE @StatementTable TABLE(
	accdate datetime,
	transtype nvarchar(100),
	transdesc nvarchar(300),
	totalamt money
)
DECLARE @f_date DATETIME,
		@t_date DATETIME

SELECT @f_date = @fromdate,
		@t_date = @todate	

if @custid is null
	select @custid = custid from customer with (nolock) where username = @username

IF @todate >= @BalanceUpDay
BEGIN
	IF @FromDate > @BalanceUpDay SELECT @f_Date = @BalanceUpDay 
	
	insert into @StatementTable
	select 
		transdate AS accdate, 
		typenamee AS transtype, 
		transdesc, 
		sum(winlost-actual_stake)  AS totalamt  
	from 
		bettrans  with (nolock) 
		INNER JOIN bettype  with (nolock)  
		ON bettype.typeid=bettrans.bettype 
	where 
		bettype >= 20000  
		and winlostdate between @f_date and @t_date
		and custid=@custid 
	group by
		typenamee,transdesc,transdate,transid
	
	union all
	
	select 
		winlostdate AS accdate,
		'POS' AS transtype, 
		'Position' AS transdesc,  
		sum(awinlost) AS totalamt 
	from 
		bettrans with (nolock) 
	where 
		bettype <= 19999
		and recommend=@custid  
		and winlostdate between @f_date and @t_date
	group by 
		winlostdate 
	having 
		sum(awinlost) <> 0

	union all 

	select  
		winlostdate AS accdate,
		'COM' AS transtype, 
		'Commission' AS transdesc,
		sum(comm-playercomm) AS totalamt  
	from 
		bettrans  with (nolock)  
	where 
		bettype <= 19999
		and recommend=@custid  
		and winlostdate between @f_date and @t_date
	--and playercomm<>0 
	group by 
		winlostdate 
	having 
		sum(comm-playercomm) <> 0

END

IF @fromdate < @BalanceUpDay
BEGIN	
	DECLARE	@PreBalanceUpDay DATETIME
	IF @ToDate >= DATEADD(dd,-1,@BalanceUpDay)
		SELECT @t_Date = DATEADD(dd,-1,@BalanceUpDay) + ' 23:59:59'
		
	SELECT	
		TOP 1 @PreBalanceUpDay = accdate  
	FROM	
		DBRPT.bodb_Report.dbo.Statement with (NOLOCK)
	WHERE	
		custid = @custid 
		AND transdesc = 'OPENING BALANCE' 
		AND accdate <= @f_date
	ORDER BY accdate DESC
	
	SELECT @f_Date = ISNULL(@PreBalanceUpDay,@f_Date)	
	
	insert into @StatementTable
	select 
		accdate,
		transtype,
		transdesc, 
		totalamt
	from DBRPT.bodb_Report.dbo.Statement with (nolock) 
	WHERE custid = @custid AND accdate between @f_date and @t_date
	
END

DECLARE @AccBal money

if (@fromdate <> @BalanceUpDay)
BEGIN
	--get acc bal from current (bettrans)
	SELECT @AccBal = isnull(SUM(totalamt),0)
	FROM @StatementTable
	where accdate < @fromdate
	
	IF EXISTS(select 1 from @StatementTable where accdate >= @fromdate AND @AccBal <>0) 
		INSERT INTO @StatementTable(accdate,transtype,transdesc,totalamt)
		SELECT '', 'BAL', 'ACCUMULATED BALANCE', @AccBal
END

IF ((@PageSize <= 0) AND (@PageIndex <= 0))
BEGIN
	SELECT  
		*,
		ROW_NUMBER() over (order by accdate, case when transdesc like '%opening balance%' then 1 else case when transdesc like '%Position%' then 2 else 3 end end, transdesc)  as RowNum	
	FROM @StatementTable
	where (accdate >= @fromdate OR transdesc = 'ACCUMULATED BALANCE')
	
	RETURN
END

IF @TotalRows = 0  
BEGIN
	SELECT @TotalRows = count(accdate) FROM @StatementTable
	where (accdate >= @fromdate OR transdesc = 'ACCUMULATED BALANCE')
END

Declare @Temp money
SELECT @SumOfTotalAmt = sum(A.totalamt)
FROM
(
	SELECT 
		*,
		ROW_NUMBER() over (order by accdate, case when transdesc like '%opening balance%' then 1 else case when transdesc like '%Position%' then 2 else 3 end end, transdesc)  as RowNum	
	FROM @StatementTable
	where (accdate >= @fromdate OR transdesc = 'ACCUMULATED BALANCE')
) A
WHERE A.RowNum < @RowStart and A.transdesc not like '%opening balance%'
---
Select TOP 1 @Temp = totalamt
From @StatementTable
Where transdesc like '%opening balance%'
Order by accdate
---
Set @SumOfTotalAmt = @SumOfTotalAmt + @Temp

SELECT A.* 
FROM
(
	SELECT 
		*,
		ROW_NUMBER() over (order by accdate, case when transdesc like '%opening balance%' then 1 else case when transdesc like '%Position%' then 2 else 3 end end, transdesc)  as RowNum	
	FROM @StatementTable
	where (accdate >= @fromdate OR transdesc = 'ACCUMULATED BALANCE')
) A
WHERE A.RowNum between @RowStart and @RowEnd



GO
GRANT  EXECUTE  ON [dbo].Age_Statement_Rpt_Ag  TO [bodbDownlineNet]
GO
GRANT  EXECUTE  ON [dbo].Age_Statement_Rpt_Ag  TO [bodbDownlineNetView]
GO




