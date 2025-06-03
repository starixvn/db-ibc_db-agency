/*<info serverAlias="DBSIC-bodb02" executers="asv_CashService,wsv_CashService,wsv_nap,wsv_alp,wsv_alpv,wsv_xnap" selecters="" viewers="" isFunction="0" isNested=""></info>*/
ALTER PROCEDURE dbo.Age_CashService_CashBalance_Sel
(
	@CustID		INT,
	@TotalCash	MONEY = 0 OUTPUT,
	-------- bonus wallet --------
	@BonusWalletFlag BIT = 0,
	@BonusAmount		MONEY = 0 OUTPUT
)
AS
/*
	Created: 20250502@Max		
	Task: Alpha - Agency Cash Service [redmine: #223896] 
	DB:  DBSIC-bodb02
		
	Revisions:
		- 20250502@Max: Alpha - Agency Cash Service [redmine: #223896] 

	Parameter's Explanation:	
*/ 
BEGIN
    SET NOCOUNT ON;

	EXEC dbo.Dot_BalanceMemberSel @CustID = @CustID, @Balance = @TotalCash OUTPUT, @BonusWalletFlag = @BonusWalletFlag, @Amount = @BonusAmount OUTPUT 
END;