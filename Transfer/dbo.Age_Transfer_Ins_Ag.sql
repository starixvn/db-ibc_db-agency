/*<info serverAlias="DBTXN-bodb02" executers="bodbDownlineNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE  [dbo].[Age_Transfer_Ins_Ag] 
	@FromCustID int, --the customer here
	@ToUserName varchar(30), --the agent here
	@SuperIDsTransferTotal VARCHAR(50)='',  
	@Amount float,
	@creator int,
	@IP nvarchar(15)='',
	@Language varchar(2)= 'E',
	@SubAccID int = 0, --Sub-AccountID
	@IsAllDayBalTransfer BIT = 0,
	@ErrCode int = 0 OUTPUT,
	@ErrMsg nvarchar(4000) = '' OUTPUT
AS
/*
Created: 
Task:	Transfer 
		. Left menu -> Member Information -> Credit/ balance -> Click Column balance -> Button Transfer
DB: DBTXN/bodb02
Original: Age_Transfer_Ins_Ag

Revisions:
    - 20080926@PhuongDao: Store transfer date with correct date 
    - 20090122@[Reviewer]: [Description of revision]    
	- 20090318@Phuc: Korean language
	- 20090417@PhuongDao: Allow some agents to transfer total balance including today balance 
	- 20090729@Phuc: Write log subaccname instead of subaccid.
	- 20090818@Phuc: check page access and check upline closed first(call Age_CustSubCheckPageAccess)
	- 20091003@Kiwi: Modify Write log function and remove CustBetCreditUpdResync
	- 20091125@Kiwi: Remove comstatus because it's no used.
	- 20100424@Henry: insert data to column StatusID of Bettrans (StatusID = 131 for bettype 104) + Update Status = 'Completed'
	- 20100611@Henry: Write exact amount to log when transferring
	- 20101224@Johnson: Apply new arrange of bettype
	- 20110107@Henry: Notification feature when transfer
    - 20111024@Sophia: Update balance credit/debit for member
	- 20120202@Jamie:Change transfer time to 12pm to 11:59pm instead of 12pm to 10pm ( 9h59pm)
	- 20120411@Sophia: Revise balance credit/debit for member	
	- 20121011@Dan: reset yesterday balance for live casino
	- 20121128@Elodie: Get an error message from f_Get_MsgNameByMsgID function by language
	- 20130201@Johnson: write log into DBTXN if failure DBLOG server
	- 20131108@Elodie: Splitting bodb02 into CustDB (Call CustInfo, Customer, Exchange, Age_Transfer_CheckTransferOption by link database)
	- 20150605@Johnson: check existing transfer transaction to prevent transfer twice per day [Redmine:#36177]
	- 20150606@Kathy: Change link server DBTXN.CustDB to DBCUST.CustDB, get credit directly from DBCUST [Redmine:#36216]
	- 20150721@Patrick: Support Gold deluxe
	- 20150808@Elodie: Balance Improvement [Redmine:#40125]
	- 20151021@Elodie: Set @IsForce = 1 for updating balance debit [Redmine:#40125]
	- 20160126@Kathy: get balance from bettransRNG + bettransLC [Redmine:#50674]
	- 20160815@Patrick: Allow SMA to transfer in 24 hours [Redmine:#61626]
	- 20160912@Percy: Expand time 24h for Agent transfer member [RedmineID: #62961]
	- 20170609@Percy:
		1. Re-check [Allow SMA to transfer in 24 hours]: apply general sp Acc_CheckProcessingData [RedmineID: #78487]
		2. Change way to calculate balance [RedmineID: #74291]
	- 20170831@Percy: Add SP Name into log [RedmineID: #80978]
	- 20180521@Percy: Correct table name: bettransLC to translog [RedmineID: #95268]
	- 20200602@Percy: Separate PendingTransfer3rd from Cash and Balance [RedmineID: #135200]
	- 20200821@Sophia: prevent duplicated transfer [Redmine: #137141]
	- 20200821@Sophia: Check UM Transfer Function [Redmine: #136992]
	- 20201005@Danny: Convert Ipv6 to dummy IPv4 [Redmine: #142511]
	- 20201015@Malcolm : Add sub account information when transfering [RedmineId : #143478]
	- 20201228@Danny: Capture total cash before transfering  [Redmine: #146038]
	- 20210505@Sol: NAP - Alpha - Allow more time for transfer - [Redmine: #149927]
	
Param's Explanation:
• @FromCustID: from customer
• @ToUserName: to user
• @Amount: amount of money
  @SuperIDsTransferTotal: Supers are allowed to tranfer total balance including today balance 
*/

