/*<info serverAlias="DBSIC-bodb02,DBCTG-bodb02" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE  [dbo].[Age_ClearBalanceCust_Job_NotifyUpd]
	@ErrCode		INT = 0 OUTPUT,  
	@ErrMsg			NVARCHAR(4000) = '' OUTPUT
AS
/*
	Created:20231024@Bobby
	Task: 182071 - Auto Transfer/ Multiple Transfer	
	DB: DBSIC-bodb02,DBCTG-bodb02

	Revisions:
		- 20231024@Bobby: INIT [RedmineID: #182071]

	Param's Explanation:

*/
BEGIN
	SET NOCOUNT ON;

	DECLARE
		@AutoJob_Runtime_VName		VARCHAR(50)  = 'AutoJob_ClearBalance_Runtime'
	;

	--TODO: UPDATE setting
	BEGIN TRY
		
		UPDATE TOP(1) s
		SET VValue = JSON_MODIFY(VValue, '$.StartTime_Notify', 1)
		FROM dbo.SystemSettings s WITH(ROWLOCK, UPDLOCK)
		WHERE VName = @AutoJob_Runtime_VName
		
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = 101,
			@ErrMsg		= ERROR_MESSAGE()
		;
	END CATCH

END
GO