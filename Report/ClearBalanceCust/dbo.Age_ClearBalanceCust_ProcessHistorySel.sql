/*<info serverAlias="DBARC-bodb_Archive" executers="bodbDownlineNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Age_ClearBalanceCust_ProcessHistorySel]
	@FromCustId		INT,
	@FromDate		DATE,
	@ToDate			DATE,
	@ViewStatus		VARCHAR(1000) = 'All',
	@Searchname		VARCHAR(50) = NULL,
	@SortBy			TINYINT = 1,
	@SortType		BIT = 0,
	@PageIndex		INT = 1,
	@PageSize		INT = 500
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

	DECLARE @today		DATE,
		@yesterday		DATE,
		@RoleId			TINYINT,
		@UplineId		INT,
		@CheckName		VARCHAR(50),
		@StatusCheck	VARCHAR(1000),
		@rptFromDate	SMALLDATETIME,
		@rptToDate		SMALLDATETIME
	;

	DECLARE @tmpStatus	TABLE([Status] VARCHAR(15));

	SELECT @today			= GETDATE(),
		@yesterday			= DATEADD(DAY, -1, @today),
		@StatusCheck		= ISNULL(@ViewStatus, 'All'),
		@UplineId			= @FromCustId,
		@CheckName			= @Searchname,
		@rptFromDate		= IIF(@FromDate >= @today, @yesterday, @FromDate),
		@rptToDate			= @ToDate
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
	SELECT t.[Value]
	FROM STRING_SPLIT('New,Waiting,Processing,Completed,Failed,Cancelled', ',') AS t
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
	SELECT c.UserName, c.FirstName, c.LastName,  
		CASE 
			WHEN p.[Status] IN ('Processing', 'Completed', 'Failed') THEN p.Amount
			ELSE NULL
		END AS Amount, 
		p.[Status],
		CASE 
			WHEN p.[Status] = 'Failed' THEN ck.ErrMsg 
		ELSE '' END AS Reason,
		CASE 
			WHEN p.[Status] IN ('Completed', 'Failed') THEN p.EndTime
			WHEN p.[Status] IN ('Cancelled') THEN p.ModifiedTime 
			ELSE NULL 
		END AS CompletedTime
		
	FROM bodb_Archive.dbo.Age_ClearBalanceCust_ProcessHistory p WITH(NOLOCK)
		INNER JOIN @tmpStatus tmp ON tmp.[Status] = p.[Status]
		INNER JOIN bodb02.dbo.Customer c WITH(NOLOCK) ON c.CustId = p.ToCustId
		LEFT JOIN #tmpDownline cte ON cte.custId = p.ToCustId
		OUTER APPLY (
			SELECT ErrType, ErrMsg
			FROM OPENJSON(p.Result)
			WITH (
				ErrType VARCHAR(15) '$.ErrType',
				ErrMsg	NVARCHAR(4000) '$.ErrMsg'
			)
		) AS ck
	WHERE p.FromCustId = @FromCustId
		AND p.SessionDate BETWEEN @rptFromDate AND @rptToDate
		AND (
			@StatusCheck <> 'Failed'
			OR (p.[Status] = 'Failed' AND ck.ErrType IN ('DBIssue'))
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
			ELSE 0
			END DESC

	OFFSET ((@PageIndex-1)*@PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY
	;

END
GO
