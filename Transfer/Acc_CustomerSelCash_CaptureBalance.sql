/*<info serverAlias="DBTXN-bodb02" executers="wsv_alp" isFunction="0" isNested="1"></info>*/
ALTER PROCEDURE [dbo].[Acc_CustomerSelCash_CaptureBalance]
	@CustId INT,
	@TotalCash MONEY = 0 OUTPUT
AS

/*
	Created by Danny
	Date: 2020-12-22
	DB: DBTXN.bodb02
	Task: Get Total cash of Customer

	Revisions:
		- 20201222@Danny: Get Balance Information of Customer by CustID [RedmineID: #146038]
		- 20210505@Sol: NAP - Alpha - Allow more time for transfer - [Redmine: #149927]
		- 20211111@Evan: Split transfer tickets out of bettrans - [Redmine: #164196]
    	- 20230227@Evan: Balance-Up support transfer 247 [Redmine: #173554] 
		- 20240314@Bobby: EC enhancement [Redmine: #202276]
		- 20241118@Max: Alpha - Offer Direct Member for Super/Master [Redmine: #211969]
	
	Param's Explaination:
		- @CustId: custid
		
	Note: get balance real time => this balance is approximately 
	
*/

BEGIN
	SET NOCOUNT ON

	IF EXISTS (
				SELECT 1
				FROM dbo.SystemSettings WITH(NOLOCK)
				WHERE VValue 	= 1 
				AND VName 		= 'isCaptureBalance'
			)
	BEGIN

		DECLARE @balanceUpDay SMALLDATETIME, @moveBetsDay SMALLDATETIME
		DECLARE @IsDiff	SMALLINT = 1, @NewMoveBetDate SMALLDATETIME = NULL,@NewBalanceUpDate SMALLDATETIME = NULL

		--TODO: Get MBU days
		EXEC dbo.NAP_Admin_GetMovebetDate @MovebetDate = @moveBetsDay OUTPUT
		EXEC dbo.NAP_Admin_GetBalanceUpDate @BalanceUpDate = @balanceUpDay OUTPUT

		DECLARE @yesterday SMALLDATETIME, @today SMALLDATETIME
		SELECT @today =   CAST(CURRENT_TIMESTAMP AS DATE)
			, @yesterday = CONVERT(DATE, DATEADD(DAY, -1, @today))

		-- Get bettype --
		DECLARE @isTest BIT = 0
		SELECT  @isTest = dbo.f_CheckSPVersion(@@PROCID)
	
		CREATE TABLE #SportBettype (bettype INT, RefTable TINYINT)
		INSERT INTO #SportBettype (bettype, RefTable)
		SELECT bettype, RefTable FROM dbo.f_SportBettypeMatrix_Sel (0, 0, 0, 2, '', '', @isTest) WHERE RefTable IN (1, 2)

		DECLARE @roleID TINYINT, @ID INT = 1

		SELECT  @roleID = roleid  FROM CustDB.dbo.custInfo WITH(NOLOCK) WHERE custid = @custID

		DECLARE @tblSportTypeRNG AS TABLE (SportType SMALLINT)
		DECLARE @tblSportTypeLC AS TABLE (SportType SMALLINT)

		INSERT INTO @tblSportTypeRNG(SportType)
		SELECT DISTINCT SportType FROM SportBettypeMatrix WITH(NOLOCK) WHERE RefTable = 1

		INSERT INTO @tblSportTypeLC(SportType)
		SELECT DISTINCT SportType FROM SportBettypeMatrix WITH(NOLOCK) WHERE RefTable = 2
	
		IF ISNULL(@roleID, 5) > 4
		BEGIN
			RETURN
		END

		DECLARE @transdate DATETIME, @UsedCredit MONEY, @transid BIGINT
	
		-- Get Balance Information 
		DECLARE @tblTotalCash TABLE (TableName VARCHAR(100), TotalCash MONEY)

		CREATE TABLE #recommend (CustId INT)	

		IF @roleid = 1
		BEGIN
			-- bettransRNG
			INSERT INTO @tblTotalCash (TotalCash)
			SELECT SUM(winlost-actual_stake+playercomm)
			FROM dbo.bettransRNG WITH(NOLOCK)
			WHERE custid = @custid
				AND winlostdate >= @yesterday
				AND statusID IN (111,112,113)
			
			-- bettransLC
			INSERT INTO @tblTotalCash (TotalCash)
			SELECT SUM(winlost-actual_stake+playercomm)
			FROM dbo.bettransLC WITH(NOLOCK)
			WHERE custid = @custid
				AND winlostdate >= @yesterday
				AND statusID IN (111,112,113)
		
			WHILE (@IsDiff = 1)
			BEGIN

				DELETE FROM @tblTotalCash WHERE TableName IN ('tblBettrans', 'tblTransfer')

				-- bettrans
				INSERT INTO @tblTotalCash (TableName, TotalCash)
				SELECT
					'tblBettrans',
					SUM(winlost-actual_stake+playercomm)
				FROM dbo.bettrans b WITH(NOLOCK)
				WHERE b.custid = @custid
					AND b.statusID IN (111,112,113)
					AND winlostdate > @moveBetsDay
					AND (
						b.winlostdate < @yesterday
						OR NOT EXISTS (SELECT TOP 1 1 FROM #SportBettype s WHERE s.Bettype = b.bettype)
					)

				-- transfer
				INSERT INTO @tblTotalCash (TableName, TotalCash)
				SELECT
					'tblTransfer',
					SUM(winlost-actual_stake+playercomm)
				FROM dbo.Transfer b WITH(NOLOCK)
				WHERE b.custid = @custid
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

			SELECT @TotalCash = SUM(ISNULL(TotalCash,0)) 
			FROM @tblTotalCash

		END 
		ELSE IF @roleid = 2
		BEGIN
			-- bettransRNG
			INSERT INTO @tblTotalCash (TotalCash)
			SELECT SUM(awinlost+comm-playercomm)
			FROM dbo.bettransRNG WITH(NOLOCK)
			WHERE recommend = @custid
				AND winlostdate >= @yesterday
				AND statusID IN (111,112,113)
		
			-- bettransLC
			INSERT INTO @tblTotalCash (TotalCash)
			SELECT SUM(awinlost+comm-playercomm)
			FROM dbo.bettransLC WITH(NOLOCK)
			WHERE recommend = @custid
				AND winlostdate >= @yesterday
				AND statusID IN (111,112,113)

			WHILE (@IsDiff = 1)
			BEGIN

				DELETE FROM @tblTotalCash WHERE TableName IN ('tblBettrans', 'tblTransfer')

				-- bettrans 
				INSERT INTO @tblTotalCash (TableName, TotalCash)
				SELECT 'tblBettrans', SUM(awinlost+comm-playercomm)
				FROM dbo.bettrans b WITH(NOLOCK)
				WHERE b.recommend = @custid	
					AND winlostdate > @moveBetsDay
					AND b.statusID IN (111,112,113)
					AND (b.winlostdate < @yesterday OR NOT EXISTS (SELECT TOP 1 1 FROM #SportBettype s WHERE s.Bettype = b.bettype))
					
				-- transfer 
				INSERT INTO @tblTotalCash (TableName, TotalCash)
				SELECT 'tblTransfer', SUM(CASE WHEN custid = recommend THEN winlost-actual_stake ELSE awinlost+comm-playercomm END)
				FROM dbo.Transfer b WITH(NOLOCK)
				WHERE b.recommend = @custid	
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

			SELECT @TotalCash = SUM(ISNULL(TotalCash,0)) 
			FROM @tblTotalCash

		END
		ELSE IF @roleid = 3
		BEGIN
	   
			INSERT INTO #recommend (CustId)
			SELECT custid
			FROM CustDB.dbo.custInfo c WITH(NOLOCK)
			WHERE c.roleid = 2 AND mrecommend = @CustId

			-- bettransRNG
			INSERT INTO @tblTotalCash (TotalCash)
			SELECT SUM(mwinlost+acomm-comm)
			FROM  #recommend r 
			INNER JOIN  dbo.bettransRNG b WITH(NOLOCK) ON r.CustId = b.recommend
			WHERE    b.productID IN (SELECT SportType FROM @tblSportTypeRNG)
					AND IsSum = 0
					AND winlostdate >= @yesterday
					AND statusID IN (111,112,113)
		
			-- bettransLC
			INSERT INTO @tblTotalCash (TotalCash)
			SELECT SUM(mwinlost+acomm-comm)
			FROM  #recommend r 
			INNER JOIN  dbo.bettransLC b WITH(NOLOCK)  ON r.CustId = b.recommend
			WHERE    b.productID IN (SELECT SportType FROM @tblSportTypeLC)
					AND IsSum = 0
					AND winlostdate >= @yesterday
					AND statusID IN (111,112,113)

			WHILE (@IsDiff = 1)
			BEGIN

				DELETE FROM @tblTotalCash WHERE TableName IN ('tblBettrans', 'tblTransfer')

				-- bettrans
				INSERT INTO @tblTotalCash (TableName, TotalCash)
				SELECT 'tblBettrans', SUM(mwinlost+acomm-comm)
				FROM  #recommend r 
				INNER JOIN  dbo.bettrans b WITH(NOLOCK, INDEX = IX_recommend) ON r.CustId = b.recommend
				WHERE b.statusID IN (111,112,113) 
					AND winlostdate > @moveBetsDay
				-- transfer
				INSERT INTO @tblTotalCash (TableName, TotalCash)
				SELECT 'tblTransfer', SUM(mwinlost+acomm-comm)
				FROM  #recommend r 
				INNER JOIN  dbo.Transfer b WITH(NOLOCK, INDEX = IX_recommend) ON r.CustId = b.recommend
				WHERE 1 = CASE WHEN bettype = 19999 AND winlostdate > @moveBetsDay THEN 0 --> new sum
							WHEN bettype = 20000 AND winlostdate > @balanceUpDay THEN 0 --> new bal
							WHEN winlostdate < @balanceUpDay THEN 0 --> old data
							ELSE 1 END
					AND bettype NOT IN (21008, 21009)

				-- sum, balance, transfer tickets of this master
				INSERT INTO @tblTotalCash (TableName, TotalCash)
				SELECT 'tblTransfer', SUM(winlost-actual_stake)
				FROM dbo.Transfer b WITH(NOLOCK)
				WHERE custid = @custid
					AND b.bettype NOT IN (21008, 21009)
					AND 1 = CASE WHEN bettype = 20000 AND winlostdate > @balanceUpDay THEN 0 --> new bal
								WHEN winlostdate < @balanceUpDay THEN 0 --> old data
							ELSE 1 END
				SELECT @TotalCash = SUM(ISNULL(TotalCash,0)) 
				FROM @tblTotalCash

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
		ELSE IF @roleid = 4
		BEGIN    	
		
			INSERT INTO #recommend (CustId)
			SELECT custid
			FROM CustDB.dbo.custInfo c WITH(NOLOCK)
			WHERE c.roleid = 2 AND srecommend = @CustId

			-- bettransRNG
			INSERT INTO @tblTotalCash (TotalCash)
			SELECT  SUM(swinlost+scomm-acomm)
			FROM	#recommend r 
			INNER JOIN dbo.bettransRNG b WITH(NOLOCK) ON r.CustId = b.recommend
			WHERE    b.productID IN (SELECT SportType FROM @tblSportTypeRNG)
					AND IsSum = 0
					AND winlostdate >= @yesterday
					AND statusID IN (111,112,113)

			-- bettransLC
			INSERT INTO @tblTotalCash (TotalCash)
			SELECT SUM(swinlost+scomm-acomm)
			FROM	#recommend r 
			INNER JOIN dbo.bettransLC b WITH(NOLOCK) ON r.CustId = b.recommend
			WHERE    b.productID IN (SELECT SportType FROM @tblSportTypeLC)
					AND IsSum = 0
					AND winlostdate >= @yesterday
					AND statusID IN (111,112,113)

			WHILE (@IsDiff = 1)
			BEGIN

				DELETE FROM @tblTotalCash WHERE TableName IN ('tblBettrans', 'tblTransfer')

				-- bettrans 
				INSERT INTO @tblTotalCash (TableName, TotalCash)
				SELECT 'tblBettrans', SUM(swinlost+scomm-acomm)
				FROM	#recommend r
				INNER JOIN dbo.bettrans b WITH(NOLOCK, INDEX = IX_recommend) ON r.CustId = b.recommend
				WHERE b.statusID IN (111,112,113)
					AND winlostdate > @moveBetsDay
				-- Transfer 
				INSERT INTO @tblTotalCash (TableName, TotalCash)
				SELECT 'tblTransfer', SUM(swinlost+scomm-acomm)
				FROM	#recommend r
				INNER JOIN dbo.Transfer b WITH(NOLOCK, INDEX = IX_recommend)  ON r.CustId = b.recommend
				WHERE 1 = CASE WHEN bettype = 19999 AND winlostdate > @moveBetsDay THEN 0 --> new sum
							WHEN bettype = 20000 AND winlostdate > @balanceUpDay THEN 0 --> new bal
							WHEN winlostdate < @balanceUpDay THEN 0 --> old data
							ELSE 1 END
					AND bettype NOT IN (21008, 21009)
				
				-- sum, balance, transfer tickets of this super
				INSERT INTO @tblTotalCash (TableName, TotalCash)
				SELECT 'tblTransfer', SUM(case when b.custID = srecommend THEN winlost-actual_stake END)
				FROM dbo.Transfer b WITH(NOLOCK) 
				WHERE b.CustId = @CustId 
					AND b.bettype NOT IN (21008, 21009)
					AND 1 = CASE WHEN bettype = 20000 AND winlostdate > @balanceUpDay THEN 0 --> new bal
								WHEN winlostdate < @balanceUpDay THEN 0 --> old data
							ELSE 1 END
				SELECT @TotalCash = SUM(ISNULL(TotalCash,0))
				FROM @tblTotalCash

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
		DROP TABLE #recommend
		DROP TABLE #SportBettype
	END
END
