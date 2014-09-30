USE [bodb02]
GO
/****** Object:  StoredProcedure [dbo].[Age_Statement_Rpt_MAg]    Script Date: 09/30/2014 13:58:40 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[Age_Statement_Rpt_MAg]
@custid int,
@fromdate 	DATETIME,
@todate 	DATETIME,
@BalanceUpDay	DATETIME ,
@PageSize int=0,
@PageIndex int=0,
@TotalRows int=0 output,
@SumOfTotalAmt money=0 output
 AS
/*
Created: 
Task : Statement Report of Master
DB: DBAGE/bodb02
Original: SP: Rpt_MaStatement

Revisions:
    - Henry@20100820: Provide Master Historical Statement Report
    - Don@20100908: Add @SumOfTotalAmt to sum of total amount through begin to current page index
	- 20101224@Johnson: Apply new arrange of bettype
	- 20130121@Dan: change linked server DB06 to DBRPT
	- 20130715@Johnson: fix report in case of @fromdate > BUDate (should get from @fromdate not BUDate)	
	- 20140930@Daniel: fix bug wrong Accu row in case cannot find any BU row before @fromDate
Param's Explanation:

*/

SET NOCOUNT ON

DECLARE @RowStart int, @RowEnd int  
SELECT	@PageIndex = @PageIndex - 1, @RowStart = @PageSize * @PageIndex + 1, @RowEnd = @RowStart + @PageSize - 1
		,@TotalRows =0
		,@SumOfTotalAmt = 0
		
DECLARE @StatementTable TABLE(
	matchdate datetime,
	transtype nvarchar(100),
	transdesc nvarchar(300),
	totalamt money
)

DECLARE @f_date DATETIME,
		@t_date DATETIME

SELECT @f_date = @fromdate,
		@t_date = @todate	
		
IF @todate >= @BalanceUpDay
BEGIN
	IF @FromDate > @BalanceUpDay 
		SELECT @f_Date = @BalanceUpDay 

	INSERT INTO @StatementTable
	select 
		transdate AS matchdate, 
		typenamee AS transtype, 
		transdesc, 
		sum(winlost-actual_stake) AS totalamt  
	from 
		bettrans  with (nolock)  
		INNER JOIN bettype  with (nolock)  ON bettype.typeid=bettrans.bettype 
	where 
		bettype >= 20000 
		and custid=@custid 
		and winlostdate between @f_date and @t_date
	group by
		typenamee,transdesc,transdate,transid
	
	union all
	select 
		winlostdate AS matchdate, 
		'POS' AS transtype, 
		'Position' AS transdesc, 
		sum(mwinlost) AS totalamt 
	from 
		bettrans with (nolock) 
	where 
		bettype <= 19999
		and mrecommend=@custid 
		and winlostdate between @f_date and @t_date
	group by 
		winlostdate 
	having 
		sum(mwinlost) <> 0
	
	union all 
	select  
		winlostdate AS matchdate,
		'COM' AS transtype, 
		'Commission' AS transdesc, 
		sum(acomm-comm) AS totalamt  
	from bettrans  with (nolock)  
	where 
		bettype <= 19999
		and mrecommend=@custid 
		and winlostdate between @f_date and @t_date		
	group by 
		winlostdate 
	having 
		sum(acomm-comm) <> 0	
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
	
	--if cannot find any old BU row, get BUDate from last BUDate before @fromdate
	if (@PreBalanceUpDay is NULL) 
		select @PreBalanceUpDay = accdate
		from DBRPT.bodb_Report.dbo.Statement with (NOLOCK)
		where custid = @custid AND accdate BETWEEN DATEADD(dd, -7, @FromDate) and @FromDate AND DATEPART(WEEKDAY, accdate) = 7	
	
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
	where matchdate < @fromdate
	
	IF EXISTS(select 1 from @StatementTable where matchdate >= @fromdate AND @AccBal <>0) 
		INSERT INTO @StatementTable(matchdate,transtype,transdesc,totalamt)
		SELECT '', 'BAL', 'ACCUMULATED BALANCE', @AccBal
END

IF ((@PageSize <= 0) AND (@PageIndex <= 0))
BEGIN
	SELECT 
		*,
		ROW_NUMBER() over (order by matchdate, case when transdesc like '%opening balance%' then 1 else case when transdesc like '%Position%' then 2 else 3 end end, transdesc)  as RowNum	 
	FROM @StatementTable
	where (matchdate >= @fromdate OR transdesc = 'ACCUMULATED BALANCE')
	
	RETURN
END

IF @TotalRows = 0  
BEGIN
	SELECT @TotalRows = count(matchdate) FROM @StatementTable
	--where (matchdate >= @fromdate OR transdesc = 'ACCUMULATED BALANCE')
END

Declare @Temp money
SELECT @SumOfTotalAmt = sum(A.totalamt)
FROM
(
	SELECT 
		*,
		ROW_NUMBER() over (order by matchdate, case when transdesc like '%opening balance%' then 1 else case when transdesc like '%Position%' then 2 else 3 end end, transdesc)  as RowNum	
	FROM @StatementTable
	where (matchdate >= @fromdate OR transdesc = 'ACCUMULATED BALANCE')
) A
WHERE A.RowNum < @RowStart and A.transdesc not like '%opening balance%'
---
Select TOP 1 @Temp = totalamt
From @StatementTable
Where transdesc like '%opening balance%'
Order by matchdate
---
Set @SumOfTotalAmt = @SumOfTotalAmt + @Temp

SELECT A.* 
FROM
(
	SELECT 
		*,
		ROW_NUMBER() over (order by matchdate, case when transdesc like '%opening balance%' then 1 else case when transdesc like '%Position%' then 2 else 3 end end, transdesc)  as RowNum	
	FROM @StatementTable
	where (matchdate >= @fromdate OR transdesc = 'ACCUMULATED BALANCE')
) A
WHERE A.RowNum between @RowStart and @RowEnd




GO
GRANT EXECUTE ON [dbo].[Age_Statement_Rpt_MAg] TO [bodbDownlineNet] AS [dbo]
GO
GRANT EXECUTE ON [dbo].[Age_Statement_Rpt_MAg] TO [bodbDownlineNetView] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[Age_Statement_Rpt_MAg] TO [vnteam] AS [dbo]