Declare @RefNo bigint, @ToCustID int, @MRecommend1 int, @agentid int, @custid int, @grefno int, @srecommend int
DECLARE @currency int, @actualrate float, @currName nvarchar(10) , @User nvarchar(50)
DECLARE @agUser nvarchar(50), @ABSamount MONEY
DECLARE @SubAccName VARCHAR(30) = ''

select @IP = dbo.f_ConvertIPv6ToDummy(@IP)

Select @ToCustID = null
select @ToCustID = CustID FROM CustDB.dbo.customer with (NOLOCK) where username = @ToUserName
if @ToCustID is NULL or @ToCustID = 0
BEGIN
	Select @ErrMsg = case @Language 
			when 'E' then 'Customer does not exist' + ': ' + @ToUserName			
			ELSE [dbo].[f_Get_MsgNamebyMsgID](40014,@Language) + ': ' + @ToUserName	
	end, @ErrCode = 101		
	return
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
	
----------------------------------------------------------------------
--Check Transfer Condition
--1		2		3		4		5		6		7		8
--isSun	isMon	isTue	isWed	isThurs	isFri	isSat	isWeekly
--0		1		0		0		1		0		1		1

EXEC DBCUST.CustDB.dbo.Age_Transfer_CheckTransferOption
	@CustID = @ToCustID,
	@ErrMsg = @ErrMsg OUTPUT,
	@ErrCode = @ErrCode OUTPUT,
	@Language = @Language

if @ErrCode <> 0  return

-- Checking archive data
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

if not exists (select 1 FROM CustDB.dbo.customer with (NOLOCK) where custid = @FromCustID and recommend = @ToCustID)
BEGIN
	Select @ErrMsg = case @Language 
		when 'E' then 'Customer does not exist.'
		ELSE [dbo].[f_Get_MsgNamebyMsgID](40014,@Language)
	end, @ErrCode = 103
	return
END

Select @AgentID = @ToCustID, @CustID = @FromCustID
  

Declare @today DATETIME
set @today = cast(datediff(dd,0,getdate()) as datetime)

IF @IsAllDayBalTransfer = 0
BEGIN
	IF EXISTS (SELECT TOP 1 1	
				FROM 
					bettrans WITH (NOLOCK)
				WHERE 
					custid=@custid AND
					bettype in (21003, 21004) AND
					CONVERT(DATE, transdate) = @today AND
					liveindicator = 0 
			)
	BEGIN
		Select @ErrMsg = case @Language 
			when 'E' then 'You can only transfer one per everyday!'
			ELSE [dbo].[f_Get_MsgNamebyMsgID](50009,@Language)
		end, @ErrCode = 105
		return		
	END
END
 
 Declare @CustBalance MONEY 
 Declare @CustOutstanding MONEY
 Declare @PendingTransfer3rd MONEY
 Declare @Credit MONEY 
 Declare @FutureCreditBalance MONEY
 Declare @WinlostDate datetime
 
 SET @CustOutstanding = 0
  --Check valid balance
 --Balance calculated with the correct transfer date @Phuong20080926
 
 select @WinlostDate = convert(nvarchar(10), current_timestamp,120)

DECLARE @yesterday SMALLDATETIME
SELECT  @yesterday = DATEADD(DAY, -1, CONVERT(DATE, GETDATE()))

