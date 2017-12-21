/*<info serverAlias="DBAGE-bodb02" executers="bodbDownlineNet,bodbDownlineNetView" viewers="vnteam" isFunction="0" isNested="0"></info>*/
USE [bodb02]
GO

ALTER PROCEDURE [dbo].[Age_CustomerSelBalance_MAg]
	@CustID					INT, -- recommend
	@UserName				VARCHAR(50) = '' OUTPUT,
	-- Cash/Balance
	@CashBalance			MONEY = 0 OUTPUT,
	@Yesterday_CashBalance	MONEY = 0 OUTPUT,  
	@TotalBalance			MONEY = 0 OUTPUT,
	@Yesterday_TotalBalance MONEY = 0 OUTPUT,
	-- Casino, Bingo, PSP
	@TotalCSTransfer		MONEY = 0 OUTPUT,
	@TotalCSOutstanding		MONEY = 0 OUTPUT,
	@TotalBITransfer		MONEY = 0 OUTPUT,
	@TotalBIOutstanding		MONEY = 0 OUTPUT,
	@TotalP2PTransfer		MONEY = 0 OUTPUT,
	@TotalP2POutstanding	MONEY = 0 OUTPUT,
	-- Outstanding
	@MasterOutstanding		MONEY = 0 OUTPUT,
	@TotalOutstanding		MONEY = 0 OUTPUT,
	-- Credit
	@MasterCredit			MONEY = 0 OUTPUT,
	@TotalAgentCredit		MONEY = 0 OUTPUT,
	@TotalMemberCredit		MONEY = 0 OUTPUT,
	-- All downlines's status
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
	Task: Member Information - Master View - Credit/Balance

	Revisions:
		- 20171020@Percy: Apply core SP [RedmineID: #84690]
*/

BEGIN
	SET NOCOUNT ON

	SELECT
		@UserName = UserName,
		@MasterCredit = ISNULL(Credit, 0)
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
		WHERE mrecommend = @CustId
			AND roleid <> 3
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
		@TotalAgentSuspended  = ISNULL(CASE WHEN roleId = 2 THEN Suspended	ELSE @TotalAgentSuspended	END, 0)
	FROM custStatus

	SELECT 
		@TotalCSTransfer     = ISNULL(SUM(CASE WHEN bettype = 23001 THEN actual_stake ELSE 0 END),0),
		@TotalCSOutstanding  = ISNULL(SUM(CASE WHEN bettype = 23002 THEN actual_stake ELSE 0 END),0),
		@TotalBITransfer     = ISNULL(SUM(CASE WHEN bettype = 23201 THEN actual_stake ELSE 0 END),0),
		@TotalBIOutstanding  = ISNULL(SUM(CASE WHEN bettype = 23202 THEN actual_stake ELSE 0 END),0),
		@TotalP2PTransfer    = ISNULL(SUM(CASE WHEN bettype = 23101 THEN actual_stake ELSE 0 END),0),
		@TotalP2POutstanding = ISNULL(SUM(CASE WHEN bettype = 23102 THEN actual_stake ELSE 0 END),0)
	FROM dbo.bettrans WITH (NOLOCK)  
	WHERE mrecommend = @CustID
		AND bettype IN (23001, 23002, 23101, 23102, 23201, 23202)
		AND ruben = 0

	CREATE TABLE #BalanceInfo
	(
		superCash	MONEY DEFAULT ((0)), yesterdaySuperCash	 MONEY DEFAULT ((0)), superOutstanding  MONEY DEFAULT ((0)),
		masterCash	MONEY DEFAULT ((0)), yesterdayMasterCash MONEY DEFAULT ((0)), masterOutstanding MONEY DEFAULT ((0)),
		agentCash	MONEY DEFAULT ((0)), yesterdayAgentCash	 MONEY DEFAULT ((0)), agentOutstanding  MONEY DEFAULT ((0)),
		memberCash	MONEY DEFAULT ((0)), yesterdayMemberCash MONEY DEFAULT ((0)), memberOutstanding MONEY DEFAULT ((0))
	)

	INSERT INTO #BalanceInfo
	(
		superCash,  yesterdaySuperCash,
		masterCash, yesterdayMasterCash,
		agentCash,  yesterdayAgentCash,
		memberCash, yesterdayMemberCash
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
		@CashBalance			= SUM(masterCash),
		@Yesterday_CashBalance	= SUM(yesterdayMasterCash),  
		@TotalBalance			= SUM(masterCash + agentCash + memberCash),
		@Yesterday_TotalBalance = SUM(yesterdayMasterCash + yesterdayAgentCash + yesterdayMemberCash),
		@MasterOutstanding		= SUM(masterOutstanding),
		@TotalOutstanding		= SUM(memberOutstanding)
	FROM #BalanceInfo

	DROP TABLE #BalanceInfo
END
GO