/*<info serverAlias="DBLOG-bodb_CustomerLog,DBCUST-bodb_CustomerLog" executers="bodbDownlineNet,bodbAdminNet,bodbDownlineNetView" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].Age_WriteLog_UserLog_RunSP_Multiple
	@UserID INT,  
	@SPName VARCHAR(50),
	@LogData NVARCHAR(MAX) = NULL,
	@Duration INT = 0,
	@Language varchar(2) = 'E',
	@IP varchar(15) = '',
	@ErrCode		INT = 0 ,
	@ErrMsg			NVARCHAR(4000) = ''
/*
	Created:20230906@Bobby
	Task: 182071 - Auto Transfer/ Multiple Transfer	
	DB: DBLOG-bodb_CustomerLog,DBCUST-bodb_CustomerLog

	Revisions:
		- 20230906@Bobby: Enhance ADBT config [RedmineID: #193017]

	Param's Explanation:
*/
AS  
BEGIN  

	DECLARE @xmlData XML;

	IF @LogData IS NULL
		RETURN;

	SET @xmlData = CAST(@LogData AS XML);
 
	
	WITH CTE_Log AS (
		SELECT 
			t.c.value('@cid','INT')	AS CustId,
			t.c.value('@aid','INT')	AS ActionId
		FROM @xmlData.nodes ('/r') t(c)
	)
	INSERT INTO dbo.UserLog_RunSP(
		UserID,   
		CustID,   
		SPName,  
		Doing,  
		ActionID,   
		TrackingValue,  
		TrackingValue2,  
		Duration  
	)  
	SELECT 
		@UserID AS UserId,
		CustId,
		@SPName AS SPName,
		NULL AS Doing,
		ActionId,
		REPLACE(tv.TrackingValue, 'SP_TEMPLATE', @SPName)	AS TrackingValue,
		REPLACE(tv.TrackingValue2, 'SP_TEMPLATE', @SPName)	AS TrackingValue2,
		@Duration AS Duration
	FROM CTE_Log l
	CROSS APPLY (
		SELECT 
			TrackingValue = (SELECT CustId AS '@CustId', 0 AS '@IsAllowAutoTransfer',
							ISNULL(@IP, SPACE(1)) AS '@IP', @Language AS '@Language', @UserID AS '@Creator',
							@ErrCode AS '@ErrCode', @ErrMsg AS '@ErrMsg'
						FOR XML PATH('SP_TEMPLATE'))
			,TrackingValue2 = (SELECT CustId AS '@CustId', 1 AS '@IsAllowAutoTransfer'
						FOR XML PATH('SP_TEMPLATE'))
	) as tv (TrackingValue, TrackingValue2)
	OPTION (OPTIMIZE FOR (@xmlData = NULL))
    
END  
go