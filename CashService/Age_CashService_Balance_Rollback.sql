/*<info serverAlias="DBSIC-bodb02" executers="asv_CashService,wsv_CashService" selecters="" viewers="" isFunction="0" isNested=""></info>*/
ALTER PROCEDURE [dbo].[Age_CashService_Balance_Rollback] 
	@Type	TINYINT,
	@TransId BIGINT,
	@CustId INT = 0,
	@TransId_From BIGINT = 0,	
	@TransId_To BIGINT = 0,	
	@TransferAmount	MONEY = 0,
	@AdjustCreditAmt MONEY = 0,
	@ErrCode	INT = 0 OUTPUT,
	@ErrMsg	VARCHAR(2000) = NULL OUTPUT
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

	--Rollback CashTransaction --> Delete
	IF @TransId <> 0
	BEGIN
		BEGIN TRY
			DELETE t
			OUTPUT deleted.TransId, [dbo].[f_GetDateTime2]()
			INTO dbo.CashTransaction_Del_InHouse(TransId, RepUpdateTime)
			FROM dbo.CashTransaction t
			WHERE t.TransID = @TransId
		END TRY
		BEGIN CATCH
			SELECT @ErrCode = ERROR_NUMBER()
			,@ErrMsg = ERROR_MESSAGE()

			RETURN
		END CATCH
	END

	--Rollback Transfer & Balance
	BEGIN TRY
		--TODO: Rollback BalanceCredit (deposit)
		IF @Type = 1
		BEGIN
			EXEC Dot_BalanceDebitUpd @CustID = @CustID, @balance = @TransferAmount, @type = 2, @IsForced = 1
		END

		--TODO: Manually rollback transfer
		BEGIN
			UPDATE dbo.Transfer WITH(ROWLOCK)
			SET	custid = 0, 
				Recommend = 0, 
				MRecommend = 0, 
				SRecommend = 0, 
				Winlost = 0, 
				Actual_Stake = 0, 
				RepUpdateTime = SYSDATETIME()
			WHERE TransId IN (@TransId_From, @TransId_To)
		END

		--TODO: Rollback BalanceDebit (Withdrawal)
		IF @Type = 2
		BEGIN 
 			EXEC Dot_BalanceCreditUpd @CustID = @CustID, @balance = @TransferAmount, @type = 2
		END

		--TODO: Manually rollback transferInfo
		BEGIN
			UPDATE TransferInfo WITH(ROWLOCK)
			SET		IsDel = 1,  RepUpdateTime = SYSDATETIME()
			WHERE TransId IN (@TransId_From, @TransId_To)
		END
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = ERROR_NUMBER()
			,@ErrMsg = ERROR_MESSAGE()
	END CATCH

	-- Adjust accumulated credit
	BEGIN TRY
		IF @Type IN (1,3) AND @AdjustCreditAmt <> 0 --Manual Deposit or Auto Deposit
		BEGIN
			EXEC dbo.Age_CashAccumulatedCredit_Adjust 
				@CustID = @CustID,
				@ActionType = 4, --Revert Deposit
				@Amount = @AdjustCreditAmt,
				@ErrCode = @ErrCode OUTPUT,
				@ErrMsg	= @ErrMsg OUTPUT

			IF @ErrCode <> 0
			BEGIN
				RETURN
			END
		END
		ELSE IF @Type = 2 AND @AdjustCreditAmt <> 0
		BEGIN
			EXEC dbo.Age_CashAccumulatedCredit_Adjust 
				@CustID = @CustID,
				@ActionType = 5, --Revert Withdraw
				@Amount = @AdjustCreditAmt,
				@ErrCode = @ErrCode OUTPUT,
				@ErrMsg	= @ErrMsg OUTPUT

			IF @ErrCode <> 0
			BEGIN
				RETURN
			END
		END
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = ERROR_NUMBER()
			,@ErrMsg = ERROR_MESSAGE()
	END CATCH

END  