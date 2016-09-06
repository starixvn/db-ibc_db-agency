USE [bodb02]
GO

ALTER PROCEDURE dbo.Age_Transfer_AllowIn24HoursCheck
	@CurrentDateTime	DATETIME
	, @Language			VARCHAR(2) = 'E'
	, @ErrMsg			NVARCHAR(2048) OUTPUT
	, @ErrCode			INT OUTPUT
AS
/*
	Created: 20160812@Patrick
	Task: Allow SMA to transfer in 24h or not
	DB: DBTXN/bodb02
	Revisions:
		- 20160906@Percy: Allow SMA to transfer in 24h or not - phase 2 [RedmineID: #62961]

*/
BEGIN
	SET NOCOUNT ON

	DECLARE @MBStartTime DATETIME, @MBEndTime DATETIME
		, @BUStartTime DATETIME, @BUEndTime DATETIME, @RemainingTime VARCHAR(50), @EndTime DATETIME

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
		DECLARE @Config_BUEndTime VARCHAR(50), @IsArchivingBet VARCHAR(1)

		SELECT @IsArchivingBet = VValue FROM dbo.SystemSettings WITH(NOLOCK) WHERE VName = 'isArchivingBet'
		SELECT @IsArchivingBet = ISNULL(@IsArchivingBet, '0')

		--set default value
		SELECT @Config_BUEndTime = CONVERT(VARCHAR(10), @CurrentDateTime, 121) + ' 20:35:00.000' -- 16:35:00 + 240 mins = 20:35:00

		--get BU's end time from config
		SELECT @Config_BUEndTime = VValue FROM dbo.SystemSettings WITH(NOLOCK) WHERE VName = 'schDataProcessingEndTime'

		--BU is still running now
		IF CONVERT(DATETIME, @Config_BUEndTime) > @CurrentDateTime
		BEGIN
			SELECT @EndTime = CONVERT(DATETIME, @Config_BUEndTime)
		END
		ELSE IF @IsArchivingBet = '1'
		BEGIN
			SELECT @EndTime = DATEADD(MINUTE, 15, @CurrentDateTime)
		END

		IF @EndTime IS NOT NULL
		BEGIN
			PRINT 'NOT OK'
			SELECT @ErrMsg = CASE @Language WHEN 'E' THEN 'To ensure the accuracy of data while being processed, all transfer transaction cannot be executed. The expected time to finish is {expandedtime} (GMT +8). We are sorry for any inconvenience caused.' --GMT+8
								ELSE dbo.f_Get_MsgNamebyMsgID(50010, @Language)	END
				, @ErrCode = 103
				, @RemainingTime = CONVERT(VARCHAR(8), DATEADD(HOUR, 12, @EndTime), 114) + ' ' + CONVERT(VARCHAR(10), DATEADD(HOUR, 12, @EndTime), 101) --convert time to GMT +8

			SELECT @ErrMsg = REPLACE(@ErrMsg, '{expandedtime}', @RemainingTime)
			RETURN
		END
	END
	ELSE --incase moving bet
	BEGIN
		DECLARE @Config_MBEndTime VARCHAR(50), @IsMovingBet VARCHAR(1), @TotalDays INT

		SELECT @IsMovingBet = VValue FROM dbo.SystemSettings WITH(NOLOCK) WHERE VName = 'isMovingBet'
		SELECT @IsMovingBet = ISNULL(@IsMovingBet, '0')

		DECLARE @MoveBetSchedule TABLE(ScheduleId TINYINT, MoveBetDay SMALLDATETIME)
		INSERT INTO @MoveBetSchedule(ScheduleId, MoveBetDay)
		EXEC dbo.Task_MoveBetsDayByScheduleSel

		SELECT @TotalDays = COUNT(1) FROM @MoveBetSchedule

		SET @TotalDays = ISNULL(@TotalDays, 0)
		IF @TotalDays = 0 --no move bet on that day
		BEGIN
			PRINT 'OK'
			RETURN
		END

		--set default value
		SELECT @Config_MBEndTime = CONVERT(VARCHAR(10), @CurrentDateTime, 121) + ' 18:30:00.000'
		SELECT @Config_MBEndTime = DATEADD(MINUTE, (60 * @TotalDays), @Config_MBEndTime)

		--get MB's end time from config
		SELECT @Config_MBEndTime = VValue FROM dbo.SystemSettings WITH(NOLOCK) WHERE VName = 'schDataProcessingEndTime'

		--MB is still running now
		IF CONVERT(DATETIME, @Config_MBEndTime) > @CurrentDateTime
		BEGIN
			SELECT @EndTime = CONVERT(DATETIME, @Config_MBEndTime)
		END
		ELSE IF @IsMovingBet = '1'
		BEGIN
			SELECT @EndTime = DATEADD(MINUTE, 15, @CurrentDateTime)
		END

		IF @EndTime IS NOT NULL
		BEGIN
			PRINT 'NOT OK'
			SELECT @ErrMsg = CASE @Language WHEN 'E' THEN 'To ensure the accuracy of data while being processed, all transfer transaction cannot be executed. The expected time to finish is {expandedtime} (GMT +8). We are sorry for any inconvenience caused.' --GMT+8
								ELSE dbo.f_Get_MsgNamebyMsgID(50010, @Language)	END
				, @ErrCode = 104
				, @RemainingTime = CONVERT(VARCHAR(8), DATEADD(HOUR, 12, @EndTime), 114) + ' ' + CONVERT(VARCHAR(10), DATEADD(HOUR, 12, @EndTime), 101) --convert time to GMT +8

			SELECT @ErrMsg = REPLACE(@ErrMsg, '{expandedtime}', @RemainingTime)
			RETURN
		END
	END
END
GO
GRANT EXECUTE ON [dbo].[Age_Transfer_AllowIn24HoursCheck] TO [bodbDownlineNet] AS [dbo]
GO
GRANT EXECUTE ON [dbo].[Age_Transfer_AllowIn24HoursCheck] TO [bodbDownlineNetView] AS [dbo]
GO
