ALTER PROCEDURE [dbo].[Age_CustomerSelBalance_SAg]
	@CustID int,
	@UserName varchar(20) = '' OUTPUT ,
	@CashBalance money = 0 OUTPUT,
	@Yesterday_CashBalance money = 0 OUTPUT,
	@TotalBalance money = 0 OUTPUT,
	@Yesterday_TotalBalance money = 0 OUTPUT,
	@TotalCSTransfer money = 0 OUTPUT,
	@TotalCSOutstanding money = 0 OUTPUT,
	@TotalBITransfer money = 0 OUTPUT,
	@TotalBIOutstanding money = 0 OUTPUT,
	@TotalP2PTransfer money = 0 OUTPUT,
	@TotalP2POutstanding money = 0 OUTPUT,
	@SuperOutstanding money = 0 OUTPUT,
	@TotalOutstanding money = 0 OUTPUT,	
	@SuperCredit money = 0 OUTPUT,
	@TotalMAgentCredit money = 0 OUTPUT, 
	@TotalAgentCredit money = 0 OUTPUT, 
	@TotalMemberCredit money = 0 OUTPUT,
	@TotalMAgentActive int = 0 OUTPUT,
	@TotalMAgentClosed int = 0 OUTPUT,
	@TotalMAgentSuspended int = 0 OUTPUT,
	@TotalAgentActive int = 0 OUTPUT,
	@TotalAgentClosed int = 0 OUTPUT,
	@TotalAgentSuspended int = 0 OUTPUT,
	@TotalMemberActive int = 0 OUTPUT,
	@TotalMemberClosed int = 0 OUTPUT,	
	@TotalMemberSuspended int = 0 OUTPUT
	
AS
/*
Created: 20090218@ThoNguyen
Task: Get Super Agent Balance
DB: DB053.bodb02
Original:CustomerSelBalance_SAg

Revisions:
    - 20090216@ThoNguyen: Add 3 param more "@TotalMAgentSuspended,@TotalAgentSuspended,@TotalMemberSuspended" to view total member suspended
    - 20090422@Simon: Add 2 param more " @SuperCSOutstanding , @TotalCSOutstanding " to view Outstanding of Casino
	- 20091110@Jamie: Including Casino Outstanding in total outstanding 
	- 20100904@Kiwi: Get Transfer and Outstanding data for IBCBet Bingo
	- 20101224@Johnson: Apply new arrange of bettype
	- 20110824@Sophia: Count Negative stake as positive Outstanding
	- 20120227@Elodie: Add 2 params @TotalP2PTransfer, @TotalP2POutstanding to view P2P transfer/outstanding
                       Delete @ABSDate= 2011-9-1 param and condition to check WinLossDate > @ABSDate
					   Remove bettype = 23101 in total Casino Outstanding
	- 20140304@Kathy: modify formula of Outstanding amount to be calculated based on table Bettrans and TransLog [Redmine:#11550]
	- 20150707@Jim: exclude Metric Gaming running ticket from bettrans (Feature #38789)
	- 20151209@Percy: exclude Cockfighting running ticket from bettrans [Redmine: #48604]
	- 20160113@Percy: expand new bettype for RNG Casino [Redmine: #48283]
*/
SET NOCOUNT ON

DECLARE @translog_superOutstanding money,
		@translog_totalOutstanding money

DECLARE @today DATE,
		@yesterday DATE
SELECT @today = CONVERT(DATE, GETDATE())
SELECT @yesterday = DATEADD(DD, -1, @today)

Select 
	@UserName = UserName,
	@SuperCredit = ISNULL(Credit, 0)
From custinfo with (NOLOCK)
Where CustID = @CustID

