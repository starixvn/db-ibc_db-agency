/*<info serverAlias="DBTXN-bodb02" executers="bodbDownlineNet" isFunction="0" isNested="1"></info>*/
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
		DECLARE @tblMoveBetBalanceUp AS TABLE (BalanceUpDay SMALLDATETIME, MoveBetsDay SMALLDATETIME)
		DECLARE @IsDiff BIT = 0, @NewMoveBetDate SMALLDATETIME = NULL

		INSERT INTO @tblMoveBetBalanceUp(BalanceUpDay,MoveBetsDay)
		EXEC bodb02.dbo.Age_SelBalanceUpDay
	
		SELECT @balanceUpDay = BalanceUpDay, @moveBetsDay = MoveBetsDay FROM @tblMoveBetBalanceUp

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
		
			-- bettrans
			INSERT INTO @tblTotalCash (TableName, TotalCash)
			SELECT
				'tblBettrans',
				SUM(winlost-actual_stake+playercomm)
			FROM dbo.bettrans b WITH(NOLOCK)
			WHERE b.custid = @custid
				AND b.bettype < 19999
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
				AND (
						(bettype = 19999 and winlostdate <= @moveBetsDay) OR (bettype > 19999 and bettype NOT IN (21008, 21009))
					)

			----check move bet date again to make sure it is not changed
			EXEC bodb02.dbo.Acc_Transfer_CheckMoveBetDate @moveBetsDay, @IsDiff = @IsDiff OUTPUT, @NewMoveBetDate = @NewMoveBetDate OUTPUT

			IF (@IsDiff = 1)
			BEGIN

				DELETE FROM @tblTotalCash WHERE TableName IN ('tblBettrans', 'tblTransfer')

				-- bettrans
				INSERT INTO @tblTotalCash (TableName, TotalCash)
				SELECT
					'tblBettrans',
					SUM(winlost-actual_stake+playercomm)
				FROM dbo.bettrans b WITH(NOLOCK)
				WHERE b.custid = @custid
					AND b.bettype < 19999
					AND b.statusID IN (111,112,113)
					AND winlostdate > @NewMoveBetDate
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
					AND (
							(bettype = 19999 and winlostdate <= @NewMoveBetDate) OR (bettype > 19999 and bettype NOT IN (21008, 21009))
						)

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
	
			-- bettrans 
			INSERT INTO @tblTotalCash (TableName, TotalCash)
			SELECT 'tblBettrans', SUM(awinlost+comm-playercomm)
			FROM dbo.bettrans b WITH(NOLOCK)
			WHERE b.recommend = @custid	
				AND winlostdate > @moveBetsDay
				AND b.bettype < 19999
				AND b.statusID IN (111,112,113)
				AND (b.winlostdate < @yesterday OR NOT EXISTS (SELECT TOP 1 1 FROM #SportBettype s WHERE s.Bettype = b.bettype))
				
			-- transfer 
			INSERT INTO @tblTotalCash (TableName, TotalCash)
			SELECT 'tblTransfer', SUM(CASE WHEN custid = recommend THEN winlost-actual_stake ELSE awinlost+comm-playercomm END)
			FROM dbo.Transfer b WITH(NOLOCK)
			WHERE b.recommend = @custid	
				AND (
						(bettype = 19999 and winlostdate <= @moveBetsDay) OR (bettype > 19999 and bettype NOT IN (21008, 21009))
					)

			----check move bet date again to make sure it is not changed
			
			EXEC bodb02.dbo.Acc_Transfer_CheckMoveBetDate @moveBetsDay, @IsDiff = @IsDiff OUTPUT, @NewMoveBetDate = @NewMoveBetDate OUTPUT

			IF (@IsDiff = 1)
			BEGIN

				DELETE FROM @tblTotalCash WHERE TableName IN ('tblBettrans', 'tblTransfer')

				-- bettrans 
				INSERT INTO @tblTotalCash (TableName, TotalCash)
				SELECT 'tblBettrans', SUM(awinlost+comm-playercomm)
				FROM dbo.bettrans b WITH(NOLOCK)
				WHERE b.recommend = @custid	
					AND winlostdate > @NewMoveBetDate
					AND b.bettype < 19999
					AND b.statusID IN (111,112,113)
					AND (b.winlostdate < @yesterday OR NOT EXISTS (SELECT TOP 1 1 FROM #SportBettype s WHERE s.Bettype = b.bettype))
					
				-- transfer 
				INSERT INTO @tblTotalCash (TableName, TotalCash)
				SELECT 'tblTransfer', SUM(CASE WHEN custid = recommend THEN winlost-actual_stake ELSE awinlost+comm-playercomm END)
				FROM dbo.Transfer b WITH(NOLOCK)
				WHERE b.recommend = @custid	
					AND (
							(bettype = 19999 and winlostdate <= @NewMoveBetDate) OR (bettype > 19999 and bettype NOT IN (21008, 21009))
						)

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

			-- bettrans
			INSERT INTO @tblTotalCash (TableName, TotalCash)
			SELECT 'tblBettrans', SUM(mwinlost+acomm-comm)
			FROM  #recommend r 
			INNER JOIN  dbo.bettrans b WITH(NOLOCK, INDEX = IX_recommend) ON r.CustId = b.recommend
			WHERE b.bettype < 19999 AND b.statusID IN (111,112,113) 
				AND winlostdate > @moveBetsDay
			-- transfer
			INSERT INTO @tblTotalCash (TableName, TotalCash)
			SELECT 'tblTransfer', SUM(mwinlost+acomm-comm)
			FROM  #recommend r 
			INNER JOIN  dbo.Transfer b WITH(NOLOCK, INDEX = IX_recommend) ON r.CustId = b.recommend
			WHERE (bettype = 19999 and winlostdate <= @moveBetsDay) OR (bettype > 19999 and bettype NOT IN (21008, 21009))
			
			----check move bet date again to make sure it is not changed
			EXEC bodb02.dbo.Acc_Transfer_CheckMoveBetDate @moveBetsDay, @IsDiff = @IsDiff OUTPUT, @NewMoveBetDate = @NewMoveBetDate OUTPUT

			IF (@IsDiff = 1)
			BEGIN

				DELETE FROM @tblTotalCash WHERE TableName IN ('tblBettrans', 'tblTransfer')

				-- bettrans
				INSERT INTO @tblTotalCash (TableName, TotalCash)
				SELECT 'tblBettrans', SUM(mwinlost+acomm-comm)
				FROM  #recommend r 
				INNER JOIN  dbo.bettrans b WITH(NOLOCK, INDEX = IX_recommend) ON r.CustId = b.recommend
				WHERE b.bettype < 19999 AND b.statusID IN (111,112,113)
					AND winlostdate > @NewMoveBetDate
				-- transfer
				INSERT INTO @tblTotalCash (TableName, TotalCash)
				SELECT 'tblTransfer', SUM(mwinlost+acomm-comm)
				FROM  #recommend r 
				INNER JOIN  dbo.Transfer b WITH(NOLOCK, INDEX = IX_recommend) ON r.CustId = b.recommend
				WHERE (bettype = 19999 and winlostdate <= @NewMoveBetDate) OR (bettype > 19999 and bettype NOT IN (21008, 21009))

			END
			-- sum, balance, transfer tickets of this master
			INSERT INTO @tblTotalCash (TotalCash)
			SELECT SUM(winlost-actual_stake)
			FROM dbo.Transfer b WITH(NOLOCK)
			WHERE custid = @custid
				AND b.bettype NOT IN (21008, 21009)

			SELECT @TotalCash = SUM(ISNULL(TotalCash,0)) 
			FROM @tblTotalCash

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

			-- bettrans 
			INSERT INTO @tblTotalCash (TableName, TotalCash)
			SELECT 'tblBettrans', SUM(swinlost+scomm-acomm)
			FROM	#recommend r
			INNER JOIN dbo.bettrans b WITH(NOLOCK, INDEX = IX_recommend) ON r.CustId = b.recommend
			WHERE b.bettype < 19999 AND b.statusID IN (111,112,113)
				AND winlostdate > @moveBetsDay
			-- Transfer 
			INSERT INTO @tblTotalCash (TableName, TotalCash)
			SELECT 'tblTransfer', SUM(swinlost+scomm-acomm)
			FROM	#recommend r
			INNER JOIN dbo.Transfer b WITH(NOLOCK, INDEX = IX_recommend)  ON r.CustId = b.recommend
			WHERE (bettype = 19999 and winlostdate <= @moveBetsDay) OR (bettype > 19999 and bettype NOT IN (21008, 21009))

			----check move bet date again to make sure it is not changed
			EXEC bodb02.dbo.Acc_Transfer_CheckMoveBetDate @moveBetsDay, @IsDiff = @IsDiff OUTPUT, @NewMoveBetDate = @NewMoveBetDate OUTPUT

			IF (@IsDiff = 1)
			BEGIN

				DELETE FROM @tblTotalCash WHERE TableName IN ('tblBettrans', 'tblTransfer')

				-- bettrans 
				INSERT INTO @tblTotalCash (TableName, TotalCash)
				SELECT 'tblBettrans', SUM(swinlost+scomm-acomm)
				FROM	#recommend r
				INNER JOIN dbo.bettrans b WITH(NOLOCK, INDEX = IX_recommend) ON r.CustId = b.recommend
				WHERE b.bettype < 19999 AND b.statusID IN (111,112,113)
					AND winlostdate > @NewMoveBetDate
				-- Transfer 
				INSERT INTO @tblTotalCash (TableName, TotalCash)
				SELECT 'tblTransfer', SUM(swinlost+scomm-acomm)
				FROM	#recommend r
				INNER JOIN dbo.Transfer b WITH(NOLOCK, INDEX = IX_recommend)  ON r.CustId = b.recommend
				WHERE (bettype = 19999 and winlostdate <= @NewMoveBetDate) OR (bettype > 19999 and bettype NOT IN (21008, 21009))

			END

			-- sum, balance, transfer tickets of this super
			INSERT INTO @tblTotalCash (TotalCash)
			SELECT SUM(case when b.custID = srecommend THEN winlost-actual_stake END)
			FROM dbo.Transfer b WITH(NOLOCK) 
			WHERE b.CustId = @CustId 
				AND b.bettype NOT IN (21008, 21009)

			SELECT @TotalCash = SUM(ISNULL(TotalCash,0))
			FROM @tblTotalCash

		END
		DROP TABLE #recommend
		DROP TABLE #SportBettype
	END
END
