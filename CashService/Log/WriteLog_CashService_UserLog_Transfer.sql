/*<info serverAlias="DBLOG-bodb_CustomerLog,DBSIC-bodb_CustomerLog" executers="asv_CashService,wsv_CashService" viewers="" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[WriteLog_CashService_UserLog_Transfer]
	@UserID int, 
	@FromCustID INT, 
	@ToCustID INT, 
	@IP varchar(45)='',
	@Doing varchar(1000)=''
AS
/*  
	Created : 20250423@Eden
	Description: Write log transfer for Cash
	DB: DBLOG-bodb_CustomerLog,DBTXN-bodb_CustomerLog
	
	Revisions:
		- 20250423@Eden: Alpha - Agency Cash Service [redmine: #223896] 

	Parameter's Explanation:	

	Sample:
*/  

SET NOCOUNT ON;

INSERT INTO dbo.Cash_UserLog_Transfer(	UserID,
									FromCustID,
									ToCustID,
									IP,
									Doing) 
							VALUES(	@UserID,
									@FromCustID,
									@ToCustID,
									@IP,
									@Doing)

GO
