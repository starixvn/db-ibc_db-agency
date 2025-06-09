/*<info serverAlias="DBSIC-bodb02" executers="asv_CashService,wsv_CashService" selecters="" viewers="" isFunction="0" isNested=""></info>*/
ALTER PROCEDURE dbo.Age_CashWithdrawal_Validate 
(
    @CustID INT,
	@UplineId INT,
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
		- 20250603@Max: Alpha - Agency Cash Service - Sprint 3 [redmine: #223896] 

	Parameter's Explanation:	
*/ 
BEGIN
    SET NOCOUNT ON;

	DECLARE @roleid TINYINT
		,@AccumCreditReturn MONEY
		,@AgentAvailableCredit MONEY
		,@beforebalance MONEY
		,@postbalance MONEY

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
	IF @Amount NOT BETWEEN ISNULL(@MinLimitAmt,0) AND @MaxLimitAmt
	BEGIN
		SELECT @ErrMsg = 'Sorry, amount is invalid.', @ErrCode = 101	
		RETURN
	END

	-- #4 Check member balance
	EXEC dbo.Age_CashService_CashBalance_Sel @CustId = @CustId, @TotalCash = @beforebalance OUTPUT
	SELECT @postbalance = @beforebalance - @Amount
	
	----------------------------------------------------------
	--- Check Member's Balance for WITHDRAWAL or TRANSFER OUT 
	----------------------------------------------------------	
	IF @postbalance < 0
	BEGIN
		SELECT @ErrMsg = 'Sorry, you do not have enough money to withdraw.'
			, @ErrCode = 103
		RETURN
	END

    SET NOCOUNT OFF;
END;