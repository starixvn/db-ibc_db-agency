/*<info serverAlias="DBSIC-bodb02" executers="asv_CashService,wsv_CashService,wsv_nap,wsv_alp,wsv_alpv,wsv_xnap" selecters="" viewers="" isFunction="0" isNested=""></info>*/
ALTER PROCEDURE dbo.Age_CashService_CashBalance_Sel
(
	@CustID		INT,
	@TotalCash	MONEY = 0 OUTPUT,
	-------- bonus wallet --------
	@BonusWalletFlag BIT = 0,
	@BonusAmount		MONEY = 0 OUTPUT,
	@IsIncludeNetPos BIT = 0
)
AS
/*
	Created: 20250502@Max
	Task: Alpha - Agency Cash Service, , clone from Dot_BalanceMemberSel [redmine: #223896] 
	DB:  DBSIC-bodb02
		
	Revisions:
		- 20250502@Max: Alpha - Agency Cash Service [redmine: #223896]
		- 20250815@Eden: Alpha - Agency Cash Service - Sprint 8 [redmine: #235012] 

	Parameter's Explanation:	
*/ 
BEGIN
    SET NOCOUNT ON;

	SELECT @TotalCash = (cs.Balance + cc.Balance + co.Balance + ct.Balance) - (ds.Balance + dc.Balance + do.Balance + dt.Balance)
	FROM dbo.BalCreditSports				cs WITH(NOLOCK)	
		INNER JOIN dbo.BalCreditCasino 		cc WITH(NOLOCK)	ON cs.custid = cc.custid 
		INNER JOIN dbo.BalCreditOthers 		co WITH(NOLOCK) ON cs.custid = co.custid 
		INNER JOIN dbo.BalCreditTransfer	ct WITH(NOLOCK) ON cs.custid = ct.custid
		INNER JOIN dbo.BalDebitSports		ds ON cs.custid = ds.custid 
		INNER JOIN dbo.BalDebitCasino		dc ON cs.custid = dc.custid 
		INNER JOIN dbo.BalDebitOthers		do ON cs.custid = do.custid 
		INNER JOIN dbo.BalDebitTransfer		dt ON cs.custid = dt.custid 
	WHERE cs.custid = @custID 
	
	IF @IsIncludeNetPos = 1
	BEGIN
		SELECT @TotalCash=Isnull(@TotalCash,0)+isnull(sum(Credit-Debit),0) FROM BalNetPosition WHERE CustID=@custID
	END
	--BONUS checking balance
	IF(@BonusWalletFlag = 1)
	BEGIN
		SELECT 	@BonusAmount 		= SUM(ISNULL(bc.initBonus,0) + ISNULL(bc.Amount,0) + ISNULL(bc.LockedAmt,0) - ISNULL(bd.Amount,0))
				
		FROM dbo.BonusWalletCredit bc WITH(NOLOCK)
			INNER JOIN dbo.BonusWalletDebit bd
			ON bd.custID 	= bc.custID
			AND bd.bonusId 	= bc.bonusId
				
		WHERE bc.custID 	= @custID
			AND bc.statusId IN (4, 8) --is running, calculating bonus program
		
		GROUP BY bc.custId
	END
	--FINAL check balance info
	SELECT	
		@TotalCash 		= ISNULL(@TotalCash, 0) 
		, @BonusAmount 		= ISNULL(@BonusAmount, 0)
END;