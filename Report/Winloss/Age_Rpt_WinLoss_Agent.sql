/*<info serverAlias="DBAGE-bodb02" executers="bodbDownlineNet,bodbDownlineNetView" viewers="" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Age_Rpt_WinLoss_Agent]
	@CustID 		INT, --mrecommend
	@FromDate 		SMALLDATETIME,
	@ToDate 		SMALLDATETIME,
	@ProductIds		VARCHAR(MAX),
	@MoveBetsDay	SMALLDATETIME,
	@BalanceUpDay	SMALLDATETIME	
AS

/*
    Created: 
    Task : 
    DB: DBAGE/bodb02
    Original SP: Age_Rpt_WinLoss_MAg
				Change SP name suffix to match with web function
    Revisions:
        - 20161111@Paul: Microsite for Report - [Redmine: #66991]
		- 20170622@Percy: Combine Betradar Virtual Sports with Virtual Sports [RedmineID: #78339]
		- 20180518@Sophia: WC2018 - Enhance Performance at Sum_winloss_old table [Redmind: #91107]
		- 20180914@Percy: Poker Games - Modify GrossComm [RedmineID: #101550]
		- 20181003@Helen: Modify code to adapt indexes changed on DB053 [Redmine:101405]

*/

BEGIN
	SET NOCOUNT ON;

	CREATE TABLE #MAgWinLoss(
		CustID		INT,
		TurnOver	MONEY,
		GrossComm	MONEY,
		AgTotal		MONEY,
		MAgWinlost	MONEY,
		Comm		MONEY
	);

	CREATE TABLE #TmpCondSumWL(
		SportType	INT,
		BetType		INT
	);

	DECLARE @isTest BIT = 0;
	SELECT  @isTest = dbo.f_CheckSPVersion(@@PROCID);

	SELECT @ProductIds = dbo.f_AddRelatedProducts(@ProductIds);

	INSERT INTO #TmpCondSumWL(SportType, BetType) 
	SELECT SportType, BetType
	FROM dbo.f_SumWinloss_ConditionSel(@ProductIds) f

	------Get @Srecommend
	DECLARE @Srecommend int;
	 
	SELECT @Srecommend = Srecommend
	FROM dbo.CustInfo WITH (NOLOCK)
	WHERE CustID = @CustID;

	-----Get Special Super to hide data of them before specific date 
	DECLARE @IsHide BIT = 0;

	IF EXISTS (	SELECT 1
				FROM dbo.f_SpecialSuper()
				WHERE Srecommend = @Srecommend)
	BEGIN
		SELECT @IsHide = 1;
	END
	
	----Get Account Login to detect Interal or not
	DECLARE @LoginName NVARCHAR(128);
	SELECT @LoginName = SUSER_NAME();

	--Avoid Parameter Sniffing for bettrans and sum_winloss
	DECLARE @FDate	SMALLDATETIME,
			@TDate	SMALLDATETIME,
			@CID	INT    	  
			  
	SELECT	@FDate = @FromDate,
			@TDate = @ToDate,
			@CID = @custid;


	DECLARE @SportBettypeMatrix TABLE(
		BetType	smallint
	);

	INSERT INTO @SportBettypeMatrix(
		BetType
	)
	SELECT BetType FROM dbo.f_SportBettypeMatrixByProduct_Sel(@ProductIds, @IsTest);

	IF @ToDate >= @BalanceUpDay
	BEGIN
		IF @FromDate <= @MoveBetsDay
		BEGIN
			SET @FDate = DATEADD(DD, 1, @MoveBetsDay);
		END

		INSERT INTO #MAgWinLoss(CustID, TurnOver, GrossComm, AgTotal, MAgWinlost, Comm)
		SELECT	recommend AS CustID,
				SUM(CASE WHEN b.liveawayscore = 0 AND b.bettype IN(33,43) THEN ABS(b.stake)/2 ELSE ABS(b.stake) END) AS TurnOver,
				SUM(CASE
					WHEN b.bettype = 1000 THEN oddsspread
					WHEN b.bettype BETWEEN 1401 AND 1499 THEN acomm
					ELSE CASE WHEN (apositiontaking + mpositiontaking = 1) THEN 0 ELSE acomm/(1-apositiontaking - mpositiontaking) END END) AS GrossComm,
				ISNULL(SUM(winlost - actual_stake), 0) + ISNULL(SUM(awinlost), 0) + ISNULL(SUM(comm), 0) AS AgTotal,
				SUM(mwinlost) AS MAgWinlost,
				ISNULL(SUM(acomm), 0) - ISNULL(SUM(comm), 0) AS Comm
		FROM dbo.bettrans b WITH (NOLOCK)
			INNER JOIN @SportBettypeMatrix s ON b.bettype = s.Bettype
		WHERE mrecommend = @CID 
			AND winlostdate BETWEEN @FDate AND @TDate
			AND b.statusID NOT IN (0, 1, 101, 102, 103)
		GROUP BY recommend, b.bettype;

		IF @BalanceUpDay < @FromDate
		BEGIN
			SET @FDate = @FromDate;
		END
		ELSE
		BEGIN
			SET @FDate = @BalanceUpDay;
		END
		
		IF @ToDate > @MoveBetsDay
		BEGIN
			SET @TDate = @MoveBetsDay;
		END
		
		INSERT INTO #MAgWinLoss(CustID, TurnOver, GrossComm, AgTotal, MAgWinlost, Comm)
		SELECT	CustID,
				SUM(ABS(TurnOver)) AS TurnOver,
				SUM(grosscomm) AS GrossComm,
				ISNULL(SUM(winlost),0) + ISNULL(SUM(awinlost), 0) + ISNULL(SUM(comm), 0) AS AgTotal,
				SUM(mwinlost) AS MAgWinlost,
				ISNULL(SUM(acomm), 0) - ISNULL(SUM(comm), 0) AS Comm
		FROM  dbo.sum_winloss b WITH (NOLOCK) 
			INNER JOIN #TmpCondSumWL t ON b.sporttype = t.sporttype AND b.bettype = t.bettype
		WHERE winlostdate BETWEEN @FDate AND @TDate
			AND mrecommend = @CID
			AND roleid = 2
		GROUP BY custid;
	END

	SELECT	@FDate = @FromDate,
			@TDate = @ToDate;

	IF @FromDate < @BalanceUpDay 
	BEGIN
		IF @ToDate >= DATEADD(dd, -1, @BalanceUpDay)
		BEGIN
			SELECT @TDate = DATEADD(dd, -1, @BalanceUpDay);
		END
	
		IF @FromDate < '2016-06-01' AND @IsHide = 1 AND @LoginName <> 'bodbDownlineNetView' --- acc internal login 
		BEGIN
			SELECT @FDate = '2016-06-01';	
		END			
				

		-- using cte to remove predicate when seek on sum_winloss_old
		;WITH CTE_Winlostdate (winlostdate, sporttype, bettype) AS
		(
			SELECT @FDate AS winlostdate, SportType, BetType
			FROM #TmpCondSumWL
			UNION ALL
			SELECT DATEADD(DAY, 1, winlostdate), SportType, BetType
			FROM CTE_Winlostdate
			WHERE winlostdate < @TDate
		)		
		INSERT INTO #MAgWinLoss(CustID, TurnOver, GrossComm, AgTotal, MAgWinlost, Comm)
		SELECT	CustID,
				SUM(ABS(TurnOver)) AS TurnOver,
				SUM(grosscomm) AS GrossComm,
				ISNULL(SUM(winlost), 0) + ISNULL(SUM(awinlost), 0) + ISNULL(SUM(comm), 0) AS AgTotal,
				SUM(mwinlost) AS MAgWinlost,
				ISNULL(SUM(acomm), 0) - ISNULL(SUM(comm), 0) AS Comm
		FROM bodb_Summary.dbo.Sum_WinLoss_Old b WITH(NOLOCK) 
			CROSS APPLY CTE_Winlostdate w
		WHERE b.Winlostdate = w.winlostdate
			AND Srecommend = @Srecommend   --- Add Srecommend, recommend to get the index seek 
			AND MRecommend = @CustID
			AND recommend = recommend
			AND RoleID = 2 
			AND b.sporttype = w.sporttype
			AND b.bettype = w.bettype		
		GROUP BY CustID
		OPTION (MAXRECURSION 0)
	END

	SELECT	w.CustID AS CustId,
			c.UserName AS CustName,
			SUM(TurnOver) AS Turnover,
			SUM(GrossComm) AS GrossComm,
			SUM(AgTotal) AS AgTotal,
			SUM(MAgWinlost) AS MAgWinLoss,
			SUM(Comm) AS MAgComm
	FROM  #MAgWinLoss w 
		INNER JOIN Customer c WITH(NOLOCK) ON w.CustID = c.CustID 
	GROUP BY w.CustID, c.UserName
	ORDER BY c.Username;

	SET NOCOUNT OFF;
END
GO