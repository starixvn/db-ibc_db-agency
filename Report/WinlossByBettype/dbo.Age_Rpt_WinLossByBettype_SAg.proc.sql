ALTER PROCEDURE [Age_Rpt_WinLossByBettype_SAg]
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
	Company money
)

DECLARE @ABSDate DATETIME
SET @ABSDate = '2011-09-01'

IF @Todate >= @BalanceUpDay 
BEGIN	
	INSERT INTO @SAgWinLoss
		select
			bettype, 
			liveindicator,
		    sum( isnull(scomm/(1-tpositiontaking),0))  as GrossComm,				
			SUM( CASE WHEN winlostdate >= @ABSDate  
				THEN CASE WHEN  bettype in(33,43) AND liveawayscore = 0 THEN ABS(stake)/2 ELSE ABS(stake) END
				ELSE CASE WHEN  bettype in(33,43) AND liveawayscore = 0 THEN stake/2 ELSE stake END
				END
				) as TurnOver,
						
			sum(mwinlost+awinlost+acomm+winlost-actual_stake),
			sum(swinlost),
			isnull(sum(scomm), 0)-isnull(sum(acomm), 0),
			isnull(sum(swinlost), 0) + isnull(sum(scomm), 0)-sum(acomm),
			-(isnull(sum(swinlost), 0) + isnull(sum(awinlost), 0) + isnull(sum(mwinlost), 0) + isnull(sum(scomm), 0) + isnull(sum(winlost-actual_stake), 0))			
		from 
			dbo.bettrans with (nolock,index=IX_srecommend)			
		where
			winlostdate between @FromDate and @ToDate and
			--status not in ('running','waiting','VOID', 'REJECT', 'Refund')  and
			statusID not in (0,1, 101, 102, 103) and
			--ruben=1 and 
			SRecommend=@CustID 
			and bettype < 19001
			AND bettype BETWEEN 81 AND 120
		group by 
			bettype, liveindicator
		UNION ALL --- Not number Game not group by liveindicator
		select
			bettype, 
			0 as liveindicator,
		    sum( case when bettype = 1000 then oddsspread else isnull(scomm/(1-tpositiontaking),0) end) as GrossComm,
			SUM( CASE WHEN winlostdate >= @ABSDate  
				THEN CASE WHEN bettype in(33,43) AND liveawayscore = 0 THEN ABS(stake)/2 ELSE ABS(stake) END
				ELSE CASE WHEN bettype in(33,43) AND liveawayscore = 0 THEN stake/2 ELSE stake END
				END
				) as TurnOver,				
			sum(mwinlost+awinlost+acomm+winlost-actual_stake),
			sum(swinlost),
			isnull(sum(scomm), 0)-isnull(sum(acomm), 0),
			isnull(sum(swinlost), 0) + isnull(sum(scomm), 0)-sum(acomm),
			-(isnull(sum(swinlost), 0) + isnull(sum(awinlost), 0) + isnull(sum(mwinlost), 0) + isnull(sum(scomm), 0) + isnull(sum(winlost-actual_stake), 0))			
		from 
			dbo.bettrans with (nolock,index=IX_srecommend)			
		where
			winlostdate between @FromDate and @ToDate and
			--status not in ('running','waiting','VOID', 'REJECT', 'Refund')  and
			statusID not in (0,1, 101, 102, 103) and
			--ruben=1 and 
			SRecommend=@CustID 
			and bettype < 19001
			AND bettype NOT BETWEEN 81 AND 120
		group by 
			bettype 

	INSERT INTO @SAgWinLoss
		select
			bettype, 
			liveindicator,
		    sum(isnull(scomm/(1-tpositiontaking),0)) as GrossComm,
			SUM( CASE WHEN winlostdate >= @ABSDate  
				THEN CASE WHEN bettype in(33,43) AND liveawayscore = 0 THEN ABS(stake)/2 ELSE ABS(stake) END
				ELSE CASE WHEN bettype in(33,43) AND liveawayscore = 0 THEN stake/2 ELSE stake END
				END
				) as TurnOver,
			sum(mwinlost+awinlost+acomm+winlost-actual_stake),
			sum(swinlost),
			isnull(sum(scomm), 0)-isnull(sum(acomm), 0),
			isnull(sum(swinlost), 0) + isnull(sum(scomm), 0)-sum(acomm),
			-(isnull(sum(swinlost), 0) + isnull(sum(awinlost), 0) + isnull(sum(mwinlost), 0) + isnull(sum(scomm), 0) + isnull(sum(winlost-actual_stake), 0))			
		from 
			dbo.bettrans14 with (nolock)			
		where
			winlostdate between @FromDate and @ToDate and
			--status not in ('running','waiting','VOID', 'REJECT', 'Refund')  and
			statusID not in (101, 102, 103) and
			ruben=1 and 
			SRecommend=@CustID 
			and bettype < 19001
			AND bettype BETWEEN 81 AND 120
		group by 
			bettype, liveindicator
		UNION ALL --- Not number Game not group by liveindicator
		select
			bettype, 
			0 as liveindicator,
		    sum( case when bettype = 1000 then oddsspread else isnull(scomm/(1-tpositiontaking),0) end) as GrossComm,
			SUM( CASE WHEN winlostdate >= @ABSDate  
				THEN CASE WHEN bettype in(33,43) AND liveawayscore = 0 THEN ABS(stake)/2 ELSE ABS(stake) END
				ELSE CASE WHEN bettype in(33,43) AND liveawayscore = 0 THEN stake/2 ELSE stake END
				END
				) as TurnOver,
			sum(mwinlost+awinlost+acomm+winlost-actual_stake),
			sum(swinlost),
			isnull(sum(scomm), 0)-isnull(sum(acomm), 0),
			isnull(sum(swinlost), 0) + isnull(sum(scomm), 0)-sum(acomm),
			-(isnull(sum(swinlost), 0) + isnull(sum(awinlost), 0) + isnull(sum(mwinlost), 0) + isnull(sum(scomm), 0) + isnull(sum(winlost-actual_stake), 0))			
		from 
			dbo.bettrans14 with (nolock)			
		where
			winlostdate between @FromDate and @ToDate and
			--status not in ('running','waiting','VOID', 'REJECT', 'Refund')  and
			statusID not in (101, 102, 103) and
			ruben=1 and 
			SRecommend=@CustID 
			and bettype < 19001
			AND bettype NOT BETWEEN 81 AND 120
		group by 
			bettype
END


SELECT
	bettype, liveindicator,
	sum(GrossComm) as GrossComm,
	sum(TurnOver) as TurnOver,	
	sum(MAgTotal) as MAgTotal,
	sum(SAgWinlost) as SAgWinlost,
	sum(Comm) as Comm,
	sum(SAgTotal) as SAgTotal,
	sum(Company) as Company
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