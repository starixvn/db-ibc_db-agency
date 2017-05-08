USE [bodb02]
GO

/****** Object:  StoredProcedure [dbo].[Age_Rpt_GetProductList]    Script Date: 12/12/2016 9:32:15 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
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
    
 Param's Explanation:  
   
 */  
BEGIN
	SET NOCOUNT ON;

	SELECT	CAST(ProductID AS INT) AS ProductID,
			ProductName,
			EndOfSupportDate
	FROM dbo.Products WITH(NOLOCK)
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


