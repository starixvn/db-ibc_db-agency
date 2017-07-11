USE [bodb02]
GO

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

	SET @SQLString = ' 
		SELECT DISTINCT CONVERT(TINYINT, ISNULL(p.GroupProductId, s.ProductID)) AS ProductID, RefTable
		FROM dbo.SportBettypeMatrix s WITH(NOLOCK)
			LEFT JOIN dbo.f_GroupProduct() p ON s.ProductID = p.ProductID
		WHERE RefTable IN (' + @RefTable + ')';

	EXEC (@SQLString);

	SET NOCOUNT OFF;
END
GO
GRANT EXECUTE ON [dbo].[Age_Rpt_GetProductListByRefTable] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_Rpt_GetProductListByRefTable] TO [bodbDownlineNetView]
GO
GRANT VIEW DEFINITION ON [dbo].[Age_Rpt_GetProductListByRefTable] TO vnteam
