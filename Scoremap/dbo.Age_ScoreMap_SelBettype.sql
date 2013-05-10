 ALTER PROCEDURE [dbo].[Age_ScoreMap_SelBettype]  
    
AS  
/*  
 Task: Get bet types for Score Map function  
 Date: 20110919@Johnson  
 DB: DB053.bodb02   
 Revisions:  
	- 20120626@Sophia: Add new bettype 121, 122, 123 for Home no bet, Away no bet, Draw/No Draw
   
*/  
		SELECT 1 typeid, 1 isLive, 1 isDead, 7 [1stId]    
	UNION ALL     
		SELECT 2 typeid, 1 isLive, 1 isDead, 12 [1stId]    
	UNION ALL     
		SELECT 3 typeid, 1 isLive, 1 isDead, 8 [1stId]    
	UNION ALL     
		SELECT 5 typeid, 1 isLive, 1 isDead, 15 [1stId]    
	UNION ALL     
		SELECT 20 typeid, 1 isLive, 1 isDead, 21 [1stId]    
	UNION ALL   
		SELECT typeid, 1 isLive, 1 isDead, 0 as [1stId]    
		FROM bettype WITH(NOLOCK)    
		WHERE typeid IN (13,24,25,27,28,26)    	   
	UNION ALL    
		SELECT 4 typeid , 0 isLive, 1 isDead, 30 [1stId]    
	UNION ALL     
		SELECT 6 typeid , 0 isLive, 1 isDead, 0 [1stId]   
	UNION ALL     
		SELECT 121 typeid , 1 isLive, 1 isDead, 0 [1stId] 
	UNION ALL     
		SELECT 122 typeid , 1 isLive, 1 isDead, 0 [1stId] 
	UNION ALL     
		SELECT 123 typeid , 1 isLive, 1 isDead, 0 [1stId] 
  
  
	
GO


GRANT EXECUTE ON [dbo].[Age_ScoreMap_SelBettype] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_ScoreMap_SelBettype] TO [bodbDownlineNetView]
GO
GRANT VIEW DEFINITION ON [dbo].[Age_ScoreMap_SelBettype] TO [vnteam]
