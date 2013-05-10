ALTER PROCEDURE [dbo].[Age_Rpt_WinLossByBettype_Ag]
	@CustID 	INT,
	@FromDate 	SMALLDATETIME,
	@ToDate 	SMALLDATETIME,	
	@BalanceUpDay SMALLDATETIME	
AS

/*
Created: 
Task : Report WinLoss
DB: DB053.bodb02
Revisions:
    - 20090321@Hiep: Get more result for Casino Integration
    - 20090602@Kiwi: exclude "refund" tickets.	
    - 20090702@AnhPham: include gross commission information for all bet types
    - 20090710@Phuc: exclude grosscomm for casino.
	- 20091127@Jamie: Change the gross commission by level (super/master/agent)
			+ super  = scomm/(1 - tpos)
			+ master = acomm/(1 - apos - mpos)
			+ agent  = comm /(1 - apos)
		Applied on Dec 1, 2009 
	- 20091211@Jamie: Show Casino grosscomm instead of 0
	- 20100515@Jamie: Exclude Refund for each way HR 
	- 20100610@Henry: Change to use StatusID instead of Status in WHERE statement
	- 20100617@Thien: put index hint on Bettrans14(index=bettrans143) to ensure correct index used.
	- 20110516@Johnson: Apply new arrange bettype
	- 20110802@Sophia: Add new column liveindicator to separate Fulltime or Deadball, but only for Number Game, if not Number Game not group by liveindicator and return 0 for liveindicator
	- 20110819@Sophia: Count Negative stake as positive turnover
	- 20120608@Elodie: Change the gross commission for P2P
					   Change DB053 server instead of DB052 server	
*/
SET NOCOUNT ON
DECLARE @AgWinLoss TABLE
(
	bettype int, 
	liveindicator int,
	GrossComm money,
	TurnOver money, 
	MemberWinLost money, 
	AgWinLost money, 
	PlayerComm money, 
	AgComm money, 
	MemberTotal money, 
	AgTotal money, 
	Company money
)

DECLARE @ABSDate DATETIME
SET @ABSDate = '2011-09-01'

