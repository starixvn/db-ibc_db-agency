ALTER PROCEDURE [dbo].[Age_Rpt_WinLossDetail_Ag_bettrans] 
	@CustID int = NULL,--recommend
	@FromDate smalldatetime,
	@ToDate smalldatetime,
	@showSB bit=1,
	@showCasino bit=0,
	@showP2P bit=0,
	@showHR bit=0,
	@showFI bit=0,
	@PageSize int=0,
	@PageIndex int=0,
	@TotalRows int=0 output

AS
/*
    Created: 28 Jun 2010
    Task : 
    DB: DB052.bodb02
    Original SP: Age_Rpt_WinLossDetail_Ag
    Revisions:
        - 20100628@viet: Created initial SP
        - 20100726@Don: paging
		- 20110907@Tom: Change range of bet type : 0->30, 
				apply new bet type 1st correct score on Sport Books	       
		- 20120405@Hurri: Change bettype of P2P (72 -> 1000)                

*/  
SET NOCOUNT ON

IF ((@PageSize <= 0) AND (@PageIndex <= 0))
BEGIN

    SELECT
        CustID,
	    Username,
        SUM(case when b.liveawayscore = 0 and b.bettype in(33,43) then b.stake/2 else b.stake end) TurnOver,	
        sum(comm/(1- apositiontaking)) as GrossComm,
        sum(winlost-actual_stake) MemberWinLost, --MemberWinlost
        sum(playercomm) PlayerComm, -- PlayerComm
        isnull(sum(winlost-actual_stake), 0) + isnull(sum(playercomm), 0) MemberTotal, --MemberTotal
        sum(awinlost) AgWinLost, -- AgWinlost
        sum(comm-playercomm) AgComm, --AgComm
        isnull(sum(awinlost), 0) + isnull(sum(comm-playercomm), 0) AgTotal, --AgTotal
        -isnull(sum(winlost-actual_stake +awinlost+comm), 0) Company --Company
    FROM
        dbo.bettrans b WITH (NOLOCK)
    WHERE
	    (
		    bettype < case when @showSB=1 then 31 else 0 end
		    OR bettype between 31 and case when @ShowHR=1 then 49 else 0 end
		    OR bettype between 51 and case when @ShowFI=1 then 69 else 0 end
		    OR bettype = case when @showCasino=1 then 71 else 0 end
		    OR bettype = case when @showP2P=1 then 1000 else 0 end	--20120405@Hurri
	    ) AND
        winlostdate between @FromDate and @todate
        and b.statusID not in (101, 102, 103)
        and Recommend=@CustID
        and ruben=1 
    GROUP BY CustID,Username
    ORDER BY username 


    RETURN
END

DECLARE @RowStart int, @RowEnd int  
SELECT @PageIndex = @PageIndex - 1, @RowStart = @PageSize * @PageIndex + 1, @RowEnd = @RowStart + @PageSize - 1

DECLARE @AgWinLossDetails TABLE(CustID int, TurnOver money, GrossComm money, MemberWinLost money, 
	PlayerComm money, MemberTotal money, AgWinLost money, AgComm money, AgTotal money, Company money)


INSERT INTO @AgWinLossDetails
    SELECT
        CustID,
        SUM(case when b.liveawayscore = 0 and b.bettype in(33,43) then b.stake/2 else b.stake end) TurnOver,	
        sum(comm/(1- apositiontaking)) as GrossComm,
        sum(winlost-actual_stake) MemberWinLost, --MemberWinlost
        sum(playercomm) PlayerComm, -- PlayerComm
        isnull(sum(winlost-actual_stake), 0) + isnull(sum(playercomm), 0) MemberTotal, --MemberTotal
        sum(awinlost) AgWinLost, -- AgWinlost
        sum(comm-playercomm) AgComm, --AgComm
        isnull(sum(awinlost), 0) + isnull(sum(comm-playercomm), 0) AgTotal, --AgTotal
        -isnull(sum(winlost-actual_stake +awinlost+comm), 0) Company --Company
    FROM
        dbo.bettrans b WITH (NOLOCK)
    WHERE
	    (
		    bettype < case when @showSB=1 then 31 else 0 end
		    OR bettype between 31 and case when @ShowHR=1 then 49 else 0 end
		    OR bettype between 51 and case when @ShowFI=1 then 69 else 0 end
		    OR bettype = case when @showCasino=1 then 71 else 0 end
		    OR bettype = case when @showP2P=1 then 1000 else 0 end	--20120405@Hurri
	    ) AND
        winlostdate between @FromDate and @todate
        and b.statusID not in (101, 102, 103)
        and Recommend=@CustID
        and ruben=1 
    GROUP BY CustID,Username    
    
IF @TotalRows = 0  
BEGIN  
 SELECT @TotalRows = count(CustID)
 FROM @AgWinLossDetails  
 
END

SELECT Username, wl.*
FROM (
	    SELECT a.*, ROW_NUMBER() over(order by a.CustID) as RowNum
	    FROM @AgWinLossDetails a
	) wl
	INNER JOIN CustInfo c with(nolock) on wl.custid = c.custid
WHERE wl.RowNum between @RowStart and @RowEnd
ORDER BY Username
  


GO
GRANT EXECUTE ON [dbo].[Age_Rpt_WinLossDetail_Ag_bettrans] TO [bodbAdminNet]
GO
GRANT EXECUTE ON [dbo].[Age_Rpt_WinLossDetail_Ag_bettrans] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_Rpt_WinLossDetail_Ag_bettrans] TO [bodbDownlineNetView]
GO
GRANT EXECUTE ON [dbo].[Age_Rpt_WinLossDetail_Ag_bettrans] TO [vnteam]
GO
GRANT VIEW DEFINITION ON [dbo].[Age_Rpt_WinLossDetail_Ag_bettrans] TO [vnteam]