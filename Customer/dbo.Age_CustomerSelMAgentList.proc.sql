ALTER PROCEDURE [dbo].[Age_CustomerSelMAgentList]
@SRecommend int
AS
--Original: CustomerSelMAgentList
SET NOCOUNT ON
SELECT username, CustID 
from customer with (nolock) 
where roleid = 3 and SRecommend = @SRecommend
order by username



GO
GRANT EXECUTE ON [dbo].[Age_CustomerSelMAgentList] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_CustomerSelMAgentList] TO [bodbDownlineNetView]
