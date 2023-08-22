/*<info serverAlias="DBSIC-bodb02,DBCTG-bodb02" executers="bodbDownlineNet,bodbAdminNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE  [dbo].[Age_ClearBalanceCust_Job_ConfigSel]
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
		@AutoJob_ClearBalance_VName_Config		VARCHAR(50)  = 'AutoJob_ClearBalance_Config',
		@AutoJob_ClearBalance_VValue_Config		VARCHAR(200),
		@AutoJob_ClearBalance_VName_Runtime		VARCHAR(50)  = 'AutoJob_ClearBalance_Runtime',
		@AutoJob_ClearBalance_VValue_Runtime	VARCHAR(200),
		@StartTime DATETIME,
		@CompletedTime DATETIME
	;

	--TODO: Check setting
	SELECT @AutoJob_ClearBalance_VValue_Config = IIF(VName = @AutoJob_ClearBalance_VName_Config, VValue, @AutoJob_ClearBalance_VValue_Config)
		, @AutoJob_ClearBalance_VValue_Runtime = IIF(VName = @AutoJob_ClearBalance_VName_Runtime, VValue, @AutoJob_ClearBalance_VValue_Runtime)
	FROM dbo.SystemSettings (NOLOCK)
	WHERE VName IN ( @AutoJob_ClearBalance_VName_Config, @AutoJob_ClearBalance_VName_Runtime)
	;

	SELECT @CompletedTime	= CAST(JSON_VALUE(@AutoJob_ClearBalance_VValue_Runtime, '$.CompletedTime') AS DATETIME),
			@StartTime		= CAST(JSON_VALUE(@AutoJob_ClearBalance_VValue_Runtime, '$.StartTime') AS DATETIME)
	;

	SELECT 
		DefaultTime		= ISNULL(JSON_VALUE(@AutoJob_ClearBalance_VValue_Config, '$.dt'), '00:00:00'),
		ManualTime		= CAST(JSON_VALUE(@AutoJob_ClearBalance_VValue_Config, '$.mt') AS SMALLDATETIME),
		RunningMode		= ISNULL(JSON_VALUE(@AutoJob_ClearBalance_VValue_Config, '$.rm'), 'Normal'),
		IsActive		= CAST(ISNULL(JSON_VALUE(@AutoJob_ClearBalance_VValue_Config, '$.ia'), 0) AS BIT),
		StartTime		= @StartTime,
		CompletedTime	= @CompletedTime
	;
END
GO