Select 
	@TotalMAgentCredit = ISNULL(sum(case when RoleID = 3 then Credit else 0 end), 0), 
	@TotalAgentCredit = ISNULL(sum(case when RoleID = 2 then Credit else 0 end), 0), 
	@TotalMemberCredit = ISNULL(sum(case when RoleID = 1 then Credit else 0 end), 0),
	
	@TotalMAgentActive = ISNULL(sum(case when RoleID = 3 and Closed = 0 and ISNULL(reject,0) = 0 then 1 else 0 end), 0),
	@TotalMAgentClosed = ISNULL(sum(case when RoleID = 3 and Closed = 1 then 1 else 0 end), 0),
	@TotalMAgentSuspended = ISNULL(sum(case when RoleID = 3 and ISNULL(reject,0) = 1 and Closed = 0 then 1 else 0 end), 0),
	
	@TotalAgentActive = ISNULL(sum(case when RoleID = 2 and Closed = 0 and ISNULL(reject,0) = 0 then 1 else 0 end), 0),
	@TotalAgentClosed = ISNULL(sum(case when RoleID = 2 and Closed = 1 then 1 else 0 end), 0),
	@TotalAgentSuspended = ISNULL(sum(case when RoleID = 2 and ISNULL(reject,0) = 1 and Closed = 0 then 1 else 0 end), 0),
	
	@TotalMemberActive = ISNULL(sum(case when RoleID = 1 and Closed = 0 and ISNULL(reject,0) = 0 then 1 else 0 end), 0),
	@TotalMemberClosed = ISNULL(sum(case when RoleID = 1 and Closed = 1 then 1 else 0 end), 0),
	@TotalMemberSuspended = ISNULL(sum(case when RoleID = 1 and ISNULL(reject,0) = 1 and Closed = 0 then 1 else 0 end), 0)
	
From Custinfo with (NOLOCK)
Where SRecommend = @CustID

SELECT @translog_superOutstanding = ISNULL(SUM(ABS(actual_stake)*spositiontaking),0),
	   @translog_totalOutstanding = ISNULL(SUM(ABS(actual_stake)),0)
FROM translog with(NOLOCK)
WHERE srecommend = @custid 
and statusid = 0

SELECT 
	@CashBalance         = ISNULL(sum(case when custid= srecommend then winlost-actual_stake else swinlost+scomm-acomm end),0),  	
	@SuperOutstanding    = ISNULL(sum(case when ruben= 0 then ABS(actual_stake) * spositiontaking else 0 end),0) + @translog_superOutstanding, 
	@TotalOutstanding    = ISNULL(sum(case when ruben= 0 then ABS(actual_stake) else 0 end),0) + @translog_totalOutstanding,
	@TotalCSTransfer     = ISNULL(sum(case when bettype= 23001 and ruben= 0 then actual_stake else 0 end),0),
	@TotalCSOutstanding  = ISNULL(sum(case when bettype= 23002 and ruben= 0 then actual_stake else 0 end),0),
	@TotalBITransfer     = ISNULL(sum(case when bettype= 23201 and ruben= 0 then actual_stake else 0 end),0),
	@TotalBIOutstanding  = ISNULL(sum(case when bettype= 23202 and ruben= 0 then actual_stake else 0 end),0),
	@TotalP2PTransfer    = ISNULL(sum(case when bettype= 23101 and ruben= 0 then actual_stake else 0 end),0),
	@TotalP2POutstanding = ISNULL(sum(case when bettype= 23102 and ruben= 0 then actual_stake else 0 end),0),
	@TotalBalance        = ISNULL(sum(case when custid= srecommend then winlost-actual_stake else swinlost+scomm-acomm end),0)
							+ ISNULL(sum(case when custid= mrecommend then winlost-actual_stake else mwinlost+acomm-comm end),0)
							+ ISNULL(sum(case when custid= recommend then winlost-actual_stake else awinlost+comm-playercomm end),0)
							+ ISNULL(sum(case when custid <> recommend and custid <> mrecommend and custid <> srecommend and ruben= 1 then winlost-actual_stake+playercomm else 0 end),0)		
FROM bettrans WITH (NOLOCK)  
WHERE srecommend= @CustID 
	AND(
			(bettype NOT IN (801,802,803,804,805,806,1003) AND bettype NOT BETWEEN 2101 AND 2399 AND ruben = 0)
			OR ruben <> 0
		)
	AND(
			(CONVERT(DATE, winlostdate) >= @yesterday AND bettype NOT BETWEEN 2101 AND 2399)
			OR CONVERT(DATE, winlostdate) < @yesterday
	   )

