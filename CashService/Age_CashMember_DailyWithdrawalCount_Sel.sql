/*<info serverAlias="DBSIC-bodb02" executers="asv_CashService,wsv_CashService,wsv_nap,wsv_alp,wsv_alpv,wsv_xnap" selecters="" viewers="" isFunction="0" isNested=""></info>*/
ALTER PROCEDURE Age_CashMember_DailyWithdrawalCount_Sel
	@CustID		INT = NULL,
	@WithdrawalCnt INT = 0 OUTPUT
AS 
/*
	Created: 20250423@Eden		
	Task: get withdrawalCount of Member on current Day
	DB:  DBSIC-bodb02
		
	Revisions:
		- 20250423@Eden: Alpha - Agency Cash Service [redmine: #223896] 

	Parameter's Explanation:	
	Sample:
		DECLARE @WithdrawalCnt INT,
				@CustID INT = 233657646
		EXEC Age_CashMember_DailyWithdrawalCount_Sel 
			 @CustID = @CustID
			,@WithdrawalCnt = @WithdrawalCnt OUTPUT

		SELECT @WithdrawalCnt AS WithdrawalCnt 
*/ 
BEGIN
	SET NOCOUNT ON

	SELECT @WithdrawalCnt = COUNT(1)
	FROM CashTransaction c WITH(NOLOCK) 
	WHERE custid = @CustID
		AND c.StatusId IN (2,4)-- Pending and Completed
		AND c.TransactionTypeID IN (3,4)--3:Manual Withdraw, 4:Auto Withdraw
		AND c.CreatedTime >= CONVERT(DATE, GETDATE()) 
		AND c.CreatedTime < CONVERT(DATE, GETDATE() + 1)
END
GO