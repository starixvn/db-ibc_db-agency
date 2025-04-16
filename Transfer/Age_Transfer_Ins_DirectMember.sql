/*<info serverAlias="DBSIC-bodb02" executers="wsv_alp" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE  [dbo].[Age_Transfer_Ins_DirectMember] 
	@FromCustID int, --the customer here
	@ToUserName varchar(30), --the agent here
	@Amount float,
	@creator int,
	@IP varchar(45)='',
	@Language varchar(2)= 'E',
	@SubAccID int = 0, --Sub-AccountID
	@ErrCode int = 0 OUTPUT,
	@ErrMsg nvarchar(4000) = '' OUTPUT
AS
/*
	Created: 20241125@Helen
	Task: Alpha - Offer Direct Member for Super/Master
	DB: DBSIC/bodb02
	Original: Clone code from Age_Transfer_Ins_Ag

	Revisions:
		- 20241125@Helen: Alpha - Offer Direct Member for Super/Master [Redmine: #211969]
	
	Param's Explanation:
	• @FromCustID: from customer
	• @ToUserName: to user
	• @Amount: amount of money
*/
BEGIN
	SET NOCOUNT ON;
	DECLARE @RefNo BIGINT, @ToCustID INT
		, @custid int,  @srecommend int, @TransID_from BIGINT,@TransID_to BIGINT, @mrecommend INT, @upline_roleid TINYINT
	DECLARE @currency int, @actualrate float, @currName nvarchar(10) , @User nvarchar(50)
	DECLARE @Upline_UserName nvarchar(50), @ABSamount MONEY
	DECLARE @SubAccName VARCHAR(30) = '', @Member_recommend INT,@member_mrecommend INT

	SELECT @ToCustID = null
	-- UplineID
	SELECT @ToCustID = CustID, @upline_roleid = roleid
	FROM CustDB.dbo.customer WITH (NOLOCK) 
	WHERE username = @ToUserName

	IF @ToCustID is NULL or @ToCustID = 0
	BEGIN
		SELECT @ErrMsg = CASE @Language 
			WHEN 'E' THEN 'Customer does not exist' + ': ' + @ToUserName			
			ELSE CustDB.dbo.f_Get_MsgNamebyMsgID(40014,@Language) + ': ' + @ToUserName	
		END, @ErrCode = 101		
		RETURN
	END

	SELECT @Member_recommend = recommend, @member_mrecommend = mrecommend
	FROM CustDB.dbo.customer WITH (NOLOCK) 
	WHERE custid = @FromCustID 
		AND ((mrecommend = @ToCustID AND recommend = -3)
			OR (srecommend = @ToCustID AND recommend = -4)
			)
	IF @Member_recommend NOT IN (-3,-4)
	BEGIN
		SELECT @ErrMsg = CASE @Language 
			WHEN 'E' THEN 'Customer does not exist' + ': ' + @ToUserName			
			ELSE CustDB.dbo.f_Get_MsgNamebyMsgID(40014,@Language) + ': ' + @ToUserName	
		END, @ErrCode = 101		
		RETURN
	END

	---- #1 CHECK UM TRANSFER FUNCTION
	EXEC DBCUST.CUSTDB.dbo.Acc_Transfer_CheckUM  
		@CustID = @ToCustID
		,@Language = @Language
		,@ErrMsg = @ErrMsg OUTPUT 
		,@ErrCode = @ErrCode OUTPUT
	 
	IF @ErrCode <> 0  -- Function Transfer is under UM 
	BEGIN
		RETURN		
	END		

	---- #2 CHECK FLAG ISTRANSFERRING = 1 THEN RAISE ERROR
	EXEC DBCUST.CUSTDB.dbo.Acc_Transfer_CheckRunningByCust  
			@CustID = @ToCustID
			,@Language = @Language
			,@ErrMsg = @ErrMsg OUTPUT 
			,@ErrCode = @ErrCode OUTPUT
		 
	IF @ErrCode <> 0  -- the auto transfer job is running this custid
	BEGIN
		RETURN		
	END	
	
	---- #2.1 CHECK Status is Waiting or Running THEN RAISE ERROR
	EXEC bodb02.dbo.Age_ClearBalanceCust_CheckRunning  
			@CustID = @ToCustID
			,@Language = @Language
			,@ErrMsg = @ErrMsg OUTPUT 
			,@ErrCode = @ErrCode OUTPUT
			 
	IF @ErrCode <> 0  -- the auto transfer job is running for this line
	BEGIN		
		RETURN		
	END	
	----------------------------------------------------------------------
	--Check Transfer Condition
	--1		2		3		4		5		6		7		8
	--isSun	isMon	isTue	isWed	isThurs	isFri	isSat	isWeekly
	--0		1		0		0		1		0		1		1
	-- do not need to check transfer condition for super
	IF @upline_roleid < 4
	BEGIN
		EXEC DBCUST.CustDB.dbo.Age_Transfer_CheckTransferOption
			@CustID = @ToCustID,
			@ErrMsg = @ErrMsg OUTPUT,
			@ErrCode = @ErrCode OUTPUT,
			@Language = @Language
	END

	IF @ErrCode <> 0  return

	IF NOT EXISTS (SELECT 1 FROM CustDB.dbo.customer WITH (NOLOCK) WHERE custid = @FromCustID)
	BEGIN
		SELECT @ErrMsg = CASE @Language 
			WHEN 'E' THEN 'Customer does not exist.'
			ELSE  CustDB.dbo.f_Get_MsgNamebyMsgID(40014,@Language)
			END, @ErrCode = 103
		RETURN
	END

	SELECT @CustID = @FromCustID

	DECLARE @today DATETIME
	SET @today = CAST(DATEDIFF(dd,0,GETDATE()) AS DATETIME)

	-- get move bet date
	DECLARE @balanceUpDay SMALLDATETIME, @moveBetsDay SMALLDATETIME
	DECLARE @IsDiff	SMALLINT = 1, @NewMoveBetDate SMALLDATETIME = NULL,@NewBalanceUpDate SMALLDATETIME = NULL

	--TODO: Get MBU days
	EXEC dbo.NAP_Admin_GetMovebetDate @MovebetDate = @moveBetsDay OUTPUT
	EXEC dbo.NAP_Admin_GetBalanceUpDate @BalanceUpDate = @balanceUpDay OUTPUT

	DECLARE @CustBalance MONEY 
	DECLARE @CustOutstanding MONEY
	DECLARE @PendingTransfer3rd MONEY
	DECLARE @Credit MONEY 
	DECLARE @FutureCreditBalance MONEY
	DECLARE @WinlostDate DATETIME

	SET @CustOutstanding = 0
	--Check valid balance
	--Balance calculated with the correct transfer date @Phuong20080926
	SELECT @WinlostDate = convert(NVARCHAR(10), current_timestamp,120)

	DECLARE @yesterday SMALLDATETIME
	SELECT  @yesterday = DATEADD(DAY, -1, CONVERT(DATE, GETDATE()))

	-- Get bettype --
	DECLARE @isTest BIT = 0
	SELECT  @isTest = dbo.f_CheckSPVersion(@@PROCID)
	
	CREATE TABLE #SportBettype (bettype INT, RefTable TINYINT)
	INSERT INTO #SportBettype (bettype, RefTable)
	SELECT bettype, RefTable FROM dbo.f_SportBettypeMatrix_Sel (0, 0, 0, 2, '', '', @isTest)

	CREATE TABLE #BalanceInfo (Balance MONEY, Outstanding MONEY, PendingTransfer3rd MONEY, TableName VARCHAR(50))

	IF @SubAccID > 0 
	BEGIN	
		SELECT @SubAccName = username 
		FROM DBCUST.CustDB.dbo.custSub WITH(NOLOCK) 
		WHERE SubAccID = @SubAccID
	END

	--Yesterday Balance  
	-- bettransRnG
	INSERT INTO #BalanceInfo (Balance, Outstanding)
	SELECT
		ISNULL(SUM(CASE WHEN statusID IN (111, 112, 113) THEN winlost-actual_stake+playercomm ELSE 0 END), 0),
		ISNULL(SUM(CASE WHEN statusID IN (0, 1) THEN ABS(actual_stake) ELSE 0 END), 0)
	FROM dbo.bettransRnG WITH (NOLOCK) 
	WHERE custid = @CustID
		AND (
			statusID IN (0, 1)
			OR winlostdate = @yesterday
		)

	-- bettransLC
	INSERT INTO #BalanceInfo (Balance, Outstanding)
	SELECT
		ISNULL(SUM(CASE WHEN statusID IN (111, 112, 113) THEN winlost-actual_stake+playercomm ELSE 0 END), 0),
		ISNULL(SUM(CASE WHEN statusID IN (0, 1) THEN ABS(actual_stake) ELSE 0 END), 0)
	FROM dbo.bettransLC WITH (NOLOCK) 
	WHERE custid = @CustID
		AND (
			statusID IN (0, 1)
			OR winlostdate = @yesterday
		)
	
	-- translog
	INSERT INTO #BalanceInfo (Balance, Outstanding)
	SELECT
		0,
		ISNULL(SUM(ABS(actual_stake)), 0)
	FROM dbo.translog WITH (NOLOCK) 
	WHERE custid = @CustID
		AND statusID IN (0, 1)

	-- bettrans
	INSERT INTO #BalanceInfo (Balance, Outstanding)
	SELECT
		0,
		ISNULL(SUM(ABS(actual_stake)), 0)
	FROM dbo.bettrans b WITH(NOLOCK)
	WHERE b.custid = @custid
		AND b.ruben = 0
		AND NOT EXISTS (SELECT TOP 1 1 FROM #SportBettype s WHERE s.Bettype = b.bettype AND s.RefTable <> 0)

	WHILE (@IsDiff = 1)
	BEGIN

		DELETE FROM #BalanceInfo WHERE TableName IN ('tblBettrans','tblTransfer')

		INSERT INTO #BalanceInfo (Balance, Outstanding, PendingTransfer3rd, TableName)
		SELECT
			ISNULL(SUM(winlost-actual_stake+playercomm), 0),
			0,
			0,
			'tblBettrans'
		FROM dbo.bettrans b WITH(NOLOCK)
		WHERE b.custid = @custid
			AND b.statusID IN (111, 112, 113)
			AND (
				b.winlostdate < @yesterday
				OR (
					winlostdate = @yesterday
					AND NOT EXISTS (SELECT TOP 1 1 FROM #SportBettype s WHERE s.Bettype = b.bettype AND s.RefTable IN (1, 2))
				)
			)
			AND winlostdate > @moveBetsDay

		-- Transfer
		INSERT INTO #BalanceInfo (Balance, Outstanding, PendingTransfer3rd, TableName)
		SELECT
			ISNULL(SUM(CASE WHEN bettype IN (21008, 21009) THEN 0 ELSE winlost-actual_stake+playercomm END), 0),
			0,
			ISNULL(SUM(CASE WHEN bettype IN (21008, 21009) THEN -(winlost-actual_stake) ELSE 0 END), 0),
			'tblTransfer'
		FROM dbo.Transfer b WITH(NOLOCK)
		WHERE b.custid = @custid
			AND (
				b.winlostdate <= @yesterday
				OR b.bettype > 20000
			)
			AND 1 = CASE WHEN bettype = 19999 AND winlostdate > @moveBetsDay THEN 0 --> new sum
										WHEN bettype = 20000 AND winlostdate > @balanceUpDay THEN 0 --> new bal
										WHEN winlostdate < @balanceUpDay THEN 0 --> old data
								ELSE 1 END

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

	SELECT
		@CustBalance = SUM(Balance),
		@CustOutstanding = -SUM(Outstanding),
		@PendingTransfer3rd = SUM(ISNULL(PendingTransfer3rd, 0))
	FROM #BalanceInfo

	SELECT @User = username, @Credit = credit
	FROM DBCUST.CustDB.dbo.custinfo with (nolock) WHERE custid = @custid AND roleid = 1
  
	IF @amount = 0
		or (@CustBalance >= 0 AND (@Amount <= 0 or @Amount > @CustBalance))
		or (@CustBalance < 0 AND (@Amount >= 0 or @Amount < @CustBalance))
	BEGIN
		SELECT @ErrMsg = case @Language 
		WHEN 'E' then 'Amount to transfer must be between 0 and' + ' ' + convert(VARCHAR(100), -@CustBalance, 2) +'.'
		ELSE CustDB.dbo.f_Get_MsgNamebyMsgID(50005,@Language) + ' ' + convert(VARCHAR(100), -@CustBalance, 2) + '.'
		end		
		SELECT @ErrCode = 104
		RETURN
	END

	SET @FutureCreditBalance = @Credit + @CustBalance + @CustOutstanding - @PendingTransfer3rd - @Amount
	SET @FutureCreditBalance = isnull(@FutureCreditBalance,0)
	----------------------------------------------------------
	SELECT @currency = c.currency,@actualrate = e.actualrate, @currName = e.currency, 
		   @Upline_Username = c.username, @srecommend = c.srecommend, @mrecommend = c.mrecommend
	FROM CustDB.dbo.custinfo c with (NOLOCK) 
		INNER JOIN CustDB.dbo.Exchange e with (NOLOCK) on c.currency = e.exchangeid 
	WHERE custid = @ToCustID AND roleid IN (3,4)

	EXEC Get_Refno_Transid @RefNo = @RefNo OUTPUT
	------------------Insert trans into DB---------------------------------------------------------------
	DECLARE @LogData NVARCHAR(500);
	-- All error messages are the same, so we set it here
	SELECT @ErrMsg = CASE @Language 
						WHEN 'E' THEN 'Transfer failed. Please try again.'
						ELSE CustDB.dbo.f_Get_MsgNamebyMsgID(50006,@Language)
					END
	IF @amount > 0
	BEGIN
		BEGIN TRY
		EXEC Get_Bettrans_TransID @TransID = @TransID_from OUTPUT
		INSERT INTO Transfer 
			(transid, creator, custid, username, refno, transdate, bettype, transdesc, winlost, actual_stake, 
				winlostdate, currency, actualrate, currencyName,recommend, mrecommend, srecommend, 
			scomm, swinlost,ip,statusID,RepUpdateTime)
		VALUES 
			(@TransID_from ,@creator, @ToCustID, @Upline_Username, @RefNo, current_timestamp, 21004, 'From Customer :: ' + @User + CASE WHEN @SubAccID > 0 THEN ' (By ' + @SubAccName + ')' ELSE '' END, 
			@amount, 0,  @WinlostDate, @currency, @actualrate, @currName, 0, @mrecommend, @srecommend, 
			0, 0,@ip,131,SYSDATETIME())
		END TRY
		BEGIN CATCH
				SELECT @ErrCode = 104
			
			----Manually rollback----
				UPDATE dbo.Transfer WITH(ROWLOCK)
				SET	 custid = 0, Winlost = 0, Actual_Stake = 0, RepUpdateTime = SYSDATETIME(), Recommend = 0, MRecommend = 0, SRecommend = 0	
				WHERE transid IN (@TransID_from,@TransID_to)
			
				RETURN
		END	CATCH
		
		---update debit balance
		--EXEC Dot_BalanceUpdDebit @CustID = @CustID, @balance = @amount  
		EXEC Dot_BalanceDebitUpd @CustID = @CustID, @balance = @amount, @type = 2, @IsForced = 1, @errCode = @ErrCode OUTPUT
		IF @ErrCode <> 0
		BEGIN
				SELECT @ErrCode = 104
			
			----Manually rollback----
				UPDATE dbo.Transfer WITH(ROWLOCK)
					SET	 custid = 0, Winlost = 0, Actual_Stake = 0, RepUpdateTime = SYSDATETIME(), Recommend = 0, MRecommend = 0, SRecommend = 0	
				WHERE transid IN (@TransID_from,@TransID_to)
			
				RETURN
		END

		DECLARE @TotalCash1 MONEY 
		EXEC Acc_CustomerSelCash_CaptureBalance @custid = @custid, @TotalCash  = @TotalCash1 OUTPUT
		BEGIN TRY
			EXEC Get_Bettrans_TransID @TransID = @TransID_to OUTPUT
			INSERT INTO Transfer
				(transid, creator, custid, username, refno, transdate, bettype, transdesc, winlost, actual_stake, 
				winlostdate, currency, actualrate, currencyName, recommend, mrecommend, srecommend, 
				scomm, swinlost,ip,statusID, balance, RepUpdateTime)
			VALUES (@TransID_to, @creator, @custid, @User, @RefNo, current_timestamp, 21004, 'To Customer :: ' + @Upline_UserName + CASE WHEN @SubAccID > 0 THEN ' (By ' + @SubAccName + ')' ELSE '' END, 
				0, @amount,  @WinlostDate, @currency,@actualrate,@currName, @member_recommend, @member_mrecommend, @srecommend, 
				0, 0,@ip,131, @TotalCash1, SYSDATETIME())
		END TRY
		BEGIN CATCH
				SELECT @ErrCode = 105			
				
				UPDATE dbo.Transfer WITH(ROWLOCK)
					SET	 custid = 0, Winlost = 0, Actual_Stake = 0, RepUpdateTime = SYSDATETIME(), Recommend = 0, MRecommend = 0, SRecommend = 0	
				WHERE transid IN (@TransID_from,@TransID_to)
				---rollback balance
				--EXEC Dot_BalanceUpdCredit @CustID = @CustID, @balance = @amount 
				EXEC Dot_BalanceCreditUpd @CustID = @CustID, @balance = @amount, @type = 2
				RETURN
		END	CATCH	

			SELECT @LogData = 'Transfer from Customer ' + @User + ' to Upline ' + @Upline_UserName + ' with amount ' + CONVERT(VARCHAR(20), @amount) + ' Ref.No ' + CONVERT(VARCHAR(20), @RefNo)
			IF @CustBalance > 0 and @FutureCreditBalance < 0 
			SELECT @LogData = @LogData + '. The Upline decided to transfer after the warning so the bet credit of this member turned to negative value (' + convert(varchar(100), @FutureCreditBalance, 2) + ') caused by having outstanding balance value ('+ convert(varchar(100), @CustOutstanding, 2) +')  '
	END
	ELSE IF @amount <0 
	BEGIN
		--SET @amount = abs(@amount)
		BEGIN TRY
		EXEC Get_Bettrans_TransID @TransID = @TransID_from OUTPUT
			INSERT INTO Transfer 
				(transid, creator, custid, username, refno, transdate, bettype, transdesc, winlost, actual_stake, 
					winlostdate, currency, actualrate, currencyName, recommend, mrecommend, srecommend, 
				scomm, swinlost,ip,statusID, RepUpdateTime)
			VALUES (@TransID_from, @creator, @ToCustID, @Upline_UserName, @RefNo, current_timestamp, 21004, 'To Customer :: ' + @User + CASE WHEN @SubAccID > 0 THEN ' (By ' + @SubAccName + ')' ELSE '' END, 
				0, abs(@amount), @WinlostDate, @currency, @actualrate,@currName, 0, @mrecommend, @srecommend, 
				0, 0,@ip,131, SYSDATETIME())
		END TRY
		BEGIN CATCH
			SELECT @ErrCode = 106
			
			----Manually rollback----
				UPDATE dbo.Transfer WITH(ROWLOCK)
					SET	 custid = 0, Winlost = 0, Actual_Stake = 0, RepUpdateTime = SYSDATETIME(), Recommend = 0, MRecommend = 0, SRecommend = 0	
				WHERE transid IN (@TransID_from,@TransID_to)
			
			RETURN
		END	CATCH	

		DECLARE @TotalCash3 MONEY 
		EXEC Acc_CustomerSelCash_CaptureBalance @custid = @custid, @TotalCash  = @TotalCash3 OUTPUT
		BEGIN TRY
			EXEC Get_Bettrans_TransID @TransID = @TransID_to OUTPUT
			INSERT INTO Transfer
				(transid, creator, custid, username, refno, transdate, bettype, transdesc, winlost, actual_stake, 
					winlostdate, currency, actualrate, currencyName, recommend, mrecommend, srecommend, 
				scomm, swinlost,ip,statusID, balance, RepUpdateTime)
			VALUES 
				(@TransID_to, @creator, @custid, @User, @RefNo, current_timestamp, 21004, 'From Customer :: ' + @Upline_UserName + CASE WHEN @SubAccID > 0 THEN ' (By ' + @SubAccName + ')' ELSE '' END, 
				abs(@amount), 0, @WinlostDate, @currency, @actualrate, @currName, @Member_recommend, @member_mrecommend, @srecommend, 
				0, 0,@ip,131,@TotalCash3, SYSDATETIME())
		END TRY
		BEGIN CATCH
			SELECT @ErrCode = 107
			----Manually rollback----
			UPDATE dbo.Transfer WITH(ROWLOCK)
				SET	 custid = 0, Winlost = 0, Actual_Stake = 0, RepUpdateTime = SYSDATETIME(), Recommend = 0, MRecommend = 0, SRecommend = 0	
			WHERE transid IN (@TransID_from,@TransID_to)		

			RETURN 
		END CATCH
		---update credit balance
		SELECT @ABSamount = abs(@amount)
		--EXEC Dot_BalanceUpdCredit @CustID = @CustID, @balance = @ABSamount 
		EXEC Dot_BalanceCreditUpd @CustID = @CustID, @balance = @ABSamount, @type = 2
								
		SELECT @LogData = 'Transfer from Upline ' + @Upline_UserName + ' to Customer ' + @User + ' with amount ' + CONVERT(VARCHAR(20), @amount) + ' Ref.No ' + CONVERT(VARCHAR(20), @RefNo)
				
	END		

	DECLARE @isResetYesterdayBalance BIT, @ErrCode_ResetYesterdayBalance BIT, @YesterdayBalance MONEY
	-- reset yesterday balance for live casino				
	EXEC Acc_BalanceGameResetYesterday @CustID = @CustID, @isResetYesterdayBalance = @isResetYesterdayBalance OUTPUT, @YesterdayBalance = @YesterdayBalance	 OUTPUT, @ErrCode = @ErrCode_ResetYesterdayBalance OUTPUT	
	SELECT @LogData = @LogData + CASE WHEN @isResetYesterdayBalance = 1 THEN 
										CASE WHEN @ErrCode_ResetYesterdayBalance = 0 THEN '. (ResetGameBalance = suscess, YesterdayBalance =' + CAST(@YesterdayBalance AS VARCHAR(50)) + ')' 
										ELSE '. (ResetGameBalance = fail)' END		
								ELSE '' END			

	SELECT @ErrMsg = ''

	---------------------------------------------------------------------------------------------------
	-- ***Check Sub-Account***
	IF @SubAccID > 0 
	BEGIN	
		SET @LogData = 'SubAccount:' +  coalesce(@SubAccName,space(1)) + ' - ' + @LogData
	END
	---------------------------
	DECLARE @procName VARCHAR(100)
	SELECT  @procName = OBJECT_NAME(@@PROCID)

	SELECT  @LogData = @LogData + ' SPName: ' + @procName

	BEGIN TRY
		EXEC DBLOG.bodb_customerlog.dbo.WriteLog_UserLog_Transfer 
						@UserID = @creator, 
						@FromCustID = @FromCustID, 
						@ToCustID =  @ToCustID, 
						@IP = @IP, 
						@Doing = @LogData
	END TRY
	BEGIN CATCH
		SELECT @LogData = @LogData + ' ErrMsg: ' + ERROR_MESSAGE()
	
		EXEC bodb_customerlog.dbo.WriteLog_UserLog_Transfer 
						@UserID = @creator, 
						@FromCustID = @FromCustID, 
						@ToCustID =  @ToCustID, 
						@IP = @IP, 
						@Doing = @LogData
	END CATCH

	DROP TABLE #SportBettype
	DROP TABLE #BalanceInfo
	
END
GO