SELECT 
	@CashBalance         = @CashBalance         + ISNULL(sum(case when CONVERT(DATE, winlostdate) >= @yesterday THEN CASE WHEN custid= srecommend then winlost-actual_stake else swinlost+scomm-acomm end ELSE 0 END),0),  	
	@SuperOutstanding    = @SuperOutstanding    + ISNULL(sum(case when statusID IN (0, 1) then ABS(actual_stake) * spositiontaking else 0 end),0), 
	@TotalOutstanding    = @TotalOutstanding    + ISNULL(sum(case when statusID IN (0, 1) then ABS(actual_stake) else 0 end),0),
	@TotalBalance        = @TotalBalance        + ISNULL(sum(case when CONVERT(DATE, winlostdate) >= @yesterday THEN CASE WHEN custid= srecommend then winlost-actual_stake else swinlost+scomm-acomm end ELSE 0 END),0)
													+ ISNULL(sum(case when CONVERT(DATE, winlostdate) >= @yesterday THEN CASE WHEN custid= mrecommend then winlost-actual_stake else mwinlost+acomm-comm end ELSE 0 END),0)
													+ ISNULL(sum(case when CONVERT(DATE, winlostdate) >= @yesterday THEN CASE WHEN custid= recommend then winlost-actual_stake else awinlost+comm-playercomm end ELSE 0 END),0)
													+ ISNULL(sum(case when CONVERT(DATE, winlostdate) >= @yesterday AND custid <> recommend and custid <> mrecommend and custid <> srecommend and statusID NOT IN (0, 1, 101, 102) then winlost-actual_stake+playercomm else 0 end),0)		
FROM bettransRNG WITH (NOLOCK)  
WHERE srecommend= @CustID 
	AND gameID BETWEEN 2101 AND 2399

SELECT 
	@Yesterday_CashBalance  = @CashBalance - ISNULL(today_balance.cashBalance,0),
	@Yesterday_TotalBalance = @TotalBalance - ISNULL(today_balance.totalBalance,0)
FROM 
	(	SELECT 
			ISNULL(sum(swinlost+scomm-acomm),0) cashBalance,  
			ISNULL(sum(swinlost+scomm + mwinlost + awinlost + winlost-actual_stake),0) totalBalance 
		FROM bettrans WITH (NOLOCK)  
		WHERE srecommend= @CustID
			AND ruben = 1
			AND bettype <= 19000 AND bettype NOT BETWEEN 2101 AND 2399
			AND CONVERT(DATE, winlostdate) = @today
	 )today_balance

SELECT 
 @Yesterday_CashBalance  = @Yesterday_CashBalance  - isnull(today_balanceRNG.cashBalance,0),
 @Yesterday_TotalBalance = @Yesterday_TotalBalance - isnull(today_balanceRNG.totalBalance,0)
FROM 
	(	SELECT
			ISNULL(sum(swinlost+scomm-acomm),0) cashBalance,  
			ISNULL(sum(swinlost+scomm + mwinlost + awinlost + winlost-actual_stake),0) totalBalance
		FROM bettransRNG WITH (NOLOCK)  
		WHERE srecommend= @CustID
			AND gameID BETWEEN 2101 AND 2399
			AND CONVERT(DATE, winlostdate) = @today
			AND statusID NOT IN (0, 1, 101, 102)
	 )today_balanceRNG



GO

GRANT EXECUTE ON [dbo].[Age_CustomerSelBalance_SAg] TO [bodbDownlineNet] AS [dbo]
GO

GRANT EXECUTE ON [dbo].[Age_CustomerSelBalance_SAg] TO [bodbDownlineNetView] AS [dbo]
GO

GRANT VIEW DEFINITION ON [dbo].[Age_CustomerSelBalance_SAg] TO [vnteam] AS [dbo]
GO