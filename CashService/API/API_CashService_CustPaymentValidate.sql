/*<info serverAlias="DBCUST-CUSTDB" executers="asv_CashService,wsv_CashService" selecters="" viewers="" isFunction="0" isNested=""></info>*/
ALTER PROCEDURE dbo.API_CashService_CustPaymentValidate
(
    @CustID INT,
	@AgentID INT,
	@TransType TINYINT, -- 1 :Deposit, 2: Withdrawal
	@IsManual BIT = 1,
	@ProviderID SMALLINT = 0,
	@PaymentMethodID SMALLINT = 0,
	@PaymentFrom VARCHAR(100) = NULL,
    @PaymentTo VARCHAR(100) = NULL,
	@ErrCode	INT = 0 OUTPUT,
	@ErrMsg	VARCHAR(2000) = NULL OUTPUT,
	@ErrExtraInfo VARCHAR(MAX) = NULL OUTPUT,
	@username2 VARCHAR(50) OUTPUT
)
AS
/*
	Created: 20250602@Eden		
	Task: Validate customer when make deposit/withdrawal request
	DB:  DBCUST-CUSTDB
		
	Revisions:
		- 20250602@Eden: Alpha - Agency Cash Service [redmine: #223896] 
		- 20250723@Eden: Alpha - Agency Cash Service - Sprint 7 [redmine: #233481] 

	Parameter's Explanation:	

	Sample:
		DECLARE @ErrCode INT,
			@ErrMsg VARCHAR(2000),
			@ErrExtraInfo VARCHAR(MAX)
		EXEC API_CashService_CustPaymentValidate 
			@CustID = 233657646,
			@AgentID = 228028013,
			@TransType = 2,
			@IsManual = 1,
			@ProviderID = 0,
			@PaymentMethodID = 0,
			@PaymentFrom = 'KKR-9877777771', 
			@PaymentTo = 'KKR-9856666666168',
			@ErrCode = @ErrCode OUTPUT,
			@ErrMsg = @ErrMsg OUTPUT,
			@ErrExtraInfo = @ErrExtraInfo OUTPUT

		SELECT @ErrCode AS ErrCode 
			,@ErrMsg AS ErrMsg
			,@ErrExtraInfo AS ErrExtraInfo
*/ 
BEGIN
    SET NOCOUNT ON;
	DECLARE @ServiceType TINYINT = 0, 
		@IsAllowDeposit BIT = 0,
		@RoleID TINYINT,
		@_AgentID INT, 
		@Enabled BIT,
		@CloseInfo TINYINT,
		@SuspendInfo TINYINT

	SELECT @_AgentID = recommend, 
		@Enabled = [Enabled],
		@RoleID = ci.RoleID
	FROM custinfo ci WITH(NOLOCK)
	WHERE custid = @CustID

	IF @_AgentID <> @AgentID OR  @_AgentID IS NULL OR @RoleID <> 1
	BEGIN
		SELECT @ErrCode = 405, @ErrMsg = 'Invalid parameters.'
		RETURN
	END

	IF @Enabled = 0
	BEGIN
		SELECT @ErrCode = 401, @ErrMsg = 'The account was disabled.'
		RETURN
	END

	SELECT @CloseInfo = CloseInfo, 
		@SuspendInfo = SuspendInfo
	FROM CustProductStatus cps WITH(NOLOCK)
	WHERE custid = @CustID

	IF @CloseInfo > 0
	BEGIN
		SELECT @ErrCode = 402, @ErrMsg = 'The account was closed.'
		RETURN
	END

	IF @SuspendInfo > 0
	BEGIN
		SELECT @ErrCode = 404, @ErrMsg = 'The account was suspended.'
		RETURN
	END

	IF @TransType = 1 -- Deposit
	BEGIN
		--Check member is cash member or not
		EXEC Age_CashService_CustServiceTypeSel 
			@CustID = @CustID,
			@ServiceType  = @ServiceType  OUTPUT  

		IF @ServiceType = 0
		BEGIN
			SELECT @ErrCode = 403, @ErrMsg = 'Unable to process deposits.'
			RETURN
		END

		--Check Agent is enable cash service or not
		EXEC Age_CashService_CustServiceTypeSel 
			@CustID = @AgentID,
			@ServiceType  = @ServiceType  OUTPUT  

		IF @ServiceType = 0
		BEGIN
			SELECT @ErrCode = 403, @ErrMsg = 'Unable to process deposits.'
			RETURN
		END

		--Check Agent is enable deposit or not
		EXEC AgencyCashService.dbo.[Age_CashService_AgentPermissionSel]
			@CustID = @AgentID,
			@IsAllowDeposit  = @IsAllowDeposit  OUTPUT  

		IF @IsAllowDeposit = 0
		BEGIN
			SELECT @ErrCode = 403, @ErrMsg = 'Unable to process deposits.'
			RETURN
		END
	END

	--Validate BankAccount
	EXEC AgencyCashService.dbo.Age_CashMember_PaymentFromTo_Validate 
		@CustID = @CustID,
		@AgentID = @AgentID,
		@TransType = @TransType,
		@IsMemberSite = 1,
		@IsManual = @IsManual,
		@ProviderID = @ProviderID,
		@PaymentMethodID = @PaymentMethodID,
		@PaymentFrom = @PaymentFrom, 
		@PaymentTo = @PaymentTo,
		@ErrCode = @ErrCode OUTPUT,
		@ErrMsg = @ErrMsg OUTPUT
	
	IF @ErrCode <> 0
	BEGIN
		SELECT @ErrExtraInfo = @ErrMsg
		SELECT @ErrCode = 405, @ErrMsg = 'Invalid parameters.'
		RETURN
	END

	-- Get NickName
	SELECT @username2 = username2 FROM dbo.Customer ci WITH(NOLOCK) WHERE custid = @CustID

    SET NOCOUNT OFF;
END
GO