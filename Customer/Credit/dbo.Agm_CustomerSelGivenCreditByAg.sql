ALTER PROCEDURE [dbo].[Agm_CustomerSelGivenCreditByAg]
	@Recommend int ,
	@Username varchar(30)=null,  
	@Enabled bit = null,  
	@Closed bit=null,  
	@Suspended bit=null,  
	@PageSize int=50,
	@PageIndex int=0,
	@TotalPages int output
AS

/*

Created: 20110223@Kaden
Task: Get all member's given credit of agent custid=@Recommend. It's only use for IPhone
DB: DBAGE.bodb02

Original:
	-20140403@Dom: Add Betcredit field
*/

SET NOCOUNT ON

DECLARE @RowCount int, @RowStart int, @RowEnd int  
SELECT @PageIndex = @PageIndex - 1, @RowStart = @PageSize * @PageIndex + 1, @RowEnd = @RowStart + @PageSize - 1   
SET @Username = isnull(@Username, '')  

IF @Username = '' AND @Enabled IS NULL AND @Closed IS NULL AND @Suspended IS NULL  
BEGIN
	IF @TotalPages = 0  
	BEGIN  
		SELECT @TotalPages = count(1),@TotalPages=@TotalPages/@PageSize + case when @TotalPages%@PageSize > 0 then 1 else 0 end   
		FROM
			custinfo WITH(NOLOCK) 
		WHERE
			recommend=@Recommend and roleid=1
	END

	SELECT 
		c.custid, 
		c.username, 
		c.givencredit,
		c.enabled,
		c.closed, 
		c.givencredit+ISNULL(t.balance,0)-(ISNULL(t.outstanding,0)+ISNULL(translog.outstanding,0)) betcredit,
		isnull(c.reject,0) as suspended 
	FROM
	(
		SELECT custid, username, reject, closed, Enabled, credit as givencredit , ROW_NUMBER() over(order by enabled desc, closed, isnull(reject,0), username) as RowNum
		FROM custinfo with(nolock) 
		WHERE recommend=@Recommend and roleid=1
	) as c
	LEFT JOIN 
	(
		SELECT
			custid as custid,
			IsNull(sum (case when ruben=0 then ABS(actual_stake) else 0 end),0) AS outstanding,
			IsNull(sum(case when ruben=1 then winlost - actual_stake + playercomm else 0 end),0) AS balance
		FROM bettrans with (NOLOCK)
		WHERE recommend = @Recommend
		GROUP BY custid
	) as t ON t.custid = c.custid
	LEFT JOIN 
	(
		SELECT
			custid as custid,
			IsNull(sum(ABS(actual_stake)),0) AS outstanding
		FROM translog with (NOLOCK)
		WHERE recommend = @Recommend
		and statusID = 0
		GROUP BY custid
	) translog ON translog.custid = c.custid
	WHERE RowNum between @RowStart and @RowEnd
END

ELSE IF @Username = ''
BEGIN
	IF @TotalPages = 0  
	BEGIN  
		SELECT @TotalPages = count(1),@TotalPages=@TotalPages/@PageSize + case when @TotalPages%@PageSize > 0 then 1 else 0 end   
		FROM
			Custinfo as ci WITH(NOLOCK) 
		WHERE
			recommend=@Recommend and roleid=1
			AND enabled = case when coalesce(@Closed,@Suspended) is not null then 1 else coalesce(@enabled, enabled) end
			AND isnull(ci.closed,0) = case when @suspended = 1 then 0 else coalesce(@closed, isnull(ci.closed, 0)) end			
			AND isnull(ci.reject,0) = case when @Closed = 0 then 0 else coalesce(@suspended, isnull(ci.reject, 0))end			
	END

	SELECT 
		c.custid, 
		c.username, 
		c.givencredit,
		c.enabled,
		c.closed, 
		c.givencredit+ISNULL(t.balance,0)-(ISNULL(t.outstanding,0)+ISNULL(translog.outstanding,0)) betcredit,
		isnull(c.reject,0) as suspended 
	FROM
	(
		SELECT custid, username, reject, closed, Enabled, credit as givencredit , ROW_NUMBER() over(order by enabled desc, closed, isnull(reject,0), username) as RowNum
		FROM Custinfo as ci with(nolock) 
		WHERE recommend=@Recommend and roleid=1
			AND enabled = case when coalesce(@Closed,@Suspended) is not null then 1 else coalesce(@enabled, enabled) end
			AND isnull(ci.closed,0) = case when @suspended = 1 then 0 else coalesce(@closed, isnull(ci.closed, 0)) end			
			AND isnull(ci.reject,0) = case when @Closed = 0 then 0 else coalesce(@suspended, isnull(ci.reject, 0))end			
	) as c
	LEFT JOIN 
	(
		SELECT
			custid as custid,
			IsNull(sum (case when ruben=0 then ABS(actual_stake) else 0 end),0) AS outstanding,
			IsNull(sum(case when ruben=1 then winlost - actual_stake + playercomm else 0 end),0) AS balance
		FROM bettrans with (NOLOCK)
		WHERE recommend = @Recommend
		GROUP BY custid
	) as t ON t.custid = c.custid
	LEFT JOIN 
	(
		SELECT
			custid as custid,
			IsNull(sum(ABS(actual_stake)),0) AS outstanding
		FROM translog with (NOLOCK)
		WHERE recommend = @Recommend
		and statusID = 0
		GROUP BY custid
	) translog ON translog.custid = c.custid
	WHERE RowNum between @RowStart and @RowEnd
