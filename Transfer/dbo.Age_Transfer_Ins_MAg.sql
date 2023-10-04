/*<info serverAlias="DBCTG-bodb02,DBSIC-bodb02" executers="bodbDownlineNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE  [dbo].[Age_Transfer_Ins_MAg]
	@MasterID int,
	@ToCustIDs varchar(4000),
	@SuperIDsTransferTotal VARCHAR(50)='', 
	@creator int,
	@FullTransfer bit = 1,
	@AmtTrans money = 0,
	@Language varchar(2)= 'E',
	@SubAccID int = 0, --Sub-AccountID
	@IP varchar(45)='',
	@ErrCode int = 0 OUTPUT,
	@ErrMsg nvarchar(4000) = '' OUTPUT,	
	@CustStatus varchar(50)='',
	@IsAutoTransfer BIT = 0
AS
/*
Created: 
Task: Transfer
DB: DBTXN/bodb02
Original: Age_Transfer_In

Revisions:
	- 20090318@Phuc: Korean language.
	- 20090417@PhuongDao: Allow some masters to transfer total balance including today balance 
	- 20090729@Phuc: Write log subaccname instead of subaccid.
	- 20090818@Phuc: check page access and check upline closed first(call Age_CustSubCheckPageAccess)
	- 20091003@Kiwi: Modify Write log function
	- 20091125@Kiwi: Remove comstatus because it's no used.
	- 20100424@Henry: insert data to column StatusID of Bettrans (StatusID = 131 for bettype 103)
	- 20100611@Henry: Write exact amount to log when transferring
	- 20101224@Johnson: Apply new arrange of bettype
	- 20120104@Lukas: modify to filter by 'enabled' status
	- 20120202@Jamie:Change transfer time to 12pm to 11:59pm instead of 12pm to 10pm ( 9h59pm)
	- 20121128@Elodie: Get an error message from f_Get_MsgNameByMsgID function by language
	- 20130201@Johnson: Write log into DBTXN if failure DBLOG server
	- 20131108@Elodie: Splitting bodb02 into CustDB (Call CustInfo, Exchange, Age_Transfer_CheckTransferOption by link database)
	- 20150606@Kathy: Migrate custDB to new server DBCust [Redmine:#36216]
	- 20160127@Kathy: get balance from bettransRNG & bettransLC [Redmine:#50674]
	- 20160815@Patrick: Allow SMA to transfer in 24 hours [Redmine:#61626]
	- 20170609@Percy:
		1. Re-check [Allow SMA to transfer in 24 hours]: apply general sp Acc_CheckProcessingData [RedmineID: #78487]
		2. Change way to calculate balance [RedmineID: #74291]
	- 20170831@Percy: Add SP Name into log [RedmineID: #80978]
	- 20200602@Percy: Separate PendingTransfer3rd from Cash and Balance [RedmineID: #135200]
	- 20200821@Sophia: prevent duplicated transfer [Redmine: #137141]
	- 20200821@Sophia: Check UM Transfer Function [Redmine: #136992]
	- 20201005@Danny: Convert Ipv6 to dummy IPv4 [Redmine: #142511]
	- 20201015@Malcolm : Add sub account information when transfering [RedmineId : #143478]
	- 20201228@Danny: Capture total cash before transfering  [Redmine: #146038]
	- 20210603@Sol: Alpha - All Sites - Lock account & indirect close account - [RedmineID: #148600]
	- 20210723@Evan: Transfer all pages work incorrect with disabled account [RedmineID: #158813]
	- 20210505@Sol: NAP - Alpha - Allow more time for transfer - [Redmine: #149927]
	- 20210817@Sophia: Fix overflow Refno [Redmine: #160262]
	- 20211111@Evan: Split transfer tickets out of bettrans - [Redmine: #164196]
	- 20220315@Evan: SQL Server Upgrade STRING_SPLIT [Redmine: #168783]
	- 20220721@Danny: get transid and refno with new generation [Redmine: #175670]
	- 20230227@Evan: Balance-Up support transfer 247 [Redmine: #173554] 
	- 20230523@Danny: support scale out credit [Redmine: #181595]
	- 20230227@Bobby: Auto Clear Balance/ Multiple Transfer	 [RedmineID: #182071]
	- 20230908@Bobby: AutoJob Enhancement [RedmineID: #193017]

Param's Explanation:
	• @AmtTrans: amount of money
	• @MasterID: from master
	• @ToCustIDs: list custid
	  @SuperIDsTransferTotal: Supers are allowed to tranfer total balance including today balance 

*/
BEGIN

	SET NOCOUNT ON;

	DECLARE @rCount INT, @FromCustID INT, @PairStatus VARCHAR(15), @Result nvarchar(4000);
	-- TODO: support auto clear balance
	DECLARE @tblResultMember TABLE(CustId INT PRIMARY KEY, UserName VARCHAR(50), MsgId INT, ErrType VARCHAR(50), ErrMsg NVARCHAR(4000), RefNo BIGINT);
	INSERT INTO @tblResultMember(CustId)
	SELECT DISTINCT t.value
	FROM STRING_SPLIT(@ToCustIDs, ',') AS t;

	SELECT @FromCustID = @MasterId;

	CREATE TABLE #Agent (
		rIdx		INT IDENTITY(1,1),
		custID		int PRIMARY KEY NONCLUSTERED, 
		amt			money DEFAULT 0, 
		agUser		nvarchar(50), 
		UNIQUE(amt,custID),
		INDEX CIX_AgentrIdx CLUSTERED (rIdx)
	)
					
	---- #1 CHECK UM TRANSFER FUNCTION
	DECLARE @ToTimeConfig DATETIME;
	EXEC DBCUST.CUSTDB.dbo.Acc_Transfer_CheckUM  
		@CustID = @MasterID
		,@Language = @Language
		,@ErrMsg = @ErrMsg OUTPUT 
		,@ErrCode = @ErrCode OUTPUT
		,@ToTimeConfig = @ToTimeConfig OUTPUT
	 
	IF @ErrCode <> 0  -- Function Transfer is under UM 
	BEGIN
		IF @IsAutoTransfer = 1
		BEGIN
			SET @Result = (SELECT 50024 AS MsgId, 'TransferUM' AS ErrType, @ErrMsg AS ErrMsg,
				@ToTimeConfig AS ToTime FOR JSON PATH, WITHOUT_ARRAY_WRAPPER)
			EXEC dbo.Age_ClearBalanceCust_Process_StatusUpd @FromCustID = @FromCustID, @ToCustIds = @ToCustIDs
				,@Status='Pending', @Result = @Result;
		END
		RETURN		
	END		

	---- #2 CHECK FLAG ISTRANSFERRING = 1 THEN RAISE ERROR
	EXEC DBCUST.CUSTDB.dbo.Acc_Transfer_CheckRunningByCust  
			@CustID = @MasterID
			,@Language = @Language
			,@ErrMsg = @ErrMsg OUTPUT 
			,@ErrCode = @ErrCode OUTPUT
		 
	IF @ErrCode <> 0  -- the auto transfer job is running this custid
	BEGIN
		IF @IsAutoTransfer = 1
		BEGIN
			SET @Result = (SELECT 50026 AS MsgId, 'AccTransfering' AS ErrType, @ErrMsg AS ErrMsg FOR JSON PATH, WITHOUT_ARRAY_WRAPPER)
			EXEC dbo.Age_ClearBalanceCust_Process_StatusUpd @FromCustID = @FromCustID, @ToCustIds = @ToCustIDs
				,@Status='Failed', @Result = @Result;
		END	
		RETURN
	END

	---- #2.1 CHECK Status is Waiting or Running THEN RAISE ERROR
	IF @IsAutoTransfer = 0
	BEGIN
		EXEC bodb02.dbo.Age_ClearBalanceCust_CheckRunning  
				@CustID = @FromCustID
				,@Language = @Language
				,@ErrMsg = @ErrMsg OUTPUT 
				,@ErrCode = @ErrCode OUTPUT
			 
		IF @ErrCode <> 0  -- the auto transfer job is running for this line
		BEGIN		
			RETURN		
		END	
	END

	----------------------------------------------------------------------
	--Check Transfer Condition
	--1		2		3		4		5		6		7		8
	--isSun	isMon	isTue	isWed	isThurs	isFri	isSat	isWeekly
	--0		1		0		0		1		0		1		1
	EXEC DBCUST.CustDB.dbo.Age_Transfer_CheckTransferOption
		@CustID = @MasterID,
		@ErrMsg = @ErrMsg OUTPUT,
		@ErrCode = @ErrCode OUTPUT,
		@Language = @Language
	
	 IF @ErrCode <> 0
	 BEGIN
		IF @IsAutoTransfer = 1
		BEGIN
			SET @Result = (SELECT 50023 AS MsgId, 'TransferOption' AS ErrType, @ErrMsg AS ErrMsg FOR JSON PATH, WITHOUT_ARRAY_WRAPPER)
			EXEC dbo.Age_ClearBalanceCust_Process_StatusUpd @FromCustID = @FromCustID, @ToCustIds = @ToCustIds
				,@Status='Failed', @Result = @Result;
		END
		RETURN
	 END

	-- get move bet date
	DECLARE @balanceUpDay SMALLDATETIME, @moveBetsDay SMALLDATETIME
	DECLARE @tblMoveBetBalanceUp AS TABLE (BalanceUpDay SMALLDATETIME, MoveBetsDay SMALLDATETIME)
	DECLARE @IsDiff	SMALLINT = 1, @NewMoveBetDate SMALLDATETIME = NULL,@NewBalanceUpDate SMALLDATETIME = NULL

	INSERT INTO @tblMoveBetBalanceUp(BalanceUpDay,MoveBetsDay)
	EXEC bodb02.dbo.Age_SelBalanceUpDay
	
	SELECT @balanceUpDay = BalanceUpDay, @moveBetsDay = MoveBetsDay FROM @tblMoveBetBalanceUp

	DECLARE @WinlostDate datetime
	SELECT  @WinlostDate = convert(varchar(10), CURRENT_TIMESTAMP, 120)
	DECLARE @yesterday SMALLDATETIME
	SELECT  @yesterday = DATEADD(DAY, -1, CONVERT(DATE, GETDATE()))
 
	DECLARE @tblCustIds TABLE (CustId INT)

	INSERT INTO @tblCustIds (CustId)
	select convert(int, value) 
	from STRING_SPLIT (@ToCustIDs, ',' ) 

	-- Get bettype --
	DECLARE @isTest BIT = 0
	SELECT  @isTest = dbo.f_CheckSPVersion(@@PROCID)
	
	CREATE TABLE #SportBettype (bettype INT, RefTable TINYINT)
	INSERT INTO #SportBettype (bettype, RefTable)
	SELECT bettype, RefTable FROM dbo.f_SportBettypeMatrix_Sel (0, 0, 0, 2, '', '', @isTest)

	CREATE TABLE #BalanceInfo (CustId INT, Balance MONEY, Outstanding MONEY, TableName VARCHAR(50))

	CREATE TABLE #recommend (CustId INT)
	IF (@CustStatus <> '' OR @CustStatus <> null)
	BEGIN
		INSERT INTO #recommend (CustId)
		SELECT c.custid  
		FROM CustDB.dbo.custInfo c WITH(NOLOCK,index=IX_custinfo)  
		INNER JOIN CustDB.dbo.CustProductStatus cs with(nolock) on c.custid=cs.CustID
		WHERE	mrecommend = @MasterID 
				AND c.roleid = 2   
				AND c.Enabled = case @CustStatus when 'All' then c.Enabled 
						else	case @CustStatus  
								when 'Disabled' then 0   
								else 1 end  
						end
				AND 1 =  case	when @CustStatus = 'Open' and cs.CloseInfo = 0 and cs.SuspendInfo = 0  then 1
									when @CustStatus = 'Suspended' and cs.CloseInfo = 0 and cs.SuspendInfo > 0 then 1
									when @CustStatus = 'Closed'	and cs.CloseInfo > 0  then 1
									when @CustStatus = 'Disabled' then 1
									when @CustStatus = 'All' then 1
									else 0 end
	END
	ELSE
	BEGIN
		INSERT INTO #recommend (CustId)
		SELECT CustId FROM @tblCustIds
	END
  
	 --MASTER IS ALLOWED TO TRANSFER TOTAL BALANCE INCLUDING TODAY BALANCE 
	 IF (SELECT srecommend FROM CustDB.dbo.custinfo (NOLOCK) WHERE custid = @MasterID AND ROLEid = 3 ) IN  (SELECT CONVERT(INT,value) FROM STRING_SPLIT(@SuperIDsTransferTotal, ','))
	BEGIN
		-- bettransRNG
		INSERT INTO #BalanceInfo (CustId, Balance)
		SELECT 
			recommend,
			ISNULL(SUM(awinlost+comm-playercomm), 0)
				+ ISNULL(SUM(winlost-actual_stake+playercomm), 0)
		FROM dbo.bettransRNG b WITH(NOLOCK)
		WHERE EXISTS (SELECT 1 FROM #recommend r WHERE b.recommend = r.CustId)
			AND statusID NOT IN (0,1)
			AND winlostdate >= @yesterday
		GROUP BY recommend

		-- bettransLC
		INSERT INTO #BalanceInfo (CustId, Balance)
		SELECT 
			recommend,
			ISNULL(SUM(awinlost+comm-playercomm), 0)
				+ ISNULL(SUM(winlost-actual_stake+playercomm), 0)
		FROM dbo.bettransLC b WITH(NOLOCK)
		WHERE EXISTS (SELECT 1 FROM #recommend r WHERE b.recommend = r.CustId)
			AND statusID NOT IN (0,1)
			AND winlostdate >= @yesterday
		GROUP BY recommend
	  
		WHILE (@IsDiff = 1)
		BEGIN

			DELETE FROM #BalanceInfo WHERE TableName IN ('tblBettrans','tblTransfer')
		
			-- bettrans
			INSERT INTO #BalanceInfo (CustId, Balance, TableName)
			SELECT 
				recommend,
				ISNULL(SUM(awinlost+comm-playercomm), 0)
					+ ISNULL(SUM(winlost-actual_stake+playercomm), 0),
				'tblBettrans'
			FROM dbo.bettrans b WITH(NOLOCK)
			WHERE EXISTS (SELECT 1 FROM #recommend r WHERE b.recommend = r.CustId)
				AND b.statusID IN (111, 112, 113)
				AND winlostdate > @moveBetsDay
				AND (
						b.winlostdate < @yesterday
						OR NOT EXISTS (SELECT TOP 1 1 FROM #SportBettype s WHERE s.Bettype = b.bettype AND s.RefTable IN (1, 2))
					)
			GROUP BY recommend

			-- Transfer
			INSERT INTO #BalanceInfo (CustId, Balance, TableName)
			SELECT 
				recommend,
				ISNULL(SUM(CASE WHEN custid = recommend THEN winlost-actual_stake ELSE awinlost+comm-playercomm END), 0)
					+ ISNULL(SUM(CASE WHEN custid <> recommend THEN winlost-actual_stake+playercomm ELSE 0 END), 0),
				'tblTransfer'
			FROM dbo.Transfer b WITH(NOLOCK)
			WHERE EXISTS (SELECT 1 FROM #recommend r WHERE b.recommend = r.CustId)
						AND 1 = CASE WHEN bettype = 19999 AND winlostdate > @moveBetsDay THEN 0 --> new sum
													WHEN bettype = 20000 AND winlostdate > @balanceUpDay THEN 0 --> new bal
													WHEN winlostdate < @balanceUpDay THEN 0 --> old data
												ELSE 1 END
						AND bettype NOT IN (21008, 21009)
			GROUP BY recommend

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
	-- YESTERDAY TRANSFER
	ELSE
	BEGIN
		-- bettransRNG
		INSERT INTO #BalanceInfo (CustId, Balance)
		SELECT 
			recommend,
			ISNULL(SUM(awinlost+comm-playercomm), 0)
				+ ISNULL(SUM(winlost-actual_stake+playercomm), 0)
		FROM dbo.bettransRNG b WITH(NOLOCK)
		WHERE EXISTS (SELECT 1 FROM #recommend r WHERE b.recommend = r.CustId)
			AND statusID NOT IN (0,1)
			AND winlostdate = @yesterday
		GROUP BY recommend

		-- bettransLC
		INSERT INTO #BalanceInfo (CustId, Balance)
		SELECT 
			recommend,
			ISNULL(SUM(awinlost+comm-playercomm), 0)
				+ ISNULL(SUM(winlost-actual_stake+playercomm), 0)
		FROM dbo.bettransLC b WITH(NOLOCK)
		WHERE EXISTS (SELECT 1 FROM #recommend r WHERE b.recommend = r.CustId)
			AND statusID NOT IN (0,1)
			AND winlostdate = @yesterday
		GROUP BY recommend

		WHILE (@IsDiff = 1)
		BEGIN

			DELETE FROM #BalanceInfo WHERE TableName IN ('tblBettrans','tblTransfer')

			-- bettrans
			INSERT INTO #BalanceInfo (CustId, Balance, TableName)
			SELECT 
				recommend,
				ISNULL(SUM(CASE WHEN winlostdate <= @yesterday THEN awinlost+comm-playercomm ELSE 0 END), 0)
					+ ISNULL(SUM(CASE WHEN winlostdate <= @yesterday THEN winlost-actual_stake+playercomm ELSE 0 END), 0),
				'tblBettrans'
			FROM dbo.bettrans b WITH(NOLOCK)
			WHERE EXISTS (SELECT 1 FROM #recommend r WHERE b.recommend = r.CustId)
				AND b.statusID IN (111, 112, 113)
				AND winlostdate > @moveBetsDay
				AND (
						b.winlostdate < @yesterday
						OR NOT EXISTS (SELECT TOP 1 1 FROM #SportBettype s WHERE s.Bettype = b.bettype AND s.RefTable IN (1, 2))
					)
			GROUP BY recommend

				-- Transfer
			INSERT INTO #BalanceInfo (CustId, Balance, TableName)
			SELECT 
				recommend,
				ISNULL(SUM(CASE WHEN custid = recommend THEN winlost-actual_stake ELSE awinlost+comm-playercomm END ), 0)
					+ ISNULL(SUM(CASE WHEN custid <> recommend THEN winlost-actual_stake+playercomm ELSE 0 END ), 0),
				'tblTransfer'
			FROM dbo.Transfer b WITH(NOLOCK)
			WHERE EXISTS (SELECT 1 FROM #recommend r WHERE b.recommend = r.CustId)
						AND 1 = CASE WHEN bettype = 19999 AND winlostdate > @moveBetsDay THEN 0 --> new sum
													WHEN bettype = 20000 AND winlostdate > @balanceUpDay THEN 0 --> new bal
													WHEN winlostdate < @balanceUpDay THEN 0 --> old data
												ELSE 1 END
						AND bettype NOT IN (21008, 21009)
			GROUP BY recommend

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

	-- Sum amount
	INSERT INTO #Agent (CustID, Amt, AgUser)
	SELECT r.CustId, SUM(ISNULL(bal.Balance,0)), ''
	FROM #recommend r
	LEFT JOIN #BalanceInfo bal ON bal.CustId = r.CustId
	GROUP BY r.CustId

	IF NOT EXISTS (SELECT 1 FROM #Agent WHERE amt <> 0)
	BEGIN
		Select @ErrMsg = case @Language   
			when 'E' then 'Cannot transfer because all downlines'' balance is 0!' 
			ELSE CustDB.dbo.f_Get_MsgNamebyMsgID(50002,@Language)
		end, @ErrCode = 103     
		
		IF @IsAutoTransfer = 1
		BEGIN
			SET @Result = (SELECT 50025 AS MsgId, 'BalanceZero' AS ErrType, @ErrMsg AS ErrMsg FOR JSON PATH, WITHOUT_ARRAY_WRAPPER)
			EXEC dbo.Age_ClearBalanceCust_Process_StatusUpd @FromCustID = @FromCustID, @ToCustIds = @ToCustIDs
				,@Status='Ignored', @Result = @Result;
		END
		RETURN	
	END
 
	 UPDATE #Agent SET agUser = ci.username 
	 FROM #Agent 
		INNER JOIN CustDB.dbo.custinfo ci with (NOLOCK) ON ci.custid = #Agent.custid 

	 DECLARE @currency int , @actualrate float, @currName nvarchar(10), @RefNo bigint, @amount money, @grefno BIGINT, @TransID BIGINT
	 DECLARE @srecommend int, @AgentID int , @MAUser nvarchar(50), @AgUser nvarchar(50)
	 DECLARE @LogData nvarchar(200), @SubAccName varchar(30)
 
	 --- 20150606@Kathy: Migrate custDB to new server DBCust(Get credit from DBCust.CustDB) [Redmine:#36216]
	 SELECT @SubAccName = username 
		FROM DBCUST.CustDB.dbo.custSub WITH(NOLOCK) 
		WHERE SubAccID = @SubAccID

	 SELECT @currency = ci.currency, @currName =e.currency, @maUser = ci.username, 
			@actualrate = e.actualrate, @srecommend = srecommend  
	 FROM CustDB.dbo.custinfo ci with (nolock) 
		INNER JOIN CustDB.dbo.Exchange e with (NOLOCK) ON ci.currency = e.exchangeid 
	 WHERE ci.custid = @masterid AND ci.roleid = 3

	 DECLARE @procName VARCHAR(100)
	 SELECT  @procName = OBJECT_NAME(@@PROCID)

	 SET @rCount = 1;
	 WHILE EXISTS (SELECT 1 FROM #Agent WHERE rIdx = @rCount)
	 BEGIN
		-- Reset error for each pair
		SELECT @ErrCode = 0,
			@ErrMsg = '';
		
		SELECT @AgentID = CustId, @Amount = Amt, @AgUser = agUser
		FROM #Agent 
		WHERE rIdx = @rCount;

		-- SET username
		UPDATE @tblResultMember
		SET UserName = @AgUser
		WHERE CustId = @AgentID;	

		IF (@Amount = 0)
		BEGIN
			UPDATE @tblResultMember
			SET MsgId = 50025, ErrType = 'BalanceZero', ErrMsg = 'Cannot transfer because balance is 0!'
			WHERE CustId = @AgentID;	
			GOTO NEXT_PAIR;
		END
	
		--AutoJob Transfer: START a Pair waiting to Processing
		IF @IsAutoTransfer = 1
		BEGIN
			EXEC dbo.Age_ClearBalanceCust_Process_StatusUpd @FromCustID = @FromCustID, @ToCustIds = @AgentID
				,@Status='Processing', @Amount=@Amount
				,@ErrCode = @ErrCode OUTPUT
				,@ErrMsg = @ErrMsg OUTPUT
			;
			-- CHECK: Cancelling
			IF @ErrCode > 0
			BEGIN
				UPDATE @tblResultMember
				SET MsgId = @ErrCode, ErrType = 'TransferStatus', ErrMsg = @ErrMsg
				WHERE CustId = @AgentID;	
				GOTO NEXT_PAIR;
			END
		END

		BEGIN TRY
	
			--CHECK FOR TRANSFER AMOUNT @Phuong20080916
			DECLARE @custBalance money 
			SELECT @custBalance = @Amount 

			if @FullTransfer = 0
			BEGIN
				IF @AmtTrans = 0
					OR (@CustBalance >= 0 AND (@AmtTrans <= 0 or @AmtTrans > @CustBalance))
					OR (@CustBalance < 0 AND (@AmtTrans >= 0 or @AmtTrans < @CustBalance))
					BEGIN
						SELECT @ErrMsg = CASE @Language 
										WHEN 'E' THEN 'Amount to transfer must be between 0 and' + ' ' + convert(VARCHAR(100), -@CustBalance, 2) +'.'
										ELSE CustDB.dbo.f_Get_MsgNamebyMsgID(50005,@Language) + ' ' + convert(VARCHAR(100), -@CustBalance, 2) + '.'
											end		
						select @ErrCode = 104
					
						UPDATE @tblResultMember
						SET MsgId = 50005, ErrType = 'FullTransfer', ErrMsg = @ErrMsg
						WHERE CustId = @AgentID;	
						GOTO NEXT_PAIR;
					END	
				-- INSERT AMOUNT INPUTED INTO BETTRANS 
				SET @amount = @AmtTrans	
			END 	

			------------------Gen refno--------------------------------------------------------------- 
			EXEC Get_Refno_Transid @RefNo = @RefNo OUTPUT

			-- TODO: AutoTransfer - Check cancelled
			IF @IsAutoTransfer = 1
			BEGIN
				EXEC dbo.Age_ClearBalanceCust_Process_StatusUpd @FromCustID = @FromCustID, @ToCustIds = @AgentID
					,@Status='Processing'
					,@ErrCode = @ErrCode OUTPUT
					,@ErrMsg = @ErrMsg OUTPUT
				;
				-- CHECK: Cancelling
				IF @ErrCode > 0
				BEGIN
					UPDATE @tblResultMember
					SET MsgId = @ErrCode, ErrType = 'TransferStatus', ErrMsg = @ErrMsg
					WHERE CustId = @AgentID;	
					GOTO NEXT_PAIR;
				END
			END

			--TODO: Set default ERROR for MANUAL transfer
			DECLARE @extraTransDesc VARCHAR(100);
			SELECT @ErrMsg = CASE @Language 
								WHEN 'E' THEN 'Clear balance failed. Please try again.'
								ELSE CustDB.dbo.f_Get_MsgNamebyMsgID(50003,@Language)
						END
						, @extraTransDesc = CASE 
											WHEN @IsAutoTransfer = 1 THEN ' (added via the Auto Transfer process)'
											WHEN @SubAccID > 0 THEN ' (By ' + @SubAccName + ')'
											ELSE ''
										END

			------------------Insert trans into DB---------------------------------------------------------------
			IF @amount > 0
			BEGIN
				EXEC Get_Bettrans_TransID @TransID = @TransID OUTPUT
				INSERT INTO Transfer 
					(transid, creator, custid, username, refno, transdate, bettype, transdesc, winlost, actual_stake, 
					winlostdate, currency, actualrate, currencyName, recommend, mrecommend, srecommend, 
					scomm, swinlost,ip,statusID, RepUpdateTime)
				VALUES 
					(@TransID ,@creator, @masterid, @maUser, @RefNo, current_timestamp, 21003, 'From Customer ::: ' + @agUser + @extraTransDesc, 
					@amount, 0, @WinlostDate, @currency, @actualrate, @currName, 0, @masterid, @srecommend, 
					0, 0,@ip,131,SYSDATETIME())
				IF @@Error <> 0
				BEGIN								
					SELECT @ErrCode = 102
					--Manually rollback
					UPDATE dbo.Transfer WITH(ROWLOCK)
					SET	 custid = 0, Winlost = 0, Actual_Stake = 0, RepUpdateTime = SYSDATETIME(), Recommend = 0, MRecommend = 0, SRecommend = 0	
					WHERE refno = @RefNo
				
					--AutoJob Transfer
					UPDATE @tblResultMember
					SET MsgId = 50027, ErrType = 'DBIssue', ErrMsg = ERROR_MESSAGE()
					WHERE CustID = @AgentID;

					GOTO NEXT_PAIR;
				END

				DECLARE @TotalCashAgent MONEY 
				EXEC Acc_CustomerSelCash_CaptureBalance @custid = @agentid, @TotalCash  = @TotalCashAgent OUTPUT

				EXEC Get_Bettrans_TransID @TransID = @TransID OUTPUT
				INSERT INTO Transfer
					(transid, creator, custid, username, refno, transdate, bettype, transdesc, winlost, actual_stake, 
					winlostdate, currency, actualrate, currencyName, recommend, mrecommend, srecommend, scomm, swinlost,ip,statusID, balance, RepUpdateTime)
				VALUES 
					(@TransID, @creator, @agentid, @agUser, @RefNo, current_timestamp, 21003, 'To Customer ::: ' + @maUser + @extraTransDesc, 
					0, @amount, @WinlostDate, @currency, @actualrate,@currName, @agentid, @masterid, @srecommend, 
					0, 0,@ip,131, @TotalCashAgent,SYSDATETIME())
				IF @@Error <> 0
				BEGIN						
					SELECT @ErrCode = 103
					--Manually rollback
					UPDATE dbo.Transfer WITH(ROWLOCK)
					SET	 custid = 0, Winlost = 0, Actual_Stake = 0, RepUpdateTime = SYSDATETIME(), Recommend = 0, MRecommend = 0, SRecommend = 0	
					WHERE refno = @RefNo
				
					--AutoJob Transfer
					UPDATE @tblResultMember
					SET MsgId = 50027, ErrType = 'DBIssue', ErrMsg = ERROR_MESSAGE()
					WHERE CustID = @AgentID;

					GOTO NEXT_PAIR;
				END

				--Add writelog for each amt transfered - Vinh 20080629
				SELECT @LogData = 'Transfer from Agent ' + @agUser + ' to Master ' + @maUser + ' with amount ' + CONVERT(VARCHAR(20), @amount) + ' Ref.No ' + CONVERT(VARCHAR(20), @RefNo)
			
				--AutoJob Transfer: Completed
				UPDATE @tblResultMember
				SET RefNo = @RefNo
				WHERE CustID = @AgentID;

			END
			ELSE IF @amount<0
			BEGIN
				--SET @amount = abs(@amount)
				EXEC Get_Bettrans_TransID @TransID = @TransID OUTPUT
				INSERT INTO Transfer 
					(transid, creator, custid, username, refno, transdate, bettype, transdesc, winlost, actual_stake, 
					winlostdate, currency, actualrate, currencyName, recommend, mrecommend, srecommend, 
					scomm, swinlost,ip,statusID, RepUpdateTime)
				VALUES 
					(@TransID, @creator, @masterid, @maUser, @RefNo, current_timestamp, 21003, 'To Customer ::: ' + @agUser + @extraTransDesc, 
					0, abs(@amount),  @WinlostDate, @currency, @actualrate, @currName, 0, @masterid, @srecommend, 
					0, 0,@ip,131,SYSDATETIME())
				if @@Error <> 0
				BEGIN						
					select @ErrCode = 107
					--Manually rollback
					UPDATE dbo.Transfer WITH(ROWLOCK)
					SET	 custid = 0, Winlost = 0, Actual_Stake = 0, RepUpdateTime = SYSDATETIME(), Recommend = 0, MRecommend = 0, SRecommend = 0	
					WHERE refno = @RefNo
				
					--AutoJob Transfer
					UPDATE @tblResultMember
					SET MsgId = 50027, ErrType = 'DBIssue', ErrMsg = ERROR_MESSAGE()
					WHERE CustID = @AgentID;

					GOTO NEXT_PAIR;
				END

				DECLARE @TotalCashAgentNev MONEY 
				EXEC Acc_CustomerSelCash_CaptureBalance @custid = @agentid, @TotalCash  = @TotalCashAgentNev OUTPUT

				EXEC Get_Bettrans_TransID @TransID = @TransID OUTPUT
				INSERT INTO Transfer
					(transid, creator, custid, username, refno, transdate, bettype, transdesc, winlost, actual_stake, 
					winlostdate, currency,actualrate, currencyName, recommend, mrecommend, srecommend, 
					scomm, swinlost,ip,statusID, balance, RepUpdateTime)
				VALUES 
					(@TransID, @creator, @agentid, @agUser, @RefNo, current_timestamp, 21003, 'From Customer ::: ' + @maUser + @extraTransDesc, 
					abs(@amount), 0,@WinlostDate, @currency, @actualrate, @currName, @agentid, @masterid, @srecommend, 
					0, 0,@ip,131, @TotalCashAgentNev,SYSDATETIME())
				IF @@Error <> 0
				BEGIN
					SELECT @ErrCode = 104
					--Manually rollback
					UPDATE dbo.Transfer WITH(ROWLOCK)
					SET	 custid = 0, Winlost = 0, Actual_Stake = 0, RepUpdateTime = SYSDATETIME(), Recommend = 0, MRecommend = 0, SRecommend = 0	
					WHERE refno = @RefNo
				
					--AutoJob Transfer
					UPDATE @tblResultMember
					SET MsgId = 50027, ErrType = 'DBIssue', ErrMsg = ERROR_MESSAGE()
					WHERE CustID = @AgentID;

					GOTO NEXT_PAIR;
				END
			
				--Add writelog for each amt transfered - Vinh 20080629
				SELECT @LogData = 'Transfer from Master ' + @maUser + ' to Agent ' + @agUser + ' with amount ' + CONVERT(VARCHAR(20), @amount) + ' Ref.No ' + CONVERT(VARCHAR(20), @RefNo)
			
				--AutoJob Transfer: Completed
				UPDATE @tblResultMember
				SET RefNo = @RefNo
				WHERE CustID = @AgentID;
			END
			---------------------------------------------------------------------------------------------------
			SELECT @ErrMsg	= '',
				@ErrCode	= 0
	
			if @SubAccID > 0
			begin
				SET @LogData = 'SubAccount:' +  coalesce(cast(@SubAccName as varchar(30)),space(1)) + ' - ' + @LogData
			end

			SELECT @LogData = @LogData + ' SPName: ' + @procName

			BEGIN TRY			
				EXEC DBLOG.bodb_customerlog.dbo.WriteLog_UserLog_Transfer 
										@UserID			= @creator, 
										@FromCustID		= @MasterID, 
										@ToCustID		= @AgentID, 
										@IP				= @IP, 
										@Doing			= @LogData
			END TRY
			BEGIN CATCH
				SELECT @LogData = @LogData + ' ErrMsg: ' + ERROR_MESSAGE()
	
				EXEC bodb_customerlog.dbo.WriteLog_UserLog_Transfer 
										@UserID			= @creator, 
										@FromCustID		= @MasterID, 
										@ToCustID		= @AgentID, 
										@IP				= @IP, 
										@Doing			= @LogData	
			END CATCH
		END TRY
		BEGIN CATCH
			--Exception
			UPDATE @tblResultMember
			SET MsgId = 50027, ErrType = 'DBIssue', ErrMsg = ERROR_MESSAGE()
			WHERE CustID = @AgentID;
		END CATCH

		NEXT_PAIR:
		IF @IsAutoTransfer = 1
		BEGIN
			SELECT @Result = (SELECT MsgId, ErrType, ErrMsg, RefNo FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
				@PairStatus = CASE WHEN RefNo > 0 THEN 'Completed' ELSE 
					CASE WHEN ErrType = 'BalanceZero' THEN 'Ignored' ELSE 'Failed' END 
				END
			FROM @tblResultMember 
			WHERE CustId=@AgentID
			;
			EXEC dbo.Age_ClearBalanceCust_Process_StatusUpd @FromCustID = @FromCustID, @ToCustIds = @AgentID
				,@Status=@PairStatus, @Result = @Result;
		END
		ELSE 
		BEGIN
			--TODO: Check FAILED break for MANUAL transfer
			IF @ErrCode > 0
				RETURN;
		END
		SET @rCount += 1;
	END
	DROP TABLE #Agent 
	DROP TABLE #SportBettype
	DROP TABLE #BalanceInfo
	DROP TABLE #recommend
END
GO