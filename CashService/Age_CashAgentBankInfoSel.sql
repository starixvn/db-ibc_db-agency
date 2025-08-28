/*<info serverAlias="DBCust-AgencyCashService" executers="asv_CashService,wsv_CashService" selecters="" viewers="" isFunction="0" isNested=""></info>*/
ALTER PROCEDURE dbo.Age_CashAgentBankInfoSel
	@AgentID		INT ,			-- SMA_ID Input
	@TransType		TINYINT,
	@IsManual		BIT = 1,
	@BankCode		VARCHAR(10) = NULL,
	@BankAccountNumber	VARCHAR(100) = NULL
AS 
/*  
	Created By: Helios
	Created Date: 2025-04-18
	Description: Agency Cash Service - Get SMA Bank Account 
	DB: DBCust.AgencyCashService
	
	Revisions:
		- 20250321@Helios: Agency Cash Service [Redmine: #223896]
		- 20250623@Helios: Offer CashService - Get Bank Account Member [RedmineID: #231204]
		- 20250822@Helios: Agency Cash Service -Customer Setting Sprint 9 [redmine: #236430]

	@TransType:
        1  : Deposit
        2  : Withdrawal

	Sample:
		--call from Infor >> Member Bank Account
		exec Age_CashAgentBankInfoSel_UAT2 @AgentID=249550999,@TransType=1,@IsManual=NULL
		
		--call from Add deposit Withdrawal
		exec Age_CashAgentBankInfoSel_UAT2 @AgentID=249550999,@TransType=1
		
		--call from Add Manual Withdrawal
		exec Age_CashAgentBankInfoSel_UAT2 @AgentID=249550999,@TransType=2
		

*/  
BEGIN
	SET NOCOUNT ON;
	DECLARE @TransactionTypeID TINYINT;

	-- Determine TransactionTypeID, support both Manual & Auto Deposit if @TransType = 1 AND @IsManual IS NULL
	IF @TransType = 1 AND @IsManual IS NULL
	BEGIN
		SET @TransactionTypeID = NULL;
	END
	ELSE
	BEGIN
		SELECT @TransactionTypeID = CASE
							WHEN @TransType = 1 AND @IsManual = 1 THEN 1 -- Manual Deposit
							WHEN @TransType = 1 AND @IsManual = 0 THEN 2 -- Auto Deposit
							WHEN @TransType = 2 AND @IsManual = 1 THEN 3 -- Manual Withdrawal
							WHEN @TransType = 2 AND @IsManual = 0 THEN 4 -- Auto Withdrawal
						END;
	END

	-- Query bank account info for agent
	-- If @TransType = 1 AND @IsManual IS NULL, return both Manual & Auto Deposit (TransTypeList contains 1 or 2)
	SELECT
		DISTINCT
		b.BankAccountNumber    AS BankAccountNumber,
		b.BankID               AS BankID,
		a.BankCode             AS BankCode
	FROM dbo.CashAgentBankAccount b WITH (NOLOCK)
		CROSS APPLY STRING_SPLIT(b.TransTypeList, ',') AS ts
		INNER JOIN dbo.CashBankList a WITH (NOLOCK)
		ON b.BankID = a.BankID
	WHERE b.AgentID = @AgentID
		AND b.BankAccountStatus = 1      -- Only enabled accounts
		AND b.IsActive = 1
		AND (
			(@TransType = 1 AND @IsManual IS NULL AND ts.value IN ('1', '2')) -- Get BankAcc Agent: Just get Deposit (Manual & Auto)
			OR
			(@TransactionTypeID IS NOT NULL AND ts.value = @TransactionTypeID)	
		)
		AND ISNULL(@BankCode, a.BankCode) = a.BankCode
		AND ISNULL(@BankAccountNumber, b.BankAccountNumber) = b.BankAccountNumber;
END