-- get move bet date
DECLARE @balanceUpDay DATE, @moveBetsDay DATE
DECLARE @tblMoveBetBalanceUp AS TABLE (BalanceUpDay DATE, MoveBetsDay DATE)

INSERT INTO @tblMoveBetBalanceUp(BalanceUpDay,MoveBetsDay)
EXEC bodb02.dbo.Age_SelBalanceUpDay
	
SELECT @balanceUpDay = BalanceUpDay, @moveBetsDay = MoveBetsDay FROM @tblMoveBetBalanceUp

-- Get bettype --
DECLARE @isTest BIT = 0
SELECT  @isTest = dbo.f_CheckSPVersion(@@PROCID)
	
CREATE TABLE #SportBettype (bettype INT, RefTable TINYINT)
INSERT INTO #SportBettype (bettype, RefTable)
SELECT bettype, RefTable FROM dbo.f_SportBettypeMatrix_Sel (0, 0, 0, 2, '', '', @isTest)

CREATE TABLE #BalanceInfo (Balance MONEY, Outstanding MONEY, PendingTransfer3rd MONEY)

if @SubAccID > 0 
begin	
	SELECT @SubAccName = username 
	FROM DBCUST.CustDB.dbo.custSub WITH(NOLOCK) 
	WHERE SubAccID = @SubAccID
