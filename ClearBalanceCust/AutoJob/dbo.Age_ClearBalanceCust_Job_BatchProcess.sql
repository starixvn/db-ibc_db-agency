/*<info serverAlias="DBTXN-bodb02" executers="bodbDownlineNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE  [dbo].[Age_ClearBalanceCust_Job_BatchProcess]
	@BatchNo		INT,
	@FromCustID		INT, 
	@ToCustIDs		VARCHAR(4000),
	@RunningMode	VARCHAR(15) = 'Normal',
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

	DECLARE 
		@SuperId			INT
		, @RoleID			TINYINT
		, @TotalPairCount	INT = 0
		, @TotalPairCheck	INT = 0
		, @SuperCount		INT = 0
		, @RoleCount		INT = 0
		, @FromCustIdCount	INT = 0
		, @Creator			INT = 8 -- StarixIT
		, @IsAllDayBalTransfer	BIT = 1
		, @IsAutoJobTransfer	BIT = 1
		, @BatchLogIdIns		INT;

	SELECT @SuperId		= 0,
		@RoleID			= 0,
		@ErrCode		= 0,
		@ErrMsg			= '';

	DROP TABLE IF EXISTS #tmpProcessCust;
	CREATE TABLE #tmpProcessCust(rIdx INT IDENTITY(1,1), FromCustId INT, ToCustID INT PRIMARY KEY);

	;WITH CTE_Cust (FromCustId, ToCustID) AS (
		SELECT @FromCustID, [value]
		FROM STRING_SPLIT(@ToCustIDs,',') AS t
	)
	INSERT INTO #tmpProcessCust(FromCustId, ToCustID)
	SELECT DISTINCT FromCustId, ToCustID
	FROM CTE_Cust;

	SET @TotalPairCount = @@ROWCOUNT;

	--TODO: Check valid batch
	SELECT @RoleId			= MAX(p.RoleId)
		, @SuperId			= MAX(p.SuperId)
		, @TotalPairCheck	= COUNT(1)
		, @SuperCount		= COUNT(DISTINCT p.SuperId)
		, @RoleCount		= COUNT(DISTINCT p.RoleId)
		, @FromCustIdCount  = COUNT(DISTINCT p.FromCustId)
		, @IsAllDayBalTransfer = p.IsAllDayBalTransfer
	FROM dbo.Age_ClearBalanceCust_Process p WITH(NOLOCK) 
	INNER JOIN #tmpProcessCust ck ON ck.FromCustId = p.FromCustId AND ck.ToCustId = p.ToCustId
	WHERE p.BatchNo = @BatchNo
		AND p.[Status] = 'Waiting'
	GROUP BY IsAllDayBalTransfer;

	IF @RoleCount > 1 OR @SuperCount >  1 OR @FromCustIdCount > 1
		OR @RoleId NOT IN (2,3,4)
		OR @TotalPairCount <> @TotalPairCheck
	BEGIN
		SELECT @ErrCode = 101,
			@ErrMsg = 'INPUT: Invalid batch info.';
		RETURN
	END

	--TODO: Process Transfering
	DECLARE @procName VARCHAR(250), 
		@commandExec NVARCHAR(MAX);
	
	BEGIN TRY
		SELECT @procName = CASE 
							WHEN @RoleID = 2 THEN 'dbo.Age_Transfer_InsClearBalance_Ag'
							WHEN @RoleID = 3 THEN 'dbo.Age_Transfer_Ins_MAg'
							WHEN @RoleID = 4 THEN 'dbo.Age_Transfer_Ins_SAg'
							ELSE 'NA'
						END;
		SELECT @commandExec = CASE 
								WHEN @RoleID = 2 THEN CONCAT('EXEC ', @procName, 
										' @FromCustID=', @FromCustID,
										', @ToCustIDs=''', @ToCustIDs, '''',
										', @Creator=', @Creator,
										', @IsAllDayBalTransfer=', @IsAllDayBalTransfer,
										', @IsAutoTransfer=', @IsAutoJobTransfer
									)

								WHEN @RoleID = 3 THEN CONCAT('EXEC ', @procName, 
										' @MasterID=', @FromCustID,
										', @ToCustIDs=''', @ToCustIDs, '''',
										', @Creator=', @Creator,
										', @FullTransfer=1',
										', @IsAutoTransfer=', @IsAutoJobTransfer
									)
								WHEN @RoleID = 4 THEN CONCAT('EXEC ', @procName, 
										' @SAgID=', @FromCustID,
										', @ToCustIDs=''', @ToCustIDs, '''',
										', @Creator=', @Creator,
										', @FullTransfer=1',
										', @IsAutoTransfer=', @IsAutoJobTransfer
									)
							END
									
	
		INSERT INTO dbo.Age_ClearBalanceCust_BatchLog(BatchNo, SuperId, Command, StartTime, BatchStatus, RunningMode)
		SELECT @BatchNo AS BatchNo
			, @SuperId AS SuperId
			, @commandExec AS Command
			, CURRENT_TIMESTAMP AS StartTime
			, 'Processing' AS BatchStatus
			, @RunningMode AS RunningMode
		;
		SET @BatchLogIdIns = SCOPE_IDENTITY();
	
		UPDATE rs WITH(ROWLOCK, UPDLOCK)
		SET rs.RunningBatchNo = @BatchNo
		FROM dbo.Age_ClearBalanceCust_RunningSuper rs
		WHERE SuperId = @SuperId
		;

		--TODO: EXEC Batch transfering
		SELECT @ErrCode		= 0, 
			@ErrMsg			= ''
		;
		SET @commandExec  = @commandExec + ', @ErrCode = @ErrCode OUTPUT, @ErrMsg=@ErrMsg OUTPUT'
		EXEC sys.sp_executesql @commandExec
			, N'@ErrCode INT OUTPUT, @ErrMsg NVARCHAR(4000) OUTPUT',
			@ErrCode OUTPUT, @ErrMsg OUTPUT
		;
		
		--- Check result
		SELECT TOP(1)
			@ErrCode	= @ErrCode
			,@ErrMsg	= CONCAT('Batch has FAILED. ', @ErrMsg)
		FROM dbo.Age_ClearBalanceCust_Process p WITH(NOLOCK)
		INNER JOIN #tmpProcessCust ck ON ck.FromCustId = p.FromCustId AND ck.ToCustId = p.ToCustId
		WHERE p.BatchNo = @BatchNo AND p.SuperId = @SuperId
			AND p.[Status] <> 'Completed'
		; 

		-- UPDATE Log:
		UPDATE bl WITH(ROWLOCK, UPDLOCK)
		SET bl.BatchStatus = CASE WHEN @ErrCode > 0 THEN 'Failed' ELSE 'Completed' END
			,bl.EndTime = CURRENT_TIMESTAMP
		FROM dbo.Age_ClearBalanceCust_BatchLog bl
		WHERE BatchLogId = @BatchLogIdIns 
			--AND bl.BatchNo = @BatchNo AND bl.SuperId = @SuperId AND RunningMode = @RunningMode
		;

		UPDATE rs WITH(ROWLOCK, UPDLOCK)
		SET rs.RunningBatchNo = 0, RunningTotal = ISNULL(RunningTotal,0) + 1
		FROM dbo.Age_ClearBalanceCust_RunningSuper rs
		WHERE rs.SuperId = @SuperId
		;

	END TRY
	BEGIN CATCH

		SELECT @ErrCode = 102
			,@ErrMsg = ERROR_MESSAGE()
	END CATCH

	--SELECT @ErrCode AS ErrCode, @ErrMsg AS ErrMsg
END
GO