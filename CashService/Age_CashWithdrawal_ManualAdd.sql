/*<info serverAlias="DBSIC-bodb02" executers="asv_CashService,wsv_CashService" selecters="" viewers="" isFunction="0" isNested=""></info>*/
ALTER PROCEDURE dbo.Age_CashWithdrawal_ManualAdd
(
    @CustID INT,
    @UplineID INT,
    @SubAccID INT = NULL,
	@SiteDBGroupID SMALLINT = 3,
    @WithdrawalLimitCnt INT = NULL,
    @MinLimitAmt MONEY,
    @MaxLimitAmt MONEY,
    @PaymentFrom VARCHAR(100),
    @PaymentTo VARCHAR(100),
    @Amount MONEY,
    @PaySlip VARBINARY(MAX) = NULL,
    @IP VARCHAR(50) = '',
	@ProviderID SMALLINT = 0,
	@PaymentMethodID SMALLINT = NULL,
	@ExchangeRate SMALLMONEY =	1,
    @Remark NVARCHAR(1000) = NULL,
	@ErrCode	INT = 0 OUTPUT,
	@ErrMsg	VARCHAR(2000) = NULL OUTPUT,
	@TransId	BIGINT = NULL OUTPUT,
	@CashAccumCreditTbl	VARCHAR(MAX) = NULL OUTPUT
)
AS
/*
	Created: 20250502@Max		
	Task: Alpha - Agency Cash Service [redmine: #223896] 
	DB:  DBSIC-bodb02
		
	Revisions:
		- 20250502@Max: Alpha - Agency Cash Service [redmine: #223896] 
		- 20250603@Max: Alpha - Agency Cash Service - Sprint 3 [redmine: #223896] 
		- 20250611@Max: Alpha - Agency Cash Service - Sprint 4 [redmine: #223896] 
		- 20250624@Eden: Alpha - Agency Cash Service - Sprint 5 [redmine: #223896] 

	Parameter's Explanation:	
*/ 
BEGIN
    SET NOCOUNT ON;

	DECLARE @TransferRefNo BIGINT
		,@LogData VARCHAR(MAX)
		,@LogDataMask VARCHAR(MAX)
		,@AdjustCreditAmt	MONEY
		,@PaymentType TINYINT 
		,@TransId_From	BIGINT = NULL
		,@TransId_To	BIGINT = NULL

	IF @ProviderID <> 0 
		SET @PaymentType = 1 -- Payment Gateway
	ELSE
		SET @PaymentType = 2 --Bank Account

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

    -- Step 1: Validate the input data
	BEGIN TRY
		EXEC dbo.Age_CashWithdrawal_Validate 
			@CustID = @CustID,
			@UplineID = @UplineID,
			@MinLimitAmt = @MinLimitAmt,
			@MaxLimitAmt = @MaxLimitAmt,
			@Amount = @Amount,
			@ErrCode = @ErrCode OUTPUT,
			@ErrMsg = @ErrMsg OUTPUT

		IF @ErrCode <> 0
		BEGIN
			RETURN
		END
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = ERROR_NUMBER()
			,@ErrMsg = ERROR_MESSAGE()

		RETURN
	END CATCH

	-- Step 2: Insert cash transaction
	BEGIN TRY
		EXEC dbo.Age_CashTransaction_Ins 
			@CustID = @CustID,
			@Creator = @UplineID,
			@SubAccID = @SubAccID,
			@SiteDBGroupID = @SiteDBGroupID,
			@TransactionTypeID = 3, --Manual Withdrawal
			@StatusId = 2, --Pending
			@OperatedBy = @UplineID,
			@PaymentType = @PaymentType,
			@PaymentMethod = @PaymentMethodID,
			@PaymentFrom = @PaymentFrom,
			@PaymentTo = @PaymentTo,
			@Amount = @Amount,
			@PaySlip = @PaySlip,
			@Remark = @Remark,
			@ErrCode = @ErrCode OUTPUT,
			@ErrMsg = @ErrMsg OUTPUT,
			@TransId = @TransId OUTPUT

		IF @ErrCode <> 0
		BEGIN
			GOTO Writelog;
		END
		ELSE --Insert data for writelog
		BEGIN
			SELECT @LogDataMask = '<R custid="'+ COALESCE(CAST(@custid AS VARCHAR(20)), SPACE(1)) + '" ' +
								'UplineID="'+ COALESCE(CAST(@UplineID AS VARCHAR(20)), SPACE(1)) + '" ' +
								'SubAccID="'+ COALESCE(CAST(@SubAccID AS VARCHAR(20)), SPACE(1)) + '" ' +
								'TransactionTypeID="'+ COALESCE(CAST(3 AS VARCHAR(20)), SPACE(1)) + '" ' +
								'PaymentType="'+ COALESCE(CAST(@PaymentType AS VARCHAR(20)), SPACE(1)) + '" ' +
								'PaymentFrom="'+ COALESCE(CAST(@PaymentFrom AS VARCHAR(100)), SPACE(1)) + '" ' +
								'PaymentTo="'+ COALESCE(CAST(@PaymentTo AS VARCHAR(100)), SPACE(1)) + '" ' +
								'Amount="'+ COALESCE(CAST(@Amount AS VARCHAR(50)), SPACE(1)) + '" ' +
								'StatusId="'+ COALESCE(CAST(2 AS VARCHAR(3)), SPACE(1)) + '" />'

			SELECT @LogData = REPLACE (REPLACE (@LogDataMask, ISNULL(@PaymentFrom,''),''),ISNULL(@PaymentTo,''),'')

			INSERT INTO @tmp_LogData (LogTypeId, UserID, CustID, ActionID, TrackingValue,TrackingValueMask)
			SELECT 2, @UplineID, @CustID, 310004, @LogData, @LogDataMask
		END
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = ERROR_NUMBER()
			,@ErrMsg = ERROR_MESSAGE()

		GOTO Writelog;
	END CATCH

    -- Step 2: Insert transfer details
	BEGIN TRY
		EXEC dbo.Age_CashWithdrawal_ManualAdd_InsTransfer 
			@CustID = @CustID,
			@UplineID = @UplineID,
			@Amount = @Amount,
			@ExchangeRate = @ExchangeRate,
			@IP = @IP,
			@ErrCode = @ErrCode OUTPUT,
			@ErrMsg = @ErrMsg OUTPUT,
			@TransferRefNo = @TransferRefNo OUTPUT,
			@TransId_From = @TransId_From OUTPUT,
			@TransId_To = @TransId_To OUTPUT

		IF @ErrCode <> 0
		BEGIN
			--Rollback CashTransaction
			EXEC dbo.Age_CashService_Balance_Rollback
				@Type = 2,
				@TransId = @TransId

			GOTO Writelog;
		END
		ELSE --Insert data for writelog
		BEGIN
			SELECT @LogData = 'Insert trans custid = ' + CONVERT(VARCHAR(20), @custid) + ', bettype = ' + CONVERT(VARCHAR(20), 31002) + ', amount = ' + CONVERT(VARCHAR(20), @amount) + ', Ref.No: ' + CONVERT(VARCHAR(20), @TransferRefNo)

			INSERT INTO @tmp_LogData (LogTypeId, UserID, FromCustID, ToCustID, IP, Doing)
			SELECT 1, @UplineID, @UplineID, @CustID, @IP, @LogData
		END
	END TRY
	BEGIN CATCH
		--Rollback CashTransaction
		EXEC dbo.Age_CashService_Balance_Rollback
				@Type = 2,
				@TransId = @TransId

		SELECT @ErrCode = ERROR_NUMBER()
			,@ErrMsg = ERROR_MESSAGE()

		GOTO Writelog;
	END CATCH

    -- Step 4: Adjust accumulated credit
	BEGIN TRY
		EXEC dbo.Age_CashAccumulatedCredit_Adjust 
			@CustID = @CustID,
			@ActionType = 2, --withdrawal
			@Amount = @Amount,
			@ErrCode = @ErrCode OUTPUT,
			@ErrMsg	= @ErrMsg OUTPUT,
			@CashAccumCreditTbl	= @CashAccumCreditTbl OUTPUT,
			@AdjustCreditAmt = @AdjustCreditAmt OUTPUT

		IF @ErrCode <> 0
		BEGIN
			--Rollback CashTransaction & Transfer
			EXEC dbo.Age_CashService_Balance_Rollback
				@Type = 2,
				@TransId = @TransId,
				@Custid = @CustID,
				@TransId_From = @TransId_From,
				@TransId_To = @TransId_To,
				@TransferAmount = @Amount

			GOTO Writelog;
		END
		ELSE --Insert data for writelog
		BEGIN
			SELECT @LogData = '<R custid="'+ COALESCE(CAST(@custid AS VARCHAR(20)), SPACE(1)) + '" ' +
								'ActionType="'+ COALESCE(CAST(2 AS VARCHAR(20)), SPACE(1)) + '" ' +
								'Amount="'+ COALESCE(CAST(@Amount AS VARCHAR(100)), SPACE(1)) + '" ' +
								'AdjustCreditAmt="'+ COALESCE(CAST(@AdjustCreditAmt AS VARCHAR(100)), SPACE(1)) + '" />'

			INSERT INTO @tmp_LogData (LogTypeId, UserID, CustID, ActionID, TrackingValue)
			SELECT 3, @UplineID, @CustID, 310005, @LogData
		END
	END TRY
	BEGIN CATCH
		--Rollback CashTransaction & Transfer
		EXEC dbo.Age_CashService_Balance_Rollback
			@Type = 2,
			@TransId = @TransId,
			@Custid = @CustID,
			@TransId_From = @TransId_From,
			@TransId_To = @TransId_To,
			@TransferAmount = @Amount

		SELECT @ErrCode = ERROR_NUMBER()
			,@ErrMsg = ERROR_MESSAGE()

		GOTO Writelog;
	END CATCH

    -- Step 5: Update cash transaction
	BEGIN TRY
		EXEC dbo.Age_CashTransaction_Upd 
			@TransId = @TransId,
			@AdjustCreditAmt = @AdjustCreditAmt,
			@StatusId = 4, --completed
			@TransferRefNo = @TransferRefNo,
			@ErrCode = @ErrCode OUTPUT,
			@ErrMsg = @ErrMsg OUTPUT

		IF @ErrCode <> 0
		BEGIN
			--Rollback CashTransaction & Transfer & CashAccumulatedCredit
			EXEC dbo.Age_CashService_Balance_Rollback
				@Type = 2,
				@TransId = @TransId,
				@Custid = @CustID,
				@TransId_From = @TransId_From,
				@TransId_To = @TransId_To,
				@TransferAmount = @Amount,
				@AdjustCreditAmt = @AdjustCreditAmt,
				@CashAccumCreditTbl	= @CashAccumCreditTbl OUTPUT

			GOTO Writelog;
		END
		ELSE --Insert data for writelog
		BEGIN
			SELECT @LogData = '<R custid="'+ COALESCE(CAST(@custid AS VARCHAR(20)), SPACE(1)) + '" ' +
								'TransId="'+ COALESCE(CAST(@TransId AS VARCHAR(20)), SPACE(1)) + '" ' +
								'TransferRefNo="'+ COALESCE(CAST(@TransferRefNo AS VARCHAR(50)), SPACE(1)) + '" ' +
								'StatusId="'+ COALESCE(CAST(4 AS VARCHAR(3)), SPACE(1)) + '" ' +
								'AdjustCreditAmt="'+ COALESCE(CAST(@AdjustCreditAmt AS VARCHAR(100)), SPACE(1)) + '" />'

			INSERT INTO @tmp_LogData (LogTypeId, UserID, CustID, ActionID, TrackingValue)
			SELECT 3, @UplineID, @CustID, 310006, @LogData
		END
	END TRY
	BEGIN CATCH
		--Rollback CashTransaction & Transfer & CashAccumulatedCredit
		EXEC dbo.Age_CashService_Balance_Rollback
			@Type = 2,
			@TransId = @TransId,
			@Custid = @CustID,
			@TransId_From = @TransId_From,
			@TransId_To = @TransId_To,
			@TransferAmount = @Amount,
			@AdjustCreditAmt = @AdjustCreditAmt,
			@CashAccumCreditTbl	= @CashAccumCreditTbl OUTPUT

		SELECT @ErrCode = ERROR_NUMBER()
			,@ErrMsg = ERROR_MESSAGE()

		GOTO Writelog;
	END CATCH

	Writelog:
	SELECT *
	FROM @tmp_LogData t

    SET NOCOUNT OFF;
END;