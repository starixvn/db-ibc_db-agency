/*<info serverAlias="DBTXN-bodb02" executers="bodbDownlineNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Age_ClearBalanceCust_Job_StatusCheck]
	@IsAutoJobRunning		BIT OUTPUT,
	@ErrCode				INT = 0 OUTPUT,
	@ErrMsg					NVARCHAR(4000) = '' OUTPUT

AS
/*
	Created:20230227@Bobby
	Task: 182071 - Auto Transfer/ Multiple Transfer	
	DB: DBTXN/bodb02

	Revisions:
		- 20230227@Bobby: AutoJob clear balance downlines [RedmineID: #182071]

	Param's Explanation:

*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @today DATE;

	SELECT @today	= GETDATE()
		, @IsAutoJobRunning	= 0
		;

	--TODO: Check the AutoJob is running or NOT
	SELECT TOP 1 @IsAutoJobRunning = 1
	FROM dbo.Age_ClearBalanceCust_Process p WITH(NOLOCK)
	WHERE SessionDate = @today
		AND [Status] IN ('New', 'Waiting', 'Running')
		OR ([Status] = 'Failed' AND TryCount BETWEEN 1 AND 4);

END
GO