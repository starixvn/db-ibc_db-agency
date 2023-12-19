/*<info serverAlias="DBCUST-CustDB" executers="" isFunction="1"></info>*/
ALTER FUNCTION [dbo].[f_TransferConditon_CharToNumeric_BaseAutoTransfer](@TransferCondition_string VARCHAR(8))
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
	DECLARE @TransferCondition_string_check VARCHAR(8) = IIF(@TransferCondition_string = '00000000','11111111', @TransferCondition_string)
	RETURN CAST(SUBSTRING(@TransferCondition_string_check,1,1) AS TINYINT)*POWER(2,1)
			+ CAST(SUBSTRING(@TransferCondition_string_check,2,1) AS TINYINT)*POWER(2,2)
			+ CAST(SUBSTRING(@TransferCondition_string_check,3,1) AS TINYINT)*POWER(2,3)
			+ CAST(SUBSTRING(@TransferCondition_string_check,4,1) AS TINYINT)*POWER(2,4)
			+ CAST(SUBSTRING(@TransferCondition_string_check,5,1) AS TINYINT)*POWER(2,5)
			+ CAST(SUBSTRING(@TransferCondition_string_check,6,1) AS TINYINT)*POWER(2,6)
			+ CAST(SUBSTRING(@TransferCondition_string_check,7,1) AS TINYINT)*POWER(2,7)
END