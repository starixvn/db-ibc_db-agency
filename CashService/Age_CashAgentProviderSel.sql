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
		- 20250616@Eden: Alpha - Agency Cash Service - Sprint 4 [redmine: #223896] 

	Parameter's Explanation:

	Sample:
		EXEC Age_CashAgentProviderSel @AgentID = 1176086, @TransType = 1, @IsMemberSite = 1
	*/ 
BEGIN
	SET NOCOUNT ON;
	IF (@IsMemberSite = 0 AND @TransType = 2) 
		OR (@IsMemberSite = 1 AND @TransType = 1) 
	BEGIN
		SELECT pm.AgentID,cp.ProviderID,p.ProviderName,pm.PaymentMethodID,m.MethodName
		FROM dbo.CashAgentPaymentMethod pm WITH (NOLOCK)
			INNER JOIN dbo.CashAgentProviderConfig cp WITH (NOLOCK)
				ON cp.AgentID = pm.AgentID
					AND cp.ProviderID = pm.ProviderID
					AND cp.ProviderStatus = 1 --Provider Enabled
			INNER JOIN dbo.CashPaymentProviderAPIConfig cpa WITH (NOLOCK)
				ON cpa.AgentID = pm.AgentID
					AND cpa.ProviderID = pm.ProviderID
					AND cpa.PaymentMethodID = pm.PaymentMethodID
					AND cpa.TransactionType = pm.TransactionType
					AND cpa.PaymentMethodStatus = 2 --Completed
			INNER JOIN CashPaymentProvider p WITH(NOLOCK) 
				ON pm.ProviderID = p.ProviderID
			INNER JOIN CashPaymentMethod m WITH(NOLOCK) 
				ON m.PaymentMethodID = pm.PaymentMethodID
		WHERE pm.AgentID = @AgentID
			AND pm.PaymentMethodEnable = 1 --Method Enabled
			AND pm.TransactionType = @TransType
	END
END
GO