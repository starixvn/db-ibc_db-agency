/*<info serverAlias="DBTXN-bodb02" executers="bodbDownlineNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE  [dbo].[Age_Transfer_InsClearBalance_Ag]
	@FromCustID int, --Agent ID here  
	@ToCustIDs varchar(4000),   
	@SuperIDsTransferTotal VARCHAR(50)='', 
	@creator int,  
	@Language varchar(2)= 'E',  
	@SubAccID int = 0, --Sub-AccountID  
	@IP varchar(45)='',
	@ErrCode int = 0 OUTPUT,  
	@ErrMsg nvarchar(4000) = '' OUTPUT,  
	@CustStatus varchar(50)='',
	@IsAllDayBalTransfer BIT = 0
AS  
/*
Created: 
Task: Transfer/ Multiple Transfer	
DB: DBTXN/bodb02
Original: Age_Transfer_InsClearBalance_Ag

Revisions:
	- 20060225@: remove refno.
	- 20090318@Phuc: Korean language.
	- 20090417@PhuongDao: Allow some agents to transfer total balance including today balance 
	- 20090729@Phuc: Write log subaccname instead of subaccid.
	- 20090818@Phuc: check page access and check upline closed first(call Age_CustSubCheckPageAccess)
	- 20091003@Kiwi: Modify Write log function and remove CustBetCreditUpdResync
	- 20091209@Kiwi: Remove comstatus because it's no used.	
	- 20100424@Henry: insert data to column StatusID of Bettrans (StatusID = 131 for bettype 104)
	- 20100611@Henry: Write exact amount to log when transferring
	- 20101224@Johnson: Apply new arrange of bettype
	- 20110107@Henry: Notification feature when transfer
	- 20111024@Sophia: Update balance credit/debit for member
	- 20120104@Lukas: modify to filter by 'enabled' status
	- 20120202@Jamie: Change transfer time to 12pm to 11:59pm instead of 12pm to 10pm ( 9h59pm)
	- 20120412@Sophia: Revise update balance credit/debit for member
	- 20121011@Dan: reset yesterday balance for live casino
	- 20121128@Elodie: Get an error message from f_Get_MsgNameByMsgID function by language
	- 20121203@Dan: skip deleted transfer record when check existed transfer
	- 20130201@Johnson: write log into DBTXN if failure DBLOG server
	- 20131108@Elodie: Splitting bodb02 into CustDB (Call CustInfo, Exchange, Customer, Age_Transfer_CheckTransferOption by link database)
	- 20150606@Kathy: Change link server DBTXN.CustDB to DBCust.CustDB, get Credit directly from DBCust [Redmine:#36216]
	- 20150721@Patrick: Support Gold deluxe
	- 20150808@Elodie: Balance Improvement [Redmine:#40125]
	- 20151021@Elodie: Set @IsForce = 1 for updating balance debit [Redmine:#40125]
	- 20160126@Kathy: get balance from bettransRNG + bettransLC [Redmine:#50674]
	- 20160815@Patrick: Allow SMA to transfer in 24 hours [Redmine:#61626]
	- 20170609@Percy:
		1. Re-check [Allow SMA to transfer in 24 hours]: apply general sp Acc_CheckProcessingData [RedmineID: #78487]
		2. Change way to calculate balance [RedmineID: #74291]
	- 20170721@Percy: Enhance performance - Phase 1 [RedmineID: #80367]
	- 20170808@Percy: Enhance performance - Phase 2 [RedmineID: #81436]
	- 20170831@Percy: Add SP Name into log [RedmineID: #80978]
	- 20200602@Percy: Separate PendingTransfer3rd from Cash and Balance [RedmineID: #135200]
	- 20200821@Sophia: prevent duplicated transfer [Redmine: #137141]
	- 20200821@Sophia: Check UM Transfer Function [Redmine: #136992]
	- 20201005@Danny: Convert Ipv6 to dummy IPv4 [Redmine: #142511]
	- 20201015@Malcolm : Add sub account information when transfering [RedmineId : #143478]
	- 20201228@Danny: Capture total cash before transfering  [Redmine: #146038]
	- 20210603@Sol: Alpha - All Sites - Lock account & indirect close account - [RedmineID: #148600]
	- 20210726@Evan: Transfer all pages work incorrect with disabled account [RedmineID: #158813]
	- 20210505@Sol: NAP - Alpha - Allow more time for transfer - [Redmine: #149927]
	- 20210817@Sophia: Fix overflow Refno [Redmine: #160262]
	- 20211111@Evan: Split transfer tickets out of bettrans - [Redmine: #164196]
	- 20220315@Evan: SQL Server Upgrade STRING_SPLIT [Redmine: #168783]
	- 20220721@Danny: get transid and refno with new generation [Redmine: #175670]
	- 20230227@Evan: Balance-Up support transfer 247 [Redmine: #173554] 

Param's Explanation:
• @FromCustID: list from custid
• @ToCustIDs: list to custid
  @SuperIDsTransferTotal: Supers are allowed to tranfer total balance including today balance 
  @IsAllDayBalTransfer: allow transfer many times per day

*/

