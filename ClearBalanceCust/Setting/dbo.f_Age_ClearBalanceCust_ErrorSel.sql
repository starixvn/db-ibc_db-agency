/*<info serverAlias="DBSIC-bodb02,DBCTG-bodb02,DBLOG-bodb_CustomerLog" selecters="bodbDownlineNet,bodbDownlineNetView" isFunction="1" isNested="1"></info>*/
ALTER FUNCTION dbo.f_Age_ClearBalanceCust_ErrorSel() 
RETURNS TABLE
RETURN
/*
	Created:20230227@Bobby
	Task: 182071 - Auto Transfer/ Multiple Transfer	
	DB: DBSIC-bodb02,DBCTG-bodb02,DBLOG-bodb_CustomerLog

	Revisions:
		- 20230227@Bobby: AutoJob clear balance downlines [RedmineID: #182071]

*/
SELECT ErrType, AllowReTry, IsShowHistory
FROM (
	VALUES ('TransferOption', 0, 1),
		('ProcessingTime', 0, 0),
		('NotFound', 0, 0),
		('TransferUM', 1, 1),
		('AccTransfering', 0, 1), --- Existing transfer NAP
		('BalanceZero', 0, 1),
		('TransferStatus', 0, 1),
		('IsAllDayBalTransfer', 0, 1), --- Existing transfer
		('DBIssue', 1, 1)
) AS t (ErrType, AllowReTry, IsShowHistory)
GO