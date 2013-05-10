ALTER PROCEDURE [dbo].[Age_Rpt_WinLossDetail_SAg_bettrans] 
	@custid int,--srecommend
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
    Original SP:Age_Rpt_WinLossDetail_SAg
    Revisions:
        - 20100628@viet: Created initial SP
        - 20100724@Don: paging
		- 20110907@Tom: Change range of bet type : 0->30, 
				apply new bet type 1st correct score on Sport Books	  
		- 20120405@Hurri: Change bettype of P2P (72 -> 1000)        
*/   

SET NOCOUNT ON


IF ((@PageSize <= 0) AND (@PageIndex <= 0))
BEGIN

    SELECT Username, b.*
    FROM (
	        SELECT
		        MRecommend as CustID,			
			    SUM(case when b.liveawayscore = 0 and b.bettype in(33,43) then b.stake/2 else b.stake end) TurnOver,	
		        sum(scomm/(1-tpositiontaking)) as GrossComm,
		        sum(winlost-actual_stake) MemberWinlost, --MemberWinlost
		        sum(playercomm) PlayerComm, -- PlayerComm
		        isnull(sum(winlost-actual_stake), 0) + isnull(sum(playercomm), 0) MemberTotal, --MemberTotal
		        sum(awinlost) AgWinlost, -- AgWinlost
		        isnull(sum(comm-playercomm),0) AgComm, --AgComm
		        isnull(sum(awinlost+comm-playercomm), 0) AgTotal, --AgTotal			
		        sum(mwinlost) MAgWinlost, -- MAgWinlost
		        sum(acomm)-sum(comm) MAgComm, --MAgComm
		        isnull(sum(mwinlost), 0) + isnull(sum(acomm), 0)-sum(comm) MAgTotal, --MAgTotal
		        sum(swinlost) SAgWinlost, -- SAgWinlost
		        isnull(sum(scomm),0) -isnull(sum(acomm),0) SAgComm, --SAgComm
		        isnull(sum(swinlost), 0) + isnull(sum(scomm), 0)-sum(acomm) SAgTotal, --SAgTotal
		        -(isnull(sum(swinlost), 0) + isnull(sum(awinlost), 0) + isnull(sum(mwinlost), 0) + isnull(sum(scomm), 0) + isnull(sum(winlost-actual_stake), 0)) Company --Company				
	        FROM
		        dbo.bettrans b WITH (NOLOCK, index=IX_srecommend)
	        WHERE
			    (
				    bettype < case when @showSB=1 then 31 else 0 end
				    OR bettype between 31 and case when @ShowHR=1 then 49 else 0 end
				    OR bettype between 51 and case when @ShowFI=1 then 69 else 0 end
				    OR bettype = case when @showCasino=1 then 71 else 0 end
				    OR bettype = case when @showP2P=1 then 1000 else 0 end	--20120405@Hurri
			    ) AND
		        winlostdate between @FromDate and @todate and
		        srecommend = @custid and		    
		         b.statusID not in (0,1,101, 102, 103) 
    		    
	        GROUP BY MRecommend
	    ) b
    INNER JOIN CustInfo c with(nolock) on b.custid = c.custid
    ORDER BY Username


    RETURN
    
END

DECLARE @RowStart int, @RowEnd int  
SELECT @PageIndex = @PageIndex - 1, @RowStart = @PageSize * @PageIndex + 1, @RowEnd = @RowStart + @PageSize - 1


DECLARE @SAgWinLossDetails TABLE(CustID int, TurnOver money, GrossComm money, MemberWinLost money, 
	PlayerComm money, MemberTotal money, AgWinLost money, AgComm money, AgTotal money, 
	MAgWinLost money, MAgComm money, MAgTotal money, SAgWinLost money, SAgComm money, SAgTotal money, Company money)
	

INSERT INTO @SAgWinLossDetails
    SELECT
	    MRecommend as CustID,			
		SUM(case when b.liveawayscore = 0 and b.bettype in(33,43) then b.stake/2 else b.stake end) TurnOver,	
	    sum(scomm/(1-tpositiontaking)) as GrossComm,
	    sum(winlost-actual_stake) MemberWinlost, --MemberWinlost
	    sum(playercomm) PlayerComm, -- PlayerComm
	    isnull(sum(winlost-actual_stake), 0) + isnull(sum(playercomm), 0) MemberTotal, --MemberTotal
	    sum(awinlost) AgWinlost, -- AgWinlost
	    isnull(sum(comm-playercomm),0) AgComm, --AgComm
	    isnull(sum(awinlost+comm-playercomm), 0) AgTotal, --AgTotal			
	    sum(mwinlost) MAgWinlost, -- MAgWinlost
	    sum(acomm)-sum(comm) MAgComm, --MAgComm
	    isnull(sum(mwinlost), 0) + isnull(sum(acomm), 0)-sum(comm) MAgTotal, --MAgTotal
	    sum(swinlost) SAgWinlost, -- SAgWinlost
	    isnull(sum(scomm),0) -isnull(sum(acomm),0) SAgComm, --SAgComm
	    isnull(sum(swinlost), 0) + isnull(sum(scomm), 0)-sum(acomm) SAgTotal, --SAgTotal
	    -(isnull(sum(swinlost), 0) + isnull(sum(awinlost), 0) + isnull(sum(mwinlost), 0) + isnull(sum(scomm), 0) + isnull(sum(winlost-actual_stake), 0)) Company --Company
    FROM
	    dbo.bettrans b WITH (NOLOCK, index=IX_srecommend)
    WHERE
		(
			bettype < case when @showSB=1 then 31 else 0 end
			OR bettype between 31 and case when @ShowHR=1 then 49 else 0 end
			OR bettype between 51 and case when @ShowFI=1 then 69 else 0 end
			OR bettype = case when @showCasino=1 then 71 else 0 end
			OR bettype = case when @showP2P=1 then 1000 else 0 end	--20120405@Hurri
		) AND
	    winlostdate between @FromDate and @todate and
	    srecommend = @custid and		    
	     b.statusID not in (0,1,101, 102, 103) 
	    
    GROUP BY MRecommend


IF @TotalRows = 0  
BEGIN  
 SELECT @TotalRows = count(CustID)
 FROM @SAgWinLossDetails  
 
END

SELECT Username, b.*
FROM (
	    SELECT s.*, ROW_NUMBER() over(order by s.CustID) as RowNum
	    FROM @SAgWinLossDetails s
	) b
INNER JOIN CustInfo c with(nolock) on b.custid = c.custid
WHERE b.RowNum between @RowStart and @RowEnd
ORDER BY Username

		

GO
GRANT EXECUTE ON [dbo].[Age_Rpt_WinLossDetail_SAg_bettrans] TO [bodbAdminNet]
GO
GRANT EXECUTE ON [dbo].[Age_Rpt_WinLossDetail_SAg_bettrans] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_Rpt_WinLossDetail_SAg_bettrans] TO [bodbDownlineNetView]
GO
GRANT VIEW DEFINITION ON [dbo].[Age_Rpt_WinLossDetail_SAg_bettrans] TO [vnteam]