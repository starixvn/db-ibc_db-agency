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

	Parameter's Explanation:	
*/ 
BEGIN
    SET NOCOUNT ON;

	DECLARE @TransferRefNo BIGINT = NULL
		,@LogData VARCHAR(MAX)
		,@LogDataMask VARCHAR(MAX)
		,@AdjustCreditAmt	MONEY = 0
		,@TransId_From	BIGINT = NULL
		,@TransId_To	BIGINT = NULL
		,@Amount MONEY = NULL
		,@_CustId INT = NULL
		,@_statusId TINYINT
		,@TransactionTypeID TINYINT

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

	SELECT @Amount = c.Amount
		, @_CustId = c.CustId
		, @_statusId = c.StatusId
		, @TransactionTypeID = c.TransactionTypeID
	FROM dbo.CashTransaction c WITH (NOLOCK)
	WHERE c.TransId = @TransId

	IF @CustID <> @_CustId OR @_CustId IS NULL OR @_statusId <> 2 OR @TransactionTypeID NOT IN (1,2) --deposit
	BEGIN
		SELECT @ErrCode = 405, @ErrMsg = 'Invalid parameters.'
		RETURN
	END

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
			SELECT @ErrCode = 405, @ErrMsg = 'Invalid parameters.'
				,@ErrExtraInfo = @ErrMsg
			RETURN
		END
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = 405, @ErrMsg = 'Invalid parameters.'
				,@ErrExtraInfo = ERROR_MESSAGE()
		RETURN
	END CATCH

	IF @StatusId = 4 --Completed
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
					,@ErrExtraInfo = @ErrMsg
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
				,@ErrExtraInfo = ERROR_MESSAGE()
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
					,@ErrExtraInfo = @ErrMsg
					,@ErrMsg = 'The transaction inserted failed. Please try again.'

				GOTO Writelog;
			END
			ELSE --Insert data for writelog
			BEGIN
				SELECT @LogData = '< custid="'+ COALESCE(CAST(@custid AS VARCHAR(20)), SPACE(1)) + '" ' +
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
					,@ErrExtraInfo = ERROR_MESSAGE()
					,@ErrMsg = 'The transaction inserted failed. Please try again.'

			GOTO Writelog;
		END CATCH
	END

    --Update cash transaction
	BEGIN TRY
		EXEC dbo.Age_CashTransaction_Upd 
			@TransId = @TransId,
			@StatusId = @StatusId,
			@TransferRefNo	= @TransferRefNo,
			@AdjustCreditAmt = @AdjustCreditAmt,
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
				@TransferAmount = @AdjustCreditAmt

			SELECT @ErrCode = 409
					,@ErrExtraInfo = @ErrMsg
					,@ErrMsg = 'The transaction inserted failed. Please try again.'

			GOTO Writelog;
		END
		ELSE --Insert data for writelog
		BEGIN
			SELECT @LogData = '< custid="'+ COALESCE(CAST(@custid AS VARCHAR(20)), SPACE(1)) + '" ' +
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
			@TransferAmount = @AdjustCreditAmt

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