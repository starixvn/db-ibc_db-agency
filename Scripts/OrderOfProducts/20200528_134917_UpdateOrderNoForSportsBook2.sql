/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet" viewers="" isFunction="0" isNested="0"></info>*/
USE bodb02
GO

/*
	Created: 20200528@Malcolm
	DB: DBPRO.bodb02
	Task: update OrderNo column [Redmine : #132760]
*/

UPDATE t 
	SET  t.OrderNo = 12
FROM Products t
WHERE ProductID = 16