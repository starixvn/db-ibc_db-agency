USE [bodb02]
GO

ALTER PROCEDURE [dbo].[Age_Rpt_GetProductList]
AS
/*  
 Created: 20161129@Paul  
 Task : Get all products for report
 DB: DBAGE/bodb02  
 Original:  
  
 Revisions:  
  - 20161129@Paul: Smartphone Friendly UI for Microsite Report - [Redmine: #61531]
  - 20170508@Paul: Return EndOfSupportDate - [Redmine: #70450]
  - 20170622@Percy: Combine Betradar Virtual Sports with Virtual Sports [RedmineID: #78339]
    
 Param's Explanation:  
   
 */  
BEGIN
	SET NOCOUNT ON;

	SELECT	CAST(ISNULL(gp.GroupProductId, p.ProductID) AS INT) AS ProductID,
			ProductName,
			EndOfSupportDate
	FROM dbo.Products p WITH(NOLOCK)
		LEFT JOIN dbo.f_GroupProduct() gp ON p.ProductID = gp.ProductId
	WHERE GroupType = 0;

	SET NOCOUNT OFF;
END
GO
GRANT EXECUTE ON [dbo].[Age_Rpt_GetProductList] TO [bodbDownlineNet] AS [dbo]
GO
GRANT EXECUTE ON [dbo].[Age_Rpt_GetProductList] TO [bodbDownlineNetView] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[Age_Rpt_GetProductList] TO [vnteam] AS [dbo]
GO


