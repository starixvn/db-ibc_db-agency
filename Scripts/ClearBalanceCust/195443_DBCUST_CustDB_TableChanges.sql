/*<info serverAlias="DBCUST-CustDB"></info>*/
/*
	Created: 20231120@Bobby
	DB: DBCUST-CustDB
	Task: AutoJob Enhancement - [Redmine : #195443]
*/
USE CustDB;
GO

ALTER TABLE [dbo].[Age_ClearBalanceCust_Setting]
ADD ScheduleOption TINYINT NULL;