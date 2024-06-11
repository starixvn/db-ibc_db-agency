/*<info serverAlias="DBAGE-bodb02,DBACC-bodb02,DBBOF-bodb02,DBCTG-bodb02" executers="wsv_nap,wsv_alp,wsv_alpv" isFunction="1" isNested="1"></info>*/
ALTER FUNCTION [dbo].[f_AddRelatedProducts]
(
	@ProductIds VARCHAR(MAX) = ''
)
RETURNS VARCHAR(MAX)
AS

/*
	Created by Percy
	Date: 2017-06-23
	DB: DBAGE.bodb02, DBACC.bodb02, DBBOF.bodb02
	Task: Add related products

	Revisions:
		- 20170623@Percy: Create new [RedmineID: #78339]
		- 20171101@Percy: Enhance Performance [RedmineID: #86200]
		- 20201005@Danny: Change to use alias DBBOF alternative to DB042 [RedmineID: #139516]	
		- 20240611@Bobby: Switch to DBTrans [RedmineID: #206369]
*/

BEGIN
	DECLARE @ProductIdList VARCHAR(MAX)

	SELECT @ProductIdList = @ProductIds + 
		ISNULL(
				(SELECT ',' + CONVERT(VARCHAR(10), ProductId)
				FROM dbo.f_GroupProduct()
				WHERE ProductId <> GroupProductId
					AND CHARINDEX(',' + CONVERT(VARCHAR(10), GroupProductId) + ',', ',' + @ProductIds + ',') > 0
				FOR XML PATH(''))
			, '')
	
	RETURN @ProductIdList
END
GO