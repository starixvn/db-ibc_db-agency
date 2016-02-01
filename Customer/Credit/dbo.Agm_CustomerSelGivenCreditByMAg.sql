ALTER PROCEDURE [dbo].[Agm_CustomerSelGivenCreditByMAg_xtest]
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
	- 20110321@Kaden.Trinh: Rename @Keyword to @Username
	- 20110321@Kaden.Trinh: add parameter status(Enabled, Closed, Suspended), so that we can search for it.  
	- 20140403@Dom: Add Betcredit field
	- 20150707@Jim: exclude Metric Gaming running ticket from bettrans (Feature #38789)
	- 20160201@Percy: expand new RNG Casino [Redmine: #51912]
	- 20160202@Percy: support new sport Cricket [Redmine: #50027]
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
		c.givencredit+ISNULL(t.balance,0)-(ISNULL(t.outstanding,0)+ISNULL(translog.outstanding,0))+ISNULL(netBalance.netPosition, 0) betcredit,
		isnull(c.reject,0) as suspended 
	FROM
	(
		select custid, username, reject, closed, Enabled, credit as givencredit , ROW_NUMBER() over(order by enabled desc, closed, isnull(reject,0), username) as RowNum
		from custinfo with(nolock) 
		where mrecommend=@MRecommend and roleid=2
	) as c
	LEFT JOIN 
	(
		SELECT
			custid,
			SUM(outstanding) AS outstanding,
			SUM(balance) AS balance
		FROM (
			SELECT
				recommend as custid,
				IsNull(sum (case when ruben=0 then ABS(actual_stake) * apositiontaking else 0 end),0) AS outstanding, 
				IsNull(sum(case when custid=recommend then winlost-actual_stake else awinlost+comm-playercomm end),0) AS balance
			FROM bettrans with (NOLOCK)
			WHERE mrecommend = @MRecommend
				AND (
						((bettype NOT IN (801,802,803,804,805,806) OR bettype NOT BETWEEN 2101 AND 2399) AND ruben =0)
						OR ruben <> 0
					)
				AND (
						(CONVERT(DATE, winlostdate) >= @yesterday AND bettype NOT BETWEEN 2101 AND 2399)
						OR CONVERT(DATE, winlostdate) < @yesterday
					)
			GROUP BY recommend
			UNION ALL
			SELECT
				recommend as custid,
				IsNull(sum (case when statusID IN (0, 1) then ABS(actual_stake) * apositiontaking else 0 end),0) AS outstanding, 
				IsNull(sum(case when CONVERT(DATE, winlostdate) >= @yesterday then case when custid=recommend then winlost-actual_stake else awinlost+comm-playercomm end else 0 end),0) AS balance
			FROM bettransRNG with (NOLOCK)
			WHERE mrecommend = @MRecommend
				AND gameID BETWEEN 2101 AND 2399
			GROUP BY recommend
			UNION ALL
			SELECT
				recommend as custid,
				IsNull(sum (case when statusID IN (0, 1) then ABS(actual_stake) * apositiontaking else 0 end),0) AS outstanding, 
				IsNull(sum(case when CONVERT(DATE, winlostdate) >= @yesterday then case when custid=recommend then winlost-actual_stake else awinlost+comm-playercomm end else 0 end),0) AS balance
			FROM bettransRNG with (NOLOCK)
			WHERE mrecommend = @MRecommend
				AND gameID BETWEEN 2101 AND 2399
			GROUP BY recommend
			) AS A
		GROUP BY custid
	) as t ON t.custid = c.custid
	LEFT JOIN 
	(
		SELECT
			recommend as custid,
			IsNull(sum(ABS(actual_stake)  * apositiontaking),0) AS outstanding
		FROM translog with (NOLOCK)
		WHERE mrecommend = @MRecommend
		and statusID = 0
		GROUP BY recommend
	) translog ON translog.custid = c.custid
	LEFT JOIN
	(
		SELECT
			C.recommend as custid,
			ISNULL(SUM(NP.Credit - NP.Debit), 0) AS netPosition
		FROM DBPRO.bodb02.dbo.BalNetPosition NP WITH (NOLOCK)
		INNER JOIN Customer C WITH (NOLOCK)
			ON NP.custid = C.custid
		WHERE C.mrecommend = @MRecommend
		GROUP BY C.recommend
	) netBalance ON netBalance.custid = c.custid
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
		c.givencredit+ISNULL(t.balance,0)-(ISNULL(t.outstanding,0)+ISNULL(translog.outstanding,0)) betcredit,
		isnull(c.reject,0) as suspended 
	FROM
	(
		SELECT custid, username, reject, closed, Enabled, credit as givencredit , ROW_NUMBER() over(order by enabled desc, closed, isnull(reject,0), username) as RowNum
		FROM Custinfo as ci with (NOLOCK)	
		WHERE ci.mrecommend = @MRecommend and ci.roleid=2 
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
				recommend as custid,
				IsNull(sum (case when ruben=0 then ABS(actual_stake) * apositiontaking else 0 end),0) AS outstanding, 
				IsNull(sum(case when custid=recommend then winlost-actual_stake else awinlost+comm-playercomm end),0) AS balance
			FROM bettrans with (NOLOCK)
			WHERE mrecommend = @MRecommend
				AND (
						((bettype NOT IN (801,802,803,804,805,806) OR bettype NOT BETWEEN 2101 AND 2399) AND ruben =0)
						OR ruben <> 0
					)
				AND (
						(CONVERT(DATE, winlostdate) >= @yesterday AND bettype NOT BETWEEN 2101 AND 2399)
						OR CONVERT(DATE, winlostdate) < @yesterday
					)
			GROUP BY recommend
			UNION ALL
			SELECT
				recommend as custid,
				IsNull(sum (case when statusID IN (0, 1) then ABS(actual_stake) * apositiontaking else 0 end),0) AS outstanding, 
				IsNull(sum(case when CONVERT(DATE, winlostdate) >= @yesterday then case when custid=recommend then winlost-actual_stake else awinlost+comm-playercomm end else 0 end),0) AS balance
			FROM bettransRNG with (NOLOCK)
			WHERE mrecommend = @MRecommend
				AND gameID BETWEEN 2101 AND 2399
			GROUP BY recommend
			) AS A
		GROUP BY custid
	) as t ON t.custid = c.custid
	LEFT JOIN 
	(
		SELECT
			recommend as custid,
			IsNull(sum(ABS(actual_stake) * apositiontaking),0) AS outstanding
		FROM translog with (NOLOCK)
		WHERE mrecommend = @MRecommend
		and statusID = 0
		GROUP BY recommend
	) translog ON translog.custid = c.custid
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
		c.givencredit+ISNULL(t.balance,0)-(ISNULL(t.outstanding,0)+ISNULL(translog.outstanding,0)) betcredit,
		isnull(c.reject,0) as suspended 
	FROM
	(
		SELECT custid, username, reject, closed, Enabled, credit as givencredit , ROW_NUMBER() over(order by enabled desc, closed, isnull(reject,0), username) as RowNum
		FROM Custinfo as ci with (NOLOCK)	
		WHERE ci.mrecommend = @MRecommend and ci.roleid=2 
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
				recommend as custid,
				IsNull(sum (case when ruben=0 then ABS(actual_stake) * apositiontaking else 0 end),0) AS outstanding, 
				IsNull(sum(case when custid=recommend then winlost-actual_stake else awinlost+comm-playercomm end),0) AS balance
			FROM bettrans with (NOLOCK)
			WHERE mrecommend = @MRecommend
				AND (
						((bettype NOT IN (801,802,803,804,805,806) OR bettype NOT BETWEEN 2101 AND 2399) AND ruben =0)
						OR ruben <> 0
					)
				AND (
						(CONVERT(DATE, winlostdate) >= @yesterday AND bettype NOT BETWEEN 2101 AND 2399)
						OR CONVERT(DATE, winlostdate) < @yesterday
					)
			GROUP BY recommend
			UNION ALL
			SELECT
				recommend as custid,
				IsNull(sum (case when statusID IN (0, 1) then ABS(actual_stake) * apositiontaking else 0 end),0) AS outstanding, 
				IsNull(sum(case when CONVERT(DATE, winlostdate) >= @yesterday then case when custid=recommend then winlost-actual_stake else awinlost+comm-playercomm end else 0 end),0) AS balance
			FROM bettransRNG with (NOLOCK)
			WHERE mrecommend = @MRecommend
				AND gameID BETWEEN 2101 AND 2399
			GROUP BY recommend
			) AS A
		GROUP BY custid
	) as t ON t.custid = c.custid
	LEFT JOIN 
	(
		SELECT
			recommend as custid,
			IsNull(sum(ABS(actual_stake) * apositiontaking),0) AS outstanding
		FROM translog with (NOLOCK)
		WHERE mrecommend = @MRecommend
		and statusID = 0
		GROUP BY recommend
	) translog ON translog.custid = c.custid
	WHERE RowNum between @RowStart and @RowEnd
END
GO

GRANT EXECUTE ON [dbo].[Agm_CustomerSelGivenCreditByMAg] TO [bodbDownlineNet] AS [dbo]
GO

GRANT VIEW DEFINITION ON [dbo].[Agm_CustomerSelGivenCreditByMAg] TO [vnteam] AS [dbo]
GO