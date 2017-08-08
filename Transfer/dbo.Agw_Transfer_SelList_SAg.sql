ALTER PROCEDURE [dbo].[Agw_Transfer_SelList_SAg]	
	@SAgID int,
	@isShowAll bit = 0,
	@IsAllowTotalBalance bit = 0,
	@Closed bit = NULL,
	@suspended bit = NULL,
	@PageSize int=50,
	@PageIndex int=0,
	@TotalPages int=0 output
AS
/*
Created: 20080905@[Tuan]
Task:
DB: DB05.bodb02
Original: Age_Transfer_SelList_SAg

Revisions:
	- 20110513@Johnson: Apply new arrange bettype
*/

SET NOCOUNT ON

DECLARE @RowCount int, @RowStart int, @RowEnd int  
SELECT @PageIndex = @PageIndex - 1, @RowStart = @PageSize * @PageIndex + 1, @RowEnd = @RowStart + @PageSize - 1   

IF @TotalPages = 0  
BEGIN  
 SELECT @TotalPages = count(c.custid),@TotalPages=@TotalPages/@PageSize + case when @TotalPages%@PageSize > 0 then 1 else 0 end   
 FROM
 (
	select 	c.custid,
		IsNull(balance.magentBalance + balance.magentCashBalance,0) magentBalance, 
		IsNull(balance.magentBalance + balance.magentCashBalance,0) - IsNull(today_balance.magentBalance + today_balance.magentCashBalance,0) yesterday_magentBalance
	from
	(
		SELECT c.custid, c.username, c.firstname, c.lastname,ci.closed,ci.reject
		FROM customer as c with (nolock) INNER JOIN custinfo as ci with (NOLOCK) on c.custid = ci.custid 
		WHERE c.srecommend = @SAgID AND c.roleid = 3 
				AND isnull(ci.closed,0) = case when @suspended = 1 then 0 else coalesce(@closed, isnull(ci.closed, 0)) end
				AND isnull(ci.reject,0) = case when @Closed = 0 then 0 else coalesce(@suspended, isnull(ci.reject, 0))end
	) AS c
	LEFT OUTER JOIN
	(
		select 	
			mrecommend, 
			isnull(sum(case when custid=mrecommend then winlost-actual_stake else mwinlost+acomm-comm end), 0) AS magentCashBalance, 
			isnull(sum(case when custid <> recommend and custid<>mrecommend and custid <> srecommend and ruben=1 then winlost-actual_stake+playercomm else 0 end), 0)
				+ IsNull(sum(case when custid=recommend then winlost-actual_stake else awinlost+comm-playercomm end),0) AS magentBalance	
		from bettrans with(nolock)
		where srecommend = @SAgID  
		group by mrecommend
	) balance ON c.custid = balance.mrecommend
	LEFT OUTER JOIN
	(
		select 	
			mrecommend, 
			isnull(sum(mwinlost+acomm-comm), 0) AS magentCashBalance, 
			isnull(sum(winlost-actual_stake+ awinlost+comm), 0) AS magentBalance
		from bettrans with(nolock)
		where 
			srecommend = @SAgID and ruben =1 and bettype <= 19000
			and bettrans.winlostdate >= convert(varchar(10), CURRENT_TIMESTAMP, 120)
		group by mrecommend
	) today_balance ON c.custid = today_balance.mrecommend
	--Where 0 <> case when @isShowAll = 1 then 1 else IsNull(balance.magentBalance + balance.magentCashBalance,0) - IsNull(today_balance.magentBalance + today_balance.magentCashBalance,0) end
	Where
	    Case 
	        When @isShowAll = 1 Then 1
	    Else
	        Case
	            When @IsAllowTotalBalance = 0 Then IsNull(balance.magentBalance + balance.magentCashBalance,0) - IsNull(today_balance.magentBalance + today_balance.magentCashBalance,0)
	            When @IsAllowTotalBalance = 1 Then IsNull(balance.magentBalance + balance.magentCashBalance,0)
	        End
	    End <> 0
 ) as c
 
 
END



SELECT t.username, t.custid, t.magentBalance, t.yesterday_magentBalance
FROM
(
	select 	c.username, 
		c.custid,
		IsNull(balance.magentBalance + balance.magentCashBalance,0) magentBalance, 
		IsNull(balance.magentBalance + balance.magentCashBalance,0) - IsNull(today_balance.magentBalance + today_balance.magentCashBalance,0) yesterday_magentBalance,
		ROW_NUMBER() over (order by username) as RowNum 
	from
	(
		SELECT c.custid, c.username, c.firstname, c.lastname,ci.closed,ci.reject
		FROM customer as c with (nolock) INNER JOIN custinfo as ci with (NOLOCK) on c.custid = ci.custid 
		WHERE c.srecommend = @SAgID AND c.roleid = 3 
				AND isnull(ci.closed,0) = case when @suspended = 1 then 0 else coalesce(@closed, isnull(ci.closed, 0)) end
				AND isnull(ci.reject,0) = case when @Closed = 0 then 0 else coalesce(@suspended, isnull(ci.reject, 0))end
	) AS c
	LEFT OUTER JOIN
	(
		select 	
			mrecommend, 
			isnull(sum(case when custid=mrecommend then winlost-actual_stake else mwinlost+acomm-comm end), 0) AS magentCashBalance, 
			isnull(sum(case when custid <> recommend and custid<>mrecommend and custid <> srecommend and ruben=1 then winlost-actual_stake+playercomm else 0 end), 0)
				+ IsNull(sum(case when custid=recommend then winlost-actual_stake else awinlost+comm-playercomm end),0) AS magentBalance		
		from bettrans with(nolock)
		where srecommend = @SAgID  
		group by mrecommend
	) balance ON c.custid = balance.mrecommend
	LEFT OUTER JOIN
	(
		select 	
			mrecommend, 
			isnull(sum(mwinlost+acomm-comm), 0) AS magentCashBalance, 
			isnull(sum(winlost-actual_stake+ awinlost+comm), 0) AS magentBalance
		from bettrans with(nolock)
		where 
			srecommend = @SAgID and ruben =1 and bettype <= 19000
			and bettrans.winlostdate >= convert(varchar(10), CURRENT_TIMESTAMP, 120)
		group by mrecommend
	) today_balance ON c.custid = today_balance.mrecommend
	--Where 0 <> case when @isShowAll = 1 then 1 else IsNull(balance.magentBalance + balance.magentCashBalance,0) - IsNull(today_balance.magentBalance + today_balance.magentCashBalance,0) end
	Where
	    Case 
	        When @isShowAll = 1 Then 1
	    Else
	        Case
	            When @IsAllowTotalBalance = 0 Then IsNull(balance.magentBalance + balance.magentCashBalance,0) - IsNull(today_balance.magentBalance + today_balance.magentCashBalance,0)
	            When @IsAllowTotalBalance = 1 Then IsNull(balance.magentBalance + balance.magentCashBalance,0)
	        End
	    End <> 0
)

as t
WHERE RowNum between  @RowStart and @RowEnd



GO
GRANT EXECUTE ON [dbo].[Agw_Transfer_SelList_SAg] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Agw_Transfer_SelList_SAg] TO [bodbDownlineNetView]
GO
GRANT VIEW DEFINITION ON [dbo].[Agw_Transfer_SelList_SAg] TO [vnteam]