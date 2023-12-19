/*<info serverAlias="DBSIC-bodb02,DBCTG-bodb02" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE  [dbo].[Age_ClearBalanceCust_Job_RuntimeUpd]
	@Environment	VARCHAR(10),
	@StartTime		DATETIME	= NULL,
	@RunningMode	VARCHAR(15)	= NULL,	
	@IsCompleted	BIT = 0,
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
		@AutoJob_Runtime_VName		VARCHAR(50),
		@AutoJob_Runtime_VValue		VARCHAR(200) = '{}',
		@EnvironmentCheck			VARCHAR(10)
	;

	SELECT @EnvironmentCheck		= IIF(@Environment = 'PRO', '', @Environment),
			@AutoJob_Runtime_VName	= CONCAT('AutoJob_ClearBalance_Runtime', @EnvironmentCheck)

	SELECT @AutoJob_Runtime_VValue = VValue
	FROM dbo.SystemSettings (NOLOCK)
	WHERE VName = @AutoJob_Runtime_VName
	
	--TODO: UPDATE setting
	BEGIN TRY
		-- StartTime
		SELECT @AutoJob_Runtime_VValue = (SELECT @StartTime AS StartTime, @RunningMode AS RunningMode FOR JSON PATH, WITHOUT_ARRAY_WRAPPER)
		WHERE @StartTime IS NOT NULL 

		-- CompletedTime
		SELECT @AutoJob_Runtime_VValue = JSON_MODIFY(@AutoJob_Runtime_VValue, '$.CompletedTime', FORMAT(GETDATE(), 'yyyy-MM-dd HH:mm:ss'))
		WHERE @IsCompleted =  1

		IF EXISTS (
			SELECT TOP(1) 1
			FROM dbo.SystemSettings (NOLOCK)
			WHERE VName = @AutoJob_Runtime_VName
		) 
		BEGIN
			UPDATE TOP(1) s
			SET VValue = @AutoJob_Runtime_VValue
			FROM dbo.SystemSettings s WITH(ROWLOCK, UPDLOCK)
			WHERE VName = @AutoJob_Runtime_VName
		END
		ELSE
		BEGIN
			INSERT INTO dbo.SystemSettings (VName, VValue)
			VALUES(@AutoJob_Runtime_VName, @AutoJob_Runtime_VValue)
		END
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = 101,
			@ErrMsg		= ERROR_MESSAGE()
		;
	END CATCH

END
GO