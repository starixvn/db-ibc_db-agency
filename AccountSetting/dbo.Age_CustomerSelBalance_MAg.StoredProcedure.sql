ALTER PROCEDURE [Age_CustomerSelBalance_MAg]
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
	@MasterOutstanding money = 0 OUTPUT,
	@TotalOutstanding money = 0 OUTPUT,
	@MasterCredit money = 0 OUTPUT,
	@TotalAgentCredit money = 0 OUTPUT, 
	@TotalMemberCredit money = 0 OUTPUT,
	@TotalAgentActive int = 0 OUTPUT,
	@TotalAgentClosed int = 0 OUTPUT,
	@TotalAgentSuspended int = 0 OUTPUT,
	@TotalMemberActive int = 0 OUTPUT,
	@TotalMemberClosed int = 0 OUTPUT,
	@TotalMemberSuspended int = 0 OUTPUT
AS
/*
Created: 20090218@ThoNguyen
Task: Get Master Agent Balance
DB: DB053.bodb02
Original:CustomerSelBalance_MAg

Revisions:
    - 20090216@ThoNguyen: Add 2 param more "@TotalAgentSuspended,@TotalMemberSuspended" to view total member suspended
    - 20090422@Simon: Add 2 param more " @MasterCSOutstanding , @TotalCSOutstanding " to view Outstanding of Casino
	- 20091110@Jamie: Including Casino Outstanding in total outstanding
	- 20100904@Kiwi: Get Transfer and Outstanding data for IBCBet Bingo 
	- 20101224@Johnson: Apply new arrange of bettype
	- 20110824@Sophia: Count Negative stake as positive Outstanding
	- 20120227@Elodie: Add 2 params @TotalP2PTransfer, @TotalP2POutstanding to view P2P transfer/outstanding
                       Delete @ABSDate = 2011-9-1 param and condition to check WinLossDate > @ABSDate
					   Remove bettype = 23101 in total Casino Outstanding
	- 20140304@Kathy: modify formula of Outstanding amount to be calculated based on table Bettrans and TransLog [Redmine:#11550]
	- 20150707@Jim: exclude Metric Gaming running ticket from bettrans (Feature #38789)

*/
SET NOCOUNT ON

DECLARE @translog_masterOutstanding money,
		@translog_totalOutstanding money 
Select 
	@UserName = UserName,
	@MasterCredit = isnull(Credit, 0)
From custinfo with (NOLOCK)
Where CustID = @CustID

Select 
	@TotalAgentCredit = isnull(sum(case when RoleID = 2 then Credit else 0 end), 0), 
	@TotalMemberCredit = isnull(sum(case when RoleID = 1 then Credit else 0 end), 0),
	
	@TotalAgentActive = isnull(sum(case when RoleID = 2 and Closed = 0 and isnull(reject,0) = 0 then 1 else 0 end), 0),
	@TotalAgentClosed = isnull(sum(case when RoleID = 2 and Closed = 1 then 1 else 0 end), 0),
	@TotalAgentSuspended = isnull(sum(case when RoleID = 2 and isnull(reject,0) = 1 and closed = 0 then 1 else 0 end), 0),
	
	@TotalMemberActive = isnull(sum(case when RoleID = 1 and Closed = 0 and isnull(reject,0) = 0 then 1 else 0 end), 0),
	@TotalMemberClosed = isnull(sum(case when RoleID = 1 and Closed = 1 then 1 else 0 end), 0),
	@TotalMemberSuspended = isnull(sum(case when RoleID = 1 and isnull(reject,0) = 1 and closed = 0 then 1 else 0 end), 0)
	
From Custinfo with (NOLOCK)
Where MRecommend = @CustID

SELECT @translog_masterOutstanding = ISNULL(SUM(ABS(actual_stake)*mpositiontaking),0),
		@translog_totalOutstanding = ISNULL(SUM(ABS(actual_stake)),0)
FROM translog with(NOLOCK)
WHERE mrecommend = @custid 
and statusid = 0

