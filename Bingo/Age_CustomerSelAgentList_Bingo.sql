CREATE PROCEDURE [dbo].[Age_CustomerSelAgentList_Bingo]
@MRecommend int
AS
/*

Created: 20100915@Kaden
Task: List UserNames are allowed to play Bingo
DB: DB052.bodb02
Original:
   Revisions:
*/
SET NOCOUNT ON

SELECT username, CustID 
FROM custInfo WITH (NOLOCK) 
WHERE roleid = 2 AND Mrecommend = @MRecommend
	AND DisableBingo=0 AND SyncBingo=1
ORDER BY username

GO 
GRANT EXECUTE ON [dbo].[Age_CustomerSelAgentList_Bingo] TO [bodbDownlineNet] 
GO
GRANT EXECUTE ON [dbo].[Age_CustomerSelAgentList_Bingo] TO [bodbDownlineNetView] 
Go
GRANT VIEW DEFINITION ON [dbo].[Age_CustomerSelAgentList_Bingo] TO vnteam  