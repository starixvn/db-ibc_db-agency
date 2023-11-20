/*<info serverAlias="DBSIC-bodb02,DBCTG-bodb02"></info>*/
/*
	Created: 20231120@Bobby
	DB: DBSIC-bodb02,DBCTG-bodb02
	Task: AutoJob Enhancement - [Redmine : #195443]
*/
--DBSIC
USE [bodb02]
GO

--1.Age_ClearBalanceCust_Process
ALTER TABLE Age_ClearBalanceCust_Process
ADD [Environment] VARCHAR(10)

GO
ALTER TABLE [dbo].[Age_ClearBalanceCust_Process] ADD  CONSTRAINT [DF_Age_ClearBalanceCust_Process_Environment]  DEFAULT ('PRO') FOR [Environment]
GO

CREATE CLUSTERED INDEX [CIX_SuperBatch] ON [dbo].[Age_ClearBalanceCust_Process]
(
	[Environment] ASC,
	[SuperId] ASC,
	[BatchNo] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = ON, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [Others_table]

GO

---2.Age_ClearBalanceCust_RunningSuper
ALTER TABLE Age_ClearBalanceCust_RunningSuper
ADD [Environment] VARCHAR(10)
GO

ALTER TABLE [dbo].[Age_ClearBalanceCust_RunningSuper] ADD  CONSTRAINT [DF_Age_ClearBalanceCust_RunningSuper_Environment]  DEFAULT ('PRO') FOR [Environment]
GO


---3.Age_ClearBalanceCust_BatchLog
ALTER TABLE Age_ClearBalanceCust_BatchLog
ADD [Environment] VARCHAR(10)
GO

ALTER TABLE [dbo].[Age_ClearBalanceCust_BatchLog] ADD  CONSTRAINT [DF_Age_ClearBalanceCust_BatchLog_Environment]  DEFAULT ('PRO') FOR [Environment]
GO