SET NOCOUNT ON  

Declare @LogData nvarchar(500)  
Declare @agentid int, @custid int  
DECLARE @currency int, @actualrate float, @currName nvarchar(10)    
DECLARE @agUser nvarchar(50), @User nvarchar(50)  
Declare @RefNo bigint, @ToCustID int, @Amount float, @Recommend1 int, @MRecommend1 int, @Recommend2 int, @MRecommend2 int, @grefno BIGINT, @srecommend1 int, @TransID BIGINT  
Declare @Outstanding MONEY, @credit MONEY, @FutureBetCredit MONEY, @ABSamount MONEY, @PendingTransfer3rd MONEY

EXEC DBCUST.CustDB.dbo.Age_Transfer_CheckTransferOption   
 @CustID = @FromCustID,  
 @ErrMsg = @ErrMsg OUTPUT,  
 @ErrCode = @ErrCode OUTPUT,  
 @Language = @Language  
   
if @ErrCode > 0  
BEGIN  
  return  
END

 if not exists (select 1 FROM CustDB.dbo.customer with (NOLOCK) where custid = @FromCustID)  
 BEGIN  
	 select @ErrCode = 102  
	 Select @ErrMsg = case @Language   
		   when 'E' then 'Customer does not exist.'  
		   ELSE [dbo].[f_Get_MsgNamebyMsgID](40014,@Language)
		  end    
	 return  
 END  
  
SELECT @AgentID = @FromCustID  
 
---- #1 CHECK UM TRANSFER FUNCTION
EXEC DBCUST.CUSTDB.dbo.Acc_Transfer_CheckUM  
	@CustID = @AgentID
	,@Language = @Language
	,@ErrMsg = @ErrMsg OUTPUT 
	,@ErrCode = @ErrCode OUTPUT
	 
IF @ErrCode <> 0  -- Function Transfer is under UM 
BEGIN	
	RETURN		
END		

---- #2 CHECK FLAG ISTRANSFERRING = 1 THEN RAISE ERROR
EXEC DBCUST.CUSTDB.dbo.Acc_Transfer_CheckRunningByCust  
		@CustID = @AgentID
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

 SELECT @currency = ci.currency, @actualrate = e.actualrate, @currName = e.currency, @agUser = ci.username, 
        @Recommend1 = ci.recommend, @MRecommend1 = ci.mrecommend, @srecommend1 = ci.srecommend  
 FROM CustDB.dbo.custinfo ci (nolock) 
	INNER JOIN CustDB.dbo.Exchange e with (NOLOCK) on ci.currency = e.exchangeid 
 WHERE custid = @agentid AND roleid = 2  
 
 ---Calculated Balance saved in Temp Table  @Phuong09152008
 CREATE TABLE #Member (	custid int PRIMARY KEY,
					    memberName nvarchar(50),	
						memberBalance money DEFAULT 0,
						memberOutstanding money DEFAULT 0,
						memberCredit money DEFAULT 0,
						memberPendingTransfer3rd money DEFAULT 0
					 ) 
 
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

