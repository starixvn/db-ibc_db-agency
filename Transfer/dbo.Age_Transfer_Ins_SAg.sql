/*<info serverAlias="DBCTG-bodb02,DBSIC-bodb02" executers="bodbDownlineNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE  [dbo].[Age_Transfer_Ins_SAg]
	@SAgID int,
	@SuperIDsTransferTotal VARCHAR(50)='', 
	@ToCustIDs varchar(4000),
	@creator int,
	@FullTransfer bit = 1,
	@AmtTrans float = 0,
	@Language varchar(2)= 'E',
	@SubAccID int = 0, --Sub-AccountID
	@IP varchar(45)='',
	@ErrCode int = 0 OUTPUT,
	@ErrMsg nvarchar(4000) = '' OUTPUT,	
	@CustStatus varchar(50)=''

AS
--AGENT SITE
--Multiple Transfer
/*
Created: 
Task: Transfer
DB: DBTXN/bodb02
Original: Age_Transfer_In

Revisions:
	- 20090318@Phuc: Korean language.
	- 20090416@PhuongDao: Allow some SuperIDs to transfer all balance including balance of today
	- 20090729@Phuc: Write log subaccname instead of subaccid.
	- 20090818@Phuc: check page access and check upline closed first(call Age_CustSubCheckPageAccess)
	- 20091003@Kiwi: Modify Write log function
	- 20091125@Kiwi: Remove comstatus because it's no used.
	- 20100424@Henry: insert data to column StatusID of Bettrans (StatusID = 131 for bettype 103)
	- 20100611@Henry: Write exact amount to log when transferring
	- 20101224@Johnson: Apply new arrange of bettype
	- 20120104@Lukas: modify to filter by 'enabled' status
	- 20120202@Jamie:Change transfer time to 12pm to 11:59pm instead of 12pm to 10pm ( 9h59pm)
	- 20121106@Viet: amend sp to reduce load for DBTRANS.
	- 20121128@Elodie: Get an error message from f_Get_MsgNameByMsgID function by language
	- 20130201@Johnson: write log into DBTXN if failure DBLOG server
	- 20131108@Elodie: Splitting bodb02 into CustDB (Call CustInfo, Exchange by link database)
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
	
Param's Explanation:
• @AmtTrans: amount of money
• @SAgID: from master
• @ToCustIDs: list custid
  @SuperIDsTransferTotal: Super IDs can transfer total balance including today balance 

*/


SET NOCOUNT ON
	
---------------------------
--declare @ErrMsg varchar(200)
 CREATE TABLE #Master (		custID	int PRIMARY KEY, 
							Amt		money DEFAULT 0, 
							MAgUser nvarchar(50), 
							UNIQUE(Amt,custid)
					 )
					 

---- #1 CHECK UM TRANSFER FUNCTION
EXEC DBCUST.CUSTDB.dbo.Acc_Transfer_CheckUM  
	@CustID = @SAgID
	,@Language = @Language
	,@ErrMsg = @ErrMsg OUTPUT 
	,@ErrCode = @ErrCode OUTPUT
	 
IF @ErrCode <> 0  -- Function Transfer is under UM 
BEGIN
	RETURN		
END		

---- #2 CHECK FLAG ISTRANSFERRING = 1 THEN RAISE ERROR
EXEC DBCUST.CUSTDB.dbo.Acc_Transfer_CheckRunningByCust  
		@CustID = @SAgID
		,@Language = @Language
		,@ErrMsg = @ErrMsg OUTPUT 
		,@ErrCode = @ErrCode OUTPUT
		 
IF @ErrCode <> 0  -- the auto transfer job is running this custid
BEGIN		
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
SELECT CONVERT(INT, value) FROM STRING_SPLIT (@ToCustIDs, ',')

-- Get bettype --
DECLARE @isTest BIT = 0
SELECT  @isTest = dbo.f_CheckSPVersion(@@PROCID)
	
CREATE TABLE #SportBettype (bettype INT, RefTable TINYINT)
INSERT INTO #SportBettype (bettype, RefTable)
SELECT bettype, RefTable FROM dbo.f_SportBettypeMatrix_Sel (0, 0, 0, 2, '', '', @isTest)

CREATE TABLE #BalanceInfo (CustId INT, Balance MONEY, Outstanding MONEY, TableName VARCHAR(50))

CREATE TABLE #mrecommend (CustId INT)
CREATE TABLE #recommend (CustId INT)

