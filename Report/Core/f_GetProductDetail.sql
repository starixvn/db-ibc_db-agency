/*<info serverAlias="DBAGE-bodb02,DBACC-bodb02" selecters="bodbDownlineNet,bodbDownlineNetView" isFunction="1" isNested="1"></info>*/
CREATE FUNCTION dbo.f_GetProductDetail()
RETURNS TABLE
AS
/*  
	Created: 20200819@Malcolm  
	Task : Get all product details for report
	DB: DBAGE/bodb02  
  
	Revisions:
		- 20200819@Malcolm: Initialize Sps - [Redmine: #139575]	
		- 20200908@Malcolm : Report Enhancement for Jackpot Product Filter [RedmineID : #139575]
		- 20210609@Malcolm: Add AE Sexy - [Redmine: #156239]	
		- 20220106@Evan: Add SG Jackpot - [Redmine: #166685]	
		
*/
RETURN
	SELECT 'ProductDetail' AS RefId, '1' AS ResourceId, 32 AS ProductId, 248 AS Sporttype, 0 AS Bettype, 1 AS [Order]	
	UNION ALL 
	SELECT 'ProductDetail' AS RefId, '2' AS ResourceId, 32 AS ProductId, 248 AS Sporttype, 4297 AS Bettype, 2 AS [Order]	
	UNION ALL 
	SELECT 'ProductDetail' AS RefId, '3' AS ResourceId, 32 AS ProductId, 248 AS Sporttype, 4298 AS Bettype, 3 AS [Order]	
	UNION ALL 
	SELECT 'ProductDetail' AS RefId, '4' AS ResourceId, 45 AS ProductId, 243 AS Sporttype, 0 AS Bettype, 4 AS [Order]	
	UNION ALL 
	SELECT 'ProductDetail' AS RefId, '5' AS ResourceId, 45 AS ProductId, 243 AS Sporttype, 3150 AS Bettype, 5 AS [Order]	
	UNION ALL 
	SELECT 'ProductDetail' AS RefId, '6' AS ResourceId, 36 AS ProductId, 247 AS Sporttype, 0 AS Bettype, 6 AS [Order]	
	UNION ALL 
	SELECT 'ProductDetail' AS RefId, '7' AS ResourceId, 36 AS ProductId, 247 AS Sporttype, 4599 AS Bettype, 7 AS [Order]	
	UNION ALL 
	SELECT 'ProductDetail' AS RefId, '8' AS ResourceId, 36 AS ProductId, 247 AS Sporttype, 4600 AS Bettype, 8 AS [Order]	
	