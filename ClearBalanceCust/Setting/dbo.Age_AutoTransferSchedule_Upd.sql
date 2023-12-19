/*<info serverAlias="DBCUST-CustDB" executers="bodbDownlineNet" isFunction="0" isNested="0"></info>*/
CREATE PROCEDURE [dbo].[Age_AutoTransferSchedule_Upd]
	@FromCustId				INT,
	@ToCustId				INT,
	@AutoTransferSchedule	VARCHAR(20),
	@Old_TransferOption		VARCHAR(8)='',
	@IsAutoJobRunning		BIT,
	@Creator				INT,
	@SubAccId				INT,
	@Language				VARCHAR(2)		= 'E',
	@IP						VARCHAR(45)		= '',
	@ErrCode				INT				= 0		OUTPUT,
	@ErrMsg					NVARCHAR(4000)	= ''	OUTPUT
AS
/*
	Created:20231025@Luke
	Task: Alpha - Enhance auto transfer function (phase 2)
	DB: DBCUST-CustDB

	Revisions:
		- 20231025@Luke: Alpha - Enhance auto transfer function (phase 2) [Redmine: #195135]

	Param's Explanation:
		• @FromCustID: The direct UplineID
		• @ToCustID: The CustID to be adjusted auto transfer schedule
		• @AutoTransferSchedule: Schedule for auto transfer
*/
BEGIN
	SET NOCOUNT ON
	DECLARE @StartRun	DATETIME
			,@EndRun	DATETIME
			,@Duration	INT
	SET @StartRun = GETDATE()

	DECLARE @username NVARCHAR(50)
			,@tomorrow DATE = DATEADD(DAY, 1, GETDATE())
	SELECT @username = username 
	FROM custinfo WITH (NOLOCK)
	WHERE custid = @ToCustId

	--Check if auto transfer is in progress
	IF @IsAutoJobRunning = 1
	BEGIN
		SELECT @ErrCode	= 0, 
				@ErrMsg	= CASE WHEN @Language = 'E' THEN REPLACE('Auto Transfer Schedule for account <username> has been successfully updated. However, this process is taking place, and the account will be queued for Auto Transfer at the next scheduled time based on its Auto Transfer Schedule. ', '<username>', @username)
								ELSE REPLACE([dbo].[f_Get_MsgNamebyMsgID](50036,@Language), '<username>', @username)
							END 
	END

	DECLARE @New_TransferOption				TINYINT
			,@Old_TransferOption_numeric	TINYINT
			,@roleid						TINYINT
			,@IsAllDayBalanceTransfer		BIT = 0

	SELECT @roleid = roleid
	FROM custinfo WITH (NOLOCK)
	WHERE custid = @FromCustId
	
	IF @roleid = 4
	BEGIN
		SELECT @IsAllDayBalanceTransfer = IsAllDayBalTransfer
		FROM CustSuper WITH (NOLOCK)
		WHERE custid = @FromCustId
	END
	IF @roleid = 3
	BEGIN
		SELECT @New_TransferOption = TransferOption
		FROM CustMaster WITH (NOLOCK)
		WHERE custid = @FromCustId

		SELECT @IsAllDayBalanceTransfer = IsAllDayBalTransfer
		FROM CustMaster WITH (NOLOCK)
		WHERE custid = @FromCustId
	END
	ELSE IF @roleid = 2
	BEGIN
		SELECT @New_TransferOption = TransferOption
		FROM CustAgent WITH (NOLOCK)
		WHERE custid = @FromCustId

		SELECT @IsAllDayBalanceTransfer = IsAllDayBalTransfer
		FROM CustMaster cm WITH (NOLOCK)
			INNER JOIN custinfo c WITH (NOLOCK) ON cm.custid = c.mrecommend
		WHERE c.custid = @FromCustId
	END

	--Check if upline is on ADBT
	IF @IsAllDayBalanceTransfer = 1
	BEGIN
		SELECT @ErrCode = 108,
				@ErrMsg = CASE WHEN @Language = 'E' THEN 'Your account has been enabled for All Day Balance Transfer. The page will be automatically refreshed.' 
								ELSE [dbo].[f_Get_MsgNamebyMsgID](50037,@Language) 
								END
		RETURN
	END

	SELECT @Old_TransferOption_numeric = dbo.f_Binary_Decimal(@Old_TransferOption)

	--Check if Transfer Condition of Master/Agent already changed
	IF @Old_TransferOption_numeric <> @New_TransferOption AND @roleid IN (2,3) 
	BEGIN
		SELECT @ErrCode = 105,
				@ErrMsg = CASE WHEN @Language = 'E' THEN 'Your Transfer Condition was changed by upline. The page will be automatically refreshed.' 
								ELSE [dbo].[f_Get_MsgNamebyMsgID](50035,@Language) 
								END
		RETURN
	END

	DECLARE @AutoTransferSchedule_numeric		TINYINT
			,@Old_AutoTransferSchedule_numeric	TINYINT
			,@TrackingValue					NVARCHAR(3000)
			,@TrackingValue2				NVARCHAR(3000)
	SET	@AutoTransferSchedule_numeric = dbo.f_AutoTransferSchedule_CharToNumeric(@AutoTransferSchedule)

	SELECT TOP 1 @Old_AutoTransferSchedule_numeric = ScheduleOption
	FROM dbo.Age_ClearBalanceCust_Setting WITH (NOLOCK)
	WHERE FromCustID = @FromCustId AND ToCustID = @ToCustId

	IF @@ROWCOUNT = 0
	BEGIN
		SELECT @ErrCode = 106,
				@ErrMsg	= CASE WHEN @Language = 'E' THEN 'This account has been disabled Auto Transfer:' 
								ELSE [dbo].[f_Get_MsgNamebyMsgID](50033,@Language) 
								END + ' ' + @username
		RETURN
	END
	ELSE IF @AutoTransferSchedule_numeric = @Old_AutoTransferSchedule_numeric
		RETURN
	ELSE
	BEGIN
		UPDATE c
		SET c.ScheduleOption = @AutoTransferSchedule_numeric, 
			c.EffectiveDate = CASE WHEN @IsAutoJobRunning = 1 THEN @tomorrow ELSE EffectiveDate END
		FROM dbo.Age_ClearBalanceCust_Setting c WITH (ROWLOCK, UPDLOCK)
		WHERE FromCustID = @FromCustId AND ToCustID = @ToCustId

		SELECT @TrackingValue = '<Age_AutoTransferSchedule_Upd FromCustId="' + COALESCE(CAST(@FromCustId AS VARCHAR(20)),SPACE(1)) +'" '+
								'ToCustID="' +  COALESCE(CAST(@ToCustId AS VARCHAR(20)),SPACE(1)) +'" '+
								'Schedule="' + COALESCE(CAST(@AutoTransferSchedule AS VARCHAR(20)), SPACE(1)) +'" '+
								'SubAccId="'+ coalesce(cast(@SubAccID as varchar(20)),space(1)) + '" '+
								'Language="' + COALESCE(CAST(@Language AS VARCHAR(2)),SPACE(1)) +'" '+
								'IP="' + COALESCE(CAST(@IP AS NVARCHAR(20)),SPACE(1)) +'" '+
								'ErrCode="' + COALESCE(CAST(@ErrCode AS VARCHAR(10)),SPACE(1)) +'" '+
								'ErrMsg="' + COALESCE(CAST(@ErrMsg AS NVARCHAR(3000)),SPACE(1)) +'"'+ '/>'

		SELECT @TrackingValue2 = '<Age_AutoTransferSchedule_Upd FromCustId="' + COALESCE(CAST(@FromCustId AS VARCHAR(20)),SPACE(1)) +'" '+
								'ToCustID="' +  COALESCE(CAST(@ToCustId AS VARCHAR(20)),SPACE(1)) +'" '+
								'Schedule="' + COALESCE(CAST(dbo.f_AutoTransferSchedule_NumericToChar(@Old_AutoTransferSchedule_numeric) AS VARCHAR(20)), SPACE(1)) +'" '+
								'SubAccId="'+ coalesce(cast(@SubAccID as varchar(20)),space(1)) + '" '+
								'Language="' + COALESCE(CAST(@Language AS VARCHAR(2)),SPACE(1)) +'" '+
								'IP="' + COALESCE(CAST(@IP AS NVARCHAR(20)),SPACE(1)) +'" '+
								'ErrCode="' + COALESCE(CAST(@ErrCode AS VARCHAR(10)),SPACE(1)) +'" '+
								'ErrMsg="' + COALESCE(CAST(@ErrMsg AS NVARCHAR(3000)),SPACE(1)) +'"'+ '/>'
		SET @EndRun		= GETDATE()
		SET @Duration	= DATEDIFF(MILLISECOND,@StartRun,@EndRun)

		BEGIN TRY
			EXEC DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_RunSP
				@UserID = @Creator,
				@CustID = @ToCustID,
				@ActionID = 95100,
				@TrackingValue = @TrackingValue,
				@TrackingValue2 = @TrackingValue2,
				@Duration = @Duration
		END TRY
		BEGIN CATCH
			EXEC bodb_CustomerLog.dbo.WriteLog_UserLog_RunSP
				@UserID = @Creator,
				@CustID = @ToCustID,
				@ActionID = 95100,
				@TrackingValue = @TrackingValue,
				@TrackingValue2 = @TrackingValue2,
				@Duration = @Duration
		END CATCH
	END
END