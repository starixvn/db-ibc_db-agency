USE [bodb02]
GO

ALTER PROCEDURE [dbo].[Age_MoveBetsProcessNotification]
AS
/*
	Creator: Percy
	Date: 2016-10-03
	DB: DBTXN.bodb02
	Task: Display notification during move bet process

	Revisions:
		- 20161027@Percy: Return output end time for move bets/balance up process [RedmineID: #64636]
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @CurrentDateTime DATETIME, @EndTime DATETIME, @FromDate DATETIME, @ToDate DATETIME, @MBBUEndTime DATETIME
		,@from			NVARCHAR(10) -- convert @fromdate
		,@to			NVARCHAR(10) -- convert @todate
		,@end			NVARCHAR(19) -- convert @endtime
		,@Content_EN	NVARCHAR(2048) -- English
		,@Content_CS	NVARCHAR(2048) -- Chinese Simplified
		,@Content_CH	NVARCHAR(2048) -- Chinese Traditional
		,@Content_TH	NVARCHAR(2048) -- Thai
		,@Content_JP	NVARCHAR(2048) -- Japan
		,@Content_KO	NVARCHAR(2048) -- Korea
		,@Content_VI	NVARCHAR(2048) -- Viet Nam

	SELECT  @CurrentDateTime = GETDATE()
	
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
			SELECT @FromDate = MIN(winlostdate), @ToDate = MAX(winlostdate) FROM dbo.Task_ArchiveDate WITH(NOLOCK)
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
		IF @TotalDays <> 0 -- have move bet on that day
		BEGIN
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
				SELECT @FromDate = MIN(MoveBetDay), @ToDate = MAX(MoveBetDay) FROM @MoveBetSchedule
			END
		END
	END

	IF @EndTime IS NOT NULL
	BEGIN
		SELECT	@from = CONVERT(NVARCHAR(10), @FromDate, 101)
				,@to = CONVERT(NVARCHAR(10), @ToDate, 101)
				,@end = CONVERT(VARCHAR(8), DATEADD(HOUR, 12, @EndTime), 114) + ' ' + CONVERT(VARCHAR(10), DATEADD(HOUR, 12, @EndTime), 101) --convert time to GMT +8
		SELECT @MBBUEndTime = CONVERT(DATETIME, @end)
		
		IF @FromDate = @ToDate -- 1 day
		BEGIN
			SELECT
				@Content_EN = MsgNameEN,
				@Content_CS = MsgNameCS,
				@Content_CH = MsgNameCT,
				@Content_TH = MsgNameTH,
				@Content_JP = MsgNameJP,
				@Content_KO = MsgNameKO,
				@Content_VI = MsgNameVI
			FROM dbo.MsgError WITH(NOLOCK) WHERE MsgID = 90012

			SELECT	@Content_EN = REPLACE(REPLACE(@Content_EN, N'[hh:mm:ss] [mm/dd/yyyy]', @end), N'[mm/dd/yyyy]', @from)
					,@Content_CS = REPLACE(REPLACE(@Content_CS, N'[hh:mm:ss] [mm/dd/yyyy]', @end), N'[mm/dd/yyyy]', @from)
					,@Content_CH = REPLACE(REPLACE(@Content_CH, N'[hh:mm:ss] [mm/dd/yyyy]', @end), N'[mm/dd/yyyy]', @from)
					,@Content_TH = REPLACE(REPLACE(@Content_TH, N'[hh:mm:ss] [mm/dd/yyyy]', @end), N'[mm/dd/yyyy]', @from)
					,@Content_JP = REPLACE(REPLACE(@Content_JP, N'[hh:mm:ss] [mm/dd/yyyy]', @end), N'[mm/dd/yyyy]', @from)
					,@Content_KO = REPLACE(REPLACE(@Content_KO, N'[hh:mm:ss] [mm/dd/yyyy]', @end), N'[mm/dd/yyyy]', @from)
					,@Content_VI = REPLACE(REPLACE(@Content_VI, N'[hh:mm:ss] [mm/dd/yyyy]', @end), N'[mm/dd/yyyy]', @from)


		END
		ELSE
		BEGIN
			SELECT
				@Content_EN = MsgNameEN,
				@Content_CS = MsgNameCS,
				@Content_CH = MsgNameCT,
				@Content_TH = MsgNameTH,
				@Content_JP = MsgNameJP,
				@Content_KO = MsgNameKO,
				@Content_VI = MsgNameVI
			FROM dbo.MsgError WITH(NOLOCK) WHERE MsgID = 90011

			SELECT	@Content_EN = REPLACE(@Content_EN, N'[hh:mm:ss] [mm/dd/yyyy]', @end)
					,@Content_CS = REPLACE(@Content_CS, N'[hh:mm:ss] [mm/dd/yyyy]', @end)
					,@Content_CH = REPLACE(@Content_CH, N'[hh:mm:ss] [mm/dd/yyyy]', @end)
					,@Content_TH = REPLACE(@Content_TH, N'[hh:mm:ss] [mm/dd/yyyy]', @end)
					,@Content_JP = REPLACE(@Content_JP, N'[hh:mm:ss] [mm/dd/yyyy]', @end)
					,@Content_KO = REPLACE(@Content_KO, N'[hh:mm:ss] [mm/dd/yyyy]', @end)
					,@Content_VI = REPLACE(@Content_VI, N'[hh:mm:ss] [mm/dd/yyyy]', @end)

			SELECT	@Content_EN = STUFF(@Content_EN, CHARINDEX('[mm/dd/yyyy]', @Content_EN, 1), 12, @from)
					,@Content_CS = STUFF(@Content_CS, CHARINDEX('[mm/dd/yyyy]', @Content_CS, 1), 12, @from)
					,@Content_CH = STUFF(@Content_CH, CHARINDEX('[mm/dd/yyyy]', @Content_CH, 1), 12, @from)
					,@Content_TH = STUFF(@Content_TH, CHARINDEX('[mm/dd/yyyy]', @Content_TH, 1), 12, @from)
					,@Content_JP = STUFF(@Content_JP, CHARINDEX('[mm/dd/yyyy]', @Content_JP, 1), 12, @from)
					,@Content_KO = STUFF(@Content_KO, CHARINDEX('[mm/dd/yyyy]', @Content_KO, 1), 12, @from)
					,@Content_VI = STUFF(@Content_VI, CHARINDEX('[mm/dd/yyyy]', @Content_VI, 1), 12, @from)

			SELECT	@Content_EN = STUFF(@Content_EN, CHARINDEX('[mm/dd/yyyy]', @Content_EN, 1), 12, @to)
					,@Content_CS = STUFF(@Content_CS, CHARINDEX('[mm/dd/yyyy]', @Content_CS, 1), 12, @to)
					,@Content_CH = STUFF(@Content_CH, CHARINDEX('[mm/dd/yyyy]', @Content_CH, 1), 12, @to)
					,@Content_TH = STUFF(@Content_TH, CHARINDEX('[mm/dd/yyyy]', @Content_TH, 1), 12, @to)
					,@Content_JP = STUFF(@Content_JP, CHARINDEX('[mm/dd/yyyy]', @Content_JP, 1), 12, @to)
					,@Content_KO = STUFF(@Content_KO, CHARINDEX('[mm/dd/yyyy]', @Content_KO, 1), 12, @to)
					,@Content_VI = STUFF(@Content_VI, CHARINDEX('[mm/dd/yyyy]', @Content_VI, 1), 12, @to)
		END
	END

	SELECT	@Content_EN AS Content_EN,
			@Content_CS AS Content_CS,
			@Content_CH AS Content_CH,
			@Content_TH AS Content_TH,
			@Content_JP AS Content_JP,
			@Content_KO AS Content_KO,
			@Content_VI AS Content_VI,
			@MBBUEndTime AS MBBUEndTime
END
GO
GRANT EXECUTE ON [dbo].[Age_MoveBetsProcessNotification] TO [bodbDownlineNet] AS [dbo]
GO
GRANT EXECUTE ON [dbo].[Age_MoveBetsProcessNotification] TO [bodbDownlineNetView] AS [dbo]
GO