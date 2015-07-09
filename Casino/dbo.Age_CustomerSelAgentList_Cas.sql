ALTER PROCEDURE  [dbo].[Age_CustomerSelAgentList_Cas]
	@MRecommend INT
AS
/*
	Created: 20100915@Kaden
	Task: List UserNames are allowed to play Bingo  
	DB: DBCUST.CustDB
	Original:
	Revisions:
		- 20100930@Johnson: add permission to execute sp
		- 20150610@Kos: Separate CustDB to DBCUST server (Move SP to DBCUST.CustDB)
*/
--Original: sp Age_CustomerSelAgentList

SET NOCOUNT ON

SELECT username, CustID 
FROM custInfo WITH (NOLOCK) 
WHERE roleid = 2 
	AND Mrecommend = @MRecommend
	AND DisableCasino = 0 
	AND SyncCasino = 1
ORDER BY username



GO
GRANT EXECUTE ON [dbo].[Age_CustomerSelAgentList_Cas] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_CustomerSelAgentList_Cas] TO [bodbDownlineNetView]