SELECT 
	@CashBalance=IsNull(sum(case when custid=mrecommend then winlost-actual_stake else mwinlost+acomm-comm end),0),  	
	@MasterOutstanding=IsNull(sum(case when ruben=0 then ABS(actual_stake) * mpositiontaking else 0 end),0) + @translog_masterOutstanding, 
	@TotalOutstanding=IsNull(sum(case when  ruben=0 then ABS(actual_stake) else 0 end),0) + @translog_totalOutstanding,
	@TotalCSTransfer=IsNull(sum(case when bettype=23001 and ruben=0 then actual_stake else 0 end),0),
	@TotalCSOutstanding=IsNull(sum(case when bettype=23002 and ruben=0 then actual_stake else 0 end),0),
	@TotalBITransfer=IsNull(sum(case when bettype=23201 and ruben=0 then actual_stake else 0 end),0),
	@TotalBIOutstanding=IsNull(sum(case when bettype = 23202 and ruben=0 then actual_stake else 0 end),0),
	@TotalP2PTransfer=IsNull(sum(case when bettype=23101 and ruben=0 then actual_stake else 0 end),0),
	@TotalP2POutstanding=IsNull(sum(case when bettype=23102 and ruben=0 then actual_stake else 0 end),0),
	@TotalBalance = IsNull(sum(case when custid=mrecommend then winlost-actual_stake else mwinlost+acomm-comm end),0)
					+ IsNull(sum(case when custid=recommend then winlost-actual_stake else awinlost+comm-playercomm end),0)
					+ IsNull(sum(case when custid <> recommend and custid <> mrecommend and ruben=1 then winlost-actual_stake+playercomm else 0 end),0)
			 
		/*	IsNull(sum(case when bettype > 90  then winlost-actual_stake 
									when bettype < 91 and ruben =1 then mwinlost+acomm + awinlost + winlost-actual_stake
									else 0 
									end),0)*/
			
FROM bettrans WITH (NOLOCK, index=bettrans16)  
WHERE mrecommend=@CustID 
	AND (
			(bettrans.bettype NOT IN (801,802,803,804,805,806)
			AND ruben =0)
			OR ruben <> 0
			)
/*
SELECT 
	@Yesterday_CashBalance=IsNull(sum(case when custid=mrecommend then winlost-actual_stake else mwinlost+acomm-comm end),0),  
	@Yesterday_TotalBalance = 
				IsNull(sum(case when custid=mrecommend then winlost-actual_stake else mwinlost+acomm-comm end),0)
				+ IsNull(sum(case when custid=recommend then winlost-actual_stake else awinlost+comm-playercomm end),0)
				+ IsNull(sum(case when custid <> recommend and custid <> mrecommend and ruben=1 then winlost-actual_stake+playercomm else 0 end),0)

FROM bettrans WITH (NOLOCK, index=bettrans16)  
WHERE mrecommend=@CustID and bettrans.winlostdate < convert(varchar(10), CURRENT_TIMESTAMP, 120)
*/

SELECT 
	@Yesterday_CashBalance  = @CashBalance - isnull(today_balance.cashBalance,0),
	@Yesterday_TotalBalance = @TotalBalance - isnull(today_balance.totalBalance,0)
FROM 
	(	SELECT	IsNull(sum(mwinlost+ acomm - comm),0) cashBalance,  
				IsNull(sum(mwinlost + acomm + awinlost + winlost-actual_stake),0) totalBalance
		FROM bettrans WITH (NOLOCK)  
		WHERE mrecommend=@CustID and ruben = 1 and bettype <= 19000
			and bettrans.winlostdate >= convert(varchar(10), CURRENT_TIMESTAMP, 120)
			AND (
			(bettrans.bettype NOT IN (801,802,803,804,805,806)
			AND ruben =0)
			OR ruben <> 0
			)
	
	 )today_balance 



GO
GRANT EXECUTE ON [dbo].[Age_CustomerSelBalance_MAg] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_CustomerSelBalance_MAg] TO [bodbDownlineNetView]
GO
GRANT VIEW DEFINITION ON [dbo].[Age_CustomerSelBalance_MAg] TO [vnteam]
