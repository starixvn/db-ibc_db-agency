/*<info serverAlias="DBTXN-bodb02" executers="" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE  [dbo].[Age_ClearBalanceCust_ProcessCancel]
	@FromCustID		INT, 
	@ToCustID		INT,
	@ViewStatus		VARCHAR(15),
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

	IF @ViewStatus <> @currentStatus
	BEGIN
		SELECT @ErrCode = 101,
				@ErrMsg = CASE 
							WHEN @ViewStatus = 'Waiting' AND @currentStatus IN ('Processing') THEN 'Status change from Waiting to Processing'
							WHEN @ViewStatus = 'Waiting' AND @currentStatus IN ('Completed') THEN 'Status change to Completed'
							WHEN @ViewStatus = 'Waiting' AND @currentStatus IN ('Failed') THEN 'Status change to Failed'
							WHEN @ViewStatus = 'Processing' AND @currentStatus IN ('Completed') THEN 'Status change to Completed'
							WHEN @ViewStatus = 'Processing' AND @currentStatus IN ('Failed') THEN 'Status change to Failed'
							ELSE ''
						END
		RETURN
	END

	-- TODO: Cancel transfer
	UPDATE TOP(1) p WITH(ROWLOCK, UPDLOCK)
	SET p.[Status] = 'Cancelled', p.ModifiedTime = CURRENT_TIMESTAMP
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
