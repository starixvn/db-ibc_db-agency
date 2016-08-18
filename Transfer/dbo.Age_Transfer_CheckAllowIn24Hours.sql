USE bodb02
GO

ALTER PROCEDURE dbo.Age_Transfer_AllowIn24HoursCheck @CurrentDateTime DATETIME
	--, @IsMultipleTransfer BIT = 0
	, @Language VARCHAR(2) = 'E'
	, @ErrMsg NVARCHAR(2048) OUTPUT
	, @ErrCode INT OUTPUT
AS
/*
	Created: 20160812@Patrick
	Task: Allow SMA to transfer in 24h or not
	DB: DBTXN/bodb02
	Revisions:

*/
BEGIN
	SET NOCOUNT ON

	DECLARE @MBStartTime DATETIME, @MBEndTime DATETIME
		, @BUStartTime DATETIME, @BUEndTime DATETIME, @RemainingTime VARCHAR(50)

	SELECT @ErrCode = 0, @ErrMsg = ''

	--check allow time
	DECLARE @IsLimitTransferTime BIT
	SET @IsLimitTransferTime = 0 --ignore this case at this time. we reserve this case for rollback or restrict time to transfer in the future
	IF (@IsLimitTransferTime = 1 AND DATEPART(HOUR, @CurrentDateTime) BETWEEN 12 AND 23) --GMT-4
	BEGIN
		SELECT @ErrMsg = CASE @Language WHEN 'E' THEN 'Sorry, you can only transfer from 12pm to 11:59pm.' --GMT+8
							ELSE dbo.f_Get_MsgNamebyMsgID(50001, @Language)	END
			, @ErrCode = 102
		RETURN
	END
	
	--check BU day
	IF DATEPART(WEEKDAY, @CurrentDateTime) = 6
	BEGIN
		DECLARE @Config_BUStartTime VARCHAR(12), @Config_BUDuration INT /*minutes*/, @IsArchivingBet BIT

		SELECT @IsArchivingBet = VValue
		FROM DBACC.bodb02.dbo.SystemSettings WITH(NOLOCK)
		WHERE VName = 'isArchivingBet'

		SET @IsArchivingBet = ISNULL(@IsArchivingBet, 0)
		--IF @IsArchivingBet = 0 AND @IsMultipleTransfer = 0
		--BEGIN
		--	PRINT 'OK'
		--	RETURN
		--END

		--set default value
		SELECT @Config_BUStartTime = '16:35:00', @Config_BUDuration = 240

		--get BU's start time from config
		SELECT @Config_BUStartTime = VValue
		FROM dbo.SystemSettings WITH(NOLOCK)
		WHERE VName = 'schMovingArchivingBetStartTime'
		
		--get BU's duration from config
		SELECT @Config_BUDuration = CAST(ISNULL(VValue, '240') AS INT)
		FROM dbo.SystemSettings WITH(NOLOCK)
		WHERE VName = 'schMovingArchivingBetDuration'

		SELECT @BUStartTime = CONVERT(DATETIME, CONVERT(VARCHAR(10), @CurrentDateTime, 121) + ' ' + @Config_BUStartTime)
		SELECT @BUEndTime = DATEADD(MINUTE, @Config_BUDuration, @BUStartTime)
		--BU is still running now
		IF @IsArchivingBet = 1 AND @BUEndTime <= @CurrentDateTime
			SET @BUEndTime = DATEADD(MINUTE, 15, @CurrentDateTime)

		--subtract 30 minutes in case multiple transfer
		--IF @IsMultipleTransfer = 1
		SET @BUStartTime = DATEADD(MINUTE, -30, @BUStartTime)

		--SELECT @BUStartTime as '@BUStartTime', @BUEndTime as '@BUEndTime'
		IF @IsArchivingBet = 1 OR @CurrentDateTime BETWEEN @BUStartTime AND @BUEndTime
		BEGIN
			PRINT 'NOT OK'
			SELECT @ErrMsg = CASE @Language WHEN 'E' THEN 'To ensure the accuracy of data while being processed, all transfer transaction cannot be executed. The expected time to finish is {expandedtime} (GMT +8). We are sorry for any inconvenience caused.' --GMT+8
								ELSE dbo.f_Get_MsgNamebyMsgID(50010, @Language)	END
				, @ErrCode = 103
				, @RemainingTime = CONVERT(VARCHAR(8), DATEADD(HOUR, 12, @BUStartTime), 114) + ' ' + CONVERT(VARCHAR(10), DATEADD(HOUR, 12, @BUStartTime), 101) --convert time to GMT +8

			SET @ErrMsg = REPLACE(@ErrMsg, '{expandedtime}', @RemainingTime)
			RETURN
		END
	END
	ELSE --incase moving bet
	BEGIN
		DECLARE @Config_MBStartTime VARCHAR(12), @Config_MBDuration INT /*minutes*/, @IsMovingBet BIT, @TotalDays TINYINT

		SELECT @IsMovingBet = VValue
		FROM DBACC.bodb02.dbo.SystemSettings WITH(NOLOCK)
		WHERE VName = 'isMovingBet'

		--SET @IsMovingBet = ISNULL(@IsMovingBet, 0)
		--IF @IsMovingBet = 0 AND @IsMultipleTransfer = 0
		--BEGIN
		--	PRINT 'OK'
		--	RETURN
		--END

		DECLARE @MoveBetSchedule TABLE(ScheduleId TINYINT, MoveBetDay SMALLDATETIME)
		INSERT INTO @MoveBetSchedule(ScheduleId, MoveBetDay)
		EXEC dbo.Task_MoveBetsDayByScheduleSel

		SELECT @TotalDays = COUNT(1)
		FROM @MoveBetSchedule

		SET @TotalDays = ISNULL(@TotalDays, 0)
		IF @TotalDays = 0 --no move bet on that day
		BEGIN
			PRINT 'OK'
			RETURN
		END

		--set default value
		SELECT @Config_MBStartTime = '18:30:00', @Config_MBDuration = 60

		--get MB's start time from config
		SELECT @Config_MBStartTime = VValue
		FROM dbo.SystemSettings WITH(NOLOCK)
		WHERE VName = 'schMovingBetStartTime'
		
		--get MB's duration from config
		SELECT @Config_MBDuration = CAST(ISNULL(VValue, '60') AS INT)
		FROM dbo.SystemSettings WITH(NOLOCK)
		WHERE VName = 'schMovingBetDuration'

		SELECT @MBStartTime = CONVERT(DATETIME, CONVERT(VARCHAR(10), @CurrentDateTime, 121) + ' ' + @Config_MBStartTime)
		SELECT @MBEndTime = DATEADD(MINUTE, (@Config_MBDuration * @TotalDays), @MBStartTime)

		--MB is still running now
		IF @IsMovingBet = 1 AND @MBEndTime <= @CurrentDateTime
			SET @MBEndTime = DATEADD(MINUTE, 15, @CurrentDateTime)

		--subtract 30 minutes in case multiple transfer
		--IF @IsMultipleTransfer = 1
		SET @MBStartTime = DATEADD(MINUTE, -30, @MBStartTime)

		IF @IsMovingBet = 1 OR @CurrentDateTime BETWEEN @MBStartTime AND @MBEndTime
		BEGIN
			PRINT 'NOT OK'
			SELECT @ErrMsg = CASE @Language WHEN 'E' THEN 'To ensure the accuracy of data while being processed, all transfer transaction cannot be executed. The expected time to finish is {expandedtime} (GMT +8). We are sorry for any inconvenience caused.' --GMT+8
								ELSE dbo.f_Get_MsgNamebyMsgID(50010, @Language)	END
				, @ErrCode = 104
				, @RemainingTime = CONVERT(VARCHAR(8), DATEADD(HOUR, 12, @MBEndTime), 114) + ' ' + CONVERT(VARCHAR(10), DATEADD(HOUR, 12, @MBEndTime), 101) --convert time to GMT +8

			SET @ErrMsg = REPLACE(@ErrMsg, '{expandedtime}', @RemainingTime)
			RETURN
		END
	END
END
GO
GRANT EXECUTE ON [dbo].[Age_Transfer_AllowIn24HoursCheck] TO [bodbDownlineNet] AS [dbo]
GO
GRANT EXECUTE ON [dbo].[Age_Transfer_AllowIn24HoursCheck] TO [bodbDownlineNetView] AS [dbo]
GO
