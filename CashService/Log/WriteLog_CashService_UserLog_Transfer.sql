/*<info serverAlias="DBLOG-bodb_CustomerLog,DBSIC-bodb_CustomerLog" executers="asv_CashService,wsv_CashService" viewers="" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[WriteLog_CashService_UserLog_Transfer]
	@UserID int = 0, 
	@FromCustID INT = 0, 
	@ToCustID INT = 0, 
	@IP varchar(45)='',
	@Doing varchar(1000)='',
	@LogData varchar(max) = null,
	@ErrCode int = 0 OUTPUT,
	@ErrMsg varchar(250) = '' OUTPUT
AS
/*  
	Created : 20250423@Eden
	Description: Write log transfer for Cash
	DB: DBLOG-bodb_CustomerLog,DBTXN-bodb_CustomerLog
	
	Revisions:
		- 20250423@Eden: Alpha - Agency Cash Service [redmine: #223896] 
		- 20250609@Bobby: Multiple logs transfer [redmine: #227984] 

	Parameter's Explanation:	

	Sample:
*/  
BEGIN
	SET NOCOUNT ON;
	SELECT @ErrCode = 0, @ErrMsg = '';

	IF @UserID > 0 
		AND @FromCustID > 0 
		AND @ToCustID > 0
	BEGIN
		INSERT INTO dbo.Cash_UserLog_Transfer(	
									UserID,
									FromCustID,
									ToCustID,
									IP,
									Doing) 
							VALUES(	@UserID,
									@FromCustID,
									@ToCustID,
									@IP,
									@Doing)
	END
	
	IF @LogData IS NOT NULL
	BEGIN
		BEGIN TRY
			-- Parse multiple rows from JSON array in @LogData and insert each as a row
			WITH CTE_LogData AS (
				SELECT
					TRY_CAST(JSON_VALUE(logItem.value, '$.UserID') AS INT) AS UserID,
					TRY_CAST(JSON_VALUE(logItem.value, '$.FromCustID') AS INT) AS FromCustID,
					TRY_CAST(JSON_VALUE(logItem.value, '$.ToCustID') AS INT) AS ToCustID,
					TRY_CAST(JSON_VALUE(logItem.value, '$.IP') AS VARCHAR(15)) AS IP,
					TRY_CAST(JSON_VALUE(logItem.value, '$.Doing') AS VARCHAR(1000)) AS Doing
				FROM OPENJSON(@LogData) AS logItem
			)
			INSERT INTO dbo.Cash_UserLog_Transfer (
				UserID,
				FromCustID,
				ToCustID,
				IP,
				Doing
			)
			SELECT 
				UserID,
				FromCustID,
				ToCustID,
				IP,
				Doing
			FROM CTE_LogData
			WHERE UserID > 0
				AND FromCustID > 0
				AND ToCustID > 0
			;
		END TRY
		BEGIN CATCH
			-- Handle any errors that occur during the insert
			SELECT @ErrCode = 101,
				@ErrMsg = 'Error inserting log data: ' + ERROR_MESSAGE();
			
			
		END CATCH
	END	
END
GO
