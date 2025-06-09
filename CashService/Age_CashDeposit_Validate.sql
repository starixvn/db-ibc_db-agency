/*<info serverAlias="DBSIC-bodb02" executers="asv_CashService,wsv_CashService" selecters="" viewers="" isFunction="0" isNested=""></info>*/
ALTER PROCEDURE dbo.Age_CashDeposit_Validate 
(
    @CustID INT,
	@UplineId INT,
    @AgentGivenCredit MONEY,
    @CreditMembers_GivenCredit MONEY,
    @MinLimitAmt MONEY = NULL,
    @MaxLimitAmt MONEY = NULL,
    @Amount MONEY,
	@UserInput_Amount MONEY = NULL,
	@PaymentType TINYINT = NULL,
	@MachingMode TINYINT = NULL,
	@ErrCode	INT = 0 OUTPUT,
	@ErrMsg	VARCHAR(2000) = NULL OUTPUT
)
AS
/*
	Created: 20250502@Max		
	Task: Alpha - Agency Cash Service [redmine: #223896] 
	DB:  DBSIC-bodb02
		
	Revisions:
		- 20250502@Max: Alpha - Agency Cash Service [redmine: #223896] 
		- 20250603@Max: Alpha - Agency Cash Service - Sprint 3 [redmine: #223896] 

	Parameter's Explanation:	
*/ 
BEGIN
    SET NOCOUNT ON;

	DECLARE @roleid TINYINT
		,@AccumCreditReturn MONEY
		,@AgentAvailableCredit MONEY
		,@IsInValidAmount BIT = 0

	SELECT @roleid = roleid
	FROM CustDB.dbo.custinfo AS ci WITH(NOLOCK)
	WHERE ci.custid = @custid

	-- #1 Check roleid
	IF @roleid <> 1
	BEGIN
		SELECT @ErrMsg = 'Invalid Role ID.', @ErrCode = 102		
		RETURN
	END

	-- #2 Check Limit Amount
	SELECT @AccumCreditReturn = AccumCreditReturn FROM dbo.f_Age_CashAccumCredit_AgSel(@UplineId)
	SET @AgentAvailableCredit = @AgentGivenCredit - @CreditMembers_GivenCredit - @AccumCreditReturn
	SELECT @MaxLimitAmt = CASE WHEN @AgentAvailableCredit < @MaxLimitAmt OR @MaxLimitAmt IS NULL THEN @AgentAvailableCredit ELSE @MaxLimitAmt END
	
	IF @PaymentType = 2 AND @MachingMode = 1
	BEGIN
		IF (@UserInput_Amount BETWEEN ISNULL(@MinLimitAmt,0) AND @MaxLimitAmt) AND @Amount <= @MaxLimitAmt
		BEGIN
			SET @IsInValidAmount = 0
		END
		ELSE
		BEGIN
			SET @IsInValidAmount = 1
		END
	END
	ELSE 
	BEGIN	
		IF @Amount NOT BETWEEN ISNULL(@MinLimitAmt,0) AND @MaxLimitAmt
		BEGIN
			SET @IsInValidAmount = 1
		END
	END

	IF @IsInValidAmount = 1
	BEGIN
		SELECT @ErrMsg = 'Sorry, amount is invalid.', @ErrCode = 101	
		RETURN
	END

    SET NOCOUNT OFF;
END;