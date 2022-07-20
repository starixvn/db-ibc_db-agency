/*<info serverAlias="DBAGE-bodb02" executers="bodbDownlineNet,bodbDownlineNetView" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Age_CustomerSelBalanceInfo_Ag]
	 @custid		INT, -- recommend
	 @MoveBetsDay	SMALLDATETIME -- not use
AS

/*
	Created by Percy
	Date: 2017-10-20
	DB: DBAGE.bodb02
	Task: Home page - Agent Balance Info
	
	Revisions:
		- 20171020@Percy: Apply core balance sp [RedmineID: #84690]
		- 20200602@Percy: Separate PendingTransfer3rd to Cash and Balance [RedmineID: #135200]
		- 20210505@Sol: NAP - Alpha - Allow more time for transfer - [Redmine: #149927]
		- 20220429@Malcolm: Offer telegram bot service - [Redmine: #167819]
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @username NVARCHAR(50), @givenCredit MONEY, @memberCredit MONEY, @Currency INT, @CurrencyName NVARCHAR(50)

	SELECT @username = username, @givenCredit = ISNULL(Credit, 0), @Currency = currency
	FROM dbo.custInfo WITH (NOLOCK)
	WHERE custid = @custid

	SELECT @CurrencyName = e.currency FROM dbo.Exchange e WITH(NOLOCK) WHERE e.ExchangeId = @Currency

	SELECT @memberCredit = ISNULL(SUM(credit), 0)
	FROM dbo.custInfo WITH (NOLOCK)
	WHERE recommend = @custid AND roleid = 1

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
	EXEC dbo.Acc_CustomerSelCash @CustId = @CustId, @MoveBetDay = @moveBetDay

	-- winloss
	INSERT INTO #BalanceInfo
	(
		todayWinloss,	yesterdayWinloss
	)
	EXEC dbo.Acc_CustomerSelWinLoss @CustId = @CustId, @MoveBetDay = @moveBetDay

	SELECT
		@username					AS username,
		@CurrencyName				AS CurrencyName,
		SUM(agentCash)				AS cashBalance,
		SUM(yesterdayAgentCash)		AS yesterday_CashBalance,
		SUM(agentCash + memberCash) AS totalBalance,
		SUM(yesterdayAgentCash + yesterdayMemberCash) AS yesterday_totalBalance,
		SUM(todayWinloss)			AS todayWinloss,
		SUM(yesterdayWinloss)		AS yesterdayWinloss,
		@givenCredit				AS givenCredit,
		@memberCredit				AS memberCredit,
		SUM(PendingTransfer3rd)	AS PendingTransfer3rd
	FROM #BalanceInfo

	DROP TABLE #BalanceInfo
END
GO