/*<info serverAlias="DBAGE-bodb02,DBCTG-bodb02" selecters="wsv_alp,wsv_alpv" viewers="" isFunction="1" isNested="1"></info>*/
ALTER FUNCTION [dbo].[f_SportBettypeMatrixByProduct]
(
	@ProductIds	VARCHAR(MAX) = '',
	@IsTest		BIT			 = 0
)

/*
	Created by Percy
	Date: 2017-10-20
	Task: Get SportType_Bettype
	DB: DBAGE.bodb02
		
	Revisions:
		- 20171020@Percy: Add new function [RedmineID: #84690]
		- 20240611@Bobby: Switch to DBTrans [RedmineID: #206369]

	Paramters Explanation:
 		. @ProductIds: list of products
		. @IsTest:
			1: Get all products and bettypes
			0: Get only products and bettypes which are not being tested
*/

RETURNS TABLE
RETURN
SELECT	DISTINCT
		ProductID,
		BetType,
		EventType,
		SubProduct,
		RefTable
FROM dbo.SportBettypeMatrix WITH (NOLOCK)
WHERE ',' + @ProductIds + ',' LIKE '%,' + CONVERT(VARCHAR(3), ProductID) + ',%'
	AND IsTest <= @IsTest
GO