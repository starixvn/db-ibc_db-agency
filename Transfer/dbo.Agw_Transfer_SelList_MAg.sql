ALTER PROCEDURE [dbo].[Agw_Transfer_SelList_MAg]
	@masterid as int,
	@isShowAll bit = 0,
	@IsAllowTotalBalance bit = 0,
	@Closed bit = null,
	@suspended bit = NULL,
	@PageSize int=50,
	@PageIndex int=0,
	@TotalPages int=0 output	
AS
/*
Created: 20080905@[Tuan]
Task:
DB: DB05.bodb02
Original: Age_Transfer_SelList_MAg

Revisions:
	- 20110513@Johnson: Apply new arrange bettype
*/

SET NOCOUNT ON

DECLARE @RowCount int, @RowStart int, @RowEnd int  
SELECT @PageIndex = @PageIndex - 1, @RowStart = @PageSize * @PageIndex + 1, @RowEnd = @RowStart + @PageSize - 1   


IF @TotalPages = 0  
BEGIN  
 SELECT @TotalPages = count(t.custid),@TotalPages=@TotalPages/@PageSize + case when @TotalPages%@PageSize > 0 then 1 else 0 end   
 FROM

(
	select 	
		c.custid,
		IsNull(balance.agentBalance + balance.agentCashBalance,0) agentBalance, 	 
		IsNull(balance.agentBalance + balance.agentCashBalance,0) - IsNull(today_balance.agentBalance + today_balance.agentCashBalance, 0) yesterday_agentBalance
	from
		(
			SELECT c.custid, c.username, c.firstname, c.lastname ,ci.closed,ci.reject
			FROM customer AS c with (nolock) INNER JOIN custinfo as ci with (NOLOCK) on c.custid = ci.custid 
			WHERE c.mrecommend = @masterid 
				AND c.roleid = 2			
				AND isnull(ci.closed,0) = case when @suspended = 1 then 0 else coalesce(@closed, isnull(ci.closed, 0)) end
				AND isnull(ci.reject,0) = case when @Closed = 0 then 0 else coalesce(@suspended, isnull(ci.reject, 0))end
		) 
		AS c		
		LEFT OUTER JOIN
		(
			select 	recommend, 
				isnull(sum(case when custid=recommend then winlost-actual_stake else awinlost+comm-playercomm end), 0) AS agentCashBalance, 
				isnull(sum(case when custid<>recommend and ruben=1 then winlost-actual_stake+playercomm else 0 end), 0) AS agentBalance
			from bettrans with(nolock)
			where mrecommend = @masterid  
			group by recommend
		) balance ON c.custid = balance.recommend
		LEFT OUTER JOIN
		(
			select 	recommend, 
				isnull(sum(awinlost+comm-playercomm), 0) AS agentCashBalance, 
				isnull(sum(winlost-actual_stake+playercomm), 0) AS agentBalance
			from bettrans with(nolock)
			where mrecommend = @masterid and ruben = 1 and bettype <= 19000
			and bettrans.winlostdate >= convert(varchar(10), current_timestamp, 120)  
			group by recommend
		) today_balance ON c.custid = today_balance.recommend
	--Where 0 <> case when @isShowAll = 1 then 1 else IsNull(balance.agentBalance + balance.agentCashBalance,0) - IsNull(today_balance.agentBalance + today_balance.agentCashBalance, 0) end
	Where
	    Case 
	        When @isShowAll = 1 Then 1
	    Else
	        Case
	            When @IsAllowTotalBalance = 0 Then IsNull(balance.agentBalance + balance.agentCashBalance,0) - IsNull(today_balance.agentBalance + today_balance.agentCashBalance, 0)
	            When @IsAllowTotalBalance = 1 Then IsNull(balance.agentBalance + balance.agentCashBalance,0)
	        End
	    End <> 0
	    
)
as t
 
 
END


SELECT t.username, t.custid, t.agentBalance, t.yesterday_agentBalance
FROM
(

select 	
	c.username, 
	c.custid,	
	IsNull(balance.agentBalance + balance.agentCashBalance,0) agentBalance, 	 
	IsNull(balance.agentBalance + balance.agentCashBalance,0) - IsNull(today_balance.agentBalance + today_balance.agentCashBalance, 0) yesterday_agentBalance,
	ROW_NUMBER() over (order by username) as RowNum 
from
	(
		SELECT c.custid, c.username, c.firstname, c.lastname, ci.closed, ci.reject
		FROM customer AS c with (nolock) INNER JOIN custinfo as ci with (NOLOCK) on c.custid = ci.custid 
		WHERE c.mrecommend = @masterid 
			AND c.roleid = 2			
			AND isnull(ci.closed,0) = case when @suspended = 1 then 0 else coalesce(@closed, isnull(ci.closed, 0)) end
			AND isnull(ci.reject,0) = case when @Closed = 0 then 0 else coalesce(@suspended, isnull(ci.reject, 0))end
	) 
	AS c		
	LEFT OUTER JOIN
	(
		select 	recommend, 
			isnull(sum(case when custid=recommend then winlost-actual_stake else awinlost+comm-playercomm end), 0) AS agentCashBalance, 
			isnull(sum(case when custid<>recommend and ruben=1 then winlost-actual_stake+playercomm else 0 end), 0) AS agentBalance
		from bettrans with(nolock)
		where mrecommend = @masterid  
		group by recommend
	) balance ON c.custid = balance.recommend
	LEFT OUTER JOIN
	(
		select 	recommend, 
			isnull(sum(awinlost+comm-playercomm), 0) AS agentCashBalance, 
			isnull(sum(winlost-actual_stake+playercomm), 0) AS agentBalance
		from bettrans with(nolock)
		where mrecommend = @masterid and ruben = 1 and bettype <= 19000
		and bettrans.winlostdate >= convert(varchar(10), current_timestamp, 120)  
		group by recommend
	) today_balance ON c.custid = today_balance.recommend
--Where 0 <> case when @isShowAll = 1 then 1 else IsNull(balance.agentBalance + balance.agentCashBalance,0) - IsNull(today_balance.agentBalance + today_balance.agentCashBalance, 0) end
Where
    Case 
        When @isShowAll = 1 Then 1
    Else
        Case
            When @IsAllowTotalBalance = 0 Then IsNull(balance.agentBalance + balance.agentCashBalance,0) - IsNull(today_balance.agentBalance + today_balance.agentCashBalance, 0)
            When @IsAllowTotalBalance = 1 Then IsNull(balance.agentBalance + balance.agentCashBalance,0)
        End
    End <> 0

)
as t
WHERE RowNum between  @RowStart and @RowEnd



GO

GRANT EXECUTE ON [dbo].[Agw_Transfer_SelList_MAg] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Agw_Transfer_SelList_MAg] TO [bodbDownlineNetView]
GO