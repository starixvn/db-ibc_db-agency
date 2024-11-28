/*<info serverAlias="DBAGE-bodb02" executers="wsv_alp,wsv_alpv" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Age_Rpt_GetProductListByRefTable]
	@RefTable VARCHAR(50) = '1,2'
AS

/*
	Created: 
	Task : 
	DB: DBAGE.bodb02
	Original:
	Revisions:
		- 20170314@Paul: Create new [RedmineID: #71739]
		- 20170622@Percy: Combine Betradar Virtual Sports with Virtual Sports [RedmineID: #78339]

*/

BEGIN
	SET NOCOUNT ON;

	DECLARE @SQLString VARCHAR(MAX);

	SET @SQLString = 'SELECT DISTINCT CONVERT(TINYINT, ISNULL(p.GroupProductId, s.ProductID)) AS ProductID, RefTable, pd.OrderNo
		FROM dbo.SportBettypeMatrix s WITH(NOLOCK) LEFT JOIN dbo.f_GroupProduct() p ON s.ProductID = p.ProductID AND p.ProductId <> p.GroupProductId
		INNER JOIN dbo.Products pd WITH (NOLOCK) ON pd.ProductID = ISNULL(p.GroupProductId, s.ProductID)
		WHERE s.RefTable IN (' + @RefTable + ') AND p.ProductId IS NULL 
		ORDER BY pd.OrderNo';

	EXEC (@SQLString);

	SET NOCOUNT OFF;
END
GO