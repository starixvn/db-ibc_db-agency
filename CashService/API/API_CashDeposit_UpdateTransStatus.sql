/*<info serverAlias="DBSIC-bodb02" executers="asv_CashService,wsv_CashService" selecters="" viewers="" isFunction="0" isNested=""></info>*/
ALTER PROCEDURE dbo.API_CashDeposit_UpdateTransStatus
(
    @CustID INT,
    @AgentID INT,
	@TransId BIGINT,
	@StatusId TINYINT,
	@SiteDBGroupID SMALLINT = 3,
    @AgentGivenCredit MONEY,
    @CreditMembers_GivenCredit MONEY,
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
*/ 
BEGIN
    SET NOCOUNT ON;

	DECLARE @TransferRefNo BIGINT = NULL
		,@LogData VARCHAR(MAX)
		,@LogData_Old VARCHAR(MAX)
		,@LogDataMask VARCHAR(MAX)
		,@AdjustCreditAmt	MONEY 
		,@_AdjustCreditAmt	MONEY 
		,@TransId_From	BIGINT = NULL
		,@TransId_To	BIGINT = NULL
		,@Amount MONEY = NULL
		,@_statusId TINYINT
		,@TransactionTypeID TINYINT
		,@_ProviderTransId VARCHAR(100)
		,@ExtraInfo NVARCHAR(1000)
		,@PaymentType	TINYINT
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
		, @_statusId = c.StatusId
		, @TransactionTypeID = c.TransactionTypeID
		, @PaymentType = c.PaymentType
		, @_AdjustCreditAmt = c.AdjustCreditAmt
		, @TransferRefNo = c.TransferRefNo
		, @_ProviderTransId = JSON_VALUE(c.ExtraInfo, '$.ProviderTransId') 
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
		OR @TransactionTypeID NOT IN (2) --auto deposit
		OR ISNULL(@StatusId,0) NOT IN (3,4,5,6)
	BEGIN
		SELECT @ErrCode = 409, @ErrMsg = 'The transaction inserted failed. Please try again.'
		RETURN
	END

	IF ISNULL(@ProviderTransId,'') <> ISNULL(@_ProviderTransId,'') AND @PaymentType = 1 AND @StatusId <> 0 -- Payment Gateway validate ProviderTransId
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

	--IF ISNULL(@ProviderTransId,'') <> ''
	--	SELECT @ExtraInfo = JSON_MODIFY(ISNULL(c.ExtraInfo,'{}'), '$.ProviderTransId',@ProviderTransId)
	--	FROM dbo.CashTransaction c WITH (NOLOCK)
	--	WHERE c.TransId = @TransId

	SELECT @LogData_Old = '<R custid="'+ COALESCE(CAST(@custid AS VARCHAR(20)), SPACE(1)) + '" ' +
							'TransferRefNo="'+ COALESCE(CAST(@TransferRefNo AS VARCHAR(50)), SPACE(1)) + '" ' +
							'StatusId="'+ COALESCE(CAST(@_statusId AS VARCHAR(3)), SPACE(1)) + '" ' +
							'AdjustCreditAmt="'+ COALESCE(CAST(@_AdjustCreditAmt AS VARCHAR(100)), SPACE(1)) + '" ' +
							'TransId="'+ COALESCE(CAST(@TransId AS VARCHAR(20)), SPACE(1)) + '" ' +
							'IP="'+ COALESCE(CAST(@IP AS VARCHAR(50)), SPACE(1)) + '" />'

	IF @StatusId = 4 --Completed
	BEGIN
		--Validate the input data
		IF @PaymentType <> 1 -- via payment gateway
		BEGIN
			BEGIN TRY
				BEGIN
					EXEC dbo.Age_CashDeposit_Validate 
							@CustID = @CustID,
							@UplineID = @AgentID,
							@AgentGivenCredit = @AgentGivenCredit,
							@CreditMembers_GivenCredit = @CreditMembers_GivenCredit,
							@Amount = @Amount,
							@ErrCode = @ErrCode OUTPUT,
							@ErrMsg = @ErrMsg OUTPUT

					IF @ErrCode <> 0
					BEGIN
						SELECT @ErrCode = 409
						,@ErrExtraInfo = @ErrMsg
						,@ErrMsg = 'The transaction inserted failed. Please try again.'

						GOTO ReturnLog;
					END
				END
			END TRY
			BEGIN CATCH
				SELECT @ErrCode = 409
					,@ErrExtraInfo = ERROR_MESSAGE()
					,@ErrMsg = 'The transaction inserted failed. Please try again.'
				GOTO ReturnLog;
			END CATCH
		END

		--Insert transfer details
		BEGIN TRY
			SELECT @Desc_Transtype = 'Approve Deposit - '

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
				SELECT 1, @CustID, @CustID, @AgentID, @IP, @LogData
			END
		END TRY
		BEGIN CATCH
			SELECT @ErrCode = 409
				,@ErrExtraInfo = ERROR_MESSAGE()
				,@ErrMsg = 'The transaction inserted failed. Please try again.'

			GOTO ReturnLog;
		END CATCH

		--Adjust accumulated credit
		IF @PaymentType <> 1
		BEGIN	
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
										'ActionType="'+ COALESCE(CAST(1 AS VARCHAR(20)), SPACE(1)) + '" ' +
										'Amount="'+ COALESCE(CAST(@Amount AS VARCHAR(100)), SPACE(1)) + '" ' +
										'AdjustCreditAmt="'+ COALESCE(CAST(@AdjustCreditAmt AS VARCHAR(100)), SPACE(1)) + '" ' +
										'TransId="'+ COALESCE(CAST(@TransId AS VARCHAR(20)), SPACE(1)) + '" ' +
										'IP="'+ COALESCE(CAST(@IP AS VARCHAR(50)), SPACE(1)) + '" />'

					INSERT INTO @tmp_LogData (LogTypeId, UserID, CustID, ActionID, TrackingValue)
					SELECT 2, @CustID, @CustID, NULL, @LogData
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
		END

		--Update cash transaction
		BEGIN TRY
			EXEC dbo.Age_CashTransaction_Upd 
				@TransId = @TransId,
				@StatusId = @StatusId,
				@TransferRefNo	= @TransferRefNo,
				@AdjustCreditAmt = @AdjustCreditAmt,
				@ExtraInfo = @ExtraInfo,
				@ErrCode = @ErrCode OUTPUT,
				@ErrMsg = @ErrMsg OUTPUT

			IF @ErrCode <> 0
			BEGIN
				--Rollback Transfer & CashAccumulatedCredit
				EXEC dbo.Age_CashService_Balance_Rollback
					@Type = 1,
					@TransId = 0,
					@Custid = @CustID,
					@TransId_From = @TransId_From,
					@TransId_To = @TransId_To,
					@TransferAmount = @Amount,
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
									'TransferRefNo="'+ COALESCE(CAST(@TransferRefNo AS VARCHAR(50)), SPACE(1)) + '" ' +
									'StatusId="'+ COALESCE(CAST(@StatusId AS VARCHAR(3)), SPACE(1)) + '" ' +
									'AdjustCreditAmt="'+ COALESCE(CAST(@AdjustCreditAmt AS VARCHAR(100)), SPACE(1)) + '" ' +
									'TransId="'+ COALESCE(CAST(@TransId AS VARCHAR(20)), SPACE(1)) + '" ' +
									'IP="'+ COALESCE(CAST(@IP AS VARCHAR(50)), SPACE(1)) + '" />'

				INSERT INTO @tmp_LogData (LogTypeId, UserID, CustID, ActionID, TrackingValue)
				SELECT 2, @CustID, @CustID, NULL, @LogData
			END
		END TRY
		BEGIN CATCH
			--Rollback Transfer & CashAccumulatedCredit
			EXEC dbo.Age_CashService_Balance_Rollback
				@Type = 1,
				@TransId = 0,
				@Custid = @CustID,
				@TransId_From = @TransId_From,
				@TransId_To = @TransId_To,
				@TransferAmount = @Amount,
				@AdjustCreditAmt = @AdjustCreditAmt,
				@CashAccumCreditTbl	= @CashAccumCreditTbl OUTPUT

			SELECT @ErrCode = 409
						,@ErrExtraInfo = ERROR_MESSAGE()
						,@ErrMsg = 'The transaction inserted failed. Please try again.'

			GOTO ReturnLog;
		END CATCH

		------------------LOG-----------------------
		SELECT @LogData = '<R custid="'+ COALESCE(CAST(@custid AS VARCHAR(20)), SPACE(1)) + '" ' +
							'TransferRefNo="'+ COALESCE(CAST(@TransferRefNo AS VARCHAR(50)), SPACE(1)) + '" ' +
							'StatusId="'+ COALESCE(CAST(@StatusId AS VARCHAR(3)), SPACE(1)) + '" ' +
							'AdjustCreditAmt="'+ COALESCE(CAST(ISNULL(@AdjustCreditAmt,@_AdjustCreditAmt) AS VARCHAR(100)), SPACE(1)) + '" ' +
							'TransId="'+ COALESCE(CAST(@TransId AS VARCHAR(20)), SPACE(1)) + '" ' +
							'IP="'+ COALESCE(CAST(@IP AS VARCHAR(50)), SPACE(1)) + '" />'

		INSERT INTO @tmp_LogData (LogTypeId, UserID, CustID, ActionID, TrackingValue,TrackingValue2)
		SELECT 2, @CustID, @CustID, 310007, @LogData, @LogData_Old
	END
	ELSE IF @StatusId IN(3,5,6)
	BEGIN
		-- Adjust accumulated credit
		IF @PaymentType = 1-- Payment Gateway
		BEGIN
			BEGIN TRY
				EXEC dbo.Age_CashAccumulatedCredit_Adjust 
					@CustID = @CustID,
					@ActionType = 4, --Revert Deposit
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
										'ActionType="'+ COALESCE(CAST(4 AS VARCHAR(20)), SPACE(1)) + '" ' +
										'Amount="'+ COALESCE(CAST(@Amount AS VARCHAR(100)), SPACE(1)) + '" ' +
										'AdjustCreditAmt="'+ COALESCE(CAST(@AdjustCreditAmt AS VARCHAR(100)), SPACE(1)) + '" ' +
										'TransId="'+ COALESCE(CAST(@TransId AS VARCHAR(20)), SPACE(1)) + '" ' +
										'IP="'+ COALESCE(CAST(@IP AS VARCHAR(50)), SPACE(1)) + '" />'

					INSERT INTO @tmp_LogData (LogTypeId, UserID, CustID, ActionID, TrackingValue)
					SELECT 2, @CustID, @CustID, NULL, @LogData
				END
			END TRY
			BEGIN CATCH
				SELECT @ErrCode = 409
						,@ErrExtraInfo = ERROR_MESSAGE()
						,@ErrMsg = 'The transaction inserted failed. Please try again.'

				GOTO ReturnLog;
			END CATCH
		END

		--Update cash transaction
		BEGIN TRY
			EXEC dbo.Age_CashTransaction_Upd 
				@TransId = @TransId,
				@StatusId = @StatusId,
				--@AdjustCreditAmt = @AdjustCreditAmt,
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
									--'AdjustCreditAmt="'+ COALESCE(CAST('' AS VARCHAR(100)), SPACE(1)) + '" ' + 
									'TransId="'+ COALESCE(CAST(@TransId AS VARCHAR(20)), SPACE(1)) + '" ' +
									'IP="'+ COALESCE(CAST(@IP AS VARCHAR(50)), SPACE(1)) + '" />'

				INSERT INTO @tmp_LogData (LogTypeId, UserID, CustID, ActionID, TrackingValue)
				SELECT 2, @CustID, @CustID, NULL, @LogData
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

		------------------LOG-----------------------
		SELECT @LogData = '<R custid="'+ COALESCE(CAST(@custid AS VARCHAR(20)), SPACE(1)) + '" ' +
							'TransferRefNo="'+ COALESCE(CAST(@TransferRefNo AS VARCHAR(50)), SPACE(1)) + '" ' + -- Don't change on CashTransaction
							'StatusId="'+ COALESCE(CAST(@StatusId AS VARCHAR(3)), SPACE(1)) + '" ' +
							'AdjustCreditAmt="'+ COALESCE(CAST(@_AdjustCreditAmt AS VARCHAR(100)), SPACE(1)) + '" ' + -- Don't change on CashTransaction
							'TransId="'+ COALESCE(CAST(@TransId AS VARCHAR(20)), SPACE(1)) + '" ' +
							'IP="'+ COALESCE(CAST(@IP AS VARCHAR(50)), SPACE(1)) + '" />'

		INSERT INTO @tmp_LogData (LogTypeId, UserID, CustID, ActionID, TrackingValue,TrackingValue2)
		SELECT 2, @CustID, @CustID, 310007, @LogData, @LogData_Old

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