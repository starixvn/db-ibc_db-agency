ALTER PROCEDURE [dbo].[Agm_CustomerSelGivenCreditByMAg]
	@MRecommend int ,
	@Username nvarchar(30)= null,
	@Enabled bit = null,
	@Closed bit=null,
	@Suspended bit=null,
	@PageSize int=50,
	@PageIndex int=0,
	@TotalPages int output
AS

/*
Created: 20110223@Kaden
Task: Get all agent's given credit of master custid=@MRecommend. It's only use for IPhone
DB: DBAGE.bodb02
Original:
Revisions:
	- 20110321@Kaden.Trinh: Rename @Keyword to @Username
	- 20110321@Kaden.Trinh: add parameter status(Enabled, Closed, Suspended), so that we can search for it.  
	- 20140403@Dom: Add Betcredit field
	- 20150707@Jim: exclude Metric Gaming running ticket from bettrans (Feature #38789)
	- 20160201@Percy: expand new RNG Casino [Redmine: #51912]
	- 20160223@Percy: Change formula when calculating bet credit [Redmine: #52653]
*/

SET NOCOUNT ON

DECLARE @today     DATE,
		@yesterday DATE
SELECT @today     = CONVERT(DATE, GETDATE())
SELECT @yesterday = DATEADD(DD, -1, @today)

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
			mrecommend=@MRecommend and roleid=2
	END


	SELECT 
		c.custid, 
		c.username, 
		c.givencredit,
		c.enabled,
		c.closed, 
		c.givencredit+ISNULL(c.usedCredit, 0) betcredit,
		isnull(c.reject,0) as suspended 
	FROM
	(
		SELECT c.custid, c.username, c.reject, c.closed, c.Enabled, c.credit as givencredit , ROW_NUMBER() over(order by c.enabled desc, c.closed, isnull(c.reject,0), c.username) as RowNum,
			(SELECT SUM(credit) FROM custInfo WITH(NOLOCK) WHERE roleid = 1 AND recommend = c.custid) AS usedCredit
		FROM Custinfo as c with (NOLOCK) 
		where c.mrecommend=@MRecommend and c.roleid=2
	) as c
			UNION ALL
			SELECT
				recommend as custid,
				IsNull(sum (case when statusID IN (0, 1) then ABS(actual_stake) * apositiontaking else 0 end),0) AS outstanding, 
				IsNull(sum(case when CONVERT(DATE, winlostdate) >= @yesterday then case when custid=recommend then winlost-actual_stake else awinlost+comm-playercomm end else 0 end),0) AS balance
			FROM bettransRNG with (NOLOCK)
			WHERE mrecommend = @MRecommend
				AND gameID BETWEEN 2101 AND 2399
			GROUP BY recommend
	WHERE RowNum between @RowStart and @RowEnd
END

ELSE IF @Username = ''
BEGIN
	IF @TotalPages = 0  
	BEGIN 
		SELECT @TotalPages = count(1),@TotalPages=@TotalPages/@PageSize + case when @TotalPages%@PageSize > 0 then 1 else 0 end   
		FROM
			Custinfo as ci with (NOLOCK)			
		WHERE ci.mrecommend = @MRecommend and ci.roleid=2 
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
		c.givencredit+ISNULL(c.usedCredit, 0) betcredit,
		isnull(c.reject,0) as suspended 
	FROM
	(
		SELECT c.custid, c.username, c.reject, c.closed, c.Enabled, c.credit as givencredit , ROW_NUMBER() over(order by c.enabled desc, c.closed, isnull(c.reject,0), c.username) as RowNum,
			(SELECT SUM(credit) FROM custInfo WITH(NOLOCK) WHERE roleid = 1 AND recommend = c.custid) AS usedCredit
		FROM Custinfo as c with (NOLOCK)	
		WHERE c.mrecommend = @MRecommend and c.roleid=2
			AND c.enabled = case when coalesce(@Closed,@Suspended) is not null then 1 else coalesce(@enabled, c.enabled) end
			AND isnull(c.closed,0) = case when @suspended = 1 then 0 else coalesce(@closed, isnull(c.closed, 0)) end
			AND isnull(c.reject,0) = case when @Closed = 0 then 0 else coalesce(@suspended, isnull(c.reject, 0))end				
	) as c
	WHERE RowNum between @RowStart and @RowEnd
END
ELSE
BEGIN
	IF @TotalPages = 0  
	BEGIN 
		SELECT @TotalPages = count(1),@TotalPages=@TotalPages/@PageSize + case when @TotalPages%@PageSize > 0 then 1 else 0 end   
		FROM
			Custinfo as ci with (NOLOCK)			
		WHERE ci.mrecommend = @MRecommend and ci.roleid=2 
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
		c.givencredit+ISNULL(c.usedCredit, 0) betcredit,
		isnull(c.reject,0) as suspended 
	FROM
	(
		SELECT custid, username, reject, closed, Enabled, credit as givencredit , ROW_NUMBER() over(order by enabled desc, closed, isnull(reject,0), username) as RowNum,
			(SELECT SUM(credit) FROM custInfo WITH(NOLOCK) WHERE roleid = 1 AND recommend = c.custid) AS usedCredit
		FROM Custinfo as c with (NOLOCK)	
		WHERE c.mrecommend = @MRecommend and c.roleid=2 
			AND c.username like '%' + @Username + '%'  
			AND c.enabled = case when coalesce(@Closed,@Suspended) is not null then 1 else coalesce(@enabled, c.enabled) end
			AND isnull(c.closed,0) = case when @suspended = 1 then 0 else coalesce(@closed, isnull(c.closed, 0)) end
			AND isnull(c.reject,0) = case when @Closed = 0 then 0 else coalesce(@suspended, isnull(c.reject, 0))end			
	) as c
	WHERE RowNum between @RowStart and @RowEnd
END
GO

GRANT EXECUTE ON [dbo].[Agm_CustomerSelGivenCreditByMAg] TO [bodbDownlineNet] AS [dbo]
GO

GRANT VIEW DEFINITION ON [dbo].[Agm_CustomerSelGivenCreditByMAg] TO [vnteam] AS [dbo]
GO