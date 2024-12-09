/*<info serverAlias="DBSIC-bodb02" executers="wsv_alp" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE  [dbo].[Age_Transfer_Auto_InsClearBalance_DirectMember]
	@FromCustID int, --Agent ID here  
	@ToCustIDs varchar(4000), 
	@DirectMember INT,
	@creator int,  
	@Language varchar(2)= 'E',  
	@IP varchar(45)='',
	@ErrCode int = 0 OUTPUT,  
	@ErrMsg nvarchar(4000) = '' OUTPUT,  
	@CustStatus varchar(50)='',
	@IsAllDayBalTransfer BIT = 0
AS  
/*
	Created:20241206@Helen 
	Task: Auto transfer for direct member - Alpha
	DB: DBSIC/bodb02
	Original: get reference code from Age_Transfer_InsClearBalance_Ag

	Revisions:
		- 20241206@Helen: Alpha - Offer Direct Member for Super/Master [Redmine: #211969]

	Param's Explanation:
		• @FromCustID: list from custid
		• @ToCustIDs: list to custid
		  @IsAllDayBalTransfer: allow transfer many times per day
		• @DirectMember: - 3: Master Direct Member;	- 4: Super Direct Member

*/
BEGIN
	SET NOCOUNT ON  

	DECLARE @LogData NVARCHAR(500), @PairStatus VARCHAR(15), @Result nvarchar(4000);
	DECLARE @custid int  
	DECLARE @currency INT, @actualrate FLOAT, @currName NVARCHAR(10)    
	DECLARE @User NVARCHAR(50)  
	DECLARE @RefNo BIGINT, @ToCustID INT, @Amount FLOAT, @MRecommend1 INT, @srecommend1 INT  
	DECLARE @Outstanding MONEY, @credit MONEY, @FutureBetCredit MONEY, @ABSamount MONEY, @PendingTransfer3rd MONEY

	DECLARE @UplineUserName NVARCHAR(50), @UplineID INT, @TransID_from BIGINT, @TransID_to BIGINT, @recommend_member INT, @mrecommend_member INT, @srecommend_member INT
	
	-- TODO: support auto clear balance
	DECLARE @tblResultMember TABLE(CustId INT PRIMARY KEY, UserName VARCHAR(50), MsgId INT, ErrType VARCHAR(50), ErrMsg NVARCHAR(4000), RefNo BIGINT);
	INSERT INTO @tblResultMember(CustId)
	SELECT DISTINCT t.value
	FROM STRING_SPLIT(@ToCustIDs, ',') AS t;

	EXEC DBCUST.CustDB.dbo.Age_Transfer_CheckTransferOption   
		@CustID = @FromCustID,  
		@ErrMsg = @ErrMsg OUTPUT,  
		@ErrCode = @ErrCode OUTPUT,  
		@Language = @Language  
   
	IF @ErrCode > 0  
	BEGIN  
		SET @Result = (SELECT 50023 AS MsgId, 'TransferOption' AS ErrType, @ErrMsg AS ErrMsg FOR JSON PATH, WITHOUT_ARRAY_WRAPPER)
		EXEC dbo.Age_ClearBalanceCust_Process_StatusUpd @FromCustID = @FromCustID, @ToCustIds = @ToCustIds
			,@Status='Failed', @Result = @Result;
		RETURN
	END

	SELECT @UplineUserName = ci.username , @currency = ci.currency, @actualrate = e.actualrate, @currName = e.currency
		, @MRecommend1 = ci.mrecommend, @srecommend1 = ci.srecommend  
	FROM CustDB.dbo.custinfo ci (nolock) 
		INNER JOIN CustDB.dbo.Exchange e with (NOLOCK) on ci.currency = e.exchangeid 
	WHERE custid = @FromCustID AND @DirectMember IN (-3,-4)
	
 	IF @UplineUserName IS NULL
	BEGIN  
		select @ErrCode = 102  
		Select @ErrMsg = case @Language   
			when 'E' then 'Customer does not exist.'  
		   ELSE CustDB.dbo.f_Get_MsgNamebyMsgID(40014,@Language)
			end    

		SET @Result = (SELECT 40014 AS MsgId, 'NotFound' AS ErrType, @ErrMsg AS ErrMsg FOR JSON PATH, WITHOUT_ARRAY_WRAPPER)
		EXEC dbo.Age_ClearBalanceCust_Process_StatusUpd @FromCustID = @FromCustID, @ToCustIds = @ToCustIDs
			,@Status='Failed', @Result = @Result;
		
		RETURN
	END  
  
	SELECT @UplineID = @FromCustID  
	
	SELECT @recommend_member = @DirectMember
		, @mrecommend_member = IIF (@DirectMember = -4 , -4 , @MRecommend1)
		, @srecommend_member = @srecommend1

	---- #1 CHECK UM TRANSFER FUNCTION
	DECLARE @ToTimeConfig DATETIME;
	EXEC DBCUST.CUSTDB.dbo.Acc_Transfer_CheckUM  
		@CustID = @UplineID
		,@Language = @Language
		,@ErrMsg = @ErrMsg OUTPUT 
		,@ErrCode = @ErrCode OUTPUT
		,@ToTimeConfig = @ToTimeConfig OUTPUT
	 
	IF @ErrCode <> 0  -- Function Transfer is under UM 
	BEGIN	
		SET @Result = (SELECT 50024 AS MsgId,'TransferUM' AS ErrType, @ErrMsg AS ErrMsg, 
			@ToTimeConfig AS ToTime FOR JSON PATH, WITHOUT_ARRAY_WRAPPER)
		EXEC dbo.Age_ClearBalanceCust_Process_StatusUpd @FromCustID = @FromCustID, @ToCustIds = @ToCustIDs
			,@Status='Pending', @Result = @Result;
		RETURN
	END		

	---- #2 CHECK FLAG ISTRANSFERRING = 1 THEN RAISE ERROR
	EXEC DBCUST.CUSTDB.dbo.Acc_Transfer_CheckRunningByCust  
			@CustID = @UplineID
			,@Language = @Language
			,@ErrMsg = @ErrMsg OUTPUT 
			,@ErrCode = @ErrCode OUTPUT
		 
	IF @ErrCode <> 0  -- the auto transfer job is running this custid
	BEGIN
		SET @Result = (SELECT 50026 AS MsgId, 'AccTransfering' AS ErrType, @ErrMsg AS ErrMsg FOR JSON PATH, WITHOUT_ARRAY_WRAPPER)
		EXEC dbo.Age_ClearBalanceCust_Process_StatusUpd @FromCustID = @FromCustID, @ToCustIds = @ToCustIDs
			,@Status='Failed', @Result = @Result;
		
		RETURN
	END
	-- get move bet date
	DECLARE @balanceUpDay SMALLDATETIME, @moveBetsDay SMALLDATETIME
	DECLARE @IsDiff	SMALLINT = 1, @NewMoveBetDate SMALLDATETIME = NULL,@NewBalanceUpDate SMALLDATETIME = NULL

	--TODO: Get MBU days
	EXEC dbo.NAP_Admin_GetMovebetDate @MovebetDate = @moveBetsDay OUTPUT
	EXEC dbo.NAP_Admin_GetBalanceUpDate @BalanceUpDate = @balanceUpDay OUTPUT

	---Calculated Balance saved in Temp Table  @Phuong09152008
	CREATE TABLE #Member (
						rIdx INT IDENTITY(1,1),
						custid int PRIMARY KEY NONCLUSTERED,
						memberName nvarchar(50),	
						memberBalance money DEFAULT 0,
						memberOutstanding money DEFAULT 0,
						memberCredit money DEFAULT 0,
						memberPendingTransfer3rd money DEFAULT 0,
						INDEX CIX_rIDx CLUSTERED (rIdx)
					); 
 
	DECLARE @WinlostDate datetime
	SELECT  @WinlostDate = convert(nvarchar(10), current_timestamp,120)

	DECLARE @yesterday SMALLDATETIME
	SELECT  @yesterday = DATEADD(DAY, -1, CONVERT(DATE, GETDATE()))
 
		-- Get bettype --
	DECLARE @isTest BIT = 0
	SELECT  @isTest = dbo.f_CheckSPVersion(@@PROCID)
	
	CREATE TABLE #SportBettype (bettype INT, RefTable TINYINT)
	INSERT INTO #SportBettype (bettype, RefTable)
	SELECT bettype, RefTable FROM dbo.f_SportBettypeMatrix_Sel (0, 0, 0, 2, '', '', @isTest)

	CREATE TABLE #BalanceInfo (CustId INT, Balance MONEY, Outstanding MONEY, PendingTransfer3rd MONEY, TableName VARCHAR(50))

	CREATE TABLE #custid (CustId INT)

	--TODO: 
	INSERT INTO #custid (CustId)
	SELECT DISTINCT CONVERT(INT, value) AS CustId
	FROM STRING_SPLIT(@ToCustIDs, ',')

	/* *********** Calculating balance *********** */
	--Yesterday Balance  
	-- bettransRnG
	INSERT INTO #BalanceInfo (CustId, Balance, Outstanding)
	SELECT
		b.custid,
		ISNULL(SUM(CASE WHEN statusID IN (111, 112, 113) THEN winlost-actual_stake+playercomm ELSE 0 END), 0),
		ISNULL(SUM(CASE WHEN statusID IN (0, 1) THEN ABS(actual_stake) ELSE 0 END), 0)
	FROM dbo.bettransRnG b WITH (NOLOCK) 
		INNER JOIN #custid c ON b.custid = c.CustId
	WHERE  statusID IN (0, 1) OR winlostdate = @yesterday
	GROUP BY b.custid

	-- bettransLC
	INSERT INTO #BalanceInfo (CustId, Balance, Outstanding)
	SELECT
		b.custid,
		ISNULL(SUM(CASE WHEN statusID IN (111, 112, 113) THEN winlost-actual_stake+playercomm ELSE 0 END), 0),
		ISNULL(SUM(CASE WHEN statusID IN (0, 1) THEN ABS(actual_stake) ELSE 0 END), 0)
	FROM dbo.bettransLC b WITH (NOLOCK) 
		INNER JOIN #custid c ON b.custid = c.CustId
	WHERE statusID IN (0, 1)
			OR winlostdate = @yesterday
	GROUP BY b.custid
	
	-- translog
	INSERT INTO #BalanceInfo (CustId, Balance, Outstanding)
	SELECT
		t.custid,
		0,
		ISNULL(SUM(ABS(actual_stake)), 0)
	FROM dbo.translog t WITH (NOLOCK) 
		INNER JOIN #custid c ON t.custid = c.CustId
	WHERE statusID IN (0, 1)
	GROUP BY t.custid

	-- bettrans
	INSERT INTO #BalanceInfo (CustId, Balance, Outstanding)
	SELECT
		b.custid,
		0,
		ISNULL(SUM(ABS(actual_stake)), 0)
	FROM dbo.bettrans b WITH(NOLOCK)
		INNER JOIN #custid c ON b.custid = c.CustId
	WHERE b.ruben = 0
		AND NOT EXISTS (SELECT TOP 1 1 FROM #SportBettype s WHERE s.Bettype = b.bettype AND s.RefTable <> 0)
	GROUP BY b.custid

	WHILE (@IsDiff = 1)
	BEGIN

		DELETE FROM #BalanceInfo WHERE TableName IN ('tblBettrans','tblTransfer')

			--tblBettrans
		INSERT INTO #BalanceInfo (CustId, Balance, Outstanding, PendingTransfer3rd, TableName)
		SELECT
			b.custid,
			ISNULL(SUM(winlost-actual_stake+playercomm ), 0),
			0,
			0,
			'tblBettrans'
		FROM dbo.bettrans b WITH(NOLOCK)
			INNER JOIN #custid c ON b.custid = c.CustId
		WHERE b.statusID IN (111, 112, 113)
			AND (
				b.winlostdate < @yesterday
				OR (
					winlostdate = @yesterday
					AND NOT EXISTS (SELECT TOP 1 1 FROM #SportBettype s WHERE s.Bettype = b.bettype AND s.RefTable IN (1, 2))
				)
			)
			AND winlostdate > @moveBetsDay
		GROUP BY b.custid
				
		--tblTransfer
		INSERT INTO #BalanceInfo (CustId, Balance, Outstanding, PendingTransfer3rd, TableName)
			SELECT
				b.custid,
				ISNULL(SUM(CASE WHEN bettype IN (21008, 21009) THEN 0 ELSE winlost-actual_stake+playercomm END), 0),
				0,
				ISNULL(SUM(CASE WHEN bettype IN (21008, 21009) THEN -(winlost-actual_stake) ELSE 0 END), 0),
				'tblTransfer'
			FROM dbo.Transfer b WITH(NOLOCK)	
				INNER JOIN #custid c ON c.CustId = b.CustId
			WHERE  (
					b.winlostdate <= @yesterday
					OR b.bettype > 20000
				)
				AND 1 = CASE WHEN bettype = 19999 AND winlostdate > @moveBetsDay THEN 0 --> new sum
										WHEN bettype = 20000 AND winlostdate > @balanceUpDay THEN 0 --> new bal
										WHEN winlostdate < @balanceUpDay THEN 0 --> old data
								ELSE 1 END
			GROUP BY b.custid
		
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

	/* *********** End Calculating balance *********** */

	/* Filtering input custids */
	INSERT INTO #Member (custid, memberName, memberBalance, memberOutstanding, memberCredit, memberPendingTransfer3rd)
	SELECT c.CustId, '', SUM(ISNULL(b.Balance,0)), SUM(ISNULL(b.Outstanding,0)), 0, SUM(ISNULL(PendingTransfer3rd, 0))
	FROM #custid c
	LEFT JOIN #BalanceInfo b ON b.CustId = c.CustId
	GROUP BY c.CustId
	/* End Filtering input custids */

	IF NOT EXISTS (SELECT 1 FROM #Member WHERE memberBalance <> 0)
	BEGIN
		SELECT @ErrMsg = CASE @Language   
							WHEN 'E' THEN 'Cannot transfer because all downlines'' balance is 0!' 
							ELSE CustDB.dbo.f_Get_MsgNamebyMsgID(50002,@Language)
							END, 
						@ErrCode = 103
			;
		
		SET @Result = (SELECT 50025 AS MsgId, 'BalanceZero' AS ErrType, @ErrMsg AS ErrMsg FOR JSON PATH, WITHOUT_ARRAY_WRAPPER)
		EXEC dbo.Age_ClearBalanceCust_Process_StatusUpd @FromCustID = @FromCustID, @ToCustIds = @ToCustIDs
			,@Status='Ignored', @Result = @Result;
		
		RETURN
	END
 
	--Update member credit of table #Member
	UPDATE #Member 
	SET #Member.memberCredit = c.credit, #Member.memberName = c.username 
	FROM #Member 
	INNER JOIN DBCUST.CustDB.dbo.custinfo c WITH (NOLOCK) ON #Member.custid = c.custid
 
	DECLARE @procName VARCHAR(100)
	SELECT  @procName = OBJECT_NAME(@@PROCID)
 
	DECLARE @ErrItems nvarchar(4000);
	DECLARE @isSucc varchar(10)
 
	SELECT @isSucc='false'  
  
	DECLARE @rCount INT = 1;
	WHILE EXISTS(SELECT 1 FROM #Member WHERE rIdx = @rCount)
	BEGIN  
		-- Reset for each pair
		SELECT @ErrCode = 0,
			@ErrMsg = '';
		SELECT @TransID_from =NULL, @TransID_to = NULL, @RefNo = NULL

		BEGIN TRY
			SELECT TOP(1)
				@custID					= custid
				, @user					= memberName			
				, @amount				= memberBalance
				, @Outstanding			= memberOutstanding
				, @credit				= memberCredit
				, @PendingTransfer3rd	= memberPendingTransfer3rd
			FROM #Member
			WHERE rIdx = @rCount

			-- SET username
			UPDATE @tblResultMember
			SET UserName = @User
			WHERE CustId = @custid;	

			IF (@amount = 0)
			BEGIN
				UPDATE @tblResultMember
				SET MsgId = 50025, ErrType = 'BalanceZero', ErrMsg = 'Cannot transfer because balance is 0!'
				WHERE CustId = @custid;
				GOTO NEXT_PAIR;
			END
	
			--AutoJob Transfer: START a Pair waiting to Processing
			EXEC dbo.Age_ClearBalanceCust_Process_StatusUpd @FromCustID = @FromCustID, @ToCustIds = @custid
				,@Status='Processing', @Amount=@Amount
				,@ErrCode = @ErrCode OUTPUT
				,@ErrMsg = @ErrMsg OUTPUT
			;
			-- CHECK: Cancelling
			IF @ErrCode > 0
			BEGIN
				UPDATE @tblResultMember
				SET MsgId = @ErrCode, ErrType = 'TransferStatus', ErrMsg = @ErrMsg
				WHERE CustId = @custid;	
				GOTO NEXT_PAIR;
			END
			
			------------------Gen refno---------------------------------------------------------------  
			EXEC Get_Refno_Transid @RefNo = @RefNo OUTPUT

			-- TODO: AutoTransfer - Check cancelled
			EXEC dbo.Age_ClearBalanceCust_Process_StatusUpd @FromCustID = @FromCustID, @ToCustIds = @custid
				,@Status='Processing'
				,@ErrCode = @ErrCode OUTPUT
				,@ErrMsg = @ErrMsg OUTPUT
			;
			-- CHECK: Cancelling
			IF @ErrCode > 0
			BEGIN
				UPDATE @tblResultMember
				SET MsgId = @ErrCode, ErrType = 'TransferStatus', ErrMsg = @ErrMsg
				WHERE CustId = @custid;	
				GOTO NEXT_PAIR;
			END
			
			--TODO: Set default ERROR for MANUAL transfer
			DECLARE @extraTransDesc VARCHAR(100);
			SELECT @ErrCode		= 105
					,@ErrMsg	= CASE @Language
									WHEN 'E'
										THEN 'Clear balance failed. Please try again.'
									ELSE CustDB.[dbo].[f_Get_MsgNamebyMsgID](50003, @Language)
								END
					, @extraTransDesc = ' (added via the Auto Transfer process)'

			------------------Insert trans into transfer---------------------------------------------------------------  
			IF (@amount > 0)  
			BEGIN
				BEGIN TRY
					EXEC Get_Bettrans_TransID @TransID = @TransID_from OUTPUT
					INSERT INTO Transfer   
						(transid, creator, custid, username, refno, transdate, bettype, transdesc, winlost, actual_stake,   
							winlostdate, currency, actualrate, currencyName, recommend, mrecommend, srecommend, scomm, swinlost,ip,statusID, RepUpdateTime)  
					VALUES 
						(@TransID_from, @creator, @UplineID, @UplineUserName, @RefNo, CURRENT_TIMESTAMP, 21004, 'From Customer :: ' + @User + @extraTransDesc, 
							@amount, 0, @WinlostDate, @currency, @actualrate, @currName, 0, @MRecommend1, @srecommend1, 0, 0,@ip,131, SYSDATETIME())  
				
				END TRY
				BEGIN CATCH
					--Manually rollback
					UPDATE dbo.Transfer WITH(ROWLOCK)
					SET	 custid = 0, Winlost = 0, Actual_Stake = 0, RepUpdateTime = SYSDATETIME(), Recommend = 0, MRecommend = 0, SRecommend = 0	
					WHERE transid IN (@TransID_from, @TransID_to)
							
					--AutoJob Transfer
					UPDATE @tblResultMember
					SET MsgId = 50027, ErrType = 'DBIssue', ErrMsg = ERROR_MESSAGE()
					WHERE CustID = @custid;

					GOTO NEXT_PAIR;
				END CATCH 
		
				---update debit balance
				--EXEC Dot_BalanceUpdDebit @CustID = @CustID, @balance = @amount  
				EXEC Dot_BalanceDebitUpd @CustID = @CustID, @balance = @amount, @type = 2, @IsForced = 1, @errCode = @ErrCode OUTPUT
				IF @ErrCode <> 0
				BEGIN
					--Manually rollback
					UPDATE dbo.Transfer WITH(ROWLOCK)
					SET	 custid = 0, Winlost = 0, Actual_Stake = 0, RepUpdateTime = SYSDATETIME(), Recommend = 0, MRecommend = 0, SRecommend = 0	
					WHERE transid IN (@TransID_from, @TransID_to)
					--AutoJob Transfer
					UPDATE @tblResultMember
					SET MsgId = 50027, ErrType = 'DBIssue', ErrMsg = CONCAT('Dot_BalanceDebitUpd @ErrCode=', @ErrCode)
					WHERE CustID = @custid;

					GOTO NEXT_PAIR;
				END
		
				DECLARE @TotalCash1 MONEY 
				EXEC Acc_CustomerSelCash_CaptureBalance @custid = @custid, @TotalCash  = @TotalCash1 OUTPUT
				BEGIN TRY
					EXEC Get_Bettrans_TransID @TransID = @TransID_to OUTPUT
					INSERT INTO Transfer  
						(transid, creator, custid, username, refno, transdate, bettype, transdesc, winlost, actual_stake,   
							winlostdate, currency, actualrate,currencyName, recommend, mrecommend, srecommend, scomm, swinlost,ip,statusID, balance, RepUpdateTime)  
					VALUES 
						(@TransID_to, @creator, @custid, @User, @RefNo, CURRENT_TIMESTAMP, 21004, 'To Customer :: ' + @UplineUserName + @extraTransDesc, 
							0, @amount,  @WinlostDate, @currency, @actualrate, @currName, @DirectMember, @MRecommend1, @srecommend1, 0, 0,@ip,131, @TotalCash1, SYSDATETIME())  
				END TRY
				BEGIN CATCH
					--Manually rollback
					UPDATE dbo.Transfer WITH(ROWLOCK)
					SET	 custid = 0, Winlost = 0, Actual_Stake = 0, RepUpdateTime = SYSDATETIME(), Recommend = 0, MRecommend = 0, SRecommend = 0	
					WHERE transid IN (@TransID_from, @TransID_to)
					
					-- rollback balance
					--EXEC Dot_BalanceUpdCredit @CustID = @CustID, @balance = @amount  
					EXEC Dot_BalanceCreditUpd @CustID = @CustID, @balance = @amount, @type = 2;
				
					--AutoJob Transfer
					UPDATE @tblResultMember
					SET MsgId = 50027, ErrType = 'DBIssue', ErrMsg = ERROR_MESSAGE()
					WHERE CustID = @custid;

					GOTO NEXT_PAIR;
				END CATCH						
				
				--AutoJob Transfer: Completed
				UPDATE @tblResultMember
				SET RefNo = @RefNo
				WHERE CustID = @custid;

				--Add writelog for each amt transfered - Vinh 20080629  
				SELECT @LogData = 'Transfer from Customer ' + @User + ' to Upline ' + @UplineUserName + ' with amount ' + convert(varchar(20), @amount) + ' Ref.No ' + convert(varchar(20), @RefNo)
		
				SET @FutureBetCredit = @credit - @outstanding - @PendingTransfer3rd
		
				IF @FutureBetCredit < 0 
				SELECT @LogData = @LogData + '. The agent decided to transfer after the warning so the bet credit of this member turned to negative value (' + convert(varchar(100), @FutureBetCredit, 2) + ') caused by having outstanding balance value ('+ convert(varchar(100), @outstanding, 2) +')  '
			END  
			ELSE IF(@amount < 0)  
			BEGIN  

				--SET @amount = abs(@amount)   
				BEGIN TRY
					EXEC Get_Bettrans_TransID @TransID = @TransID_from OUTPUT
					INSERT INTO Transfer   
						(transid, creator, custid, username, refno, transdate, bettype, transdesc, winlost, actual_stake,   
							winlostdate, currency,actualrate, currencyName, recommend, mrecommend, srecommend, scomm, swinlost,ip,statusID, RepUpdateTime)  
					VALUES 
						(@TransID_from, @creator, @UplineID, @UplineUserName, @RefNo, CURRENT_TIMESTAMP, 21004, 'To Customer :: ' + @User + @extraTransDesc, 
							0, abs(@amount),@WinlostDate, @currency, @actualrate, @currName, 0, @MRecommend1, @srecommend1, 0, 0,@ip,131, SYSDATETIME())  
				
				END TRY
				BEGIN  CATCH
					--Manually rollback
					UPDATE dbo.Transfer WITH(ROWLOCK)
					SET	 custid = 0, Winlost = 0, Actual_Stake = 0, RepUpdateTime = SYSDATETIME(), Recommend = 0, MRecommend = 0, SRecommend = 0	
					WHERE transid IN (@TransID_from, @TransID_to)
									
					--AutoJob Transfer
					UPDATE @tblResultMember
					SET MsgId = 50027, ErrType = 'DBIssue', ErrMsg = ERROR_MESSAGE()
					WHERE CustID = @custid;

					GOTO NEXT_PAIR;
				END CATCH 

				DECLARE @TotalCash3 MONEY 
				EXEC Acc_CustomerSelCash_CaptureBalance @custid = @custid, @TotalCash  = @TotalCash3 OUTPUT
				BEGIN TRY
					EXEC Get_Bettrans_TransID @TransID = @TransID_to OUTPUT
					INSERT INTO Transfer  
						(transid, creator, custid, username, refno, transdate, bettype, transdesc, winlost, actual_stake,   
							winlostdate, currency, actualrate, currencyName, recommend, mrecommend, srecommend, scomm, swinlost,ip,statusID, balance, RepUpdateTime)  
					VALUES 
						(@TransID_to, @creator, @custid, @User, @RefNo, CURRENT_TIMESTAMP, 21004, 'From Customer :: ' + @UplineUserName + @extraTransDesc, 
							abs(@amount), 0, @WinlostDate, @currency, @actualrate, @currName, @DirectMember, @MRecommend1, @srecommend1, 0, 0,@ip,131, @TotalCash3, SYSDATETIME())  
				END TRY 
				
				BEGIN CATCH
					--Manually rollback
					UPDATE dbo.Transfer WITH(ROWLOCK)
					SET	 custid = 0, Winlost = 0, Actual_Stake = 0, RepUpdateTime = SYSDATETIME(), Recommend = 0, MRecommend = 0, SRecommend = 0	
					WHERE transid IN (@TransID_from, @TransID_to)
					
					--AutoJob Transfer
					UPDATE @tblResultMember
					SET MsgId = 50027, ErrType = 'DBIssue', ErrMsg = ERROR_MESSAGE()
					WHERE CustID = @custid;

					GOTO NEXT_PAIR;
				END CATCH
		
				--AutoJob Transfer: Completed
				UPDATE @tblResultMember
				SET RefNo = @RefNo
				WHERE CustID = @custid;

				---update credit balance 
				SELECT @ABSamount = abs(@amount)  
				--EXEC Dot_BalanceUpdCredit @CustID = @CustID, @balance = @ABSamount	
				EXEC Dot_BalanceCreditUpd @CustID = @CustID, @balance = @ABSamount, @type = 2
				--Add writelog for each amt transfered - Vinh 20080629  
				SELECT @LogData = 'Transfer from Upline ' + @UplineUserName + ' to Customer ' + @User + ' with amount ' + convert(varchar(20), @amount) + ' Ref.No ' + convert(varchar(20), @RefNo) 
		
			END  
			---------------------------------------------------------------------------------------------------

			DECLARE @isResetYesterdayBalance BIT, @ErrCode_ResetYesterdayBalance BIT, @YesterdayBalance MONEY
			-- reset yesterday balance for live casino				
			EXEC Acc_BalanceGameResetYesterday @CustID = @CustID, @isResetYesterdayBalance = @isResetYesterdayBalance OUTPUT, @YesterdayBalance = @YesterdayBalance	 OUTPUT, @ErrCode = @ErrCode_ResetYesterdayBalance OUTPUT	
			Select @LogData = @LogData + CASE WHEN @isResetYesterdayBalance = 1 THEN 
												CASE WHEN @ErrCode_ResetYesterdayBalance = 0 THEN '. (ResetGameBalance = suscess, YesterdayBalance =' + CAST(@YesterdayBalance AS VARCHAR(50)) + ')' 
												ELSE '. (ResetGameBalance = fail)' END		
										ELSE '' END			
							
			SELECT @ErrCode = 0  
			SELECT @ErrMsg = ''  
     
			SET @isSucc='true'

			SELECT @LogData = @LogData + ' SPName: ' + @procName
		
			BEGIN TRY	
				EXEC DBLOG.bodb_customerlog.dbo.WriteLog_UserLog_Transfer 
										@UserID		= @creator, 
										@FromCustID = @FromCustID, 
										@ToCustID	= @custID, 
										@IP			= @IP, 
										@Doing		= @LogData 
			END TRY
			BEGIN CATCH
				SELECT @LogData = @LogData + ' ErrMsg: ' + ERROR_MESSAGE()
			
				EXEC bodb_customerlog.dbo.WriteLog_UserLog_Transfer 
									@UserID		= @creator, 
									@FromCustID = @FromCustID, 
									@ToCustID	= @custID, 
									@IP			= @IP, 
									@Doing		= @LogData
			END CATCH
	  
		END TRY
		BEGIN CATCH
			--Exception
			UPDATE @tblResultMember
			SET MsgId = 50027, ErrType = 'DBIssue', ErrMsg = ERROR_MESSAGE()
			WHERE CustID = @custid;
		END CATCH

		NEXT_PAIR:
		
		SELECT @Result = (SELECT MsgId, ErrType, ErrMsg, RefNo FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
			@PairStatus = CASE WHEN RefNo > 0 THEN 'Completed' ELSE 
				CASE WHEN ErrType = 'BalanceZero' THEN 'Ignored' ELSE 'Failed' END 
			END
		FROM @tblResultMember 
		WHERE CustId=@CustId
		;
		EXEC dbo.Age_ClearBalanceCust_Process_StatusUpd @FromCustID = @FromCustID, @ToCustIds = @custid
			,@Status=@PairStatus, @Result = @Result;
		
		SET @rCount += 1;
	END  
 
	DROP TABLE #Member  

END		
GO