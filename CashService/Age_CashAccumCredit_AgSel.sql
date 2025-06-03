/*<info serverAlias="DBSIC-bodb02" executers="asv_CashService,wsv_CashService,wsv_nap,wsv_alp,wsv_alpv,wsv_xnap" selecters="" viewers="" isFunction="0" isNested=""></info>*/
ALTER PROCEDURE Age_CashAccumCredit_AgSel
	@CustID		INT = NULL,
	@AccumCreditReturn MONEY = 0 OUTPUT
AS 
/*
	Created: 20250423@Eden		
	Task: get total Cash member return Credit of Agent
	DB:  DBSIC-bodb02
		
	Revisions:
		- 20250423@Eden: Alpha - Agency Cash Service [redmine: #223896] 

	Parameter's Explanation:	
	Sample:
		DECLARE @AccumCreditReturn MONEY,
				@CustID INT = 1176086
		EXEC Age_CashAccumCredit_AgSel 
			 @CustID = @CustID
			,@AccumCreditReturn = @AccumCreditReturn OUTPUT

		SELECT @AccumCreditReturn AS AccumCreditReturn 
*/ 
BEGIN
	SET NOCOUNT ON

	SELECT @AccumCreditReturn = AccumCreditReturn 
	FROM dbo.f_Age_CashAccumCredit_AgSel(@CustID)
END
GO