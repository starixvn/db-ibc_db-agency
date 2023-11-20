/*<info serverAlias="DBLOG-bodb_CustomerLog"></info>*/
/*
	Created: 20231120@Bobby
	DB: DBSIC-bodb02,DBCTG-bodb02
	Task: AutoJob Enhancement - [Redmine : #195443]
*/
--DBLOG
USE bodb_CustomerLog;
GO

ALTER TABLE [Age_ClearBalanceCust_ProcessHistory]
ADD [Environment] VARCHAR(10)
GO

ALTER TABLE [dbo].[Age_ClearBalanceCust_ProcessHistory] ADD  CONSTRAINT [DF_Age_ClearBalanceCust_ProcessHistory_Environment]  DEFAULT ('PRO') FOR [Environment]
GO