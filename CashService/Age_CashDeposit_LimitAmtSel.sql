/*<info serverAlias="DBCust-CustDB" executers="asv_CashService,wsv_CashService" selecters="" viewers="" isFunction="0" isNested=""></info>*/
ALTER PROCEDURE dbo.Age_CashDeposit_LimitAmtSel
	@CustID	INT,
	@AgentID INT = NULL,
	@AccumCreditReturn MONEY,
	@IsMemberSite BIT = 0,
	@PaymentType TINYINT = 2,-- default bank 
	@ProviderID SMALLINT = 0,
	@PaymentMethodID SMALLINT = 0,
	@AgentAvailableCredit MONEY = NULL OUTPUT,
	@AgentGivenCredit MONEY = NULL OUTPUT,
	@CreditMembers_GivenCredit MONEY = NULL OUTPUT,
	@MinAmt MONEY = NULL OUTPUT,
	@MaxAmt MONEY = NULL OUTPUT
AS 
/*  
	Created : 20250423@Eden
	Description: get range value can deposit for Member (MinAmt - MaxAmt)
	DB: DBCust.CustDB
	
	Revisions:
		- 20250423@Eden: Alpha - Agency Cash Service [redmine: #223896] 

	Parameter's Explanation:	
		@PaymentType: 1-Gateway | 2-Bank account

	Sample:
		DECLARE @CustID INT = 1176092,
			@MinAmt	MONEY ,
			@MaxAmt	MONEY, 
			@AgentAvailableCredit MONEY
		EXEC Age_CashDeposit_LimitAmtSel 
			 @CustID = @CustID
			,@AccumCreditReturn = 10
			,@IsMemberSite = 1
			,@PaymentType = 2
			--,@ProviderID = 1
			--,@PaymentMethodID = 1
			,@MinAmt = @MinAmt OUTPUT
			,@MaxAmt = @MaxAmt OUTPUT
			,@AgentAvailableCredit = @AgentAvailableCredit OUTPUT

		SELECT @MinAmt AS MinAmt,@MaxAmt AS MaxAmt, @AgentAvailableCredit AS AgentAvailableCredit
		GO
		DECLARE @CustID INT = 1176092,
			@MinAmt	MONEY ,
			@MaxAmt	MONEY, 
			@AgentGivenCredit MONEY,
			@CreditMembers_GivenCredit MONEY
		EXEC Age_CashDeposit_LimitAmtSel 
			 @CustID = @CustID
			,@AccumCreditReturn = 10
			,@IsMemberSite = 1
			,@PaymentType = 2
			--,@ProviderID = 1
			--,@PaymentMethodID = 1
			,@MinAmt = @MinAmt OUTPUT
			,@MaxAmt = @MaxAmt OUTPUT
			,@AgentGivenCredit = @AgentGivenCredit OUTPUT
			,@CreditMembers_GivenCredit = @CreditMembers_GivenCredit OUTPUT

		SELECT @MinAmt AS MinAmt,@MaxAmt AS MaxAmt, @AgentGivenCredit AS AgentGivenCredit, @CreditMembers_GivenCredit AS CreditMembers_GivenCredit
*/  
BEGIN
	SET NOCOUNT ON;
		
	IF ISNULL(@AgentID, 0) = 0
	BEGIN
		SELECT @AgentID = recommend
		FROM custinfo WITH(NOLOCK)
		WHERE custid = @CustID
	END

	IF @IsMemberSite = 1
	BEGIN
		IF @PaymentType = 2 --Limit by BankAccount, Available Agent Credit
		BEGIN
			SELECT @MinAmt = MinPerDeposit, @MaxAmt = MaxPerDeposit
			FROM AgencyCashService.dbo.CashAgentBankAccountLimit l WITH(NOLOCK) 
			WHERE l.AgentID = @AgentID
		END
		ELSE IF @PaymentType = 1 AND @ProviderID <> 0 --Limit by Payment Gateway method, Available Agent Credit
		BEGIN
			SELECT @MinAmt = MinAmountTrans, @MaxAmt = MaxAmountTrans
			FROM AgencyCashService.dbo.CashPaymentProviderInfo p WITH(NOLOCK) 
			WHERE ProviderID = @ProviderID
				AND PaymentMethodID = @PaymentMethodID
				AND TransactionType = 1 --deposit
		END
		ELSE -- Invalid
		BEGIN
			SELECT @MinAmt = 0, @MaxAmt = 0
		END
	END

	IF @AccumCreditReturn IS NULL
	BEGIN
		SELECT @AccumCreditReturn = AccumCreditReturn FROM dbo.f_Age_CashAccumCredit_AgSel(@AgentID)
	END

	SELECT @CreditMembers_GivenCredit =  ISNULL(SUM(ISNULL(c.credit,0)),0) 
	FROM custinfo c WITH(NOLOCK) 
	WHERE c.recommend = @AgentID
		AND roleid = 1

	SELECT @AgentGivenCredit = ag.credit
	FROM custinfo ag WITH(NOLOCK)
	WHERE ag.custid = @AgentID

	SELECT @AgentAvailableCredit = @AgentGivenCredit - @CreditMembers_GivenCredit - @AccumCreditReturn
END
GO