IF (@CustStatus <> '' OR @CustStatus <> null)
BEGIN
	INSERT INTO #mrecommend (CustId)
	SELECT c.custid  
	FROM CustDB.dbo.custInfo c WITH(NOLOCK)  
	INNER JOIN CustDB.dbo.CustProductStatus cs with(nolock) on c.custid=cs.CustID
	WHERE	srecommend = @SAgID 
			AND c.roleid = 3  
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
	INSERT INTO #mrecommend (CustId)
	SELECT CustId FROM @tblCustIds
END

INSERT INTO #recommend (CustId)
SELECT custid
FROM CustDB.dbo.custInfo c WITH(NOLOCK)
WHERE c.roleid = 2
	AND EXISTS (SELECT 1 FROM #mrecommend m WHERE c.mrecommend = m.CustId)

 --Allow some IDs to transfer total balance including the balance of today
 IF @SAgID IN (SELECT CONVERT(INT, value) from STRING_SPLIT(@SuperIDsTransferTotal, ','))
 BEGIN 
	-- bettransRNG
	INSERT INTO #BalanceInfo (CustId, Balance)
	SELECT 
		mrecommend,
		ISNULL(SUM(mwinlost+acomm-comm), 0)
			+ ISNULL(SUM(awinlost+comm-playercomm), 0)
			+ ISNULL(SUM(winlost-actual_stake+playercomm), 0)
	FROM dbo.bettransRNG b WITH(NOLOCK)
	WHERE EXISTS (SELECT 1 FROM #recommend r WHERE b.recommend = r.CustId)
		AND statusID NOT IN (0,1)
		AND winlostdate >= @yesterday
	GROUP BY mrecommend

	-- bettransLC
	INSERT INTO #BalanceInfo (CustId, Balance)
	SELECT 
		mrecommend,
		ISNULL(SUM(mwinlost+acomm-comm), 0)
			+ ISNULL(SUM(awinlost+comm-playercomm), 0)
			+ ISNULL(SUM(winlost-actual_stake+playercomm), 0)
	FROM dbo.bettransLC b WITH(NOLOCK)
	WHERE EXISTS (SELECT 1 FROM #recommend r WHERE b.recommend = r.CustId)
		AND statusID NOT IN (0,1)
		AND winlostdate >= @yesterday
	GROUP BY mrecommend

	WHILE (@IsDiff = 1)
	BEGIN

		DELETE FROM #BalanceInfo WHERE TableName IN ('tblBettrans','tblTransfer')

		-- bettrans
		INSERT INTO #BalanceInfo (CustId, Balance, TableName)
		SELECT 
			mrecommend,
			ISNULL(SUM(mwinlost+acomm-comm), 0)
				+ ISNULL(SUM(awinlost+comm-playercomm), 0)
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
		GROUP BY mrecommend

		-- Transfer
		INSERT INTO #BalanceInfo (CustId, Balance, TableName)
		SELECT 
			mrecommend,
			ISNULL(SUM(mwinlost+acomm-comm), 0)
				+ ISNULL(SUM(CASE WHEN custid = recommend THEN winlost-actual_stake ELSE awinlost+comm-playercomm END), 0)
				+ ISNULL(SUM(CASE WHEN custid <> recommend THEN winlost-actual_stake+playercomm ELSE 0 END), 0),
			'tblTransfer'
		FROM dbo.Transfer b WITH(NOLOCK)
		WHERE EXISTS (SELECT 1 FROM #recommend r WHERE b.recommend = r.CustId)
					AND 1 = CASE WHEN bettype = 19999 AND winlostdate > @moveBetsDay THEN 0 --> new sum
											WHEN bettype = 20000 AND winlostdate > @balanceUpDay THEN 0 --> new bal
											WHEN winlostdate < @balanceUpDay THEN 0 --> old data
									ELSE 1 END
					AND bettype NOT IN (21008, 21009)
		GROUP BY mrecommend

		INSERT INTO #BalanceInfo (CustId, Balance, TableName)
		SELECT 
			mrecommend,
			ISNULL(SUM(winlost-actual_stake), 0),
			'tblTransfer'
		FROM dbo.Transfer b WITH(NOLOCK)
		WHERE EXISTS (SELECT 1 FROM #mrecommend m WHERE b.custid = m.CustId)
					AND 1 = CASE WHEN bettype = 20000 AND winlostdate > @balanceUpDay THEN 0 --> new bal
												WHEN winlostdate < @balanceUpDay THEN 0 --> old data
										ELSE 1 END
					AND bettype NOT IN (21008, 21009)
		GROUP BY mrecommend


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
		mrecommend,
		ISNULL(SUM(mwinlost+acomm-comm), 0)
			+ ISNULL(SUM(awinlost+comm-playercomm), 0)
			+ ISNULL(SUM(winlost-actual_stake+playercomm), 0)
	FROM dbo.bettransRNG b WITH(NOLOCK)
	WHERE EXISTS (SELECT 1 FROM #recommend r WHERE b.recommend = r.CustId)
		AND statusID NOT IN (0,1)
		AND winlostdate = @yesterday
	GROUP BY mrecommend

	-- bettransLC
	INSERT INTO #BalanceInfo (CustId, Balance)
	SELECT 
		mrecommend,
		ISNULL(SUM(mwinlost+acomm-comm), 0)
			+ ISNULL(SUM(awinlost+comm-playercomm), 0)
			+ ISNULL(SUM(winlost-actual_stake+playercomm), 0)
	FROM dbo.bettransLC b WITH(NOLOCK)
	WHERE EXISTS (SELECT 1 FROM #recommend r WHERE b.recommend = r.CustId)
		AND statusID NOT IN (0,1)
		AND winlostdate = @yesterday
	GROUP BY mrecommend

	WHILE (@IsDiff = 1)
	BEGIN

		DELETE FROM #BalanceInfo WHERE TableName IN ('tblBettrans','tblTransfer')
		
		-- bettrans
		INSERT INTO #BalanceInfo (CustId, Balance, TableName)
		SELECT 
			mrecommend,
			ISNULL(SUM(CASE WHEN winlostdate <= @yesterday THEN mwinlost+acomm-comm ELSE 0 END), 0)
				+ ISNULL(SUM(CASE WHEN winlostdate <= @yesterday THEN awinlost+comm-playercomm ELSE 0 END), 0)
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
		GROUP BY mrecommend

		-- Transfer
		INSERT INTO #BalanceInfo (CustId, Balance, TableName)
		SELECT 
			mrecommend,
			ISNULL(SUM(CASE WHEN winlostdate <= @yesterday THEN mwinlost+acomm-comm ELSE 0 END), 0)
				+ ISNULL(SUM(CASE WHEN custid = recommend THEN winlost-actual_stake ELSE awinlost+comm-playercomm END ), 0)
				+ ISNULL(SUM(CASE WHEN custid <> recommend THEN winlost-actual_stake+playercomm ELSE 0 END ), 0),
			'tblTransfer'
		FROM dbo.Transfer b WITH(NOLOCK)
		WHERE EXISTS (SELECT 1 FROM #recommend r WHERE b.recommend = r.CustId)
					AND 1 = CASE WHEN bettype = 19999 AND winlostdate > @moveBetsDay THEN 0 --> new sum
										WHEN bettype = 20000 AND winlostdate > @balanceUpDay THEN 0 --> new bal
										WHEN winlostdate < @balanceUpDay THEN 0 --> old data
								ELSE 1 END
					AND bettype NOT IN (21008, 21009)
		GROUP BY mrecommend

		INSERT INTO #BalanceInfo (CustId, Balance, TableName)
		SELECT 
			mrecommend,
			ISNULL(SUM(winlost-actual_stake), 0),
			'tblTransfer'
		FROM dbo.Transfer b WITH(NOLOCK)
		WHERE EXISTS (SELECT 1 FROM #mrecommend m WHERE b.custid = m.CustId)
			AND bettype NOT IN (21008, 21009)
			AND 1 = CASE WHEN bettype = 19999 AND winlostdate > @moveBetsDay THEN 0 --> new sum
						WHEN bettype = 20000 AND winlostdate > @balanceUpDay THEN 0 --> new bal
						WHEN winlostdate < @balanceUpDay THEN 0 --> old data
				ELSE 1 END
		GROUP BY mrecommend

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

 -- sum amount
 INSERT INTO #Master (custID, Amt, MAgUser)
 SELECT CustId, SUM(Balance), ''
 FROM #BalanceInfo
 GROUP BY CustId

 DELETE FROM #Master WHERE amt = 0 
 
 if not exists (select 1 from #Master)
 BEGIN
	Select @ErrMsg = case @Language   
		when 'E' then 'Cannot transfer because all downlines'' balance is 0!' 
		ELSE CustDB.dbo.f_Get_MsgNamebyMsgID(50002,@Language)
	end
		, @ErrCode = 103     
 
	RETURN	
  END
 
 UPDATE #Master SET MAgUser = ci.username 
 FROM #Master 
	INNER JOIN CustDB.dbo.custinfo ci with (NOLOCK) ON ci.custid = #Master.custid 
	
 DECLARE @currency int, @actualrate float, @currName nvarchar(10),
	     @transcode bigint, @amount float, @grefno BIGINT, @transid BIGINT
 DECLARE @SAUser nvarchar(50), @MAgUser nvarchar(50), @MAgentID int
 DECLARE @LogData nvarchar(300), @SubAccName varchar(30)
 
 --- 20150606@Kathy: Migrate custDB to new server DBCust(Get credit from DBCust.CustDB) [Redmine:#36216]
 SELECT @SubAccName = username 
 FROM DBCUST.CustDB.dbo.custSub WITH(NOLOCK) 
 WHERE SubAccID = @SubAccID

 SELECT @currency = ci.currency, @currName = e.currency ,@SaUser = ci.username, 
		@actualrate = e.actualrate  
 FROM CustDB.dbo.custinfo ci with (nolock) 
	INNER JOIN CustDB.dbo.Exchange e with (NOLOCK) on ci.currency = e.exchangeid  
 WHERE custid = @SAgID

 DECLARE @procName VARCHAR(100)
 SELECT  @procName = OBJECT_NAME(@@PROCID)

 DECLARE CUR CURSOR FOR SELECT CustID,Amt,MAgUser FROM #Master 
 OPEN CUR
 FETCH NEXT FROM CUR INTO @MAgentID, @Amount, @MAgUser
 WHILE @@FETCH_STATUS = 0
 BEGIN
	
	EXEC Get_Refno_Transid @RefNo = @transcode OUTPUT
	
	--CHECK MASTER'S BALANCE
	DECLARE @custBalance money 
	SELECT @custBalance = @Amount 
	IF @FullTransfer = 0
	BEGIN
		IF @AmtTrans = 0
				OR (@CustBalance >= 0 AND (@AmtTrans <= 0 or @AmtTrans > @CustBalance))
				OR (@CustBalance < 0 AND (@AmtTrans >= 0 or @AmtTrans < @CustBalance))
			BEGIN
				SELECT @ErrMsg = CASE @Language 
										WHEN 'E' THEN 'Amount to transfer must be between 0 and' + ' ' + CONVERT(VARCHAR(100), -@CustBalance, 2) + '.'
										ELSE CustDB.dbo.f_Get_MsgNamebyMsgID(50005,@Language) + ' ' + CONVERT(VARCHAR(100), -@CustBalance, 2) + '.'
									END		
				SELECT @ErrCode = 104
				RETURN
			END	
		-- INSERT AMOUNT INPUTED INTO BETTRANS 
		SET @amount = @AmtTrans	
	END 	
	
	BEGIN TRANSACTION
	
		-- All error messages are the same, so we set it here
		SELECT @ErrMsg = CASE @Language 
								WHEN 'E' THEN 'Clear balance failed. Please try again.'
								ELSE CustDB.dbo.f_Get_MsgNamebyMsgID(50003,@Language)
								END
		
		
		IF @amount >0
		BEGIN
			EXEC Get_Bettrans_TransID @TransID = @TransID OUTPUT
			INSERT INTO Transfer 
			   (transid, creator, custid, username, refno, transdate, bettype, transdesc, winlost, actual_stake, 
				 winlostdate, currency, actualrate,currencyName, mrecommend, srecommend, scomm, swinlost, recommend,ip,statusID, RepUpdateTime)
			VALUES (@transid, @creator, @SAgID, @SAUser, @transcode, current_timestamp, 21003, 'From Customer ::: ' + @MagUser + CASE WHEN @SubAccID > 0 THEN ' (By ' + @SubAccName + ')' ELSE '' END,
				@amount, 0,@WinlostDate, @currency, @actualrate, @currName, 0, @SAgID, 0, 0, 0,@ip,131,SYSDATETIME())
			IF @@Error <> 0
			BEGIN
				SELECT @ErrCode = 103
				ROLLBACK TRANSACTION
				RETURN
			END

			DECLARE @TotalCashMaster MONEY 
			EXEC Acc_CustomerSelCash_CaptureBalance @custid = @Magentid, @TotalCash  = @TotalCashMaster OUTPUT

			EXEC Get_Bettrans_TransID @TransID = @TransID OUTPUT
			INSERT INTO Transfer
				(transid, creator, custid, username, refno, transdate, bettype, transdesc, winlost, actual_stake, 
				winlostdate, currency, actualrate, currencyName, mrecommend, srecommend, scomm, swinlost, recommend,ip,statusID, balance, RepUpdateTime)
			VALUES (@TransID, @creator, @Magentid, @MAgUser, @transcode, current_timestamp, 21003, 'To Customer ::: ' + @saUser + CASE WHEN @SubAccID > 0 THEN ' (By ' + @SubAccName + ')' ELSE '' END, 0, 
				@amount, @WinlostDate, @currency, @actualrate, @currName, @Magentid, @SAgID, 0, 0, 0,@ip,131, @TotalCashMaster,SYSDATETIME())
			IF @@Error <> 0
			BEGIN
				select @ErrCode = 104
				ROLLBACK TRANSACTION
				RETURN
			END

			--Add writelog for each amt transfered - Vinh 20080629
			SELECT @LogData = 'Transfer from Master ' + @MagUser + ' to Super ' + @saUser + ' with amount ' + CONVERT(VARCHAR(20), @amount) + ' Ref.No ' + CONVERT(VARCHAR(20), @transcode)			
			
		END
		ELSE IF @amount<0
		BEGIN
			--SET @amount = abs(@amount)

			EXEC Get_Bettrans_TransID @TransID = @TransID OUTPUT
			INSERT INTO Transfer 
				(transid, creator, custid, username, refno, transdate, bettype, transdesc, winlost, actual_stake, 
				winlostdate, currency, actualrate, currencyName, mrecommend, srecommend, scomm, swinlost, recommend,ip,statusID, RepUpdateTime)
			VALUES (@transid,@creator, @SAgID, @SAUser, @transcode, current_timestamp, 21003, 'To Customer ::: ' + @MagUser + CASE WHEN @SubAccID > 0 THEN ' (By ' + @SubAccName + ')' ELSE '' END, 0, 
				abs(@amount),@WinlostDate, @currency, @actualrate, @currName, 0, @SAgID, 0, 0, 0,@ip,131,SYSDATETIME())
			if @@Error <> 0
			BEGIN
				select @ErrCode = 105
				ROLLBACK TRANSACTION
				RETURN
			END

			DECLARE @TotalCashMasterNev MONEY 
			EXEC Acc_CustomerSelCash_CaptureBalance @custid = @Magentid, @TotalCash  = @TotalCashMasterNev OUTPUT

			EXEC Get_Bettrans_TransID @TransID = @TransID OUTPUT
			INSERT INTO Transfer
				(transid, creator, custid, username, refno, transdate, bettype, transdesc, winlost, actual_stake, 
				winlostdate, currency,actualrate, currencyName, mrecommend, srecommend, scomm, swinlost, recommend,ip,statusID, balance, RepUpdateTime)
			VALUES (@transid, @creator, @Magentid, @MAgUser, @transcode, current_timestamp, 21003, 'From Customer ::: ' + @saUser + CASE WHEN @SubAccID > 0 THEN ' (By ' + @SubAccName + ')' ELSE '' END, 
				abs(@amount), 0, @WinlostDate, @currency, @actualrate, @currName, @Magentid, @SAgID, 0, 0, 0,@ip,131, @TotalCashMasterNev,SYSDATETIME())
			if @@Error <> 0
			BEGIN
				SELECT @ErrCode = 106
				ROLLBACK TRANSACTION
				RETURN
			END
			
			--Add writelog for each amt transfered - Vinh 20080629
			SELECT @LogData = 'Transfer from Super ' + @saUser + ' to Master ' + @MagUser + ' with amount ' + convert(varchar(20), @amount) + ' Ref.No ' + convert(varchar(20), @transcode)			
			
		END
	COMMIT TRANSACTION
	Select @ErrMsg = ''
	
	IF @SubAccID > 0
		SET @LogData = 'SubAccount:' + coalesce(cast(@SubAccName as varchar(30)),space(1)) + ' - ' + @LogData

	SELECT @LogData = @LogData + ' SPName: ' + @procName

	BEGIN TRY
		EXEC DBLOG.bodb_customerlog.dbo.WriteLog_UserLog_Transfer 
							@UserID		= @creator, 
							@FromCustID = @SAgID, 
							@ToCustID	=  @MAgentID, 
							@IP			= @IP, 
							@Doing		= @LogData
	END TRY
	BEGIN CATCH
		SELECT @LogData = @LogData + ' ErrMsg: ' + ERROR_MESSAGE()
	
		EXEC bodb_customerlog.dbo.WriteLog_UserLog_Transfer 
							@UserID		= @creator, 
							@FromCustID = @SAgID, 
							@ToCustID	=  @MAgentID, 
							@IP			= @IP, 
							@Doing		= @LogData
	END CATCH
			
	FETCH NEXT FROM CUR INTO @MAgentID, @Amount,@MAgUser
 END
 CLOSE CUR
 DEALLOCATE CUR
 
DROP TABLE #Master
DROP TABLE #BalanceInfo
DROP TABLE #mrecommend
DROP TABLE #recommend
DROP TABLE #SportBettype
GO