ALTER PROCEDURE [dbo].[Age_Rpt_CommByFinance_Ag]
	@CustID INT, 
	@FromDate SMALLDATETIME,
	@ToDate SMALLDATETIME
AS
/*
Created: 20090307@nqminh
Task : Select financial commission
DB: DB05.bodb02
Original:

Revisions:
    - 20090122@[Reviewer]: [Description of revision]    

Param's Explanation:
• @CustId: 
• @FromDate: 
• @ToDate: 
*/

SET NOCOUNT ON

CREATE TABLE #tmp(a_comm money, bettype int, custid int)

INSERT INTO #tmp
SELECT sum(isnull(comm,0) - isnull(playercomm,0)) as a_comm, bettype, custid
FROM dbo.bettrans b with(nolock) 
WHERE b.recommend = @CustID and ruben = 1 and
	winlostdate between @FromDate and @ToDate 
	and (bettype between 51 and 56 or bettype between 61 and 66)
GROUP BY b.custid, bettype
		
INSERT INTO #tmp
SELECT sum(isnull(comm,0) - isnull(playercomm,0)) as a_comm, bettype, custid
FROM dbo.bettrans14 b with(nolock) 
WHERE b.recommend = @CustID and ruben = 1 and
	winlostdate between @FromDate and @ToDate 
	and (bettype between 51 and 56 or bettype between 61 and 66)
GROUP BY custid, bettype

SELECT pvt.custid, c.username, 	
	isnull([51],0) as fa51_comm,
	isnull([52],0) as fa52_comm,
	isnull([53],0) as fa53_comm,
	isnull([54],0) as fa54_comm,
	isnull([55],0) as fa55_comm,
	isnull([56],0) as fa56_comm,
	isnull([51],0) + isnull([52],0) + isnull([53],0) + isnull([54],0) + isnull([55],0) + isnull([56],0) as totalcomm_OU,

	isnull([61],0) as fa61_comm,
	isnull([62],0) as fa62_comm,
	isnull([63],0) as fa63_comm,
	isnull([64],0) as fa64_comm,
	isnull([65],0) as fa65_comm,
	isnull([66],0) as fa66_comm,
	isnull([61],0) + isnull([62],0) + isnull([63],0) + isnull([64],0) + isnull([65],0) + isnull([66],0) as totalcomm_OE

FROM #tmp AS p
PIVOT
(
	SUM(a_comm)
	FOR bettype IN ([51],[52],[53],[54],[55],[56], [61],[62],[63],[64],[65],[66])  
) AS pvt
INNER JOIN customer c with(nolock) on c.custid = pvt.custid 
ORDER BY c.username

DROP TABLE #tmp

GO
GRANT EXECUTE ON [dbo].[Age_Rpt_CommByFinance_Ag] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_Rpt_CommByFinance_Ag] TO [bodbDownlineNetView]
GO
GRANT VIEW DEFINITION ON [dbo].[Age_Rpt_CommByFinance_Ag] TO [vnteam]
