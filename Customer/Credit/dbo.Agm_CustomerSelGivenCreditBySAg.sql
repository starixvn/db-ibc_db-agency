ALTER PROCEDURE [dbo].[Agm_CustomerSelGivenCreditBySAg]
	@SRecommend int ,
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
Task: Get all master's given credit of super custid=@SRecommend. It's only use for IPhone
DB: DBAGE.bodb02
Original:
Revisions:
	- 20110321@Kaden.Trinh: Rename @Keyword to @Username
	- 20110321@Kaden.Trinh: add parameter status(Enabled, Closed, Suspended), so that we can search for it.  
	- 20140403@Dom: Add Betcredit field
	- 20150707@Jim: exclude Metric Gaming running ticket from bettrans (Feature #38789)
	- 20160201@Percy: expand new RNG Casino [Redmine: #51952]
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
		srecommend=@SRecommend and roleid=3 
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
		select custid, username,reject, closed, Enabled, credit as givencredit , ROW_NUMBER() over(order by enabled desc, closed, isnull(reject,0), username) as RowNum
		from custinfo with(nolock) 
		where srecommend=@SRecommend and roleid=3
	) as c
	LEFT JOIN 
	(
		SELECT
			custid,
			SUM(outstanding) AS outstanding,
			SUM(balance) AS balance
		FROM (
			SELECT
				mrecommend as custid,
				IsNull(sum (case when ruben=0 then ABS(actual_stake) * mpositiontaking else 0 end),0) AS outstanding,
				IsNull(sum(case when custid=mrecommend then winlost-actual_stake else mwinlost+acomm-comm end),0) AS balance
			FROM bettrans with (NOLOCK)
			WHERE srecommend = @SRecommend
				AND (
						((bettype NOT IN (801,802,803,804,805,806) OR bettype NOT BETWEEN 2101 AND 2399) AND ruben =0)
						OR ruben <> 0
					)
				AND (
						(CONVERT(DATE, winlostdate) >= @yesterday AND bettype NOT BETWEEN 2101 AND 2399)
						OR CONVERT(DATE, winlostdate) < @yesterday
					)
			GROUP BY mrecommend
			UNION ALL
			SELECT
				mrecommend as custid,
				IsNull(sum (case when statusID IN (0, 1) then ABS(actual_stake) * mpositiontaking else 0 end),0) AS outstanding,
				IsNull(sum(case when CONVERT(DATE, winlostdate) >= @yesterday then case when custid=mrecommend then winlost-actual_stake else mwinlost+acomm-comm end else 0 end),0) AS balance
			FROM bettransRNG with (NOLOCK)
			WHERE srecommend = @SRecommend
				AND gameID BETWEEN 2101 AND 2399
			GROUP BY mrecommend
			) AS A
		GROUP BY custid
	) as t ON t.custid = c.custid
	LEFT JOIN 
	(
		SELECT
			mrecommend as custid,
			IsNull(sum(ABS(actual_stake) * mpositiontaking),0) AS outstanding
		FROM translog with (NOLOCK)
		WHERE srecommend = @SRecommend
		and statusID = 0
		GROUP BY mrecommend
	) translog ON translog.custid = c.custid
	WHERE RowNum between @RowStart and @RowEnd
END

ELSE IF @Username = ''
BEGIN
	IF @TotalPages = 0
	BEGIN  
		SELECT 
			@TotalPages = count(1),@TotalPages=@TotalPages/@PageSize + case when @TotalPages%@PageSize > 0 then 1 else 0 end  
		FROM 
			Custinfo as ci with (NOLOCK)
		WHERE 
			ci.SRecommend = @SRecommend and ci.roleid=3
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
		select custid, username,reject, closed, Enabled, credit as givencredit , ROW_NUMBER() over(order by enabled desc, closed, isnull(reject,0), username) as RowNum
		from custinfo with(nolock) 
		where srecommend=@SRecommend and roleid=3
		AND enabled = case when coalesce(@Closed,@Suspended) is not null then 1 else coalesce(@enabled, enabled) end
		AND isnull(closed,0) = case when @suspended = 1 then 0 else coalesce(@closed, isnull(closed, 0)) end
		AND isnull(reject,0) = case when @Closed = 0 then 0 else coalesce(@suspended, isnull(reject, 0))end
	) as c
	LEFT JOIN 
	(
		SELECT
			custid,
			SUM(outstanding) AS outstanding,
			SUM(balance) AS balance
		FROM (
			SELECT
				mrecommend as custid,
				IsNull(sum (case when ruben=0 then ABS(actual_stake) * mpositiontaking else 0 end),0) AS outstanding,
				IsNull(sum(case when custid=mrecommend then winlost-actual_stake else mwinlost+acomm-comm end),0) AS balance
			FROM bettrans with (NOLOCK)
			WHERE srecommend = @SRecommend
				AND (
						((bettype NOT IN (801,802,803,804,805,806) OR bettype NOT BETWEEN 2101 AND 2399) AND ruben =0)
						OR ruben <> 0
					)
				AND (
						(CONVERT(DATE, winlostdate) >= @yesterday AND bettype NOT BETWEEN 2101 AND 2399)
						OR CONVERT(DATE, winlostdate) < @yesterday
					)
			GROUP BY mrecommend
			UNION ALL
			SELECT
				mrecommend as custid,
				IsNull(sum (case when statusID IN (0, 1) then ABS(actual_stake) * mpositiontaking else 0 end),0) AS outstanding,
				IsNull(sum(case when CONVERT(DATE, winlostdate) >= @yesterday then case when custid=mrecommend then winlost-actual_stake else mwinlost+acomm-comm end else 0 end),0) AS balance
			FROM bettransRNG with (NOLOCK)
			WHERE srecommend = @SRecommend
				AND gameID BETWEEN 2101 AND 2399
			GROUP BY mrecommend
			UNION ALL
			SELECT
				mrecommend as custid,
				IsNull(sum (case when statusID IN (0, 1) then ABS(actual_stake) * mpositiontaking else 0 end),0) AS outstanding,
				IsNull(sum(case when CONVERT(DATE, winlostdate) >= @yesterday then case when custid=mrecommend then winlost-actual_stake else mwinlost+acomm-comm end else 0 end),0) AS balance
			FROM bettransRNG with (NOLOCK)
			WHERE srecommend = @SRecommend
				AND gameID BETWEEN 2101 AND 2399
			GROUP BY mrecommend
			) AS A
		GROUP BY custid
	) as t ON t.custid = c.custid
	LEFT JOIN 
	(
		SELECT
			mrecommend as custid,
			IsNull(sum(ABS(actual_stake) * mpositiontaking),0) AS outstanding
		FROM translog with (NOLOCK)
		WHERE srecommend = @SRecommend
		and statusID = 0
		GROUP BY mrecommend
	) translog ON translog.custid = c.custid
	WHERE RowNum between @RowStart and @RowEnd