IF @Todate >= @BalanceUpDay
BEGIN 
	INSERT INTO @AgWinLoss
		SELECT 
			bettype, 
			liveindicator,
		    sum(comm/(1 - apositiontaking)) as GrossComm,
			SUM( CASE WHEN winlostdate >= @ABSDate  
				THEN CASE WHEN  bettype in(33,43) AND liveawayscore = 0 THEN ABS(stake)/2 ELSE ABS(stake) END
				ELSE CASE WHEN  bettype in(33,43) AND liveawayscore = 0 THEN stake/2 ELSE stake END
				END
				) as TurnOver,
			sum(winlost-actual_stake),
			sum(awinlost),	
			sum(playercomm),
			sum(comm-playercomm),
			isnull(sum(winlost-actual_stake), 0) + isnull(sum(playercomm), 0) as MemberTotal,
			isnull(sum(awinlost), 0) + isnull(sum(comm-playercomm), 0) as AgTotal,
			-sum(winlost-actual_stake+awinlost+comm)
		FROM Bettrans WITH(NOLOCK)
		WHERE 
			winlostdate between @FromDate and @ToDate and
			ruben=1 and 
			--status not in ('VOID', 'REJECT', 'Refund')  and
			statusID not in (101, 102, 103) and
			recommend=@custid 
			and bettype < 19001
			AND bettype BETWEEN 81 AND 120
		group by bettype, liveindicator
		UNION ALL --- Not number Game not group by liveindicator
		SELECT 
			bettype, 
			0 as liveindicator,
		    sum(case when bettype = 1000 then oddsspread else comm/(1 - apositiontaking) end) as GrossComm,
			SUM( CASE WHEN winlostdate >= @ABSDate  
				THEN CASE WHEN  bettype in(33,43) AND liveawayscore = 0 THEN ABS(stake)/2 ELSE ABS(stake) END
				ELSE CASE WHEN  bettype in(33,43) AND liveawayscore = 0 THEN stake/2 ELSE stake END
				END
				) as TurnOver,
			sum(winlost-actual_stake),
			sum(awinlost),	
			sum(playercomm),
			sum(comm-playercomm),
			isnull(sum(winlost-actual_stake), 0) + isnull(sum(playercomm), 0) as MemberTotal,
			isnull(sum(awinlost), 0) + isnull(sum(comm-playercomm), 0) as AgTotal,
			-sum(winlost-actual_stake+awinlost+comm)
		FROM Bettrans WITH(NOLOCK)
		WHERE 
			winlostdate between @FromDate and @ToDate and
			ruben=1 and 
			--status not in ('VOID', 'REJECT', 'Refund')  and
			statusID not in (101, 102, 103) and
			recommend=@custid 
			and bettype < 19001
			AND bettype NOT BETWEEN 81 AND 120
		group by bettype 

	INSERT INTO @AgWinLoss
		SELECT 
			bettype, 
			liveindicator,
		    sum(comm/(1 - apositiontaking)) as GrossComm,
			SUM( CASE WHEN winlostdate >= @ABSDate  
				THEN CASE WHEN  bettype in(33,43) AND liveawayscore = 0 THEN ABS(stake)/2 ELSE ABS(stake) END
				ELSE CASE WHEN  bettype in(33,43) AND liveawayscore = 0 THEN stake/2 ELSE stake END
				END
				) as TurnOver,
			sum(winlost-actual_stake),
			sum(awinlost),	
			sum(playercomm),
			sum(comm-playercomm),
			isnull(sum(winlost-actual_stake), 0) + isnull(sum(playercomm), 0) as MemberTotal,
			isnull(sum(awinlost), 0) + isnull(sum(comm-playercomm), 0) as AgTotal,
			-sum(winlost-actual_stake+awinlost+comm)
		FROM Bettrans14 WITH(NOLOCK, index=bettrans143)
		WHERE 
			winlostdate between @FromDate and @ToDate and
			ruben=1 and 
			--status not in ('VOID', 'REJECT', 'Refund')  and
			statusID not in (101, 102, 103) and
			recommend=@custid 
			and bettype < 19001
			AND bettype BETWEEN 81 AND 120
		group by bettype, liveindicator
		UNION ALL
		SELECT 
			bettype,
			0 as  liveindicator,
		    sum(case when bettype = 1000 then oddsspread else comm/(1 - apositiontaking) end) as GrossComm,
			SUM( CASE WHEN winlostdate >= @ABSDate  
				THEN CASE WHEN  bettype in(33,43) AND liveawayscore = 0 THEN ABS(stake)/2 ELSE ABS(stake) END
				ELSE CASE WHEN  bettype in(33,43) AND liveawayscore = 0 THEN stake/2 ELSE stake END
				END
				) as TurnOver,
			sum(winlost-actual_stake),
			sum(awinlost),	
			sum(playercomm),
			sum(comm-playercomm),
			isnull(sum(winlost-actual_stake), 0) + isnull(sum(playercomm), 0) as MemberTotal,
			isnull(sum(awinlost), 0) + isnull(sum(comm-playercomm), 0) as AgTotal,
			-sum(winlost-actual_stake+awinlost+comm)
		FROM Bettrans14 WITH(NOLOCK, index=bettrans143)
		WHERE 
			winlostdate between @FromDate and @ToDate and
			ruben=1 and 
			--status not in ('VOID', 'REJECT', 'Refund')  and
			statusID not in (101, 102, 103) and
			recommend=@custid 
			and bettype < 19001
			AND bettype NOT BETWEEN 81 AND 120
		group by bettype
END

SELECT
	bettype, 
	liveindicator,
	sum(GrossComm) as GrossComm,
	sum(TurnOver) as TurnOver,
	sum(MemberWinLost) as MemberWinLost,
	sum(playercomm) as PlayerComm,
	sum(MemberTotal) as MemberTotal,
	sum(AgWinLost) as AgWinLost,
	sum(AgComm) as AgComm,		
	sum(AgTotal) as AgTotal,
	sum(company) as Company
FROM @AgWinLoss 
Group by bettype, liveindicator
ORDER BY bettype, liveindicator

GO
GRANT EXECUTE ON [dbo].[Age_Rpt_WinLossByBettype_Ag] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_Rpt_WinLossByBettype_Ag] TO [bodbDownlineNetView]
GO
GRANT EXECUTE ON [dbo].[Age_Rpt_WinLossByBettype_Ag] TO [vnteam]
