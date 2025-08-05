/*<info serverAlias="DBSIC-bodb02" executers="wsv_alp" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_CustWinLimitBetReset_CashMember]
	@Custid				INT,
    @SubAccID           INT         = 0,
    @SubAccName         VARCHAR(30) = '',
    @UserID				INT,
    @IP                 VARCHAR(50) = '',
	@SettingStatus		TINYINT = 0
AS
/*
	Created: 20250716@Dave
	Task: Reset Potential Winning Limit for Cash Member
	DB: DBSIC-bodb02
	
	Revisions:
		- 20250705@Dave: Agency Cash Service - Customer Setting - Sprint 7 [Redmine: #233474]
		
	Parameter's Explanation:
		@SettingStatus: 0: Pro, 1: UAT
	
*/	
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE @OldAmount		MONEY = 0,
			@TrackingValue	NVARCHAR(200), 
			@TrackingValue2	NVARCHAR(200),
			@SP_START_TIME  DATETIME = GETDATE(),
			@Duration		INT;
	DECLARE @History TABLE (
		CustID		INT,
		Transid		INT,
		AdjToWin	MONEY,
		AdjWinLoss	MONEY,
		SportType	SMALLINT,
		Bettype		SMALLINT,
		ActionType	INT,
		RepUpdateTime DATETIME
	);
			
	IF NOT EXISTS (
		SELECT	TOP (1) 1
		FROM	dbo.CustWinLimitBet WITH (NOLOCK)
		WHERE	CustId = @Custid
			AND AccumWinLoss > 0
	)
	BEGIN
		RETURN;
	END;

	UPDATE b
	SET AccumWinLoss = 0,
		RepUpdateTime = [dbo].[f_GetDateTime2]()
	OUTPUT 
		DELETED.CustID, 
		NULL, 
		0, 
		-DELETED.AccumWinLoss, 
		NULL, 
		NULL, 
		100, 
		[dbo].[f_GetDateTime2]()
	INTO @History (CustID, Transid, AdjToWin, AdjWinLoss, SportType, Bettype, ActionType, RepUpdateTime)
	FROM dbo.CustWinLimitBet b WITH (ROWLOCK, UPDLOCK)
	WHERE b.CustID = @Custid AND b.AccumWinLoss > 0;

	INSERT INTO CustWinLimitBet_History (CustID, Transid, AdjToWin, AdjWinLoss, SportType, Bettype, ActionType, RepUpdateTime)
	SELECT CustID, Transid, AdjToWin, AdjWinLoss, SportType, Bettype, ActionType, RepUpdateTime
	FROM @History;

	SELECT TOP(1) @OldAmount = AdjWinLoss FROM @History;


	SET @TrackingValue2 = 
        '<Acc_CustWinLimitBetReset_CashMember ' +
        'CustID="'      + COALESCE(CAST(@Custid AS VARCHAR(20)), SPACE(1)) + '" ' +
        'ProductID="1" ' +
        'SubAccID="'    + COALESCE(CAST(@SubAccID AS VARCHAR(20)), SPACE(1)) + '" ' +
        'SubAccName="'  + COALESCE(@SubAccName, SPACE(1)) + '" ' +
        'SettingStatus="'+ COALESCE(CAST(@SettingStatus AS VARCHAR(5)), SPACE(1)) + '" ' +
        'WinAmount="' + COALESCE(CAST(@OldAmount AS VARCHAR(30)), SPACE(1)) + '" ' +
        'UserID="'      + COALESCE(CAST(@UserID AS VARCHAR(20)), SPACE(1)) + '" ' +
        'IP="'          + COALESCE(@IP, SPACE(1)) + '" ' +
        '/>';

    SET @TrackingValue = 
        '<Acc_CustWinLimitBetReset_CashMember ' +
        'CustID="'      + COALESCE(CAST(@Custid AS VARCHAR(20)), SPACE(1)) + '" ' +
        'ProductID="1" ' +
        'SubAccID="'    + COALESCE(CAST(@SubAccID AS VARCHAR(20)), SPACE(1)) + '" ' +
        'SubAccName="'  + COALESCE(@SubAccName, SPACE(1)) + '" ' +
        'SettingStatus="'+ COALESCE(CAST(@SettingStatus AS VARCHAR(5)), SPACE(1)) + '" ' +
        'WinAmount="0" ' +
        'UserID="'      + COALESCE(CAST(@UserID AS VARCHAR(20)), SPACE(1)) + '" ' +
        'IP="'          + COALESCE(@IP, SPACE(1)) + '" ' +
        '/>';

	SELECT @Duration = DATEDIFF(MILLISECOND, @SP_START_TIME, GETDATE());

    EXEC dbo.Acc_WriteLog_UserLog_RunSP_Wrapper
        @UserID = @UserID,
        @CustID = @Custid,
        @ActionID = 265002,
        @TrackingValue = @TrackingValue,
        @TrackingValue2 = @TrackingValue2,
        @duration = @Duration;


END
