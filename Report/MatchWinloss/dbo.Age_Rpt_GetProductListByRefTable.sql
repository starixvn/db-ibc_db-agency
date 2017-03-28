USE [bodb02]
GO

CREATE PROCEDURE [dbo].[Age_Rpt_GetProductListByRefTable]
	@RefTable VARCHAR(50) = '1,2'
AS

/*
	Created: 
	Task : 
	DB: DBAGE.bodb02
	Original:
	Revisions:
		- 20170314@Paul: Create new [RedmineID: #71739]

*/

BEGIN
	SET NOCOUNT ON;

	DECLARE @SQLString VARCHAR(MAX);

	SET @SQLString = ' 
		SELECT DISTINCT ProductID, RefTable
		FROM SportBettypeMatrix WITH(NOLOCK)
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
