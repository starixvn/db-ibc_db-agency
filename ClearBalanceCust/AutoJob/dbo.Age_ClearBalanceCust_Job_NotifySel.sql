/*<info serverAlias="DBSIC-bodb02,DBCTG-bodb02" executers="bodbDownlineNet,bodbAdminNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Age_ClearBalanceCust_Job_NotifySel]
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
		@AutoJob_Runtime_VName		VARCHAR(50)  = 'AutoJob_ClearBalance_Runtime',
		@AutoJob_Runtime_VValue		VARCHAR(200) = '{}'
	;

	SELECT TOP(1) @AutoJob_Runtime_VValue = VValue
	FROM dbo.SystemSettings (NOLOCK)
	WHERE VName = @AutoJob_Runtime_VName
	
	SELECT StartTime		= CAST(JSON_VALUE(@AutoJob_Runtime_VValue, '$.StartTime') AS DATETIME),
		StartTime_Notify	= ISNULL(CAST(JSON_VALUE(@AutoJob_Runtime_VValue, '$.StartTime_Notify') AS INT),0)

END
GO