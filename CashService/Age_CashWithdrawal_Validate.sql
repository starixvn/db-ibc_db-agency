/*<info serverAlias="DBSIC-bodb02" executers="asv_CashService,wsv_CashService" selecters="" viewers="" isFunction="0" isNested=""></info>*/
ALTER PROCEDURE dbo.Age_CashWithdrawal_Validate 
(
    @CustID INT,
	@UplineId INT,
    @MinLimitAmt MONEY = NULL,
    @MaxLimitAmt MONEY = NULL,
    @Amount MONEY,
	@DailyWithdrawalCnt_Setting SMALLINT = NULL,
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
		- 20250611@Max: Alpha - Agency Cash Service - Sprint 4 [redmine: #223896] 
		- 20250805@Eden: Alpha - Agency Cash Service - Sprint 8 [redmine: #235012] 

	Parameter's Explanation:	
*/ 
BEGIN
    SET NOCOUNT ON;

	DECLARE @roleid TINYINT
		,@AccumCreditReturn MONEY
		,@AgentAvailableCredit MONEY
		,@beforebalance MONEY
		,@postbalance MONEY
		,@_AgentID INT
		,@Act_DailyWithdrawalCnt INT

	SELECT @roleid = roleid, @_AgentID = recommend
	FROM CustDB.dbo.custinfo AS ci WITH(NOLOCK)
	WHERE ci.custid = @custid

	SELECT @Act_DailyWithdrawalCnt = COUNT(1)
	FROM CashTransaction c WITH(NOLOCK) 
	WHERE custid = @CustID
		AND c.StatusId IN (2,4)-- Pending and Completed
		AND c.TransactionTypeID IN (3, 4) --3:Manual Withdraw, 4:Auto Withdraw
		AND c.CreatedTime >= CONVERT(DATE, GETDATE()) 
		AND c.CreatedTime < CONVERT(DATE, GETDATE() + 1)

	-- #1 Check roleid
	IF @roleid <> 1 OR @_AgentID <> @UplineId OR  @_AgentID IS NULL
	BEGIN
		SELECT @ErrCode = 405, @ErrMsg = 'Invalid parameters.'
		RETURN
	END

	-- #2 Check Limit Amount
	IF @Amount NOT BETWEEN ISNULL(@MinLimitAmt,0) AND @MaxLimitAmt
	BEGIN
		SELECT @ErrMsg = 'The amount exceeds the allowed minimum or maximum value.', @ErrCode = 407	
		RETURN
	END
	IF @DailyWithdrawalCnt_Setting IS NOT NULL AND @Act_DailyWithdrawalCnt >= @DailyWithdrawalCnt_Setting
	BEGIN
		SELECT @ErrMsg = 'Exceeds the daily withdrawal limit.', @ErrCode = 408
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
		SELECT @ErrMsg = 'Member' + '''' + 's cash balance is insufficient.'
			, @ErrCode = 406
		RETURN
	END

    SET NOCOUNT OFF;
END;