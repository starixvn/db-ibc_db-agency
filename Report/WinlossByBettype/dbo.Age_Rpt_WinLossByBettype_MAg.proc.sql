ALTER PROCEDURE [dbo].[Age_Rpt_WinLossByBettype_MAg]
	@CustID INT,
	@FromDate SMALLDATETIME,
	@ToDate SMALLDATETIME,	
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
	- 20100619@Phuc: put index hint on bettrans14(index=IX_bettrans4)
	- 20110516@Johnson: Apply new arrange bettype
	- 20110802@Sophia: Add new column liveindicator to separate Fulltime or Deadball, but only for Number Game, if not Number Game not group by liveindicator and return 0 for liveindicator
	- 20110819@Sophia: Count Negative stake as positive turnover
	- 20120608@Elodie: Change the gross commission for P2P
					   Change DB053 server instead of DB052 server
    - 20140509@Logan:	Add counting for number of tickets - Code aligning
*/
SET NOCOUNT ON
DECLARE @MAgWinLoss TABLE
(
	bettype int, 
	liveindicator int,
	GrossComm money,
	TurnOver money, 
	AgTotal money, 
	MAgWinlost money, 
	Comm money, 
	MAgTotal money, 
	Company money,
	NoOfTicket int
)

DECLARE @ABSDate DATETIME
SET @ABSDate = '2011-09-01'

