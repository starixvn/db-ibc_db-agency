/*<info serverAlias="DBSIC-bodb02" executers="wsv_CashService" selecters="" viewers="" isFunction="0" isNested=""></info>*/
ALTER PROCEDURE dbo.Task_CashService_AccumCreditReturn_YesterdayLoss_Sel
	@IsTest BIT = 0
    ,@CustIDList NVARCHAR(MAX) OUTPUT -- JSON: [{CustID,YesterdayWL}]
AS
/*
	Created: 20250617@Max		
	Task: Get All Customers from CashAccumCredit and YesterdayWinLoss < 0, Return All CustID output Json (@CustIDList)
	DB:  DBSIC-bodb02
		
	Revisions:
		- 20250617@Max: Alpha - Agency Cash Service [redmine: #223896] 

	Parameter's Explanation:	
			[{"CustID":1,"YesterdayWL":-0.25}, {"CustID":2,"YesterdayWL":-2.25}]
	Sample:
		
*/ 
BEGIN
    SET NOCOUNT ON;

	DECLARE @yesterday SMALLDATETIME, @today SMALLDATETIME
	SELECT @today =   CAST(CURRENT_TIMESTAMP AS DATE)
		, @yesterday = CONVERT(DATE, DATEADD(DAY, -1, @today))

	DECLARE @balanceUpDay SMALLDATETIME, @moveBetsDay SMALLDATETIME
	DECLARE @IsDiff	SMALLINT = 1, @NewMoveBetDate SMALLDATETIME = NULL,@NewBalanceUpDate SMALLDATETIME = NULL

	--TODO: Get MBU days
	EXEC dbo.NAP_Admin_GetMovebetDate @MovebetDate = @moveBetsDay OUTPUT
	EXEC dbo.NAP_Admin_GetBalanceUpDate @BalanceUpDate = @balanceUpDay OUTPUT
	
	CREATE TABLE #tmp_CustId (CustId INT PRIMARY KEY)
	CREATE TABLE #balance (CustId INT, YesterdayWL MONEY, TableName VARCHAR(100))
	CREATE TABLE #result_balance (CustId INT, YesterdayWL MONEY)

	CREATE TABLE #SportBettype (bettype INT, RefTable TINYINT)
	INSERT INTO #SportBettype (bettype, RefTable)
	SELECT bettype, RefTable FROM dbo.f_SportBettypeMatrix_Sel (0, 0, 0, 2, '', '', 0)

	INSERT INTO #tmp_CustId (CustId)
	SELECT CustID
	FROM dbo.CashAccumCredit c WITH (NOLOCK)
		CROSS APPLY (
			SELECT TOP 1 1 AS IsTest
			FROM CustDB.dbo.custInfo ci WITH (NOLOCK)
			WHERE ci.custid = c.CustID
				AND 1 = CASE WHEN @IsTest = 1 AND ci.currency = 20 THEN 1
							WHEN @IsTest = 0 THEN 1
						ELSE 0 END
		)ci
	WHERE AccumCreditReturn > 0
		AND ModifiedDate > CONVERT(DATE,GETDATE() - 1) -- No need scan customers who don't have any action from yesterday (Deposit, withdrawal,Job adjust Loss...)

	-- bettransRNG
	INSERT INTO #balance (CustId, YesterdayWL)
	SELECT c.CustId, SUM(winlost-actual_stake+playercomm)
	FROM dbo.bettransRNG b WITH(NOLOCK)
		INNER JOIN #tmp_CustId c ON c.CustId = b.custid
	WHERE winlostdate = @yesterday
		AND statusID IN (111,112,113)
	GROUP BY c.CustId
			
	-- bettransLC
	INSERT INTO #balance (CustId, YesterdayWL)
	SELECT c.CustId, SUM(winlost-actual_stake+playercomm)
	FROM dbo.bettransLC b WITH(NOLOCK)
		INNER JOIN #tmp_CustId c ON c.CustId = b.custid
	WHERE  winlostdate = @yesterday
		AND statusID IN (111,112,113)
	GROUP BY c.CustId
		
	WHILE (@IsDiff = 1)
	BEGIN

		DELETE FROM #balance WHERE TableName IN ('tblBettrans', 'tblTransfer')

		-- bettrans
		INSERT INTO #balance (TableName, CustId, YesterdayWL)
		SELECT
			'tblBettrans',
			c.CustId,
			SUM(winlost-actual_stake+playercomm)
		FROM dbo.bettrans b WITH(NOLOCK)
			INNER JOIN #tmp_CustId c ON c.CustId = b.custid
		WHERE b.statusID IN (111,112,113)
			AND winlostdate > @moveBetsDay
			AND (
				b.winlostdate = @yesterday
				OR NOT EXISTS (SELECT TOP 1 1 FROM #SportBettype s WHERE s.Bettype = b.bettype)
			)
		GROUP BY c.CustId

		-- transfer
		INSERT INTO #balance (TableName, CustId, YesterdayWL)
		SELECT
			'tblTransfer',
			c.custid,
			SUM(winlost-actual_stake+playercomm)
		FROM dbo.Transfer b WITH(NOLOCK)
			INNER JOIN #tmp_CustId c ON c.CustId = b.custid
		WHERE b.WinlostDate = @yesterday
			AND 1 = CASE WHEN bettype = 19999 AND winlostdate > @moveBetsDay THEN 0 --> new sum
				WHEN bettype = 20000 AND winlostdate > @balanceUpDay THEN 0 --> new bal
				WHEN winlostdate < @balanceUpDay THEN 0 --> old data
				ELSE 1 END
			AND bettype NOT IN (21008, 21009)
		GROUP BY c.CustId

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
	/* End Balance Info */

	INSERT INTO #result_balance (custid, YesterdayWL)
	SELECT custid, SUM(YesterdayWL)
	FROM #balance
	GROUP BY custid

	DELETE #result_balance  WHERE YesterdayWL >= 0

	--Return Data
	SET @CustIDList = (
		SELECT r.CustId AS 'CustID'
			,r.YesterdayWL AS 'YesterdayWL'
		FROM #result_balance r
		FOR JSON PATH)
	
	DROP TABLE #balance
	DROP TABLE #result_balance
	DROP TABLE #SportBettype
	DROP TABLE #tmp_CustId
END
GO
