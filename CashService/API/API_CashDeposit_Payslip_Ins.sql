/*<info serverAlias="DBSIC-bodb02" executers="asv_CashService,wsv_CashService" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE dbo.API_CashDeposit_Payslip_Ins
(
    @CustID INT,
    @AgentID INT,
    @TransId BIGINT,
    @PaySlip VARBINARY(MAX),
    @IP VARCHAR(50) = '',
    @ErrCode INT = 0 OUTPUT,
    @ErrMsg VARCHAR(2000) = NULL OUTPUT,
    @ErrExtraInfo VARCHAR(MAX) = NULL OUTPUT
)
AS
/*
	Created: 20250624@Eden		
	Task: API Upload Payslip
	DB:  DBSIC-bodb02
		
	Revisions:
		- 20250624@Eden: Alpha - Agency Cash Service - Sprint 5 [redmine: #223896] 

	Parameter's Explanation:	
*/ 
BEGIN
    SET NOCOUNT ON;

    DECLARE @LogData VARCHAR(MAX)
		,@StatusId TINYINT
		,@TransactionTypeID TINYINT
		,@HadPaySlip BIT 

    DECLARE @tmp_LogData AS TABLE (
		 UserID	INT
		,CustID	INT
		,ActionID INT
		,TrackingValue	VARCHAR(MAX)
		,TrackingValue2	VARCHAR(MAX)
		,TrackingValueMask	VARCHAR(MAX)
		,TrackingValueMask2	VARCHAR(MAX)
	)

    -- Validate input: Check transaction exists and belongs to customer
    SELECT @StatusId = c.StatusId
		, @TransactionTypeID = c.TransactionTypeID
		, @HadPaySlip = CASE WHEN c.PaySlip IS NOT NULL THEN 1 ELSE 0 END
	FROM dbo.CashTransaction c WITH (NOLOCK)
		INNER JOIN custdb.dbo.vw_CashService_Customer ci WITH(NOLOCK) 
			ON c.CustId = ci.custid
	WHERE c.TransId = @TransId
		AND c.CustId = @CustID
		AND ci.recommend = @AgentID

	IF @TransactionTypeID IS NULL OR @PaySlip IS NULL
	BEGIN
		SELECT @ErrCode = 405, @ErrMsg = 'Invalid parameters.'
		RETURN
	END

	IF @StatusId <> 2 OR @HadPaySlip = 1 OR @TransactionTypeID NOT IN (1) --manual deposit
	BEGIN
		SELECT @ErrCode = 409, @ErrMsg = 'The transaction inserted failed. Please try again.'
		RETURN
	END

    BEGIN TRY
        EXEC dbo.Age_CashTransaction_Upd
            @TransId = @TransId,
            @PaySlip = @PaySlip,
			@IsUpdateOperatedTime = 0,
            @ErrCode = @ErrCode OUTPUT,
            @ErrMsg = @ErrMsg OUTPUT

        IF @ErrCode <> 0
        BEGIN
            SELECT @ErrExtraInfo = @ErrMsg
				, @ErrCode = 409
				, @ErrMsg = 'The transaction inserted failed. Please try again.'
            RETURN;
        END

        -- Ghi log
        SELECT @LogData = '<R custid="' + COALESCE(CAST(@CustID AS VARCHAR(20)), SPACE(1)) + '" '
                        + 'TransId="' + COALESCE(CAST(@TransId AS VARCHAR(20)), SPACE(1)) + '" ' 
						+ 'IP="'+ COALESCE(CAST(@IP AS VARCHAR(50)), SPACE(1)) + '" />'

        INSERT INTO @tmp_LogData (UserID, CustID, ActionID, TrackingValue)
		SELECT @CustID, @CustID, 310009, @LogData
    END TRY
    BEGIN CATCH
        SELECT @ErrCode = 409
			, @ErrMsg = 'The transaction inserted failed. Please try again.'
			, @ErrExtraInfo = ERROR_MESSAGE();

        RETURN;
    END CATCH

    -- Return log dataset
    SELECT * FROM @tmp_LogData;
    SET NOCOUNT OFF;
END
GO
