/*<info serverAlias="DBSIC-bodb02" executers="asv_CashService,wsv_CashService" selecters="" viewers="" isFunction="0" isNested=""></info>*/
ALTER PROCEDURE dbo.API_CashDeposit_AddTransaction
(
    @CustID INT,
    @AgentID INT,
    @SubAccID INT = NULL,
	@SiteDBGroupID SMALLINT = 3,
    @AgentGivenCredit MONEY,
    @CreditMembers_GivenCredit MONEY,
	@MinAmt MONEY = 0,
	@MaxAmt MONEY = NULL,
	@TransactionTypeID TINYINT = 1,
	@PaymentType TINYINT = 2,
	@ProviderID	SMALLINT = NULL,
	@PaymentMethodID SMALLINT = 0,
    @PaymentFrom VARCHAR(100) = NULL,
    @PaymentTo VARCHAR(100),
    @Amount MONEY,
	@UserInput_Amount MONEY = NULL,
	@MatchingMode TINYINT = NULL,
    @PaySlip VARBINARY(MAX) = NULL,
    @IP VARCHAR(50) = '',
	@ExchangeRate SMALLMONEY =	1,
    @Remark NVARCHAR(1000) = NULL,
	@ErrCode	INT = 0 OUTPUT,
	@ErrMsg	VARCHAR(2000) = NULL OUTPUT,
	@TransId	BIGINT = NULL OUTPUT,
	@ErrExtraInfo	VARCHAR(MAX) = NULL OUTPUT,
	@CashAccumCreditTbl	VARCHAR(MAX) = NULL OUTPUT
)
AS
/*
	Created: 20250502@Max		
	Task: Alpha - Agency Cash Service [redmine: #223896] 
	DB:  DBSIC-bodb02
		
	Revisions:
		- 20250530@Max: Alpha - Agency Cash Service [redmine: #223896] 
		- 20250610@Eden: API Cash Service Deposit - Lock Agent Credit for Payment Gateway method [redmine: #223896] 
		- 20250624@Eden: Alpha - Agency Cash Service - Sprint 5 [redmine: #223896] 
		- 20250723@Eden: Alpha - Agency Cash Service - Sprint 7 [redmine: #233481] 

	Parameter's Explanation:	
*/ 
BEGIN
    SET NOCOUNT ON;

	DECLARE @TransferRefNo BIGINT
		,@LogData VARCHAR(MAX)
		,@LogDataMask VARCHAR(MAX)
		,@AdjustCreditAmt	MONEY
		,@ExtraInfo NVARCHAR(1000) = NULL
		,@SPNAME		VARCHAR(200)
		,@SubAccName	VARCHAR(30) = ''

	DECLARE @tmp_LogData AS TABLE (
		LogTypeId TINYINT --1: Insert Transfer, 2: Insert/Update CashTransaction, 3: Insert/Update Accumulate Return Credit 
		,UserID	INT
		,CustID	INT
		,ActionID INT
		,TrackingValue	VARCHAR(MAX)
		,TrackingValue2	VARCHAR(MAX)
		,TrackingValueMask	VARCHAR(MAX)
		,TrackingValueMask2	VARCHAR(MAX)
		,FromCustID	INT
		,ToCustID	INT
		,IP	VARCHAR(45)
		,Doing	VARCHAR(1000)
	)
	
	SELECT @SPNAME = OBJECT_NAME(@@PROCID)

    -- Step 1: Validate the input data
	BEGIN TRY
		EXEC dbo.Age_CashDeposit_Validate 
			@CustID = @CustID,
			@UplineID = @AgentID,
			@AgentGivenCredit = @AgentGivenCredit,
			@CreditMembers_GivenCredit = @CreditMembers_GivenCredit,
			@UserInput_Amount = @UserInput_Amount,
			@MatchingMode = @MatchingMode,
			@MinLimitAmt  = @MinAmt,
			@MaxLimitAmt  = @MaxAmt,
			@Amount = @Amount,
			@ErrCode = @ErrCode OUTPUT,
			@ErrMsg = @ErrMsg OUTPUT

		IF @ErrCode <> 0
		BEGIN
			SELECT @ErrExtraInfo = @ErrMsg
				,@ErrCode = CASE WHEN @ErrCode = 407 THEN 407 ELSE 409 END
				,@ErrMsg = CASE WHEN @ErrCode = 407 THEN 'The amount exceeds the allowed minimum or maximum value.'
								ELSE 'The transaction inserted failed. Please try again.' END

			RETURN
		END
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = 409
			,@ErrExtraInfo = ERROR_MESSAGE()
			,@ErrMsg = 'The transaction inserted failed. Please try again.'

		RETURN
	END CATCH

	-- Step 2: Insert cash transaction
	BEGIN TRY
		--Generate extrainfo in case auto deposit via bank
		IF @TransactionTypeID = 2 AND @PaymentType = 2
		BEGIN
			SET @ExtraInfo = (SELECT @UserInput_Amount AS UserInputAmt, @MatchingMode AS MatchingMode FOR JSON PATH, WITHOUT_ARRAY_WRAPPER)
		END
		ELSE IF @TransactionTypeID = 2 AND @PaymentType = 1 --Generate extrainfo in case auto deposit via paymentGateway
		BEGIN
			SELECT @AdjustCreditAmt = @Amount
			SELECT @ExtraInfo = JSON_MODIFY(ISNULL(@ExtraInfo,'{}'), '$.ProviderId',@ProviderID)
		END

		EXEC dbo.Age_CashTransaction_Ins 
			@CustID = @CustID,
			@Creator = @CustID,
			@SubAccID = @SubAccID,
			@SiteDBGroupID = @SiteDBGroupID,
			@TransactionTypeID = @TransactionTypeID,
			@StatusId = 2, --Pending
			@PaymentMethod = @PaymentMethodID,
			@PaymentType = @PaymentType, 
			@PaymentFrom = @PaymentFrom,
			@PaymentTo = @PaymentTo,
			@Amount = @Amount,
			@PaySlip = @PaySlip,
			@Remark = @Remark,
			@AdjustCreditAmt = @AdjustCreditAmt,
			@ExtraInfo = @ExtraInfo,
			@ErrCode = @ErrCode OUTPUT,
			@ErrMsg = @ErrMsg OUTPUT,
			@TransId = @TransId OUTPUT

		IF @ErrCode <> 0
		BEGIN
			SELECT @ErrCode = 409
				,@ErrExtraInfo = @ErrMsg
				,@ErrMsg = 'The transaction inserted failed. Please try again.'

			GOTO ReturnLog;
		END
		ELSE --Insert data for writelog
		BEGIN
			SELECT @LogDataMask = '<R SPName="'+ COALESCE(CAST(@SPName AS VARCHAR(200)), SPACE(1)) + '" ' +
								'custid="'+ COALESCE(CAST(@custid AS VARCHAR(20)), SPACE(1)) + '" ' +
								'UplineID="'+ COALESCE(CAST(@AgentId AS VARCHAR(20)), SPACE(1)) + '" ' +
								'TransactionTypeID="'+ COALESCE(CAST(@TransactionTypeID AS VARCHAR(20)), SPACE(1)) + '" ' +
								'PaymentType="'+ COALESCE(CAST(@PaymentType AS VARCHAR(20)), SPACE(1)) + '" ' +
								'ProviderID="'+ COALESCE(CAST(@ProviderID AS VARCHAR(20)), SPACE(1)) + '" ' +
								'PaymentMethod="'+ COALESCE(CAST(@PaymentMethodID AS VARCHAR(20)), SPACE(1)) + '" ' +
								'PaymentFrom="'+ COALESCE(CAST(@PaymentFrom AS VARCHAR(100)), SPACE(1)) + '" ' +
								'PaymentTo="'+ COALESCE(CAST(@PaymentTo AS VARCHAR(100)), SPACE(1)) + '" ' +
								'Amount="'+ COALESCE(CAST(@Amount AS VARCHAR(50)), SPACE(1)) + '" ' +
								'StatusId="'+ COALESCE(CAST(2 AS VARCHAR(3)), SPACE(1)) + '" ' +
								'TransId="'+ COALESCE(CAST(@TransId AS VARCHAR(20)), SPACE(1)) + '" ' +
								'IP="'+ COALESCE(CAST(@IP AS VARCHAR(50)), SPACE(1)) + '" />'

			SELECT @LogData = REPLACE (REPLACE (@LogDataMask, ISNULL(@PaymentFrom,''),''),ISNULL(@PaymentTo,''),'')

			INSERT INTO @tmp_LogData (LogTypeId, UserID, CustID, ActionID, TrackingValue,TrackingValueMask)
			SELECT 2, @CustID, @CustID, NULL, @LogData, @LogDataMask
		END
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = 409
			,@ErrExtraInfo = ERROR_MESSAGE()
			,@ErrMsg = 'The transaction inserted failed. Please try again.'

		GOTO ReturnLog;
	END CATCH

	-- Step 3: Adjust accumulated credit
	BEGIN TRY
		-- Auto Deposit via Payment Gateway
		IF @TransactionTypeID = 2 AND @PaymentType = 1
		BEGIN
			EXEC dbo.Age_CashAccumulatedCredit_Adjust 
				@CustID = @CustID,
				@ActionType = 1, --Deposit
				@Amount = @Amount,
				@ErrCode = @ErrCode OUTPUT,
				@ErrMsg	= @ErrMsg OUTPUT,
				@CashAccumCreditTbl	= @CashAccumCreditTbl OUTPUT,
				@AdjustCreditAmt = @AdjustCreditAmt OUTPUT

			IF @ErrCode <> 0
			BEGIN
				SELECT @ErrCode = 409
					,@ErrExtraInfo = @ErrMsg
					,@ErrMsg = 'The transaction inserted failed. Please try again.'

				EXEC dbo.Age_CashService_Balance_Rollback
					@Type = 3,
					@TransId = @TransId,
					@Custid = @CustID,
					@AdjustCreditAmt = @AdjustCreditAmt,
					@CashAccumCreditTbl	= @CashAccumCreditTbl OUTPUT

				GOTO ReturnLog;
			END
			ELSE --Insert data for writelog
			BEGIN
				SELECT @LogData = '<R SPName="'+ COALESCE(CAST(@SPName AS VARCHAR(200)), SPACE(1)) + '" ' +
									'custid="'+ COALESCE(CAST(@custid AS VARCHAR(20)), SPACE(1)) + '" ' +
									'ActionType="'+ COALESCE(CAST(1 AS VARCHAR(20)), SPACE(1)) + '" ' +
									'Amount="'+ COALESCE(CAST(@Amount AS VARCHAR(100)), SPACE(1)) + '" ' +
									'AdjustCreditAmt="'+ COALESCE(CAST(@AdjustCreditAmt AS VARCHAR(100)), SPACE(1))  + '" ' +
									'TransId="'+ COALESCE(CAST(@TransId AS VARCHAR(20)), SPACE(1)) + '" ' +
									'IP="'+ COALESCE(CAST(@IP AS VARCHAR(50)), SPACE(1)) + '" />'

				INSERT INTO @tmp_LogData (LogTypeId, UserID, CustID, ActionID, TrackingValue)
				SELECT 3, @CustID, @CustID, NULL, @LogData
			END
		END
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = 409
			,@ErrExtraInfo = ERROR_MESSAGE()
			,@ErrMsg = 'The transaction inserted failed. Please try again.'

		EXEC dbo.Age_CashService_Balance_Rollback
				@Type = 3,
				@TransId = @TransId,
				@Custid = @CustID,
				@AdjustCreditAmt = @AdjustCreditAmt,
				@CashAccumCreditTbl	= @CashAccumCreditTbl OUTPUT

		GOTO ReturnLog;
	END CATCH

	-------LOG-------------
	--Insert Deposit transaction
	SELECT @LogDataMask = '<R custid="'+ COALESCE(CAST(@custid AS VARCHAR(20)), SPACE(1)) + '" ' +
						'UplineID="'+ COALESCE(CAST(@AgentId AS VARCHAR(20)), SPACE(1)) + '" ' +
						'TransactionTypeID="'+ COALESCE(CAST(@TransactionTypeID AS VARCHAR(20)), SPACE(1)) + '" ' +
						'PaymentType="'+ COALESCE(CAST(@PaymentType AS VARCHAR(20)), SPACE(1)) + '" ' +
						'ProviderID="'+ COALESCE(CAST(@ProviderID AS VARCHAR(20)), SPACE(1)) + '" ' +
						'PaymentMethod="'+ COALESCE(CAST(@PaymentMethodID AS VARCHAR(20)), SPACE(1)) + '" ' +
						'PaymentFrom="'+ COALESCE(CAST(@PaymentFrom AS VARCHAR(100)), SPACE(1)) + '" ' +
						'PaymentTo="'+ COALESCE(CAST(@PaymentTo AS VARCHAR(100)), SPACE(1)) + '" ' +
						'Amount="'+ COALESCE(CAST(@Amount AS VARCHAR(50)), SPACE(1)) + '" ' +
						'AdjustCreditAmt="'+ COALESCE(CAST(@AdjustCreditAmt AS VARCHAR(100)), SPACE(1))  + '" ' +
						'StatusId="'+ COALESCE(CAST(2 AS VARCHAR(3)), SPACE(1)) + '" ' +
						'TransId="'+ COALESCE(CAST(@TransId AS VARCHAR(20)), SPACE(1)) + '" ' +
						'IP="'+ COALESCE(CAST(@IP AS VARCHAR(50)), SPACE(1)) + '" />'

	SELECT @LogData = REPLACE (REPLACE (@LogDataMask, ISNULL(@PaymentFrom,''),''),ISNULL(@PaymentTo,''),'')

	INSERT INTO @tmp_LogData (LogTypeId, UserID, CustID, ActionID, TrackingValue,TrackingValueMask)
	SELECT 2, @CustID, @CustID, 310005, @LogData, @LogDataMask

	ReturnLog:
	SELECT *
	FROM @tmp_LogData t

    SET NOCOUNT OFF;
END;