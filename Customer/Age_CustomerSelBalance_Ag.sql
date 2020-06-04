/*<info serverAlias="DBAGE-bodb02" executers="bodbDownlineNet,bodbDownlineNetView" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Age_CustomerSelBalance_Ag]
	@CustID					INT, -- recommend
	@UserName				VARCHAR(50) = '' OUTPUT,
	-- Cash/Balance
	@CashBalance			MONEY = 0 OUTPUT,
	@Yesterday_CashBalance	MONEY = 0 OUTPUT,  
	@TotalBalance			MONEY = 0 OUTPUT,
	@Yesterday_TotalBalance MONEY = 0 OUTPUT,
	-- Outstanding
	@AgentOutstanding		MONEY = 0 OUTPUT,
	@TotalOutstanding		MONEY = 0 OUTPUT,
	-- @PendingTransfer3rd
	@PendingTransfer3rd		MONEY = 0 OUTPUT,
	-- Credit
	@AgentCredit			MONEY = 0 OUTPUT,
	@TotalMemberCredit		MONEY = 0 OUTPUT,
	-- All downlines's status
	@TotalMemberActive		INT = 0 OUTPUT,
	@TotalMemberClosed		INT = 0 OUTPUT,
	@TotalMemberSuspended	INT = 0 OUTPUT
AS

/*
	Created by Percy
	Date: 2017-10-20
	DB: DBAGE.bodb02
	Task: Member Information - Agent View - Credit/Balance

	Revisions:
		- 20171020@Percy: Apply core SP [RedmineID: #84690]
		- 20190918@Percy: Remove inactive products [RedmineID: #118699]
		- 20200602@Percy: Separate PendingTransfer3rd from Cash and Balance [RedmineID: #135200]
*/

BEGIN
	SET NOCOUNT ON

	SELECT
		@UserName = UserName,
		@AgentCredit = ISNULL(Credit, 0)
	FROM dbo.custInfo WITH (NOLOCK)
	WHERE CustID = @CustID

	-- all downlines's status + credit
	SELECT
		@TotalMemberCredit		= ISNULL(SUM(ISNULL(Credit, 0)), 0),
		@TotalMemberActive		= ISNULL(SUM(CASE WHEN Closed = 0 AND ISNULL(reject, 0) = 0 THEN 1 ELSE 0 END), 0),
		@TotalMemberClosed		= ISNULL(SUM(CASE WHEN Closed = 1 THEN 1 ELSE 0 END), 0),
		@TotalMemberSuspended	= ISNULL(SUM(CASE WHEN ISNULL(reject, 0) = 1 AND closed = 0 THEN 1 ELSE 0 END), 0)
	FROM dbo.custInfo WITH (NOLOCK)
	WHERE recommend = @CustID
		AND RoleID = 1

	CREATE TABLE #BalanceInfo
	(
		superCash	MONEY DEFAULT ((0)), yesterdaySuperCash	 MONEY DEFAULT ((0)), superOutstanding  MONEY DEFAULT ((0)),
		masterCash	MONEY DEFAULT ((0)), yesterdayMasterCash MONEY DEFAULT ((0)), masterOutstanding MONEY DEFAULT ((0)),
		agentCash	MONEY DEFAULT ((0)), yesterdayAgentCash	 MONEY DEFAULT ((0)), agentOutstanding  MONEY DEFAULT ((0)),
		memberCash	MONEY DEFAULT ((0)), yesterdayMemberCash MONEY DEFAULT ((0)), memberOutstanding MONEY DEFAULT ((0)),
		PendingTransfer3rd MONEY DEFAULT ((0))
	)

	INSERT INTO #BalanceInfo
	(
		superCash,  yesterdaySuperCash,
		masterCash, yesterdayMasterCash,
		agentCash,  yesterdayAgentCash,
		memberCash, yesterdayMemberCash,
		PendingTransfer3rd
	)
	EXEC dbo.Acc_CustomerSelCash @CustId = @CustId

	INSERT INTO #BalanceInfo
	(
		superOutstanding,
		masterOutstanding,
		agentOutstanding,
		memberOutstanding
	)
	EXEC dbo.Acc_CustomerSelOutstanding @CustId = @CustId

	SELECT
		@CashBalance			= SUM(agentCash),
		@Yesterday_CashBalance	= SUM(yesterdayAgentCash),  
		@TotalBalance			= SUM(agentCash + memberCash),
		@Yesterday_TotalBalance = SUM(yesterdayAgentCash + yesterdayMemberCash),
		@AgentOutstanding		= SUM(agentOutstanding),
		@TotalOutstanding		= SUM(memberOutstanding),
		@PendingTransfer3rd		= SUM(PendingTransfer3rd)
	FROM #BalanceInfo

	DROP TABLE #BalanceInfo
END
GO