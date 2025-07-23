/*<info serverAlias="DBSIC-bodb02" executers="asv_CashService,wsv_CashService" selecters="" viewers="" isFunction="0" isNested=""></info>*/
ALTER PROCEDURE dbo.Age_CashWithdrawal_UpdateTransStatus
(
    @CustID INT,
    @AgentID INT,
	@SubAccID INT = 0,
	@TransId BIGINT,
	@StatusId TINYINT = NULL,
	@SiteDBGroupID SMALLINT = 3,
	@ProviderID SMALLINT = 0,
	@PaymentMethodID SMALLINT = NULL,
	@PaymentFrom VARCHAR(100),
    @IP VARCHAR(50) = '',
	@Remark NVARCHAR(1000) = NULL,
	@PaySlip VARBINARY(MAX) = NULL,
	@ErrCode	INT = 0 OUTPUT,
	@ErrMsg	VARCHAR(2000) = NULL OUTPUT,	
	@CashAccumCreditTbl	VARCHAR(MAX) = NULL OUTPUT
)
AS
/*
	Created: 20250611@Max		
	Task: Alpha - Agency Cash Service [redmine: #223896] 
	DB:  DBSIC-bodb02
		
	Revisions:
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
		,@Amount MONEY = NULL
		,@_statusId TINYINT
		,@TransactionTypeID TINYINT
		,@ExtraInfo NVARCHAR(1000) = NULL
		,@_PaymentType TINYINT 

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

	SET @StatusId = ISNULL(@StatusId,0)

	IF @ProviderID <> 0 
		SET @PaymentType = 1 -- Payment Gateway
	ELSE
		SET @PaymentType = 2 --Bank Account

	SELECT @Amount = c.Amount
		, @TransferRefNo = c.TransferRefNo
		, @_statusId = c.StatusId
		, @TransactionTypeID = c.TransactionTypeID
		, @_PaymentType = c.PaymentType
	FROM dbo.CashTransaction c WITH (NOLOCK)
		INNER JOIN custdb.dbo.vw_CashService_Customer ci WITH(NOLOCK) 
			ON c.CustId = ci.custid
	WHERE c.TransId = @TransId
		AND c.CustId = @CustID
		AND ci.recommend = @AgentID
	
	IF @TransactionTypeID IS NULL
	BEGIN
		SELECT @ErrCode = 405, @ErrMsg = 'Invalid parameters.'
		RETURN
	END

	IF @_statusId <> 2 
		OR @TransactionTypeID NOT IN (3,4) --Withdrawal
		OR @StatusId NOT IN (0,3,4,5,6) -- 0 : Update info for Payment Gateway, not update status
		OR (@StatusId = 0 AND @PaymentType = 2) --Bank transfer 
		OR (@StatusId IN (0,4) AND ISNULL(@PaymentFrom,'') = '') -- Approve or Update Payment Gateway info need this Info
		OR @_PaymentType = 1 -- Provider in-progess
	BEGIN
		SELECT @ErrCode = 409, @ErrMsg = 'The transaction inserted failed. Please try again.'
		RETURN
	END

	--Locking transaction for process
	BEGIN TRY
		EXEC dbo.Age_CashDeposit_CheckingProcess
			@TransId = @TransId,
			@ErrCode = @ErrCode OUTPUT,
			@ErrMsg = @ErrMsg OUTPUT

		IF @ErrCode <> 0
		BEGIN
			SELECT @ErrCode = 409
				,@ErrMsg = 'The transaction inserted failed. Please try again.'

			RETURN
		END
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = 409
				,@ErrMsg = 'The transaction inserted failed. Please try again.'

		RETURN
	END CATCH

	IF @StatusId = 4 --Completed
	BEGIN
		--Adjust accumulated credit
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
				SELECT @ErrCode = 409
					,@ErrMsg = 'The transaction inserted failed. Please try again.'

				GOTO Writelog;
			END
			ELSE --Insert data for writelog
			BEGIN
				SELECT @LogData = '<R custid="'+ COALESCE(CAST(@custid AS VARCHAR(20)), SPACE(1)) + '" ' +
									'ActionType="'+ COALESCE(CAST(2 AS VARCHAR(20)), SPACE(1)) + '" ' +
									'Amount="'+ COALESCE(CAST(@Amount AS VARCHAR(100)), SPACE(1)) + '" ' +
									'AdjustCreditAmt="'+ COALESCE(CAST(@AdjustCreditAmt AS VARCHAR(100)), SPACE(1)) + '" />'

				INSERT INTO @tmp_LogData (LogTypeId, UserID, CustID, ActionID, TrackingValue)
				SELECT 3, @AgentID, @CustID, 310005, @LogData
			END
		END TRY
		BEGIN CATCH
			SELECT @ErrCode = 409
					,@ErrMsg = 'The transaction inserted failed. Please try again.'

			GOTO Writelog;
		END CATCH

		--Update cash transaction
		BEGIN TRY
			EXEC dbo.Age_CashTransaction_Upd 
				@TransId = @TransId,
				@AdjustCreditAmt = @AdjustCreditAmt,
				@StatusId = @StatusId,
				@OperatedBy = @AgentID,
				--@TransferRefNo = @TransferRefNo,
				@PaymentMethod = @PaymentMethodID,
				@PaymentType = @PaymentType,
				@PaymentFrom = @PaymentFrom,
				@PaySlip = @PaySlip,
				@Remark = @Remark,
				@ErrCode = @ErrCode OUTPUT,
				@ErrMsg = @ErrMsg OUTPUT

			IF @ErrCode <> 0
			BEGIN
				--Rollback CashAccumulatedCredit
				EXEC dbo.Age_CashService_Balance_Rollback
					@Type = 2,
					@TransId = 0,
					@Custid = @CustID,
					@AdjustCreditAmt = @AdjustCreditAmt,
					@CashAccumCreditTbl	= @CashAccumCreditTbl OUTPUT

				SELECT @ErrCode = 409
						,@ErrMsg = 'The transaction inserted failed. Please try again.'

				GOTO Writelog;
			END
			ELSE --Insert data for writelog
			BEGIN
				SELECT @LogDataMask = '<R custid="'+ COALESCE(CAST(@custid AS VARCHAR(20)), SPACE(1)) + '" ' +
									'TransId="'+ COALESCE(CAST(@TransId AS VARCHAR(20)), SPACE(1)) + '" ' +
									'TransferRefNo="'+ COALESCE(CAST(@TransferRefNo AS VARCHAR(50)), SPACE(1)) + '" ' +
									'PaymentType="'+ COALESCE(CAST(@PaymentType AS VARCHAR(20)), SPACE(1)) + '" ' +
									'PaymentFrom="'+ COALESCE(CAST(@PaymentFrom AS VARCHAR(100)), SPACE(1)) + '" ' +
									'StatusId="'+ COALESCE(CAST(@StatusId AS VARCHAR(3)), SPACE(1)) + '" ' +
									'AdjustCreditAmt="'+ COALESCE(CAST(@AdjustCreditAmt AS VARCHAR(100)), SPACE(1)) + '" />'

				SELECT @LogData = REPLACE (@LogDataMask, ISNULL(@PaymentFrom,''),'')

				INSERT INTO @tmp_LogData (LogTypeId, UserID, CustID, ActionID, TrackingValue,TrackingValueMask)
				SELECT 3, @CustID, @CustID, 310006, @LogData, @LogDataMask
			END
		END TRY
		BEGIN CATCH
			--Rollback CashAccumulatedCredit
			EXEC dbo.Age_CashService_Balance_Rollback
				@Type = 2,
				@TransId = 0,
				@Custid = @CustID,
				@AdjustCreditAmt = @AdjustCreditAmt,
				@CashAccumCreditTbl	= @CashAccumCreditTbl OUTPUT

			SELECT @ErrCode = 409
				,@ErrMsg = 'The transaction inserted failed. Please try again.'

			GOTO Writelog;
		END CATCH
	END
	ELSE IF @StatusId IN (3,5,6)
	BEGIN
		--Insert transfer details
		BEGIN TRY
			EXEC dbo.Age_CashDeposit_ManualAdd_InsTransfer 
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
					,@ErrMsg = 'The transaction inserted failed. Please try again.'

				GOTO Writelog;
			END
			ELSE --Insert data for writelog
			BEGIN
				SELECT @LogData = 'Insert trans custid = ' + CONVERT(VARCHAR(20), @custid) + ', bettype = ' + CONVERT(VARCHAR(20), 31001) + ', amount = ' + CONVERT(VARCHAR(20), @amount) + ', Ref.No: ' + CONVERT(VARCHAR(20), @TransferRefNo) 

				INSERT INTO @tmp_LogData (LogTypeId, UserID, FromCustID, ToCustID, IP, Doing)
				SELECT 1, @AgentID, @CustID, @AgentID, @IP, @LogData
			END
		END TRY
		BEGIN CATCH
			SELECT @ErrCode = 409
					,@ErrMsg = 'The transaction inserted failed. Please try again.'

			GOTO Writelog;
		END CATCH

		--Update cash transaction
		BEGIN TRY
			EXEC dbo.Age_CashTransaction_Upd 
				@TransId = @TransId,
				@AdjustCreditAmt = @AdjustCreditAmt,
				@StatusId = @StatusId,
				@OperatedBy = @AgentID,
				@TransferRefNo = @TransferRefNo,
				@PaymentMethod = @PaymentMethodID,
				@PaymentType = @PaymentType,
				@PaymentFrom = @PaymentFrom,
				@PaySlip = @PaySlip,
				@Remark = @Remark,
				@ErrCode = @ErrCode OUTPUT,
				@ErrMsg = @ErrMsg OUTPUT

			IF @ErrCode <> 0
			BEGIN
				--Rollback Transfer
				EXEC dbo.Age_CashService_Balance_Rollback
					@Type = 1,
					@TransId = 0,
					@Custid = @CustID,
					@TransId_From = @TransId_From,
					@TransId_To = @TransId_To,
					@TransferAmount = @Amount

				SELECT @ErrCode = 409
						,@ErrMsg = 'The transaction inserted failed. Please try again.'

				GOTO Writelog;
			END
			ELSE --Insert data for writelog
			BEGIN
				SELECT @LogData = '<R custid="'+ COALESCE(CAST(@custid AS VARCHAR(20)), SPACE(1)) + '" ' +
									'TransId="'+ COALESCE(CAST(@TransId AS VARCHAR(20)), SPACE(1)) + '" ' +
									'TransferRefNo="'+ COALESCE(CAST(@TransferRefNo AS VARCHAR(50)), SPACE(1)) + '" ' +
									'StatusId="'+ COALESCE(CAST(@StatusId AS VARCHAR(3)), SPACE(1)) + '" ' +
									'AdjustCreditAmt="'+ COALESCE(CAST(@AdjustCreditAmt AS VARCHAR(100)), SPACE(1)) + '" />'

				INSERT INTO @tmp_LogData (LogTypeId, UserID, CustID, ActionID, TrackingValue)
				SELECT 3, @AgentID, @CustID, 310006, @LogData
			END
		END TRY
		BEGIN CATCH
			--Rollback Transfer
			EXEC dbo.Age_CashService_Balance_Rollback
				@Type = 1,
				@TransId = 0,
				@Custid = @CustID,
				@TransId_From = @TransId_From,
				@TransId_To = @TransId_To,
				@TransferAmount = @Amount

			SELECT @ErrCode = 409
				,@ErrMsg = 'The transaction inserted failed. Please try again.'

			GOTO Writelog;
		END CATCH
	END
	ELSE IF @StatusId = 0 AND @PaymentType = 1
	BEGIN
		--Update cash transaction, payment information only, not update status
		BEGIN TRY
			SELECT @ExtraInfo = JSON_MODIFY(ISNULL(c.ExtraInfo,'{}'), '$.ProviderId',@ProviderID)
			FROM dbo.CashTransaction c WITH (NOLOCK)
			WHERE c.TransId = @TransId

			EXEC dbo.Age_CashTransaction_Upd 
				@TransId = @TransId,
				@PaymentMethod = @PaymentMethodID,
				@PaymentType = @PaymentType,
				@PaymentFrom = @PaymentFrom,
				@ExtraInfo = @ExtraInfo,
				@PaySlip = @PaySlip,
				@Remark = @Remark,
				@ErrCode = @ErrCode OUTPUT,
				@ErrMsg = @ErrMsg OUTPUT

			IF @ErrCode <> 0
			BEGIN
				SELECT @ErrCode = 409
					,@ErrMsg = 'The transaction inserted failed. Please try again.'

				GOTO Writelog;
			END
			ELSE --Insert data for writelog
			BEGIN
				SELECT @LogDataMask = '<R custid="'+ COALESCE(CAST(@custid AS VARCHAR(20)), SPACE(1)) + '" ' +
									'UplineID="'+ COALESCE(CAST(@AgentId AS VARCHAR(20)), SPACE(1)) + '" ' +
									'SubAccID="'+ COALESCE(CAST(@SubAccID AS VARCHAR(20)), SPACE(1)) + '" ' +
									'TransId="'+ COALESCE(CAST(@TransId AS VARCHAR(20)), SPACE(1)) + '" ' +
									'PaymentType="'+ COALESCE(CAST(@PaymentType AS VARCHAR(20)), SPACE(1)) + '" ' +
									'PaymentFrom="'+ COALESCE(CAST(@PaymentFrom AS VARCHAR(100)), SPACE(1)) + '" />'

				SELECT @LogData = REPLACE (@LogDataMask, ISNULL(@PaymentFrom,''),'')

				INSERT INTO @tmp_LogData (LogTypeId, UserID, CustID, ActionID, TrackingValue,TrackingValueMask)
				SELECT 3, @CustID, @CustID, 310006, @LogData, @LogDataMask
			END
		END TRY
		BEGIN CATCH
			SELECT @ErrCode = 409
				,@ErrMsg = 'The transaction inserted failed. Please try again.'

			GOTO Writelog;
		END CATCH
	END

	Writelog:
	--Unlock Transaction
	EXEC dbo.Age_CashDeposit_CheckingProcess
		@TransId = @TransId,
		@IsRelease = 1

	SELECT *
	FROM @tmp_LogData t

    SET NOCOUNT OFF;
END;