IF @Todate >= @BalanceUpDay 
BEGIN
	INSERT INTO @MAgWinLoss
		select bettype,
		       liveindicator,
		       SUM(acomm/(1 -apositiontaking - mpositiontaking)) as GrossComm,
		       SUM( CASE WHEN winlostdate >= @ABSDate
				THEN CASE WHEN bettype in (33, 43) AND liveawayscore = 0 THEN ABS(stake)/2 ELSE ABS(stake) END
				ELSE CASE WHEN bettype in (33, 43) AND liveawayscore = 0 THEN stake/2 ELSE stake END
				END
				) as TurnOver,
			   isnull(SUM(winlost - actual_stake), 0) + isnull(SUM(awinlost), 0) + isnull(SUM(comm), 0),
			   SUM(mwinlost),
			   isnull(SUM(acomm), 0) - isnull(SUM(comm), 0),
			   isnull(SUM(mwinlost), 0) + isnull(SUM(acomm), 0) - SUM(comm),
			   -(isnull(SUM(awinlost), 0) + isnull(SUM(mwinlost), 0) + isnull(SUM(acomm), 0) + isnull(SUM(winlost - actual_stake), 0)),
			   COUNT(transid) as NoOfTicket
		  from dbo.bettrans with(nolock)
		 where 1 = 1
		   and winlostdate between @FromDate and @ToDate
		   and statusID not in (101, 102, 103)
		   --status not in ('VOID', 'REJECT', 'Refund')  and
		   and ruben = 1
		   and mrecommend = @CustID
		   and bettype < 19001
		   AND bettype BETWEEN 81 AND 120
      group by bettype, liveindicator
	 	 
	 	 UNION ALL --- Not number Game not group by liveindicator

		select bettype,
		       0 as liveindicator,
		       SUM(case when bettype = 1000 then oddsspread else acomm/(1 - apositiontaking - mpositiontaking) end) as GrossComm,
			   SUM(CASE WHEN winlostdate >= @ABSDate
				THEN CASE WHEN bettype in (33, 43) AND liveawayscore = 0 THEN ABS(stake)/2 ELSE ABS(stake) END
				ELSE CASE WHEN bettype in (33, 43) AND liveawayscore = 0 THEN stake/2 ELSE stake END
				END
				) as TurnOver,			
			   isnull(SUM(winlost - actual_stake), 0) + isnull(SUM(awinlost), 0) + isnull(SUM(comm), 0),
			   SUM(mwinlost),
			   isnull(SUM(acomm), 0) - isnull(SUM(comm), 0),
			   isnull(SUM(mwinlost), 0) + isnull(SUM(acomm), 0) - SUM(comm),
			   -(isnull(SUM(awinlost), 0) + isnull(SUM(mwinlost), 0) + isnull(SUM(acomm), 0) + isnull(SUM(winlost - actual_stake), 0)),
			   COUNT(transid) as NoOfTicket
		  from dbo.bettrans with(nolock)
		 where 1 = 1
		   and winlostdate between @FromDate and @ToDate
			--status not in ('VOID', 'REJECT', 'Refund')  and
		   and statusID not in (101, 102, 103)
		   and ruben = 1
		   and mrecommend = @CustID
		   and bettype < 19001
		   AND bettype NOT BETWEEN 81 AND 120
	  group by bettype

	INSERT INTO @MAgWinLoss
		select bettype,
			   liveindicator,
		       SUM(acomm/(1 - apositiontaking - mpositiontaking)) as GrossComm,
			   SUM(CASE WHEN winlostdate >= @ABSDate
				THEN CASE WHEN bettype in (33, 43) AND liveawayscore = 0 THEN ABS(stake)/2 ELSE ABS(stake) END
				ELSE CASE WHEN bettype in (33, 43) AND liveawayscore = 0 THEN stake/2 ELSE stake END
				END
				) as TurnOver,		
			   isnull(SUM(winlost - actual_stake), 0)+isnull(SUM(awinlost), 0) + isnull(SUM(comm), 0),
			   SUM(mwinlost),
			   isnull(SUM(acomm), 0) - isnull(SUM(comm), 0),
			   isnull(SUM(mwinlost), 0) + isnull(SUM(acomm), 0) - SUM(comm),
			   -(isnull(SUM(awinlost), 0) + isnull(SUM(mwinlost), 0) + isnull(SUM(acomm), 0) + isnull(SUM(winlost - actual_stake), 0)),
			   COUNT(transid) as NoOfTicket
		  from dbo.bettrans14 with(nolock, index = IX_bettrans4)			
		 where 1 = 1
	       and winlostdate between @FromDate and @ToDate
			--status not in ('VOID', 'REJECT', 'Refund')  and
		   and statusID not in (101, 102, 103)
		   and ruben = 1
		   and mrecommend = @CustID
		   and bettype < 19001
		   AND bettype BETWEEN 81 AND 120
      group by bettype, liveindicator

	     UNION ALL

		select bettype, 
			   0 as liveindicator,
		       SUM(case when bettype = 1000 then oddsspread else acomm/(1 - apositiontaking - mpositiontaking) end) as GrossComm,
			   SUM(CASE WHEN winlostdate >= @ABSDate  
				THEN CASE WHEN bettype in (33, 43) AND liveawayscore = 0 THEN ABS(stake)/2 ELSE ABS(stake) END
				ELSE CASE WHEN bettype in (33, 43) AND liveawayscore = 0 THEN stake/2 ELSE stake END
				END
				) as TurnOver,			
			   isnull(SUM(winlost - actual_stake), 0) + isnull(SUM(awinlost), 0) + isnull(SUM(comm), 0),
		       SUM(mwinlost),
			   isnull(SUM(acomm), 0) - isnull(SUM(comm), 0),
			   isnull(SUM(mwinlost), 0) + isnull(SUM(acomm), 0) - SUM(comm),
			   -(isnull(SUM(awinlost), 0) + isnull(SUM(mwinlost), 0) + isnull(SUM(acomm), 0) + isnull(SUM(winlost - actual_stake), 0)),
			   COUNT(transid) as NoOfTicket
		  from dbo.bettrans14 with(nolock, index = IX_bettrans4)
		 where 1 = 1
		   and winlostdate between @FromDate and @ToDate
			--status not in ('VOID', 'REJECT', 'Refund')  and
		   and statusID not in (101, 102, 103)
		   and ruben = 1
		   and mrecommend = @CustID
		   and bettype < 19001
		   AND bettype NOT BETWEEN 81 AND 120
	  group by bettype 
END

SELECT bettype, liveindicator,
       SUM(GrossComm) as GrossComm,
	   SUM(TurnOver) as TurnOver,	
	   SUM(AgTotal) as AgTotal,
	   SUM(MAgWinlost) as MAgWinlost,
	   SUM(Comm) as Comm,
	   SUM(MAgTotal) as MAgTotal,
	   SUM(Company) as Company,
       SUM(NoOfTicket) as NoOfTicket
  FROM @MAgWinLoss 
 Group by bettype, liveindicator
 ORDER BY bettype, liveindicator

GO
GRANT EXECUTE ON [dbo].[Age_Rpt_WinLossByBettype_MAg] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_Rpt_WinLossByBettype_MAg] TO [bodbDownlineNetView]
GO
GRANT EXECUTE ON [dbo].[Age_Rpt_WinLossByBettype_MAg] TO [vnteam]
GO
GRANT VIEW DEFINITION ON [dbo].[Age_Rpt_WinLossByBettype_MAg] TO [vnteam]