/*<info serverAlias="DBSIC-bodb02,DBCTG-bodb02" executers="bodbDownlineNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE  [dbo].[Age_ClearBalanceCust_ProcessCancel_All]
	@FromCustId		INT, 
	@Creator		INT,
	@ViewStatus		VARCHAR(1000) = 'All',
	@Searchname		NVARCHAR(50) = NULL,
	@Language		VARCHAR(2)= 'E',
	@IP				VARCHAR(45)='',
	@ErrCode		INT = 0 OUTPUT,  
	@ErrMsg			NVARCHAR(4000) = '' OUTPUT
AS  
/*
	Created:20201016@Bobby
	Task: 195443 - Enhance auto transfer function
	DB: DBSIC-bodb02,DBCTG-bodb02

	Revisions:
		- 20231018@Bobby: Support cancel ALL [RedmineID: #195443]

	Param's Explanation:
		• @FromCustID: S/M/A's custid

*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @totalCust	INT, @CheckCount INT,
		@RoleID			INT,
		@UplineId		INT,
		@CheckName		NVARCHAR(50),
		@StatusCheck	VARCHAR(1000)
	;

	DECLARE @tmpStatus	TABLE([Status] VARCHAR(15));

	SELECT @StatusCheck		= ISNULL(@ViewStatus, 'All'),
		@UplineId			= @FromCustId,
		@CheckName			= @Searchname

	DROP TABLE IF EXISTS #tmpDownlineSearch;
	CREATE TABLE #tmpDownlineSearch(CustId INT PRIMARY KEY);

	DROP TABLE IF EXISTS #tmpDownline;
	CREATE TABLE #tmpDownline(CustId INT PRIMARY KEY);

	SELECT @RoleID = (SELECT TOP 1 RoleID FROM CustDB.dbo.customer WITH (NOLOCK) WHERE custid = @UplineId);

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

	IF LEN(@Searchname) > 0 AND @RoleId IN (2,3,4)
	BEGIN
		INSERT INTO #tmpDownlineSearch (CustId)
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

	--TODO: Search for canceling
	INSERT INTO #tmpDownline(CustId)
	SELECT p.ToCustID
	FROM bodb02.dbo.Age_ClearBalanceCust_Process p WITH(NOLOCK)
		INNER JOIN @tmpStatus tmp ON tmp.[Status] = p.[Status]
		LEFT JOIN #tmpDownlineSearch src ON src.custId = p.ToCustId
	WHERE p.FromCustId = @FromCustId
		AND p.[Status] IN ('Waiting', 'Processing', 'Pending') 
		AND DATEDIFF(MINUTE, p.ModifiedTime, CURRENT_TIMESTAMP) >= 15
		AND (@CheckName IS NULL OR src.CustId > 0)
	;
	SET @totalCust = @@ROWCOUNT;

	IF (@totalCust = 0)
	BEGIN
		SELECT @ErrCode = 101,
				@ErrMsg = CustDB.[dbo].[f_Get_MsgNamebyMsgID](50032, @Language)
		RETURN;
	END

	--TODO: check cross line
	SELECT @CheckCount = COUNT(1)
	FROM dbo.Age_ClearBalanceCust_Process p WITH(ROWLOCK)
		INNER JOIN #tmpDownline c ON c.CustId = p.ToCustId
		INNER JOIN CustDB.dbo.customer ck WITH (NOLOCK) ON ck.CustId = c.CustId
	WHERE p.FromCustId = @FromCustID
		AND 1 = CASE 
					WHEN @RoleID = 2 AND ck.RoleID = 1 AND ck.recommend = @Creator THEN 1
					WHEN @RoleID = 3 AND ck.RoleID = 2 AND ck.mrecommend = @Creator THEN 1
					WHEN @RoleID = 4 AND ck.RoleID = 3 AND ck.srecommend = @Creator THEN 1
					ELSE 0
				END

	IF (@totalCust <> @CheckCount)
	BEGIN
		SELECT @ErrCode = 102,
				@ErrMsg = 'Invalid Auto Transfer process request.'
		RETURN;
	END

	BEGIN TRY
		-- TODO: Cancel All
		UPDATE TOP(@totalCust) p WITH(ROWLOCK, UPDLOCK)
		SET p.Result = (SELECT @Creator AS [Creator], @IP AS [IP], p.[Status] AS [CurrentStatus] FOR JSON PATH, WITHOUT_ARRAY_WRAPPER)
			,p.[Status] = 'Cancelled', p.EndTime = CURRENT_TIMESTAMP
		FROM dbo.Age_ClearBalanceCust_Process p 
		INNER JOIN #tmpDownline c ON c.CustId = p.ToCustId
		WHERE p.FromCustId = @FromCustID
		;

	END TRY
	BEGIN CATCH
		SELECT @ErrCode = 102,
				@ErrMsg = ERROR_MESSAGE();
	END CATCH
	
END
GO
