/*<info serverAlias="DBSIC-bodb02" executers="asv_CashService,wsv_CashService" selecters="" viewers="" isFunction="0" isNested=""></info>*/
ALTER PROCEDURE dbo.Age_CashDeposit_ManualAdd
(
    @CustID INT,
    @UplineID INT,
    @SubAccID INT = NULL,
	@SiteDBGroupID SMALLINT = 3,
    @AgentGivenCredit MONEY,
    @CreditMembers_GivenCredit MONEY,
    @PaymentFrom VARCHAR(100),
    @PaymentTo VARCHAR(100),
	@PaymentMethodID SMALLINT = NULL,
    @Amount MONEY,
    @PaySlip VARBINARY(MAX) = NULL,
    @IP VARCHAR(50) = '',
	@ExchangeRate SMALLMONEY =	1,
    @Remark NVARCHAR(1000) = NULL,
	@ErrCode	INT = 0 OUTPUT,
	@ErrMsg	VARCHAR(2000) = NULL OUTPUT,
	@TransId	BIGINT = NULL OUTPUT,
	@CashAccumCreditTbl	VARCHAR(MAX) = NULL OUTPUT,
	@AgentAvailableCredit MONEY = 0 OUTPUT
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
		- 20250723@Eden: Alpha - Agency Cash Service - Sprint 7 [redmine: #233481] 
		- 20250808@Eden: Alpha - Agency Cash Service - Sprint 8 [redmine: #235012]
		- 20250821@Eden: Alpha - Agency Cash Service - Sprint 9 [redmine: #236435]  

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
		,@SubAccName	VARCHAR(30) = ''
		,@Desc_Transtype   VARCHAR(100)
		,@PaymentType TINYINT = 2 -- via bank
		,@HasPaySlip	BIT = 0
		,@SPNAME		VARCHAR(200)

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

	IF ISNULL(@PaySlip,0x) <> 0x
		SET @HasPaySlip = 1
	ELSE 
		SET @HasPaySlip = 0

    -- Step 1: Validate the input data
	BEGIN TRY
		EXEC dbo.Age_CashDeposit_Validate 
			@CustID = @CustID,
			@UplineID = @UplineID,
			@AgentGivenCredit = @AgentGivenCredit,
			@CreditMembers_GivenCredit = @CreditMembers_GivenCredit,
			@Amount = @Amount,
			@ErrCode = @ErrCode OUTPUT,
			@ErrMsg = @ErrMsg OUTPUT,
			@AgentAvailableCredit= @AgentAvailableCredit OUTPUT

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

	BEGIN TRY
		IF @SubAccID > 0 
		BEGIN	
			EXEC Age_GetSubAccName
				@SubAccID = @SubAccID,
				@SubAccName = @SubAccName OUTPUT
		END
	END TRY
	BEGIN CATCH
		PRINT 'Cannot get SubAccName'
		SET @SubAccName = ''
	END CATCH

	-- Step 2: Insert cash transaction
	BEGIN TRY
		EXEC dbo.Age_CashTransaction_Ins 
			@CustID = @CustID,
			@Creator = @UplineID,
			@SubAccID = @SubAccID,
			@SiteDBGroupID = @SiteDBGroupID,
			@TransactionTypeID = 1, --Manual Deposit
			@StatusId = 2, --Pending
			@PaymentType = @PaymentType, 
			@PaymentMethod = @PaymentMethodID,
			@OperatedBy = @UplineID,
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
			GOTO ReturnLog;
		END
		ELSE --Insert data for writelog
		BEGIN
			SELECT @LogDataMask = '<R SPName="'+ COALESCE(CAST(@SPName AS VARCHAR(200)), SPACE(1)) + '" ' +
								'custid="'+ COALESCE(CAST(@custid AS VARCHAR(20)), SPACE(1)) + '" ' +
								'Creator="'+ COALESCE(CAST(@UplineID AS VARCHAR(20)), SPACE(1)) + '" ' +
								'SubAccName="'+ COALESCE(CAST(@SubAccName AS VARCHAR(30)), SPACE(1)) + '" ' +
								'TransactionTypeID="'+ COALESCE(CAST(1 AS VARCHAR(20)), SPACE(1)) + '" ' +
								'PaymentType="'+ COALESCE(CAST(@PaymentType AS VARCHAR(20)), SPACE(1)) + '" ' +
								'PaymentFrom="'+ COALESCE(CAST(@PaymentFrom AS VARCHAR(100)), SPACE(1)) + '" ' +
								'PaymentTo="'+ COALESCE(CAST(@PaymentTo AS VARCHAR(100)), SPACE(1)) + '" ' +
								'HasPaySlip="'+ COALESCE(CAST(@HasPaySlip AS VARCHAR(1)), SPACE(1)) + '" ' +
								'StatusId="'+ COALESCE(CAST(2 AS VARCHAR(3)), SPACE(1)) + '" ' +
								'TransId="'+ COALESCE(CAST(@TransId AS VARCHAR(20)), SPACE(1)) + '" ' +
								'IP="'+ COALESCE(CAST(@IP AS VARCHAR(50)), SPACE(1)) + '" />'

			SELECT @LogData = REPLACE (REPLACE (@LogDataMask, ISNULL(@PaymentFrom,''),''),ISNULL(@PaymentTo,''),'')

			INSERT INTO @tmp_LogData (LogTypeId, UserID, CustID, ActionID, TrackingValue,TrackingValueMask)
			SELECT 2, @UplineID, @CustID, NULL, @LogData, @LogDataMask
		END
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = ERROR_NUMBER()
			,@ErrMsg = ERROR_MESSAGE()

		GOTO ReturnLog;
	END CATCH

    -- Step 3: Insert transfer details
	BEGIN TRY
		SELECT @Desc_Transtype = 'Approve Deposit - '

		EXEC dbo.Age_CashDeposit_ManualAdd_InsTransfer 
			@CustID = @CustID,
			@UplineID = @UplineID,
			@Amount = @Amount,
			@ExchangeRate = @ExchangeRate,
			@IP = @IP,
			@ErrCode = @ErrCode OUTPUT,
			@ErrMsg = @ErrMsg OUTPUT,
			@TransferRefNo = @TransferRefNo OUTPUT,
			@TransId_From = @TransId_From OUTPUT,
			@TransId_To = @TransId_To OUTPUT,
			@CashTransactionID = @TransId,
			@SubAccName = @SubAccName,
			@Desc_Transtype = @Desc_Transtype

		IF @ErrCode <> 0
		BEGIN
			--Rollback CashTransaction
			EXEC dbo.Age_CashService_Balance_Rollback
				@Type = 1,
				@TransId = @TransId

			GOTO ReturnLog;
		END
		ELSE --Insert data for writelog
		BEGIN
			SELECT @LogData = 'Insert trans custid = ' + CONVERT(VARCHAR(20), @custid) + ', bettype = ' + CONVERT(VARCHAR(20), 31001) + ', amount = ' + CONVERT(VARCHAR(20), @amount) + ', Ref.No: ' + CONVERT(VARCHAR(20), @TransferRefNo)
			IF @SubAccID > 0 AND ISNULL(@SubAccName, '') <> ''
				SELECT @LogData = @LogData + ' (By ' + @SubAccName + ')'

			INSERT INTO @tmp_LogData (LogTypeId, UserID, FromCustID, ToCustID, IP, Doing)
			SELECT 1, @UplineID, @CustID, @UplineID, @IP, @LogData
		END
	END TRY
	BEGIN CATCH
		--Rollback CashTransaction
		EXEC dbo.Age_CashService_Balance_Rollback
				@Type = 1,
				@TransId = @TransId

		SELECT @ErrCode = ERROR_NUMBER()
			,@ErrMsg = ERROR_MESSAGE()

		GOTO ReturnLog;
	END CATCH

    -- Step 4: Adjust accumulated credit
	BEGIN TRY
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
			--Rollback CashTransaction & Transfer
			EXEC dbo.Age_CashService_Balance_Rollback
				@Type = 1,
				@TransId = @TransId,
				@Custid = @CustID,
				@TransId_From = @TransId_From,
				@TransId_To = @TransId_To,
				@TransferAmount = @Amount

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
			SELECT 2, @UplineID, @CustID, NULL, @LogData
		END
	END TRY
	BEGIN CATCH
		--Rollback CashTransaction & Transfer
		EXEC dbo.Age_CashService_Balance_Rollback
			@Type = 1,
			@TransId = @TransId,
			@Custid = @CustID,
			@TransId_From = @TransId_From,
			@TransId_To = @TransId_To,
			@TransferAmount = @Amount

		SELECT @ErrCode = ERROR_NUMBER()
			,@ErrMsg = ERROR_MESSAGE()

		GOTO ReturnLog;
	END CATCH

    -- Step 5: Update cash transaction
	BEGIN TRY
		EXEC dbo.Age_CashTransaction_Upd 
			@TransId = @TransId,
			@StatusId = 4, --completed
			@TransferRefNo	= @TransferRefNo,
			@AdjustCreditAmt = @AdjustCreditAmt,
			@ErrCode = @ErrCode OUTPUT,
			@ErrMsg = @ErrMsg OUTPUT

		IF @ErrCode <> 0
		BEGIN
			--Rollback CashTransaction & Transfer & CashAccumulatedCredit
			EXEC dbo.Age_CashService_Balance_Rollback
				@Type = 1,
				@TransId = @TransId,
				@Custid = @CustID,
				@TransId_From = @TransId_From,
				@TransId_To = @TransId_To,
				@TransferAmount = @Amount,
				@AdjustCreditAmt = @AdjustCreditAmt,
				@CashAccumCreditTbl	= @CashAccumCreditTbl OUTPUT

			GOTO ReturnLog;
		END
		ELSE --Insert data for writelog
		BEGIN
			SELECT @LogData = '<R SPName="'+ COALESCE(CAST(@SPName AS VARCHAR(200)), SPACE(1)) + '" ' +
								'custid="'+ COALESCE(CAST(@custid AS VARCHAR(20)), SPACE(1)) + '" ' +
								'TransferRefNo="'+ COALESCE(CAST(@TransferRefNo AS VARCHAR(50)), SPACE(1)) + '" ' +
								'StatusId="'+ COALESCE(CAST(4 AS VARCHAR(3)), SPACE(1)) + '" ' +
								'AdjustCreditAmt="'+ COALESCE(CAST(@AdjustCreditAmt AS VARCHAR(100)), SPACE(1))  + '" ' +
								'TransId="'+ COALESCE(CAST(@TransId AS VARCHAR(20)), SPACE(1)) + '" ' +
								'IP="'+ COALESCE(CAST(@IP AS VARCHAR(50)), SPACE(1)) + '" />'

			INSERT INTO @tmp_LogData (LogTypeId, UserID, CustID, ActionID, TrackingValue)
			SELECT 3, @UplineID, @CustID, NULL, @LogData
		END
	END TRY
	BEGIN CATCH
		--Rollback CashTransaction & Transfer & CashAccumulatedCredit
		EXEC dbo.Age_CashService_Balance_Rollback
			@Type = 1,
			@TransId = @TransId,
			@Custid = @CustID,
			@TransId_From = @TransId_From,
			@TransId_To = @TransId_To,
			@TransferAmount = @Amount,
			@AdjustCreditAmt = @AdjustCreditAmt,
			@CashAccumCreditTbl	= @CashAccumCreditTbl OUTPUT

		SELECT @ErrCode = ERROR_NUMBER()
			,@ErrMsg = ERROR_MESSAGE()

		GOTO ReturnLog;
	END CATCH

	-------LOG-------------
	--Log the transaction
	SELECT @LogDataMask = '<R custid="'+ COALESCE(CAST(@custid AS VARCHAR(20)), SPACE(1)) + '" ' +
						'Creator="'+ COALESCE(CAST(@UplineID AS VARCHAR(20)), SPACE(1)) + '" ' +
						'SubAccName="'+ COALESCE(CAST(@SubAccName AS VARCHAR(30)), SPACE(1)) + '" ' +
						'TransactionTypeID="'+ COALESCE(CAST(1 AS VARCHAR(20)), SPACE(1)) + '" ' +
						'PaymentType="'+ COALESCE(CAST(@PaymentType AS VARCHAR(20)), SPACE(1)) + '" ' +
						'PaymentMethod="'+ COALESCE(CAST(@PaymentMethodID AS VARCHAR(20)), SPACE(1)) + '" ' +
						'PaymentFrom="'+ COALESCE(CAST(@PaymentFrom AS VARCHAR(100)), SPACE(1)) + '" ' +
						'PaymentTo="'+ COALESCE(CAST(@PaymentTo AS VARCHAR(100)), SPACE(1)) + '" ' +
						'Amount="'+ COALESCE(CAST(@Amount AS VARCHAR(50)), SPACE(1)) + '" ' +
						'HasPaySlip="'+ COALESCE(CAST(@HasPaySlip AS VARCHAR(1)), SPACE(1)) + '" ' +
						'StatusId="'+ COALESCE(CAST(4 AS VARCHAR(3)), SPACE(1)) + '" ' +
						'TransferRefNo="'+ COALESCE(CAST(@TransferRefNo AS VARCHAR(50)), SPACE(1)) + '" ' +
						'OperatedBy="'+ COALESCE(CAST(@UplineID AS VARCHAR(20)), SPACE(1)) + '" ' +
						'AdjustCreditAmt="'+ COALESCE(CAST(@AdjustCreditAmt AS VARCHAR(100)), SPACE(1)) + '" ' +
						'TransId="'+ COALESCE(CAST(@TransId AS VARCHAR(20)), SPACE(1)) + '" ' +
						'IP="'+ COALESCE(CAST(@IP AS VARCHAR(50)), SPACE(1)) + '" />'

	SELECT @LogData = REPLACE (REPLACE (@LogDataMask, ISNULL(@PaymentFrom,''),''),ISNULL(@PaymentTo,''),'')

	INSERT INTO @tmp_LogData (LogTypeId, UserID, CustID, ActionID, TrackingValue,TrackingValueMask)
	SELECT 2, @UplineID, @CustID, 310001, @LogData, @LogDataMask

	ReturnLog:

	SELECT *
	FROM @tmp_LogData t

    SET NOCOUNT OFF;
END;

