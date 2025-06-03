/*<info serverAlias="DBCust-CustDB" executers="asv_CashService,wsv_CashService" selecters="" viewers="" isFunction="0" isNested=""></info>*/
ALTER PROCEDURE dbo.Age_CashDeposit_MemberSettingSel
	@CustID	INT ,
	@IsMemberSite BIT = 0,
	@ProviderID SMALLINT = 0,
	@PaymentMethodID SMALLINT = 0,
	@AgentGivenCredit MONEY OUTPUT,
	@CreditMembers_GivenCredit MONEY OUTPUT,
	@MinLimitAmt MONEY = NULL OUTPUT,
	@MaxLimitAmt MONEY = NULL OUTPUT
AS 
/*  
	Created : 20250423@Eden
	Description: get deposit setting value for Member - use to validate min-max amount
	DB: DBCust.CustDB
	
	Revisions:
		- 20250423@Eden: Alpha - Agency Cash Service [redmine: #223896] 

	Parameter's Explanation:	

	Sample:
		DECLARE @CustID INT = 1176092,
			@MinLimitAmt	MONEY ,
			@MaxLimitAmt	MONEY,
			@AgentGivenCredit MONEY,
			@CreditMembers_GivenCredit MONEY
		EXEC Age_CashDeposit_MemberSettingSel 
			 @CustID = @CustID
			,@MinLimitAmt = @MinLimitAmt OUTPUT
			,@MaxLimitAmt = @MaxLimitAmt OUTPUT
			,@AgentGivenCredit = @AgentGivenCredit OUTPUT
			,@CreditMembers_GivenCredit = @CreditMembers_GivenCredit OUTPUT
		SELECT @MinLimitAmt AS MinAmt,@MaxLimitAmt AS MaxAmt, @AgentGivenCredit AS AgentGivenCredit,@CreditMembers_GivenCredit AS MemberUsedCredit
*/  
BEGIN
	SET NOCOUNT ON;

	DECLARE  @AgentID INT
			
	SELECT @AgentID = recommend
	FROM custinfo WITH(NOLOCK)
	WHERE custid = @CustID

	IF @IsMemberSite = 1
	BEGIN
		IF ISNULL(@ProviderID,0) = 0 --Limit by BankAccount, Available Agent Credit
		BEGIN
			SELECT @MinLimitAmt = 0, @MaxLimitAmt = NULL
		END
		ELSE --Limit by Payment Gateway method, Available Agent Credit
		BEGIN
			SELECT @MinLimitAmt = 0, @MaxLimitAmt = NULL
		END
	END

	SELECT @CreditMembers_GivenCredit =  ISNULL(SUM(ISNULL(c.credit,0)),0) 
	FROM custinfo c WITH(NOLOCK) 
	WHERE c.recommend = @AgentID
		AND roleid = 1

	SELECT @AgentGivenCredit = ag.credit
	FROM custinfo ag WITH(NOLOCK)
	WHERE ag.custid = @AgentID
END
GO