/*<info serverAlias="DBCUST-CustDB" executers="" isFunction="1"></info>*/
CREATE FUNCTION [dbo].[f_AutoTransferSchedule_CharToNumeric](@AutoTransferSchedule_string VARCHAR(20))
RETURNS TINYINT
AS
/*
	Created: 20231102@Luke
	DB: DBCUST/CustDB
	Task: Alpha - Enhance auto transfer function (Phase 2) [Redmine: #195135]

	Revisions:
		- 20231102@Luke: Alpha - Enhance auto transfer function (Phase 2) [Redmine: #195135] 
*/
BEGIN
	RETURN
	(
		SELECT SUM(POWER(2, CONVERT(TINYINT, value))) FROM string_split(@AutoTransferSchedule_string, ',') WHERE value <> ''
	)
END


