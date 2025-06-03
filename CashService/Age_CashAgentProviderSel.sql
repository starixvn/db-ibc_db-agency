/*<info serverAlias="DBCust-AgencyCashService" executers="asv_CashService,wsv_CashService" selecters="" viewers="" isFunction="0" isNested=""></info>*/
ALTER PROCEDURE dbo.Age_CashAgentProviderSel
	@AgentID		INT , -- SMA_ID Input
	@TransType		TINYINT,
	@IsMemberSite	BIT = 0
AS 
/*
	Created: 20250423@Eden		
	Task: get Agent Provider
	DB:  DBSIC-bodb02
		
	Revisions:
		- 20250423@Eden: Alpha - Agency Cash Service [redmine: #223896] 

	Parameter's Explanation:

	Sample:
		EXEC Age_CashAgentProviderSel @AgentID = 1176086, @TransType = 2, @IsMemberSite = 0
	*/ 
BEGIN
	SET NOCOUNT ON;
	IF (@IsMemberSite = 0 AND @TransType = 2) 
		OR (@IsMemberSite = 1 AND @TransType = 1) 
	BEGIN
		SELECT b.AgentID,p.ProviderID,p.ProviderName,b.PaymentMethodID,m.MethodName
		FROM CashPaymentProviderAPIConfig b WITH (NOLOCK)
			INNER JOIN CashPaymentProvider p WITH(NOLOCK) 
				ON b.ProviderID = p.ProviderID
			INNER JOIN CashPaymentMethod m WITH(NOLOCK) 
				ON m.PaymentMethodID = b.PaymentMethodID
		WHERE b.AgentID = @AgentID
			AND b.TransactionType = @TransType
			AND b.PaymentMethodStatus = 1 --Completed
	END
END
GO