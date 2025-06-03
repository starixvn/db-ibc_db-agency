/*<info serverAlias="DBSIC-bodb02" executers="asv_CashService,wsv_CashService,wsv_nap,wsv_alp,wsv_alpv,wsv_xnap" selecters="" viewers="" isFunction="0" isNested=""></info>*/
ALTER PROCEDURE [dbo].[Age_CashTransaction_RevertDeposit_Upd]  
	@TransId BIGINT,
	@SiteDBGroupID	SMALLINT,
	@Remark NVARCHAR(2000) = NULL,
	@IsForce BIT = 0,
	@UserId INT = 0, 
	@IP VARCHAR(50) = '',
	@ErrCode	INT = 0 OUTPUT,
	@ErrMsg	VARCHAR(2000) = NULL OUTPUT
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
		,@CustId INT
		,@LogData VARCHAR(MAX)
		,@LogDataMask VARCHAR(MAX)
		,@TransactionTypeId TINYINT

	IF @SiteDBGroupID <> dbo.f_Get_SiteDBGroupID() OR @SiteDBGroupID IS NULL
	BEGIN
		SELECT @ErrCode = 101
			,@ErrMsg = 'Wrong SiteDB'

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

	SELECT @StatusId_before = StatusId, @AdjustAmount = c.AdjustCreditAmt, @Transfer_RefNo = c.TransferRefNo, @CustId = c.CustId, @TransactionTypeId = c.TransactionTypeID
	FROM dbo.CashTransaction c WITH (NOLOCK)
	WHERE c.TransId = @TransId

	IF @StatusId_before = 4 OR @IsForce = 1
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
			SELECT @ErrCode = ERROR_NUMBER()
				,@ErrMsg = ERROR_MESSAGE()

			RETURN
		END CATCH

		BEGIN TRY
			EXEC dbo.Age_CashService_Balance_Rollback
				@CustID = @CustID,
				@UplineID = @UserId,
				@Amount = @AdjustAmount,
				@ExchangeRate = 1,
				@IP = @IP,
				@TransactionTypeId = @TransactionTypeId,
				@ErrCode = @ErrCode OUTPUT,
				@ErrMsg = @ErrMsg OUTPUT,
				@TransferRefNo = @Transfer_RefNo OUTPUT

			IF @ErrCode <> 0
			BEGIN
				GOTO Writelog;
			END
			ELSE --Insert data for writelog
			BEGIN
				SELECT @LogDataMask = '< custid="'+ COALESCE(CAST(@custid AS VARCHAR(20)), SPACE(1)) + '" ' +
									'UserId="'+ COALESCE(CAST(@UserId AS VARCHAR(20)), SPACE(1)) + '" ' +
									'Transfer_RefNo ="'+ COALESCE(CAST(@Transfer_RefNo AS VARCHAR(20)), SPACE(1)) + '" ' +
									'Amount="'+ COALESCE(CAST(@AdjustAmount AS VARCHAR(50)), SPACE(1)) + + '" />'

				INSERT INTO @tmp_LogData (LogTypeId, UserID, CustID, ActionID, TrackingValue,TrackingValueMask)
				SELECT 1, @UserId, @CustID, 9999991, @LogData, @LogDataMask
			END
		END TRY
		BEGIN CATCH
			SELECT @ErrCode = ERROR_NUMBER()
			,@ErrMsg = ERROR_MESSAGE()

			RETURN
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
			GOTO Writelog;
		END
		ELSE --Insert data for writelog
		BEGIN
			SELECT @LogData = '< custid="'+ COALESCE(CAST(@custid AS VARCHAR(20)), SPACE(1)) + '" ' +
								'TransId="'+ COALESCE(CAST(@TransId AS VARCHAR(20)), SPACE(1)) + '" ' +
								'Before_StatusId="'+ COALESCE(CAST(@StatusId_before AS VARCHAR(3)), SPACE(1)) + '" ' +
								'After_StatusId="'+ COALESCE(CAST(2 AS VARCHAR(3)), SPACE(1)) + '" />'

			INSERT INTO @tmp_LogData (LogTypeId, UserID, CustID, ActionID, TrackingValue)
			SELECT 2, @UserId, @CustID, 9999993, @LogData
		END
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = ERROR_NUMBER()
			,@ErrMsg = ERROR_MESSAGE()

		RETURN
	END CATCH

	Writelog:
	SELECT *
	FROM @tmp_LogData t

END  