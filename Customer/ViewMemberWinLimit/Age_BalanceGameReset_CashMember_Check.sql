/*<info serverAlias="DBCUST-CustDB" executers="wsv_alp" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Age_BalanceGameReset_CashMember_Check]
    @Custid				INT,
    @ProductID          TINYINT,
    @SportType 			SMALLINT,
    @BetType   			SMALLINT,
	@SubAccID           INT             = 0,
    @SubAccName         VARCHAR(30)     = '',
	@UserID             INT,
    @SettingStatus      TINYINT         = 0,
	@ErrCode            INT             = 0     OUTPUT,
	@ErrMsg             NVARCHAR(4000)  = ''    OUTPUT
AS
/*
	Created: 20250705@Dave
	Task: Reset Balance Game Win Amount for Cash Member
	DB: DBCUST-CustDB
	
	Revisions:
		- 20250705@Dave: Agency Cash Service - Customer Setting - Sprint 7 [Redmine: #233474]
		
	Parameter's Explanation:
		@SettingStatus: 0: Pro, 1: UAT
	
*/	
BEGIN
	SET NOCOUNT ON;

	DECLARE @isCashService	TINYINT;

	EXEC dbo.Age_CashService_CustServiceTypeSel @CustID =  @Custid  , @ServiceType = @isCashService OUTPUT;
	
	IF @isCashService = 0
	BEGIN
        SET @ErrCode = 50039;
        SET @ErrMsg = 'Cannot reset Current win Amount. This member is not a Cash member.';
		RETURN;
	END;

	IF EXISTS (
		SELECT TOP (1) 1
		FROM dbo.f_CustSetting_SportBetTypeSettingMatrix (@SettingStatus) AS st
			INNER JOIN dbo.f_CustSetting_ProductProfileCashSel(29, @SettingStatus, 0, 0) AS s
				ON st.SporttypeRefWinlossLimit = s.SportType 
				AND st.BettypeRefWinlossLimit = s.Bettype
				AND st.isLicensee = 0 AND st.Site = 'ALL'
			INNER JOIN dbo.CustWinLossLimit_Member AS Cus WITH (NOLOCK)
				ON Cus.SportType = st.SporttypeRefWinlossLimit
				AND Cus.BetType = st.BettypeRefWinlossLimit
				AND Cus.CustId = @Custid
		WHERE st.SportType = @SportType
			AND st.bettype = @BetType
			AND st.isDeleted = 0
			AND Cus.IsAutoReset = 1
	)
	BEGIN
		SET @ErrCode = 50041;
		SET @ErrMsg = 'Cannot reset Current win Amount. This member has an auto-reset win/loss limit for this Product.';
		RETURN;
	END;

	SET @ErrCode = 0;
	SET @ErrMsg = '';

END
GO
