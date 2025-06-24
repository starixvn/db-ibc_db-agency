/*<info serverAlias="DBCust-AgencyCashService" executers="asv_CashService,wsv_CashService" selecters="" viewers="" isFunction="0" isNested=""></info>*/
ALTER PROCEDURE dbo.Age_CashWithdrawal_LimitAmtSel
	@CustID INT,
	@UplineID INT,
	@IsMemberSite BIT = 0,
	@ProviderID SMALLINT = 0,
	@PaymentMethodID SMALLINT = 0,
	@WithdrawalCnt INT = NULL, --Get From CashTransaction History
	@DailyWithdrawalCnt_Setting SMALLINT = NULL OUTPUT,--Limit Get From Setting
	@MinAmt	MONEY = NULL OUTPUT,
	@MaxAmt	MONEY = NULL  OUTPUT,
	@WithdrawalLimitCnt INT = 0 OUTPUT --The number of withdrawals remaining today
AS 
/*  
	Created : 20250423@Eden
	Description: get range value can withdrawal for Member (MinAmt - MaxAmt)
	DB: DBCust.CustDB
	
	Revisions:
		- 20250423@Eden: Alpha - Agency Cash Service [redmine: #223896] 
		- 20250616@Eden: Alpha - Agency Cash Service - Sprint 4 [redmine: #223896] 

	Parameter's Explanation:	

	Sample:
		DECLARE @MinAmt	MONEY ,
			@MaxAmt	MONEY,
			@WithdrawalLimitCnt INT
		EXEC Age_CashWithdrawal_LimitAmtSel 
			 @CustID = 1176093
			,@UplineID = 1176086
			--,@ProviderID = 1
			--,@PaymentMethodID = 6
			,@IsMemberSite = 1
			,@WithdrawalCnt = 7
			,@MinAmt = @MinAmt OUTPUT
			,@MaxAmt = @MaxAmt OUTPUT
			,@WithdrawalLimitCnt = @WithdrawalLimitCnt OUTPUT

		SELECT @MinAmt AS MinAmt,@MaxAmt AS MaxAmt, @WithdrawalLimitCnt AS WithdrawalLimitCnt
*/  
BEGIN
	SET NOCOUNT ON;
	
	IF @IsMemberSite = 0 -- Agency site
	BEGIN
		IF @ProviderID <> 0
		BEGIN
			SELECT @MinAmt = pm.MinAmount, @MaxAmt = pm.MaxAmount
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
			WHERE pm.AgentID = @UplineID
				AND pm.PaymentMethodID = @PaymentMethodID
				AND pm.ProviderID = @ProviderID
				AND pm.PaymentMethodEnable = 1 --Method Enabled
				AND pm.TransactionType = 2 --withdrawal	
		END
	END
	ELSE IF @IsMemberSite = 1 --Limit by agent config
	BEGIN
		SELECT @MinAmt = 0, @MaxAmt = NULL

		SELECT @MinAmt = MinPerWithdrawal, @MaxAmt = MaxPerWithdrawal
		FROM CashAgentBankAccountLimit l WITH(NOLOCK) 
		WHERE l.AgentID = @UplineID

		SELECT @DailyWithdrawalCnt_Setting = DailyWithdrawalCount 
		FROM CashAgentManagement WITH(NOLOCK)
		WHERE AgentId = @UplineID

		SELECT @WithdrawalLimitCnt = IIF(ISNULL(@DailyWithdrawalCnt_Setting,0) - ISNULL(@WithdrawalCnt,0) > 0, ISNULL(@DailyWithdrawalCnt_Setting,0) - ISNULL(@WithdrawalCnt,0), 0)
	END
END
GO