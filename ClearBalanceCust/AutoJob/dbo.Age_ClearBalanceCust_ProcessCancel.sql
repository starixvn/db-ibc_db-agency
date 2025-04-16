/*<info serverAlias="DBSIC-bodb02,DBCTG-bodb02" executers="wsv_alp" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE  [dbo].[Age_ClearBalanceCust_ProcessCancel]
	@FromCustID		INT, 
	@ToCustID		INT,
	@ViewStatus		VARCHAR(15),
	@Creator		INT,
	@Language		VARCHAR(2)= 'E',
	@IP				VARCHAR(45)='',
	@ErrCode		INT = 0 OUTPUT,  
	@ErrMsg			NVARCHAR(4000) = '' OUTPUT
AS  
/*
	Created:20230227@Bobby
	Task: 182071 - Auto Transfer/ Multiple Transfer	
	DB: DBSIC-bodb02,DBCTG-bodb02

	Revisions:
		- 20230227@Bobby: INIT [RedmineID: #182071]
		- 20230822@Bobby: Enhance checking cross level [RedmineID: #193021]
		- 20241118@Max: Alpha - Offer Direct Member for Super/Master [Redmine: #211969]

	Param's Explanation:
		• @FromCustID: S/M/A's custid
		• @ToCustIDs: list M/A/Player custid

*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @currentStatus VARCHAR(15), @effectedRows INT, @RoleID INT;

	DROP TABLE IF EXISTS #tmpDownline;
	CREATE TABLE #tmpDownline(CustId INT PRIMARY KEY);

	INSERT INTO #tmpDownline(CustId)
	SELECT @ToCustID
	;

	SELECT @RoleID = (SELECT TOP 1 RoleID FROM CustDB.dbo.customer WITH (NOLOCK) WHERE custid = @FromCustID);

	STATUS_CHECK:
	SELECT @currentStatus = p.[Status]
	FROM dbo.Age_ClearBalanceCust_Process p WITH(ROWLOCK)
		INNER JOIN #tmpDownline c ON c.CustId = p.ToCustId
		INNER JOIN CustDB.dbo.customer ck WITH (NOLOCK) ON ck.CustId = c.CustId
	WHERE p.FromCustId = @FromCustID
		AND 1 = CASE 
					WHEN @RoleID = 2 AND ck.RoleID = 1 AND ck.recommend = p.FromCustID THEN 1
					WHEN @RoleID = 3 AND ck.RoleID = 2 AND ck.mrecommend = p.FromCustID THEN 1
					WHEN @RoleID = 3 AND ck.roleid = 1 AND ck.recommend = -3 AND ck.mrecommend = p.FromCustId THEN 1
					WHEN @RoleID = 4 AND ck.RoleID = 3 AND ck.srecommend = p.FromCustID THEN 1
					WHEN @RoleID = 4 AND ck.roleid = 1 AND ck.recommend = -4 AND ck.srecommend = p.FromCustId THEN 1
					ELSE 0
				END

	SELECT @ErrCode = 0,
		@ErrMsg		= ''

	IF @ViewStatus NOT IN ('Waiting', 'Processing', 'Pending')
		OR @currentStatus IS NULL
	BEGIN
		SELECT @ErrCode = 101,
				@ErrMsg = 'Invalid Auto Transfer process request.'
		RETURN;
	END

	IF ( @ViewStatus <> @currentStatus)
	BEGIN
		--ERROR: Auto Transfer process status has changed to (Processing|Completed|Failed|Waiting|Pending|Ignored|New). Please refresh the page.
		SELECT @ErrCode = 102,
				@ErrMsg = 
						CASE 
							WHEN @currentStatus IN ('Processing') THEN CustDB.[dbo].[f_Get_MsgNamebyMsgID](50028, @Language) 
							WHEN @currentStatus IN ('Completed') THEN CustDB.[dbo].[f_Get_MsgNamebyMsgID](50029, @Language)
							WHEN @currentStatus IN ('Failed') THEN CustDB.[dbo].[f_Get_MsgNamebyMsgID](50030, @Language)
							WHEN @currentStatus IN ('Pending') THEN CustDB.[dbo].[f_Get_MsgNamebyMsgID](50031, @Language)
							ELSE CustDB.[dbo].[f_Get_MsgNamebyMsgID](50032, @Language)
						END
		RETURN;
	END

	-- TODO: Cancel transfer
	UPDATE TOP(1) p WITH(ROWLOCK, UPDLOCK)
	SET p.[Status] = 'Cancelled', p.EndTime = CURRENT_TIMESTAMP
		,p.Result = (SELECT @Creator AS [Creator], @IP AS [IP], @ViewStatus AS [CurrentStatus] FOR JSON PATH, WITHOUT_ARRAY_WRAPPER)
	FROM dbo.Age_ClearBalanceCust_Process p 
	INNER JOIN #tmpDownline c ON c.CustId = p.ToCustId
	WHERE p.FromCustId = @FromCustID
		AND p.[Status] = @currentStatus
	;
	SET @effectedRows = @@ROWCOUNT;

	IF @effectedRows = 0
		GOTO STATUS_CHECK;

	RETURN
END
GO
