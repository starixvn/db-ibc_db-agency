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
	- 20140403@Dom: Add Betcredit field
	- 20150707@Jim: exclude Metric Gaming running ticket from bettrans (Feature #38789)
	- 20160201@Percy: expand new RNG Casino [Redmine: #51912]
	- 20160202@Percy: support new sport Cricket [Redmine: #50027]
	- 20160219@Percy: Support AllBet Live Casino [Redmine: #52553]
	- 20160413@Percy: Support Voidbridge single wallet [Redmine: #55259]
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
			recommend=@Recommend and roleid=1
	END

	SELECT 
		c.custid, 
		c.username, 
		c.givencredit,
		c.enabled,
		c.closed, 
		c.givencredit+ISNULL(t.balance,0)-(ISNULL(t.outstanding,0)+ISNULL(translog.outstanding,0))+ISNULL(netBalance.netPosition, 0) betcredit,
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
			custid,
			SUM(outstanding) AS outstanding,
			SUM(balance) AS balance
		FROM (
			SELECT
				custid as custid,
				IsNull(sum (case when ruben=0 then ABS(actual_stake) else 0 end),0) AS outstanding,
				IsNull(sum(case when ruben=1 then winlost - actual_stake + playercomm else 0 end),0) AS balance
			FROM bettrans with (NOLOCK)
			WHERE recommend = @Recommend
				AND (
						(bettype NOT IN (801,802,803,804,805,806) AND bettype NOT BETWEEN 2101 AND 2499 AND bettype NOT BETWEEN 4001 AND 7999 AND ruben =0)
						OR ruben <> 0
					)
				AND (
						(CONVERT(DATE, winlostdate) >= @yesterday AND bettype NOT BETWEEN 2101 AND 2499 AND bettype NOT BETWEEN 4001 AND 7999)
						OR CONVERT(DATE, winlostdate) < @yesterday
					)
			GROUP BY custid
			UNION ALL
			SELECT
				custid as custid,
				IsNull(sum (case when statusID IN (0, 1) then ABS(actual_stake) else 0 end),0) AS outstanding,
				IsNull(sum(case when CONVERT(DATE, winlostdate) >= @yesterday then case when statusID NOT IN (0, 1) then winlost - actual_stake + playercomm else 0 end else 0 end),0) AS balance
			FROM bettransRNG with (NOLOCK)
			WHERE recommend = @Recommend
				AND (gameID BETWEEN 2101 AND 2399 OR gameID BETWEEN 4001 AND 7999)
			GROUP BY custid
			UNION ALL
			SELECT
				custid as custid,
				IsNull(sum (case when statusID IN (0, 1) then ABS(actual_stake) else 0 end),0) AS outstanding,
				IsNull(sum(case when CONVERT(DATE, winlostdate) >= @yesterday then case when statusID NOT IN (0, 1) then winlost - actual_stake + playercomm else 0 end else 0 end),0) AS balance
			FROM bettransLC with (NOLOCK)
			WHERE recommend = @Recommend
				AND gameID BETWEEN 2401 AND 2499
			GROUP BY custid
			) AS A
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
	LEFT JOIN
	(
		SELECT
			C.custid as custid,
			ISNULL(SUM(NP.Credit - NP.Debit), 0) AS netPosition
		FROM DBTXN.bodb02.dbo.BalNetPosition NP WITH (NOLOCK)
		INNER JOIN Customer C WITH (NOLOCK)
			ON NP.custid = C.custid
		WHERE C.recommend = @Recommend
		GROUP BY C.custid
	) netBalance ON netBalance.custid = c.custid
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
		c.givencredit+ISNULL(t.balance,0)-(ISNULL(t.outstanding,0)+ISNULL(translog.outstanding,0))+ISNULL(netBalance.netPosition, 0) betcredit,
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
			custid,
			SUM(outstanding) AS outstanding,
			SUM(balance) AS balance
		FROM (
			SELECT
				custid as custid,
				IsNull(sum (case when ruben=0 then ABS(actual_stake) else 0 end),0) AS outstanding,
				IsNull(sum(case when ruben=1 then winlost - actual_stake + playercomm else 0 end),0) AS balance
			FROM bettrans with (NOLOCK)
			WHERE recommend = @Recommend
				AND (
						(bettype NOT IN (801,802,803,804,805,806) AND bettype NOT BETWEEN 2101 AND 2499 AND bettype NOT BETWEEN 4001 AND 7999 AND ruben =0)
						OR ruben <> 0
					)
				AND (
						(CONVERT(DATE, winlostdate) >= @yesterday AND bettype NOT BETWEEN 2101 AND 2499 AND bettype NOT BETWEEN 4001 AND 7999)
						OR CONVERT(DATE, winlostdate) < @yesterday
					)
			GROUP BY custid
			UNION ALL
			SELECT
				custid as custid,
				IsNull(sum (case when statusID IN (0, 1) then ABS(actual_stake) else 0 end),0) AS outstanding,
				IsNull(sum(case when CONVERT(DATE, winlostdate) >= @yesterday then case when statusID NOT IN (0, 1) then winlost - actual_stake + playercomm else 0 end else 0 end),0) AS balance
			FROM bettransRNG with (NOLOCK)
			WHERE recommend = @Recommend
				AND (gameID BETWEEN 2101 AND 2399 OR gameID BETWEEN 4001 AND 7999)
			GROUP BY custid
			UNION ALL
			SELECT
				custid as custid,
				IsNull(sum (case when statusID IN (0, 1) then ABS(actual_stake) else 0 end),0) AS outstanding,
				IsNull(sum(case when CONVERT(DATE, winlostdate) >= @yesterday then case when statusID NOT IN (0, 1) then winlost - actual_stake + playercomm else 0 end else 0 end),0) AS balance
			FROM bettransLC with (NOLOCK)
			WHERE recommend = @Recommend
				AND gameID BETWEEN 2401 AND 2499
			GROUP BY custid
			) AS A
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
	LEFT JOIN
	(
		SELECT
			C.custid as custid,
			ISNULL(SUM(NP.Credit - NP.Debit), 0) AS netPosition
		FROM DBTXN.bodb02.dbo.BalNetPosition NP WITH (NOLOCK)
		INNER JOIN Customer C WITH (NOLOCK)
			ON NP.custid = C.custid
		WHERE C.recommend = @Recommend
		GROUP BY C.custid
	) netBalance ON netBalance.custid = c.custid
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
		c.givencredit+ISNULL(t.balance,0)-(ISNULL(t.outstanding,0)+ISNULL(translog.outstanding,0))+ISNULL(netBalance.netPosition, 0) betcredit,
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
			custid,
			SUM(outstanding) AS outstanding,
			SUM(balance) AS balance
		FROM (
			SELECT
				custid as custid,
				IsNull(sum (case when ruben=0 then ABS(actual_stake) else 0 end),0) AS outstanding,
				IsNull(sum(case when ruben=1 then winlost - actual_stake + playercomm else 0 end),0) AS balance
			FROM bettrans with (NOLOCK)
			WHERE recommend = @Recommend AND recommend <> custid
				AND (
						(bettype NOT IN (801,802,803,804,805,806) AND bettype NOT BETWEEN 2101 AND 2499 AND bettype NOT BETWEEN 4001 AND 7999 AND ruben =0)
						OR ruben <> 0
					)
				AND (
						(CONVERT(DATE, winlostdate) >= @yesterday AND bettype NOT BETWEEN 2101 AND 2499 AND bettype NOT BETWEEN 4001 AND 7999)
						OR CONVERT(DATE, winlostdate) < @yesterday
					)
			GROUP BY custid
			UNION ALL
			SELECT
				custid as custid,
				IsNull(sum (case when statusID IN (0, 1) then ABS(actual_stake) else 0 end),0) AS outstanding,
				IsNull(sum(case when CONVERT(DATE, winlostdate) >= @yesterday then case when statusID NOT IN (0, 1) then winlost - actual_stake + playercomm else 0 end else 0 end),0) AS balance
			FROM bettransRNG with (NOLOCK)
			WHERE recommend = @Recommend AND recommend <> custid
				AND (gameID BETWEEN 2101 AND 2399 OR gameID BETWEEN 4001 AND 7999)
			GROUP BY custid
			UNION ALL
			SELECT
				custid as custid,
				IsNull(sum (case when statusID IN (0, 1) then ABS(actual_stake) else 0 end),0) AS outstanding,
				IsNull(sum(case when CONVERT(DATE, winlostdate) >= @yesterday then case when statusID NOT IN (0, 1) then winlost - actual_stake + playercomm else 0 end else 0 end),0) AS balance
			FROM bettransLC with (NOLOCK)
			WHERE recommend = @Recommend AND recommend <> custid
				AND gameID BETWEEN 2401 AND 2499
			GROUP BY custid
			) AS A
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
	LEFT JOIN
	(
		SELECT
			C.custid as custid,
			ISNULL(SUM(NP.Credit - NP.Debit), 0) AS netPosition
		FROM DBTXN.bodb02.dbo.BalNetPosition NP WITH (NOLOCK)
		INNER JOIN Customer C WITH (NOLOCK)
			ON NP.custid = C.custid
		WHERE C.recommend = @Recommend
		GROUP BY C.custid
	) netBalance ON netBalance.custid = c.custid
	WHERE RowNum between @RowStart and @RowEnd
END
GO
GRANT EXECUTE ON [dbo].[Agm_CustomerSelGivenCreditByAg] TO [bodbDownlineNet] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[Agm_CustomerSelGivenCreditByAg] TO [vnteam] AS [dbo]
GO