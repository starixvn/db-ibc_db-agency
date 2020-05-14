/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet" viewers="" isFunction="0" isNested="0"></info>*/
USE bodb02
GO

/*
	Created: 20200513@Malcolm
	DB: DBPRO.bodb02
	Task: Update CasinoType [Redmine : #132760]
*/
Update p
	SET p.CasinoType = 0
FROM dbo.Products p
WHERE ProductName = 'Saba.club'