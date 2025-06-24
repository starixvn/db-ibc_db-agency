/*<info serverAlias="DBSIC-bodb02" executers="asv_CashService,wsv_CashService" selecters="" viewers="" isFunction="0" isNested=""></info>*/
ALTER PROCEDURE [dbo].[Age_CashTransaction_RevertWithdrawal_Upd]  
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
		,@Transfer_RefNo BIGINT
		,@CustId INT
		,@LogData VARCHAR(MAX)
		,@LogDataMask VARCHAR(MAX)
		,@TransactionTypeId TINYINT
		,@Amount MONEY

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

	SELECT @StatusId_before = StatusId, @AdjustAmount = c.AdjustCreditAmt
		, @Transfer_RefNo = c.TransferRefNo, @CustId = c.CustId
		, @TransactionTypeId = c.TransactionTypeID, @Amount = c.Amount
	FROM dbo.CashTransaction c WITH (NOLOCK)
	WHERE c.TransId = @TransId

	--Step 1: Adjust accumulated credit
	IF @StatusId_before = 4 AND @AdjustAmount <> 0
	BEGIN
		-- Adjust accumulated credit
		BEGIN TRY
			EXEC dbo.Age_CashAccumulatedCredit_Adjust 
				@CustID = @CustID,
				@ActionType = 5, --Revert Withdraw
				@Amount = @AdjustAmount,
				@ErrCode = @ErrCode OUTPUT,
				@ErrMsg	= @ErrMsg OUTPUT,
				@CashAccumCreditTbl	= @CashAccumCreditTbl OUTPUT

			IF @ErrCode <> 0
			BEGIN
				SELECT @ErrCode = 409
					,@ErrMsg = 'The transaction inserted failed. Please try again.'

				RETURN
			END
			ELSE --Insert data for writelog
			BEGIN
				SELECT @LogData = '< custid="'+ COALESCE(CAST(@custid AS VARCHAR(20)), SPACE(1)) + '" ' +
									'ActionType="'+ COALESCE(CAST(5 AS VARCHAR(20)), SPACE(1)) + '" ' +
									'Amount="'+ COALESCE(CAST(@Amount AS VARCHAR(100)), SPACE(1)) + '" ' + '" />'

				INSERT INTO @tmp_LogData (LogTypeId, UserID, CustID, ActionID, TrackingValue)
				SELECT 3, @UserId, @CustID, 310104, @LogData
			END
		END TRY
		BEGIN CATCH
			SELECT @ErrCode = 409
				,@ErrMsg = 'The transaction inserted failed. Please try again.'
		END CATCH
	END

	--Step 2: Update transaction status
	BEGIN TRY
		EXEC dbo.Age_CashTransaction_Upd 
			@TransId = @TransId,
			@StatusId = 2, --Pending
			@AdjustCreditAmt = 0,
			@Remark = @Remark,
			@ErrCode = @ErrCode OUTPUT,
			@ErrMsg = @ErrMsg OUTPUT

		IF @ErrCode <> 0
		BEGIN
			--Rollback CashAccumulatedCredit
			EXEC dbo.Age_CashService_Balance_Rollback
				@Type = 1, 
				@TransId = 0,
				@Custid = @CustID,
				@AdjustCreditAmt = @AdjustAmount

			SELECT @ErrCode = 409
				,@ErrMsg = 'The transaction inserted failed. Please try again.'

			GOTO Writelog;
		END
		ELSE --Insert data for writelog
		BEGIN
			SELECT @LogData = '< custid="'+ COALESCE(CAST(@custid AS VARCHAR(20)), SPACE(1)) + '" ' +
								'TransId="'+ COALESCE(CAST(@TransId AS VARCHAR(20)), SPACE(1)) + '" ' +
								'Before_StatusId="'+ COALESCE(CAST(@StatusId_before AS VARCHAR(3)), SPACE(1)) + '" ' +
								'After_StatusId="'+ COALESCE(CAST(2 AS VARCHAR(3)), SPACE(1)) + '" />'

			INSERT INTO @tmp_LogData (LogTypeId, UserID, CustID, ActionID, TrackingValue)
			SELECT 2, @UserId, @CustID, 310103, @LogData
		END
	END TRY
	BEGIN CATCH
		--Rollback CashAccumulatedCredit
		EXEC dbo.Age_CashService_Balance_Rollback
			@Type = 1, 
			@TransId = 0,
			@Custid = @CustID,
			@AdjustCreditAmt = @AdjustAmount

		SELECT @ErrCode = 409
				,@ErrMsg = 'The transaction inserted failed. Please try again.'

		RETURN
	END CATCH

	Writelog:
	SELECT *
	FROM @tmp_LogData t
END  