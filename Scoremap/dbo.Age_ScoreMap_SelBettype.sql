 ALTER PROCEDURE [dbo].[Age_ScoreMap_SelBettype]  
    
AS  
/*  
 Task: Get bet types for Score Map function  
 Date: 20110919@Johnson  
 DB: DB053.bodb02   
 Revisions:  
	- 20120626@Sophia: Add new bettype 121, 122, 123 for Home no bet, Away no bet, Draw/No Draw
    - 20140417@Dom: Add new bettype 126
	- 20140807@Dom: Include 11 new bettypes of Soccer [feature: #19632]
	- 20150410@Tom: Modify Forecast function to support new 60 bet types [Feature #32738]
*/  
BEGIN
	SET NOCOUNT ON
	
	SELECT 1 typeid
	,1 isLive
	,1 isDead
	,'7' [1stId]
	,'7' [InfoId]

	UNION ALL
	SELECT 2 typeid
		,1 isLive
		,1 isDead
		,'12,136,137,138,139,157' [1stId]
		,'12,136,137,138,139' [InfoId]

	UNION ALL
	SELECT 3 typeid
		,1 isLive
		,1 isDead
		,'8' [1stId]
		,'8' [InfoId]

	UNION ALL
	SELECT 5 typeid
		,1 isLive
		,1 isDead
		,'15,167' [1stId]
		,'15,167' [InfoId]

	UNION ALL
	SELECT 20 typeid
		,1 isLive
		,1 isDead
		,'21' [1stId]
		,'21' [InfoId]

	UNION ALL
	SELECT 24 typeid
		,1 isLive
		,1 isDead
		,'151' [1stId]
		,'151' [InfoId]

	UNION ALL
	SELECT 26 typeid
		,1 isLive
		,1 isDead
		,'145,146,170,188' [1stId]
		,'145,146,170,188' [InfoId]

	UNION ALL
	SELECT 25 typeid
		,1 isLive
		,1 isDead
		,'191' [1stId]
		,'191' [InfoId]

	UNION ALL
	SELECT bt.typeid
		,1 isLive
		,1 isDead
		,'0' AS [1stId]
		,'0' AS [InfoId]
	FROM dbo.bettype bt WITH (NOLOCK)
	WHERE bt.typeid IN (13, 27, 28)

	UNION ALL
	SELECT 4 typeid
		,0 isLive
		,1 isDead
		,'30' [1stId]
		,'30' [InfoId]

	UNION ALL
	SELECT 6 typeid
		,1 isLive
		,1 isDead
		,'126,131,132,159,161,162,163,179,181,182' [1stId]
		,'126,131,132,159,161,162,179,181,182' [InfoId] --Dom add 126

	UNION ALL
	SELECT 121 typeid
		,1 isLive
		,1 isDead
		,'0' [1stId]
		,'0' [InfoId]

	UNION ALL
	SELECT 122 typeid
		,1 isLive
		,1 isDead
		,'0' [1stId]
		,'0' [InfoId]

	UNION ALL
	SELECT 123 typeid
		,1 isLive
		,1 isDead
		,'0' [1stId]
		,'0' [InfoId]
 
END  
	
GO


GRANT EXECUTE ON [dbo].[Age_ScoreMap_SelBettype] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_ScoreMap_SelBettype] TO [bodbDownlineNetView]
GO
GRANT VIEW DEFINITION ON [dbo].[Age_ScoreMap_SelBettype] TO [vnteam]
