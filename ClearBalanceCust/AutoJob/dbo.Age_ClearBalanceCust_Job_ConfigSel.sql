/*<info serverAlias="DBTXN-bodb02" executers="bodbDownlineNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE  [dbo].[Age_ClearBalanceCust_Job_ConfigSel]
AS
/*
	Created:20230227@bobby
	Task: 182071 - Auto Transfer/ Multiple Transfer	
	DB: DBAGE/bodb02

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

	--TODO: Check setting
	SELECT TOP(1) @AutoJob_ClearBalance_VValue = VValue
	FROM dbo.SystemSettings (NOLOCK)
	WHERE VName = @AutoJob_ClearBalance_VName
	;

	SELECT 
		DefaultTime	= ISNULL(JSON_VALUE(@AutoJob_ClearBalance_VValue, '$.dt'), '00:00:00'),
		ManualTime	= CAST(JSON_VALUE(@AutoJob_ClearBalance_VValue, '$.mt') AS SMALLDATETIME),
		RunningMode	= ISNULL(JSON_VALUE(@AutoJob_ClearBalance_VValue, '$.rm'), 'Normal')
END
GO