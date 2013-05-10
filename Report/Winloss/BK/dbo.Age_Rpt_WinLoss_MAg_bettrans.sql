ALTER PROCEDURE [dbo].[Age_Rpt_WinLoss_MAg_bettrans]
	@CustID INT,--mrecommend
	@FromDate SMALLDATETIME,
	@ToDate SMALLDATETIME,	
	@showSB bit=1,
	@showCasino bit=0,
	@showP2P bit=0,
	@showHR bit=0,
	@showFI bit=0
AS
/*
    Created: 28 Jun 2010
    Task : 
    DB: DB052.bodb02
    Original SP:Age_Rpt_WinLoss_MAg
    Revisions:
        - 20100628@viet: Created initial SP
		- 20110907@Tom: Change range of bet type : 0->30, 
				apply new bet type 1st correct score on Sport Books	  
		- 20120405@Hurri: Change bettype of P2P (72 -> 1000)      

*/   
SET NOCOUNT ON

SELECT Username, b.*
FROM (
		select
			b.recommend as CustID,		
			SUM(case when b.liveawayscore = 0 and b.bettype in(33,43) then b.stake/2 else b.stake end) TurnOver,	
			SUM(acomm/(1-apositiontaking - mpositiontaking)) as GrossComm,
			isnull(sum(winlost-actual_stake), 0)+isnull(sum(awinlost), 0) + isnull(sum(comm), 0) AgTotal,
			sum(mwinlost) MAgWinlost,
			isnull(sum(acomm), 0) - isnull(sum(comm), 0) Comm,
			isnull(sum(mwinlost), 0) + isnull(sum(acomm), 0)-sum(comm) MAgTotal,
			-(isnull(sum(awinlost), 0) + isnull(sum(mwinlost), 0) + isnull(sum(acomm), 0) + isnull(sum(winlost-actual_stake), 0)) Company
		from 
			dbo.bettrans b WITH (NOLOCK)
		where
			(
				bettype < case when @showSB=1 then 31 else 0 end
				OR bettype between 31 and case when @ShowHR=1 then 49 else 0 end
				OR bettype between 51 and case when @ShowFI=1 then 69 else 0 end
				OR bettype = case when @showCasino=1 then 71 else 0 end
				OR bettype = case when @showP2P=1 then 1000 else 0 end	--20120405@Hurri
			) AND
			mrecommend=@CustID AND
			winlostdate between @FromDate and @ToDate and
			b.statusID not in (101, 102, 103) AND
			ruben=1 
		    
		group by 
			recommend
	) b
	INNER JOIN CustInfo c with(nolock) on b.custid = c.custid
ORDER BY Username

GO
GRANT EXECUTE ON [dbo].[Age_Rpt_WinLoss_MAg_bettrans] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_Rpt_WinLoss_MAg_bettrans] TO [bodbDownlineNetView]
GO
GRANT VIEW DEFINITION ON [dbo].[Age_Rpt_WinLoss_MAg_bettrans] TO [vnteam]