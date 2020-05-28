/*<info serverAlias="DBAGE-bodb02" executers="bodbDownlineNet,bodbDownlineNetView,bodbExtAccNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Age_Rpt_GetProductList]
	@isShowSetting BIT = 0
AS

/*  
	Created: 20161129@Paul  
	Task : Get all products for report
	DB: DBAGE/bodb02  
  
	Revisions:
		- 20161129@Paul: Smartphone Friendly UI for Microsite Report - [Redmine: #61531]
		- 20170508@Paul: Return EndOfSupportDate - [Redmine: #70450]
		- 20170622@Percy: Combine Betradar Virtual Sports with Virtual Sports [RedmineID: #78339]
		- 20200428@Malcolm : re-order products [Redmine : #132760]
		- 20200528@Malcolm : add Sportsbook 2 for Setting [Redmine : #134917]
*/

BEGIN
	SET NOCOUNT ON

	SELECT @isShowSetting = ISNULL(@isShowSetting,0)

	SELECT
		CAST(ISNULL(gp.GroupProductId, p.ProductID) AS INT) AS ProductID
	   ,p.ProductName
	   ,p.EndOfSupportDate
	   ,ISNULL(p.OrderNo,0) AS OrderNo
	   ,CASE WHEN p.CasinoType = 1 THEN 53
	         WHEN p.CasinoType = 2 THEN 41
			 ELSE 0 END AS [Type]
	FROM dbo.Products p WITH (NOLOCK)
		LEFT JOIN dbo.f_GroupProduct() gp ON p.ProductID = gp.ProductId AND gp.ProductId <> gp.GroupProductId
	WHERE p.GroupType = 0 AND gp.ProductId IS NULL

	UNION ALL

	-- add Sportsbook 2 for setting
	SELECT p.ProductID,
		   P.ProductName,
		   P.EndOfSupportDate,
		   ISNULL(p.OrderNo,0) AS OrderNo,
		   0 AS [Type]
	FROM dbo.Products p WITH(NOLOCK)
	WHERE ProductID = 16 AND @isShowSetting = 1

	ORDER BY OrderNo

	SET NOCOUNT OFF
END
GO