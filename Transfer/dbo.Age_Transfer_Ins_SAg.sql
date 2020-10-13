/*<info serverAlias="DBTXN-bodb02" executers="bodbDownlineNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE  [dbo].[Age_Transfer_Ins_SAg]
	@SAgID int,
	@SuperIDsTransferTotal VARCHAR(50)='', 
	@ToCustIDs varchar(4000),
	@creator int,
	@FullTransfer bit = 1,
	@AmtTrans float = 0,
	@Language varchar(2)= 'E',
	@SubAccID int = 0, --Sub-AccountID
	@IP nvarchar(15)='',
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
	
Param's Explanation:
• @AmtTrans: amount of money
• @SAgID: from master
• @ToCustIDs: list custid
  @SuperIDsTransferTotal: Super IDs can transfer total balance including today balance 

*/


SET NOCOUNT ON
	
select @IP = dbo.f_ConvertIPv6ToDummy(@IP)	
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

  DECLARE @WinlostDate datetime
 SELECT  @WinlostDate = convert(varchar(10), CURRENT_TIMESTAMP, 120)
 
DECLARE @yesterday SMALLDATETIME
SELECT  @yesterday = DATEADD(DAY, -1, CONVERT(DATE, GETDATE()))

 DECLARE @tblCustIds TABLE (CustId INT)
 
 INSERT INTO @tblCustIds (CustId)
 select convert(int, val) from dbo.strSplit (@ToCustIDs, ',')

-- Get bettype --
DECLARE @isTest BIT = 0
SELECT  @isTest = dbo.f_CheckSPVersion(@@PROCID)
	
CREATE TABLE #SportBettype (bettype INT, RefTable TINYINT)
INSERT INTO #SportBettype (bettype, RefTable)
SELECT bettype, RefTable FROM dbo.f_SportBettypeMatrix_Sel (0, 0, 0, 2, '', '', @isTest)

CREATE TABLE #BalanceInfo (CustId INT, Balance MONEY, Outstanding MONEY)

CREATE TABLE #mrecommend (CustId INT)
CREATE TABLE #recommend (CustId INT)

