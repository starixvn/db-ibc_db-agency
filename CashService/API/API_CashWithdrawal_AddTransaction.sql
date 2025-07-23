/*<info serverAlias="DBSIC-bodb02" executers="asv_CashService,wsv_CashService" selecters="" viewers="" isFunction="0" isNested=""></info>*/
ALTER PROCEDURE dbo.API_CashWithdrawal_AddTransaction
(
    @CustID INT,
    @AgentID INT,
	@SiteDBGroupID SMALLINT = 3,
	@TransactionTypeID	TINYINT,
    @DailyWithdrawalCnt_Setting SMALLINT,
    @MinAmt MONEY = 0,
    @MaxAmt MONEY = NULL,
    @PaymentTo VARCHAR(100),
    @Amount MONEY,
    @IP VARCHAR(50) = '',
	@ErrCode	INT = 0 OUTPUT,
	@ErrMsg	VARCHAR(2000) = NULL OUTPUT,
	@TransId	BIGINT = NULL OUTPUT,
	@ErrExtraInfo	VARCHAR(MAX) = NULL OUTPUT
)
AS
/*
	Created: 20250502@Max		
	Task: Alpha - Agency Cash Service [redmine: #223896] 
	DB:  DBSIC-bodb02
		
	Revisions:
		- 20250530@Max: Alpha - Agency Cash Service [redmine: #223896] 
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
		,@TransId_From	BIGINT = NULL
		,@TransId_To	BIGINT = NULL

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
			@UplineID = @AgentID,
			@MinLimitAmt = @MinAmt,
			@MaxLimitAmt = @MaxAmt,
			@Amount = @Amount,
			@DailyWithdrawalCnt_Setting = @DailyWithdrawalCnt_Setting,
			@ErrCode = @ErrCode OUTPUT,
			@ErrMsg = @ErrMsg OUTPUT

		IF @ErrCode <> 0
		BEGIN
			SELECT @ErrExtraInfo = @ErrMsg
				,@ErrCode = CASE WHEN @ErrCode IN(406, 407, 408) THEN @ErrCode ELSE 409 END
				,@ErrMsg = CASE WHEN @ErrCode IN(406, 407, 408) THEN @ErrMsg
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

	-- Step 2: Insert transfer details
	BEGIN TRY
		EXEC dbo.Age_CashWithdrawal_ManualAdd_InsTransfer 
			@CustID = @CustID,
			@UplineID = @AgentID,
			@Amount = @Amount,
			@IP = @IP,
			@ErrCode = @ErrCode OUTPUT,
			@ErrMsg = @ErrMsg OUTPUT,
			@TransferRefNo = @TransferRefNo OUTPUT,
			@TransId_From = @TransId_From OUTPUT,
			@TransId_To = @TransId_To OUTPUT

		IF @ErrCode <> 0
		BEGIN
			SELECT @ErrCode = 409
				,@ErrExtraInfo = @ErrMsg
				,@ErrMsg = 'The transaction inserted failed. Please try again.'

			GOTO Writelog;
		END
		ELSE --Insert data for writelog
		BEGIN
			SELECT @LogData = 'Insert trans custid = ' + CONVERT(VARCHAR(20), @custid) + ', bettype = ' + CONVERT(VARCHAR(20), 31002) + ', amount = ' + CONVERT(VARCHAR(20), @amount) + ', Ref.No: ' + CONVERT(VARCHAR(20), @TransferRefNo)

			INSERT INTO @tmp_LogData (LogTypeId, UserID, FromCustID, ToCustID, IP, Doing)
			SELECT 1, @CustID, @AgentID, @CustID, @IP, @LogData
		END
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = 409
			,@ErrExtraInfo = ERROR_MESSAGE()
			,@ErrMsg = 'The transaction inserted failed. Please try again.'

		GOTO Writelog;
	END CATCH

	-- Step 3: Insert cash transaction
	BEGIN TRY
		EXEC dbo.Age_CashTransaction_Ins 
			@CustID = @CustID,
			@Creator = @CustID,
			@SiteDBGroupID = @SiteDBGroupID,
			@TransactionTypeID = @TransactionTypeID, --Manual Withdrawal
			@StatusId = 2, --Pending
			@PaymentTo = @PaymentTo,
			@Amount = @Amount,
			@TransferRefNo = @TransferRefNo,
			@AdjustCreditAmt = 0,
			@ErrCode = @ErrCode OUTPUT,
			@ErrMsg = @ErrMsg OUTPUT,
			@TransId = @TransId OUTPUT

		IF @ErrCode <> 0
		BEGIN
			--Rollback Transfer
			EXEC dbo.Age_CashService_Balance_Rollback
				@Type = 2,
				@TransId = @TransId,
				@Custid = @CustID,
				@TransId_From = @TransId_From,
				@TransId_To = @TransId_To,
				@TransferAmount = @Amount

			SELECT @ErrCode = 409
				,@ErrExtraInfo = @ErrMsg
				,@ErrMsg = 'The transaction inserted failed. Please try again.'

			GOTO Writelog;
		END
		ELSE --Insert data for writelog
		BEGIN
			SELECT @LogDataMask = '<R custid="'+ COALESCE(CAST(@custid AS VARCHAR(20)), SPACE(1)) + '" ' +
								'UplineID="'+ COALESCE(CAST(@AgentId AS VARCHAR(20)), SPACE(1)) + '" ' +
								'TransactionTypeID="'+ COALESCE(CAST(@TransactionTypeID AS VARCHAR(20)), SPACE(1)) + '" ' +
								'PaymentTo="'+ COALESCE(CAST(@PaymentTo AS VARCHAR(100)), SPACE(1)) + '" ' +
								'Amount="'+ COALESCE(CAST(@Amount AS VARCHAR(50)), SPACE(1)) + '" ' +
								'TransferRefNo="'+ COALESCE(CAST(@TransferRefNo AS VARCHAR(50)), SPACE(1)) + '" ' +
								'StatusId="'+ COALESCE(CAST(2 AS VARCHAR(3)), SPACE(1)) + '" />'

			SELECT @LogData = REPLACE (@LogDataMask,ISNULL(@PaymentTo,''),'')

			INSERT INTO @tmp_LogData (LogTypeId, UserID, CustID, ActionID, TrackingValue,TrackingValueMask)
			SELECT 2, @CustId, @CustID, 310008, @LogData, @LogDataMask
		END
	END TRY
	BEGIN CATCH
		--Rollback Transfer
			EXEC dbo.Age_CashService_Balance_Rollback
				@Type = 2,
				@TransId = @TransId,
				@Custid = @CustID,
				@TransId_From = @TransId_From,
				@TransId_To = @TransId_To,
				@TransferAmount = @Amount

		SELECT @ErrCode = 409
			,@ErrExtraInfo = ERROR_MESSAGE()
			,@ErrMsg = 'The transaction inserted failed. Please try again.'

		GOTO Writelog;
	END CATCH

	Writelog:
	SELECT *
	FROM @tmp_LogData t

    SET NOCOUNT OFF;
END;