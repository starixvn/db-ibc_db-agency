/*<info serverAlias="DBSIC-bodb02" executers="asv_CashService,wsv_CashService,wsv_nap,wsv_alp,wsv_alpv,wsv_xnap" selecters="" viewers="" isFunction="0" isNested=""></info>*/
ALTER PROCEDURE [dbo].[Age_CashTransactionDetail_Sel]  
	@TransId BIGINT
	,@CustId INT
AS  
/*
	Created: 20250502@Max		
	Task: Alpha - Agency Cash Service [redmine: #223896] 
	DB:  DBSIC-bodb02
		
	Revisions:
		- 20250502@Max: Alpha - Agency Cash Service [redmine: #223896] 
		- 20250611@Max: Alpha - Agency Cash Service - Sprint 4 [redmine: #223896] 
		- 20250624@Eden: Alpha - Agency Cash Service - Sprint 5 [redmine: #223896] 

	Parameter's Explanation:

	Sample:
		EXEC [Age_CashTransactionDetail_Sel] @TransID = 1 , @CustID = 1
*/ 
BEGIN  
    SET NOCOUNT ON; 

	DECLARE @CashMemberBetCredit money
	EXEC dbo.Age_CashService_CashBalance_Sel @CustId = @CustId , @TotalCash = @CashMemberBetCredit OUTPUT

	SELECT tr.CustId
		,c.username
		,c.username2 AS nickname
		,c.firstname
		,c.lastname
		,tr.Amount
		,e.currency
		,tr.PaymentFrom
		,tr.PaymentTo
		,tr.StatusId
		,tr.TransactionTypeID
		,tr.TransferRefNo
		,tr.CreatedTime
		,co.username AS CreatedBy 
		,tr.OperatedTime
		,tr.Remark
		,Payslip
		,@CashMemberBetCredit AS BetCredit 
		,IIF(tr.PaymentType = 1, 0 , 1) AS IsAllowRevert
		,tr.TransId
		,tr.PaymentType
	FROM dbo.CashTransaction tr WITH (NOLOCK)
		INNER JOIN CustDB.dbo.vw_CashService_Customer c WITH (NOLOCK) ON c.custid = tr.CustID
		INNER JOIN CustDB.dbo.vw_CashService_Customer co WITH (NOLOCK) ON co.custid = tr.Creator
		INNER JOIN CustDB.dbo.exchange e WITH (NOLOCK) ON e.ExchangeId = c.currency
	WHERE tr.TransId = @TransId
	ORDER BY tr.TransId DESC
	
END  