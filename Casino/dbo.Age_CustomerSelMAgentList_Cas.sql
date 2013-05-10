ALTER PROCEDURE [dbo].[Age_CustomerSelMAgentList_Cas]
@SRecommend int
AS
/*
Original: sp CustomerSelMAgentList
Task : List UserNames are allowed to play Casino
DB: DB05.bodb02
Create: 20090310@Tuan
*/

SET NOCOUNT ON
SELECT username, CustID 
from custInfo with (nolock) 
where roleid = 3 and SRecommend = @SRecommend
	and DisableCasino=0 and SyncCasino=1
order by username


GO
GRANT EXECUTE ON [dbo].[Age_CustomerSelMAgentList_Cas] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_CustomerSelMAgentList_Cas] TO [bodbDownlineNetView]