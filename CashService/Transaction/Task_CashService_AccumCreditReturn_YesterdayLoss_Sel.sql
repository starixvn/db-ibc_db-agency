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
		- 20250627@Eden: Alpha - Agency Cash Service - Sprint 5 [redmine: #223896] 

	Parameter's Explanation:	
			[{"CustID":1,"YesterdayWL":-0.25}, {"CustID":2,"YesterdayWL":-2.25}]
	Sample:
		DECLARE @CustIDList NVARCHAR(MAX)
		EXEC Task_CashService_AccumCreditReturn_YesterdayLoss_Sel_UAT2
			@CustIDList= @CustIDList OUTPUT,
			@IsTest = 0
		SELECT @CustIDList
*/ 
BEGIN
    SET NOCOUNT ON;

	DECLARE @yesterday SMALLDATETIME
	SELECT @yesterday = CONVERT(DATE,GETDATE()- 1)
	
	CREATE TABLE #tmp_CustId (CustId INT PRIMARY KEY)
	CREATE TABLE #balance (CustId INT, YesterdayWL MONEY)
	CREATE TABLE #result_balance (CustId INT, YesterdayWL MONEY)

	CREATE TABLE #SportBettype (bettype INT, RefTable TINYINT)
	INSERT INTO #SportBettype (bettype, RefTable)
	SELECT bettype, RefTable FROM dbo.f_SportBettypeMatrix_Sel (0, 0, 0, 2, '', '', 0)
	WHERE RefTable IN (1, 2) -- RefTable: 0-bettrans, 1-bettransRnG, 2-bettransLC, 3-translog

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
		--AND ModifiedDate > CONVERT(DATE,GETDATE() - 1) -- No need scan customers who don't have any action from yesterday (Deposit, withdrawal,Job adjust Loss...)

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

	-- bettrans
	INSERT INTO #balance (CustId, YesterdayWL)
	SELECT c.CustId, SUM(winlost-actual_stake+playercomm)
	FROM dbo.bettrans b WITH(NOLOCK)
		INNER JOIN #tmp_CustId c ON c.CustId = b.custid
	WHERE b.statusID IN (111,112,113)
		AND	b.winlostdate = @yesterday
		AND NOT EXISTS (SELECT 1 FROM #Sportbettype s WHERE s.Bettype = b.bettype) -- already get on bettransRNG/bettransLC table
	GROUP BY c.CustId

	INSERT INTO #result_balance (custid, YesterdayWL)
	SELECT custid, SUM(YesterdayWL)
	FROM #balance bt
	GROUP BY custid
	HAVING SUM(YesterdayWL) < 0

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
