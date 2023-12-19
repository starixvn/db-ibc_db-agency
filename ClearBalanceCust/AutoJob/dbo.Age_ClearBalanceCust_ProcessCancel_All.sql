/*<info serverAlias="DBSIC-bodb02,DBCTG-bodb02" executers="bodbDownlineNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE  [dbo].[Age_ClearBalanceCust_ProcessCancel_All]
	@FromCustId		INT, 
	@Creator		INT,
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
		@UplineId		INT
	;

	SELECT @UplineId	= @FromCustId;

	DROP TABLE IF EXISTS #tmpDownline;
	CREATE TABLE #tmpDownline(CustId INT PRIMARY KEY);

	SELECT @RoleID = (SELECT TOP 1 RoleID FROM CustDB.dbo.customer WITH (NOLOCK) WHERE custid = @UplineId);

	--TODO: Search for canceling
	INSERT INTO #tmpDownline(CustId)
	SELECT p.ToCustID
	FROM bodb02.dbo.Age_ClearBalanceCust_Process p WITH(NOLOCK)
	WHERE p.FromCustId = @FromCustId
		AND p.[Status] IN ('Waiting', 'Processing', 'Pending') 
		AND DATEDIFF(MINUTE, p.ModifiedTime, CURRENT_TIMESTAMP) >= 15
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
