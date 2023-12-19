/*<info serverAlias="DBLOG-bodb_CustomerLog,DBCUST-bodb_CustomerLog" executers="bodbDownlineNet,bodbAdminNet,bodbDownlineNetView" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].Age_WriteLog_UserLog_RunSP_Multiple
	@UserID INT,  
	@LogData NVARCHAR(MAX) = NULL,
	@SubAccId INT,
	@Duration INT = 0,
	@Language varchar(2) = 'E',
	@IP varchar(15) = '',
	@ErrCode		INT = 0 ,
	@ErrMsg			NVARCHAR(4000) = '',
	@Mode	TINYINT
/*
	Created:20230906@Bobby
	Task: 182071 - Auto Transfer/ Multiple Transfer	
	DB: DBLOG-bodb_CustomerLog,DBCUST-bodb_CustomerLog

	Revisions:
		- 20230906@Bobby: Enhance ADBT config [RedmineID: #193017]
		- 20231106@Luke: Enhance Auto Transfer function (Phase 2) [Redmine: #195135]

	Param's Explanation:
		@Mode:	1 - Disable Auto Transfer of downlines when turn on All Day Balance Transfer
				2 - Clear Auto Transfer Schedule of downlines when turn on All Day Balance Transfer
				3,5 - Disable Auto Transfer of downlines when update Transfer Condition
				4,6 - Update Auto Transfer Schedule of downlines when update Transfer Condition
*/
AS  
BEGIN  

	DECLARE @xmlData XML;
	DECLARE @SPName VARCHAR(100)

	SELECT @SpName = CASE WHEN @Mode IN (1,2) THEN '<Age_ClearBalanceCust_SettingUpdate_Downline'
							WHEN @Mode IN (3,4) THEN '<Acc_CustomerUpdTransferOption' 
							WHEN @Mode IN (5,6) THEN '<EAS_CustomerUpdTransferOption' END

	IF @LogData IS NULL
		RETURN;

	SET @xmlData = CAST(@LogData AS XML);
 
	IF @Mode = 1	--Disable Auto Transfer of downlines when turn on All Day Balance Transfer
	BEGIN
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
			REPLACE(@SPName, '<', '') AS SPName,
			NULL AS Doing,
			ActionId,
			REPLACE(tv.TrackingValue, '<SP_TEMPLATE', @SPName)	AS TrackingValue,
			REPLACE(tv.TrackingValue2, '<SP_TEMPLATE', @SPName)	AS TrackingValue2,
			@Duration AS Duration
		FROM CTE_Log l
		CROSS APPLY (
			SELECT 
				TrackingValue = (SELECT CustId AS '@CustId', 0 AS '@IsAllowAutoTransfer',
								ISNULL(@IP, SPACE(1)) AS '@IP', @Language AS '@Language', ISNULL(@SubAccId,SPACE(1)) AS '@SubAccId',
								@ErrCode AS '@ErrCode', @ErrMsg AS '@ErrMsg'
							FOR XML PATH('SP_TEMPLATE'))
				,TrackingValue2 = (SELECT CustId AS '@CustId', 1 AS '@IsAllowAutoTransfer'
							FOR XML PATH('SP_TEMPLATE'))
		) as tv (TrackingValue, TrackingValue2)
		OPTION (OPTIMIZE FOR (@xmlData = NULL))
	END
	ELSE IF @Mode = 2	--Clear Auto Transfer Schedule of downlines when turn on All Day Balance Transfer
	BEGIN
		WITH CTE_Log AS (
			SELECT 
				t.c.value('@cid','INT')	AS CustId,
				t.c.value('@os','VARCHAR(20)') AS OldSchedule,
				t.c.value('@aid','INT')	AS ActionId
			FROM @xmlData.nodes ('/r') t(c)
		)
		INSERT INTO dbo.UserLog_RunSP(
			UserID,   
			CustID,   
			SPName,   
			ActionID,   
			TrackingValue,  
			TrackingValue2,  
			Duration  
		)  
		SELECT 
			@UserID AS UserId,
			CustId,
			REPLACE(@SPName, '<', '') AS SPName,
			ActionId,
			REPLACE(tv.TrackingValue, '<SP_TEMPLATE', @SPName)	AS TrackingValue,
			REPLACE(tv.TrackingValue2, '<SP_TEMPLATE', @SPName)	AS TrackingValue2,
			@Duration AS Duration
		FROM CTE_Log l
		CROSS APPLY (
			SELECT 
				TrackingValue = (
					SELECT CustId AS '@CustId', 
							'' AS '@Schedule',
							ISNULL(@IP, SPACE(1)) AS '@IP', @Language AS '@Language', 
							ISNULL(@SubAccId,SPACE(1)) AS '@SubAccId',
							ISNULL(@ErrCode,SPACE(1)) AS '@ErrCode', 
							ISNULL(@ErrMsg,SPACE(1)) AS '@ErrMsg'
					FOR XML PATH('SP_TEMPLATE')
				)
				,TrackingValue2 = (
					SELECT CustId AS '@CustId', 
							ISNULL(OldSchedule,SPACE(1)) AS '@Schedule'
					FOR XML PATH('SP_TEMPLATE')
				)
		) as tv (TrackingValue, TrackingValue2)
		OPTION (OPTIMIZE FOR (@xmlData = NULL))
	END
	ELSE IF @Mode IN (3,5)	--Disable Auto Transfer of downlines when update Transfer Condition
	BEGIN
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
			ActionID,   
			TrackingValue,  
			TrackingValue2,  
			Duration  
		)  
		SELECT 
			@UserID AS UserId,
			CustId,
			REPLACE(@SPName, '<', '') AS SPName,
			ActionId,
			REPLACE(tv.TrackingValue, '<SP_TEMPLATE', @SPName)	AS TrackingValue,
			REPLACE(tv.TrackingValue2, '<SP_TEMPLATE', @SPName)	AS TrackingValue2,
			@Duration AS Duration
		FROM CTE_Log l
		CROSS APPLY (
			SELECT 
				TrackingValue = (
					SELECT CustId AS '@CustId', 
							0 AS '@IsAutoTransfer',
							ISNULL(@IP, SPACE(1)) AS '@IP', @Language AS '@Language', 
							ISNULL(@SubAccId,SPACE(1)) AS '@SubAccId',
							ISNULL(@ErrCode,SPACE(1)) AS '@ErrCode', 
							ISNULL(@ErrMsg,SPACE(1)) AS '@ErrMsg'
					FOR XML PATH('SP_TEMPLATE')
				)
				,TrackingValue2 = (
					SELECT CustId AS '@CustId', 
							1 AS '@IsAutoTransfer'
					FOR XML PATH('SP_TEMPLATE')
				)
		) as tv (TrackingValue, TrackingValue2)
		OPTION (OPTIMIZE FOR (@xmlData = NULL))
	END
	ELSE IF @Mode IN (4,6)	--Update Auto Transfer Schedule of downlines when update Transfer Condition
	BEGIN
		WITH CTE_Log AS (
			SELECT 
				t.c.value('@cid','INT')	AS CustId,
				t.c.value('@aid','INT')	AS ActionId,
				t.c.value('@os', 'VARCHAR(20)') AS OldSchedule,
				t.c.value('@ns', 'VARCHAR(20)') AS NewSchedule
			FROM @xmlData.nodes ('/r') t(c)
		)
		INSERT INTO dbo.UserLog_RunSP(
			UserID,   
			CustID,   
			SPName,   
			ActionID,   
			TrackingValue,  
			TrackingValue2,  
			Duration  
		)  
		SELECT 
			@UserID AS UserId,
			CustId,
			REPLACE(@SPName, '<', '') AS SPName,
			ActionId,
			REPLACE(tv.TrackingValue, '<SP_TEMPLATE', @SPName)	AS TrackingValue,
			REPLACE(tv.TrackingValue2, '<SP_TEMPLATE', @SPName)	AS TrackingValue2,
			@Duration AS Duration
		FROM CTE_Log l
		CROSS APPLY (
			SELECT 
				TrackingValue = (
					SELECT CustId AS '@CustId', 
							ISNULL(NewSchedule,SPACE(1)) AS '@Schedule',
							ISNULL(@IP, SPACE(1)) AS '@IP', @Language AS '@Language', 
							ISNULL(@SubAccId,SPACE(1)) AS '@SubAccId',
							ISNULL(@ErrCode,SPACE(1)) AS '@ErrCode', 
							ISNULL(@ErrMsg,SPACE(1)) AS '@ErrMsg'
					FOR XML PATH('SP_TEMPLATE')
				)
				,TrackingValue2 = (
					SELECT CustId AS '@CustId', 
							ISNULL(OldSchedule,SPACE(1)) AS '@Schedule'
					FOR XML PATH('SP_TEMPLATE')
				)
		) as tv (TrackingValue, TrackingValue2)
		OPTION (OPTIMIZE FOR (@xmlData = NULL))		
	END
END  
go