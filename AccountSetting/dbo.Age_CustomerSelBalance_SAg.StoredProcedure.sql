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

*/
SET NOCOUNT ON

Select 
	@UserName = UserName,
	@SuperCredit = isnull(Credit, 0)
From custinfo with (NOLOCK)
Where CustID = @CustID

Select 
	@TotalMAgentCredit = isnull(sum(case when RoleID = 3 then Credit else 0 end), 0), 
	@TotalAgentCredit = isnull(sum(case when RoleID = 2 then Credit else 0 end), 0), 
	@TotalMemberCredit = isnull(sum(case when RoleID = 1 then Credit else 0 end), 0),
	
	@TotalMAgentActive = isnull(sum(case when RoleID = 3 and Closed = 0 and isnull(reject,0) = 0 then 1 else 0 end), 0),
	@TotalMAgentClosed = isnull(sum(case when RoleID = 3 and Closed = 1 then 1 else 0 end), 0),
	@TotalMAgentSuspended = isnull(sum(case when RoleID = 3 and isnull(reject,0) = 1 and Closed = 0 then 1 else 0 end), 0),
	
	@TotalAgentActive = isnull(sum(case when RoleID = 2 and Closed = 0 and isnull(reject,0) = 0 then 1 else 0 end), 0),
	@TotalAgentClosed = isnull(sum(case when RoleID = 2 and Closed = 1 then 1 else 0 end), 0),
	@TotalAgentSuspended = isnull(sum(case when RoleID = 2 and isnull(reject,0) = 1 and Closed = 0 then 1 else 0 end), 0),
	
	@TotalMemberActive = isnull(sum(case when RoleID = 1 and Closed = 0 and isnull(reject,0) = 0 then 1 else 0 end), 0),
	@TotalMemberClosed = isnull(sum(case when RoleID = 1 and Closed = 1 then 1 else 0 end), 0),
	@TotalMemberSuspended = isnull(sum(case when RoleID = 1 and isnull(reject,0) = 1 and Closed = 0 then 1 else 0 end), 0)
	
From Custinfo with (NOLOCK)
Where SRecommend = @CustID

SELECT 
	@CashBalance=IsNull(sum(case when custid=srecommend then winlost-actual_stake else swinlost+scomm-acomm end),0),  	
	@SuperOutstanding=IsNull(sum(case when ruben=0 then ABS(actual_stake) * spositiontaking else 0 end),0), 
	@TotalOutstanding=IsNull(sum(case when ruben=0 then ABS(actual_stake) else 0 end),0),
	@TotalCSTransfer=IsNull(sum(case when bettype=23001 and ruben=0 then actual_stake else 0 end),0),
	@TotalCSOutstanding=IsNull(sum(case when bettype=23002 and ruben=0 then actual_stake else 0 end),0),
	@TotalBITransfer=IsNull(sum(case when bettype=23201 and ruben=0 then actual_stake else 0 end),0),
	@TotalBIOutstanding=IsNull(sum(case when bettype=23202 and ruben=0 then actual_stake else 0 end),0),
	@TotalP2PTransfer=IsNull(sum(case when bettype=23101 and ruben=0 then actual_stake else 0 end),0),
	@TotalP2POutstanding=IsNull(sum(case when bettype=23102 and ruben=0 then actual_stake else 0 end),0),
	@TotalBalance = IsNull(sum(case when custid=srecommend then winlost-actual_stake else swinlost+scomm-acomm end),0)
					+ IsNull(sum(case when custid=mrecommend then winlost-actual_stake else mwinlost+acomm-comm end),0)
					+ IsNull(sum(case when custid=recommend then winlost-actual_stake else awinlost+comm-playercomm end),0)
					+ IsNull(sum(case when custid <> recommend and custid <> mrecommend and custid <> srecommend and ruben=1 then winlost-actual_stake+playercomm else 0 end),0)
			
		/*	IsNull(sum(case when bettype > 90 then winlost-actual_stake 
									when bettype < 91 and ruben =1 then swinlost+scomm + mwinlost + awinlost + winlost-actual_stake 
									else 0 
									end),0)*/
			
FROM bettrans WITH (NOLOCK)  
WHERE srecommend=@CustID 
/*
SELECT 
	@Yesterday_CashBalance=IsNull(sum(case when custid=srecommend then winlost-actual_stake else swinlost+scomm-acomm end),0),  
	@Yesterday_TotalBalance = 
				IsNull(sum(case when custid=srecommend then winlost-actual_stake else swinlost+scomm-acomm end),0)
				+ IsNull(sum(case when custid=mrecommend then winlost-actual_stake else mwinlost+acomm-comm end),0)
				+ IsNull(sum(case when custid=recommend then winlost-actual_stake else awinlost+comm-playercomm end),0)
				+ IsNull(sum(case when custid <> recommend and custid <> mrecommend and custid <> srecommend and ruben=1 then winlost-actual_stake+playercomm else 0 end),0)
FROM bettrans WITH (NOLOCK)  
WHERE srecommend=@CustID and bettrans.winlostdate < convert(varchar(10), CURRENT_TIMESTAMP, 120)
*/

SELECT 
	@Yesterday_CashBalance  = @CashBalance - isnull(today_balance.cashBalance,0),
	@Yesterday_TotalBalance = @TotalBalance - isnull(today_balance.totalBalance,0)
FROM 
	(	SELECT 
			IsNull(sum(swinlost+scomm-acomm),0) cashBalance,  
			IsNull(sum(swinlost+scomm + mwinlost + awinlost + winlost-actual_stake),0) totalBalance 
		FROM bettrans WITH (NOLOCK)  
		WHERE srecommend=@CustID  and ruben = 1 and bettype <= 19000
			and bettrans.winlostdate >= convert(varchar(10), CURRENT_TIMESTAMP, 120)
	 )today_balance 

GO
GRANT EXECUTE ON [dbo].[Age_CustomerSelBalance_SAg] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_CustomerSelBalance_SAg] TO [bodbDownlineNetView]
GO
GRANT VIEW DEFINITION ON [dbo].[Age_CustomerSelBalance_SAg] TO [vnteam]