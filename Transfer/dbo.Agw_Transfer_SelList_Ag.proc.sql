ALTER PROCEDURE [dbo].[Agw_Transfer_SelList_Ag]
	@custid INT,
	@isShowAll bit = 0,
	@IsAllowTotalBalance bit = 0,
	@closed bit = NULL,
	@suspended bit = NULL,
	@PageSize int=50,
	@PageIndex int=0,
	@TotalPages int=0 output	
AS
SET NOCOUNT ON

/*
Task : Select transfer list of Agent
DB: DB05/DB052.bodb02
Original: 

Revisions:
		- 20090212@Phuc: paging
		- 20090819@Lee: Add 2 columns reject, closed (reset casino transfer limit)
		- 20110513@Johnson: Apply new arrange bettype
*/

DECLARE @RowCount int, @RowStart int, @RowEnd int  
SELECT @PageIndex = @PageIndex - 1, @RowStart = @PageSize * @PageIndex + 1, @RowEnd = @RowStart + @PageSize - 1   


IF @TotalPages = 0  
BEGIN  
 SELECT @TotalPages = count(t.custid),@TotalPages=@TotalPages/@PageSize + case when @TotalPages%@PageSize > 0 then 1 else 0 end   
 FROM
 (
	SELECT 
		c.custid
	FROM 
	(	
		SELECT 
			customer.custid	
		FROM 
			customer WITH (NOLOCK)
			INNER JOIN CustInfo as ci with (NOLOCK) on Customer.CustID = ci.custid
		WHERE 
			customer.recommend = @custid
			AND customer.roleid = 1
			AND isnull(ci.closed,0) = case when @suspended = 1 then 0 else coalesce(@closed, isnull(ci.closed, 0)) end
			AND isnull(ci.reject,0) = case when @Closed = 0 then 0 else coalesce(@suspended, isnull(ci.reject, 0))end			
	) AS c 
	LEFT JOIN 
	(
		SELECT 
			custid,
			isnull(SUM(CASE WHEN ruben = 1 THEN winlost-actual_stake+playercomm END),0) balance 
		FROM bettrans WITH (NOLOCK)
		where recommend = @custid
		group by custid 

	) as b on c.custid =b.custid 
	LEFT JOIN 
	(	SELECT 
			custid,
			isnull(SUM(winlost-actual_stake+playercomm ),0) balance
		FROM bettrans with (nolock)
		where recommend = @custid AND ruben = 1 AND bettype <= 19000 
				AND winlostdate >= convert(varchar(10), current_timestamp, 120) 
		group by custid 
	)today_balance on c.custid = today_balance.custid 
	--Where 0 <> case when @isShowAll = 1 then 1 else isnull(b.balance, 0) - isnull(today_balance.balance, 0) end
	Where
	    Case 
	        When @isShowAll = 1 Then 1
	    Else
	        Case
	            When @IsAllowTotalBalance = 0 Then Isnull(b.balance, 0) - Isnull(today_balance.balance, 0)
	            When @IsAllowTotalBalance = 1 Then Isnull(b.balance, 0)
	        End
	    End <> 0
 ) as t
 
 
END



SELECT t.username, t.custid, t.yesterday_balance, t.balance, closed, reject
FROM
(


SELECT 
	c.username as username,
	c.custid as custid,
	isnull(b.balance,0) - isnull(today_balance.balance,0) yesterday_balance,
	isnull(b.balance,0) balance,
	closed, reject,
	ROW_NUMBER() over (order by username) as RowNum 
FROM 
(	
	SELECT 
		customer.custid, 
		customer.username,
		ci.closed,
		ci.reject
	FROM 
		customer WITH (NOLOCK)
		INNER JOIN CustInfo as ci with (NOLOCK) on Customer.CustID = ci.custid
	WHERE 
		customer.recommend = @custid
		AND customer.roleid = 1
		--ci.closed= @closed AND
		AND isnull(ci.closed,0) = case when @suspended = 1 then 0 else coalesce(@closed, isnull(ci.closed, 0)) end
		AND isnull(ci.reject,0) = case when @Closed = 0 then 0 else coalesce(@suspended, isnull(ci.reject, 0))end			
) AS c 
LEFT JOIN 
(
	SELECT 
		custid,
		isnull(SUM(CASE WHEN ruben = 1 THEN winlost-actual_stake+playercomm END),0) balance     	
	FROM bettrans WITH (NOLOCK)
	where recommend = @custid
	group by custid 

) as b on c.custid =b.custid 
LEFT JOIN 
(	SELECT 
		custid, 
		isnull(SUM(winlost-actual_stake+playercomm ),0) balance
	FROM bettrans with (nolock)
	where recommend = @custid AND ruben = 1 AND bettype <= 19000 
			AND winlostdate >= convert(varchar(10), current_timestamp, 120) 
	group by custid 
)today_balance on c.custid = today_balance.custid 
--Where 0 <> case when @isShowAll = 1 then 1 else isnull(b.balance, 0) - isnull(today_balance.balance, 0) end
Where
    Case 
        When @isShowAll = 1 Then 1
    Else
        Case
            When @IsAllowTotalBalance = 0 Then Isnull(b.balance, 0) - Isnull(today_balance.balance, 0)
            When @IsAllowTotalBalance = 1 Then Isnull(b.balance, 0)
        End
    End <> 0

) 


as t
WHERE RowNum between  @RowStart and @RowEnd




GO

GRANT EXECUTE ON [dbo].[Agw_Transfer_SelList_Ag] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Agw_Transfer_SelList_Ag] TO [bodbDownlineNetView]
GO