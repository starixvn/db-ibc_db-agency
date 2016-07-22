USE [bodb02]
GO

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
		- 20150410@Tom: Modify Forecast function to support new 60 bet types [Feature #32738
		- 20150828@Winnie: Myanmar odds
		- 20151126@Percy: Add Correct Score into the Live Ball Section [RedmineID: #48050]
		- 20160509@Percy: Add 2 bettype Correct Score (AOS) [RedmineID: #48785]
		- 20160722@Percy: Support parent-child bettype [RedmineID: #53152]
	Parameter's Explanations:
		EvenType : 0 DeadBall 1 LiveBall
*/  
BEGIN
	SET NOCOUNT ON
	
	DECLARE @tblCoreMap TABLE(typeid SMALLINT
		,EvenType SMALLINT
		,[1stId] VARCHAR(100)
		,[InfoId] VARCHAR(100)
		,OrderID INT)
	
	INSERT INTO @tblCoreMap (typeid,EvenType,[1stId],[InfoId],OrderID)
	
	SELECT 1 typeid
	,0 EvenType
	,'1,7,301,303' [1stId]
	,'1,7,301,303' [InfoId]
	,1 OrderID
	UNION ALL
	SELECT 1 typeid
	,1 EvenType
	,'1,7' [1stId]
	,'1,7' [InfoId]
	,1 OrderID
	
	UNION ALL
	SELECT 2 typeid
		,0 EvenType
		,'2,12,136,137,138,139' [1stId]
		,'2,12,136,137,138,139' [InfoId]
		,20 OrderID
	UNION ALL
	SELECT 2 typeid
		,1 EvenType
		,'2,12,136,137,138,139,157' [1stId]
		,'2,12,136,137,138,139' [InfoId]
		,20 OrderID
	UNION ALL
	SELECT 3 typeid
		,0 EvenType
		,'3,8,302,304' [1stId]
		,'3,8,302,304' [InfoId]
		,30 OrderID
	UNION ALL
	SELECT 3 typeid
		,1 EvenType
		,'3,8' [1stId]
		,'3,8' [InfoId]
		,30 OrderID
		
	UNION ALL
	SELECT 5 typeid
		,0 EvenType
		,'5,15' [1stId]
		,'5,15' [InfoId]
		,50 OrderID
	UNION ALL
	SELECT 5 typeid
		,1 EvenType
		,'5,15,167' [1stId]
		,'5,15,167' [InfoId]
		,50 OrderID
		
	UNION ALL
	SELECT 20 typeid
		,0 EvenType
		,'20,21' [1stId]
		,'20,21' [InfoId]
		,200 OrderID
		
	UNION ALL
	SELECT 20 typeid
		,1 EvenType
		,'20,21' [1stId]
		,'20,21' [InfoId]
		,200 OrderID
		
	UNION ALL
	SELECT 24 typeid
		,0 EvenType
		,'24,151,410' [1stId]
		,'24,151,410' [InfoId]
		,240 OrderID
		
	UNION ALL
	SELECT 24 typeid
		,1 EvenType
		,'24,410' [1stId]
		,'24,410' [InfoId]
		,240 OrderID
		
	UNION ALL
	SELECT 26 typeid
		,0 EvenType
		,'26,170,188,427' [1stId]
		,'26,170,188,427' [InfoId]
		,260 OrderID
		
	UNION ALL
	SELECT 26 typeid
		,1 EvenType
		,'26' [1stId]
		,'26' [InfoId]
		,260 OrderID
		
	UNION ALL
	SELECT 25 typeid
		,0 EvenType
		,'25,191,411' [1stId]
		,'25,191,411' [InfoId]
		,2500 OrderID
		
	UNION ALL
	SELECT 25 typeid
		,1 EvenType
		,'25,411' [1stId]
		,'25,411' [InfoId]
		,2500 OrderID
		
	UNION ALL
	
	SELECT bt.typeid
		,0 EvenType
		,CONVERT(VARCHAR(10),bt.typeid ) AS [1stId]
		,CONVERT(VARCHAR(10),bt.typeid ) AS [InfoId]
		,2500+bt.typeid OrderID
	FROM dbo.bettype bt WITH (NOLOCK)
	WHERE bt.typeid IN (13, 27, 28)
	
	UNION ALL
	SELECT bt.typeid
		,1 EvenType
		,CONVERT(VARCHAR(10),bt.typeid ) AS [1stId]
		,CONVERT(VARCHAR(10),bt.typeid ) AS [InfoId]
		,2500+bt.typeid OrderID
	FROM dbo.bettype bt WITH (NOLOCK)
	WHERE bt.typeid IN (13, 27, 28)

	UNION ALL
	SELECT 4 typeid
		,0 EvenType
		,'4,30,413,414' [1stId]
		,'4,30,413,414' [InfoId]
		,4000 OrderID
	UNION ALL
	
	SELECT 4 typeid
		,1 EvenType
		,'4,30,413,414' [1stId]
		,'4,30,413,414' [InfoId]
		,4000 OrderID
	UNION ALL
	
	SELECT 6 typeid
		,0 EvenType
		,'6,126,131,132,159,406,161,407,162,409' [1stId]
		,'6,126,131,132,159,406,161,407,162,409' [InfoId] --Dom add 126
		,6000 OrderID
		
	UNION ALL
	SELECT 6 typeid
		,1 EvenType
		,'6,126,131,132,159,406,161,407,162,409,179,181,182' [1stId]
		,'6,126,131,132,159,406,161,407,162,409,179,181,182' [InfoId] --Dom add 126
		,6000 OrderID
		
	UNION ALL
	
	SELECT 121 typeid
		,0 EvenType
		,'121' [1stId]
		,'121' [InfoId]
		,12100 OrderID
	UNION ALL
	SELECT 121 typeid
		,1 EvenType
		,'121' [1stId]
		,'121' [InfoId]
		,12100 OrderID
	UNION ALL
	
	SELECT 122 typeid
		,0 EvenType
		,'122' [1stId]
		,'122' [InfoId]
		,12200 OrderID
		
	UNION ALL
	SELECT 122 typeid
		,1 EvenType
		,'122' [1stId]
		,'122' [InfoId]		
		,12200 OrderID
		
	UNION ALL
	SELECT 123 typeid
		,0 EvenType
		,'123' [1stId]
		,'123' [InfoId]		
		,12300 OrderID
	UNION ALL
	SELECT 123 typeid
		,1 EvenType
		,'123' [1stId]
		,'123' [InfoId]	
		,12300 OrderID
		
	
	SELECT typeid,EvenType,[1stId],[InfoId] 
	FROM @tblCoreMap tbl
	ORDER BY OrderID,EvenType
END  
	
GO

GRANT EXECUTE ON [dbo].[Age_ScoreMap_SelBettype] TO [bodbDownlineNet] AS [dbo]
GO

GRANT EXECUTE ON [dbo].[Age_ScoreMap_SelBettype] TO [bodbDownlineNetView] AS [dbo]
GO

GRANT VIEW DEFINITION ON [dbo].[Age_ScoreMap_SelBettype] TO [vnteam] AS [dbo]
GO