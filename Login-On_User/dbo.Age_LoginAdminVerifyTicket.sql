ALTER PROCEDURE Age_LoginAdminVerifyTicket
	@LoginTime  DATETIME = null OUTPUT
AS
SET NOCOUNT ON
/*
Created: 20091006@Phuc
Task : use for admin login agent site
DB: DB02.bodb02

Revisions:
    
Param's Explanation:
*/

SELECT @LoginTime = CURRENT_TIMESTAMP

GO
GRANT EXECUTE ON [dbo].Age_LoginAdminVerifyTicket TO [bodbAdminNet]
GO
GRANT EXECUTE ON [dbo].Age_LoginAdminVerifyTicket TO [bodbExtAccNet]
GO
GRANT VIEW DEFINITION ON [dbo].Age_LoginAdminVerifyTicket TO [vnteam]
