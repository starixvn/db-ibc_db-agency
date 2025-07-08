/*<info serverAlias="DBSIC-bodb02" executers="wsv_alp,wsv_alpv" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_CustWinLimitBetReset_CashMember]
	@Custid				INT
	,@SettingStatus		TINYINT = 0
AS
/*
	Created: 20250716@Dave
	Task: Reset Potential Winning Limit for Cash Member
	DB: DBTXN-bodb02
	
	Revisions:
		- 20250705@Dave: Agency Cash Service - Customer Setting - Sprint 6 [Redmine: #233474]
		
	Parameter's Explanation:
		@SettingStatus: 0: Pro, 1: UAT
	
*/	
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE @isCashService	TINYINT;

	EXEC DBCUST.CustDB.dbo.Age_CashService_CustServiceTypeSel @CustID =  @Custid  , @ServiceType = @isCashService OUTPUT;

	IF @isCashService = 0
	BEGIN
		RETURN;
	END;

	IF NOT EXISTS (
		SELECT	TOP (1) 1
		FROM 	CustDB.dbo.CustPotentialWinLimit AS Cus WITH (NOLOCK)
		WHERE	Cus.CustID = @Custid
			AND Cus.Bettype = 0
			AND Cus.Sporttype = 0
			AND Cus.IsAutoReset = 0
			AND Cus.PotentialWinLimit > 0
		/*
		SELECT	TOP (1) 1
		FROM 	CustDB.dbo.f_CustSetting_ProductProfileCashSel(30, @SettingStatus, 0, 0) AS pp
				INNER JOIN CustDB.dbo.CustPotentialWinLimit AS Cus WITH (NOLOCK)
					ON Cus.SportType = pp.SportType
					AND Cus.BetType = pp.BetType
		WHERE	Cus.CustID = @Custid
			AND Cus.IsAutoReset = 0
			AND Cus.PotentialWinLimit > 0
		*/
	)
	BEGIN
		RETURN;
	END;

	IF NOT EXISTS (
		SELECT	TOP (1) 1
		FROM	dbo.CustWinLimitBet WITH (NOLOCK)
		WHERE	CustId = @Custid
			AND AccumWinLoss > 0
	)
	BEGIN
		RETURN;
	END;


    EXECUTE dbo.Acc_CustWinLimitBet_Reset @ListCustId = @Custid;

END
