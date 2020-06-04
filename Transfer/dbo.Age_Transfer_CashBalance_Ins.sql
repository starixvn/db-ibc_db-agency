/*<info serverAlias="DBTXN-bodb02" executers="bodbDownlineNet,bodbDownlineNetView" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE  [dbo].[Age_Transfer_CashBalance_Ins]
	@FromCustID		INT,
	@ToCustID		INT,
	@SubAccID		INT = 0,
	@Amount			FLOAT = 0,
	
	@Creator INT,
	@IP NVARCHAR(15) = '',
	@Language VARCHAR(2) = 'E',
	@ErrCode INT = 0 OUTPUT,
	@ErrMsg NVARCHAR(4000) = '' OUTPUT
AS

/*
	Created by Percy
	Date: 2017-06-01
	DB: DBTXN.bodb02
	Task: Alpha - SMA - Transfer function

	Revisions:
		- 20170609@Percy: Create new [RedmineID: #74291]
		- 20200602@Percy: Separate PendingTransfer3rd from Cash and Balance [RedmineID: #135200]
	
	Param's Explanation:
		@FromCustID, @ToCustID: upline (super/master/agent) transfer dowline (master/agent/member)
		@SubAccID: sub-account of upline
*/

BEGIN
	SET NOCOUNT ON

	-- Check processing data
	DECLARE @EndProcessingTime DATETIME, @RemainingTime VARCHAR(30)
	EXEC dbo.Acc_CheckProcessingData @EndProcessingTime = @EndProcessingTime OUTPUT

	IF @EndProcessingTime IS NOT NULL
	BEGIN
		SELECT
			@ErrCode = 101,
			@ErrMsg = CASE @Language WHEN 'E' THEN 'To ensure the accuracy of data while being processed, all transfer transaction cannot be executed. The expected time to finish is {expandedtime} (GMT +8). We are sorry for any inconvenience caused.'
									ELSE dbo.f_Get_MsgNamebyMsgID(50010, @Language)	END,
			@RemainingTime = CONVERT(VARCHAR(8), DATEADD(HOUR, 12, @EndProcessingTime), 114) + ' ' + CONVERT(VARCHAR(10), DATEADD(HOUR, 12, @EndProcessingTime), 101) --convert time to GMT +8

		SELECT @ErrMsg = REPLACE(@ErrMsg, '{expandedtime}', @RemainingTime)
	
		RETURN
	END

	DECLARE @winlostdate SMALLDATETIME, @yesterday SMALLDATETIME
	SELECT  @winlostdate = CONVERT(DATE, GETDATE())
	SELECT  @yesterday = DATEADD(DAY, -1, @winlostdate)
	
	DECLARE @custid INT, @recommend INT, @mrecommend INT, @srecommend INT, @RoleId TINYINT, @Credit MONEY, @FutureCreditBalance MONEY

	DECLARE @FromUsername NVARCHAR(50), @ToUsername NVARCHAR(50), @SubAccName VARCHAR(30),
			@Currency INT, @CurrencyName NVARCHAR(100), @actualrate FLOAT,
			@RefNo BIGINT, @grefno INT, @LogData NVARCHAR(200), @transdesc NVARCHAR(2000), @ABSAmount MONEY
			
	SELECT
		@srecommend = srecommend,
		@mrecommend = mrecommend,
		@recommend = recommend,
		@custid = custid,
		@RoleId = roleid,
		@ToUsername = username,
		@Currency = currency
	FROM CustDB.dbo.Customer WITH(NOLOCK)
	WHERE custid = @ToCustID

	IF @RoleId NOT BETWEEN 1 AND 3
	BEGIN
		SELECT
			@ErrCode = 101,
			@ErrMsg = CASE @Language WHEN 'E' THEN 'Customer does not exist' ELSE [dbo].[f_Get_MsgNamebyMsgID](40014, @Language) END
		RETURN
	END

	IF @RoleId <> 3
	BEGIN
		-- Check Transfer Condition
		EXEC DBCUST.CustDB.dbo.Age_Transfer_CheckTransferOption
			@CustID = @FromCustID,
			@Language = @Language,
			@ErrMsg = @ErrMsg OUTPUT,
			@ErrCode = @ErrCode OUTPUT

		IF @ErrCode > 0
			RETURN
	END

	SELECT @FromUsername = username
	FROM CustDB.dbo.Customer WITH(NOLOCK)
	WHERE custid = @FromCustID AND roleid = @RoleId + 1

	IF @FromUsername IS NULL
	BEGIN
		SELECT
			@ErrCode = 101,
			@ErrMsg = CASE @Language WHEN 'E' THEN 'Customer does not exist' ELSE [dbo].[f_Get_MsgNamebyMsgID](40014, @Language) END
		RETURN
	END

	IF @RoleId = 1
	BEGIN
		SELECT @Credit = credit FROM DBCUST.CustDB.dbo.custinfo WITH(NOLOCK) WHERE custid = @ToCustID
	END

	SELECT
		@CurrencyName = currency,
		@actualrate = actualrate
	FROM CustDB.dbo.Exchange WITH(NOLOCK) WHERE exchangeid = @Currency
 
	IF @SubAccID > 0
	BEGIN
		SELECT @SubAccName = username
		FROM DBCUST.CustDB.dbo.custSub WITH(NOLOCK) 
		WHERE SubAccID = @SubAccID
	END

	/***** Calculate Upline Balance, Cash Balance and Outstanding *****/
	CREATE TABLE #TransferCash (uplineCashBalance MONEY, CashBalance MONEY, Outstanding MONEY, PendingTransfer3rd MONEY)
	CREATE TABLE #recommend (custid INT)

	-- Get bettype --
	DECLARE @isTest BIT = 0
	SELECT  @isTest = dbo.f_CheckSPVersion(@@PROCID)
	
	CREATE TABLE #SportBettype (bettype INT, RefTable TINYINT)
	INSERT INTO #SportBettype (bettype, RefTable)
	SELECT bettype, RefTable FROM dbo.f_SportBettypeMatrix_Sel (0, 0, 0, 2, '', '', @isTest)

	DECLARE @uplineCashBalance MONEY, @CashBalance MONEY, @Outstanding MONEY, @PendingTransfer3rd MONEY
	DECLARE @FromAmountValue DECIMAL(19,4), @ToAmountValue DECIMAL(19,4)

	IF @roleid = 1
    BEGIN
		-- bettransRNG
		INSERT INTO #TransferCash (uplineCashBalance, CashBalance, Outstanding)
		SELECT 
			SUM(CASE WHEN statusID NOT IN (0,1) THEN awinlost+comm-playercomm ELSE 0 END),
			SUM(CASE WHEN statusID NOT IN (0,1) AND custid = @custid THEN winlost-actual_stake+playercomm ELSE 0 END),
			SUM(CASE WHEN statusID IN (0,1) AND custid = @custid THEN ABS(actual_stake) ELSE 0 END)
	    FROM dbo.bettransRNG WITH(NOLOCK)
		WHERE recommend = @recommend
			AND (
				statusID IN (0,1)
				OR winlostdate >= @yesterday
			)

		-- bettransLC
		INSERT INTO #TransferCash (uplineCashBalance, CashBalance, Outstanding)
		SELECT 
			SUM(CASE WHEN statusID NOT IN (0,1) THEN awinlost+comm-playercomm ELSE 0 END),
			SUM(CASE WHEN statusID NOT IN (0,1) AND custid = @custid THEN winlost-actual_stake+playercomm ELSE 0 END),
			SUM(CASE WHEN statusID IN (0,1) AND custid = @custid THEN ABS(actual_stake) ELSE 0 END)
	    FROM dbo.bettransLC WITH(NOLOCK)
		WHERE recommend = @recommend
			AND (
				statusID IN (0,1)
				OR winlostdate >= @yesterday
			)

		-- translog
		INSERT INTO #TransferCash (uplineCashBalance, CashBalance, Outstanding)
		SELECT 0, 0, SUM(ABS(actual_stake))
	    FROM dbo.translog WITH(NOLOCK)
		WHERE custid = @custid
			AND statusID IN (0,1)

		-- bettrans
		INSERT INTO #TransferCash (uplineCashBalance, CashBalance, Outstanding, PendingTransfer3rd)
		SELECT
			SUM(CASE WHEN bettype IN (21008, 21009) THEN 0 ELSE CASE WHEN ruben = 1 THEN CASE WHEN custid = recommend THEN winlost-actual_stake ELSE awinlost+comm-playercomm END ELSE 0 END END),
			SUM(CASE WHEN bettype IN (21008, 21009) THEN 0 ELSE CASE WHEN ruben = 1 AND custid = @custid THEN winlost-actual_stake+playercomm ELSE 0 END END),
			SUM(CASE WHEN bettype IN (21008, 21009) THEN 0 ELSE CASE WHEN ruben = 0 AND custid = @custid THEN ABS(actual_stake) ELSE 0 END END),
			SUM(CASE WHEN bettype IN (21008, 21009) AND custid = @custid THEN -(winlost-actual_stake) ELSE 0 END)
		FROM dbo.bettrans WITH(NOLOCK)
		WHERE recommend = @recommend
			AND
			(
				ruben <> 0
				OR (ruben = 0 AND bettype NOT IN (SELECT bettype FROM #SportBettype WHERE RefTable <> 0))
			)
			AND
			(
				winlostdate < @yesterday
				OR (winlostdate >=  @yesterday AND bettype NOT IN (SELECT bettype FROM #SportBettype WHERE RefTable IN (1,2)))
			)
    END
    ELSE IF @roleid = 2
    BEGIN
		-- bettransRNG
		INSERT INTO #TransferCash (uplineCashBalance, CashBalance, Outstanding)
		SELECT 
			SUM(CASE WHEN statusID NOT IN (0,1) THEN mwinlost+acomm-comm ELSE 0 END),
			SUM(CASE WHEN statusID NOT IN (0,1) AND recommend = @recommend THEN awinlost+comm-playercomm ELSE 0 END),
			SUM(CASE WHEN statusID IN (0,1) AND recommend = @recommend THEN ABS(actual_stake*apositiontaking) ELSE 0 END)
	    FROM dbo.bettransRNG WITH(NOLOCK)
		WHERE mrecommend = @mrecommend
			AND (
				statusID IN (0,1)
				OR winlostdate >= @yesterday
			)

		-- bettransLC
		INSERT INTO #TransferCash (uplineCashBalance, CashBalance, Outstanding)
		SELECT 
			SUM(CASE WHEN statusID NOT IN (0,1) THEN mwinlost+acomm-comm ELSE 0 END),
			SUM(CASE WHEN statusID NOT IN (0,1) AND recommend = @recommend THEN awinlost+comm-playercomm ELSE 0 END),
			SUM(CASE WHEN statusID IN (0,1) AND recommend = @recommend THEN ABS(actual_stake*apositiontaking) ELSE 0 END)
	    FROM dbo.bettransLC WITH(NOLOCK)
		WHERE mrecommend = @mrecommend
			AND (
				statusID IN (0,1)
				OR winlostdate >= @yesterday
			)

		-- translog
		INSERT INTO #TransferCash (uplineCashBalance, CashBalance, Outstanding)
		SELECT 0, 0, SUM(ABS(actual_stake*apositiontaking))
	    FROM dbo.translog t WITH(NOLOCK)
		WHERE recommend = @recommend
			AND statusID IN (0,1)

		-- bettrans
		INSERT INTO #TransferCash (uplineCashBalance, CashBalance, Outstanding)
		SELECT
			SUM(CASE WHEN ruben = 1 THEN CASE WHEN custid = mrecommend THEN winlost-actual_stake ELSE mwinlost+acomm-comm END ELSE 0 END),
			SUM(CASE WHEN ruben = 1 AND recommend = @recommend THEN CASE WHEN custid = recommend THEN winlost-actual_stake ELSE awinlost+comm-playercomm END ELSE 0 END),
			SUM(CASE WHEN ruben = 0 AND recommend = @recommend THEN ABS(actual_stake*apositiontaking) ELSE 0 END)
		FROM dbo.bettrans WITH(NOLOCK)
		WHERE mrecommend = @mrecommend
			AND
			(
				ruben <> 0
				OR (ruben = 0 AND bettype NOT IN (SELECT bettype FROM #SportBettype WHERE RefTable <> 0))
			)
			AND
			(
				winlostdate < @yesterday
				OR (winlostdate >=  @yesterday AND bettype NOT IN (SELECT bettype FROM #SportBettype WHERE RefTable IN (1,2)))
			)
			AND bettype NOT IN (21008, 21009)
    END
    ELSE IF @roleid = 3
    BEGIN
		-- bettransRNG
		INSERT INTO #TransferCash (uplineCashBalance, CashBalance, Outstanding)
		SELECT 
			SUM(CASE WHEN statusID NOT IN (0,1) THEN swinlost+scomm-acomm ELSE 0 END),
			SUM(CASE WHEN statusID NOT IN (0,1) AND mrecommend = @mrecommend THEN mwinlost+acomm-comm ELSE 0 END),
			SUM(CASE WHEN statusID IN (0,1) AND mrecommend = @mrecommend THEN ABS(actual_stake*mpositiontaking) ELSE 0 END)
	    FROM dbo.bettransRNG WITH(NOLOCK)
		WHERE srecommend = @srecommend
			AND (
				statusID IN (0,1)
				OR winlostdate >= @yesterday
			)

		-- bettransLC
		INSERT INTO #TransferCash (uplineCashBalance, CashBalance, Outstanding)
		SELECT 
			SUM(CASE WHEN statusID NOT IN (0,1) THEN swinlost+scomm-acomm ELSE 0 END),
			SUM(CASE WHEN statusID NOT IN (0,1) AND mrecommend = @mrecommend THEN mwinlost+acomm-comm ELSE 0 END),
			SUM(CASE WHEN statusID IN (0,1) AND mrecommend = @mrecommend THEN ABS(actual_stake*mpositiontaking) ELSE 0 END)
	    FROM dbo.bettransLC WITH(NOLOCK)
		WHERE srecommend = @srecommend
			AND (
				statusID IN (0,1)
				OR winlostdate >= @yesterday
			)

		-- translog
		INSERT INTO #TransferCash (uplineCashBalance, CashBalance, Outstanding)
		SELECT 0, 0, SUM(ABS(actual_stake*mpositiontaking))
	    FROM dbo.translog t WITH(NOLOCK)
		WHERE EXISTS (SELECT TOP 1 1 FROM CustDB.dbo.Customer c WITH(NOLOCK) WHERE t.recommend = c.custid AND c.mrecommend = @mrecommend AND c.roleid = 2)
			AND statusID IN (0,1)

		-- bettrans
		INSERT INTO #TransferCash (uplineCashBalance, CashBalance, Outstanding)
		SELECT
			SUM(CASE WHEN ruben = 1 THEN CASE WHEN custid = srecommend THEN winlost-actual_stake ELSE swinlost+scomm-acomm END ELSE 0 END),
			SUM(CASE WHEN ruben = 1 AND mrecommend = @mrecommend THEN CASE WHEN custid = mrecommend THEN winlost-actual_stake ELSE mwinlost+acomm-comm END ELSE 0 END),
			SUM(CASE WHEN ruben = 0 AND mrecommend = @mrecommend THEN ABS(actual_stake*mpositiontaking) ELSE 0 END)
		FROM dbo.bettrans WITH(NOLOCK)
		WHERE srecommend = @srecommend
			AND
			(
				ruben <> 0
				OR (ruben = 0 AND bettype NOT IN (SELECT bettype FROM #SportBettype WHERE RefTable <> 0))
			)
			AND
			(
				winlostdate < @yesterday
				OR (winlostdate >=  @yesterday AND bettype NOT IN (SELECT bettype FROM #SportBettype WHERE RefTable IN (1,2)))
			)
			AND bettype NOT IN (21008, 21009)
    END

	/*
		======================== Check amount cash transfer =========================
		- From value:
			- If dowline cash - dowline outstanding > 0: - (dowline cash - dowline outstanding)
			- If dowline cash - dowline outstanding <= 0: 0
		- To value:
			- If upline cash > 0: upline cash
			- If upline cash <= 0: 0
	*/
	
	SELECT
		@uplineCashBalance = SUM(ISNULL(uplineCashBalance, 0)),
		@CashBalance = SUM(ISNULL(CashBalance, 0)),
		@Outstanding = SUM(ISNULL(Outstanding, 0)),
		@PendingTransfer3rd = SUM(ISNULL(PendingTransfer3rd, 0))
	FROM #TransferCash

	SELECT
		@FromAmountValue = CASE WHEN @CashBalance - @Outstanding - @PendingTransfer3rd > 0 THEN - (@CashBalance - @Outstanding - @PendingTransfer3rd) ELSE 0 END,
		@ToAmountValue = CASE WHEN @uplineCashBalance > 0 THEN @uplineCashBalance ELSE 0 END

	IF @Amount = 0 OR -@Amount NOT BETWEEN @FromAmountValue AND @ToAmountValue
	BEGIN
		SELECT
			@ErrCode = 105,
			@ErrMsg = CASE @Language WHEN 'E' THEN 'Amount to transfer must be between 0 and ' ELSE [dbo].[f_Get_MsgNamebyMsgID](50005, @Language) END
						+ CASE WHEN @ToAmountValue = 0 THEN '0' ELSE CONVERT(VARCHAR(100), @ToAmountValue) END

		IF @FromAmountValue <> 0
			SELECT @ErrMsg = REPLACE(@ErrMsg, 'between 0', 'between ' + CONVERT(VARCHAR(30), @FromAmountValue))
			
		RETURN
	END

	-- All error messages are the same, so we set it here
	SELECT @ErrMsg = CASE @Language WHEN 'E' THEN 'Clear balance failed. Please try again.' ELSE [dbo].[f_Get_MsgNamebyMsgID](50003, @Language) END

	BEGIN TRANSACTION
		UPDATE ref WITH (ROWLOCK, UPDLOCK)
		SET @grefno = transcode = transcode + 1
		WHERE refid = 'acc'
		
		IF @@ERROR <> 0
		BEGIN
			ROLLBACK TRANSACTION
			RETURN
		END		

		SELECT @RefNo = 200000000000 + @grefno
	COMMIT TRANSACTION

	DECLARE @bettype INT, @LogUsername VARCHAR(200)
	SELECT  @bettype = CASE @RoleId WHEN 1 THEN 21004 ELSE 21003 END

	IF @Amount > 0
	BEGIN
		SELECT @transdesc = 'Cash Balance From ::' + CASE WHEN @RoleId = 1 THEN ' ' ELSE ': ' END + @ToUsername
			
		INSERT INTO bettrans
			(matchid, creator, custid, username, refno, transdate, bettype, transdesc, winlost, actual_stake, 
			status, ruben, winlostdate, currency, actualrate, currencyName, recommend, mrecommend, srecommend, 
			scomm, swinlost, ip, statusID)
		VALUES 
			(0, @creator, @FromCustID, @FromUsername, @RefNo, CURRENT_TIMESTAMP, @bettype, @transdesc, @Amount, 0, 
			'Completed', 1, @winlostdate, @currency, @actualrate, @currencyname, CASE WHEN @RoleId = 1 THEN @recommend ELSE 0 END, CASE WHEN @RoleId <= 2 THEN @mrecommend ELSE 0 END, @srecommend,
			0, 0, @ip, 131)
			
		IF @@ERROR <> 0
		BEGIN
			SELECT @ErrCode = 102
				
			-- Manually rollback
			DELETE dbo.bettrans WITH (ROWLOCK, UPDLOCK) WHERE refno = @RefNo AND matchid = 0
				
			RETURN
		END

		-- Update balance of member
		IF @RoleId = 1
		BEGIN
			EXEC Dot_BalanceDebitUpd @CustID = @CustID, @balance = @amount, @type = 2, @IsForced = 1, @errCode = @ErrCode OUTPUT
			
			IF @ErrCode <> 0
			BEGIN
				SELECT @ErrCode = 104
			
				-- Manually rollback
				DELETE FROM bettrans where refno = @RefNo and matchid = 0
			
				RETURN
			END
		END

		SELECT @transdesc = 'Cash Balance To ::' + CASE WHEN @RoleId = 1 THEN ' ' ELSE ': ' END + @FromUsername

		INSERT INTO bettrans
			(matchid, creator, custid, username, refno, transdate, bettype, transdesc, winlost, actual_stake, 
			status, ruben, winlostdate, currency, actualrate, currencyName, recommend, mrecommend, srecommend,
			scomm, swinlost, ip, statusID)
		VALUES 
			(0, @creator, @ToCustID, @ToUsername, @RefNo, CURRENT_TIMESTAMP, @bettype, @transdesc, 0, @Amount,
			'Completed', 1, @winlostdate, @currency, @actualrate, @currencyname, CASE WHEN @RoleId <= 2 THEN @recommend ELSE 0 END, CASE WHEN @RoleId <= 3 THEN @mrecommend ELSE 0 END, @srecommend,
			0, 0, @ip, 131)

				
		IF @@ERROR <> 0
		BEGIN
			SELECT @ErrCode = 102

			-- Manually rollback
			DELETE dbo.bettrans WITH (ROWLOCK, UPDLOCK) WHERE refno = @RefNo AND matchid = 0

			-- rollback balance
			IF @RoleId = 1
			BEGIN
				EXEC Dot_BalanceCreditUpd @CustID = @CustID, @balance = @amount, @type = 2
			END

			RETURN
		END

		SELECT @LogUsername = CASE @RoleId
								WHEN 1 THEN 'from Customer ' + @ToUsername + ' to Agent' + @FromUsername
								WHEN 2 THEN 'from Agent ' + @ToUsername + ' to Master' + @FromUsername
								WHEN 3 THEN 'from Master ' + @ToUsername + ' to Super' + @FromUsername
								END
		SELECT @LogData = 'Transfer ' + @LogUsername + ' with amount ' + CONVERT(VARCHAR(20), @Amount) + ' Ref.No ' + CONVERT(VARCHAR(20), @RefNo)
			
	END
	ELSE IF @Amount < 0
	BEGIN
		SELECT @transdesc = 'Cash Balance To ::' + CASE WHEN @RoleId = 1 THEN ' ' ELSE ': ' END + @ToUsername

		INSERT INTO bettrans 
			(matchid, creator, custid, username, refno, transdate, bettype, transdesc, winlost, actual_stake, 
			status, ruben, winlostdate, currency, actualrate, currencyName, recommend, mrecommend, srecommend, 
			scomm, swinlost, ip, statusID)
		VALUES 
			(0, @creator, @FromCustID, @FromUsername, @RefNo, CURRENT_TIMESTAMP, @bettype, @transdesc, 0, ABS(@Amount),
			'Completed', 1, @winlostdate, @currency, @actualrate, @currencyname, CASE WHEN @RoleId = 1 THEN @recommend ELSE 0 END, CASE WHEN @RoleId <= 2 THEN @mrecommend ELSE 0 END, @srecommend,
			0, 0, @ip, 131)
				
		IF @@ERROR <> 0
		BEGIN
			SELECT @ErrCode = 107

			--Manually rollback
			DELETE dbo.bettrans WITH (ROWLOCK, UPDLOCK) WHERE refno = @RefNo AND matchid = 0
					
			RETURN
		END
		
		SELECT @transdesc = 'Cash Balance From ::' + CASE WHEN @RoleId = 1 THEN ' ' ELSE ': ' END + @FromUsername
			
		INSERT INTO bettrans
			(matchid, creator, custid, username, refno, transdate, bettype, transdesc, winlost, actual_stake, 
			status, ruben, winlostdate, currency,actualrate, currencyName, recommend, mrecommend, srecommend, 
			scomm, swinlost, ip, statusID)
		VALUES 
			(0, @creator, @ToCustID, @ToUsername, @RefNo, CURRENT_TIMESTAMP, @bettype, @transdesc, ABS(@Amount), 0,
			'Completed', 1, @winlostdate, @currency, @actualrate, @currencyname, CASE WHEN @RoleId <= 2 THEN @recommend ELSE 0 END, CASE WHEN @RoleId <= 3 THEN @mrecommend ELSE 0 END, @srecommend,
			0, 0, @ip, 131)
				
		IF @@ERROR <> 0
		BEGIN
			SELECT @ErrCode = 107

			--Manually rollback
			DELETE dbo.bettrans WITH (ROWLOCK, UPDLOCK) WHERE refno = @RefNo AND matchid = 0
					
			RETURN
		END

		-- Update balance of member
		IF @RoleId = 1
		BEGIN
			SELECT @ABSAmount = ABS(@Amount)
			EXEC Dot_BalanceCreditUpd @CustID = @CustID, @balance = @ABSamount, @type = 2, @errCode = @ErrCode OUTPUT

			IF @ErrCode <> 0
			BEGIN
				SELECT @ErrCode = 104
			
				-- Manually rollback
				DELETE FROM bettrans where refno = @RefNo and matchid = 0
			
				RETURN
			END
		END
		
		SELECT @LogUsername = CASE @RoleId
								WHEN 1 THEN 'from Agent ' + @FromUsername + ' to Customer' + @ToUsername
								WHEN 2 THEN 'from Master ' + @FromUsername + ' to Agent' + @ToUsername
								WHEN 3 THEN 'from Super ' + @FromUsername + ' to Master' + @ToUsername
								END
		SELECT @LogData = 'Transfer ' + @LogUsername + ' with amount ' + CONVERT(VARCHAR(20), @Amount) + ' Ref.No ' + CONVERT(VARCHAR(20), @RefNo)

		IF @RoleId = 1 AND @CashBalance > 0
		BEGIN
			SELECT @FutureCreditBalance = ISNULL(@Credit, 0) + ISNULL(@CashBalance, 0) - ISNULL(@Outstanding, 0) - ISNULL(@Amount, 0)
			
			IF @FutureCreditBalance < 0
				SELECT @LogData = @LogData + '. The agent decided to transfer after the warning so the bet credit of this member turned to negative value (' + CONVERT(VARCHAR(100), @FutureCreditBalance, 2) + ') caused by having outstanding balance value ('+ CONVERT(VARCHAR(100), -@Outstanding, 2) +')  '
		END
	END
		
	SELECT @ErrMsg = ''

	IF @SubAccID > 0
		SELECT @LogData = 'SubAccount:' + COALESCE(@SubAccName, SPACE(1)) + ' - ' + @LogData

	BEGIN TRY
		EXEC DBLOG.bodb_customerlog.dbo.WriteLog_UserLog_Transfer 
			@UserID			= @creator, 
			@FromCustID		= @FromCustID, 
			@ToCustID		= @ToCustID, 
			@IP				= @IP, 
			@Doing			= @LogData
	END TRY
	BEGIN CATCH
		SELECT @LogData = @LogData + ' ErrMsg: ' + ERROR_MESSAGE()
	
		EXEC bodb_customerlog.dbo.WriteLog_UserLog_Transfer 
			@UserID			= @creator,
			@FromCustID		= @FromCustID, 
			@ToCustID		= @ToCustID,
			@IP				= @IP,
			@Doing			= @LogData
	END CATCH

	DROP TABLE #TransferCash
	DROP TABLE #recommend
	DROP TABLE #SportBettype
END
GO
