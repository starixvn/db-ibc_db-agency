/*<info serverAlias="DBCUST-CustDB" executers="" isFunction="1"></info>*/
CREATE FUNCTION [dbo].[f_AutoTransferSchedule_NumericToChar](@AutoTransferSchedule_numeric TINYINT)
RETURNS VARCHAR(20)
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
        SELECT STRING_AGG(dayweek, ',') WITHIN GROUP (ORDER BY CASE WHEN dayweek = 1 THEN 8 ELSE dayweek END) AS day_string
        FROM(
			VALUES
				(1,@AutoTransferSchedule_numeric & POWER(2,1)),
				(2,@AutoTransferSchedule_numeric & POWER(2,2)),
				(3,@AutoTransferSchedule_numeric & POWER(2,3)),
				(4,@AutoTransferSchedule_numeric & POWER(2,4)),
				(5,@AutoTransferSchedule_numeric & POWER(2,5)),
				(6,@AutoTransferSchedule_numeric & POWER(2,6)),
				(7,@AutoTransferSchedule_numeric & POWER(2,7))
			) AS t(dayweek, bitcheck)
        WHERE bitcheck > 0  
	)
END

