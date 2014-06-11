ALTER PROCEDURE [dbo].[Age_Rpt_WinLossByBettype_SAg]
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
     - 20090702@AnhPham: include gross commission information for all bet types.
     - 20090710@Phuc: exclude grosscomm for casino.
	 - 20091127@Jamie: Including GrossComm Casino
	 - 20100515@Jamie: Exclude Refund for each way HR 
	 - 20100610@Henry: Change to use StatusID instead of Status in WHERE statement
	 - 20100617@Jamie: Use  new index hint index=IX_srecommend 
	 - 20110516@Johnson: Apply new arrange bettype
	 - 20110802@Sophia: Add new column liveindicator to separate Fulltime or Deadball, but only for Number Game, if not Number Game not group by liveindicator and return 0 for liveindicator
	 - 20110819@Sophia: Count Negative stake as positive turnover
  	 - 20120608@Elodie: Change the gross commission for P2P
						Change DB053 server instead of DB052 server
    - 20140509@Logan:	Add counting for number of tickets - Code aligning						

+ Note: Review index=IX_srecommend when modifying this SP 
*/
SET NOCOUNT ON

DECLARE @SAgWinLoss TABLE
(
	bettype int, 
	liveindicator  int, 
	GrossComm money,
	TurnOver money, 
	MAgTotal money, 
	SAgWinlost money, 
	Comm money, 
	SAgTotal money, 
	Company money,
	NoOfTicket int
)

DECLARE @ABSDate DATETIME
SET @ABSDate = '2011-09-01'

