/*<info serverAlias="DBSIC-bodb02,DBCTG-bodb02"></info>*/
/*
	Created: 20230921@Bobby
	DB: DBSIC-bodb02,DBCTG-bodb02
	Task: AutoJob Enhancement - [Redmine : #193021]
*/
--DBSIC
USE [bodb02]
GO

/****** Object:  Column IsSyncNotice  Script Date: 9/6/2023 11:09:21 AM ******/
ALTER TABLE dbo.Age_ClearBalanceCust_Process ADD
	IsSyncNotice bit NULL
GO
ALTER TABLE dbo.Age_ClearBalanceCust_Process ADD CONSTRAINT
	DF_Age_ClearBalanceCust_Process_IsSyncNotice DEFAULT 0 FOR IsSyncNotice
GO

/****** Object:  Index [IX_FailedStatus]    Script Date: 9/6/2023 11:09:21 AM ******/
CREATE NONCLUSTERED INDEX [IX_FailedStatus] ON [dbo].[Age_ClearBalanceCust_Process]
(
	[Status] ASC,
	[IsSyncNotice] ASC
) 
INCLUDE ([FromCustId], [ToCustId])
WHERE [Status] = 'Failed'
WITH (ONLINE = ON) ON [Others_table]
GO