end
 --Total balance including today balance 
 IF (SELECT srecommend FROM CustDB.dbo.custInfo WITH (NOLOCK) WHERE custid = @ToCustID AND roleid = 2) IN (SELECT CONVERT(INT,val) FROM dbo.strSplit(@SuperIDsTransferTotal, ','))
 BEGIN 
	-- bettransRnG
	INSERT INTO #BalanceInfo (Balance, Outstanding)
	SELECT
		ISNULL(SUM(CASE WHEN statusID NOT IN (0, 1) THEN winlost-actual_stake+playercomm ELSE 0 END), 0),
		ISNULL(SUM(CASE WHEN statusID IN (0, 1) THEN ABS(actual_stake) ELSE 0 END), 0)
	FROM dbo.bettransRnG WITH (NOLOCK) 
	WHERE custid = @CustID
		AND (
			statusID IN (0, 1)
			OR winlostdate >= @yesterday
		)

	-- bettransLC
	INSERT INTO #BalanceInfo (Balance, Outstanding)
	SELECT
		ISNULL(SUM(CASE WHEN statusID NOT IN (0, 1) THEN winlost-actual_stake+playercomm ELSE 0 END), 0),
		ISNULL(SUM(CASE WHEN statusID IN (0, 1) THEN ABS(actual_stake) ELSE 0 END), 0)
	FROM dbo.bettransLC WITH (NOLOCK) 
	WHERE custid = @CustID
		AND (
			statusID IN (0, 1)
			OR winlostdate >= @yesterday
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

	INSERT INTO #BalanceInfo (Balance, Outstanding, PendingTransfer3rd)
	SELECT
		ISNULL(SUM(CASE WHEN bettype IN (21008, 21009) THEN 0 ELSE winlost-actual_stake+playercomm END), 0),
		0,
		ISNULL(SUM(CASE WHEN bettype IN (21008, 21009) THEN -(winlost-actual_stake) ELSE 0 END), 0)
	FROM dbo.bettrans b WITH(NOLOCK)
	WHERE b.custid = @custid
		AND b.ruben = 1
		AND (
			b.winlostdate < @yesterday
			OR NOT EXISTS (SELECT TOP 1 1 FROM #SportBettype s WHERE s.Bettype = b.bettype AND s.RefTable IN (1, 2))
		)
		AND 1 = CASE 
			WHEN bettype = 19999 and winlostdate > @moveBetsDay THEN 0 --> get data from ticket detail
			WHEN bettype < 19999 and winlostdate <= @moveBetsDay THEN 0 --> get data from sum record
		ELSE 1 END

	SELECT
		@CustBalance = SUM(Balance),
		@CustOutstanding = -SUM(Outstanding),
		@PendingTransfer3rd = SUM(ISNULL(PendingTransfer3rd, 0))
	FROM #BalanceInfo
 END 
 --Yesterday Balance  
 ELSE 
 BEGIN 
	 -- bettransRnG
	INSERT INTO #BalanceInfo (Balance, Outstanding)
	SELECT
		ISNULL(SUM(CASE WHEN statusID NOT IN (0, 1) THEN winlost-actual_stake+playercomm ELSE 0 END), 0),
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
		ISNULL(SUM(CASE WHEN statusID NOT IN (0, 1) THEN winlost-actual_stake+playercomm ELSE 0 END), 0),
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

	INSERT INTO #BalanceInfo (Balance, Outstanding, PendingTransfer3rd)
	SELECT
		ISNULL(SUM(CASE WHEN bettype IN (21008, 21009) THEN 0 ELSE winlost-actual_stake+playercomm END), 0),
		0,
		ISNULL(SUM(CASE WHEN bettype IN (21008, 21009) THEN -(winlost-actual_stake) ELSE 0 END), 0)
	FROM dbo.bettrans b WITH(NOLOCK)
	WHERE b.custid = @custid
		AND b.ruben = 1
		AND (
			b.winlostdate < @yesterday
			OR b.bettype > 20000
			OR (
				winlostdate = @yesterday
				AND NOT EXISTS (SELECT TOP 1 1 FROM #SportBettype s WHERE s.Bettype = b.bettype AND s.RefTable IN (1, 2))
			)
		)
		AND 1 = CASE 
			WHEN bettype = 19999 and winlostdate > @moveBetsDay THEN 0 --> get data from ticket detail
			WHEN bettype < 19999 and winlostdate <= @moveBetsDay THEN 0 --> get data from sum record
		ELSE 1 END

	SELECT
		@CustBalance = SUM(Balance),
		@CustOutstanding = -SUM(Outstanding),
		@PendingTransfer3rd = SUM(ISNULL(PendingTransfer3rd, 0))
	FROM #BalanceInfo
 END 


SELECT @User = username, @Credit = credit
FROM DBCUST.CustDB.dbo.custinfo with (nolock) WHERE custid = @custid AND roleid = 1
  
if @amount = 0
	or (@CustBalance >= 0 AND (@Amount <= 0 or @Amount > @CustBalance))
	or (@CustBalance < 0 AND (@Amount >= 0 or @Amount < @CustBalance))
BEGIN
	Select @ErrMsg = case @Language 
		when 'E' then 'Amount to transfer must be between 0 and' + ' ' + convert(varchar(100), -@CustBalance, 2) +'.'
		ELSE [dbo].[f_Get_MsgNamebyMsgID](50005,@Language) + ' ' + convert(varchar(100), -@CustBalance, 2) + '.'
	end		
	select @ErrCode = 104
	return
END


set @FutureCreditBalance = @Credit + @CustBalance + @CustOutstanding - @PendingTransfer3rd - @Amount
set @FutureCreditBalance = isnull(@FutureCreditBalance,0)


----------------------------------------------------------

SELECT @currency = c.currency,@actualrate = e.actualrate, @currName = e.currency, 
       @agUser = c.username,@MRecommend1 = c.mrecommend,@srecommend = c.srecommend 
FROM CustDB.dbo.custinfo c with (NOLOCK) 
	INNER JOIN CustDB.dbo.Exchange e with (NOLOCK) on c.currency = e.exchangeid 
WHERE custid = @agentid AND roleid = 2

BEGIN TRANSACTION
	UPDATE ref with (rowlock, UPDLOCK)  SET   @grefno=transcode=transcode+1
	WHERE  refid='acc'

	if @@Error <> 0
	BEGIN
		ROLLBACK TRANSACTION
		return
	END		

	select @RefNo=200000000000+@grefno
COMMIT TRANSACTION
----------------------------------

------------------Insert trans into DB---------------------------------------------------------------
	declare @LogData nvarchar(500)
			
    -- All error messages are the same, so we set it here
	Select @ErrMsg = case @Language 
						when 'E' then 'Transfer failed. Please try again.'
						ELSE [dbo].[f_Get_MsgNamebyMsgID](50006,@Language)
					end
	IF @amount > 0
	BEGIN
		INSERT INTO bettrans 
		   (matchid, creator, custid, username, refno, transdate, bettype, transdesc, winlost, actual_stake, 
			status, ruben, winlostdate, currency, actualrate, currencyName,recommend, mrecommend, srecommend, 
			scomm, swinlost,ip,statusID)
		VALUES 
		   (0, @creator, @agentid, @agUser, @RefNo, CURRENT_TIMESTAMP, 21004, 'From Customer :: ' + @User + CASE WHEN @SubAccID > 0 THEN ' (By ' + @SubAccName + ')' ELSE '' END, 
			@amount, 0, 'Completed', 1, @WinlostDate, @currency, @actualrate, @currName, @agentid, @MRecommend1, @srecommend, 
			0, 0,@ip,131)
		if @@Error <> 0
		BEGIN
			select @ErrCode = 104
			
			----Manually rollback----
			DELETE FROM bettrans where refno = @RefNo and matchid = 0
			
			return
		END	
		
		---update debit balance
		--EXEC Dot_BalanceUpdDebit @CustID = @CustID, @balance = @amount  
				EXEC Dot_BalanceDebitUpd @CustID = @CustID, @balance = @amount, @type = 2, @IsForced = 1, @errCode = @ErrCode OUTPUT
		IF @ErrCode <> 0
		BEGIN
			select @ErrCode = 104
			
			----Manually rollback----
			DELETE FROM bettrans where refno = @RefNo and matchid = 0
			
			return
		END

		DECLARE @TotalCash1 MONEY 
		EXEC Acc_CustomerSelCash_CaptureBalance @custid = @custid, @TotalCash  = @TotalCash1 OUTPUT
						
		INSERT INTO bettrans
		   (matchid, creator, custid, username, refno, transdate, bettype, transdesc, winlost, actual_stake, 
			status, ruben, winlostdate, currency, actualrate, currencyName, recommend, mrecommend, srecommend, 
			scomm, swinlost,ip,statusID, balance)
		VALUES (0, @creator, @custid, @User, @RefNo, CURRENT_TIMESTAMP, 21004, 'To Customer :: ' + @agUser + CASE WHEN @SubAccID > 0 THEN ' (By ' + @SubAccName + ')' ELSE '' END, 
			0, @amount, 'Completed', 1, @WinlostDate, @currency,@actualrate,@currName, @agentid, @MRecommend1, @srecommend, 
			0, 0,@ip,131, @TotalCash1)
		if @@Error <> 0
		BEGIN
			select @ErrCode = 105			
			----Manually rollback----
			DELETE FROM bettrans where refno = @RefNo and matchid = 0
			---rollback balance
			--EXEC Dot_BalanceUpdCredit @CustID = @CustID, @balance = @amount 
			EXEC Dot_BalanceCreditUpd @CustID = @CustID, @balance = @amount, @type = 2
			return
		END		

		Select @LogData = 'Transfer from Customer ' + @User + ' to Agent ' + @agUser + ' with amount ' + convert(varchar(20), @amount) + ' Ref.No ' + convert(varchar(20), @RefNo)
		
		if @CustBalance > 0 and @FutureCreditBalance < 0 
		Select @LogData = @LogData + '. The agent decided to transfer after the warning so the bet credit of this member turned to negative value (' + convert(varchar(100), @FutureCreditBalance, 2) + ') caused by having outstanding balance value ('+ convert(varchar(100), @CustOutstanding, 2) +')  '
	END
	ELSE IF @amount <0 
	BEGIN
		--SET @amount = abs(@amount)
	
		INSERT INTO bettrans 
		   (matchid, creator, custid, username, refno, transdate, bettype, transdesc, winlost, actual_stake, 
			status, ruben, winlostdate, currency, actualrate, currencyName, recommend, mrecommend, srecommend, 
			scomm, swinlost,ip,statusID)
		VALUES (0, @creator, @agentid, @agUser, @RefNo, CURRENT_TIMESTAMP, 21004, 'To Customer :: ' + @User + CASE WHEN @SubAccID > 0 THEN ' (By ' + @SubAccName + ')' ELSE '' END, 
			0, abs(@amount), 'Completed', 1, @WinlostDate, @currency, @actualrate,@currName, @agentid, @MRecommend1, @srecommend, 
			0, 0,@ip,131)
		if @@Error <> 0
		BEGIN
			select @ErrCode = 106
			
			----Manually rollback----
			DELETE FROM bettrans where refno = @RefNo and matchid = 0
			
			RETURN
		END		

		DECLARE @TotalCash3 MONEY 
		EXEC Acc_CustomerSelCash_CaptureBalance @custid = @custid, @TotalCash  = @TotalCash3 OUTPUT

		INSERT INTO bettrans
		   (matchid, creator, custid, username, refno, transdate, bettype, transdesc, winlost, actual_stake, 
			status, ruben, winlostdate, currency, actualrate, currencyName, recommend, mrecommend, srecommend, 
			scomm, swinlost,ip,statusID, balance)
		VALUES 
		   (0, @creator, @custid, @User, @RefNo, CURRENT_TIMESTAMP, 21004, 'From Customer :: ' + @agUser + CASE WHEN @SubAccID > 0 THEN ' (By ' + @SubAccName + ')' ELSE '' END, 
			abs(@amount), 0, 'Completed', 1,@WinlostDate, @currency, @actualrate, @currName, @agentid, @MRecommend1, @srecommend, 
			0, 0,@ip,131,@TotalCash3)
		if @@Error <> 0
		BEGIN
			select @ErrCode = 107
			
			----Manually rollback----
			DELETE FROM bettrans where refno = @RefNo and matchid = 0
			
			RETURN 
		END
		---update credit balance
		SELECT @ABSamount = abs(@amount)
		--EXEC Dot_BalanceUpdCredit @CustID = @CustID, @balance = @ABSamount 
		EXEC Dot_BalanceCreditUpd @CustID = @CustID, @balance = @ABSamount, @type = 2
								
		Select @LogData = 'Transfer from Agent ' + @agUser + ' to Customer ' + @User + ' with amount ' + convert(varchar(20), @amount) + ' Ref.No ' + convert(varchar(20), @RefNo)
				
	END		

DECLARE @isResetYesterdayBalance BIT, @ErrCode_ResetYesterdayBalance BIT, @YesterdayBalance MONEY
-- reset yesterday balance for live casino				
EXEC Acc_BalanceGameResetYesterday @CustID = @CustID, @isResetYesterdayBalance = @isResetYesterdayBalance OUTPUT, @YesterdayBalance = @YesterdayBalance	 OUTPUT, @ErrCode = @ErrCode_ResetYesterdayBalance OUTPUT	
Select @LogData = @LogData + CASE WHEN @isResetYesterdayBalance = 1 THEN 
									CASE WHEN @ErrCode_ResetYesterdayBalance = 0 THEN '. (ResetGameBalance = suscess, YesterdayBalance =' + CAST(@YesterdayBalance AS VARCHAR(50)) + ')' 
									ELSE '. (ResetGameBalance = fail)' END		
							ELSE '' END			

Select @ErrMsg = ''

---------------------------------------------------------------------------------------------------
-- ***Check Sub-Account***


if @SubAccID > 0 
begin	
	SET @LogData = 'SubAccount:' +  coalesce(@SubAccName,space(1)) + ' - ' + @LogData
end
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
GO