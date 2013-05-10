ALTER PROCEDURE [dbo].[Age_CustomerSelAgentList]
@MRecommend int
AS
--Original: sp CustomerSelAgentList
SELECT username, CustID 
from customer with (nolock) 
where roleid = 2 and Mrecommend = @MRecommend
order by username




GO
GRANT EXECUTE ON [dbo].[Age_CustomerSelAgentList] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_CustomerSelAgentList] TO [bodbDownlineNetView]
