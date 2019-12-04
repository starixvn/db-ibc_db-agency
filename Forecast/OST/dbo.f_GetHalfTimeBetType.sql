/*<info serverAlias="DBOST-bodb_ost" selectors="bodbDownlineNet,bodbDownlineNetView" executers="" viewers="" isFunction="1" isNested="1"></info>*/
ALTER FUNCTION [dbo].[f_GetHalfTimeBetType] ()
RETURNS TABLE
AS
/*
	Created:20191021@Bobby
	Task: New Forecast at Agent Site - Supported HDP & OU only
	DB: DBOST.bodb_ost
	
	Revisions: 
		- 20191021@Bobby: Initialize [Redmine:114231] 
		- 20191203@Bobby: Remove redundant HT bettype [Redmine:114231] 
		
*/
RETURN (
	SELECT 7 AS bettype

	UNION ALL
	SELECT 8
)
GO
