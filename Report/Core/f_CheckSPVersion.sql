/*<info serverAlias="DBAGE-bodb02,DBEXT-bodb02,DBDWH-bodb02,DBDWH-bodb_dwrs,DBSUM.bodb_Summary,DBACC-bodb02,DBACC-bodb_ACC,DBRPT-bodb_Report,DBPRO-bodb02,DBCUST-CUSTDB,DBTXN-bodb02" executers="bodbAdminNet" isFunction="1" isNested="1"></info>*/
ALTER FUNCTION [dbo].[f_CheckSPVersion]
(
	@PROCID INT
)
/*
	Creator: Percy
	Date: 2016-03-23
	Task: Check SP Version
	DB:
		DBAGE.bodb02, DBEXT.bodb02, DBDWH.bodb02, DBDWH.bodb_dwrs,DBSUM.bodb_Summary
		DBACC.bodb02, DBACC.bodb_ACC, DBRPT.bodb_Report,
		DBPRO.bodb02, DBCUST.CUSTDB, DBTXN.bodb02
	Revisions:
		- 20160505@Percy: Remove 2 versions UAT3, UAT4 (for hotfix only)
	Remark: use function at database local - not link server or link database
*/
RETURNS BIT
AS
BEGIN
	IF	OBJECT_NAME(@PROCID) LIKE '%_xtest%'
		OR OBJECT_NAME(@PROCID) LIKE '%_xpre%'
		OR OBJECT_NAME(@PROCID) LIKE '%_UAT1%'
		OR OBJECT_NAME(@PROCID) LIKE '%_UAT2%'
		RETURN 1
	RETURN 0
END
GO