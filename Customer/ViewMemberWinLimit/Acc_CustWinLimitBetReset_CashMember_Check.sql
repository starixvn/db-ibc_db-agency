/*<info serverAlias="DBCUST-CustDB" executers="wsv_alp" viewers="" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[Acc_CustWinLimitBetReset_CashMember_Check]
	@Custid				INT,
    @SubAccID           INT         	= 0,
    @SubAccName         VARCHAR(30)		= '',
    @UserID				INT,
	@SettingStatus		TINYINT 		= 0,
	@ErrCode            INT             = 0     OUTPUT,
	@ErrMsg             NVARCHAR(4000)  = ''    OUTPUT
AS
/*
	Created: 20250716@Dave
	Task: Reset Potential Winning Limit for Cash Member
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
        SET @ErrCode = 50040;
        SET @ErrMsg = 'Cannot reset Accumulated win Amount. This member is not a Cash member.';
		RETURN;
	END;

	IF EXISTS (
		SELECT	TOP (1) 1
		FROM 	dbo.f_CustSetting_ProductProfileCashSel(30, @SettingStatus, 0, 0) AS pp
				INNER JOIN dbo.CustPotentialWinLimit AS Cus WITH (NOLOCK)
					ON Cus.SportType = pp.SportType
					AND Cus.BetType = pp.BetType
		WHERE	Cus.CustID = @Custid
			AND Cus.IsAutoReset = 1
	)
	BEGIN
		SET @ErrCode = 50042;
		SET @ErrMsg = 'Cannot reset Accumulated win Amount. This member has an auto-reset potential winning limit.';
		RETURN;
	END;

	SET @ErrCode = 0;
	SET @ErrMsg = '';

END
