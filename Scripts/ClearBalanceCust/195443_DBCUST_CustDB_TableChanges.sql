/*<info serverAlias="DBCUST-CustDB"></info>*/
/*
	Created: 20231120@Bobby
	DB: DBSIC-bodb02,DBCTG-bodb02
	Task: AutoJob Enhancement - [Redmine : #195443]
*/
USE CustDB;
GO

ALTER TABLE [dbo].[Age_ClearBalanceCust_Setting]
ADD ScheduleOption TINYINT NULL;