/*<info serverAlias="DBBAH-bodb02"></info>*/
/*
	Created: 20220323@Sol
	DB: DBBAH-bodb02
	Task: grant access to db BalanceRecord - [Redmine : #167296]
*/

USE BalanceRecord;

GO

CREATE USER [bodbDownlineNetView] FOR LOGIN [bodbDownlineNetView]

GO

GRANT SELECT ON BalanceRecord_bk TO bodbDownlineNetView

GO