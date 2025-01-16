/*<info serverAlias="DBSIC-bodb02" executers="wsv_alp,wsv_alpv" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE  [dbo].[Age_Transfer_CashBalance_DirectMember_Ins]
	@FromCustID		INT,
	@ToCustID		INT,
	@SubAccID		INT = 0,
	@Amount			FLOAT = 0,	
	@Creator INT,
	@IP VARCHAR(45) = '',
	@Language VARCHAR(2) = 'E',
	@ErrCode INT = 0 OUTPUT,
	@ErrMsg NVARCHAR(4000) = '' OUTPUT
AS

/*
	Created by: Max
	Task: Alpha - Offer Direct Member for Super/Master [Redmine: #211969]
	DB: DBSIC.bodb02
	
	Revisions:
		- 20241127@20241127: Init SP [RedmineID: #211969]

	Param's Explanation:
		@FromCustID, @ToCustID: upline (super/master/agent) transfer dowline (master/agent/member)
		@SubAccID: sub-account of upline
*/

BEGIN
	SET NOCOUNT ON	
	
	---- #1 CHECK UM TRANSFER FUNCTION
	EXEC DBCUST.CUSTDB.dbo.Acc_Transfer_CheckUM  
		@CustID = @FromCustID
		,@Language = @Language
		,@ErrMsg = @ErrMsg OUTPUT 
		,@ErrCode = @ErrCode OUTPUT
		 
	IF @ErrCode <> 0  -- Function Transfer is under UM 
	BEGIN
		RETURN		
	END		

	---- #2 CHECK FLAG ISTRANSFERRING = 1 THEN RAISE ERROR
	EXEC DBCUST.CUSTDB.dbo.Acc_Transfer_CheckRunningByCust  
			@CustID = @FromCustID
			,@Language = @Language
			,@ErrMsg = @ErrMsg OUTPUT 
			,@ErrCode = @ErrCode OUTPUT
			 
	IF @ErrCode <> 0  -- the auto transfer job is running this custid
	BEGIN
		RETURN		
	END

	---- #2.1 CHECK Status is Waiting or Running THEN RAISE ERROR
	EXEC bodb02.dbo.Age_ClearBalanceCust_CheckRunning  
			@CustID = @FromCustID
			,@Language = @Language
			,@ErrMsg = @ErrMsg OUTPUT 
			,@ErrCode = @ErrCode OUTPUT
			 
	IF @ErrCode <> 0  -- the auto transfer job is running for this line
	BEGIN		
		RETURN		
	END	
	
	DECLARE @winlostdate SMALLDATETIME, @yesterday SMALLDATETIME
	SELECT  @winlostdate = CONVERT(DATE, GETDATE())
	SELECT  @yesterday = DATEADD(DAY, -1, @winlostdate)
	
	DECLARE @custid INT, @recommend INT, @mrecommend INT, @srecommend INT, @RoleId TINYINT, @Credit MONEY, @FutureCreditBalance MONEY

	DECLARE @FromUsername NVARCHAR(50), @ToUsername NVARCHAR(50), @SubAccName VARCHAR(30),
			@Currency INT, @CurrencyName NVARCHAR(100), @actualrate FLOAT,
			@RefNo BIGINT, @grefno BIGINT, @LogData NVARCHAR(200), @transdesc NVARCHAR(2000), @ABSAmount MONEY, @TransID BIGINT,
			@Member_recommend INT,@member_mrecommend INT
			
	SELECT
		@srecommend = srecommend,
		@member_mrecommend = mrecommend,
		@Member_recommend = recommend,
		@custid = custid,
		@RoleId = roleid,
		@ToUsername = username,
		@Currency = currency
	FROM CustDB.dbo.Customer WITH(NOLOCK)
	WHERE custid = @ToCustID

	IF @RoleId <> 1
	BEGIN
		SELECT
			@ErrCode = 101,
			@ErrMsg = CASE @Language WHEN 'E' THEN 'Customer does not exist' ELSE CustDB.dbo.f_Get_MsgNamebyMsgID(40014, @Language) END
		RETURN
	END

	IF @RoleId < 4
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

	SELECT @FromUsername = username, @mrecommend = mrecommend, @srecommend = srecommend
	FROM CustDB.dbo.Customer WITH(NOLOCK)
	WHERE custid = @FromCustID AND roleid IN (3,4)

	IF @FromUsername IS NULL
	BEGIN
		SELECT
			@ErrCode = 101,
			@ErrMsg = CASE @Language WHEN 'E' THEN 'Customer does not exist' ELSE CustDB.dbo.f_Get_MsgNamebyMsgID(40014, @Language) END
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
	CREATE TABLE #TransferCash (uplineCashBalance MONEY, CashBalance MONEY, Outstanding MONEY, PendingTransfer3rd MONEY, TableName VARCHAR(50))
	CREATE TABLE #recommend (custid INT)

	-- Get bettype --
	DECLARE @isTest BIT = 0
	SELECT  @isTest = dbo.f_CheckSPVersion(@@PROCID)
	
	CREATE TABLE #SportBettype (bettype INT, RefTable TINYINT)
	INSERT INTO #SportBettype (bettype, RefTable)
	SELECT bettype, RefTable FROM dbo.f_SportBettypeMatrix_Sel (0, 0, 0, 2, '', '', @isTest)

	DECLARE @uplineCashBalance MONEY, @CashBalance MONEY, @Outstanding MONEY, @PendingTransfer3rd MONEY
	DECLARE @FromAmountValue DECIMAL(19,4), @ToAmountValue DECIMAL(19,4)

	-- get move bet date
	DECLARE @balanceUpDay SMALLDATETIME, @moveBetsDay SMALLDATETIME
	DECLARE @IsDiff	SMALLINT = 1, @NewMoveBetDate SMALLDATETIME = NULL,@NewBalanceUpDate SMALLDATETIME = NULL

	--TODO: Get MBU days
	EXEC dbo.NAP_Admin_GetMovebetDate @MovebetDate = @moveBetsDay OUTPUT
	EXEC dbo.NAP_Admin_GetBalanceUpDate @BalanceUpDate = @balanceUpDay OUTPUT

	IF @member_recommend = -3
    BEGIN
		-- bettransRNG
		INSERT INTO #TransferCash (uplineCashBalance, CashBalance, Outstanding)
		SELECT 
			SUM(CASE WHEN statusID NOT IN (0,1) THEN mwinlost+acomm-comm ELSE 0 END),
			SUM(CASE WHEN statusID NOT IN (0,1) AND custid = @custid THEN winlost-actual_stake+playercomm ELSE 0 END),
			SUM(CASE WHEN statusID IN (0,1) AND custid = @custid THEN ABS(actual_stake) ELSE 0 END)
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
			SUM(CASE WHEN statusID NOT IN (0,1) AND custid = @custid THEN winlost-actual_stake+playercomm ELSE 0 END),
			SUM(CASE WHEN statusID IN (0,1) AND custid = @custid THEN ABS(actual_stake) ELSE 0 END)
	    FROM dbo.bettransLC WITH(NOLOCK)
		WHERE mrecommend = @mrecommend
			AND (
				statusID IN (0,1)
				OR winlostdate >= @yesterday
			)

		-- translog
		INSERT INTO #TransferCash (uplineCashBalance, CashBalance, Outstanding)
		SELECT 0, 0, SUM(ABS(actual_stake))
	    FROM dbo.translog t WITH(NOLOCK)
		WHERE custid = @custid
			AND statusID IN (0,1)

		WHILE (@IsDiff = 1)
		BEGIN

			DELETE FROM #TransferCash WHERE TableName IN ('tblBettrans','tblTransfer')
			
			-- bettrans
			INSERT INTO #TransferCash (uplineCashBalance, CashBalance, Outstanding, TableName)
			SELECT
				SUM(CASE WHEN ruben = 1 THEN mwinlost+acomm-comm ELSE 0 END),  
				SUM(CASE WHEN ruben = 1 AND custid = @custid THEN winlost-actual_stake+playercomm ELSE 0 END),  
				SUM(CASE WHEN ruben = 0 AND custid = @custid THEN ABS(actual_stake) ELSE 0 END), 
				'tblBettrans'
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
				AND winlostdate > @moveBetsDay
			-- Transfer
			INSERT INTO #TransferCash (uplineCashBalance, CashBalance, Outstanding, TableName)
			SELECT
				SUM(CASE WHEN custid = mrecommend THEN winlost-actual_stake ELSE mwinlost+acomm-comm END),  
				ISNULL(SUM(CASE WHEN custid = @custid THEN winlost-actual_stake+playercomm ELSE 0 END),0),  
				0,
				'tblTransfer'
			FROM dbo.Transfer WITH(NOLOCK)
			WHERE mrecommend = @mrecommend
				AND 1 = CASE WHEN bettype = 19999 AND winlostdate > @moveBetsDay THEN 0 --> new sum
							WHEN bettype = 20000 AND winlostdate > @balanceUpDay THEN 0 --> new bal
							WHEN winlostdate < @balanceUpDay THEN 0 --> old data
						ELSE 1 END
				AND bettype NOT IN (21008, 21009)
				
			----check MB date, BU date again to make sure it is not changed
			SELECT @NewMoveBetDate = NULL, @NewBalanceUpDate = NULL
			EXEC dbo.Acc_ReCheck_MBUDate 
				@MBDate = @moveBetsDay,
				@BUDate = @balanceUpDay,
				@IsDiff = @IsDiff OUTPUT,
				@NewMBDate = @NewMoveBetDate OUTPUT,
				@NewBUDate = @NewBalanceUpDate OUTPUT

			IF @IsDiff = -1 
			BEGIN
				RETURN	
			END

			IF @IsDiff = 1 
			BEGIN
				SELECT @moveBetsDay = @NewMoveBetDate, @balanceUpDay = @NewBalanceUpDate
			END
		END
    END
    ELSE IF @Member_recommend = -4
    BEGIN
		-- bettransRNG
		INSERT INTO #TransferCash (uplineCashBalance, CashBalance, Outstanding)
		SELECT 
			SUM(CASE WHEN statusID NOT IN (0,1) THEN swinlost+scomm-acomm ELSE 0 END),
			SUM(CASE WHEN statusID NOT IN (0,1) AND custid = @custid THEN winlost-actual_stake+playercomm ELSE 0 END),
			SUM(CASE WHEN statusID IN (0,1) AND custid = @custid THEN ABS(actual_stake) ELSE 0 END)
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
			SUM(CASE WHEN statusID NOT IN (0,1) AND custid = @custid THEN winlost-actual_stake+playercomm ELSE 0 END),
			SUM(CASE WHEN statusID IN (0,1) AND custid = @custid THEN ABS(actual_stake) ELSE 0 END)
	    FROM dbo.bettransLC WITH(NOLOCK)
		WHERE srecommend = @srecommend
			AND (
				statusID IN (0,1)
				OR winlostdate >= @yesterday
			)

		-- translog
		INSERT INTO #TransferCash (uplineCashBalance, CashBalance, Outstanding)
		SELECT 0, 0, SUM(ABS(actual_stake))
	    FROM dbo.translog t WITH(NOLOCK)
		WHERE custid = @custid
			AND statusID IN (0,1)

		WHILE (@IsDiff = 1)
		BEGIN

			DELETE FROM #TransferCash WHERE TableName IN ('tblBettrans','tblTransfer')
			
			-- bettrans
			INSERT INTO #TransferCash (uplineCashBalance, CashBalance, Outstanding, TableName)  
			SELECT  
				SUM(CASE WHEN ruben = 1 THEN swinlost+scomm-acomm ELSE 0 END),  
				SUM(CASE WHEN ruben = 1 AND custid = @custid THEN winlost-actual_stake+playercomm ELSE 0 END),  
				SUM(CASE WHEN ruben = 0 AND custid = @custid THEN ABS(actual_stake) ELSE 0 END),  
				'tblBettrans'  
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
				AND winlostdate > @moveBetsDay
			-- Transfer
			INSERT INTO #TransferCash (uplineCashBalance, CashBalance, Outstanding, TableName)  
			SELECT  
				SUM(CASE WHEN custid = srecommend THEN winlost-actual_stake ELSE swinlost+scomm-acomm END),  
				ISNULL(SUM(CASE WHEN custid = @custid THEN winlost-actual_stake+playercomm ELSE 0 END),0),  
				0,  
				'tblTransfer'
			FROM dbo.Transfer WITH(NOLOCK)
			WHERE srecommend = @srecommend
				AND 1 = CASE WHEN bettype = 19999 AND winlostdate > @moveBetsDay THEN 0 --> new sum
							WHEN bettype = 20000 AND winlostdate > @balanceUpDay THEN 0 --> new bal
							WHEN winlostdate < @balanceUpDay THEN 0 --> old data
						ELSE 1 END
				AND bettype NOT IN (21008, 21009)

			----check MB date, BU date again to make sure it is not changed
			SELECT @NewMoveBetDate = NULL, @NewBalanceUpDate = NULL
			EXEC dbo.Acc_ReCheck_MBUDate 
				@MBDate = @moveBetsDay,
				@BUDate = @balanceUpDay,
				@IsDiff = @IsDiff OUTPUT,
				@NewMBDate = @NewMoveBetDate OUTPUT,
				@NewBUDate = @NewBalanceUpDate OUTPUT

			IF @IsDiff = -1 
			BEGIN
				RETURN	
			END
			
			IF @IsDiff = 1 
			BEGIN
				SELECT @moveBetsDay = @NewMoveBetDate, @balanceUpDay = @NewBalanceUpDate
			END
		END
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
			@ErrMsg = CASE @Language WHEN 'E' THEN 'Amount to transfer must be between 0 and ' ELSE CustDB.dbo.f_Get_MsgNamebyMsgID(50005, @Language) END
						+ CASE WHEN @ToAmountValue = 0 THEN '0' ELSE CONVERT(VARCHAR(100), @ToAmountValue) END

		IF @FromAmountValue <> 0
			SELECT @ErrMsg = REPLACE(@ErrMsg, 'between 0', 'between ' + CONVERT(VARCHAR(30), @FromAmountValue))
			
		RETURN
	END

	-- All error messages are the same, so we set it here
	SELECT @ErrMsg = CASE @Language WHEN 'E' THEN 'Clear balance failed. Please try again.' ELSE CustDB.dbo.f_Get_MsgNamebyMsgID(50003, @Language) END

	EXEC Get_Refno_Transid @RefNo = @RefNo OUTPUT

	DECLARE @bettype INT, @LogUsername VARCHAR(200)
	SELECT  @bettype = CASE @RoleId WHEN 1 THEN 21004 ELSE 21003 END

	IF @Amount > 0
	BEGIN
		SELECT @transdesc = 'Cash Balance From ::' + CASE WHEN @RoleId = 1 THEN ' ' ELSE ': ' END + @ToUsername + CASE WHEN @SubAccID > 0 THEN ' (By ' + @SubAccName + ')' ELSE '' END
		
		EXEC Get_Bettrans_TransID @TransID = @TransID OUTPUT

		BEGIN TRY
			INSERT INTO Transfer
				(TransId, Creator, CustId, Username, RefNo, TransDate, Bettype, TransDesc, Winlost, Actual_Stake,   
				 WinlostDate, Currency, ActualRate, CurrencyName, Recommend, MRecommend, SRecommend, SComm, SWinlost,IP,StatusId, RepUpdateTime)
			VALUES 
				(@TransID, @creator, @FromCustID, @FromUsername, @RefNo, CURRENT_TIMESTAMP, @bettype, @transdesc, @Amount, 0, 
				 @winlostdate, @currency, @actualrate, @currencyname, 
				 0, @mrecommend, @srecommend,
				0, 0, @ip, 131,SYSDATETIME())
		END	TRY		
		BEGIN CATCH
			SELECT @ErrCode = 102
				
			-- Manually rollback
			UPDATE dbo.Transfer WITH(ROWLOCK)
			SET	 custid = 0, Winlost = 0, Actual_Stake = 0, RepUpdateTime = SYSDATETIME(), Recommend = 0, MRecommend = 0, SRecommend = 0	
			WHERE refno = @RefNo
				
			RETURN
		END CATCH

		-- Update balance of member
		IF @RoleId = 1
		BEGIN
			EXEC Dot_BalanceDebitUpd @CustID = @CustID, @balance = @amount, @type = 2, @IsForced = 1, @errCode = @ErrCode OUTPUT
			
			IF @ErrCode <> 0
			BEGIN
				SELECT @ErrCode = 104
			
				-- Manually rollback
				UPDATE dbo.Transfer WITH(ROWLOCK)
				SET	 custid = 0, Winlost = 0, Actual_Stake = 0, RepUpdateTime = SYSDATETIME(), Recommend = 0, MRecommend = 0, SRecommend = 0	
				WHERE refno = @RefNo
			
				RETURN
			END
		END

		SELECT @transdesc = 'Cash Balance To ::' + CASE WHEN @RoleId = 1 THEN ' ' ELSE ': ' END + @FromUsername + CASE WHEN @SubAccID > 0 THEN ' (By ' + @SubAccName + ')' ELSE '' END

		DECLARE @TotalCashTo MONEY 
		EXEC Acc_CustomerSelCash_CaptureBalance @custid = @ToCustID, @TotalCash  = @TotalCashTo OUTPUT

		EXEC Get_Bettrans_TransID @TransID = @TransID OUTPUT

		BEGIN TRY
			INSERT INTO Transfer
				(TransID, Creator, CustId, Username, RefNo, TransDate, Bettype, TransDesc, Winlost, Actual_Stake,   
				 WinlostDate, Currency, ActualRate, CurrencyName, Recommend, MRecommend, SRecommend, SComm, SWinlost,IP,StatusId, Balance, RepUpdateTime)
			VALUES 
				(@TransID, @creator, @ToCustID, @ToUsername, @RefNo, CURRENT_TIMESTAMP, @bettype, @transdesc, 0, @Amount,
				 @winlostdate, @currency, @actualrate, @currencyname
				 , @member_recommend
				 , @member_mrecommend
				 , @srecommend,
				0, 0, @ip, 131,@TotalCashTo,SYSDATETIME())

		END TRY		
		BEGIN CATCH
			SELECT @ErrCode = 102

			-- Manually rollback
			UPDATE dbo.Transfer WITH(ROWLOCK)
			SET	 custid = 0, Winlost = 0, Actual_Stake = 0, RepUpdateTime = SYSDATETIME(), Recommend = 0, MRecommend = 0, SRecommend = 0	
			WHERE refno = @RefNo

			-- rollback balance
			IF @RoleId = 1
			BEGIN
				EXEC Dot_BalanceCreditUpd @CustID = @CustID, @balance = @amount, @type = 2
			END

			RETURN
		END CATCH

		SELECT @LogUsername = CASE @RoleId
								WHEN 1 THEN 'from Customer ' + @ToUsername + ' to Agent' + @FromUsername
								WHEN 2 THEN 'from Agent ' + @ToUsername + ' to Master' + @FromUsername
								WHEN 3 THEN 'from Master ' + @ToUsername + ' to Super' + @FromUsername
								END
		SELECT @LogData = 'Transfer ' + @LogUsername + ' with amount ' + CONVERT(VARCHAR(20), @Amount) + ' Ref.No ' + CONVERT(VARCHAR(20), @RefNo)
			
	END
	ELSE IF @Amount < 0
	BEGIN
		SELECT @transdesc = 'Cash Balance To ::' + CASE WHEN @RoleId = 1 THEN ' ' ELSE ': ' END + @ToUsername + CASE WHEN @SubAccID > 0 THEN ' (By ' + @SubAccName + ')' ELSE '' END

		EXEC Get_Bettrans_TransID @TransID = @TransID OUTPUT

		BEGIN TRY
			INSERT INTO Transfer 
				(TransID, Creator, CustId, Username, RefNo, TransDate, Bettype, TransDesc, Winlost, Actual_Stake,   
				 WinlostDate, Currency, ActualRate, CurrencyName, Recommend, MRecommend, SRecommend, SComm, SWinlost,IP,StatusId, RepUpdateTime)
			VALUES 
				(@TransID, @creator, @FromCustID, @FromUsername, @RefNo, CURRENT_TIMESTAMP, @bettype, @transdesc, 0, ABS(@Amount),
				   @winlostdate, @currency, @actualrate, @currencyname
				   , 0	
				   , @mrecommend
				   , @srecommend,
				0, 0, @ip, 131, SYSDATETIME())
		END TRY
		BEGIN CATCH
			SELECT @ErrCode = 107

			--Manually rollback
			UPDATE dbo.Transfer WITH(ROWLOCK)
			SET	 custid = 0, Winlost = 0, Actual_Stake = 0, RepUpdateTime = SYSDATETIME(), Recommend = 0, MRecommend = 0, SRecommend = 0	
			WHERE refno = @RefNo
					
			RETURN
		END CATCH
		
		SELECT @transdesc = 'Cash Balance From ::' + CASE WHEN @RoleId = 1 THEN ' ' ELSE ': ' END + @FromUsername + CASE WHEN @SubAccID > 0 THEN ' (By ' + @SubAccName + ')' ELSE '' END
		
		DECLARE @TotalCashToNev MONEY 
		EXEC Acc_CustomerSelCash_CaptureBalance @custid = @ToCustID, @TotalCash  = @TotalCashToNev OUTPUT

		EXEC Get_Bettrans_TransID @TransID = @TransID OUTPUT

		BEGIN TRY
			INSERT INTO Transfer
				(TransId, Creator, CustId, Username, RefNo, TransDate, Bettype, TransDesc, Winlost, Actual_Stake,   
				 WinlostDate, Currency, ActualRate, CurrencyName, Recommend, MRecommend, SRecommend, SComm, SWinlost,IP,StatusId, balance, RepUpdateTime)
			VALUES 
				(@TransID, @creator, @ToCustID, @ToUsername, @RefNo, CURRENT_TIMESTAMP, @bettype, @transdesc, ABS(@Amount), 0,
				 @winlostdate, @currency, @actualrate, @currencyname
				 , @Member_recommend
				 , @member_mrecommend
				 , @srecommend,
				0, 0, @ip, 131,@TotalCashToNev, SYSDATETIME())
		END TRY	
		BEGIN CATCH
			SELECT @ErrCode = 107

			--Manually rollback
			UPDATE dbo.Transfer WITH(ROWLOCK)
			SET	 custid = 0, Winlost = 0, Actual_Stake = 0, RepUpdateTime = SYSDATETIME(), Recommend = 0, MRecommend = 0, SRecommend = 0	
			WHERE refno = @RefNo
					
			RETURN
		END CATCH

		-- Update balance of member
		IF @RoleId = 1
		BEGIN
			SELECT @ABSAmount = ABS(@Amount)
			EXEC Dot_BalanceCreditUpd @CustID = @CustID, @balance = @ABSamount, @type = 2, @errCode = @ErrCode OUTPUT

			IF @ErrCode <> 0
			BEGIN
				SELECT @ErrCode = 104
			
				-- Manually rollback
				DELETE FROM Transfer where refno = @RefNo
			
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
