/*<info serverAlias="DBTXN-bodb02" executers="" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE  [dbo].[Age_ClearBalanceCust_Process_StatusUpd]
	@FromCustID		INT, 
	@ToCustIDs		VARCHAR(4000),
	@Status			VARCHAR(15),
	@Amount			MONEY = NULL,
	@Result			NVARCHAR(4000) = '',
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
	SELECT DISTINCT [Value]
	FROM STRING_SPLIT(@ToCustIDs, ',');

	SELECT @ErrCode = 0,
		@ErrMsg		= ''
	;

	IF @Status IN ('Processing')
	BEGIN
		IF (ISNULL(@Amount,0)  = 0)
		BEGIN
			UPDATE p WITH(ROWLOCK, UPDLOCK)
			SET	p.Status = @Status
				,p.ModifiedTime = CURRENT_TIMESTAMP, p.StartTime = CURRENT_TIMESTAMP
			FROM dbo.Age_ClearBalanceCust_Process p
			INNER JOIN #tmpDownline c ON c.CustId = p.ToCustId
			WHERE p.FromCustId = @FromCustID
				AND p.[Status] = 'Waiting'
			;
			SET @effectedRows = @@ROWCOUNT;
		END
		ELSE IF (ISNULL(@Amount,0)  <> 0)
		BEGIN
			UPDATE p WITH(ROWLOCK, UPDLOCK)
			SET	p.Amount = @Amount
				,p.ModifiedTime = CURRENT_TIMESTAMP
			FROM dbo.Age_ClearBalanceCust_Process p
			INNER JOIN #tmpDownline c ON c.CustId = p.ToCustId
			WHERE p.FromCustId = @FromCustID
				AND p.[Status] = 'Processing'
			;
			SET @effectedRows = @@ROWCOUNT;
		END

		IF @effectedRows = 0
		BEGIN
			SELECT @currentStatus = p.[Status]
			FROM dbo.Age_ClearBalanceCust_Process p WITH(ROWLOCK)
			INNER JOIN #tmpDownline c ON c.CustId = p.ToCustId
			WHERE p.FromCustId = @FromCustID

			-- Re-New/Cancelled
			SELECT @ErrCode = 101
				, @ErrMsg = 'This transfer''s status has been changed to ' + @currentStatus + '.'
			RETURN
		END

	END
	ELSE IF @Status IN ('Failed', 'Completed')
	BEGIN
		UPDATE p WITH(ROWLOCK, UPDLOCK)
		SET	p.Status = @Status
			,p.ModifiedTime = CURRENT_TIMESTAMP, p.EndTime = CASE WHEN p.StartTime IS NOT NULL THEN CURRENT_TIMESTAMP ELSE NULL END
			,p.Result = @Result
		FROM dbo.Age_ClearBalanceCust_Process p
		INNER JOIN #tmpDownline c ON c.CustId = p.ToCustId
		WHERE p.FromCustId = @FromCustID
			AND p.[Status] <> 'Cancelled'
	END
END
GO
