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
		
*/
RETURN
	SELECT 'ProductDetail' AS RefId, '1' AS ResourceId, 32 AS ProductId, 248 AS Sporttype, 0 AS Bettype, 1 AS [Order]	
	UNION ALL 
	SELECT 'ProductDetail' AS RefId, '2' AS ResourceId, 32 AS ProductId, 248 AS Sporttype, 4297 AS Bettype, 2 AS [Order]	
	UNION ALL 
	SELECT 'ProductDetail' AS RefId, '3' AS ResourceId, 32 AS ProductId, 248 AS Sporttype, 4298 AS Bettype, 3 AS [Order]	

