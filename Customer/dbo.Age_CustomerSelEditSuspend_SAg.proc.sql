ALTER PROCEDURE [dbo].[Age_CustomerSelEditSuspend_SAg]
@CustID INT 	
AS
SET NOCOUNT ON
SELECT isnull(reject,0) UplineSuspended, isnull(DisableOutright, 0) UplineDisableOutright FROM CustInfo with (nolock)
WHERE custid = (SELECT srecommend FROM Custinfo with (nolock) WHERE custid = @CustID )

GO
GRANT EXECUTE ON [Age_CustomerSelEditSuspend_SAg] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [Age_CustomerSelEditSuspend_SAg] TO [bodbDownlineNetView]

