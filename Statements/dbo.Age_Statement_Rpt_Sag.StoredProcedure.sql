/****** Object:  Stored Procedure dbo.Age_Statement_Rpt_Sag    Script Date: 5/23/2011 6:27:06 PM ******/
ALTER PROCEDURE [dbo].[Age_Statement_Rpt_Sag]
	@custid int,
	@fromdate 	DATETIME,
	@todate 	DATETIME,
	@BalanceUpDay	DATETIME,
	@PageSize int=0,
	@PageIndex int=0,
	@TotalRows int=0 output,
	@SumOfTotalAmt money=0 output
AS
/*
Created: 
Task : Statement Report of Super
DB: DBAGE/bodb02
Original: SP: Rpt_SuperAgentStatement

Revisions:
    --Henry@20100820: Provide Super Historical Statement Report
    --Don@20100908: Add @SumOfTotalAmt to sum of total amount through begin to current page index
	- 20101224@Johnson: Apply new arrange of bettype
	- 20130121@Dan: change linked server DB06 to DBRPT
Param's Explanation:

*/

SET NOCOUNT ON

DECLARE @RowStart int, @RowEnd int  
SELECT @PageIndex = @PageIndex - 1, @RowStart = @PageSize * @PageIndex + 1, @RowEnd = @RowStart + @PageSize - 1

DECLARE @StatementTable TABLE(
	matchdate datetime,
	transtype nvarchar(100),
	transdesc nvarchar(300),
	totalamt money
)

IF @todate >= @BalanceUpDay
BEGIN
	IF @FromDate > @BalanceUpDay SELECT @FromDate = @BalanceUpDay 
	
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
		and winlostdate between @fromdate and @todate
	group by typenamee,transdesc,transdate,transid
	union all
	select 
		winlostdate AS matchdate, 
		'POS' AS transtype, 
		'Position' AS transdesc, 
		sum(swinlost) AS totalamt 
	from bettrans with (nolock) 
	where 
		bettype <= 19999
		and srecommend=@custid 
		and winlostdate between @fromdate and @todate
	group by 
		winlostdate 
	having 
		sum(swinlost) <> 0
	union all 
	select  
		winlostdate AS matchdate,
		'COM' AS transtype, 
		'Commission' AS transdesc, 
		sum(scomm-acomm) AS totalamt  
	from bettrans  with (nolock)  
	where 
		bettype <= 19999
		and srecommend=@custid 
		and winlostdate between @fromdate and @todate
	group by 
		winlostdate 
	having 
		sum(scomm-acomm) <> 0
	
END	

IF @fromdate < @BalanceUpDay
BEGIN	
	DECLARE	@PreBalanceUpDay DATETIME
	IF @ToDate >= DATEADD(dd,-1,@BalanceUpDay)
		SELECT @ToDate = DATEADD(dd,-1,@BalanceUpDay) + ' 23:59:59'
		
	SELECT	
		TOP 1 @PreBalanceUpDay = accdate  
	FROM	
		DBRPT.bodb_Report.dbo.Statement with (NOLOCK)
	WHERE	
		custid = @custid 
		AND transdesc = 'OPENING BALANCE' 
		AND accdate <= @fromdate
	ORDER BY accdate DESC
	
	SELECT @FromDate = ISNULL(@PreBalanceUpDay,@FromDate)	
	
	insert into @StatementTable
	select 
		accdate,
		transtype,
		transdesc, 
		totalamt
	from DBRPT.bodb_Report.dbo.Statement with (nolock) 
	WHERE custid = @custid AND accdate between @fromdate and @todate
		
		
		
END

IF ((@PageSize <= 0) AND (@PageIndex <= 0))
BEGIN
	SELECT 
		*,
		ROW_NUMBER() over (order by matchdate, case when transdesc like '%opening balance%' then 1 else case when transdesc like '%Position%' then 2 else 3 end end, transdesc)  as RowNum	 
	FROM @StatementTable
	
	
	RETURN
END

IF @TotalRows = 0  
BEGIN
	SELECT @TotalRows = count(matchdate) FROM @StatementTable
END

Declare @Temp money
SELECT @SumOfTotalAmt = sum(A.totalamt)
FROM
(
	SELECT 
		*,
		ROW_NUMBER() over (order by matchdate, case when transdesc like '%opening balance%' then 1 else case when transdesc like '%Position%' then 2 else 3 end end, transdesc)  as RowNum	
	FROM @StatementTable
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
) A
WHERE A.RowNum between @RowStart and @RowEnd

GO
GRANT EXECUTE ON [dbo].[Age_Statement_Rpt_Sag] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_Statement_Rpt_Sag] TO [bodbDownlineNetView]
GO
GRANT VIEW DEFINITION ON [dbo].[Age_Statement_Rpt_Sag] TO [vnteam]