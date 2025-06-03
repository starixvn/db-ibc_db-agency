/*<info serverAlias="DBSIC-bodb02" executers="asv_CashService,wsv_CashService,wsv_nap,wsv_alp,wsv_alpv,wsv_xnap" selecters="" viewers="" isFunction="0" isNested=""></info>*/
ALTER PROCEDURE [dbo].[Age_CashService_Balance_Rollback]  
	@CustID INT,
    @UplineID INT,
    @Amount MONEY,
	@ExchangeRate SMALLMONEY =	1,
	@BonusID INT = NULL,
	@IP VARCHAR(50) = '',
	@TransactionTypeId TINYINT = 0,
	@ErrCode	INT = 0 OUTPUT,
	@ErrMsg	VARCHAR(2000) = NULL OUTPUT,
	@TransferRefNo	BIGINT = NULL OUTPUT
AS  
/*
	Created: 20250502@Max		
	Task: Alpha - Agency Cash Service [redmine: #223896] 
	DB:  DBSIC-bodb02
		
	Revisions:
		- 20250502@Max: Alpha - Agency Cash Service [redmine: #223896] 

	Parameter's Explanation:
*/ 
BEGIN  
    SET NOCOUNT ON; 

	DECLARE @StatusId_before TINYINT
		,@AdjustAmount MONEY
		,@Transfer_RefNo BIGINT
		,@LogData VARCHAR(MAX)
		,@LogDataMask VARCHAR(MAX)

	BEGIN TRY
		IF @TransactionTypeId IN (1,2) --Revert deposit need to call SP withdrawal 
		BEGIN
			EXEC dbo.Age_CashWithdrawal_ManualAdd_InsTransfer 
				@CustID = @CustID,
				@UplineID = @UplineID,
				@Amount = @Amount,
				@ExchangeRate = @ExchangeRate,
				@IP = @IP,
				@ErrCode = @ErrCode OUTPUT,
				@ErrMsg = @ErrMsg OUTPUT,
				@TransferRefNo = @TransferRefNo OUTPUT
		END

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

	-- Adjust accumulated credit
	BEGIN TRY
		IF @TransactionTypeId IN (1,2) --Deposit
		BEGIN
			EXEC dbo.Age_CashAccumulatedCredit_Adjust 
				@CustID = @CustID,
				@ActionType = 4, --Revert Deposit
				@Amount = @Amount,
				@ErrCode = @ErrCode OUTPUT,
				@ErrMsg	= @ErrMsg OUTPUT

		END
		IF @TransactionTypeId IN (3,4) --Withdraw
		BEGIN
			EXEC dbo.Age_CashAccumulatedCredit_Adjust 
				@CustID = @CustID,
				@ActionType = 5, --Revert Withdraw
				@Amount = @Amount,
				@ErrCode = @ErrCode OUTPUT,
				@ErrMsg	= @ErrMsg OUTPUT
		END

		IF @ErrCode <> 0
		BEGIN
			RETURN
		END
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = ERROR_NUMBER()
			,@ErrMsg = ERROR_MESSAGE()
	END CATCH


END  