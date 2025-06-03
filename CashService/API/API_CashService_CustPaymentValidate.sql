/*<info serverAlias="DBCUST-CUSTDB" executers="asv_CashService,wsv_CashService" selecters="" viewers="" isFunction="0" isNested=""></info>*/
ALTER PROCEDURE dbo.API_CashService_CustPaymentValidate
(
    @CustID INT,
	@AgentID INT,
	@TransType TINYINT = 1, -- 1 :Deposit, 2: Withdrawal
	@ErrCode	INT = 0 OUTPUT,
	@ErrMsg	VARCHAR(2000) = NULL OUTPUT
)
AS
/*
	Created: 20250602@Eden		
	Task: Validate customer when make deposit/withdrawal request
	DB:  DBCUST-CUSTDB
		
	Revisions:
		- 20250602@Eden: Alpha - Agency Cash Service [redmine: #223896] 

	Parameter's Explanation:	
*/ 
BEGIN
    SET NOCOUNT ON;
	DECLARE @ServiceType TINYINT = 0, 
		@IsAllowDeposit BIT = 0,
		@_AgentID INT, 
		@Enabled BIT,
		@CloseInfo TINYINT,
		@SuspendInfo TINYINT

	SELECT @_AgentID = recommend, 
		@Enabled = [Enabled]
	FROM custinfo ci WITH(NOLOCK)
	WHERE custid = @CustID

	IF @_AgentID <> @AgentID OR  @_AgentID IS NULL
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

    SET NOCOUNT OFF;
END
GO