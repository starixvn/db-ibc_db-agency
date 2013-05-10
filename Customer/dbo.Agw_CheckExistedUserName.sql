ALTER PROCEDURE [dbo].[Agw_CheckExistedUserName]
	@custid int,
	@username nvarchar(30)=null,
	@subfix nvarchar(3) output,
	@isExisted bit output
AS
/*

	Created: 20090114@QuiNV
	Task: Check a member username is existed or not, if it is existed, output max subfix username
	DB: DBAGE/bodb02
	Original:

	Revisions:
		- 20120803@Johnson: get subfix from Age_CustomerSelSuggestUsername
		- 20130121@Dan: call to DBAGE/bodb_AGE for Age_CustomerSelSuggestUsername sp because moving this SP to bodb_AGE 
*/
SET NOCOUNT ON

DECLARE @agentUserName nvarchar(30)

if exists (SELECT 1 FROM customer with(nolock) WHERE recommend=@custid and roleid=1 and username=@username)
BEGIN
SELECT @isExisted=1
END
else
SELECT @isExisted=0

SELECT @agentUserName = username
FROM customer with (nolock)
WHERE custid=@custid and roleid=2

EXEC bodb_AGE.dbo.Age_CustomerSelSuggestUsername @prefix = @agentUserName, @custid = @custid, @roleid = 2,@seqname = @subfix output


GO
GRANT EXECUTE ON [dbo].[Agw_CheckExistedUserName] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Agw_CheckExistedUserName] TO [bodbDownlineNetView]
GO
GRANT VIEW DEFINITION ON [dbo].[Agw_CheckExistedUserName] TO [vnteam]
GO