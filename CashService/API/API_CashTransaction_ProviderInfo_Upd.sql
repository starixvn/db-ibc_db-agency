/*<info serverAlias="DBSIC-bodb02" executers="asv_CashService,wsv_CashService" selecters="" viewers="" isFunction="0" isNested=""></info>*/
ALTER PROCEDURE dbo.API_CashTransaction_ProviderInfo_Upd
(
    @CustID INT,
    @AgentID INT,
	@TransId BIGINT,
	@TransType TINYINT, -- 1 :Deposit, 2: Withdrawal
	@ProviderTransId VARCHAR(100),
    @IP VARCHAR(50) = '',
	@ErrCode	INT = 0 OUTPUT,
	@ErrMsg	VARCHAR(2000) = NULL OUTPUT	,
	@ErrExtraInfo VARCHAR(MAX) = NULL OUTPUT
)
AS
/*
	Created: 20250624@Eden		
	Task: API Update ProviderTransId
	DB:  DBSIC-bodb02
		
	Revisions:
		- 20250708@Eden: Alpha - Agency Cash Service - Sprint 6 [redmine: #223896] 
		- 20250723@Eden: Alpha - Agency Cash Service - Sprint 7 [redmine: #233481] 
		- 20250723@Eden: Alpha - Agency Cash Service - Sprint 7 [redmine: #233481] 

	Parameter's Explanation:		
*/ 
BEGIN
    SET NOCOUNT ON;

	DECLARE @LogData VARCHAR(MAX)
		,@LogDataMask VARCHAR(MAX)
		,@PaymentType TINYINT 
		,@_statusId TINYINT
		,@TransactionTypeID TINYINT
		,@ExtraInfo NVARCHAR(1000) = NULL

	DECLARE @tmp_LogData AS TABLE (
		 LogTypeId TINYINT --1: Insert Transfer, 2: Insert/Update CashTransaction, 3: Insert/Update Accumulate Return Credit 
		,UserID	INT
		,CustID	INT
		,ActionID INT
		,TrackingValue	VARCHAR(MAX)
		,TrackingValue2	VARCHAR(MAX)
		,TrackingValueMask	VARCHAR(MAX)
		,TrackingValueMask2	VARCHAR(MAX)
	)

	SELECT @_statusId = c.StatusId
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
		OR (@TransType = 1 AND @TransactionTypeID NOT IN (1,2) ) --Deposit
		OR (@TransType = 2 AND @TransactionTypeID NOT IN (3,4) ) --Withdrawal
		OR ISNULL(@TransType, 0) NOT IN (1,2)
		OR @PaymentType = 2 --Bank transfer 
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
				,@ErrExtraInfo = @ErrMsg
			RETURN
		END
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = 409
				,@ErrMsg = 'The transaction inserted failed. Please try again.'
				,@ErrExtraInfo = ERROR_MESSAGE()
		RETURN
	END CATCH

	IF ISNULL(@ProviderTransId,'') <> ''
	BEGIN
		SELECT @ExtraInfo = JSON_MODIFY(ISNULL(c.ExtraInfo,'{}'), '$.ProviderTransId',@ProviderTransId)
		FROM dbo.CashTransaction c WITH (NOLOCK)
		WHERE c.TransId = @TransId
	END
	ELSE
	BEGIN
		GOTO ReturnLog;
	END

	--Update cash transaction, payment information only, not update status
	BEGIN TRY
		EXEC dbo.Age_CashTransaction_Upd 
			@TransId = @TransId,
			@ExtraInfo = @ExtraInfo,
			@ErrCode = @ErrCode OUTPUT,
			@ErrMsg = @ErrMsg OUTPUT

		IF @ErrCode <> 0
		BEGIN
			SELECT @ErrCode = 409
				,@ErrMsg = 'The transaction inserted failed. Please try again.'
				,@ErrExtraInfo = @ErrMsg

			GOTO ReturnLog;
		END
		ELSE --Insert data for writelog
		BEGIN
			SELECT @LogData = '<R custid="'+ COALESCE(CAST(@custid AS VARCHAR(20)), SPACE(1)) + '" ' +
								'TransType="'+ COALESCE(CAST(@TransType AS VARCHAR(20)), SPACE(1)) + '" ' +
								'TransId="'+ COALESCE(CAST(@TransId AS VARCHAR(20)), SPACE(1)) + '" ' +
								'ProviderTransId="'+ COALESCE(CAST(@ProviderTransId AS VARCHAR(100)), SPACE(1)) + '" ' +
								'IP="'+ COALESCE(CAST(@IP AS VARCHAR(50)), SPACE(1)) + '" />'

			INSERT INTO @tmp_LogData (LogTypeId, UserID, CustID, ActionID, TrackingValue)
			SELECT 3, @CustID, @CustID, 310011, @LogData
		END
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = 409
			,@ErrMsg = 'The transaction inserted failed. Please try again.'
			,@ErrExtraInfo = ERROR_MESSAGE();

		GOTO ReturnLog;
	END CATCH

	ReturnLog:
	--Unlock Transaction
	EXEC dbo.Age_CashDeposit_CheckingProcess
		@TransId = @TransId,
		@IsRelease = 1

	SELECT *
	FROM @tmp_LogData t

    SET NOCOUNT OFF;
END;