IF (@CustStatus <> '' OR @CustStatus <> null)
BEGIN
	INSERT INTO #custid (CustId)
	SELECT c.custid
	FROM CustDB.dbo.custInfo c WITH(NOLOCK,index=IX_custinfo_1)  
	INNER JOIN CustDB.dbo.CustProductStatus cs with(nolock) on c.custid=cs.CustID
	WHERE	recommend = @AgentID 
			AND c.roleid = 1   
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
	INSERT INTO #custid (CustId)
	SELECT CONVERT(INT, value) AS CustId
	FROM STRING_SPLIT(@ToCustIDs, ',')
END

/* *********** Calculating balance *********** */
/* Note: using recommend = @AgentId on bettrans, bettransRnG, bettransLC, translog to using index on recommend column */

  --TOTAL BALANCE INCLUDING TODAY BALANCE 
 IF (SELECT srecommend FROM CustDB.dbo.custInfo (NOLOCK) WHERE custid = @AgentID AND roleid = 2) IN (SELECT CONVERT(INT,value) FROM STRING_SPLIT(@SuperIDsTransferTotal, ','))
 BEGIN 
	-- bettransRnG
	INSERT INTO #BalanceInfo (CustId, Balance, Outstanding)
	SELECT
		custid,
		ISNULL(SUM(CASE WHEN statusID IN (111, 112, 113) THEN winlost-actual_stake+playercomm ELSE 0 END), 0),
		ISNULL(SUM(CASE WHEN statusID IN (0, 1) THEN ABS(actual_stake) ELSE 0 END), 0)
	FROM dbo.bettransRnG b WITH (NOLOCK) 
	WHERE b.recommend = @AgentID
		AND (
			statusID IN (0, 1)
			OR winlostdate >= @yesterday
		)
	GROUP BY custid

	-- bettransLC
	INSERT INTO #BalanceInfo (CustId, Balance, Outstanding)
	SELECT
		custid,
		ISNULL(SUM(CASE WHEN statusID IN (111, 112, 113) THEN winlost-actual_stake+playercomm ELSE 0 END), 0),
		ISNULL(SUM(CASE WHEN statusID IN (0, 1) THEN ABS(actual_stake) ELSE 0 END), 0)
	FROM dbo.bettransLC b WITH (NOLOCK) 
	WHERE b.recommend = @AgentID
		AND (
			statusID IN (0, 1)
			OR winlostdate >= @yesterday
		)
	GROUP BY custid
	
	-- translog
	INSERT INTO #BalanceInfo (CustId, Balance, Outstanding)
	SELECT
		custid,
		0,
		ISNULL(SUM(ABS(actual_stake)), 0)
	FROM dbo.translog t WITH (NOLOCK) 
	WHERE t.recommend = @AgentID
		AND statusID IN (0, 1)
	GROUP BY custid

	-- bettrans
	INSERT INTO #BalanceInfo (CustId, Balance, Outstanding)
	SELECT
		custid,
		0,
		ISNULL(SUM(ABS(actual_stake)), 0)
	FROM dbo.bettrans b WITH(NOLOCK)
	WHERE b.recommend = @AgentID
		AND b.ruben = 0
		AND NOT EXISTS (SELECT TOP 1 1 FROM #SportBettype s WHERE s.Bettype = b.bettype AND s.RefTable <> 0)
	GROUP BY custid
	
	WHILE (@IsDiff = 1)
	BEGIN
		DELETE FROM #BalanceInfo WHERE TableName IN ('tblBettrans','tblTransfer')

		INSERT INTO #BalanceInfo (CustId, Balance, Outstanding, PendingTransfer3rd, TableName)
		SELECT
			custid,
			ISNULL(SUM( winlost-actual_stake+playercomm ), 0),
			0,
			0,
			'tblBettrans'
		FROM dbo.bettrans b WITH(NOLOCK)
		WHERE b.recommend = @AgentID
			AND b.statusID IN (111, 112, 113)
			AND (
				b.winlostdate < @yesterday
				OR NOT EXISTS (SELECT TOP 1 1 FROM #SportBettype s WHERE s.Bettype = b.bettype AND s.RefTable IN (1, 2))
			)
			AND winlostdate > @moveBetsDay
		GROUP BY custid

		INSERT INTO #BalanceInfo (CustId, Balance, Outstanding, PendingTransfer3rd, TableName)
		SELECT
			custid,
			ISNULL(SUM(CASE WHEN bettype IN (21008, 21009) THEN 0 ELSE winlost-actual_stake+playercomm END), 0),
			0,
			ISNULL(SUM(CASE WHEN bettype IN (21008, 21009) THEN -(winlost-actual_stake) ELSE 0 END), 0),
			'tblTransfer'
		FROM dbo.Transfer b WITH(NOLOCK)
		WHERE b.recommend = @AgentID
					AND 1 = CASE WHEN bettype = 19999 AND winlostdate > @moveBetsDay THEN 0 --> new sum
												WHEN bettype = 20000 AND winlostdate > @balanceUpDay THEN 0 --> new bal
												WHEN winlostdate < @balanceUpDay THEN 0 --> old data
										ELSE 1 END
		GROUP BY custid
		
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
 --Yesterday Balance  
 ELSE 
 BEGIN 
	-- bettransRnG
	INSERT INTO #BalanceInfo (CustId, Balance, Outstanding)
	SELECT
		custid,
		ISNULL(SUM(CASE WHEN statusID IN (111, 112, 113) THEN winlost-actual_stake+playercomm ELSE 0 END), 0),
		ISNULL(SUM(CASE WHEN statusID IN (0, 1) THEN ABS(actual_stake) ELSE 0 END), 0)
	FROM dbo.bettransRnG b WITH (NOLOCK) 
	WHERE b.recommend = @AgentID
		AND (
			statusID IN (0, 1)
			OR winlostdate = @yesterday
		)
	GROUP BY custid

	-- bettransLC
	INSERT INTO #BalanceInfo (CustId, Balance, Outstanding)
	SELECT
		custid,
		ISNULL(SUM(CASE WHEN statusID IN (111, 112, 113) THEN winlost-actual_stake+playercomm ELSE 0 END), 0),
		ISNULL(SUM(CASE WHEN statusID IN (0, 1) THEN ABS(actual_stake) ELSE 0 END), 0)
	FROM dbo.bettransLC b WITH (NOLOCK) 
	WHERE b.recommend = @AgentID
		AND (
			statusID IN (0, 1)
			OR winlostdate = @yesterday
		)
	GROUP BY custid
	
	-- translog
	INSERT INTO #BalanceInfo (CustId, Balance, Outstanding)
	SELECT
		custid,
		0,
		ISNULL(SUM(ABS(actual_stake)), 0)
	FROM dbo.translog t WITH (NOLOCK) 
	WHERE t.recommend = @AgentID
		AND statusID IN (0, 1)
	GROUP BY custid

	-- bettrans
	INSERT INTO #BalanceInfo (CustId, Balance, Outstanding)
	SELECT
		custid,
		0,
		ISNULL(SUM(ABS(actual_stake)), 0)
	FROM dbo.bettrans b WITH(NOLOCK)
	WHERE b.recommend = @AgentID
		AND b.ruben = 0
		AND NOT EXISTS (SELECT TOP 1 1 FROM #SportBettype s WHERE s.Bettype = b.bettype AND s.RefTable <> 0)
	GROUP BY custid

	WHILE (@IsDiff = 1)
	BEGIN

		DELETE FROM #BalanceInfo WHERE TableName IN ('tblBettrans','tblTransfer')

		INSERT INTO #BalanceInfo (CustId, Balance, Outstanding, PendingTransfer3rd, TableName)
		SELECT
			custid,
			ISNULL(SUM(winlost-actual_stake+playercomm ), 0),
			0,
			0,
			'tblBettrans'
		FROM dbo.bettrans b WITH(NOLOCK)
		WHERE b.recommend = @AgentID
			AND b.statusID IN (111, 112, 113)
			AND (
				b.winlostdate < @yesterday
				OR (
					winlostdate = @yesterday
					AND NOT EXISTS (SELECT TOP 1 1 FROM #SportBettype s WHERE s.Bettype = b.bettype AND s.RefTable IN (1, 2))
				)
			)
			AND winlostdate > @moveBetsDay
		GROUP BY custid

		INSERT INTO #BalanceInfo (CustId, Balance, Outstanding, PendingTransfer3rd, TableName)
			SELECT
				custid,
				ISNULL(SUM(CASE WHEN bettype IN (21008, 21009) THEN 0 ELSE winlost-actual_stake+playercomm END), 0),
				0,
				ISNULL(SUM(CASE WHEN bettype IN (21008, 21009) THEN -(winlost-actual_stake) ELSE 0 END), 0),
				'tblTransfer'
			FROM dbo.Transfer b WITH(NOLOCK)
			WHERE b.recommend = @AgentID
				AND (
					b.winlostdate <= @yesterday
					OR b.bettype > 20000
				)
				AND 1 = CASE WHEN bettype = 19999 AND winlostdate > @moveBetsDay THEN 0 --> new sum
										WHEN bettype = 20000 AND winlostdate > @balanceUpDay THEN 0 --> new bal
										WHEN winlostdate < @balanceUpDay THEN 0 --> old data
								ELSE 1 END
			GROUP BY custid
		
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

/* *********** End Calculating balance *********** */

/* Filtering input custids */
 INSERT INTO #Member (custid, memberName, memberBalance, memberOutstanding, memberCredit, memberPendingTransfer3rd)
 SELECT b.CustId, '', SUM(Balance), SUM(Outstanding), 0, SUM(ISNULL(PendingTransfer3rd, 0))
 FROM #BalanceInfo b
	INNER JOIN #custid c ON b.CustId = c.CustId
 GROUP BY b.CustId
/* End Filtering input custids */

 DELETE FROM #Member WHERE memberBalance = 0

 if not exists (select 1 from #Member)
 BEGIN
	Select @ErrMsg = case @Language   
		when 'E' then 'Cannot transfer because all downlines'' balance is 0!' 
		ELSE [dbo].[f_Get_MsgNamebyMsgID](50002,@Language)
	end, @ErrCode = 103     
 
	RETURN	
 END
 
 --Update member credit of table #Member
 Update #Member 
 SET #Member.memberCredit = c.credit, #Member.memberName = c.username 
 FROM #Member INNER JOIN DBCUST.CustDB.dbo.custinfo c with (nolock) ON #Member.custid = c.custid
 
 DECLARE @procName VARCHAR(100)
 SELECT  @procName = OBJECT_NAME(@@PROCID)

 DECLARE CUR Cursor FOR SELECT custid, memberName, memberBalance, memberOutstanding, memberCredit, memberPendingTransfer3rd
						FROM #Member  
 
 DECLARE @ErrItems nvarchar(4000)  
 DECLARE @SkipTransfer bit  
 DECLARE @isSucc varchar(10), @SubAccName varchar(30)
 
 --- 20150606@Kathy: Migrate custDB to new server DBCust(Get credit from DBCust.CustDB) [Redmine:#36216]
 SELECT @SubAccName = username 
 FROM DBCUST.CustDB.dbo.custSub WITH(NOLOCK) 
 WHERE SubAccID = @SubAccID

    
 SELECT @isSucc='false'  
 SELECT @ErrItems = ''  
  
 OPEN CUR  
   
 FETCH NEXT FROM CUR INTO @custID,@user,@amount, @Outstanding, @credit, @PendingTransfer3rd
 WHILE @@FETCH_STATUS = 0  
 BEGIN  
	SELECT @SkipTransfer = 0
	
  --Check for existing transfer (allow only one transfer per day) - Tho@09062008  
    IF @IsAllDayBalTransfer = 0
		BEGIN
		IF EXISTS(  
			  SELECT TOP 1 1 FROM Transfer t WITH (NOLOCK) LEFT JOIN TransferInfo ti WITH(NOLOCK) ON t.TransId = ti.TransId 
			  WHERE CustId=@custid AND Bettype in (21003, 21004)   
			  AND (TransDate BETWEEN convert(varchar(10), current_timestamp, 120) AND convert(varchar(10), current_timestamp, 120) + ' 23:59:59')  
			  AND ISNULL(ti.IsDel,0) = 0
		 ) 
		BEGIN 
			SELECT @SkipTransfer = 1  
			SELECT @ErrItems = @ErrItems + @User + ', '  
		END
	END
  ----/---------------------------------------------------------------  

    EXEC Get_Refno_Transid @RefNo = @RefNo OUTPUT
    
    ------------------Insert trans into DB---------------------------------------------------------------  
     
   -- All error messages are the same, so we set it here  
		select @ErrCode = 105  
		Select @ErrMsg = case @Language   
        when 'E' then 'Clear balance failed. Please try again.'  
        ELSE [dbo].[f_Get_MsgNamebyMsgID](50003,@Language)
        end  
   
	IF (@amount > 0 and @SkipTransfer = 0)  
    BEGIN  
		EXEC Get_Bettrans_TransID @TransID = @TransID OUTPUT
		INSERT INTO Transfer   
			(transid, creator, custid, username, refno, transdate, bettype, transdesc, winlost, actual_stake,   
			 winlostdate, currency, actualrate, currencyName, recommend, mrecommend, srecommend, scomm, swinlost,ip,statusID, RepUpdateTime)  
		VALUES 
		    (@TransID, @creator, @agentid, @agUser, @RefNo, CURRENT_TIMESTAMP, 21004, 'From Customer :: ' + @User + CASE WHEN @SubAccID > 0 THEN ' (By ' + @SubAccName + ')' ELSE '' END, 
			 @amount, 0, @WinlostDate, @currency, @actualrate, @currName, @agentid, @MRecommend1, @srecommend1, 0, 0,@ip,131, SYSDATETIME())  
		IF @@Error <> 0  
		BEGIN  
			--Manually rollback
			DELETE FROM Transfer where refno = @RefNo			
			RETURN  
		END  
		
		---update debit balance
		--EXEC Dot_BalanceUpdDebit @CustID = @CustID, @balance = @amount  
		EXEC Dot_BalanceDebitUpd @CustID = @CustID, @balance = @amount, @type = 2, @IsForced = 1, @errCode = @ErrCode OUTPUT
		IF @ErrCode <> 0
		BEGIN
			--Manually rollback
			DELETE FROM Transfer where refno = @RefNo			
			RETURN 
		END
		
		DECLARE @TotalCash1 MONEY 
		EXEC Acc_CustomerSelCash_CaptureBalance @custid = @custid, @TotalCash  = @TotalCash1 OUTPUT

		EXEC Get_Bettrans_TransID @TransID = @TransID OUTPUT
		INSERT INTO Transfer  
			(transid, creator, custid, username, refno, transdate, bettype, transdesc, winlost, actual_stake,   
			 winlostdate, currency, actualrate,currencyName, recommend, mrecommend, srecommend, scomm, swinlost,ip,statusID, balance, RepUpdateTime)  
		VALUES 
		    (@TransID, @creator, @custid, @User, @RefNo, CURRENT_TIMESTAMP, 21004, 'To Customer :: ' + @agUser + CASE WHEN @SubAccID > 0 THEN ' (By ' + @SubAccName + ')' ELSE '' END, 
		     0, @amount,  @WinlostDate, @currency, @actualrate, @currName, @agentid, @MRecommend1, @srecommend1, 0, 0,@ip,131, @TotalCash1, SYSDATETIME())  
		IF @@Error <> 0  
		BEGIN  
			--Manually rollback
			DELETE FROM Transfer where refno = @RefNo 
			-- rollback balance
			--EXEC Dot_BalanceUpdCredit @CustID = @CustID, @balance = @amount  
			EXEC Dot_BalanceCreditUpd @CustID = @CustID, @balance = @amount, @type = 2
			RETURN  
		END  						
				
      --Add writelog for each amt transfered - Vinh 20080629  
		SELECT @LogData = 'Transfer from Customer ' + @User + ' to Agent ' + @agUser + ' with amount ' + convert(varchar(20), @amount) + ' Ref.No ' + convert(varchar(20), @RefNo)
		
		
		SET @FutureBetCredit = @credit - @outstanding - @PendingTransfer3rd
		
		if @FutureBetCredit < 0 
		Select @LogData = @LogData + '. The agent decided to transfer after the warning so the bet credit of this member turned to negative value (' + convert(varchar(100), @FutureBetCredit, 2) + ') caused by having outstanding balance value ('+ convert(varchar(100), @outstanding, 2) +')  '
    END  
	ELSE IF(@amount<0 and @SkipTransfer = 0)  
    BEGIN  

		--SET @amount = abs(@amount)    
		EXEC Get_Bettrans_TransID @TransID = @TransID OUTPUT
		INSERT INTO Transfer   
			(transid, creator, custid, username, refno, transdate, bettype, transdesc, winlost, actual_stake,   
			 winlostdate, currency,actualrate, currencyName, recommend, mrecommend, srecommend, scomm, swinlost,ip,statusID, RepUpdateTime)  
		VALUES 
		    (@TransID, @creator, @agentid, @agUser, @RefNo, CURRENT_TIMESTAMP, 21004, 'To Customer :: ' + @User + CASE WHEN @SubAccID > 0 THEN ' (By ' + @SubAccName + ')' ELSE '' END, 
			 0, abs(@amount),@WinlostDate, @currency, @actualrate, @currName, @agentid, @MRecommend1, @srecommend1, 0, 0,@ip,131, SYSDATETIME())  
		IF @@Error <> 0  
		BEGIN  
			--Manually rollback
			DELETE FROM Transfer where refno = @RefNo
			RETURN  
		END  

		DECLARE @TotalCash3 MONEY 
		EXEC Acc_CustomerSelCash_CaptureBalance @custid = @custid, @TotalCash  = @TotalCash3 OUTPUT

		EXEC Get_Bettrans_TransID @TransID = @TransID OUTPUT
		INSERT INTO Transfer  
			(transid, creator, custid, username, refno, transdate, bettype, transdesc, winlost, actual_stake,   
			 winlostdate, currency, actualrate, currencyName, recommend, mrecommend, srecommend, scomm, swinlost,ip,statusID, balance, RepUpdateTime)  
		VALUES 
		    (@TransID, @creator, @custid, @User, @RefNo, CURRENT_TIMESTAMP, 21004, 'From Customer :: ' + @agUser + CASE WHEN @SubAccID > 0 THEN ' (By ' + @SubAccName + ')' ELSE '' END, 
			 abs(@amount), 0, @WinlostDate, @currency, @actualrate, @currName, @agentid, @MRecommend1, @srecommend1, 0, 0,@ip,131, @TotalCash3, SYSDATETIME())  
		IF @@Error <> 0  
		BEGIN  
			--Manually rollback
			DELETE FROM Transfer where refno = @RefNo
			RETURN  
		END 
		
		---update credit balance 
		SELECT @ABSamount = abs(@amount)  
		--EXEC Dot_BalanceUpdCredit @CustID = @CustID, @balance = @ABSamount	
		EXEC Dot_BalanceCreditUpd @CustID = @CustID, @balance = @ABSamount, @type = 2
    --Add writelog for each amt transfered - Vinh 20080629  
		SELECT @LogData = 'Transfer from Agent ' + @agUser + ' to Customer ' + @User + ' with amount ' + convert(varchar(20), @amount) + ' Ref.No ' + convert(varchar(20), @RefNo) 
		
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
     
	IF(@SkipTransfer = 0)   
    BEGIN  
		set @isSucc='true'
        --Select @LogData = @LogData + '[' + convert(varchar(20),@ToCustID) + ', ' + convert(varchar(20), @amount) + ']'      
		IF @SubAccID > 0  
			SET @LogData = 'SubAccount:' +  coalesce(cast(@SubAccName as varchar(30)),space(1)) + ' - ' + @LogData  

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
    END  	  
  
    FETCH NEXT FROM CUR INTO @custID,@user,@amount,@Outstanding,@credit, @PendingTransfer3rd
 END  
 CLOSE CUR  
 DEALLOCATE CUR  
 
 DROP TABLE #Member  
 if @ErrItems <> ''  
 BEGIN  
	select @ErrCode = 104  
	select @ErrItems = LEFT(@ErrItems, len(@ErrItems)-1)  
	Select @ErrMsg = case @Language   
       when 'E' then N'Clear balance failed: Allow only one transfer per day. Failed for the following user(s):' + ' ' + @ErrItems + '_' + @isSucc  
       ELSE [dbo].[f_Get_MsgNamebyMsgID](50004,@Language) + ' ' + @ErrItems + '_' + @isSucc  
      end  
 END
GO