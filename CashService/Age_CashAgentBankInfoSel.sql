/*<info serverAlias="DBCust-AgencyCashService" executers="asv_CashService,wsv_CashService" selecters="" viewers="" isFunction="0" isNested=""></info>*/
ALTER PROCEDURE dbo.Age_CashAgentBankInfoSel
	@AgentID		INT ,			-- SMA_ID Input
	@TransType		TINYINT,
	@IsManual		BIT = 1,
	@BankCode		VARCHAR(10) = NULL,
	@BankAccountNumber	VARCHAR(50) = NULL
AS 
/*  
	Created By: Helios
	Created Date: 2025-04-18
	Description: Agency Cash Service - Get SMA Bank Account 
	DB: DBCust.AgencyCashService
	
	Revisions:
		- 20250321@Helios: Agency Cash Service [Redmine: #223896]

	@TransType:
        1  : Deposit
        2  : Withdrawal

	Sample:
		exec Age_CashAgentBankInfoSel @AgentID=  1176086 , @TransType = 1, @IsManual = 1, @BankCode = 'KKR', @BankAccountNumber = '68204931752844'
		exec Age_CashAgentBankInfoSel @AgentID=  1176086 , @TransType = 2, @IsManual = 1, @BankCode = 'SCB', @BankAccountNumber = '1231249'
*/  
BEGIN
	SET NOCOUNT ON;
	DECLARE @TransactionTypeID TINYINT 
	SELECT @TransactionTypeID = CASE WHEN @TransType = 1 AND @IsManual = 1 THEN 1 --Manual Deposit
									 WHEN @TransType = 1 AND @IsManual = 0 THEN 2 --Auto Deposit
									 WHEN @TransType = 2 AND @IsManual = 1 THEN 3 --Manual Withdrawal
									 WHEN @TransType = 2 AND @IsManual = 0 THEN 4 --Auto Withdrawal
								END


	SELECT b.BankAccountNumber,b.BankID, a.BankCode
	FROM CashAgentBankAccount b WITH (NOLOCK)
		CROSS APPLY STRING_SPLIT(b.TransTypeList, ',') AS ts
		INNER JOIN CashBankList a WITH(NOLOCK) 
			ON b.BankID = a.BankID
	WHERE b.AgentID = @AgentID
		AND b.BankAccountStatus =  1 -- Enabled
		AND b.IsActive = 1
		AND ts.value = @TransactionTypeID
		AND ISNULL(@BankCode, a.BankCode) = a.BankCode
		AND ISNULL(@BankAccountNumber, b.BankAccountNumber) = b.BankAccountNumber
END
GO