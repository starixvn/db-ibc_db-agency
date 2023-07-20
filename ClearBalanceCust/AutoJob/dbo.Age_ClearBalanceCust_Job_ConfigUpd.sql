/*<info serverAlias="DBSIC-bodb02,DBCTG-bodb02" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE  [dbo].[Age_ClearBalanceCust_Job_ConfigUpd]
	@DefaultTime	VARCHAR(8),
	@RunningMode	VARCHAR(10),
	@ManualTime		SMALLDATETIME = NULL,
	@ErrCode		INT = 0 OUTPUT,
	@ErrMsg			NVARCHAR(4000) = '' OUTPUT
AS
/*
	Created:20230227@bobby
	Task: 182071 - Auto Transfer/ Multiple Transfer	
	DB: DBSIC-bodb02,DBCTG-bodb02

	Revisions:
		- 20230227@bobby: INIT [RedmineID: #182071]

	Param's Explanation:

*/
BEGIN
	SET NOCOUNT ON;

	DECLARE
		@AutoJob_ClearBalance_VName		VARCHAR(50)  = 'AutoJob_ClearBalance_Config',
		@AutoJob_ClearBalance_VValue	VARCHAR(200)
	;

	SELECT @ErrCode = 0,
		@ErrMsg		= ''
	;

	IF @RunningMode NOT IN ('Normal', 'Resume')
		OR LEN(ISNULL(@DefaultTime,'')) <> 5 ---> 'hh:mm'
	BEGIN
		SELECT @ErrCode = 101,
			@ErrMsg		= 'Invalid input values'
		;
		RETURN;
	END


	--TODO: UPDATE setting
	BEGIN TRY
		SET @AutoJob_ClearBalance_VValue = (
			SELECT 
				@DefaultTime	AS dt,
				@ManualTime		AS mt,
				@RunningMode	AS rm
			FOR JSON PATH, WITHOUT_ARRAY_WRAPPER 
		);

		IF EXISTS (
			SELECT TOP(1) 1
			FROM dbo.SystemSettings (NOLOCK)
			WHERE VName = @AutoJob_ClearBalance_VName
		) 
		BEGIN
			UPDATE TOP(1) s
			SET VValue = @AutoJob_ClearBalance_VValue
			FROM dbo.SystemSettings s WITH(ROWLOCK, UPDLOCK)
			WHERE VName = @AutoJob_ClearBalance_VName
		END
		ELSE
		BEGIN
			INSERT INTO dbo.SystemSettings (VName, VValue)
			VALUES(@AutoJob_ClearBalance_VName, @AutoJob_ClearBalance_VValue)
		END
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = 102,
			@ErrMsg		= ERROR_MESSAGE()
		;
	END CATCH

END
GO