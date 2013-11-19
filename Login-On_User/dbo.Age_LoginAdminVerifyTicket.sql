ALTER PROCEDURE [dbo].[Age_LoginAdminVerifyTicket]
	@LoginTime  DATETIME = null OUTPUT
AS
SET NOCOUNT ON
/*
Created: 20091006@Phuc
Task : use for admin login agent site
DB: DBTXN/CustDB

Revisions:
    
Param's Explanation:
*/

SELECT @LoginTime = CURRENT_TIMESTAMP




GO
GRANT EXECUTE ON [dbo].[Age_LoginAdminVerifyTicket] TO [bodbadminNet] AS [dbo]
GO
GRANT EXECUTE ON [dbo].[Age_LoginAdminVerifyTicket] TO [bodbExtAccNet] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[Age_LoginAdminVerifyTicket] TO [vnteam] AS [dbo]