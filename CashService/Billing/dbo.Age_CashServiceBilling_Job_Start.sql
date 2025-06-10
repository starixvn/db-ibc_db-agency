/*<info serverAlias="DBSIC-bodb02" executers="wsv_CashService" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE  [dbo].[Age_CashServiceBilling_Job_Start]
	@AgentList		NVARCHAR(MAX), -- JSON input for agent list
	@ErrCode		INT = 0 OUTPUT,
	@ErrMsg			NVARCHAR(4000) = '' OUTPUT
AS
/*
  Created: 20250526@Bobby
  Task: Implement daily fee and free period records for agents
  DB: DBSIC-bodb02
  
  Revisions:
    - 20250526@Bobby: Initial [RedmineID: #227215]

  Description:
    - @AgentList: JSON([{"AgentId":1176086,"StartTime":"2025-05-22","TrialEndTime":"2025-06-04","ServiceType":0}])
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE 
		@CashBilling_VName		VARCHAR(50),
		@CashBilling_Config		VARCHAR(1000),
		@CashBilling_StartTime	DATETIME,
		@ChkExisting			BIT = 0 -- Flag to check if the job is already running
	;

	SELECT @CashBilling_StartTime = CURRENT_TIMESTAMP,
			@ErrCode				= 0,
			@ErrMsg					= '',
			@CashBilling_VName		= 'Age_CashServiceBilling_Job'
	;
	-- Get the configuration value for the cash billing job
	SELECT TOP(1)
		@CashBilling_Config = VValue, @ChkExisting = 1
	FROM dbo.SystemSettings (NOLOCK)
	WHERE VName = @CashBilling_VName
	;

	-- Update StartTime in JSON format to VValue
	IF @ChkExisting = 0
	BEGIN
		SET @CashBilling_Config = JSON_MODIFY(ISNULL(@CashBilling_Config, '{}'), '$.StartTime', FORMAT(@CashBilling_StartTime, 'yyyy-MM-ddTHH:mm:ss'));
		INSERT INTO dbo.SystemSettings (VName, VValue)
		VALUES (@CashBilling_VName, @CashBilling_Config);	
	END
	ELSE
	BEGIN
		SET @CashBilling_Config = JSON_MODIFY(ISNULL(@CashBilling_Config, '{}'), '$.StartTime', FORMAT(@CashBilling_StartTime, 'yyyy-MM-ddTHH:mm:ss'));
		UPDATE TOP(1) s
		SET s.VValue = @CashBilling_Config
		FROM dbo.SystemSettings s WITH (ROWLOCK, UPDLOCK)
		WHERE s.VName = @CashBilling_VName;
	END

	DECLARE 
		@TotalInputCount		INT,
		@TotalAgentCount 		INT,
		@TotalOthers 			INT,
		@SiteDBGroupID			SMALLINT = 0, -- SiteDBGroupID for the current session
		@Today					SMALLDATETIME -- Current date without time
	;

	SELECT @SiteDBGroupID	= [dbo].[f_Get_SiteDBGroupID](),
		@Today				=  CAST(GETDATE() AS DATE)
	;

	-- Parse @AgentList JSON into @tmpAgent table
	-- [{'AgentId': 1, 'TrialEndTime': 'yyyy-MM-DD'}]
	DROP TABLE IF EXISTS #tmpAgent;
	CREATE TABLE #tmpAgent (
		AgentId INT PRIMARY KEY,
		StartTime SMALLDATETIME,
		TrialEndTime SMALLDATETIME,
		ServiceType TINYINT,
		RowNum INT IDENTITY(1,1)
	);

	INSERT INTO #tmpAgent (AgentId, StartTime, TrialEndTime, ServiceType)
	SELECT 
		TRY_CAST(JSON_VALUE([value], '$.AgentId') AS INT) AS AgentId,
		TRY_CAST(JSON_VALUE([value], '$.StartTime') AS SMALLDATETIME) AS StartTime,
		TRY_CAST(JSON_VALUE([value], '$.TrialEndTime') AS SMALLDATETIME) AS TrialEndTime,
		TRY_CAST(JSON_VALUE([value], '$.ServiceType') AS TINYINT) AS ServiceType
	FROM OPENJSON(@AgentList)
	;SET @TotalInputCount = @@ROWCOUNT;

	SELECT 
		@TotalAgentCount 	= SUM(IIF(roleId = 2 , 1, 0)),
		@TotalOthers 		= SUM(IIF(roleId <> 2 , 1, 0))
	FROM #tmpAgent t
	INNER JOIN CustDB.dbo.vw_CashService_Customer c (NOLOCK) ON t.AgentId = c.custid
	INNER JOIN CustDB.dbo.[site] s (NOLOCK) ON c.[site] = s.[site]
	WHERE t.AgentId > 0
		AND s.SiteDBGroupID = @SiteDBGroupID

	IF @TotalAgentCount = 0 
		OR @TotalOthers > 0
		OR @TotalInputCount <> @TotalAgentCount
	BEGIN
		SELECT @ErrCode = 100
			,@ErrMsg	= 'No valid agent data found in the input list.'
		RETURN
	END

	-- TODO: Issue Cash Service Fees & Free Periods
	DECLARE @AgentId 	INT, 
		@TrialEndTime 	SMALLDATETIME,
		@ServiceType 	TINYINT,
		@Row 			INT = 1

	WHILE EXISTS (SELECT 1 FROM #tmpAgent WHERE RowNum = @Row)
	BEGIN
		SELECT @ErrCode		= 0,
				@ErrMsg		= ''

		SELECT 
			@AgentId 		= AgentId,
			@TrialEndTime 	= TrialEndTime,
			@ServiceType 	= ServiceType
		FROM #tmpAgent
		WHERE RowNum = @Row;

		--Cash Service Fees
		IF @ServiceType = 1
		BEGIN
			EXEC dbo.Age_CashServiceBilling_DailyFee_Ins 
				@CustId			= @AgentId,
				@TrialEndTime	= @TrialEndTime,
				@ErrCode		= @ErrCode OUTPUT,
				@ErrMsg			= @ErrMsg OUTPUT;

			IF @ErrCode > 110 -- DB error code for cash service fee processing
			BEGIN
				-- If there is an error, log it and exit the loop
				SELECT @ErrMsg = 'Error processing Service Fees AgentId: ' + CAST(@AgentId AS NVARCHAR(10)) + ' - ' + @ErrMsg;
				RETURN;
			END
		END

		SET @Row = @Row + 1
	END

	/**********************************************************
		- Cash Transaction Fees
		- Initialize variables for transaction fee processing
	***********************************************************/
	DECLARE @Yesterday	SMALLDATETIME;
	SELECT @Yesterday 	= DATEADD(DAY, -1, @Today); 

	-- Create temp table to store transaction fee summary
	DECLARE 
		@FeeRow INT = 1,
		@FeeRowCount INT
	;

	DECLARE @AgentCashFees TABLE (
		RowNum INT IDENTITY(1,1) PRIMARY KEY,
		AgentId INT
	);

	INSERT INTO @AgentCashFees(AgentId)
	SELECT 
		ci.recommend AS AgentId
	FROM dbo.[CashTransaction] ct WITH (NOLOCK)
	INNER JOIN CustDB.dbo.vw_CashService_Customer ci (NOLOCK) ON ci.custid = ct.CustId
	WHERE 
		ct.OperatedTime >= @Yesterday AND ct.OperatedTime < @Today
		AND ct.statusID = 4 -- Only consider successful transactions
		AND ct.PaymentType = 2 -- Only consider bank transactions
		AND ct.TransactionTypeID IN (1, 2, 3) -- Only consider deposits and withdrawals
		AND TRY_CAST(JSON_VALUE(ct.ExtraInfo, '$.ChargedAt') AS SMALLDATETIME) IS NULL
	GROUP BY ci.recommend
	HAVING COUNT(1) > 0
	;SET @FeeRowCount = @@ROWCOUNT;
	
	-- Insert transaction fee summary into the temp table
	SET @FeeRow = 1;
	WHILE @FeeRow <= @FeeRowCount
	BEGIN
		SELECT @AgentId		= 0,
			@ErrCode 		= 0,
			@ErrMsg 		= ''

		SELECT 
			@AgentId		= AgentId
		FROM @AgentCashFees
		WHERE RowNum = @FeeRow;

		-- Call your fee processing procedure here, for example:
		EXEC dbo.Age_CashServiceBilling_DailyTransFee_Ins 
			@custid			= @AgentId,
			@ChargeDate		= @Today,
			@ErrCode		= @ErrCode OUTPUT,
			@ErrMsg			= @ErrMsg OUTPUT;

		IF @ErrCode > 110 -- DB error code for cash transaction fee processing
		BEGIN
			SELECT @ErrMsg = 'Error processing Transaction Fees AgentId: ' + CAST(@AgentId AS NVARCHAR(10)) + ' - ' + @ErrMsg;
			RETURN;
		END

		SET @FeeRow = @FeeRow + 1;
	END


	-- Update the EndTime in the SystemSettings table
	BEGIN
		UPDATE TOP(1) s
		SET s.VValue = JSON_MODIFY(ISNULL(s.VValue, '{}'), '$.EndTime', FORMAT(GETDATE(), 'yyyy-MM-ddTHH:mm:ss'))
		FROM dbo.SystemSettings s WITH (ROWLOCK, UPDLOCK)
		WHERE s.VName = @CashBilling_VName;
	END
END
GO