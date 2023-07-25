/*<info serverAlias="DBARC-bodb_Archive" executers="bodbDownlineNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Age_ClearBalanceCust_ProcessHistorySel]
	@FromCustId		INT,
	@FromDate		DATE,
	@ToDate			DATE,
	@Language		VARCHAR(2)= 'E', 
	@ViewStatus		VARCHAR(1000) = 'All',
	@Searchname		VARCHAR(50) = NULL,
	@SortBy			TINYINT = 1,
	@SortType		BIT = 0,
	@PageIndex		INT = 1,
	@PageSize		INT = 500,
	@TotalRow		INT = 0 OUTPUT
AS
/*
	Created:20230227@Bobby
	Task: 182071 - Auto Transfer/ Multiple Transfer	
	DB: DBTXN/bodb02

	Revisions:
		- 20230227@Bobby: AutoJob clear balance downlines [RedmineID: #182071]

	Param's Explanation:

*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @BASELINE_DATE	DATETIME = '2023-01-01';
	DECLARE @today		DATE,
		@yesterday		DATE,
		@RoleId			TINYINT,
		@UplineId		INT,
		@CheckName		VARCHAR(50),
		@StatusCheck	VARCHAR(1000),
		@rptFromDate	SMALLDATETIME,
		@rptToDate		SMALLDATETIME,
		@Last3Months	SMALLDATETIME
	;

	DECLARE @tmpStatus	TABLE([Status] VARCHAR(15));

	SELECT @today			= GETDATE(),
		@yesterday			= DATEADD(DAY, -1, @today),
		@Last3Months		= DATEADD(MONTH, -3, @today),
		@StatusCheck		= ISNULL(@ViewStatus, 'All'),
		@UplineId			= @FromCustId,
		@CheckName			= @Searchname,
		@rptToDate			= IIF(@ToDate >= @today, @yesterday, @ToDate),
		@rptFromDate		= IIF(@FromDate < @Last3Months, @Last3Months, @FromDate)
	;

	DROP TABLE IF EXISTS #tmpDownline;
	CREATE TABLE #tmpDownline (CustId INT PRIMARY KEY)
	;

	WITH CTE_Status AS (
		SELECT t.[Value] AS [Status]
		FROM STRING_SPLIT(@StatusCheck, ',') t
		WHERE @StatusCheck <> 'All'
	)
	INSERT INTO @tmpStatus([Status])
	SELECT DISTINCT t.[Value]
	FROM STRING_SPLIT('New,Waiting,Processing,Completed,Failed,Cancelled,Pending,Ignored', ',') AS t
	LEFT JOIN CTE_Status cte ON cte.[Status] = t.[Value]
	WHERE @StatusCheck = 'All'
		OR cte.[Status] IS NOT NULL
	;

	SELECT TOP 1 @RoleId = c.RoleId
	FROM bodb02.dbo.Customer c WITH(NOLOCK)
	WHERE c.CustId = @UplineId
	;

	IF LEN(@Searchname) > 0 AND @RoleId IN (2,3,4)
	BEGIN
		INSERT INTO #tmpDownline (CustId)
		SELECT custid
		FROM bodb02.dbo.Customer c WITH(NOLOCK)
		WHERE c.Recommend = @UplineId
			AND (
				c.username LIKE '%' + @CheckName + '%' OR
				c.FirstName LIKE '%' + @CheckName + '%' OR
				c.LastName LIKE '%' + @CheckName + '%'
			)
			AND @RoleId = 2
		UNION ALL
		SELECT custid
		FROM bodb02.dbo.Customer c WITH(NOLOCK)
		WHERE c.MRecommend = @UplineId
			AND (
				c.username LIKE '%' + @CheckName + '%' OR
				c.FirstName LIKE '%' + @CheckName + '%' OR
				c.LastName LIKE '%' + @CheckName + '%'
			)
			AND @RoleId = 3
		UNION ALL
		SELECT custid
		FROM bodb02.dbo.Customer c WITH(NOLOCK)
		WHERE c.SRecommend = @UplineId
			AND (
				c.username LIKE '%' + @CheckName + '%' OR
				c.FirstName LIKE '%' + @CheckName + '%' OR
				c.LastName LIKE '%' + @CheckName + '%'
			)
			AND @RoleId = 4
	END
	
	-- TOTO: OUTPUT Result
	DROP TABLE IF EXISTS #pageResult;
	CREATE TABLE #pageResult
	(
		rIdx			INT IDENTITY(1, 1) PRIMARY KEY,
		UserName		VARCHAR(50),
		FirstName		VARCHAR(50),
		LastName		VARCHAR(50),
		Amount			MONEY,
		[Status]		VARCHAR(15),
		Reason			NVARCHAR(4000),
		CompletedTime	VARCHAR(100),
		TotalRow		INT
	);

	INSERT INTO #pageResult (UserName, FirstName, LastName, Amount, [Status], Reason, CompletedTime, TotalRow)
	SELECT c.UserName, c.FirstName, c.LastName,  
		CASE 
			WHEN p.StartTime IS NOT NULL THEN p.Amount
			ELSE NULL
		END AS Amount, 
		p.[Status],
		CASE 
			WHEN p.[Status] IN ('Pending') THEN REPLACE(ct.Reason, '<TO_TIME>', ct.ToTimeText)
			ELSE ct.Reason END AS Reason,
		CASE WHEN ct.CompletedTimeSec > 0 THEN FORMAT(DATEADD(SECOND, ct.CompletedTimeSec, @BASELINE_DATE), 'MM/dd/yyyy HH:mm:ss tt') ELSE '' END AS CompletedTime,
		COUNT(1) OVER() AS TotalRow
		
	FROM bodb_Archive.dbo.Age_ClearBalanceCust_ProcessHistory p WITH(NOLOCK)
		INNER JOIN @tmpStatus tmp ON tmp.[Status] = p.[Status]
		INNER JOIN bodb02.dbo.Customer c WITH(NOLOCK) ON c.CustId = p.ToCustId
		LEFT JOIN #tmpDownline cte ON cte.custId = p.ToCustId
		LEFT JOIN dbo.f_Age_ClearBalanceCust_ErrorSel() err ON err.ErrType = JSON_VALUE(p.Result, '$.ErrType')
		OUTER APPLY (
			SELECT CASE 
				WHEN p.Status IN ('Completed','Failed','Cancelled') THEN DATEDIFF(SECOND,@BASELINE_DATE, ISNULL(p.EndTime, p.ModifiedTime))
				ELSE 0 
			END AS CompletedTimeSec,
			CASE 
				WHEN err.ErrType IS NOT NULL THEN bodb02.[dbo].[f_Get_MsgNamebyMsgID](JSON_VALUE(p.Result, '$.MsgId'), @Language)
				ELSE '' END AS Reason,
				ISNULL(FORMAT(DATEADD(HOUR, 12, CAST(JSON_VALUE(p.Result, '$.ToTime') AS DATETIME)), 'MM/dd/yyyy HH:mm:ss tt'), '') AS ToTimeText
		) AS ct
	WHERE p.FromCustId = @FromCustId
		AND p.SessionDate BETWEEN @rptFromDate AND @rptToDate
		AND (
			err.ErrType IS NULL
			OR (err.ErrType IS NOT NULL AND err.IsShowHistory = 1)
		)
		AND (@CheckName IS NULL OR cte.CustId > 0)
	ORDER BY 
		------------ ASC
		CASE 
			WHEN @SortType = 0 AND @SortBy = 1 THEN c.UserName 
			WHEN @SortType = 0 AND @SortBy = 2 THEN p.[Status]
			ELSE '' 
			END ASC,
		CASE 
			WHEN @SortType = 0 AND @SortBy = 3 THEN p.Amount
			WHEN @SortType = 0 AND @SortBy = 4 THEN ct.CompletedTimeSec
			ELSE 0
			END ASC,
		------------ DESC
		CASE 
			WHEN @SortType = 1 AND @SortBy = 1 THEN c.UserName 
			WHEN @SortType = 1 AND @SortBy = 2 THEN p.[Status]
			ELSE '' 
			END DESC,
		CASE 
			WHEN @SortType = 1 AND @SortBy = 3 THEN p.Amount
			WHEN @SortType = 1 AND @SortBy = 4 THEN ct.CompletedTimeSec
			ELSE 0
			END DESC

	OFFSET ((@PageIndex-1)*@PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY
	;

	SELECT TOP(1) @TotalRow = TotalRow
	FROM #pageResult
	;

	SELECT UserName, FirstName, LastName, Amount, [Status], Reason, CompletedTime
	FROM #pageResult
	ORDER BY rIdx ASC
	;

END
GO
