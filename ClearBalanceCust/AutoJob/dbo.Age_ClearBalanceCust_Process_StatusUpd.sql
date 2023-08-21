/*<info serverAlias="DBCTG-bodb02,DBSIC-bodb02" executers="" isFunction="0" isNested="0"></info>*/
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
	DB: DBSIC-bodb02,DBCTG-bodb02

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
		UPDATE p WITH(ROWLOCK, UPDLOCK)
		SET	p.Status		= @Status
			,p.StartTime	= IIF(p.StartTime IS NULL, CURRENT_TIMESTAMP, p.StartTime)
			,p.Amount		= ISNULL(@Amount, p.Amount)
			,p.ModifiedTime = CURRENT_TIMESTAMP
		FROM dbo.Age_ClearBalanceCust_Process p
		INNER JOIN #tmpDownline c ON c.CustId = p.ToCustId
		WHERE p.FromCustId = @FromCustID
			AND p.[Status] IN ('Waiting', 'Processing')
		;

		SET @effectedRows = @@ROWCOUNT;
	END
	ELSE IF @Status IN ('Failed', 'Completed')
	BEGIN
		UPDATE p WITH(ROWLOCK, UPDLOCK)
		SET	p.Status = @Status
			,p.EndTime = CURRENT_TIMESTAMP
			,p.Result = @Result
		FROM dbo.Age_ClearBalanceCust_Process p
		INNER JOIN #tmpDownline c ON c.CustId = p.ToCustId
		WHERE p.FromCustId = @FromCustID
			AND p.[Status] <> 'Cancelled';

		SET @effectedRows = @@ROWCOUNT;
	END
	ELSE IF @Status IN ('Pending', 'Ignored')
	BEGIN
		UPDATE p WITH(ROWLOCK, UPDLOCK)
		SET	p.[Status] = IIF(ck.IsReachPending = 1, 'Failed', @Status)
			,p.ModifiedTime = IIF(ck.IsReachPending = 0, CURRENT_TIMESTAMP, p.ModifiedTime)
			,p.EndTime = IIF(ck.IsReachPending = 1, CURRENT_TIMESTAMP, p.EndTime)
			,p.Result = @Result
		FROM dbo.Age_ClearBalanceCust_Process p
		INNER JOIN #tmpDownline c ON c.CustId = p.ToCustId
			OUTER APPLY ( 
				SELECT 
					CASE WHEN @Status = 'Pending' AND p.TryCount = 60 THEN 1 ELSE 0 END AS IsReachPending
			) AS ck
		WHERE p.FromCustId = @FromCustID
			AND p.[Status] = 'Waiting';

		SET @effectedRows = @@ROWCOUNT;
	END

	IF @effectedRows = 0
	BEGIN
		-- Re-New/Cancelled
		SELECT @ErrCode = 50032
			, @ErrMsg = CustDB.[dbo].[f_Get_MsgNamebyMsgID](50032, 'E')
	END
END
GO
