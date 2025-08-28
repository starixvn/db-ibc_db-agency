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
	@MatchingMode TINYINT = NULL,
	@ErrCode	INT = 0 OUTPUT,
	@ErrMsg	VARCHAR(2000) = NULL OUTPUT,
	@AgentAvailableCredit MONEY = 0 OUTPUT
)
AS
/*
	Created: 20250502@Max		
	Task: Alpha - Agency Cash Service [redmine: #223896] 
	DB:  DBSIC-bodb02
		
	Revisions:
		- 20250502@Max: Alpha - Agency Cash Service [redmine: #223896] 
		- 20250603@Max: Alpha - Agency Cash Service - Sprint 3 [redmine: #223896] 
		- 20250611@Max: Alpha - Agency Cash Service - Sprint 4 [redmine: #223896]
		- 20250821@Eden: Alpha - Agency Cash Service - Sprint 9 [redmine: #236435]   

	Parameter's Explanation:	
*/ 
BEGIN
    SET NOCOUNT ON;

	DECLARE @AccumCreditReturn MONEY

	EXEC Age_CashService_CheckBelonging
			@CustID	= @CustID 
			,@UplineID	= @UplineId
			,@ErrCode = @ErrCode OUTPUT 
			,@ErrMsg  = @ErrMsg OUTPUT

	IF @ErrCode <> 0
	BEGIN
		RETURN
	END

	-- #2 Check Limit Amount
	SELECT @AccumCreditReturn = AccumCreditReturn FROM dbo.f_Age_CashAccumCredit_AgSel(@UplineId)
	SET @AgentAvailableCredit = @AgentGivenCredit - @CreditMembers_GivenCredit - @AccumCreditReturn
	--SELECT @MaxLimitAmt = CASE WHEN @AgentAvailableCredit < @MaxLimitAmt OR @MaxLimitAmt IS NULL THEN @AgentAvailableCredit ELSE @MaxLimitAmt END
	
	--Validate Min-Max Setting
	IF @PaymentType = 2 AND @MatchingMode = 1
	BEGIN
		IF @UserInput_Amount NOT BETWEEN ISNULL(@MinLimitAmt,0) AND @MaxLimitAmt
		BEGIN
			SELECT @ErrMsg = 'The amount exceeds the allowed minimum or maximum value.', @ErrCode = 407	
			RETURN
		END
	END
	ELSE 
	BEGIN	
		IF @Amount NOT BETWEEN ISNULL(@MinLimitAmt,0) AND @MaxLimitAmt
		BEGIN
			SELECT @ErrMsg = 'The amount exceeds the allowed minimum or maximum value.', @ErrCode = 407	
			RETURN
		END
	END

	--Validate Agent Available Credit
	IF @Amount > @AgentAvailableCredit
	BEGIN
		SELECT @ErrMsg = 'The amount must not exceed agent available credit [' + CAST(@AgentAvailableCredit AS VARCHAR(20)) + '].'
			, @ErrCode = 417	
		RETURN
	END

    SET NOCOUNT OFF;
END;