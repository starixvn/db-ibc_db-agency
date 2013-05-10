 ALTER PROCEDURE [dbo].[Age_GetCSStatus]
	@custid int,
	@status bit=0 output
AS
/*

Created: 20090310@QuiNV
Task: Get casino status
DB: DB05.bodb02
Original:

*/
SET NOCOUNT ON

SELECT @status = disablecasino from custinfo with (nolock) where custid=@custid


GO
GRANT EXECUTE ON [dbo].[Age_GetCSStatus] TO [bodbDownlineNet]
GO

GO
GRANT EXECUTE ON [dbo].[Age_GetCSStatus] TO [bodbAdminNet]
GO

GRANT VIEW DEFINITION ON [dbo].[Age_GetCSStatus] TO [vnteam]

GO