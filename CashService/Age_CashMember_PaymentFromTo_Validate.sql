/*<info serverAlias="DBCust-AgencyCashService" executers="asv_CashService,wsv_CashService" selecters="" viewers="" isFunction="0" isNested=""></info>*/
ALTER PROCEDURE [dbo].[Age_CashMember_PaymentFromTo_Validate]
	@CustID INT,
	@AgentID INT,
	@IsMemberSite BIT = 0,
	@TransType TINYINT, -- 1 :Deposit, 2: Withdrawal
	@IsManual BIT = 1,
	@ProviderID SMALLINT = 0,
	@PaymentMethodID SMALLINT = NULL,
	@PaymentFrom VARCHAR(100) = NULL,
    @PaymentTo VARCHAR(100) = NULL,
	@ErrCode INT = 0 OUTPUT,
	@ErrMsg	VARCHAR(2000) = NULL OUTPUT
AS 
/*  
	Created: 20250423@Eden		
	Task: Validate Payment infomation
	DB:  DBSIC-bodb02
		
	Revisions:
		- 20250423@Eden: Alpha - Agency Cash Service [redmine: #223896] 

	Parameter's Explanation:
		 @TransactionTypeID = 
			1: Manual Deposit
			2: Auto Deposit
			3: Manual Withdrawal
			4: Auto Withdrawal				

	Sample:
		DECLARE @ErrCode INT,
			@ErrMsg VARCHAR(2000)
		EXEC Age_CashMember_PaymentFromTo_Validate 
			@CustID = 233657646,
			@AgentID = 228028013,
			@TransType = 1,
			@IsManual = 1,
			@ProviderID = 0,
			@PaymentMethodID = 0,
			@PaymentFrom = 'KKR-9877777771', 
			@PaymentTo = 'KKR-9856666666168',
			@ErrCode = @ErrCode OUTPUT,
			@ErrMsg = @ErrMsg OUTPUT

		SELECT @ErrCode AS ErrCode 
			,@ErrMsg AS ErrMsg
*/  
BEGIN 
	SET NOCOUNT ON;
	DECLARE @AgentPaymentInfo VARCHAR(100)
    DECLARE @MemberPaymentInfo VARCHAR(100)
	DECLARE @TransactionTypeID TINYINT 

	SELECT @TransactionTypeID = CASE WHEN @TransType = 1 AND @IsManual = 1 THEN 1 --Manual Deposit
									 WHEN @TransType = 1 AND @IsManual = 0 THEN 2 --Auto Deposit
									 WHEN @TransType = 2 AND @IsManual = 1 THEN 3 --Manual Withdrawal
									 WHEN @TransType = 2 AND @IsManual = 0 THEN 4 --Auto Withdrawal
								END

	--Validate Bank transfer
	IF @TransType = 1 -- Deposit
	BEGIN
		SELECT @AgentPaymentInfo = @PaymentTo, @MemberPaymentInfo = @PaymentFrom
	END
	ELSE IF @TransType = 2 --Withdrawal
	BEGIN
		SELECT @AgentPaymentInfo = @PaymentFrom, @MemberPaymentInfo = @PaymentTo
	END

	IF (@TransType = 1 AND ISNULL(@ProviderID,0) = 0) -- Deposit by Bank transfer
		OR (@TransType = 2) -- Withdrawal
	BEGIN
		IF NOT EXISTS(
			SELECT 1
			FROM CashMemberBankAccount b WITH (NOLOCK)
				INNER JOIN CashBankList a WITH(NOLOCK) 
					ON b.BankID = a.BankID
			WHERE b.CustId = @CustID
				AND a.BankCode + '-' + b.AccountNumber  = @MemberPaymentInfo
				AND b.IsActive = 1
		)
		BEGIN
			SELECT @ErrCode = 421, 
				@ErrMsg = 'Invalid Member Bank Account'

			RETURN
		END
	END

	IF (@TransType = 2 AND ISNULL(@ProviderID,0) = 0 AND @IsMemberSite = 0) -- Withdrawal by Bank transfer on Agency Site
		OR (@TransType = 1) -- Deposit
	BEGIN
		IF NOT EXISTS(
			SELECT 1
			FROM CashAgentBankAccount b WITH (NOLOCK)
				CROSS APPLY STRING_SPLIT(b.TransTypeList, ',') AS ts
				INNER JOIN CashBankList a WITH(NOLOCK) 
					ON b.BankID = a.BankID
			WHERE b.AgentID = @AgentID
				AND b.BankAccountStatus =  1 -- Enabled
				AND b.IsActive = 1 -- Enabled
				AND ts.value = @TransactionTypeID
				AND a.BankCode + '-' + b.BankAccountNumber  = @AgentPaymentInfo
			)
		BEGIN
			SELECT @ErrCode = 422, 
				@ErrMsg = 'Invalid Agent Bank Account'

			RETURN
		END
	END

	IF @ProviderID <> 0 AND @IsManual = 0
	BEGIN
		IF NOT EXISTS(
			SELECT 1
			FROM CashPaymentProviderAPIConfig b WITH (NOLOCK)
				INNER JOIN CashPaymentProvider p WITH(NOLOCK) 
					ON b.ProviderID = p.ProviderID
				INNER JOIN CashPaymentMethod m WITH(NOLOCK) 
					ON m.PaymentMethodID = b.PaymentMethodID
			WHERE b.AgentID = @AgentID
				AND b.TransactionType = @TransType
				AND b.PaymentMethodID = @PaymentMethodID
				AND b.ProviderID = @ProviderID
				AND b.PaymentMethodStatus = 1 --Completed
			)
		BEGIN
			SELECT @ErrCode = 423, 
				@ErrMsg = 'Invalid Provider'

			RETURN
		END

	END
END
GO