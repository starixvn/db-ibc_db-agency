/*<info serverAlias="DBSIC-bodb02" executers="asv_CashService,wsv_CashService" selecters="" viewers="" isFunction="0" isNested=""></info>*/
ALTER PROCEDURE [dbo].[Age_CashTransaction_RevertWithdrawal_Upd]  
	@TransId BIGINT,
	@CustID INT,
	@AgentID INT = NULL,
	@SiteDBGroupID	SMALLINT = 3,
	@AgentGivenCredit MONEY = NULL,
    @CreditMembers_GivenCredit MONEY = NULL,
	@SubAccID INT = 0,
	@Remark NVARCHAR(2000) = NULL,
	@UserId INT = 0, 
	@IP VARCHAR(50) = '',
	@ErrCode	INT = 0 OUTPUT,
	@ErrMsg	VARCHAR(2000) = NULL OUTPUT,
	@CashAccumCreditTbl	VARCHAR(MAX) = NULL OUTPUT,
	@AgentAvailableCredit MONEY = 0 OUTPUT,
	@CashBalance MONEY = NULL OUTPUT
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

	DECLARE @StatusId_before TINYINT
		,@AdjustCreditAmt MONEY
		,@LogData VARCHAR(MAX)
		,@LogData_Old VARCHAR(MAX)
		,@TransactionTypeId TINYINT
		,@Amount MONEY
		--Transfer
		,@TransferRefNo BIGINT
		,@TransId_From	BIGINT 
		,@TransId_To	BIGINT
		,@PaymentType	tinyint
		,@SPNAME		VARCHAR(200)
		,@Desc_Transtype   VARCHAR(100)
		,@SubAccName	VARCHAR(30) = ''
		,@AdjustCreditAmt_ABS MONEY

	IF @SiteDBGroupID <> dbo.f_Get_SiteDBGroupID() OR @SiteDBGroupID IS NULL
	BEGIN
		SELECT @ErrCode = 405, @ErrMsg = 'Invalid parameters.'

		RETURN
	END

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
		RETURN
	END

	SELECT @StatusId_before = c.StatusId
		, @AdjustCreditAmt = c.AdjustCreditAmt
		, @TransferRefNo = c.TransferRefNo
		, @TransactionTypeId = c.TransactionTypeID
		, @Amount = c.Amount
		, @PaymentType = c.PaymentType
		, @AdjustCreditAmt_ABS = ABS(c.AdjustCreditAmt)
	FROM dbo.CashTransaction c WITH (NOLOCK)
	WHERE c.TransId = @TransId
		AND c.custid = @CustID

	IF @TransactionTypeID IS NULL
	BEGIN
		SELECT @ErrCode = 416
			, @ErrMsg = 'Invalid Transaction [' + ISNULL(CAST(@TransId AS VARCHAR(20)),'') + ', ' + ISNULL(CAST(@custid AS VARCHAR(10)),'') + ']'
		RETURN
	END

	IF ISNULL(@TransactionTypeId,0) <> 3  -- Withdrawal
		OR ISNULL(@Amount,0) = 0 
		OR @PaymentType = 1 -- Payment Gateway do not revert
		OR @StatusId_before NOT IN (3,4,5) -- only revert expired/completed/rejected
	BEGIN
		SELECT @ErrCode = 409
				,@ErrMsg = 'The transaction inserted failed. Please try again.'
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

	SELECT @LogData_Old = '<R SPName="'+ COALESCE(CAST(@SPName AS VARCHAR(200)), SPACE(1)) + '" ' +
							'custid="'+ COALESCE(CAST(@custid AS VARCHAR(20)), SPACE(1)) + '" ' +
							'SubAccName="'+ COALESCE(CAST(@SubAccName AS VARCHAR(30)), SPACE(1)) + '" ' +
							'StatusId="'+ COALESCE(CAST(@StatusId_before AS VARCHAR(3)), SPACE(1)) + '" ' +
							'TransId="'+ COALESCE(CAST(@TransId AS VARCHAR(20)), SPACE(1)) + '" ' +
							'IP="'+ COALESCE(CAST(@IP AS VARCHAR(50)), SPACE(1)) + '" />'

	--Step 1: Adjust accumulated credit
	IF @StatusId_before = 4 AND @AdjustCreditAmt <> 0 -- completed--> pending
	BEGIN
		--Validate the input data
		BEGIN TRY
			EXEC dbo.Age_CashDeposit_Validate 
				@CustID = @CustID,
				@UplineID = @AgentID,
				@AgentGivenCredit = @AgentGivenCredit,
				@CreditMembers_GivenCredit = @CreditMembers_GivenCredit,
				@Amount = @AdjustCreditAmt_ABS,
				@ErrCode = @ErrCode OUTPUT,
				@ErrMsg = @ErrMsg OUTPUT,
				@AgentAvailableCredit= @AgentAvailableCredit OUTPUT

			IF @ErrCode <> 0
			BEGIN
				GOTO ReturnLog;
			END
		END TRY
		BEGIN CATCH
			SELECT @ErrCode = 409, @ErrMsg = 'The transaction inserted failed. Please try again.'
			GOTO ReturnLog;
		END CATCH
			
		-- Adjust accumulated credit
		BEGIN TRY
			EXEC dbo.Age_CashAccumulatedCredit_Adjust 
				@CustID = @CustID,
				@ActionType = 5, --Revert Withdraw
				@Amount = @AdjustCreditAmt,
				@ErrCode = @ErrCode OUTPUT,
				@ErrMsg	= @ErrMsg OUTPUT,
				@CashAccumCreditTbl	= @CashAccumCreditTbl OUTPUT,
				@AdjustCreditAmt= @AdjustCreditAmt OUTPUT

			IF @ErrCode <> 0
			BEGIN
				SELECT @ErrCode = 409
					,@ErrMsg = 'The transaction inserted failed. Please try again.'

				GOTO ReturnLog;
			END
			ELSE --Insert data for writelog
			BEGIN
				SELECT @LogData = '<R custid="'+ COALESCE(CAST(@custid AS VARCHAR(20)), SPACE(1)) + '" ' +
									'ActionType="'+ COALESCE(CAST(5 AS VARCHAR(20)), SPACE(1)) + '" ' +
									'Amount="'+ COALESCE(CAST(@AdjustCreditAmt AS VARCHAR(100)), SPACE(1)) + '" ' +
									'AdjustCreditAmt="'+ COALESCE(CAST(@AdjustCreditAmt AS VARCHAR(100)), SPACE(1))+ '" ' +
									'TransId="'+ COALESCE(CAST(@TransId AS VARCHAR(20)), SPACE(1)) + '" ' +
									'IP="'+ COALESCE(CAST(@IP AS VARCHAR(50)), SPACE(1)) + '" />'

				INSERT INTO @tmp_LogData (LogTypeId, UserID, CustID, ActionID, TrackingValue)
				SELECT 2, @AgentID, @CustID, NULL, @LogData
			END
		END TRY
		BEGIN CATCH
			SELECT @ErrCode = 409
				,@ErrMsg = 'The transaction inserted failed. Please try again.'
			GOTO ReturnLog;
		END CATCH
	END
	ELSE IF @StatusId_before <> 4 -- Reject/expired --> pending
	BEGIN
		BEGIN TRY
			-- Step 1: Validate cash balance
			EXEC dbo.Age_CashWithdrawal_Validate 
				@CustID = @CustID,
				@UplineID = @AgentID,
				@Amount = @Amount,
				@ErrCode = @ErrCode OUTPUT,
				@ErrMsg = @ErrMsg OUTPUT,
				@CashBalance= @CashBalance OUTPUT

			IF @ErrCode <> 0
			BEGIN
				GOTO ReturnLog;
			END
			
			SELECT @Desc_Transtype = 'Revert Withdrawal - '

			-- Step 2: Insert transfer details
			EXEC dbo.Age_CashWithdrawal_ManualAdd_InsTransfer 
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
				@SubAccName = @SubAccName,
				@Desc_Transtype = @Desc_Transtype

			IF @ErrCode <> 0
			BEGIN
				IF @ErrCode <> 406
				BEGIN
					SELECT @ErrCode = 409
						,@ErrMsg = 'The transaction inserted failed. Please try again.'
				END

				GOTO ReturnLog;
			END
			ELSE --Insert data for writelog
			BEGIN
				SELECT @LogData = 'Insert trans custid = ' + CONVERT(VARCHAR(20), @custid) + ', bettype = ' + CONVERT(VARCHAR(20), 31002) + ', amount = ' + CONVERT(VARCHAR(20), @amount) + ', Ref.No: ' + CONVERT(VARCHAR(20), @TransferRefNo)
				IF @SubAccID > 0 AND ISNULL(@SubAccName, '') <> ''
					SELECT @LogData = @LogData + ' (By ' + @SubAccName + ')'

				INSERT INTO @tmp_LogData (LogTypeId, UserID, FromCustID, ToCustID, IP, Doing)
				SELECT 1, @CustID, @AgentID, @CustID, @IP, @LogData
			END
		END TRY
		BEGIN CATCH
			SELECT @ErrCode = 409
				,@ErrMsg = 'The transaction inserted failed. Please try again.'

			GOTO ReturnLog;
		END CATCH
	END

	--Step: Update transaction status
	BEGIN TRY
		EXEC dbo.Age_CashTransaction_Upd 
			@TransId = @TransId,
			@StatusId = 2, --Pending
			@AdjustCreditAmt = 0,
			@TransferRefNo = @TransferRefNo,
			@OperatedBy = @AgentID,
			@SubAccID = @SubAccID,
			@Remark = @Remark,
			@ErrCode = @ErrCode OUTPUT,
			@ErrMsg = @ErrMsg OUTPUT

		IF @ErrCode <> 0
		BEGIN
			IF @StatusId_before = 4
			BEGIN
				--Rollback CashAccumulatedCredit
				EXEC dbo.Age_CashService_Balance_Rollback
					@Type = 1, 
					@TransId = 0,
					@Custid = @CustID,
					@AdjustCreditAmt = @AdjustCreditAmt,
					@CashAccumCreditTbl	= @CashAccumCreditTbl OUTPUT
			END
			IF @StatusId_before <> 4
			BEGIN
				--Rollback Transfer
				EXEC dbo.Age_CashService_Balance_Rollback
					@Type = 2,
					@TransId = 0,
					@Custid = @CustID,
					@TransId_From = @TransId_From,
					@TransId_To = @TransId_To,
					@TransferAmount = @Amount
			END

			SELECT @ErrCode = 409
				,@ErrMsg = 'The transaction inserted failed. Please try again.'

			GOTO ReturnLog;
		END
		ELSE --Insert data for writelog
		BEGIN
			SELECT @LogData = '<R SPName="'+ COALESCE(CAST(@SPName AS VARCHAR(200)), SPACE(1)) + '" ' +
								'custid="'+ COALESCE(CAST(@custid AS VARCHAR(20)), SPACE(1)) + '" ' +
								'SubAccName="'+ COALESCE(CAST(@SubAccName AS VARCHAR(30)), SPACE(1)) + '" ' +
								'StatusId="'+ COALESCE(CAST(2 AS VARCHAR(3)), SPACE(1)) + '" ' +
								'TransId="'+ COALESCE(CAST(@TransId AS VARCHAR(20)), SPACE(1)) + '" ' +
								'IP="'+ COALESCE(CAST(@IP AS VARCHAR(50)), SPACE(1)) + '" />'

			INSERT INTO @tmp_LogData (LogTypeId, UserID, CustID, ActionID, TrackingValue)
			SELECT 2, @AgentID, @CustID, NULL, @LogData
		END
	END TRY
	BEGIN CATCH
		IF @StatusId_before = 4
		BEGIN
			--Rollback CashAccumulatedCredit
			EXEC dbo.Age_CashService_Balance_Rollback
				@Type = 1, 
				@TransId = 0,
				@Custid = @CustID,
				@AdjustCreditAmt = @AdjustCreditAmt,
				@CashAccumCreditTbl	= @CashAccumCreditTbl OUTPUT
		END
		IF @StatusId_before <> 4
		BEGIN
			--Rollback Transfer
			EXEC dbo.Age_CashService_Balance_Rollback
				@Type = 2,
				@TransId = 0,
				@Custid = @CustID,
				@TransId_From = @TransId_From,
				@TransId_To = @TransId_To,
				@TransferAmount = @Amount
		END

		SELECT @ErrCode = 409
				,@ErrMsg = 'The transaction inserted failed. Please try again.'

		GOTO ReturnLog;
	END CATCH

	SELECT @LogData = '<R custid="'+ COALESCE(CAST(@custid AS VARCHAR(20)), SPACE(1)) + '" ' +
						'SubAccName="'+ COALESCE(CAST(@SubAccName AS VARCHAR(30)), SPACE(1)) + '" ' +
						'StatusId="'+ COALESCE(CAST(2 AS VARCHAR(3)), SPACE(1)) + '" ' +
						'TransId="'+ COALESCE(CAST(@TransId AS VARCHAR(20)), SPACE(1)) + '" ' +
						'IP="'+ COALESCE(CAST(@IP AS VARCHAR(50)), SPACE(1)) + '" />'

	INSERT INTO @tmp_LogData (LogTypeId, UserID, CustID, ActionID, TrackingValue,TrackingValue2)
	SELECT 2, @AgentID, @CustID, 310015, @LogData, @LogData_Old

	ReturnLog:
	--Unlock transaction
	EXEC dbo.Age_CashDeposit_CheckingProcess
					@TransId = @TransId,
					@IsRelease = 1

	SELECT *
	FROM @tmp_LogData t
END  
GO