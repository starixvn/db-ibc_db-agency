/*<info serverAlias="DBSIC-bodb02,DBCUST-CustDB,DBAGE-bodb02,DBACC-bodb02" selecters="" viewers="" isFunction="1"></info>*/
ALTER FUNCTION dbo.f_Age_CashAccumCredit_AgSel (@CustID INT)
RETURNS TABLE  
AS
/*
	Created: 20241107@Eden		
	Task: Return Cash Member used Credit of Agent level
	DB:  DBSIC-bodb02,DBCUST-CustDB,DBAGE-bodb02,DBACC-bodb02
		
	Revisions:
		- 20250423@Eden: Alpha - Agency Cash Service [redmine: #223896] 

	Parameter's Explanation:			
	
	Sample:
		SELECT * FROM dbo.f_Age_CashAccumCredit_AgSel(1176086)
	*/ 
RETURN
	SELECT ISNULL(SUM(ISNULL(AccumCreditReturn,0)),0) AS AccumCreditReturn
	FROM CashAccumCredit WITH (NOLOCK) 
	WHERE recommend = @CustID