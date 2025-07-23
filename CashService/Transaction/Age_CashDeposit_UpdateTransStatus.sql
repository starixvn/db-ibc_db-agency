/*<info serverAlias="DBSIC-bodb02" executers="asv_CashService,wsv_CashService" selecters="" viewers="" isFunction="0" isNested=""></info>*/
ALTER PROCEDURE dbo.Age_CashDeposit_UpdateTransStatus
(
    @CustID INT,
    @AgentID INT,
	@TransId BIGINT,
	@SubAccID INT = 0,
	@StatusId TINYINT,
	@SiteDBGroupID SMALLINT = 3,
    @AgentGivenCredit MONEY,
    @CreditMembers_GivenCredit MONEY,
	@New_Amount MONEY = 0,
    @IP VARCHAR(50) = '',
	@Remark NVARCHAR(1000) = NULL,
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

	DECLARE @TransferRefNo BIGINT = NULL
		,@LogData VARCHAR(MAX)
		,@LogDataMask VARCHAR(MAX)
		,@AdjustCreditAmt	MONEY = NULL
		,@TransId_From	BIGINT = NULL
		,@TransId_To	BIGINT = NULL
		,@Amount MONEY = NULL
		,@_statusId TINYINT
		,@TransactionTypeID TINYINT
		,@PaymentType TINYINT

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

	SELECT @Amount = IIF(@New_Amount <> 0, @New_Amount, c.Amount)
		, @_statusId = c.StatusId
		, @TransactionTypeID = c.TransactionTypeID
		, @PaymentType = c.PaymentType
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
		OR @PaymentType = 1 -- Payment Gateway
		OR @TransactionTypeID NOT IN (1,2) --deposit
		OR ISNULL(@StatusId,0) NOT IN (3,4,5,6)
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

	--Process update
	IF @StatusId = 4 --Completed
	BEGIN
		--Validate the input data
		BEGIN TRY
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
				GOTO Writelog;
			END
		END TRY
		BEGIN CATCH
			SELECT @ErrCode = 409, @ErrMsg = 'The transaction inserted failed. Please try again.'
			GOTO Writelog;
		END CATCH

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

		--Adjust accumulated credit
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
					,@ErrMsg = 'The transaction inserted failed. Please try again.'

				GOTO Writelog;
			END
			ELSE --Insert data for writelog
			BEGIN
				SELECT @LogData = '<R custid="'+ COALESCE(CAST(@custid AS VARCHAR(20)), SPACE(1)) + '" ' +
									'ActionType="'+ COALESCE(CAST(1 AS VARCHAR(20)), SPACE(1)) + '" ' +
									'Amount="'+ COALESCE(CAST(@Amount AS VARCHAR(100)), SPACE(1)) + '" ' +
									'AdjustCreditAmt="'+ COALESCE(CAST(@AdjustCreditAmt AS VARCHAR(100)), SPACE(1)) + '" />'

				INSERT INTO @tmp_LogData (LogTypeId, UserID, CustID, ActionID, TrackingValue)
				SELECT 3, @AgentID, @CustID, 310002, @LogData
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

		--Update cash transaction
		BEGIN TRY
			EXEC dbo.Age_CashTransaction_Upd 
				@TransId = @TransId,
				@StatusId = @StatusId,
				@OperatedBy = @AgentID,
				@TransferRefNo	= @TransferRefNo,
				@AdjustCreditAmt = @AdjustCreditAmt,
				@Remark = @Remark,
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
						,@ErrMsg = 'The transaction inserted failed. Please try again.'

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
				SELECT 3, @AgentID, @CustID, 310003, @LogData
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
						,@ErrMsg = 'The transaction inserted failed. Please try again.'

			GOTO Writelog;
		END CATCH
	END
	ELSE IF @StatusId IN(3,5,6)
	BEGIN
		--Update cash transaction
		BEGIN TRY
			EXEC dbo.Age_CashTransaction_Upd 
				@TransId = @TransId,
				@StatusId = @StatusId,
				@OperatedBy = @AgentID,
				@Remark = @Remark,
				@ErrCode = @ErrCode OUTPUT,
				@ErrMsg = @ErrMsg OUTPUT

			IF @ErrCode <> 0
			BEGIN
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
				SELECT 3, @AgentID, @CustID, 310003, @LogData
			END
		END TRY
		BEGIN CATCH
			SELECT @ErrCode = 409
						,@ErrMsg = 'The transaction inserted failed. Please try again.'

			GOTO Writelog;
		END CATCH
	END

	Writelog:
	--Unlock transaction
	EXEC dbo.Age_CashDeposit_CheckingProcess
					@TransId = @TransId,
					@IsRelease = 1

	SELECT *
	FROM @tmp_LogData t

    SET NOCOUNT OFF;
END;