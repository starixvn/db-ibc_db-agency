/*<info serverAlias="DBSIC-bodb02,DBCTG-bodb02" executers="bodbDownlineNet,bodbDownlineNetView" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Age_ClearBalanceCust_ProcessSel]
	@FromCustId		INT,
	@Language		VARCHAR(2)= 'E', 
	@ViewStatus		VARCHAR(1000) = 'All',
	@Searchname		NVARCHAR(50) = NULL,
	@SortBy			TINYINT = 1,
	@SortType		BIT = 0,
	@PageIndex		INT = 1,
	@PageSize		INT = 500,
	@TotalRow		INT = 0 OUTPUT,
	@TotalCancelAll	INT = 0 OUTPUT,
	@TotalPending	INT = 0 OUTPUT,
	@TotalProcessing	INT = 0 OUTPUT,
	@TotalFailed	INT = 0 OUTPUT
AS
/*
	Created:20230227@Bobby
	Task: 182071 - Auto Transfer/ Multiple Transfer	
	DB: DBSIC-bodb02,DBCTG-bodb02

	Revisions:
		- 20230227@Bobby: AutoJob clear balance downlines [RedmineID: #182071]
		- 20230822@Bobby: Support unicode FirstName/LastName [RedmineID: #193017]
		- 20231018@Bobby: Support cancel ALL [RedmineID: #195443]

	Param's Explanation:
		- @SortBy:
			+ 1: Username
			+ 2: Status
			+ 3: Amount
			+ 4: CompletedTime
			

*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @BASELINE_DATE	DATETIME = '2023-01-01';
	DECLARE @today		DATE,
		@RoleId			TINYINT,
		@UplineId		INT,
		@CheckName		NVARCHAR(50),
		@StatusCheck	VARCHAR(1000)
	;

	DECLARE @tmpStatus	TABLE([Status] VARCHAR(15));

	SELECT @today			= GETDATE(),
		@StatusCheck		= ISNULL(@ViewStatus, 'All'),
		@UplineId			= @FromCustId,
		@CheckName			= @Searchname,
		@TotalRow			= 0,
		@TotalCancelAll		= 0,
		@TotalPending		= 0,
		@TotalProcessing	= 0,
		@TotalFailed		= 0
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
	FROM STRING_SPLIT('New,Waiting,Processing,Completed,Failed,Cancelled,Pending,Ignored', ',') AS t
	LEFT JOIN CTE_Status cte ON cte.[Status] = t.[Value]
	WHERE @StatusCheck = 'All'
		OR cte.[Status] IS NOT NULL
	;

	SELECT TOP 1 @RoleId = c.RoleId
	FROM CustDB.dbo.Customer c WITH(NOLOCK)
	WHERE c.CustId = @UplineId
	;

	IF LEN(@Searchname) > 0 AND @RoleId IN (2,3,4)
	BEGIN
		INSERT INTO #tmpDownline (CustId)
		SELECT custid
		FROM CustDB.dbo.Customer c WITH(NOLOCK)
		WHERE c.Recommend = @UplineId
			AND (
				c.username LIKE '%' + @CheckName + '%' OR
				c.FirstName LIKE '%' + @CheckName + '%' OR
				c.LastName LIKE '%' + @CheckName + '%'
			)
			AND @RoleId = 2
		UNION ALL
		SELECT custid
		FROM CustDB.dbo.Customer c WITH(NOLOCK)
		WHERE c.MRecommend = @UplineId
			AND (
				c.username LIKE '%' + @CheckName + '%' OR
				c.FirstName LIKE '%' + @CheckName + '%' OR
				c.LastName LIKE '%' + @CheckName + '%'
			)
			AND @RoleId = 3
		UNION ALL
		SELECT custid
		FROM CustDB.dbo.Customer c WITH(NOLOCK)
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
		CustId			INT,
		UserName		VARCHAR(30),
		FirstName		NVARCHAR(50),
		LastName		NVARCHAR(50),
		Amount			MONEY,
		[Status]		VARCHAR(15),
		Reason			NVARCHAR(4000),
		CompletedTime	VARCHAR(100),
		IsAllowCancel	BIT,
		TotalRow		INT
	);

	INSERT INTO #pageResult (CustId, UserName, FirstName, LastName, Amount, [Status], Reason, CompletedTime, IsAllowCancel, TotalRow)
	SELECT c.custid, c.UserName, c.FirstName, c.LastName,  
		CASE 
			WHEN p.StartTime IS NOT NULL THEN p.Amount
			ELSE NULL
		END AS Amount, 
		p.[Status],
		CASE 
			WHEN p.[Status] IN ('Pending') THEN REPLACE(ct.Reason, '<TO_TIME>', ct.ToTimeText)
			ELSE ct.Reason END AS Reason,
		CASE WHEN ct.CompletedTimeSec > 0 THEN FORMAT(DATEADD(SECOND, ct.CompletedTimeSec, @BASELINE_DATE), 'MM/dd/yyyy HH:mm:ss tt') ELSE '' END AS CompletedTime,
		CASE 
			WHEN p.[Status] IN ('Waiting', 'Processing', 'Pending') AND DATEDIFF(MINUTE, p.ModifiedTime, CURRENT_TIMESTAMP) >= 15 THEN 1 
			ELSE 0 
		END AS IsAllowCancel,
		COUNT(1) OVER() AS TotalRow
	
	FROM bodb02.dbo.Age_ClearBalanceCust_Process p WITH(NOLOCK)
		INNER JOIN @tmpStatus tmp ON tmp.[Status] = p.[Status]
		INNER JOIN CustDB.dbo.Customer c WITH(NOLOCK) ON c.CustId = p.ToCustId
		LEFT JOIN #tmpDownline cte ON cte.custId = p.ToCustId
		LEFT JOIN dbo.f_Age_ClearBalanceCust_ErrorSel() err ON err.ErrType = JSON_VALUE(p.Result, '$.ErrType')
		OUTER APPLY (
			SELECT CASE 
				WHEN p.Status IN ('Completed','Failed','Cancelled','Ignored') THEN DATEDIFF(SECOND,@BASELINE_DATE, ISNULL(p.EndTime, p.ModifiedTime))
				ELSE 0 
			END AS CompletedTimeSec,
			CASE 
				WHEN err.ErrType IS NOT NULL THEN CustDB.[dbo].[f_Get_MsgNamebyMsgID](JSON_VALUE(p.Result, '$.MsgId'), @Language)
				ELSE '' END AS Reason,
				ISNULL(FORMAT(DATEADD(HOUR, 12, CAST(JSON_VALUE(p.Result, '$.ToTime') AS DATETIME)), 'MM/dd/yyyy HH:mm:ss'), '') AS ToTimeText

		) AS ct
	WHERE p.FromCustId = @FromCustId
		AND p.SessionDate = @today
		AND (
			err.ErrType IS NULL
			OR err.IsShowHistory = 1
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
	;

	SELECT TOP(1) @TotalRow = TotalRow
	FROM #pageResult
	;

	-- GET total by StatusCount
	WITH CTE_CountInfo AS (
		SELECT 
			CASE 
				WHEN p.[Status] IN ('Waiting', 'Processing') AND DATEDIFF(MINUTE, p.ModifiedTime, CURRENT_TIMESTAMP) >= 15 THEN 'Cancel_Processing' 
				WHEN p.[Status] IN ('Pending') AND DATEDIFF(MINUTE, p.ModifiedTime, CURRENT_TIMESTAMP) >= 15 THEN 'Cancel_Pending' 
				WHEN p.[Status] IN ('Pending') THEN 'Pending'
				WHEN p.[Status] IN ('New', 'Waiting', 'Processing', 'Pending') THEN 'Processing'
				WHEN p.[Status] IN ('Failed') AND ((err.IsShowHistory = 1 AND err.AllowReTry = 0) OR (err.AllowReTry = 1 AND p.TryCount IN (5, 60))) THEN 'Failed'
			END AS StatusCount
		FROM bodb02.dbo.Age_ClearBalanceCust_Process p WITH(NOLOCK)
			LEFT JOIN dbo.f_Age_ClearBalanceCust_ErrorSel() err ON err.ErrType = JSON_VALUE(p.Result, '$.ErrType')
		WHERE p.FromCustId = @FromCustId
			AND p.SessionDate = @today
	)
	SELECT 
		@TotalCancelAll		= SUM(CASE WHEN StatusCount IN ('Cancel_Processing', 'Cancel_Pending') THEN 1 ELSE 0 END)
		,@TotalPending		= SUM(CASE WHEN StatusCount IN ('Pending', 'Cancel_Pending') THEN 1 ELSE 0 END)
		,@TotalProcessing	= SUM(CASE WHEN StatusCount IN ('Processing', 'Cancel_Processing') THEN 1 ELSE 0 END)
		,@TotalFailed		= SUM(CASE WHEN StatusCount = 'Failed' THEN 1 ELSE 0 END)
	FROM CTE_CountInfo;

	SELECT CustId, UserName, FirstName, LastName, Amount, [Status], Reason, CompletedTime, IsAllowCancel
	FROM #pageResult
	ORDER BY rIdx ASC
	OFFSET ((@PageIndex-1)*@PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY
	;
END
GO