END
ELSE
BEGIN 
	IF @TotalPages = 0
	BEGIN
		SELECT 
			@TotalPages = count(1),@TotalPages=@TotalPages/@PageSize + case when @TotalPages%@PageSize > 0 then 1 else 0 end  
		FROM 
			Custinfo as ci with (NOLOCK)
		WHERE 
			ci.SRecommend = @SRecommend and ci.roleid=3
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
		select custid, username,reject, closed, Enabled, credit as givencredit , ROW_NUMBER() over(order by enabled desc, closed, isnull(reject,0), username) as RowNum
		from custinfo ci with(nolock) 
		where srecommend=@SRecommend and roleid=3
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
				mrecommend as custid,
				IsNull(sum (case when ruben=0 then ABS(actual_stake) * mpositiontaking else 0 end),0) AS outstanding,
				IsNull(sum(case when custid=mrecommend then winlost-actual_stake else mwinlost+acomm-comm end),0) AS balance
			FROM bettrans with (NOLOCK)
			WHERE srecommend = @SRecommend
				AND (
						((bettype NOT IN (801,802,803,804,805,806) OR bettype NOT BETWEEN 2101 AND 2399) AND ruben =0)
						OR ruben <> 0
					)
				AND (
						(CONVERT(DATE, winlostdate) >= @yesterday AND bettype NOT BETWEEN 2101 AND 2399)
						OR CONVERT(DATE, winlostdate) < @yesterday
					)
			GROUP BY mrecommend
			UNION ALL
			SELECT
				mrecommend as custid,
				IsNull(sum (case when statusID IN (0, 1) then ABS(actual_stake) * mpositiontaking else 0 end),0) AS outstanding,
				IsNull(sum(case when CONVERT(DATE, winlostdate) >= @yesterday then case when custid=mrecommend then winlost-actual_stake else mwinlost+acomm-comm end else 0 end),0) AS balance
			FROM bettransRNG with (NOLOCK)
			WHERE srecommend = @SRecommend
				AND gameID BETWEEN 2101 AND 2399
			GROUP BY mrecommend
			UNION ALL
			SELECT
				mrecommend as custid,
				IsNull(sum (case when statusID IN (0, 1) then ABS(actual_stake) * mpositiontaking else 0 end),0) AS outstanding,
				IsNull(sum(case when CONVERT(DATE, winlostdate) >= @yesterday then case when custid=mrecommend then winlost-actual_stake else mwinlost+acomm-comm end else 0 end),0) AS balance
			FROM bettransRNG with (NOLOCK)
			WHERE srecommend = @SRecommend
				AND gameID BETWEEN 2101 AND 2399
			GROUP BY mrecommend
			) AS A
		GROUP BY custid
	) as t ON t.custid = c.custid
	LEFT JOIN 
	(
		SELECT
			mrecommend as custid,
			IsNull(sum(ABS(actual_stake) * mpositiontaking),0) AS outstanding
		FROM translog with (NOLOCK)
		WHERE srecommend = @SRecommend
		and statusID = 0
		GROUP BY mrecommend
	) translog ON translog.custid = c.custid
	WHERE RowNum between @RowStart and @RowEnd
END
GO

GRANT EXECUTE ON [dbo].[Agm_CustomerSelGivenCreditBySAg] TO [bodbDownlineNet] AS [dbo]
GO
GO