IF (@CustStatus <> '' OR @CustStatus <> null)
BEGIN
	INSERT INTO #mrecommend (CustId)
	SELECT custid
	FROM CustDB.dbo.custInfo c WITH(NOLOCK)
	WHERE srecommend = @SAgID AND c.roleid = 3
		AND	c.closed = case @CustStatus
							when 'Open' then 0 
							when 'Close' then 1 
							when 'Suspend' then 0
							else c.closed
							end
		AND isnull(c.reject,0) = case when c.closed = 0 then case @CustStatus
															when 'Suspend' then 1 
															when 'Open' then 0	
															else isnull(c.reject,0)
															end  
								else isnull(c.reject,0)
								end
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
 IF @SAgID IN (select convert(int, val) from dbo.strSplit (@SuperIDsTransferTotal, ','))
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

	-- bettrans
	INSERT INTO #BalanceInfo (CustId, Balance)
	SELECT 
		mrecommend,
		ISNULL(SUM(mwinlost+acomm-comm), 0)
			+ ISNULL(SUM(CASE WHEN custid = recommend THEN winlost-actual_stake ELSE awinlost+comm-playercomm END), 0)
			+ ISNULL(SUM(CASE WHEN custid <> recommend THEN winlost-actual_stake+playercomm ELSE 0 END), 0)
	FROM dbo.bettrans b WITH(NOLOCK)
	WHERE EXISTS (SELECT 1 FROM #recommend r WHERE b.recommend = r.CustId)
		AND ruben = 1
		AND winlostdate < @yesterday
		AND bettype NOT IN (21008, 21009)
	GROUP BY mrecommend

	INSERT INTO #BalanceInfo (CustId, Balance)
	SELECT 
		mrecommend,
		ISNULL(SUM(mwinlost+acomm-comm), 0)
			+ ISNULL(SUM(CASE WHEN custid = recommend THEN winlost-actual_stake ELSE awinlost+comm-playercomm END), 0)
			+ ISNULL(SUM(CASE WHEN custid <> recommend THEN winlost-actual_stake+playercomm ELSE 0 END), 0)
	FROM dbo.bettrans b WITH(NOLOCK)
	WHERE EXISTS (SELECT 1 FROM #recommend r WHERE b.recommend = r.CustId)
		AND ruben = 1
		AND winlostdate >= @yesterday
		AND NOT EXISTS (SELECT TOP 1 1 FROM #SportBettype s WHERE s.Bettype = b.bettype AND s.RefTable IN (1, 2))
		AND bettype NOT IN (21008, 21009)
	GROUP BY mrecommend

	INSERT INTO #BalanceInfo (CustId, Balance)
	SELECT 
		mrecommend,
		ISNULL(SUM(winlost-actual_stake), 0)
	FROM dbo.bettrans b WITH(NOLOCK)
	WHERE EXISTS (SELECT 1 FROM #mrecommend m WHERE b.custid = m.CustId)
		AND ruben = 1
		AND matchid = 0
		AND bettype >= 19999
		AND bettype NOT IN (21008, 21009)
	GROUP BY mrecommend
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

	-- bettrans
	INSERT INTO #BalanceInfo (CustId, Balance)
	SELECT 
		mrecommend,
		ISNULL(SUM(mwinlost+acomm-comm), 0)
			+ ISNULL(SUM(CASE WHEN custid = recommend THEN winlost-actual_stake ELSE awinlost+comm-playercomm END), 0)
			+ ISNULL(SUM(CASE WHEN custid <> recommend THEN winlost-actual_stake+playercomm ELSE 0 END), 0)
	FROM dbo.bettrans b WITH(NOLOCK)
	WHERE EXISTS (SELECT 1 FROM #recommend r WHERE b.recommend = r.CustId)
		AND ruben = 1
		AND winlostdate < @yesterday
		AND bettype NOT IN (21008, 21009)
	GROUP BY mrecommend

	INSERT INTO #BalanceInfo (CustId, Balance)
	SELECT 
		mrecommend,
		ISNULL(SUM(CASE WHEN winlostdate = @yesterday THEN mwinlost+acomm-comm ELSE 0 END), 0)
			+ ISNULL(SUM(CASE WHEN winlostdate = @yesterday OR bettype > 20000 THEN CASE WHEN custid = recommend THEN winlost-actual_stake ELSE awinlost+comm-playercomm END ELSE 0 END), 0)
			+ ISNULL(SUM(CASE WHEN winlostdate = @yesterday OR bettype > 20000 THEN CASE WHEN custid <> recommend THEN winlost-actual_stake+playercomm ELSE 0 END ELSE 0 END), 0)
	FROM dbo.bettrans b WITH(NOLOCK)
	WHERE EXISTS (SELECT 1 FROM #recommend r WHERE b.recommend = r.CustId)
		AND ruben = 1
		AND winlostdate >= @yesterday
		AND NOT EXISTS (SELECT TOP 1 1 FROM #SportBettype s WHERE s.Bettype = b.bettype AND s.RefTable IN (1, 2))
		AND bettype NOT IN (21008, 21009)
	GROUP BY mrecommend

	INSERT INTO #BalanceInfo (CustId, Balance)
	SELECT 
		mrecommend,
		ISNULL(SUM(winlost-actual_stake), 0)
	FROM dbo.bettrans b WITH(NOLOCK)
	WHERE EXISTS (SELECT 1 FROM #mrecommend m WHERE b.custid = m.CustId)
		AND ruben = 1
		AND matchid = 0
		AND bettype >= 19999
		AND bettype NOT IN (21008, 21009)
	GROUP BY mrecommend
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
		ELSE [dbo].[f_Get_MsgNamebyMsgID](50002,@Language)
	end
		, @ErrCode = 103     
 
	RETURN	
  END
 
 UPDATE #Master SET MAgUser = ci.username 
 FROM #Master 
	INNER JOIN CustDB.dbo.custinfo ci with (NOLOCK) ON ci.custid = #Master.custid 
	
 DECLARE @currency int, @actualrate float, @currName nvarchar(10),
	     @transcode bigint, @amount float, @grefno int
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
	
	BEGIN TRANSACTION
		UPDATE ref with (rowlock, UPDLOCK)  SET   @grefno=transcode=transcode+1
		WHERE  refid='acc'
	
		if @@Error <> 0
		BEGIN
			ROLLBACK TRANSACTION
			return
		END		
	
		select @transcode=200000000000+@grefno
	COMMIT TRANSACTION
	
	--CHECK MASTER'S BALANCE
	DECLARE @custBalance money 
	SELECT @custBalance = @Amount 
	if @FullTransfer = 0
	BEGIN
		if @AmtTrans = 0
				or (@CustBalance >= 0 AND (@AmtTrans <= 0 or @AmtTrans > @CustBalance))
				or (@CustBalance < 0 AND (@AmtTrans >= 0 or @AmtTrans < @CustBalance))
			BEGIN
				Select @ErrMsg = case @Language 
										when 'E' then 'Amount to transfer must be between 0 and' + ' ' + convert(varchar(100), -@CustBalance, 2) + '.'
										ELSE [dbo].[f_Get_MsgNamebyMsgID](50005,@Language) + ' ' + convert(varchar(100), -@CustBalance, 2) + '.'
									end		
				select @ErrCode = 104
				return
			END	
		-- INSERT AMOUNT INPUTED INTO BETTRANS 
		SET @amount = @AmtTrans	
	END 	
	
	BEGIN TRANSACTION
	
		-- All error messages are the same, so we set it here
		Select @ErrMsg = case @Language 
								when 'E' then 'Clear balance failed. Please try again.'
								ELSE [dbo].[f_Get_MsgNamebyMsgID](50003,@Language)
								end
		
		
		IF @amount >0
		BEGIN
			
			INSERT INTO bettrans 
			   (matchid, creator, custid, username, refno, transdate, bettype, transdesc, winlost, actual_stake, 
				status, ruben, winlostdate, currency, actualrate,currencyName, mrecommend, srecommend, scomm, swinlost, recommend,ip,statusID)
			VALUES (0, @creator, @SAgID, @SAUser, @transcode, CURRENT_TIMESTAMP, 21003, 'From Customer ::: ' + @MagUser, @amount, 0, 
				'Completed', 1,@WinlostDate, @currency, @actualrate, @currName, 0, @SAgID, 0, 0, 0,@ip,131)
			if @@Error <> 0
			BEGIN
				select @ErrCode = 103
				ROLLBACK TRANSACTION
				return
			END
			INSERT INTO bettrans
				(matchid, creator, custid, username, refno, transdate, bettype, transdesc, winlost, actual_stake, 
				status, ruben, winlostdate, currency, actualrate, currencyName, mrecommend, srecommend, scomm, swinlost, recommend,ip,statusID)
			VALUES (0, @creator, @Magentid, @MAgUser, @transcode, CURRENT_TIMESTAMP, 21003, 'To Customer ::: ' + @saUser, 0, @amount,
				'Completed', 1, @WinlostDate, @currency, @actualrate, @currName, @Magentid, @SAgID, 0, 0, 0,@ip,131)
			if @@Error <> 0
			BEGIN
				select @ErrCode = 104
				ROLLBACK TRANSACTION
				return
			END

			--Add writelog for each amt transfered - Vinh 20080629
			Select @LogData = 'Transfer from Master ' + @MagUser + ' to Super ' + @saUser + ' with amount ' + convert(varchar(20), @amount) + ' Ref.No ' + convert(varchar(20), @transcode)			
			
		END
		ELSE if @amount<0
		BEGIN
			--SET @amount = abs(@amount)
		
			INSERT INTO bettrans 
				(matchid, creator, custid, username, refno, transdate, bettype, transdesc, winlost, actual_stake, 
				status, ruben, winlostdate, currency, actualrate, currencyName, mrecommend, srecommend, scomm, swinlost, recommend,ip,statusID)
			VALUES (0, @creator, @SAgID, @SAUser, @transcode, CURRENT_TIMESTAMP, 21003, 'To Customer ::: ' + @MagUser, 0, abs(@amount),
				'Completed', 1, @WinlostDate, @currency, @actualrate, @currName, 0, @SAgID, 0, 0, 0,@ip,131)
			if @@Error <> 0
			BEGIN
				select @ErrCode = 105
				ROLLBACK TRANSACTION
				return
			END
			INSERT INTO bettrans
				(matchid, creator, custid, username, refno, transdate, bettype, transdesc, winlost, actual_stake, 
				status, ruben, winlostdate, currency,actualrate, currencyName, mrecommend, srecommend, scomm, swinlost, recommend,ip,statusID)
			VALUES (0, @creator, @Magentid, @MAgUser, @transcode, CURRENT_TIMESTAMP, 21003, 'From Customer ::: ' + @saUser, abs(@amount), 0,
				'Completed', 1, @WinlostDate, @currency, @actualrate, @currName, @Magentid, @SAgID, 0, 0, 0,@ip,131)
			if @@Error <> 0
			BEGIN
				select @ErrCode = 106
				ROLLBACK TRANSACTION
				return
			END
			
			--Add writelog for each amt transfered - Vinh 20080629
			Select @LogData = 'Transfer from Super ' + @saUser + ' to Master ' + @MagUser + ' with amount ' + convert(varchar(20), @amount) + ' Ref.No ' + convert(varchar(20), @transcode)			
			
		END
	COMMIT TRANSACTION
	Select @ErrMsg = ''
	
	if @SubAccID > 0
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