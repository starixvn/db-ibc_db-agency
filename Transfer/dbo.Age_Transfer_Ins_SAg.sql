/*<info serverAlias="DBCTG-bodb02,DBSIC-bodb02" executers="bodbDownlineNet,wsv_alp" isFunction="0" isNested="0"></info>*/
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
	@CustStatus varchar(50)='',
	@IsAutoTransfer BIT = 0,
	@AutoTransfer	TINYINT = 2

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
	- 20230227@Bobby: Auto Clear Balance/ Multiple Transfer	 [RedmineID: #182071]
	- 20230908@Bobby: AutoJob Enhancement [RedmineID: #193017]
	- 20231027@Bobby: AutoJob transfer - schedule option [RedmineID: #195135]
	- 20240314@Bobby: EC enhancement [Redmine: #202276]
	- 20241118@Max: Alpha - Offer Direct Member for Super/Master [Redmine: #211969]
	
Param's Explanation:
	• @AmtTrans: amount of money
	• @SAgID: from master
	• @ToCustIDs: list custid
	  @SuperIDsTransferTotal: Super IDs can transfer total balance including today balance 

*/
BEGIN

	SET NOCOUNT ON;

	DECLARE @rCount INT, @FromCustID INT, @PairStatus VARCHAR(15), @Result nvarchar(4000);
	DECLARE @IsExistDirect BIT = 0

	-- TODO: support auto clear balance
	DECLARE @tblResultMember TABLE(CustId INT PRIMARY KEY, UserName VARCHAR(50), MsgId INT, ErrType VARCHAR(50), ErrMsg NVARCHAR(4000), RefNo BIGINT);
	INSERT INTO @tblResultMember(CustId)
	SELECT DISTINCT t.value
	FROM STRING_SPLIT(@ToCustIDs, ',') AS t;

	SELECT @FromCustID = @SAgID;

	---------------------------
	--declare @ErrMsg varchar(200)
	 CREATE TABLE #Customer_Result (		
		rIdx	INT IDENTITY(1,1),
		custID	int PRIMARY KEY NONCLUSTERED, 
		Amt		money DEFAULT 0, 
		MAgUser nvarchar(50), 
		UNIQUE(Amt,custid),
		INDEX CIX_MasterrIdx CLUSTERED (rIdx)
	)				 

	---- #1 CHECK UM TRANSFER FUNCTION
	DECLARE @ToTimeConfig DATETIME;
	EXEC DBCUST.CUSTDB.dbo.Acc_Transfer_CheckUM  
		@CustID = @SAgID
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
			@CustID = @SAgID
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

	-- get move bet date
	DECLARE @balanceUpDay SMALLDATETIME, @moveBetsDay SMALLDATETIME
	DECLARE @IsDiff	SMALLINT = 1, @NewMoveBetDate SMALLDATETIME = NULL,@NewBalanceUpDate SMALLDATETIME = NULL

	--TODO: Get MBU days
	EXEC dbo.NAP_Admin_GetMovebetDate @MovebetDate = @moveBetsDay OUTPUT
	EXEC dbo.NAP_Admin_GetBalanceUpDate @BalanceUpDate = @balanceUpDay OUTPUT
	
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

	CREATE TABLE #customerList (CustId INT PRIMARY KEY, IsDirectMember BIT)
	CREATE TABLE #DirectMemberList (CustId INT)
	CREATE TABLE #recommend (CustId INT)

	--TODO: Filter downlines
	SET @AutoTransfer = ISNULL(@AutoTransfer, 2)
	IF (@CustStatus <> '' OR @CustStatus <> null OR @AutoTransfer <> 2)
	BEGIN
		DROP TABLE IF EXISTS #ClearBalanceCust_Setting;
		CREATE TABLE #ClearBalanceCust_Setting(FromCustID INT, ToCustID INT);
		DECLARE @SQL_CBS NVARCHAR(MAX);

		SET @CustStatus = ISNULL(@CustStatus, 'All');

		IF @AutoTransfer <> 2
		BEGIN
			SELECT  @SQL_CBS = 'SELECT FromCustID, ToCustID
							FROM OPENQUERY(DBCUST, ''SELECT cbs.FromCustID, cbs.ToCustID
													FROM CustDB.dbo.Age_ClearBalanceCust_Setting cbs WITH(NOLOCK)
													WHERE cbs.FromCustID = ' + CONVERT(VARCHAR(30), @SAgID) + ''')'
			INSERT INTO #ClearBalanceCust_Setting (FromCustID, ToCustID)
			EXEC (@SQL_CBS)
		END

		INSERT INTO #customerList (CustId, IsDirectMember)
		SELECT c.custid
			, CASE WHEN roleid = 3 THEN 0 ELSE 1 END
		FROM CustDB.dbo.custInfo c WITH(NOLOCK)  
		INNER JOIN CustDB.dbo.CustProductStatus cs with(nolock) on c.custid=cs.CustID
		LEFT JOIN #ClearBalanceCust_Setting cbs ON cbs.ToCustID = c.custid
		WHERE	srecommend = @SAgID 
				AND 1 = CASE WHEN c.roleid = 3 THEN 1
							WHEN c.roleid = 1 AND c.mrecommend = -4 THEN 1
						END
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
				AND 1 = CASE 
							WHEN @AutoTransfer = 2 THEN 1
							WHEN @AutoTransfer = 0 AND cbs.ToCustID IS NULL THEN 1
							WHEN @AutoTransfer = 1 AND cbs.ToCustID > 0 THEN 1
							ELSE 0
						END
	END
	ELSE
	BEGIN
		INSERT INTO #customerList (CustId, IsDirectMember)
		SELECT t.CustId, CASE WHEN c.roleid = 3 THEN 0 ELSE 1 END
		FROM @tblCustIds t
			INNER JOIN CustDB.dbo.custInfo c WITH (NOLOCK) ON c.custid = t.CustId
	END

	INSERT INTO #recommend (CustId)
	SELECT custid
	FROM CustDB.dbo.custInfo c WITH(NOLOCK)
	WHERE c.roleid = 2
		AND EXISTS (SELECT 1 FROM #customerList m WHERE c.mrecommend = m.CustId AND m.IsDirectMember = 0)

	INSERT INTO #DirectMemberList (custid)
	SELECT custid
	FROM #CustomerList
	WHERE IsDirectMember = 1

	IF @@ROWCOUNT > 0
		SET @IsExistDirect = 1

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
		FROM #recommend r
			INNER JOIN dbo.bettransRnG b WITH(NOLOCK, index = IX_recommend) ON b.recommend = r.CustId
		WHERE statusID NOT IN (0,1)
			AND winlostdate >= @yesterday
		GROUP BY mrecommend

		IF @IsExistDirect = 1
		BEGIN
			INSERT INTO #BalanceInfo (CustId, Balance)
			SELECT 
				r.CustId,
				ISNULL(SUM(mwinlost+acomm-comm), 0)
					+ ISNULL(SUM(awinlost+comm-playercomm), 0)
					+ ISNULL(SUM(winlost-actual_stake+playercomm), 0)
			FROM #DirectMemberList r
				INNER JOIN dbo.bettransRnG b WITH(NOLOCK, index = IX_custid) ON b.custid = r.CustId
			WHERE statusID NOT IN (0,1)
				AND winlostdate >= @yesterday
			GROUP BY r.CustId
		END

		-- bettransLC
		INSERT INTO #BalanceInfo (CustId, Balance)
		SELECT 
			mrecommend,
			ISNULL(SUM(mwinlost+acomm-comm), 0)
				+ ISNULL(SUM(awinlost+comm-playercomm), 0)
				+ ISNULL(SUM(winlost-actual_stake+playercomm), 0)
		FROM #recommend r
			INNER JOIN dbo.bettransLC b WITH(NOLOCK, index = IX_recommend) ON b.recommend = r.CustId
		WHERE statusID NOT IN (0,1)
			AND winlostdate >= @yesterday
		GROUP BY mrecommend

		IF @IsExistDirect = 1
		BEGIN
			INSERT INTO #BalanceInfo (CustId, Balance)
			SELECT 
				r.CustId,
				ISNULL(SUM(mwinlost+acomm-comm), 0)
					+ ISNULL(SUM(awinlost+comm-playercomm), 0)
					+ ISNULL(SUM(winlost-actual_stake+playercomm), 0)
			FROM #DirectMemberList r
				INNER JOIN dbo.bettransLC b WITH (NOLOCK,index = IX_custid) ON b.custid = r.CustId
			WHERE statusID NOT IN (0,1)
				AND winlostdate >= @yesterday
			GROUP BY r.CustId
		END

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
			FROM #recommend r
				INNER JOIN dbo.bettrans b WITH(NOLOCK, index = IX_recommend) ON b.recommend = r.CustId
			WHERE b.statusID IN (111, 112, 113)
				AND winlostdate > @moveBetsDay
				AND (
						b.winlostdate < @yesterday
						OR NOT EXISTS (SELECT TOP 1 1 FROM #SportBettype s WHERE s.Bettype = b.bettype AND s.RefTable IN (1, 2))
					)
			GROUP BY mrecommend

			IF @IsExistDirect = 1 
			BEGIN
				INSERT INTO #BalanceInfo (CustId, Balance, TableName)
				SELECT 
					r.CustId,
					ISNULL(SUM(mwinlost+acomm-comm), 0)
						+ ISNULL(SUM(awinlost+comm-playercomm), 0)
						+ ISNULL(SUM(winlost-actual_stake+playercomm), 0),
					'tblBettrans'
				FROM #DirectMemberList r
					INNER JOIN dbo.bettrans b WITH(NOLOCK, INDEX = IX_customerinfo) ON b.custid = r.CustId
				WHERE b.statusID IN (111, 112, 113)
					AND winlostdate > @moveBetsDay
					AND (
							b.winlostdate < @yesterday
							OR NOT EXISTS (SELECT TOP 1 1 FROM #SportBettype s WHERE s.Bettype = b.bettype AND s.RefTable IN (1, 2))
						)
				GROUP BY r.CustId
			END

			-- Transfer
			INSERT INTO #BalanceInfo (CustId, Balance, TableName)
			SELECT 
				mrecommend,
				ISNULL(SUM(mwinlost+acomm-comm), 0)
					+ ISNULL(SUM(CASE WHEN b.custid = recommend THEN winlost-actual_stake ELSE awinlost+comm-playercomm END), 0)
					+ ISNULL(SUM(CASE WHEN b.custid <> recommend THEN winlost-actual_stake+playercomm ELSE 0 END), 0),
				'tblTransfer'
			FROM #recommend r
				INNER JOIN dbo.Transfer b WITH(NOLOCK, index = IX_Recommend) ON b.recommend = r.CustId
			WHERE 1 = CASE WHEN bettype = 19999 AND winlostdate > @moveBetsDay THEN 0 --> new sum
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
			FROM #CustomerList r
				INNER JOIN dbo.Transfer b WITH(NOLOCK, index = IX_custid) ON b.CustId = r.CustId AND r.IsDirectMember = 0
			WHERE 1 = CASE WHEN bettype = 20000 AND winlostdate > @balanceUpDay THEN 0 --> new bal
													WHEN winlostdate < @balanceUpDay THEN 0 --> old data
											ELSE 1 END
						AND bettype NOT IN (21008, 21009)
			GROUP BY mrecommend

			IF @IsExistDirect = 1
			BEGIN
				SELECT 
					r.CustId,
					ISNULL(SUM(winlost-actual_stake), 0),
					'tblTransfer'
				FROM #DirectMemberList r
					INNER JOIN dbo.Transfer b WITH(NOLOCK, INDEX = IX_CustId) ON b.CustId = r.CustId
				WHERE 1 = CASE WHEN bettype = 20000 AND winlostdate > @balanceUpDay THEN 0 --> new bal
														WHEN winlostdate < @balanceUpDay THEN 0 --> old data
												ELSE 1 END
							AND bettype NOT IN (21008, 21009)
				GROUP BY r.CustId
			END


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
		FROM #recommend r
			INNER JOIN dbo.bettransRnG b WITH(NOLOCK, index = IX_recommend) ON b.recommend = r.CustId
		WHERE statusID NOT IN (0,1)
			AND winlostdate = @yesterday
		GROUP BY mrecommend

		IF @IsExistDirect = 1
		BEGIN
			INSERT INTO #BalanceInfo (CustId, Balance)
			SELECT 
				r.CustId,
				ISNULL(SUM(mwinlost+acomm-comm), 0)
					+ ISNULL(SUM(awinlost+comm-playercomm), 0)
					+ ISNULL(SUM(winlost-actual_stake+playercomm), 0)
			FROM #DirectMemberList r
				inner join dbo.bettransRnG b WITH(NOLOCK, index = IX_custid ) ON r.custid = b.custid
			WHERE statusID NOT IN (0,1)
				AND winlostdate = @yesterday
			GROUP BY r.CustId
		END

		-- bettransLC
		INSERT INTO #BalanceInfo (CustId, Balance)
		SELECT 
			mrecommend,
			ISNULL(SUM(mwinlost+acomm-comm), 0)
				+ ISNULL(SUM(awinlost+comm-playercomm), 0)
				+ ISNULL(SUM(winlost-actual_stake+playercomm), 0)
		FROM #recommend r
			INNER JOIN dbo.bettransLC b WITH(NOLOCK, index = IX_recommend) ON b.recommend = r.CustId
		WHERE statusID NOT IN (0,1)
			AND winlostdate = @yesterday
		GROUP BY mrecommend

		IF @IsExistDirect = 1 
		BEGIN
			INSERT INTO #BalanceInfo (CustId, Balance)
			SELECT 
				r.CustId,
				ISNULL(SUM(mwinlost+acomm-comm), 0)
					+ ISNULL(SUM(awinlost+comm-playercomm), 0)
					+ ISNULL(SUM(winlost-actual_stake+playercomm), 0)
			FROM #DirectMemberList r
				INNER JOIN dbo.bettransLC b WITH (NOLOCK,index = IX_custid) ON b.custid = r.CustId
			WHERE statusID NOT IN (0,1)
				AND winlostdate = @yesterday
			GROUP BY r.CustId
		END

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
			FROM #recommend r
				INNER JOIN dbo.bettrans b WITH(NOLOCK, index = IX_recommend) ON b.recommend = r.CustId
			WHERE b.statusID IN (111, 112, 113)
				AND winlostdate > @moveBetsDay
				AND (
						b.winlostdate < @yesterday
						OR NOT EXISTS (SELECT TOP 1 1 FROM #SportBettype s WHERE s.Bettype = b.bettype AND s.RefTable IN (1, 2))
					)
			GROUP BY mrecommend

			IF @IsExistDirect = 1
			BEGIN
				INSERT INTO #BalanceInfo (CustId, Balance, TableName)
				SELECT 
					r.CustId,
					ISNULL(SUM(CASE WHEN winlostdate <= @yesterday THEN mwinlost+acomm-comm ELSE 0 END), 0)
						+ ISNULL(SUM(CASE WHEN winlostdate <= @yesterday THEN awinlost+comm-playercomm ELSE 0 END), 0)
						+ ISNULL(SUM(CASE WHEN winlostdate <= @yesterday THEN winlost-actual_stake+playercomm ELSE 0 END), 0),
					'tblBettrans'
				FROM #DirectMemberList r
					INNER JOIN dbo.bettrans b WITH(NOLOCK, INDEX = IX_customerinfo ) ON b.custid = r.CustId
				WHERE b.statusID IN (111, 112, 113)
					AND winlostdate > @moveBetsDay
					AND (
							b.winlostdate < @yesterday
							OR NOT EXISTS (SELECT TOP 1 1 FROM #SportBettype s WHERE s.Bettype = b.bettype AND s.RefTable IN (1, 2))
						)
				GROUP BY r.CustId
			END

			-- Transfer
			INSERT INTO #BalanceInfo (CustId, Balance, TableName)
			SELECT 
				mrecommend,
				ISNULL(SUM(CASE WHEN winlostdate <= @yesterday THEN mwinlost+acomm-comm ELSE 0 END), 0)
					+ ISNULL(SUM(CASE WHEN b.custid = recommend THEN winlost-actual_stake ELSE awinlost+comm-playercomm END ), 0)
					+ ISNULL(SUM(CASE WHEN b.custid <> recommend THEN winlost-actual_stake+playercomm ELSE 0 END ), 0),
				'tblTransfer'
			FROM #recommend r
				INNER JOIN dbo.Transfer b WITH(NOLOCK, index = IX_Recommend) ON b.recommend = r.CustId
			WHERE 1 = CASE WHEN bettype = 19999 AND winlostdate > @moveBetsDay THEN 0 --> new sum
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
			FROM #CustomerList r
				INNER JOIN dbo.Transfer b WITH(NOLOCK, index = IX_custid) ON b.CustId = r.CustId AND r.IsDirectMember = 0
			WHERE bettype NOT IN (21008, 21009)
				AND 1 = CASE WHEN bettype = 19999 AND winlostdate > @moveBetsDay THEN 0 --> new sum
							WHEN bettype = 20000 AND winlostdate > @balanceUpDay THEN 0 --> new bal
							WHEN winlostdate < @balanceUpDay THEN 0 --> old data
					ELSE 1 END
			GROUP BY mrecommend

			IF @IsExistDirect = 1
			BEGIN
				INSERT INTO #BalanceInfo (CustId, Balance, TableName)
				SELECT 
					r.CustId,
					ISNULL(SUM(winlost-actual_stake), 0),
					'tblTransfer'
				FROM #DirectMemberList r
					INNER JOIN dbo.Transfer b WITH(NOLOCK, INDEX = IX_CustId) ON b.CustId = r.CustId
				WHERE bettype NOT IN (21008, 21009)
					AND 1 = CASE WHEN bettype = 19999 AND winlostdate > @moveBetsDay THEN 0 --> new sum
								WHEN bettype = 20000 AND winlostdate > @balanceUpDay THEN 0 --> new bal
								WHEN winlostdate < @balanceUpDay THEN 0 --> old data
						ELSE 1 END
				GROUP BY r.CustId
			END


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
	INSERT INTO #Customer_Result (custID, Amt, MAgUser)
	SELECT m.custID, SUM(ISNULL(bal.Balance,0)), ''
	FROM #customerList m
	LEFT JOIN #BalanceInfo bal ON bal.CustId = m.CustId
	GROUP BY m.custID

	IF NOT EXISTS (SELECT 1 FROM #Customer_Result WHERE Amt <> 0)
	BEGIN
		Select @ErrMsg = case @Language   
			when 'E' then 'Cannot transfer because all downlines'' balance is 0!' 
			ELSE CustDB.dbo.f_Get_MsgNamebyMsgID(50002,@Language)
		end
			, @ErrCode = 103     
 
		IF @IsAutoTransfer = 1
		BEGIN
			SET @Result = (SELECT 50025 AS MsgId, 'BalanceZero' AS ErrType, @ErrMsg AS ErrMsg FOR JSON PATH, WITHOUT_ARRAY_WRAPPER)
			EXEC dbo.Age_ClearBalanceCust_Process_StatusUpd @FromCustID = @FromCustID, @ToCustIds = @ToCustIDs
				,@Status='Ignored', @Result = @Result;
		END
		RETURN	
	END
 
	 UPDATE t SET MAgUser = ci.username 
	 FROM #Customer_Result t
		INNER JOIN CustDB.dbo.custinfo ci with (NOLOCK) ON ci.custid = t.custid 
	
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

	SET @rCount = 1;
	WHILE EXISTS(SELECT 1 FROM #Customer_Result WHERE rIdx = @rCount)
	BEGIN
		-- Reset error for each pair
		SELECT @ErrCode = 0,
			@ErrMsg = '';

		SELECT @MAgentID = custID, 
			@Amount = amt,
			@MAgUser = MAgUser
		FROM #Customer_Result 
		WHERE rIdx = @rCount;

		-- SET username
		UPDATE @tblResultMember
		SET UserName = @MAgUser
		WHERE CustId = @MAgentID;	

		IF (@Amount = 0)
		BEGIN
			UPDATE @tblResultMember
			SET MsgId = 50025, ErrType = 'BalanceZero', ErrMsg = 'Cannot transfer because balance is 0!'
			WHERE CustId = @MAgentID;	
			GOTO NEXT_PAIR;
		END
	
		--AutoJob Transfer: START a Pair waiting to Processing
		IF @IsAutoTransfer = 1
		BEGIN
			EXEC dbo.Age_ClearBalanceCust_Process_StatusUpd @FromCustID = @FromCustID, @ToCustIds = @MAgentID
				,@Status='Processing', @Amount=@Amount
				,@ErrCode = @ErrCode OUTPUT
				,@ErrMsg = @ErrMsg OUTPUT
			;
			-- CHECK: Cancelling
			IF @ErrCode > 0
			BEGIN
				UPDATE @tblResultMember
				SET MsgId = @ErrCode, ErrType = 'TransferStatus', ErrMsg = @ErrMsg
				WHERE CustId = @MAgentID;	
				GOTO NEXT_PAIR;
			END
		END

		BEGIN TRY
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
						
						UPDATE @tblResultMember
						SET MsgId = 50005, ErrType = 'FullTransfer', ErrMsg = @ErrMsg
						WHERE CustId = @MAgentID;	
						GOTO NEXT_PAIR;
					END	
				-- INSERT AMOUNT INPUTED INTO BETTRANS 
				SET @amount = @AmtTrans	
			END 	

			------------------Gen refno--------------------------------------------------------------- 
			EXEC Get_Refno_Transid @RefNo = @transcode OUTPUT
			
			-- TODO: AutoTransfer - Check cancelled
			IF @IsAutoTransfer = 1
			BEGIN
				EXEC dbo.Age_ClearBalanceCust_Process_StatusUpd @FromCustID = @FromCustID, @ToCustIds = @MAgentID
					,@Status='Processing'
					,@ErrCode = @ErrCode OUTPUT
					,@ErrMsg = @ErrMsg OUTPUT
				;
				-- CHECK: Cancelling
				IF @ErrCode > 0
				BEGIN
					UPDATE @tblResultMember
					SET MsgId = @ErrCode, ErrType = 'TransferStatus', ErrMsg = @ErrMsg
					WHERE CustId = @MAgentID;	
					GOTO NEXT_PAIR;
				END
			END

			--TODO: Set default ERROR for MANUAL transfer
			DECLARE @extraTransDesc VARCHAR(100);
			SELECT @ErrMsg = case @Language 
								when 'E' then 'Clear balance failed. Please try again.'
								ELSE CustDB.[dbo].[f_Get_MsgNamebyMsgID](50003,@Language)
							end
							, @extraTransDesc = CASE 
											WHEN @IsAutoTransfer = 1 THEN ' (added via the Auto Transfer process)'
											WHEN @SubAccID > 0 THEN ' (By ' + @SubAccName + ')'
											ELSE ''
										END

			------------------Insert trans into transfer----------------------------------------------
			BEGIN TRANSACTION
			IF @amount >0
			BEGIN
				EXEC Get_Bettrans_TransID @TransID = @TransID OUTPUT

				BEGIN TRY
					INSERT INTO Transfer 
						(transid, creator, custid, username, refno, transdate, bettype, transdesc, winlost, actual_stake, 
							winlostdate, currency, actualrate,currencyName, mrecommend, srecommend, scomm, swinlost, recommend,ip,statusID, RepUpdateTime)
					VALUES (@transid, @creator, @SAgID, @SAUser, @transcode, current_timestamp, 21003, 'From Customer ::: ' + @MagUser + @extraTransDesc,
						@amount, 0,@WinlostDate, @currency, @actualrate, @currName, 0, @SAgID, 0, 0, 0,@ip,131,SYSDATETIME())
				END TRY
				BEGIN CATCH
					SELECT @ErrCode = 103
					ROLLBACK TRANSACTION
						
					--AutoJob Transfer
					UPDATE @tblResultMember
					SET MsgId = 50027, ErrType = 'DBIssue', ErrMsg = ERROR_MESSAGE()
					WHERE CustID = @MAgentID;

					GOTO NEXT_PAIR;
				END CATCH

				DECLARE @TotalCashMaster MONEY 
				EXEC Acc_CustomerSelCash_CaptureBalance @custid = @Magentid, @TotalCash  = @TotalCashMaster OUTPUT

				EXEC Get_Bettrans_TransID @TransID = @TransID OUTPUT

				BEGIN TRY
					INSERT INTO Transfer
						(transid, creator, custid, username, refno, transdate, bettype, transdesc, winlost, actual_stake, 
						winlostdate, currency, actualrate, currencyName, mrecommend, srecommend, scomm, swinlost, recommend,ip,statusID, balance, RepUpdateTime)
					VALUES (@TransID, @creator, @Magentid, @MAgUser, @transcode, current_timestamp, 21003, 'To Customer ::: ' + @saUser + @extraTransDesc, 0, 
						@amount, @WinlostDate, @currency, @actualrate, @currName, @Magentid, @SAgID, 0, 0, 0,@ip,131, @TotalCashMaster,SYSDATETIME())
				END TRY
				BEGIN CATCH
					select @ErrCode = 104
					ROLLBACK TRANSACTION
						
					--AutoJob Transfer
					UPDATE @tblResultMember
					SET MsgId = 50027, ErrType = 'DBIssue', ErrMsg = ERROR_MESSAGE()
					WHERE CustID = @MAgentID;

					GOTO NEXT_PAIR;
				END CATCH

				--Add writelog for each amt transfered - Vinh 20080629
				SELECT @LogData = 'Transfer from Master ' + @MagUser + ' to Super ' + @saUser + ' with amount ' + CONVERT(VARCHAR(20), @amount) + ' Ref.No ' + CONVERT(VARCHAR(20), @transcode)			
				--AutoJob Transfer: Completed
				UPDATE @tblResultMember
				SET RefNo = @transcode
				WHERE CustID = @MAgentID;

			END
			ELSE IF @amount<0
			BEGIN
				--SET @amount = abs(@amount)

				EXEC Get_Bettrans_TransID @TransID = @TransID OUTPUT
				BEGIN TRY
					INSERT INTO Transfer 
						(transid, creator, custid, username, refno, transdate, bettype, transdesc, winlost, actual_stake, 
						winlostdate, currency, actualrate, currencyName, mrecommend, srecommend, scomm, swinlost, recommend,ip,statusID, RepUpdateTime)
					VALUES (@transid,@creator, @SAgID, @SAUser, @transcode, current_timestamp, 21003, 'To Customer ::: ' + @MagUser + @extraTransDesc, 0, 
						abs(@amount),@WinlostDate, @currency, @actualrate, @currName, 0, @SAgID, 0, 0, 0,@ip,131,SYSDATETIME())
				END TRY
				BEGIN CATCH
					select @ErrCode = 105
					ROLLBACK TRANSACTION
						
					--AutoJob Transfer
					UPDATE @tblResultMember
					SET MsgId = 50027, ErrType = 'DBIssue', ErrMsg = ERROR_MESSAGE()
					WHERE CustID = @MAgentID;

					GOTO NEXT_PAIR;
				END CATCH

				DECLARE @TotalCashMasterNev MONEY 
				EXEC Acc_CustomerSelCash_CaptureBalance @custid = @Magentid, @TotalCash  = @TotalCashMasterNev OUTPUT

				EXEC Get_Bettrans_TransID @TransID = @TransID OUTPUT
				BEGIN TRY
					INSERT INTO Transfer
						(transid, creator, custid, username, refno, transdate, bettype, transdesc, winlost, actual_stake, 
						winlostdate, currency,actualrate, currencyName, mrecommend, srecommend, scomm, swinlost, recommend,ip,statusID, balance, RepUpdateTime)
					VALUES (@transid, @creator, @Magentid, @MAgUser, @transcode, current_timestamp, 21003, 'From Customer ::: ' + @saUser + @extraTransDesc, 
						abs(@amount), 0, @WinlostDate, @currency, @actualrate, @currName, @Magentid, @SAgID, 0, 0, 0,@ip,131, @TotalCashMasterNev,SYSDATETIME())
				END TRY
				BEGIN CATCH
					SELECT @ErrCode = 106
					ROLLBACK TRANSACTION
						
					--AutoJob Transfer
					UPDATE @tblResultMember
					SET MsgId = 50027, ErrType = 'DBIssue', ErrMsg = ERROR_MESSAGE()
					WHERE CustID = @MAgentID;

					GOTO NEXT_PAIR;
				END CATCH
			
				--Add writelog for each amt transfered - Vinh 20080629
				SELECT @LogData = 'Transfer from Super ' + @saUser + ' to Master/DirectMemeber ' + @MagUser + ' with amount ' + convert(varchar(20), @amount) + ' Ref.No ' + convert(varchar(20), @transcode)			
					
				--AutoJob Transfer: Completed
				UPDATE @tblResultMember
				SET RefNo = @transcode
				WHERE CustID = @MAgentID;
			END
			--
			COMMIT TRANSACTION

			SELECT @ErrCode = 0, 
				@ErrMsg		= ''
	
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
		END TRY
		BEGIN CATCH
			--Exception
			UPDATE @tblResultMember
			SET MsgId = 50003, ErrType = 'DBIssue', ErrMsg = ERROR_MESSAGE()
			WHERE CustID = @MAgentID;
		END CATCH

		NEXT_PAIR:
		IF @IsAutoTransfer = 1
		BEGIN
			SELECT @Result = (SELECT MsgId, ErrType, ErrMsg, RefNo FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
				@PairStatus = CASE WHEN RefNo > 0 THEN 'Completed' ELSE 
					CASE WHEN ErrType = 'BalanceZero' THEN 'Ignored' ELSE 'Failed' END
				END
			FROM @tblResultMember 
			WHERE CustId=@MAgentID
			;
			EXEC dbo.Age_ClearBalanceCust_Process_StatusUpd @FromCustID = @FromCustID, @ToCustIds = @MAgentID
				,@Status=@PairStatus, @Result = @Result;
		END
		ELSE
		BEGIN
			--TODO: Check FAILED break for MANUAL transfer
			IF @ErrCode > 0
				RETURN
		END

		SET @rCount += 1;
	END
 
	DROP TABLE #Customer_Result
	DROP TABLE #BalanceInfo
	DROP TABLE #customerList
	DROP TABLE #recommend
	DROP TABLE #SportBettype
	DROP TABLE #ClearBalanceCust_Setting
	DROP TABLE #DirectMemberList
END
GO