
ALTER PROCEDURE [dbo].[Age_CustomerSelMAgentList_Cas]
	@SRecommend INT
AS

/*
	Created: 
	Date:  
	Task : 
	DB: DBCUST.CustDB
	Revisions: 
		- 20150610@Kos: Separate CustDB to DBCUST server (Move SP to DBCUST.CustDB)

	Param's Explanation:
	• @SRecommend: Super Agent ID
*/

--Original: CustomerSelMAgentList
SET NOCOUNT ON

SELECT username, CustID 
FROM custInfo WITH (NOLOCK) 
WHERE 
	roleid = 3 
	AND SRecommend = @SRecommend
	AND DisableCasino = 0 
	AND SyncCasino = 1
ORDER BY username



GO
GRANT EXECUTE ON [dbo].[Age_CustomerSelMAgentList_Cas] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_CustomerSelMAgentList_Cas] TO [bodbDownlineNetView]