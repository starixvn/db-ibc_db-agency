/*<info serverAlias="DBAGE-bodb02" executers="bodbDownlineNet,bodbDownlineNetView" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Age_CustomerSelBalance_SAg]
	@CustID					INT, -- recommend
	@UserName				VARCHAR(50) = '' OUTPUT,
	-- Cash/Balance
	@CashBalance			MONEY = 0 OUTPUT,
	@Yesterday_CashBalance	MONEY = 0 OUTPUT,  
	@TotalBalance			MONEY = 0 OUTPUT,
	@Yesterday_TotalBalance MONEY = 0 OUTPUT,
	-- Outstanding
	@SuperOutstanding		MONEY = 0 OUTPUT,
	@TotalOutstanding		MONEY = 0 OUTPUT,
	-- @3rdPendingTransfer
	@3rdPendingTransfer		MONEY = 0 OUTPUT,
	-- Credit
	@SuperCredit			MONEY = 0 OUTPUT,
	@TotalMAgentCredit		MONEY = 0 OUTPUT,
	@TotalAgentCredit		MONEY = 0 OUTPUT,
	@TotalMemberCredit		MONEY = 0 OUTPUT,
	-- All downlines's status
	@TotalMAgentActive		INT = 0 OUTPUT,
	@TotalMAgentClosed		INT = 0 OUTPUT,
	@TotalMAgentSuspended	INT = 0 OUTPUT,
	@TotalAgentActive		INT = 0 OUTPUT,
	@TotalAgentClosed		INT = 0 OUTPUT,
	@TotalAgentSuspended	INT = 0 OUTPUT,
	@TotalMemberActive		INT = 0 OUTPUT,
	@TotalMemberClosed		INT = 0 OUTPUT,
	@TotalMemberSuspended	INT = 0 OUTPUT
AS

/*
	Created by Percy
	Date: 2017-10-20
	DB: DBAGE.bodb02
	Task: Member Information - Super View - Credit/Balance

	Revisions:
		- 20171020@Percy: Apply core SP [RedmineID: #84690]
		- 20190918@Percy: Remove inactive products [RedmineID: #118699]
		- 20200602@Percy: Separate 3rdPendingTransfer from Cash and Balance [RedmineID: #135200]
*/

BEGIN
	SET NOCOUNT ON

	SELECT
		@UserName = UserName,
		@SuperCredit = ISNULL(Credit, 0)
	FROM dbo.custInfo WITH (NOLOCK)
	WHERE CustID = @CustID

	-- all downlines's status + credit
	;WITH custStatus AS
	(
		SELECT
			roleid,
			SUM(ISNULL(Credit, 0)) AS Credit,
			SUM(CASE WHEN Closed = 0 AND ISNULL(reject,0) = 0 THEN 1 ELSE 0 END) AS Active,
			SUM(CASE WHEN Closed = 1 THEN 1 ELSE 0 END) AS Closed,
			SUM(CASE WHEN ISNULL(reject,0) = 1 AND Closed = 0 THEN 1 ELSE 0 END) AS Suspended
		FROM dbo.custInfo WITH (NOLOCK)
		WHERE srecommend = @CustId
			AND roleid <> 4
		GROUP BY roleid
	)
	SELECT
		-- member
		@TotalMemberCredit	  = ISNULL(CASE WHEN roleId = 1 THEN Credit		ELSE @TotalMemberCredit		END, 0),
		@TotalMemberActive    = ISNULL(CASE WHEN roleId = 1 THEN Active		ELSE @TotalMemberActive		END, 0),
		@TotalMemberClosed    = ISNULL(CASE WHEN roleId = 1 THEN Closed		ELSE @TotalMemberClosed		END, 0),
		@TotalMemberSuspended = ISNULL(CASE WHEN roleId = 1 THEN Suspended	ELSE @TotalMemberSuspended	END, 0),
		-- agent
		@TotalAgentCredit	  = ISNULL(CASE WHEN roleId = 2 THEN Credit		ELSE @TotalAgentCredit		END, 0),
		@TotalAgentActive     = ISNULL(CASE WHEN roleId = 2 THEN Active		ELSE @TotalAgentActive		END, 0),
		@TotalAgentClosed     = ISNULL(CASE WHEN roleId = 2 THEN Closed		ELSE @TotalAgentClosed		END, 0),
		@TotalAgentSuspended  = ISNULL(CASE WHEN roleId = 2 THEN Suspended	ELSE @TotalAgentSuspended	END, 0),
		-- master
		@TotalMAgentCredit	  = ISNULL(CASE WHEN roleId = 3 THEN Credit		ELSE @TotalMAgentCredit		END, 0),
		@TotalMAgentActive    = ISNULL(CASE WHEN roleId = 3 THEN Active		ELSE @TotalMAgentActive		END, 0),
		@TotalMAgentClosed    = ISNULL(CASE WHEN roleId = 3 THEN Closed		ELSE @TotalMAgentClosed		END, 0),
		@TotalMAgentSuspended = ISNULL(CASE WHEN roleId = 3 THEN Suspended	ELSE @TotalMAgentSuspended	END, 0)
	FROM custStatus

	CREATE TABLE #BalanceInfo
	(
		superCash	MONEY DEFAULT ((0)), yesterdaySuperCash	 MONEY DEFAULT ((0)), superOutstanding  MONEY DEFAULT ((0)),
		masterCash	MONEY DEFAULT ((0)), yesterdayMasterCash MONEY DEFAULT ((0)), masterOutstanding MONEY DEFAULT ((0)),
		agentCash	MONEY DEFAULT ((0)), yesterdayAgentCash	 MONEY DEFAULT ((0)), agentOutstanding  MONEY DEFAULT ((0)),
		memberCash	MONEY DEFAULT ((0)), yesterdayMemberCash MONEY DEFAULT ((0)), memberOutstanding MONEY DEFAULT ((0)),
		[3rdPendingTransfer] MONEY DEFAULT ((0))
	)

	INSERT INTO #BalanceInfo
	(
		superCash,  yesterdaySuperCash,
		masterCash, yesterdayMasterCash,
		agentCash,  yesterdayAgentCash,
		memberCash, yesterdayMemberCash,
		[3rdPendingTransfer]
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
		@CashBalance			= SUM(superCash),
		@Yesterday_CashBalance	= SUM(yesterdaySuperCash),  
		@TotalBalance			= SUM(superCash + masterCash + agentCash + memberCash),
		@Yesterday_TotalBalance = SUM(yesterdaySuperCash + yesterdayMasterCash + yesterdayAgentCash + yesterdayMemberCash),
		@SuperOutstanding		= SUM(superOutstanding),
		@TotalOutstanding		= SUM(memberOutstanding),
		@3rdPendingTransfer		= SUM([3rdPendingTransfer])
	FROM #BalanceInfo

	DROP TABLE #BalanceInfo
END
GO