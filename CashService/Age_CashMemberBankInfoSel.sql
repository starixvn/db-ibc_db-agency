/*<info serverAlias="DBCust-AgencyCashService" executers="asv_CashService,wsv_CashService" selecters="" viewers="" isFunction="0" isNested=""></info>*/
ALTER PROCEDURE dbo.Age_CashMemberBankInfoSel
	@CustID INT,
	@BankCode		VARCHAR(10) = NULL,
	@BankAccountNumber	VARCHAR(50) = NULL
AS 
/*  
	Created By: Helios
	Created Date: 2025-04-18
	Description: Agency Cash Service - Get Member Bank Account [Redmine #223896]
	DB: DBCust.AgencyCashService
	
	Revisions:
		- 20250321@Helios: Agency Cash Service [Redmine: #223896]
		- 20250604@Eden: Alpha - Agency Cash Service [redmine: #223896] 
	
	Sample:
		EXEC Age_CashMemberBankInfoSel @CustID = 1176093, @BankCode = 'KKR', @BankAccountNumber = '730918204765'
*/  
BEGIN 
	SET NOCOUNT ON;

	SELECT b.AccountNumber AS BankAccountNumber, b.BankId, a.BankCode
	FROM CashMemberBankAccount b WITH (NOLOCK)
		INNER JOIN CashBankList a WITH(NOLOCK) 
				ON b.BankID = a.BankID
	WHERE b.CustId = @CustID
		AND b.IsActive = 1
		AND ISNULL(@BankCode, a.BankCode) = a.BankCode
		AND ISNULL(@BankAccountNumber, b.AccountNumber) = b.AccountNumber
END
GO