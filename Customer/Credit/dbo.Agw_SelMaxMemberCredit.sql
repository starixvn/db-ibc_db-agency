ALTER PROCEDURE [dbo].[Agw_SelMaxMemberCredit]
	@custid int, -- Agent custid
	@maxMemberCredit float output
AS
/*
Created: 20090114@QuiNV
Task: Ouput max credit which new member can have
DB: DB05.bodb02
Original:

Revisions:
	- 20090521@PhuongDao: Get maxcredit from CustAgent 

*/
SET NOCOUNT ON

DECLARE @memberCreditT float -- 
DECLARE @agentCredit float -- 
DECLARE @agentMaxMemberCredit float --Member Max credit of agent (upline set)

SELECT @agentCredit = isnull(sum(credit), 0)
FROM custinfo with (nolock)
WHERE custid=@custid and roleid=2

SELECT  @agentMaxMemberCredit = isnull(sum(maxcredit),0) 
FROM	CustAgent with (NOLOCK) 
WHERE	custid=@custid

SELECT @memberCreditT = isnull(sum(credit), 0)
FROM custinfo with (nolock) 
WHERE recommend=@custid and roleid=1

-- Agent credit left
SELECT @maxMemberCredit = @agentCredit - @memberCreditT

-- Max credit which new member can have


SELECT @maxMemberCredit = case when (@maxMemberCredit < @agentMaxMemberCredit or @agentMaxMemberCredit = 0) then @maxMemberCredit else @agentMaxMemberCredit end


GO
GRANT EXECUTE ON [dbo].[Agw_SelMaxMemberCredit] TO [bodbDownlineNet]
GO


GO
GRANT EXECUTE ON [dbo].[Agw_SelMaxMemberCredit] TO [bodbAdminNet]
GO



GRANT VIEW DEFINITION ON [dbo].[Agw_SelMaxMemberCredit] TO [vnteam]

GO
