ALTER PROCEDURE [dbo].[Age_CustomerSelMAgentList_Bingo]
	@SRecommend INT
AS
/*
	Created: 20100915@Kaden
	Task: List UserNames are allowed to play Bingo
	DB: DBCUST.CustDB
	Original:
	Revisions:
		- 20150610@Kos: Separate CustDB to DBCUST server (Move SP to DBCUST.CustDB)
*/

SET NOCOUNT ON

SELECT username, CustID 
FROM custInfo WITH (NOLOCK) 
WHERE 
	roleid = 3 
	AND SRecommend = @SRecommend
	AND DisableBingo = 0 
	AND SyncBingo = 1
ORDER BY username


GO 
GRANT EXECUTE ON [dbo].[Age_CustomerSelMAgentList_Bingo] TO [bodbDownlineNet] 
GO
GRANT EXECUTE ON [dbo].[Age_CustomerSelMAgentList_Bingo] TO [bodbDownlineNetView] 
Go
GRANT VIEW DEFINITION ON [dbo].[Age_CustomerSelMAgentList_Bingo] TO vnteam  