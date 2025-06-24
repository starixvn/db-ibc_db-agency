/*<info serverAlias="DBSIC-bodb02" executers="asv_CashService,wsv_CashService" selecters="" viewers="" isFunction="0" isNested=""></info>*/
ALTER PROCEDURE [dbo].[Age_CashTransaction_RevertDeposit_Upd]  
	@TransId BIGINT,
	@SiteDBGroupID	SMALLINT,
	@Remark NVARCHAR(2000) = NULL,
	@UserId INT = 0, 
	@IP VARCHAR(50) = '',
	@ErrCode	INT = 0 OUTPUT,
	@ErrMsg	VARCHAR(2000) = NULL OUTPUT,
	@CashAccumCreditTbl	VARCHAR(MAX) = NULL OUTPUT
AS  
/*
	Created: 20250502@Max		
	Task: Alpha - Agency Cash Service [redmine: #223896] 
	DB:  DBSIC-bodb02
		
	Revisions:
		- 20250502@Max: Alpha - Agency Cash Service [redmine: #223896] 
		- 20250603@Max: Alpha - Agency Cash Service - Sprint 3 [redmine: #223896] 
		- 20250611@Max: Alpha - Agency Cash Service - Sprint 4 [redmine: #223896] 

	Parameter's Explanation:
*/ 
BEGIN  
    SET NOCOUNT ON; 

	DECLARE @StatusId_before TINYINT
		,@AdjustAmount MONEY
		,@RevertRefNo BIGINT
		,@CustId INT
		,@LogData VARCHAR(MAX)
		,@LogDataMask VARCHAR(MAX)
		,@TransactionTypeId TINYINT
		,@TransferRefNo BIGINT
		,@TransId_From BIGINT = 0
		,@TransId_To BIGINT = 0

	IF @SiteDBGroupID <> dbo.f_Get_SiteDBGroupID() OR @SiteDBGroupID IS NULL
	BEGIN
		SELECT @ErrCode = 405, @ErrMsg = 'Invalid parameters.'

		RETURN
	END

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

	SELECT @StatusId_before = StatusId, @AdjustAmount = c.AdjustCreditAmt, @RevertRefNo = c.TransferRefNo, @CustId = c.CustId, @TransactionTypeId = c.TransactionTypeID
	FROM dbo.CashTransaction c WITH (NOLOCK)
	WHERE c.TransId = @TransId

	IF @StatusId_before = 4
	BEGIN
		 -- Step 1: Validate the input data
		BEGIN TRY
			EXEC dbo.Age_CashWithdrawal_Validate 
				@CustID = @CustID,
				@UplineID = @UserId,
				@Amount = @AdjustAmount,
				@ErrCode = @ErrCode OUTPUT,
				@ErrMsg = @ErrMsg OUTPUT

			IF @ErrCode <> 0
			BEGIN
				RETURN
			END
		END TRY
		BEGIN CATCH
			SELECT @ErrCode = 409
				,@ErrMsg = 'The transaction inserted failed. Please try again.'

			RETURN
		END CATCH

		--Revert deposit need to call SP withdrawal 
		BEGIN TRY
			EXEC dbo.Age_CashWithdrawal_ManualAdd_InsTransfer 
				@CustID = @CustID,
				@UplineID = @UserId,
				@Amount = @AdjustAmount,
				@IP = @IP,
				@RevertRefNo = @RevertRefNo,
				@ErrCode = @ErrCode OUTPUT,
				@ErrMsg = @ErrMsg OUTPUT,
				@TransId_From = @TransId_From OUTPUT,
				@TransId_To = @TransId_To OUTPUT

			IF @ErrCode <> 0
			BEGIN
				SELECT @ErrCode = 409
					,@ErrMsg = 'The transaction inserted failed. Please try again.'
				RETURN
			END
			ELSE --Insert data for writelog
			BEGIN
				SELECT @LogData = 'Insert revert trans custid = ' + CONVERT(VARCHAR(20), @custid) + ', bettype = ' + CONVERT(VARCHAR(20), 31002) + ', amount = ' + CONVERT(VARCHAR(20), @AdjustAmount) + ', Ref.No: ' + CONVERT(VARCHAR(20), @RevertRefNo)

				INSERT INTO @tmp_LogData (LogTypeId, UserID, FromCustID, ToCustID, IP, Doing)
				SELECT 1, @UserId, @UserId, @CustID, @IP, @LogData
			END
		END TRY
		BEGIN CATCH
			SELECT @ErrCode = 409
				,@ErrMsg = 'The transaction inserted failed. Please try again.'

			RETURN
		END CATCH

		-- Adjust accumulated credit
		BEGIN TRY
			EXEC dbo.Age_CashAccumulatedCredit_Adjust 
				@CustID = @CustID,
				@ActionType = 4, --Revert Deposit
				@Amount = @AdjustAmount,
				@ErrCode = @ErrCode OUTPUT,
				@ErrMsg	= @ErrMsg OUTPUT,
				@CashAccumCreditTbl	= @CashAccumCreditTbl OUTPUT

			IF @ErrCode <> 0
			BEGIN
				--Rollback transaction transfer withdrawal when revert deposit
				EXEC dbo.Age_CashService_Balance_Rollback
					@Type = 2, 
					@TransId = 0,
					@Custid = @CustID,
					@TransId_From = @TransId_From,
					@TransId_To = @TransId_To,
					@TransferAmount = @AdjustAmount

				SELECT @ErrCode = 409
					,@ErrMsg = 'The transaction inserted failed. Please try again.'

				RETURN
			END
			ELSE --Insert data for writelog
			BEGIN
				SELECT @LogData = '< custid="'+ COALESCE(CAST(@custid AS VARCHAR(20)), SPACE(1)) + '" ' +
									'ActionType="'+ COALESCE(CAST(4 AS VARCHAR(20)), SPACE(1)) + '" ' +
									'Amount="'+ COALESCE(CAST(@AdjustAmount AS VARCHAR(100)), SPACE(1)) + '" ' + '" />'

				INSERT INTO @tmp_LogData (LogTypeId, UserID, CustID, ActionID, TrackingValue)
				SELECT 3, @UserId, @CustID, 310102, @LogData
			END
		END TRY
		BEGIN CATCH
			--Rollback transaction transfer withdrawal when revert deposit
			EXEC dbo.Age_CashService_Balance_Rollback
				@Type = 2, 
				@TransId = 0,
				@Custid = @CustID,
				@TransId_From = @TransId_From,
				@TransId_To = @TransId_To,
				@TransferAmount = @AdjustAmount

			SELECT @ErrCode = 409
				,@ErrMsg = 'The transaction inserted failed. Please try again.'
		END CATCH
	END

	--Update transaction status
	BEGIN TRY
		EXEC dbo.Age_CashTransaction_Upd 
			@TransId = @TransId,
			@StatusId = 2, --Pending
			@Remark = @Remark,
			@ErrCode = @ErrCode OUTPUT,
			@ErrMsg = @ErrMsg OUTPUT

		IF @ErrCode <> 0
		BEGIN
			--Rollback transfer & CashAccumulatedCredit
			EXEC dbo.Age_CashService_Balance_Rollback
				@Type = 2, 
				@TransId = 0,
				@Custid = @CustID,
				@TransId_From = @TransId_From,
				@TransId_To = @TransId_To,
				@TransferAmount = @AdjustAmount,
				@AdjustCreditAmt = @AdjustAmount

			GOTO Writelog;
		END
		ELSE --Insert data for writelog
		BEGIN
			SELECT @LogData = '< custid="'+ COALESCE(CAST(@custid AS VARCHAR(20)), SPACE(1)) + '" ' +
								'TransId="'+ COALESCE(CAST(@TransId AS VARCHAR(20)), SPACE(1)) + '" ' +
								'Before_StatusId="'+ COALESCE(CAST(@StatusId_before AS VARCHAR(3)), SPACE(1)) + '" ' +
								'After_StatusId="'+ COALESCE(CAST(2 AS VARCHAR(3)), SPACE(1)) + '" />'

			INSERT INTO @tmp_LogData (LogTypeId, UserID, CustID, ActionID, TrackingValue)
			SELECT 2, @UserId, @CustID, 310101, @LogData
		END
	END TRY
	BEGIN CATCH
		--Rollback transfer & CashAccumulatedCredit
		EXEC dbo.Age_CashService_Balance_Rollback
			@Type = 2, 
			@TransId = 0,
			@Custid = @CustID,
			@TransId_From = @TransId_From,
			@TransId_To = @TransId_To,
			@TransferAmount = @AdjustAmount,
			@AdjustCreditAmt = @AdjustAmount

		SELECT @ErrCode = 409
				,@ErrMsg = 'The transaction inserted failed. Please try again.'

		RETURN
	END CATCH

	Writelog:
	SELECT *
	FROM @tmp_LogData t

END  