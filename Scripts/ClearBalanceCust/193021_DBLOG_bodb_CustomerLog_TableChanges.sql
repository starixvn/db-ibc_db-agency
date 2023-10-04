/*<info serverAlias="DBLOG-bodb_CustomerLog"></info>*/
/*
	Created: 20230921@Bobby
	DB: DBLOG-bodb_CustomerLog
	Task: AutoJob Enhancement - [Redmine : #193021]
*/

-- DBLOG
use bodb_CustomerLog;
GO

/**
insert into [LogAction] (ActionID,ActionTypeID,	SPName,	ActionNameEN, ActionNameTH, ActionNameCS, ActionNameCN, ActionNameCH)
VALUES
(95097,	4, 'Age_ClearBalanceCust_SettingUpdate_Downline',
	N'Auto Transfer is disabled when All Day Balance Transfer is enabled for Super',
	N'ระบบโอนอัตโนมัติจะปิดใช้งาน เมื่อโหมดการโอนยอดคงเหลือตลอดทั้งวันของสูงสุดเปิดใช้งานอยู่',
	N'当超级启用全天余额转账时，自动转账将被禁用。',
	N'當超級啟用全天餘額轉賬時，自動轉賬將被禁用。',
	N'當超級啟用全天餘額轉賬時，自動轉賬將被禁用。'
)
,(95098, 4, 'Age_ClearBalanceCust_SettingUpdate_Downline',
	N'Auto Transfer is disabled when All Day Balance Transfer is enabled for Master',
	N'ระบบโอนอัตโนมัติจะปิดใช้งาน เมื่อโหมดการโอนยอดคงเหลือตลอดทั้งวันของตัวแทนหลักเปิดใช้งานอยู่',
	N'当总代理启用全天余额转账时，自动转账将被禁用。',
	N'當總代理啟用全天餘額轉賬時，自動轉賬將被禁用。',
	N'當總代理啟用全天餘額轉賬時，自動轉賬將被禁用。'
)
;
GO

UPDATE [LogAction] WITH(ROWLOCK, UPDLOCK)
SET ActionNameKO = ActionNameEN,
	ActionNameJP = ActionNameEN
WHERE ActionID IN (95097, 95098)
**/


-- DBLOG
use bodb_CustomerLog;
GO
--TODO: Update TH translation
--Super level
UPDATE la WITH(ROWLOCK, UPDLOCK)
SET ActionNameTH = N'ระบบโอนอัตโนมัติจะปิดใช้งาน เมื่อโหมดการโอนยอดคงเหลือตลอดทั้งวันของซุปเปอร์เปิดใช้งานอยู่'
FROM LogAction la
WHERE ActionID IN (95097)
GO

--Master level
UPDATE la WITH(ROWLOCK, UPDLOCK)
SET ActionNameTH = N'ระบบโอนอัตโนมัติจะปิดใช้งาน เมื่อโหมดการโอนยอดคงเหลือตลอดทั้งวันของมาสเตอร์เปิดใช้งานอยู่'
FROM LogAction la
WHERE ActionID IN (95098)