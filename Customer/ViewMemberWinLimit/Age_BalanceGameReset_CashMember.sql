/*<info serverAlias="DBTXN-bodb02" executers="wsv_alp,wsv_alpv" viewers="" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[Age_BalanceGameReset_CashMember]
	@Custid				INT
	,@SportType 		SMALLINT
	,@BetType   		SMALLINT
	,@SettingStatus		TINYINT = 0
AS
/*
	Created: 20250705@Dave
	Task: Reset Balance Game WinLimit for Cash Member
	DB: DBTXN-bodb02
	
	Revisions:
		- 20250705@Dave: Agency Cash Service - Customer Setting - Sprint 7 [Redmine: #233474]
		
	Parameter's Explanation:
		@SettingStatus: 0: Pro, 1: UAT
	
*/	
BEGIN
	SET NOCOUNT ON;

	DECLARE @WinlostDate	SMALLDATETIME = GETDATE(),
			@isCashService	TINYINT;

	EXEC CustDB.dbo.Age_CashService_CustServiceTypeSel @CustID =  @Custid  , @ServiceType = @isCashService OUTPUT;
	
	IF @isCashService = 0
	BEGIN
		RETURN;
	END;

	IF EXISTS (
		SELECT TOP (1) 1
		FROM CustDB.dbo.f_CustSetting_SportBetTypeSettingMatrix (@SettingStatus) AS st
			INNER JOIN CustDB.dbo.f_CustSetting_ProductProfileCashSel(29, @SettingStatus, 0, 0) AS s
				ON st.SporttypeRefWinlossLimit = s.SportType 
				AND st.BettypeRefWinlossLimit = s.Bettype
				AND st.isLicensee = 0 AND st.Site = 'ALL'
			INNER JOIN DBCUST.CustDB.dbo.CustWinLossLimit_Member AS Cus WITH (NOLOCK)
				ON Cus.SportType = st.SporttypeRefWinlossLimit
				AND Cus.BetType = st.BettypeRefWinlossLimit
				AND Cus.CustId = @Custid
		WHERE st.SportType = @SportType
			AND st.bettype = @BetType
			AND st.isDeleted = 0
			AND Cus.IsAutoReset = 1
	)
	BEGIN
		RETURN;
	END;

	DELETE bal
	FROM dbo.BalanceCreditGame bal WITH (ROWLOCK)
	WHERE bal.custid = @Custid 
        AND bal.winlostdate <= @WinlostDate
        AND bal.bettype = @BetType;

	DELETE bal
	FROM dbo.BalanceDebitGame bal WITH (ROWLOCK)
	WHERE bal.custid = @Custid 
        AND bal.winlostdate <= @WinlostDate
        AND bal.bettype = @BetType;

END
GO
