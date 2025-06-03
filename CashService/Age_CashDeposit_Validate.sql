/*<info serverAlias="DBSIC-bodb02" executers="asv_CashService,wsv_CashService,wsv_nap,wsv_alp,wsv_alpv,wsv_xnap" selecters="" viewers="" isFunction="0" isNested=""></info>*/
ALTER PROCEDURE dbo.Age_CashDeposit_Validate 
(
    @CustID INT,
	@UplineId INT,
    @AgentGivenCredit MONEY,
    @CreditMembers_GivenCredit MONEY,
    @MinLimitAmt MONEY = NULL,
    @MaxLimitAmt MONEY = NULL,
    @Amount MONEY,
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

	Parameter's Explanation:	
*/ 
BEGIN
    SET NOCOUNT ON;

	DECLARE @roleid TINYINT
		,@AccumCreditReturn MONEY
		,@AgentAvailableCredit MONEY

	-- #1 CHECK UM TRANSFER FUNCTION
	EXEC DBCUST.CUSTDB.dbo.Acc_Transfer_CheckUM  
		@CustID = @custid
		,@Language = 'E'
		,@ErrMsg = @ErrMsg OUTPUT 
		,@ErrCode = @ErrCode OUTPUT
	 
	IF @ErrCode <> 0  -- Function Transfer is under UM 
	BEGIN
		RETURN		
	END

	SELECT @roleid = roleid
	FROM CustDB.dbo.custinfo AS ci WITH(NOLOCK)
	WHERE ci.custid = @custid

	-- #2 Check roleid
	IF @roleid <> 1
	BEGIN
		SELECT @ErrMsg = 'Invalid Role ID.', @ErrCode = 102		
		RETURN
	END

	-- #3 Check Limit Amount
	SELECT @AccumCreditReturn = AccumCreditReturn FROM dbo.f_Age_CashAccumCredit_AgSel(@UplineId)
	SET @AgentAvailableCredit = @AgentGivenCredit - @CreditMembers_GivenCredit - @AccumCreditReturn
	SELECT @MaxLimitAmt = CASE WHEN @AgentAvailableCredit < @MaxLimitAmt OR @MaxLimitAmt IS NULL THEN @AgentAvailableCredit ELSE @MaxLimitAmt END

	IF @Amount NOT BETWEEN ISNULL(@MinLimitAmt,0) AND @MaxLimitAmt
	BEGIN
		SELECT @ErrMsg = 'Sorry, amount is invalid.', @ErrCode = 101	
		RETURN
	END

    SET NOCOUNT OFF;
END;