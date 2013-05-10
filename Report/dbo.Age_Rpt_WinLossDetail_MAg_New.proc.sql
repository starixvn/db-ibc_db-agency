CREATE PROCEDURE [dbo].[Age_Rpt_WinLossDetail_MAg_New] 
	@FromDate smalldatetime,
	@ToDate smalldatetime,
	@MRecommend int = NULL,
	@showSB bit=1,
	@showCasino bit=0,
	@showP2P bit=0,
	@BalanceUpDay SMALLDATETIME	
AS
/*
Created: 
Task : Agent Winloss Detail
DB: DB052.bodb02
Original SP:Age_Rpt_WinLossDetail_MAg
Revisions:
    - 20090508@Hiep: Change the logic of AgTotal

*/

SET NOCOUNT ON

DECLARE @MAgWinLossDetails TABLE(CustID int, TurnOver money, GrossComm money, MemberWinLost money, 
	PlayerComm money, MemberTotal money, AgWinLost money, AgComm money, AgTotal money, 
	MAgWinLost money, MAgComm money, MAgTotal money, Company money)
	
IF @Todate >= @BalanceUpDay
BEGIN 
	INSERT INTO @MAgWinLossDetails
		SELECT
			Recommend,			
			sum(stake), -- TurnOver
			--sum(scomm/(1-tpositiontaking)), -- GrossComm
			case when (@showSB = 1 and bettype < 99 and bettype not in (71,72)) then sum(isnull(scomm/(1-tpositiontaking),0)) else 0 end as GrossComm,
			sum(winlost-actual_stake), --MemberWinlost
			sum(playercomm), -- PlayerComm
			isnull(sum(winlost-actual_stake), 0) + isnull(sum(playercomm), 0), --MemberTotal
			sum(awinlost), -- AgWinlost
			isnull(sum(comm-playercomm),0), --AgComm
			isnull(sum(awinlost), 0) + isnull(sum(comm-playercomm), 0), --AgTotal
			sum(mwinlost), -- MAgWinlost
			sum(acomm)-sum(comm), --MAgComm
			isnull(sum(mwinlost), 0) + isnull(sum(acomm), 0)-sum(comm), --MAgTotal
			-(isnull(sum(awinlost), 0) + isnull(sum(mwinlost), 0) + isnull(sum(acomm), 0) + isnull(sum(winlost-actual_stake), 0))--Company				
		FROM
			dbo.Bettrans WITH (NOLOCK)
		WHERE
			winlostdate between @FromDate and @todate and
			status not in ('running','waiting','VOID', 'REJECT')  and
			ruben=1 and 
			mrecommend=@MRecommend  
			and ((@showSB = 1 and bettype < 99 and bettype not in (71,72)) 
				or (@showCasino = 1 and bettype = 71) 
				or (@showP2P = 1 and bettype = 72))			
		GROUP BY Recommend,bettype	
		
		if @BalanceUpDay < @FromDate
		select @BalanceUpDay=@FromDate
		
	INSERT INTO @MAgWinLossDetails
		SELECT
			CustID,			
			sum(TurnOver), -- TurnOver
			--sum(GrossComm), -- GrossComm
			case when (@showSB = 1 and sporttype = 0 and bettype = 0) then sum(isnull(grosscomm,0)) else 0 end as GrossComm,
			sum(winlost), --MemberWinlost
			sum(playercomm), -- PlayerComm
			isnull(sum(winlost), 0) + isnull(sum(playercomm), 0), --MemberTotal
			sum(awinlost), -- AgWinlost
			isnull(sum(comm-playercomm),0), --AgComm
			isnull(sum(awinlost), 0) + isnull(sum(comm-playercomm), 0), --AgTotal
			sum(mwinlost), -- MAgWinlost
			sum(acomm)-sum(comm), --MAgComm
			isnull(sum(mwinlost), 0) + isnull(sum(acomm), 0)-sum(comm), --MAgTotal
			-(isnull(sum(awinlost), 0) + isnull(sum(mwinlost), 0) + isnull(sum(acomm), 0) + isnull(sum(winlost), 0))--Company				
		FROM
			dbo.Sum_Winloss with (nolock)
		WHERE
			winlostdate between @BalanceUpDay and @todate			
			and MRecommend=@MRecommend
			and RoleID=2
			and ( (@showSB = 1 and sporttype = 0 and bettype = 0) 
				or (@showCasino = 1 and sporttype = 251 and bettype = 71) 
				or (@showP2P = 1 and sporttype = 251 and bettype = 72) )
		GROUP BY CustID, sporttype,bettype					
END

IF @FromDate < @BalanceUpDay 
BEGIN
	if @ToDate >= DATEADD(dd, -1, @BalanceUpDay)
		select @ToDate = DATEADD(dd, -1, @BalanceUpDay)
		
	INSERT INTO @MAgWinLossDetails
		SELECT
			CustID,			
			sum(TurnOver), -- TurnOver
			--sum(grosscomm), -- GrossComm
			case when (@showSB = 1 and sporttype = 0 and bettype = 0) then sum(isnull(grosscomm,0)) else 0 end as GrossComm,
			sum(winlost), --MemberWinlost
			sum(playercomm), -- PlayerComm
			isnull(sum(winlost), 0) + isnull(sum(playercomm), 0), --MemberTotal
			sum(awinlost), -- AgWinlost
			isnull(sum(comm-playercomm),0), --AgComm
			isnull(sum(awinlost), 0) + isnull(sum(comm-playercomm), 0), --AgTotal
			sum(mwinlost), -- MAgWinlost
			sum(acomm)-sum(comm), --MAgComm
			isnull(sum(mwinlost), 0) + isnull(sum(acomm), 0)-sum(comm), --MAgTotal
			-(isnull(sum(awinlost), 0) + isnull(sum(mwinlost), 0) + isnull(sum(acomm), 0) + isnull(sum(winlost), 0))--Company				
		FROM
			DB06.bodb_archive.dbo.Sum_Winloss_Old with (nolock)
		WHERE
			winlostdate between @fromdate and @ToDate			
			and MRecommend=@MRecommend
			and RoleID=2
			and ( (@showSB = 1 and sporttype = 0 and bettype = 0) 
				or (@showCasino = 1 and sporttype = 251 and bettype = 71) 
				or (@showP2P = 1 and sporttype = 251 and bettype = 72) )
		GROUP BY CustID,sporttype,bettype					
END	

SELECT
	w.CustID, 
	c.UserName, 
	sum(TurnOver) as TurnOver,
	sum(GrossComm) as GrossComm,
	sum(MemberWinLost) as MemberWinlost,
	sum(PlayerComm) as PlayerComm,
	sum(MemberTotal) as MemberTotal,
	sum(AgWinlost) as AgWinlost,
	sum(AgComm) as AgComm,
	sum(AgTotal) as AgTotal,
	sum(MAgWinlost) as MAgWinlost,
	sum(MAgComm) as MAgComm,
	sum(MAgTotal) as MAgTotal,
	sum(Company) as Company	
FROM @MAgWinLossDetails w INNER JOIN Customer c WITH(NOLOCK) ON w.CustID = c.CustID 
Group by w.CustID, c.UserName
order by c.Username

GO
GRANT EXECUTE ON [dbo].[Age_Rpt_WinLossDetail_MAg_New] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_Rpt_WinLossDetail_MAg_New] TO [bodbDownlineNetView]
GO
GRANT VIEW DEFINITION ON [dbo].[Age_Rpt_WinLossDetail_MAg_New] TO vnteam