END
ELSE
BEGIN
	IF @TotalPages = 0  
	BEGIN  
		SELECT @TotalPages = count(1),@TotalPages=@TotalPages/@PageSize + case when @TotalPages%@PageSize > 0 then 1 else 0 end   
		FROM
			Custinfo as ci WITH(NOLOCK) 
		WHERE
			recommend=@Recommend and roleid=1
			AND ci.username like '%' + @Username + '%'  
			AND enabled = case when coalesce(@Closed,@Suspended) is not null then 1 else coalesce(@enabled, enabled) end
			AND isnull(ci.closed,0) = case when @suspended = 1 then 0 else coalesce(@closed, isnull(ci.closed, 0)) end
			AND isnull(ci.reject,0) = case when @Closed = 0 then 0 else coalesce(@suspended, isnull(ci.reject, 0))end			
	END

	SELECT 
		c.custid, 
		c.username, 
		c.givencredit,
		c.enabled,
		c.closed, 
		c.givencredit+ISNULL(t.balance,0)-(ISNULL(t.outstanding,0)+ISNULL(translog.outstanding,0)) betcredit,
		isnull(c.reject,0) as suspended 
	FROM
	(
		SELECT custid, username, reject, closed, Enabled, credit as givencredit , ROW_NUMBER() over(order by enabled desc, closed, isnull(reject,0), username) as RowNum
		FROM Custinfo as ci with(nolock) 
		WHERE recommend=@Recommend and roleid=1
			AND ci.username like '%' + @Username + '%'  
			AND enabled = case when coalesce(@Closed,@Suspended) is not null then 1 else coalesce(@enabled, enabled) end
			AND isnull(ci.closed,0) = case when @suspended = 1 then 0 else coalesce(@closed, isnull(ci.closed, 0)) end
			AND isnull(ci.reject,0) = case when @Closed = 0 then 0 else coalesce(@suspended, isnull(ci.reject, 0))end			
	) as c
	LEFT JOIN 
	(
		SELECT
			custid as custid,
			IsNull(sum (case when ruben=0 then ABS(actual_stake) else 0 end),0) AS outstanding,
			IsNull(sum(case when ruben=1 then winlost - actual_stake + playercomm else 0 end),0) AS balance
		FROM bettrans with (NOLOCK)
		WHERE recommend = @Recommend AND recommend <> custid
		GROUP BY custid
	) as t ON t.custid = c.custid
	LEFT JOIN 
	(
		SELECT
			custid as custid,
			IsNull(sum(ABS(actual_stake)),0) AS outstanding
		FROM translog with (NOLOCK)
		WHERE recommend = @Recommend
		and statusID = 0
		GROUP BY custid
	) translog ON translog.custid = c.custid
	WHERE RowNum between @RowStart and @RowEnd
END


GO
GRANT EXECUTE ON [dbo].[Agm_CustomerSelGivenCreditByAg] TO [bodbDownlineNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Agm_CustomerSelGivenCreditByAg] TO [vnteam]


GO
/*
declare @p8 int
set @p8=12
exec Agm_CustomerSelGivenCreditByAg @Recommend=3230184,@Username='',@Enabled=default,@Closed=default,@Suspended=default,@PageSize=20,@PageIndex=1,@TotalPages=@p8 output
select @p8
*/
/*
SELECT
	custid as custid,
	bettype,
	IsNull(sum (case when ruben=0 then ABS(actual_stake) else 0 end),0) AS outstanding,
	IsNull(sum(case when ruben=1 then winlost - actual_stake + playercomm else 0 end),0) AS balance
FROM bettrans with (NOLOCK)
WHERE recommend = 3230184
GROUP BY custid,bettype
select * from translog where custid = 7889865
select custid from Customer(nolock)
where username in('SUPERTEST1201000','SuperTest1201001','SuperTest1201002','SuperTest1201003')


SELECT
			custid as custid,
			IsNull(sum(ABS(actual_stake)),0) AS outstanding
		FROM translog with (NOLOCK)
		WHERE recommend = 3230184
		and statusID = 0
		GROUP BY custid



		select recommend,winlostdate,ruben,statusid,actual_stake,* from bettrans where transid=5659874692*/
