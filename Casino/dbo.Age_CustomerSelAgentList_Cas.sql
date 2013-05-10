ALTER PROCEDURE [dbo].[Age_CustomerSelAgentList_Cas]
@MRecommend int
AS
/*
Original: sp Age_CustomerSelAgentList
Task : List UserNames are allowed to play Casino
DB: DB05.bodb02
Create: 20090310@Tuan
*/

SELECT username, CustID 
from custInfo with (nolock) 
where roleid = 2 and Mrecommend = @MRecommend
	and DisableCasino=0 and SyncCasino=1
order by username


GO
GRANT EXECUTE ON [dbo].[Age_CustomerSelAgentList_Cas] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_CustomerSelAgentList_Cas] TO [bodbDownlineNetView]