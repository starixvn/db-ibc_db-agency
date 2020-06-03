/*<info serverAlias="DBAGE-bodb02" executers="bodbDownlineNet,bodbDownlineNetView" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Age_CustomerSelBalanceInfo_SAg]
	 @custid		INT, -- srecommend
	 @MoveBetsDay	SMALLDATETIME -- not use
AS

/*
	Created by Percy
	Date: 2017-10-20
	DB: DBAGE.bodb02
	Task: Home page - Super Balance Info
	
	Revisions:
		- 20171020@Percy: Apply core balance sp [RedmineID: #84690]
		- 20200602@Percy: Separate PendingTransfer3rd to Cash and Balance [RedmineID: #135200]
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @username NVARCHAR(50), @givenCredit MONEY, @memberCredit MONEY

	SELECT @username = username, @givenCredit = ISNULL(Credit, 0)
	FROM dbo.custInfo WITH (NOLOCK)
	WHERE custid = @custid

	SELECT @memberCredit = ISNULL(SUM(credit), 0)
	FROM dbo.custInfo WITH (NOLOCK)
	WHERE srecommend = @custid AND roleid = 3

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
	
	-- cash
	INSERT INTO #BalanceInfo
	(
		superCash,		yesterdaySuperCash,
		masterCash,		yesterdayMasterCash,
		agentCash,		yesterdayAgentCash,
		memberCash,		yesterdayMemberCash,
		PendingTransfer3rd
	)
	EXEC dbo.Acc_CustomerSelCash @CustId = @CustId

	-- winloss
	INSERT INTO #BalanceInfo
	(
		todayWinloss,	yesterdayWinloss
	)
	EXEC dbo.Acc_CustomerSelWinLoss @CustId = @CustId

	SELECT
		@username					AS username,
		SUM(superCash)				AS cashBalance,
		SUM(yesterdaySuperCash)		AS yesterday_CashBalance,
		SUM(superCash + masterCash + agentCash + memberCash) AS totalBalance,
		SUM(yesterdaySuperCash + yesterdayMasterCash + yesterdayAgentCash + yesterdayMemberCash) AS yesterday_totalBalance,
		SUM(todayWinloss)			AS todayWinloss,
		SUM(yesterdayWinloss)		AS yesterdayWinloss,
		@givenCredit				AS givenCredit,
		@memberCredit				AS memberCredit,
		SUM(PendingTransfer3rd)	AS PendingTransfer3rd
	FROM #BalanceInfo

	DROP TABLE #BalanceInfo
END
GO