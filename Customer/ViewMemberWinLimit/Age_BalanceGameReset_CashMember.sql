/*<info serverAlias="DBSIC-bodb02" executers="wsv_alp" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Age_BalanceGameReset_CashMember]
    @Custid				INT,
    @ProductID          TINYINT,
    @SportType 			SMALLINT,
    @BetType   			SMALLINT,
	@SubAccID           INT         = 0,
    @SubAccName         VARCHAR(30) = '',
	@UserID             INT,
	@IP                 VARCHAR(50) = '',
    @SettingStatus      TINYINT     = 0
AS
/*
	Created: 20250705@Dave
	Task: Reset Balance Game Win Amount for Cash Member
	DB: DBSIC-bodb02
	
	Revisions:
		- 20250705@Dave: Agency Cash Service - Customer Setting - Sprint 7 [Redmine: #233474]
		
	Parameter's Explanation:
		@SettingStatus: 0: Pro, 1: UAT
	
*/	
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE @WinlostDate	SMALLDATETIME = GETDATE(),
            @SP_START_TIME  DATETIME = GETDATE(),
            @Duration		INT;

    DECLARE @DeletedCredit TABLE (amount MONEY);
    DECLARE @DeletedDebit TABLE (amount MONEY);

    DELETE FROM dbo.BalanceCreditGame WITH (ROWLOCK)
    OUTPUT DELETED.Balance INTO @DeletedCredit(amount)
    WHERE custid = @Custid 
        AND winlostdate <= @WinlostDate
        AND bettype = @BetType;

    DELETE FROM dbo.BalanceDebitGame WITH (ROWLOCK)
    OUTPUT DELETED.Balance INTO @DeletedDebit(amount)
    WHERE custid = @Custid 
        AND winlostdate <= @WinlostDate
        AND bettype = @BetType;

    DECLARE @SumCredit MONEY = (SELECT ISNULL(SUM(amount), 0) FROM @DeletedCredit);
    DECLARE @SumDebit MONEY = (SELECT ISNULL(SUM(amount), 0) FROM @DeletedDebit);

    DECLARE @TrackingValue2 NVARCHAR(MAX), @TrackingValue NVARCHAR(1000);

    SET @TrackingValue2 = 
        '<Age_BalanceGameReset_CashMember ' +
        'CustID="'      + COALESCE(CAST(@Custid AS VARCHAR(20)), SPACE(1)) + '" ' +
        'SportType="'   + COALESCE(CAST(@SportType AS VARCHAR(10)), SPACE(1)) + '" ' +
        'BetType="'     + COALESCE(CAST(@BetType AS VARCHAR(10)), SPACE(1)) + '" ' +
        'ProductID="'   + COALESCE(CAST(@ProductID AS VARCHAR(10)), SPACE(1)) + '" ' +
        'SettingStatus="'+ COALESCE(CAST(@SettingStatus AS VARCHAR(5)), SPACE(1)) + '" ' +
        'WinAmount="'   + COALESCE(CAST(@SumCredit - @SumDebit AS VARCHAR(30)), SPACE(1)) + '" ' +
        'SumCredit="'   + COALESCE(CAST(@SumCredit AS VARCHAR(30)), SPACE(1)) + '" ' +
        'SumDebit="'    + COALESCE(CAST(@SumDebit AS VARCHAR(30)), SPACE(1)) + '" ' +
        'UserID="'      + COALESCE(CAST(@UserID AS VARCHAR(20)), SPACE(1)) + '" ' +
        'IP="'          + COALESCE(@IP, SPACE(1)) + '" ' +
        'SubAccID="'    + COALESCE(CAST(@SubAccID AS VARCHAR(20)), SPACE(1)) + '" ' +
        'SubAccName="'  + COALESCE(@SubAccName, SPACE(1)) + '" ' +
        '/>';

    SET @TrackingValue = 
        '<Age_BalanceGameReset_CashMember ' +
        'CustID="'      + COALESCE(CAST(@Custid AS VARCHAR(20)), SPACE(1)) + '" ' +
        'SportType="'   + COALESCE(CAST(@SportType AS VARCHAR(10)), SPACE(1)) + '" ' +
        'BetType="'     + COALESCE(CAST(@BetType AS VARCHAR(10)), SPACE(1)) + '" ' +
        'ProductID="'   + COALESCE(CAST(@ProductID AS VARCHAR(10)), SPACE(1)) + '" ' +
        'SettingStatus="'+ COALESCE(CAST(@SettingStatus AS VARCHAR(5)), SPACE(1)) + '" ' +
        'WinAmount="'   + COALESCE('0', SPACE(1)) + '" ' +
        'SumCredit="'   + COALESCE('0', SPACE(1)) + '" ' +
        'SumDebit="'    + COALESCE('0', SPACE(1)) + '" ' +
        'UserID="'      + COALESCE(CAST(@UserID AS VARCHAR(20)), SPACE(1)) + '" ' +
        'IP="'          + COALESCE(@IP, SPACE(1)) + '" ' +
        'SubAccID="'    + COALESCE(CAST(@SubAccID AS VARCHAR(20)), SPACE(1)) + '" ' +
        'SubAccName="'  + COALESCE(@SubAccName, SPACE(1)) + '" ' +
        '/>';

    SELECT @Duration = DATEDIFF(MILLISECOND, @SP_START_TIME, GETDATE());

    EXEC dbo.Acc_WriteLog_UserLog_RunSP_Wrapper
        @UserID = @UserID,
        @CustID = @Custid,
        @ActionID = 265001,
        @TrackingValue = @TrackingValue,
        @TrackingValue2 = @TrackingValue2,
        @Duration = @Duration
        ;

END
GO
