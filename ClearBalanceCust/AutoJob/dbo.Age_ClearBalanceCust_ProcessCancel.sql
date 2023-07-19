/*<info serverAlias="DBTXN-bodb02" executers="bodbDownlineNet" isFunction="0" isNested="0"></info>*/
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
	Created:20230227@bobby
	Task: 182071 - Auto Transfer/ Multiple Transfer	
	DB: DBTXN/bodb02

	Revisions:
		- 20230227@bobby: INIT [RedmineID: #182071]

	Param's Explanation:
		• @FromCustID: S/M/A's custid
		• @ToCustIDs: list M/A/Player custid

*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @currentStatus VARCHAR(15), @effectedRows INT;

	DROP TABLE IF EXISTS #tmpDownline;
	CREATE TABLE #tmpDownline(CustId INT PRIMARY KEY);

	INSERT INTO #tmpDownline(CustId)
	SELECT @ToCustID
	;

	STATUS_CHECK:
	SELECT @currentStatus = p.[Status]
	FROM dbo.Age_ClearBalanceCust_Process p WITH(ROWLOCK)
	INNER JOIN #tmpDownline c ON c.CustId = p.ToCustId
	WHERE p.FromCustId = @FromCustID

	SELECT @ErrCode = 0,
		@ErrMsg		= ''

	IF @ViewStatus NOT IN ('Waiting', 'Processing', 'Pending')
	BEGIN
		SELECT @ErrCode = 101,
				@ErrMsg = 'Invalid Auto Transfer process status.'
		RETURN;
	END

	IF ( @ViewStatus <> @currentStatus)
	BEGIN
		--ERROR: Auto Transfer process status has changed to (Processing|Completed|Failed|Waiting|Pending). Please refresh the page.
		SELECT @ErrCode = 102,
				@ErrMsg = 
						CASE 
							WHEN @currentStatus IN ('Processing') THEN CustDB.[dbo].[f_Get_MsgNamebyMsgID](50028, @Language) 
							WHEN @currentStatus IN ('Completed') THEN CustDB.[dbo].[f_Get_MsgNamebyMsgID](50029, @Language)
							WHEN @currentStatus IN ('Failed') THEN CustDB.[dbo].[f_Get_MsgNamebyMsgID](50030, @Language)
							WHEN @currentStatus IN ('Waiting') THEN CustDB.[dbo].[f_Get_MsgNamebyMsgID](50031, @Language)
							WHEN @currentStatus IN ('Pending') THEN CustDB.[dbo].[f_Get_MsgNamebyMsgID](50032, @Language)
							ELSE 'Unknown Auto Transfer process status.'
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
		AND p.[Status] = @ViewStatus
	;
	SET @effectedRows = @@ROWCOUNT;

	IF @effectedRows = 0
		GOTO STATUS_CHECK;

	RETURN
END
GO
