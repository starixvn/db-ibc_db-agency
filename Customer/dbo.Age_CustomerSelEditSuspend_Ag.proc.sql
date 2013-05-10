ALTER PROCEDURE [dbo].[Age_CustomerSelEditSuspend_Ag]
@CustID INT 	--MemberID
AS

SET NOCOUNT ON 
SELECT isnull(reject,0) UplineSuspended, isnull(DisableOutright, 0) UplineDisableOutright FROM CustInfo with (nolock)
WHERE custid = (SELECT recommend FROM Custinfo with (nolock) WHERE custid = @CustID )


GO
GRANT EXECUTE ON [Age_CustomerSelEditSuspend_Ag] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [Age_CustomerSelEditSuspend_Ag] TO [bodbDownlineNetView]
