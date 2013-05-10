 ALTER PROCEDURE [dbo].[Age_Rpt_WinLoss_SAg_bettrans]
	@CustID INT,--srecommend
	@FromDate SMALLDATETIME,
	@ToDate SMALLDATETIME,	
	@showSB BIT=1,
	@showCasino BIT=0,
	@showP2P BIT=0,
	@showHR BIT=0,
	@showFI BIT=0
AS

/*
    Created: 28 Jun 2010
    Task : 
    DB: DB052.bodb02
    Original Age_Rpt_WinLoss_SAg
    Revisions:
        - 20100628@viet: Created initial SP
		- 20110907@Tom: Change range of bet type : 0->30, 
				apply new bet type 1st correct score on Sport Books	     
		- 20120405@Hurri: Change bettype of P2P (72 -> 1000)          

*/   

SET NOCOUNT ON

SELECT Username, b.*
FROM (
	    SELECT
		    mrecommend as CustID,	
		    SUM(case when b.liveawayscore = 0 and b.bettype in(33,43) then b.stake/2 else b.stake end) TurnOver,	
		    SUM(scomm/(1 - tpositiontaking)) as GrossComm,
		    SUM(mwinlost+awinlost+acomm+winlost-actual_stake) MAgTotal,
		    SUM(swinlost) SAgWinlost,
		    ISNULL(SUM(scomm), 0)-ISNULL(SUM(acomm), 0) Comm,
		    ISNULL(SUM(swinlost), 0) + ISNULL(SUM(scomm), 0)-SUM(acomm) SAgTotal,
		    -(ISNULL(SUM(swinlost), 0) + ISNULL(SUM(awinlost), 0) + ISNULL(SUM(mwinlost), 0) + ISNULL(SUM(scomm), 0) + ISNULL(SUM(winlost-actual_stake), 0)) Company
	    FROM 
		    dbo.bettrans b WITH (NOLOCK,index=IX_srecommend)
	    WHERE
			(
				bettype < case when @showSB=1 then 31 else 0 end
				OR bettype between 31 and case when @ShowHR=1 then 49 else 0 end
				OR bettype between 51 and case when @ShowFI=1 then 69 else 0 end
				OR bettype = case when @showCasino=1 then 71 else 0 end
				OR bettype = case when @showP2P=1 then 1000 else 0 end	--20120405@Hurri
			) AND
			SRecommend=@CustID AND
		    winlostdate BETWEEN @FromDate AND @ToDate AND
		    b.statusID not in (0,1,101, 102, 103) 	       
	    GROUP BY 
		    mrecommend
	) b
	INNER JOIN Custinfo c with(nolock) on c.custid=b.custid
ORDER BY Username
	


GO
GRANT EXECUTE ON [dbo].[Age_Rpt_WinLoss_SAg_bettrans] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_Rpt_WinLoss_SAg_bettrans] TO [bodbDownlineNetView]
GO
GRANT VIEW DEFINITION ON [dbo].[Age_Rpt_WinLoss_SAg_bettrans] TO [vnteam]