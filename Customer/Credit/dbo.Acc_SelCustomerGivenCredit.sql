ALTER PROCEDURE [dbo].[Acc_SelCustomerGivenCredit]
@CustID int

AS

/*

Created: 20081024@QuiNV
Task: Get given credit of a customer (belonging have been checked on web already). Returns: username, givencredit
DB: DB05.bodb02
Original:

*/

SET NOCOUNT ON
SELECT c.username as username, 
		c.roleid as roleid,
		credit as givencredit  
FROM Customer c with(nolock) INNER JOIN Custinfo ci with(nolock) ON c.CustID = ci.CustID
WHERE c.CustID = @CustID  


GO
GRANT EXECUTE ON [dbo].[Acc_SelCustomerGivenCredit] TO [bodbDownlineNet]
GO

GO
GRANT EXECUTE ON [dbo].[Acc_SelCustomerGivenCredit] TO [bodbAdminNet]
GO

GRANT VIEW DEFINITION ON [dbo].[Acc_SelCustomerGivenCredit] TO [vnteam]

GO
