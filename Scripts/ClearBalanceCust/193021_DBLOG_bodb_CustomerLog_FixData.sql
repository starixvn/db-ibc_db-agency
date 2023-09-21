/*<info serverAlias="DBLOG-bodb_CustomerLog"></info>*/
/*
	Created: 20230922@Bobby
	DB: DBLOG-bodb_CustomerLog
	Task: AutoJob Enhancement - [Redmine : #193021]
*/
--DBLOG
 USE [bodb_CustomerLog]
  go
  -- 44 rows
  UPDATE u WITH(ROWLOCK, UPDLOCK)
  SET spname = REPLACE(spname, '_xtest', '')
	  ,TrackingValue = REPLACE(TrackingValue, '_xtest', '')
	  ,TrackingValue2 = REPLACE(TrackingValue2, '_xtest', '')
  FROM .[dbo].[UserLog_RunSP] u
  where logdate >= '2023-09-21' AND ActionID in (95097,95098)