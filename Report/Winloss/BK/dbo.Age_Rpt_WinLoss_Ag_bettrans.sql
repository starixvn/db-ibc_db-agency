ALTER PROCEDURE [dbo].[Age_Rpt_WinLoss_Ag_bettrans]
	@CustID 	INT,--recommend
	@FromDate 	SMALLDATETIME,
	@ToDate 	SMALLDATETIME,	
	@showSB  BIT = 1,
	@showCasino  BIT = 0 ,
	@showP2P  BIT = 0,
	@showHR  BIT = 0,
	@showFI  BIT = 0
AS
/*
    Created: 28 Jun 2010
    Task : 
    DB: DB052.bodb02
    Original SP:Age_Rpt_WinLoss_Ag
    Revisions:
        - 20100628@viet: Created initial SP
        - 20110907@Tom: Change range of bet type : 0->30, 
				apply new bet type 1st correct score on Sport Books	
		- 20120405@Hurri: Change bettype of P2P (72 -> 1000)

*/
SET NOCOUNT ON

SELECT 
    CustID,
	Username,
    SUM(case when b.liveawayscore = 0 and b.bettype in(33,43) then b.stake/2 else b.stake end) TurnOver,	
    SUM(comm/(1-apositiontaking)) as GrossComm,
    SUM(winlost-actual_stake) as MemberWinLost,
    SUM(awinlost) as AgWinLost,	
    SUM(playercomm) as PlayerComm,
    SUM(comm-playercomm) as AgComm,
    ISNULL(SUM(winlost-actual_stake), 0) + ISNULL(SUM(playercomm), 0) AS MemberTotal,
    ISNULL(SUM(awinlost), 0) + ISNULL(SUM(comm-playercomm), 0) AS AgTotal,
    -SUM(winlost-actual_stake+awinlost+comm) as Company
FROM Bettrans b WITH(NOLOCK)
WHERE 
	(
		bettype < case when @showSB=1 then 31 else 0 end
		OR bettype between 31 and case when @ShowHR=1 then 49 else 0 end
		OR bettype between 51 and case when @ShowFI=1 then 69 else 0 end
		OR bettype = case when @showCasino=1 then 71 else 0 end
		OR bettype = case when @showP2P=1 then 1000 else 0 end	--20120405@Hurri
	) AND
	recommend = @custid AND
    winlostdate BETWEEN @FromDate AND @ToDate AND
    ruben = 1 AND 
    b.statusID not in (101, 102, 103)	    
GROUP BY 
    CustID,username
ORDER BY Username


GO
GRANT EXECUTE ON [dbo].[Age_Rpt_WinLoss_Ag_bettrans] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_Rpt_WinLoss_Ag_bettrans] TO [bodbDownlineNetView]
GO
GRANT VIEW DEFINITION ON [dbo].[Age_Rpt_WinLoss_Ag_bettrans] TO [vnteam]