/*<info serverAlias="DBAGE-bodb02" executers="wsv_alp,wsv_alpv" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Age_CustomerSelBalanceInfo_MAg]
	 @custid		INT -- mrecommend
AS

/*
	Created by Percy
	Date: 2017-10-20
	DB: DBAGE.bodb02
	Task: Home page - Master Balance Info
	
	Revisions:
		- 20171020@Percy: Apply core balance sp [RedmineID: #84690]
		- 20200602@Percy: Separate PendingTransfer3rd to Cash and Balance [RedmineID: #135200]
		- 20210505@Sol: NAP - Alpha - Allow more time for transfer - [Redmine: #149927]
		- 20220429@Malcolm: Offer telegram bot service - [Redmine: #167819]
		- 20230227@Evan: Balance-Up support transfer 247 [Redmine: #173554] 
        - 20240918@Lewis: Rebate Retention - RewardReceivable RewardPayable [RedmineId: #208503]
		- 20241118@Max: Alpha - Offer Direct Member for Super/Master [Redmine: #211969]
		- 20250707@Dave: Add AccumCredit_AllCashMember to memberCredit [Redmine: #231524]
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @username NVARCHAR(50), @givenCredit MONEY, @memberCredit MONEY, @Currency INT, @CurrencyName NVARCHAR(50), @DirectMemberCredit MONEY

	SELECT @username = username, @givenCredit = ISNULL(Credit, 0), @Currency = currency
	FROM dbo.custInfo WITH (NOLOCK)
	WHERE custid = @custid

	SELECT @CurrencyName = e.currency FROM dbo.Exchange e WITH(NOLOCK) WHERE e.ExchangeId = @Currency

	SELECT @memberCredit = ISNULL(SUM(CASE WHEN roleid = 2 THEN credit ELSE 0 END), 0)
		,@DirectMemberCredit = ISNULL(SUM(CASE WHEN roleid = 1 THEN credit ELSE 0 END), 0)
	FROM dbo.custInfo WITH (NOLOCK)
	WHERE mrecommend = @custid 
		AND 1 = CASE WHEN roleid = 2 THEN 1
					WHEN roleid = 1 AND recommend = -3 THEN 1 ELSE 0 END

	SELECT @memberCredit = ISNULL(SUM(AccumCreditReturn),0) + @memberCredit
	FROM dbo.CashAccumCredit WITH (NOLOCK)
	WHERE mrecommend = @custid;

	CREATE TABLE #BalanceInfo
	(
		-- cash
		superCash		MONEY DEFAULT ((0)), yesterdaySuperCash		MONEY DEFAULT ((0)),
		masterCash		MONEY DEFAULT ((0)), yesterdayMasterCash	MONEY DEFAULT ((0)),
		agentCash		MONEY DEFAULT ((0)), yesterdayAgentCash		MONEY DEFAULT ((0)),
		memberCash		MONEY DEFAULT ((0)), yesterdayMemberCash	MONEY DEFAULT ((0)),
		-- winloss
		todayWinloss	MONEY DEFAULT ((0)), yesterdayWinloss		MONEY DEFAULT ((0)),
		-- PendingTransfer3rd
		PendingTransfer3rd MONEY DEFAULT ((0))
	)
	
	-- get move bet date
	DECLARE @balanceUpDay SMALLDATETIME, @moveBetDay SMALLDATETIME
	DECLARE @tblMoveBetBalanceUp AS TABLE (BalanceUpDay SMALLDATETIME, MoveBetsDay SMALLDATETIME)

	INSERT INTO @tblMoveBetBalanceUp(BalanceUpDay,MoveBetsDay)
	EXEC bodb02.dbo.Age_SelBalanceUpDay

	SELECT @balanceUpDay = BalanceUpDay, @moveBetDay = MoveBetsDay FROM @tblMoveBetBalanceUp

	-- cash
	INSERT INTO #BalanceInfo
	(
		superCash,		yesterdaySuperCash,
		masterCash,		yesterdayMasterCash,
		agentCash,		yesterdayAgentCash,
		memberCash,		yesterdayMemberCash,
		PendingTransfer3rd
	)
	EXEC dbo.Acc_CustomerSelCash @CustId = @CustId, @MoveBetDay = @moveBetDay, @BUDate = @balanceUpDay

	-- winloss
	INSERT INTO #BalanceInfo
	(
		todayWinloss,	yesterdayWinloss
	)
	EXEC dbo.Acc_CustomerSelWinLoss @CustId = @CustId, @MoveBetDay = @moveBetDay

	--Reward
	DECLARE
			@RewardPending MONEY = NULL ,
			@RewardBalance MONEY = NULL ,  
			@RewardCurrency VARCHAR(10) = NULL 
	EXEC Acc_CustomerSelBalanceReward @CustId = @CustID
									  ,@RewardPending  = @RewardPending OUTPUT   
									  ,@RewardBalance  = @RewardBalance OUTPUT
									  ,@RewardCurrency = @RewardCurrency OUTPUT

	SELECT
		@username					AS username,
		@CurrencyName				AS CurrencyName,
		SUM(masterCash)				AS cashBalance,
		SUM(yesterdayMasterCash)	AS yesterday_CashBalance,
		SUM(masterCash + agentCash + memberCash) AS totalBalance,
		SUM(yesterdayMasterCash + yesterdayAgentCash + yesterdayMemberCash) AS yesterday_totalBalance,
		SUM(todayWinloss)			AS todayWinloss,
		SUM(yesterdayWinloss)		AS yesterdayWinloss,
		@givenCredit				AS givenCredit,
		@memberCredit				AS memberCredit,
		SUM(PendingTransfer3rd)	AS PendingTransfer3rd,
		--Reward
		@RewardPending AS RewardPayable,
		@RewardBalance AS RewardReceivable,
		@RewardCurrency AS RewardCurrency,
		@DirectMemberCredit AS DirectMemberCredit
	FROM #BalanceInfo

	DROP TABLE #BalanceInfo
END
GO