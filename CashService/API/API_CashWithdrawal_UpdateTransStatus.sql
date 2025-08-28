/*<info serverAlias="DBSIC-bodb02" executers="asv_CashService,wsv_CashService" selecters="" viewers="" isFunction="0" isNested=""></info>*/
ALTER PROCEDURE dbo.API_CashWithdrawal_UpdateTransStatus
(
    @CustID INT,
    @AgentID INT,
	@TransId BIGINT,
	@StatusId TINYINT,
	@SiteDBGroupID SMALLINT = 3,
	@ProviderTransId VARCHAR(100) = NULL,
    @IP VARCHAR(50) = '',
	@ErrCode	INT = 0 OUTPUT,
	@ErrMsg	VARCHAR(2000) = NULL OUTPUT,	
	@ErrExtraInfo	VARCHAR(MAX) = NULL OUTPUT,
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
		- 20250723@Eden: Alpha - Agency Cash Service - Sprint 7 [redmine: #233481] 
		- 20250821@Eden: Alpha - Agency Cash Service - Sprint 9 [redmine: #236435]  

	Parameter's Explanation:	
		@StatusId =
			3: Expired
			4: Completed
			6: Provider Reject
			0: Revert Transaction (Web cannot connect with API)
*/ 
BEGIN
    SET NOCOUNT ON;

	DECLARE @TransferRefNo BIGINT
		,@LogData VARCHAR(MAX)
		,@LogData_Old VARCHAR(MAX)
		,@LogDataMask VARCHAR(MAX)
		,@AdjustCreditAmt	MONEY
		,@_AdjustCreditAmt	MONEY
		,@PaymentType TINYINT 
		,@TransId_From	BIGINT = NULL
		,@TransId_To	BIGINT = NULL
		,@Amount MONEY = NULL
		,@_statusId TINYINT
		,@_ProviderTransId VARCHAR(100)
		,@TransactionTypeID TINYINT
		,@ExtraInfo NVARCHAR(1000)
		,@SPNAME		VARCHAR(200)
		,@Desc_Transtype   VARCHAR(100)

	SELECT @SPNAME = OBJECT_NAME(@@PROCID)

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

	SELECT @StatusId = ISNULL(@StatusId,0)

	EXEC Age_CashService_CheckBelonging
			@CustID	= @CustID 
			,@UplineID	= @AgentID
			,@ErrCode = @ErrCode OUTPUT 
			,@ErrMsg  = @ErrMsg OUTPUT

	IF @ErrCode <> 0
	BEGIN
		SELECT @ErrExtraInfo = @ErrMsg
			, @ErrCode = 405
			, @ErrMsg = 'Invalid parameters.'
		RETURN
	END

	SELECT @Amount = c.Amount
		, @TransferRefNo = c.TransferRefNo
		, @_statusId = c.StatusId
		, @TransactionTypeID = c.TransactionTypeID
		, @PaymentType = c.PaymentType
		, @_ProviderTransId = JSON_VALUE(c.ExtraInfo, '$.ProviderTransId') 
		, @_AdjustCreditAmt = c.AdjustCreditAmt
	FROM dbo.CashTransaction c WITH (NOLOCK)
	WHERE c.TransId = @TransId
		AND c.CustId = @CustID
	
	IF @TransactionTypeID IS NULL
	BEGIN
		SELECT @ErrCode = 405
			, @ErrMsg = 'Invalid parameters.'
			, @ErrExtraInfo = 'Invalid Transaction [' + ISNULL(CAST(@TransId AS VARCHAR(20)),'') + ', ' + ISNULL(CAST(@custid AS VARCHAR(10)),'') + ']'
		RETURN
	END

	IF @_statusId <> 2 
		OR @TransactionTypeID NOT IN (3,4) --Withdrawal
		OR @StatusId NOT IN (0,3,4,5,6)
	BEGIN
		SELECT @ErrCode = 409, @ErrMsg = 'The transaction inserted failed. Please try again.'
			,@ErrExtraInfo = 'Wrong TransactionType or StatusId'
		RETURN
	END

	IF ISNULL(@ProviderTransId,'') <> ISNULL(@_ProviderTransId,'') AND @PaymentType = 1 AND @StatusId <> 0-- Payment Gateway validate ProviderTransId
	BEGIN  
		SELECT @ErrCode = 409
			,@ErrMsg = 'The transaction inserted failed. Please try again.'  
			,@ErrExtraInfo = 'Wrong ProviderTransId'
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
				,@ErrExtraInfo = @ErrMsg
				,@ErrMsg = 'The transaction inserted failed. Please try again.'
				

			RETURN
		END
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = 409
				,@ErrMsg = 'The transaction inserted failed. Please try again.'
				,@ErrExtraInfo = ERROR_MESSAGE()
		RETURN
	END CATCH

	SELECT @LogData_Old = '<R custid="'+ COALESCE(CAST(@custid AS VARCHAR(20)), SPACE(1)) + '" ' +
							'TransferRefNo="'+ COALESCE(CAST(@TransferRefNo AS VARCHAR(50)), SPACE(1)) + '" ' +
							'StatusId="'+ COALESCE(CAST(@_statusId AS VARCHAR(3)), SPACE(1)) + '" ' +
							'AdjustCreditAmt="'+ COALESCE(CAST(@_AdjustCreditAmt AS VARCHAR(100)), SPACE(1)) + '" ' +
							'TransId="'+ COALESCE(CAST(@TransId AS VARCHAR(20)), SPACE(1)) + '" ' +
							'IP="'+ COALESCE(CAST(@IP AS VARCHAR(50)), SPACE(1)) + '" />'

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
					,@ErrExtraInfo = @ErrMsg
					,@ErrMsg = 'The transaction inserted failed. Please try again.'

				GOTO ReturnLog;
			END
			ELSE --Insert data for writelog
			BEGIN
				SELECT @LogData = '<R SPName="'+ COALESCE(CAST(@SPName AS VARCHAR(200)), SPACE(1)) + '" ' +
									'custid="'+ COALESCE(CAST(@custid AS VARCHAR(20)), SPACE(1)) + '" ' +
									'ActionType="'+ COALESCE(CAST(2 AS VARCHAR(20)), SPACE(1)) + '" ' +
									'Amount="'+ COALESCE(CAST(@Amount AS VARCHAR(100)), SPACE(1)) + '" ' +
									'AdjustCreditAmt="'+ COALESCE(CAST(@AdjustCreditAmt AS VARCHAR(100)), SPACE(1)) + '" ' +
									'TransId="'+ COALESCE(CAST(@TransId AS VARCHAR(20)), SPACE(1)) + '" ' +
									'IP="'+ COALESCE(CAST(@IP AS VARCHAR(50)), SPACE(1)) + '" />'

				INSERT INTO @tmp_LogData (LogTypeId, UserID, CustID, ActionID, TrackingValue)
				SELECT 2, @AgentID, @CustID, NULL, @LogData
			END
		END TRY
		BEGIN CATCH
			SELECT @ErrCode = 409
					,@ErrExtraInfo = ERROR_MESSAGE()
					,@ErrMsg = 'The transaction inserted failed. Please try again.'

			GOTO ReturnLog;
		END CATCH

		--Update cash transaction
		BEGIN TRY
			EXEC dbo.Age_CashTransaction_Upd 
				@TransId = @TransId,
				@AdjustCreditAmt = @AdjustCreditAmt,
				@StatusId = @StatusId,
				@ExtraInfo = @ExtraInfo,
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
						,@ErrExtraInfo = @ErrMsg
						,@ErrMsg = 'The transaction inserted failed. Please try again.'

				GOTO ReturnLog;
			END
			ELSE --Insert data for writelog
			BEGIN
				SELECT @LogData = '<R SPName="'+ COALESCE(CAST(@SPName AS VARCHAR(200)), SPACE(1)) + '" ' +
									'custid="'+ COALESCE(CAST(@custid AS VARCHAR(20)), SPACE(1)) + '" ' +
									--'TransferRefNo="'+ COALESCE(CAST(@TransferRefNo AS VARCHAR(50)), SPACE(1)) + '" ' +
									'StatusId="'+ COALESCE(CAST(@StatusId AS VARCHAR(3)), SPACE(1)) + '" ' +
									'AdjustCreditAmt="'+ COALESCE(CAST(@AdjustCreditAmt AS VARCHAR(100)), SPACE(1)) + '" ' +
									'TransId="'+ COALESCE(CAST(@TransId AS VARCHAR(20)), SPACE(1)) + '" ' +
									'IP="'+ COALESCE(CAST(@IP AS VARCHAR(50)), SPACE(1)) + '" />'

				INSERT INTO @tmp_LogData (LogTypeId, UserID, CustID, ActionID, TrackingValue)
				SELECT 2, @AgentID, @CustID, NULL, @LogData
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
				,@ErrExtraInfo = ERROR_MESSAGE()
				,@ErrMsg = 'The transaction inserted failed. Please try again.'

			GOTO ReturnLog;
		END CATCH

		-------------LOG------------
		SELECT @LogData = '<R custid="'+ COALESCE(CAST(@custid AS VARCHAR(20)), SPACE(1)) + '" ' +
							'TransferRefNo="'+ COALESCE(CAST(@TransferRefNo AS VARCHAR(50)), SPACE(1)) + '" ' +
							'StatusId="'+ COALESCE(CAST(@StatusId AS VARCHAR(3)), SPACE(1)) + '" ' +
							'AdjustCreditAmt="'+ COALESCE(CAST(@AdjustCreditAmt AS VARCHAR(100)), SPACE(1)) + '" ' +
							'TransId="'+ COALESCE(CAST(@TransId AS VARCHAR(20)), SPACE(1)) + '" ' +
							'IP="'+ COALESCE(CAST(@IP AS VARCHAR(50)), SPACE(1)) + '" />'

		INSERT INTO @tmp_LogData (LogTypeId, UserID, CustID, ActionID, TrackingValue)
		SELECT 2, @AgentID, @CustID, 310008, @LogData

	END
	ELSE IF @StatusId IN (3,5,6)
	BEGIN
		--Insert transfer details
		BEGIN TRY
			SELECT @Desc_Transtype = 'Reject Withdrawal - '

			EXEC dbo.Age_CashDeposit_ManualAdd_InsTransfer 
				@CustID = @CustID,
				@UplineID = @AgentID,
				@Amount = @Amount,
				@IP = @IP,
				@ErrCode = @ErrCode OUTPUT,
				@ErrMsg = @ErrMsg OUTPUT,
				@TransferRefNo = @TransferRefNo OUTPUT,
				@TransId_From = @TransId_From OUTPUT,
				@TransId_To = @TransId_To OUTPUT,
				@CashTransactionID = @TransId,
				@Desc_Transtype = @Desc_Transtype

			IF @ErrCode <> 0
			BEGIN
				SELECT @ErrCode = 409
					,@ErrExtraInfo = @ErrMsg
					,@ErrMsg = 'The transaction inserted failed. Please try again.'

				GOTO ReturnLog;
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
					,@ErrExtraInfo = ERROR_MESSAGE()
					,@ErrMsg = 'The transaction inserted failed. Please try again.'

			GOTO ReturnLog;
		END CATCH

		--Update cash transaction
		BEGIN TRY
			EXEC dbo.Age_CashTransaction_Upd 
				@TransId = @TransId,
				--@AdjustCreditAmt = @AdjustCreditAmt,
				@StatusId = @StatusId,
				@ExtraInfo = @ExtraInfo,
				@TransferRefNo = @TransferRefNo,
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
						,@ErrExtraInfo = @ErrMsg
						,@ErrMsg = 'The transaction inserted failed. Please try again.'

				GOTO ReturnLog;
			END
			ELSE --Insert data for writelog
			BEGIN
				SELECT @LogData = '<R SPName="'+ COALESCE(CAST(@SPName AS VARCHAR(200)), SPACE(1)) + '" ' +
									'custid="'+ COALESCE(CAST(@custid AS VARCHAR(20)), SPACE(1)) + '" ' +
									'TransferRefNo="'+ COALESCE(CAST(@TransferRefNo AS VARCHAR(50)), SPACE(1)) + '" ' +
									'StatusId="'+ COALESCE(CAST(@StatusId AS VARCHAR(3)), SPACE(1)) + '" ' +
									--'AdjustCreditAmt="'+ COALESCE(CAST(@AdjustCreditAmt AS VARCHAR(100)), SPACE(1)) + '" ' +
									'TransId="'+ COALESCE(CAST(@TransId AS VARCHAR(20)), SPACE(1)) + '" ' +
									'IP="'+ COALESCE(CAST(@IP AS VARCHAR(50)), SPACE(1)) + '" />'

				INSERT INTO @tmp_LogData (LogTypeId, UserID, CustID, ActionID, TrackingValue)
				SELECT 3, @AgentID, @CustID, NULL, @LogData
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
				,@ErrExtraInfo = ERROR_MESSAGE()
				,@ErrMsg = 'The transaction inserted failed. Please try again.'

			GOTO ReturnLog;
		END CATCH

		-------------LOG------------
		SELECT @LogData = '<R custid="'+ COALESCE(CAST(@custid AS VARCHAR(20)), SPACE(1)) + '" ' +
							'TransferRefNo="'+ COALESCE(CAST(@TransferRefNo AS VARCHAR(50)), SPACE(1)) + '" ' +
							'StatusId="'+ COALESCE(CAST(@StatusId AS VARCHAR(3)), SPACE(1)) + '" ' +
							'AdjustCreditAmt="'+ COALESCE(CAST(@_AdjustCreditAmt AS VARCHAR(100)), SPACE(1)) + '" ' + --Don't change
							'TransId="'+ COALESCE(CAST(@TransId AS VARCHAR(20)), SPACE(1)) + '" ' +
							'IP="'+ COALESCE(CAST(@IP AS VARCHAR(50)), SPACE(1)) + '" />'

		INSERT INTO @tmp_LogData (LogTypeId, UserID, CustID, ActionID, TrackingValue)
		SELECT 2, @AgentID, @CustID, 310008, @LogData

	END
	ELSE IF @StatusId = 0 -- Revert Transaction
	BEGIN
		BEGIN TRY
			SELECT @ExtraInfo = JSON_MODIFY(ISNULL(c.ExtraInfo,'{}'), '$.ProviderId',NULL)
			FROM dbo.CashTransaction c WITH (NOLOCK)
			WHERE c.TransId = @TransId

			EXEC dbo.Age_CashTransaction_Upd 
				@TransId = @TransId,
				@PaymentType = 0,
				@PaymentFrom = '',
				@Remark = '',
				@PaySlip = 0x,
				@IsClearPaymentMethod = 1,
				@ExtraInfo = @ExtraInfo,
				@ErrCode = @ErrCode OUTPUT,
				@ErrMsg = @ErrMsg OUTPUT

			IF @ErrCode <> 0
			BEGIN
				SELECT @ErrCode = 409
						,@ErrExtraInfo = @ErrMsg
						,@ErrMsg = 'The transaction inserted failed. Please try again.'

				GOTO ReturnLog;
			END
			ELSE --Insert data for writelog
			BEGIN
				SELECT @LogData = '<R SPName="'+ COALESCE(CAST(@SPName AS VARCHAR(200)), SPACE(1)) + '" ' +
									'custid="'+ COALESCE(CAST(@custid AS VARCHAR(20)), SPACE(1)) + '" ' +
									'PaymentType="'+ COALESCE(CAST(0 AS VARCHAR(20)), SPACE(1)) + '" ' +
									'PaymentFrom="'+ COALESCE(CAST('' AS VARCHAR(100)), SPACE(1)) + '" ' +
									'TransId="'+ COALESCE(CAST(@TransId AS VARCHAR(20)), SPACE(1)) + '" ' +
									'IP="'+ COALESCE(CAST(@IP AS VARCHAR(50)), SPACE(1)) + '" />'

				INSERT INTO @tmp_LogData (LogTypeId, UserID, CustID, ActionID, TrackingValue)
				SELECT 2, @AgentID, @CustID, 310010, @LogData
			END
		END TRY
		BEGIN CATCH
			SELECT @ErrCode = 409
				,@ErrExtraInfo = ERROR_MESSAGE()
				,@ErrMsg = 'The transaction inserted failed. Please try again.'

			GOTO ReturnLog;
		END CATCH
	END

	ReturnLog:
	--Unlock transaction
	EXEC dbo.Age_CashDeposit_CheckingProcess
		@TransId = @TransId,
		@IsRelease = 1

	SELECT *
	FROM @tmp_LogData t

    SET NOCOUNT OFF;
END;