IF @Todate >= @BalanceUpDay 
BEGIN	
	INSERT INTO @SAgWinLoss
		select bettype,
		       liveindicator,
		       SUM(isnull(scomm/(1 - tpositiontaking), 0)) as GrossComm,
			   SUM(CASE WHEN winlostdate >= @ABSDate  
				THEN CASE WHEN bettype in (33, 43) AND liveawayscore = 0 THEN ABS(stake)/2 ELSE ABS(stake) END
				ELSE CASE WHEN bettype in (33, 43) AND liveawayscore = 0 THEN stake/2 ELSE stake END
				END
				) as TurnOver,
    		   SUM(mwinlost + awinlost + acomm + winlost - actual_stake),
			   SUM(swinlost),
			   isnull(SUM(scomm), 0) - isnull(SUM(acomm), 0),
			   isnull(SUM(swinlost), 0) + isnull(SUM(scomm), 0) - SUM(acomm),
			   -(isnull(SUM(swinlost), 0) + isnull(SUM(awinlost), 0) + isnull(SUM(mwinlost), 0) + isnull(SUM(scomm), 0) + isnull(SUM(winlost - actual_stake), 0)),
			   COUNT(transid) as NoOfTicket
		  from dbo.bettrans with(nolock, index = IX_srecommend)			
		 where 1 = 1
		   and winlostdate between @FromDate and @ToDate
			--status not in ('running','waiting','VOID', 'REJECT', 'Refund')  and
		   and statusID not in (0,1, 101, 102, 103)
			--ruben=1 and 
		   and SRecommend = @CustID 
		   and bettype < 19001
		   AND bettype BETWEEN 81 AND 120
	  group by bettype, liveindicator

		 UNION ALL --- Not number Game not group by liveindicator

    	select bettype, 
			   0 as liveindicator,
		       SUM(case when bettype = 1000 then oddsspread else isnull(scomm/(1 - tpositiontaking), 0) end) as GrossComm,
			   SUM(CASE WHEN winlostdate >= @ABSDate
				THEN CASE WHEN bettype in (33, 43) AND liveawayscore = 0 THEN ABS(stake)/2 ELSE ABS(stake) END
				ELSE CASE WHEN bettype in (33, 43) AND liveawayscore = 0 THEN stake/2 ELSE stake END
				END
				) as TurnOver,				
			   SUM(mwinlost + awinlost + acomm + winlost - actual_stake),
			   SUM(swinlost),
			   isnull(SUM(scomm), 0) - isnull(SUM(acomm), 0),
			   isnull(SUM(swinlost), 0) + isnull(SUM(scomm), 0) - SUM(acomm),
			   -(isnull(SUM(swinlost), 0) + isnull(SUM(awinlost), 0) + isnull(SUM(mwinlost), 0) + isnull(SUM(scomm), 0) + isnull(SUM(winlost - actual_stake), 0)),
			   COUNT(transid) as NoOfTicket
		  from dbo.bettrans with(nolock, index = IX_srecommend)
		 where 1 = 1
		   and winlostdate between @FromDate and @ToDate
			--status not in ('running','waiting','VOID', 'REJECT', 'Refund')  and
		   and	statusID not in (0,1, 101, 102, 103)
			--ruben=1 and 
		   and SRecommend = @CustID
		   and bettype < 19001
		   AND bettype NOT BETWEEN 81 AND 120
	  group by bettype

	INSERT INTO @SAgWinLoss
		select bettype, 
			   liveindicator,
		       SUM(isnull(scomm/(1 - tpositiontaking),0)) as GrossComm,
			   SUM(CASE WHEN winlostdate >= @ABSDate
				THEN CASE WHEN bettype in (33, 43) AND liveawayscore = 0 THEN ABS(stake)/2 ELSE ABS(stake) END
				ELSE CASE WHEN bettype in (33, 43) AND liveawayscore = 0 THEN stake/2 ELSE stake END
				END
				) as TurnOver,
               SUM(mwinlost + awinlost + acomm + winlost - actual_stake),
			   SUM(swinlost),
			   isnull(SUM(scomm), 0) - isnull(SUM(acomm), 0),
			   isnull(SUM(swinlost), 0) + isnull(SUM(scomm), 0)-SUM(acomm),
			   -(isnull(SUM(swinlost), 0) + isnull(SUM(awinlost), 0) + isnull(SUM(mwinlost), 0) + isnull(SUM(scomm), 0) + isnull(SUM(winlost - actual_stake), 0)),
			   COUNT(transid) as NoOfTicket
		  from dbo.bettrans14 with(nolock)			
		 where 1 = 1
		   and winlostdate between @FromDate and @ToDate
			--status not in ('running','waiting','VOID', 'REJECT', 'Refund')  and
		   and statusID not in (101, 102, 103)
		   and ruben = 1
		   and SRecommend = @CustID
		   and bettype < 19001
		   AND bettype BETWEEN 81 AND 120
      group by bettype, liveindicator

 		 UNION ALL --- Not number Game not group by liveindicator

		select bettype,
			   0 as liveindicator,
		       SUM(case when bettype = 1000 then oddsspread else isnull(scomm/(1-tpositiontaking),0) end) as GrossComm,
			   SUM(CASE WHEN winlostdate >= @ABSDate
				THEN CASE WHEN bettype in (33, 43) AND liveawayscore = 0 THEN ABS(stake)/2 ELSE ABS(stake) END
				ELSE CASE WHEN bettype in (33, 43) AND liveawayscore = 0 THEN stake/2 ELSE stake END
				END
				) as TurnOver,
			   SUM(mwinlost + awinlost + acomm + winlost - actual_stake),
			   SUM(swinlost),
			   isnull(SUM(scomm), 0) - isnull(SUM(acomm), 0),
			   isnull(SUM(swinlost), 0) + isnull(SUM(scomm), 0) - SUM(acomm),
			   -(isnull(SUM(swinlost), 0) + isnull(SUM(awinlost), 0) + isnull(SUM(mwinlost), 0) + isnull(SUM(scomm), 0) + isnull(SUM(winlost - actual_stake), 0)),
			   COUNT(transid) as NoOfTicket
		  from dbo.bettrans14 with(nolock)			
		 where 1 = 1
		   and winlostdate between @FromDate and @ToDate
			--status not in ('running','waiting','VOID', 'REJECT', 'Refund')  and
		   and statusID not in (101, 102, 103)
		   and ruben = 1
		   and SRecommend = @CustID 
		   and bettype < 19001
		   AND bettype NOT BETWEEN 81 AND 120
      group by bettype
END


SELECT bettype,
       liveindicator,
	   SUM(GrossComm) as GrossComm,
	   SUM(TurnOver) as TurnOver,	
	   SUM(MAgTotal) as MAgTotal,
	   SUM(SAgWinlost) as SAgWinlost,
	   SUM(Comm) as Comm,
	   SUM(SAgTotal) as SAgTotal,
	   SUM(Company) as Company,
       SUM(NoOfTicket) as NoOfTicket
  FROM @SAgWinLoss 
 Group by bettype, liveindicator
 ORDER BY bettype, liveindicator

GO

GRANT EXECUTE ON [dbo].[Age_Rpt_WinLossByBettype_SAg] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_Rpt_WinLossByBettype_SAg] TO [bodbDownlineNetView]
GO
GRANT EXECUTE ON [dbo].[Age_Rpt_WinLossByBettype_SAg] TO [vnteam]
GO