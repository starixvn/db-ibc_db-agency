/*<info serverAlias="DBLOG-bodb_CustomerLog" executers="bodbDownlineNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Age_ClearBalanceCust_Job_ProcessHistoryImport]
	@RowData	VARCHAR(MAX) = '',
	@ErrCode	INT = 0 OUTPUT,
	@ErrMsg		NVARCHAR(4000) = '' OUTPUT
AS
/*
	Created:20230227@Bobby
	Task: 182071 - Auto Transfer/ Multiple Transfer	
	DB: DBLOG/bodb_CustomerLog

	Revisions:
		- 20230227@Bobby: AutoJob clear balance downlines [RedmineID: #182071]

	Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	SELECT @ErrCode = 0,
		@ErrMsg		= ''
	;

	IF @RowData IS NULL
		RETURN

	BEGIN TRY
		WITH CTE_Data AS (
			SELECT *
			FROM OPENJSON(@RowData) 
			WITH (
				SessionDate		SMALLDATETIME '$.c1',
				BatchNo			INT '$.c2',
				SuperId			INT '$.c3',
				FromCustId		INT '$.c4',
				ToCustId		INT '$.c5',
				RoleId			TINYINT '$.c6',
				Status			VARCHAR(15) '$.c7',	
				Amount			MONEY '$.c8',	
				Result			VARCHAR(MAX) '$.c9',	
				TryCount		TINYINT '$.c10',	
				ModifiedTime	DATETIME '$.c11',	
				StartTime		DATETIME '$.c12',	
				EndTime			DATETIME '$.c13',	
				Creator			INT '$.c14',	
				IsAllDayBalTransfer		BIT '$.c15'
			)
		)
		INSERT INTO [dbo].[Age_ClearBalanceCust_ProcessHistory]
           ([SessionDate]
           ,[BatchNo]
           ,[SuperId]
           ,[FromCustId]
           ,[ToCustId]
           ,[RoleId]
           ,[Status]
           ,[Amount]
           ,[Result]
           ,[TryCount]
           ,[ModifiedTime]
           ,[StartTime]
           ,[EndTime]
           ,[Creator]
           ,[IsAllDayBalTransfer])
		SELECT [SessionDate]
           ,[BatchNo]
           ,[SuperId]
           ,[FromCustId]
           ,[ToCustId]
           ,[RoleId]
           ,[Status]
           ,[Amount]
           ,[Result]
           ,[TryCount]
           ,[ModifiedTime]
           ,[StartTime]
           ,[EndTime]
           ,[Creator]
           ,[IsAllDayBalTransfer]
		FROM CTE_Data
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = 102
			, @ErrMsg = ERROR_MESSAGE()
	END CATCH
END
GO
