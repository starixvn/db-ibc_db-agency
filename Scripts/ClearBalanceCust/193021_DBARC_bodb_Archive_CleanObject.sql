/*<info serverAlias="DBARC-bodb_Archive"></info>*/
/*
	Created: 20231003@Bobby
	DB: DBARC-bodb_Archive
	Task: AutoJob Enhancement - [Redmine : #193021]
*/
--DBLOG

--TODO: CLEAN DBARC
USE bodb_Archive;
DROP TABLE IF EXISTS dbo.Age_ClearBalanceCust_ProcessHistory;
GO

DROP PROC IF EXISTS Age_ClearBalanceCust_Job_ProcessHistoryImport_xtest;
DROP PROC IF EXISTS Age_ClearBalanceCust_Job_ProcessHistoryImport;

DROP PROC IF EXISTS Age_ClearBalanceCust_ProcessHistorySel_xtest
DROP PROC IF EXISTS Age_ClearBalanceCust_ProcessHistorySel;
GO