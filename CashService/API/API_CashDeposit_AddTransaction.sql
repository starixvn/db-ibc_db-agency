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
	@PaymentMethodID SMALLINT = 0,
    @PaymentFrom VARCHAR(100),
    @PaymentTo VARCHAR(100),
    @Amount MONEY,
	@UserInput_Amount MONEY = NULL,
	@MachingMode TINYINT = NULL,
    @PaySlip VARBINARY(MAX) = NULL,
    @IP VARCHAR(50) = '',
	@ExchangeRate SMALLMONEY =	1,
    @Remark NVARCHAR(1000) = NULL,
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

	Parameter's Explanation:	
*/ 
BEGIN
    SET NOCOUNT ON;

	DECLARE @TransferRefNo BIGINT
		,@LogData VARCHAR(MAX)
		,@LogDataMask VARCHAR(MAX)
		,@AdjustCreditAmt	MONEY
		,@ExtraInfo NVARCHAR(1000) = NULL

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
		EXEC dbo.Age_CashDeposit_Validate 
			@CustID = @CustID,
			@UplineID = @AgentID,
			@AgentGivenCredit = @AgentGivenCredit,
			@CreditMembers_GivenCredit = @CreditMembers_GivenCredit,
			@UserInput_Amount = @UserInput_Amount,
			@MachingMode = @MachingMode,
			@MinLimitAmt  = @MinAmt,
			@MaxLimitAmt  = @MaxAmt,
			@Amount = @Amount,
			@ErrCode = @ErrCode OUTPUT,
			@ErrMsg = @ErrMsg OUTPUT

		IF @ErrCode <> 0
		BEGIN
			SELECT @ErrExtraInfo = @ErrMsg
				,@ErrCode = CASE WHEN @ErrCode = 101 THEN 407 ELSE 409 END
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
			SET @ExtraInfo = (SELECT @UserInput_Amount AS UserInputAmt, @MachingMode AS MatchingMode FOR JSON PATH)
		END

		EXEC dbo.Age_CashTransaction_Ins 
			@CustID = @CustID,
			@Creator = @CustID,
			@SubAccID = @SubAccID,
			@SiteDBGroupID = @SiteDBGroupID,
			@TransactionTypeID = @TransactionTypeID,
			@StatusId = 2, --Pending
			@PaymentType = @PaymentType, 
			@OperatedBy = @AgentID,
			@PaymentFrom = @PaymentFrom,
			@PaymentTo = @PaymentTo,
			@Amount = @Amount,
			@PaySlip = @PaySlip,
			@Remark = @Remark,
			@AdjustCreditAmt = @Amount,
			@ExtraInfo = @ExtraInfo,
			@ErrCode = @ErrCode OUTPUT,
			@ErrMsg = @ErrMsg OUTPUT,
			@TransId = @TransId OUTPUT

		IF @ErrCode <> 0
		BEGIN
			SELECT @ErrCode = 409
				,@ErrExtraInfo = @ErrMsg
				,@ErrMsg = 'The transaction inserted failed. Please try again.'

			GOTO Writelog;
		END
		ELSE --Insert data for writelog
		BEGIN
			SELECT @LogDataMask = '< custid="'+ COALESCE(CAST(@custid AS VARCHAR(20)), SPACE(1)) + '" ' +
								'UplineID="'+ COALESCE(CAST(@AgentId AS VARCHAR(20)), SPACE(1)) + '" ' +
								'SubAccID="'+ COALESCE(CAST(@SubAccID AS VARCHAR(20)), SPACE(1)) + '" ' +
								'TransactionTypeID="'+ COALESCE(CAST(1 AS VARCHAR(20)), SPACE(1)) + '" ' +
								'PaymentType="'+ COALESCE(CAST(2 AS VARCHAR(20)), SPACE(1)) + '" ' +
								'PaymentFrom="'+ COALESCE(CAST(@PaymentFrom AS VARCHAR(100)), SPACE(1)) + '" ' +
								'PaymentTo="'+ COALESCE(CAST(@PaymentTo AS VARCHAR(100)), SPACE(1)) + '" ' +
								'Amount="'+ COALESCE(CAST(@Amount AS VARCHAR(50)), SPACE(1)) + '" ' +
								'StatusId="'+ COALESCE(CAST(2 AS VARCHAR(3)), SPACE(1)) + '" />'

			SELECT @LogData = REPLACE (REPLACE (@LogDataMask, ISNULL(@PaymentFrom,''),''),ISNULL(@PaymentTo,''),'')

			INSERT INTO @tmp_LogData (LogTypeId, UserID, CustID, ActionID, TrackingValue,TrackingValueMask)
			SELECT 2, @CustID, @CustID, 310007, @LogData, @LogDataMask
		END
	END TRY
	BEGIN CATCH
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