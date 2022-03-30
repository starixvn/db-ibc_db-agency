/*<info serverAlias="DBAGE-bodb02" executers="bodbDownlineNet,bodbDownlineNetView" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Age_Rpt_WinLoss_Member]
	@CustID 		INT, --recommend
	@FromDate 		SMALLDATETIME,
	@ToDate 		SMALLDATETIME,
	@ProductIds		VARCHAR(MAX),
	@ProductDetails NVARCHAR(MAX) = 'All',
	@MoveBetsDay	SMALLDATETIME,
	@BalanceUpDay	SMALLDATETIME	
AS

/*
    Created: 
    Task : 
    DB: DBAGE/bodb02
    
	Revisions:
        - 20161111@Paul: Microsite for Report - [Redmine: #66991]
		- 20170622@Percy: Combine Betradar Virtual Sports with Virtual Sports [RedmineID: #78339]
		- 20180518@Sophia: WC2018 - Enhance Performance at Sum_winloss_old table [Redmind: #91107]
		- 20180914@Percy: Poker Games - Modify GrossComm [RedmineID: #101550]
		- 20190826@Percy: Remove inactive products [RedmineID: #118699]
		- 20200909@Malcolm : Report Enhancement for Jackpot Product [RedmineID : #139575]
		- 20211122@Percy: Enhance gross comm formula [RedmineID: #164479]
		- 20220208@Danny: Separate Saba Sport Performance [Redmine: #167177]
	
	Param's Explanation:
	  @ProductDetails:		
		<ROOT>
				<ProductDetail ProductId = "32" Sporttype = "248" Bettype = "0" LeagueGroupID = "0" TicketType = "0"/>
				<ProductDetail ProductId = "32" Sporttype = "248" Bettype = "4298" LeagueGroupID = "0" TicketType = "0"/>
				<ProductDetail ProductId = "1" Sporttype = "0" Bettype = "0" LeagueGroupID = "0" TicketType = "0"/>
				<ProductDetail ProductId = "1" Sporttype = "1" Bettype = "0" LeagueGroupID = "42,74" TicketType = "0"/>
				<ProductDetail ProductId = "1" Sporttype = "1" Bettype = "0" LeagueGroupID = "113" TicketType = "0"/>
				<ProductDetail ProductId = "1" Sporttype = "2" Bettype = "0" LeagueGroupID = "42,74" TicketType = "0"/>
				<ProductDetail ProductId = "1" Sporttype = "2" Bettype = "0" LeagueGroupID = "113" TicketType = "0"/>
		</ROOT>	
*/
    
BEGIN
	SET NOCOUNT ON;

	CREATE TABLE #AgWinLoss(
		CustID			INT,
		TurnOver		MONEY,
		GrossComm		MONEY,
		MemberWinLost	MONEY,
		AgWinLost		MONEY,
		PlayerComm		MONEY,
		AgComm			MONEY
	);

	CREATE TABLE #GrossComm (CustId INT, GrossComm MONEY)

	CREATE TABLE #TmpCondSumWL(
		SportType	SMALLINT,
		BetType		INT,
		LeagueGroupID SMALLINT, 
		TicketType TINYINT
	);

	CREATE TABLE #matchInfo (matchID INT, SportType SMALLINT, LeagueGroupID SMALLINT)
	DECLARE @ExistingProductDetails TABLE (ProductId INT,Sporttype SMALLINT,Bettype INT, LeagueGroupID SMALLINT, TicketType TINYINT)
	DECLARE @isTest BIT = 0, @__ProductDetails XML;
	SELECT  @isTest = dbo.f_CheckSPVersion(@@PROCID);	

	SELECT @ProductIds = dbo.f_AddRelatedProducts(@ProductIds);
	SELECT @__ProductDetails = CONVERT(XML, @ProductDetails)

	DECLARE @SeparateSabaSport_Cutoff DATE 

	SELECT @SeparateSabaSport_Cutoff = CutoffDate
	FROM dbo.f_GetCutoffDate()
	WHERE TypeName = 'SabaSport'

	INSERT INTO @ExistingProductDetails(ProductId,Sporttype,Bettype,LeagueGroupID,TicketType)
	SELECT ProductId,Sporttype,Bettype,LeagueGroupID,TicketType
	FROM dbo.f_ProductDetail_ConditionSel(@ProductDetails, @__ProductDetails)

	; WITH cte AS 
	(
		SELECT f.SportType, f.BetType, x.LeagueGroupID, f.TicketType, f.ProductID
		FROM dbo.f_SumWinloss_ConditionSel(@ProductIds) f
		CROSS APPLY (SELECT CAST (val AS INT) LeagueGroupID FROM  strSplit(f.LeagueGroupID, ',') x) x
	)
	INSERT INTO #TmpCondSumWL(SportType, BetType, LeagueGroupID, TicketType) 
	SELECT f.SportType, f.BetType, f.LeagueGroupID, f.TicketType
	FROM cte f
		LEFT JOIN @ExistingProductDetails e ON f.ProductID = e.ProductId 
	WHERE e.ProductId IS NULL OR (e.Bettype = f.BetType AND e.Sporttype = f.SportType AND e.TicketType = f.TicketType AND e.LeagueGroupID = f.LeagueGroupID AND e.ProductID = f.ProductId)

	------Get @Srecommend
	DECLARE @Srecommend int, @mrecommend int;

	SELECT	@Srecommend =  Srecommend,
			@Mrecommend =  Mrecommend 
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

	--Avoid Parameter Sniffing
	DECLARE @FDate	SMALLDATETIME,
			@TDate	SMALLDATETIME,
			@CID	INT;

	SELECT	@FDate = @FromDate,
			@TDate = @ToDate,
			@CID = @custid;

	DECLARE @SportBettypeMatrix TABLE (BetType SMALLINT, RefTable TINYINT,  LeagueGroupID SMALLINT, TicketType TINYINT, SportType SMALLINT, ProductID INT);

	INSERT INTO @SportBettypeMatrix (BetType, RefTable, LeagueGroupID, ticketType, SportType, ProductID)
	SELECT f.BetType, f.RefTable, ISNULL(e.LeagueGroupID,0) AS LeagueGroupID, ISNULL(e.TicketType,0) AS TicketType, ISNULL(SportType,0) AS SportType, f.ProductID
	FROM dbo.f_SportBettypeMatrixByProduct_Sel(@ProductIds, @IsTest) f
		LEFT JOIN @ExistingProductDetails e ON e.ProductId = f.ProductID
	WHERE EXISTS(SELECT 1
				 WHERE e.ProductId IS NULL 
					OR 
						(
							e.Bettype = f.BetType 
							OR (
										e.Bettype = 0  AND  (e.ProductId = 1 OR  f.BetType NOT IN (SELECT g.Bettype FROM f_GetProductDetail() g WHERE g.ProductId <> 1) )
									)
						)
				 )

	IF @ToDate >= @BalanceUpDay
	BEGIN 
		IF @FromDate <= @MoveBetsDay
		BEGIN
			SET @FDate = DATEADD(DD, 1, @MoveBetsDay);
		END

		INSERT INTO #matchInfo(matchID, SportType, LeagueGroupID)
		SELECT m.matchid, m.SportType, l.LeagueGroupID
		FROM dbo.match m WITH(NOLOCK)
		LEFT JOIN   dbo.League l WITH(NOLOCK) ON m.leagueid = l.leagueid
		WHERE m.eventdate BETWEEN  @FDate AND @TDate AND m.sporttype IN (1,2,50) AND l.LeagueGroupID IN (42,74,108,113,122)

		; WITH cte_Bettrans AS 
		(		
			SELECT	b.CustID,
					b.apositiontaking,
					b.bettype,
					SUM(comm) AS comm,
					SUM(ABS(b.stake)) AS stake,
					SUM(winlost) AS winlost,
					SUM(actual_stake) AS actual_stake,
					SUM(awinlost) AS awinlost,
					SUM(playercomm) AS playercomm,
					CASE WHEN ( 
									(m.LeagueGroupID IN (42,74,108,113) AND m.sporttype = 1 ) 
										OR (m.LeagueGroupID IN (122, 42) AND m.sporttype = 2 )
										OR (m.LeagueGroupID = 42 AND m.sporttype = 50)
									) AND b.betdaqid <> -2 AND b.winlostdate >= @SeparateSabaSport_Cutoff THEN m.sporttype
					ELSE 0 END sporttype, 
					CASE WHEN ( 
									(m.LeagueGroupID IN (42,74,108,113) AND m.sporttype = 1 ) 
										OR (m.LeagueGroupID IN (122, 42) AND m.sporttype = 2 )
										OR (m.LeagueGroupID = 42 AND m.sporttype = 50)
									) AND b.betdaqid <> -2 AND b.winlostdate >= @SeparateSabaSport_Cutoff THEN m.LeagueGroupID
					ELSE 0 END LeagueGroupID,
					CASE WHEN b.betdaqid = -2 THEN 1 ELSE 0 END TicketType
			FROM	Bettrans b WITH(NOLOCK)
				LEFT JOIN	#matchInfo m ON b.matchid = m.matchid
			WHERE  b.recommend = @CID
				AND  b.winlostdate BETWEEN @FDate AND @TDate
				AND  b.statusID IN (111, 112, 113)
			GROUP BY b.CustID, b.apositiontaking, b.bettype, 
					CASE WHEN ( 
									(m.LeagueGroupID IN (42,74,108,113) AND m.sporttype = 1 ) 
										OR (m.LeagueGroupID IN (122, 42) AND m.sporttype = 2 )
										OR (m.LeagueGroupID = 42 AND m.sporttype = 50)
									) AND b.betdaqid <> -2 AND b.winlostdate >= @SeparateSabaSport_Cutoff THEN m.sporttype
					ELSE 0 END,
					CASE WHEN ( 
									(m.LeagueGroupID IN (42,74,108,113) AND m.sporttype = 1 ) 
										OR (m.LeagueGroupID IN (122, 42) AND m.sporttype = 2 )
										OR (m.LeagueGroupID = 42 AND m.sporttype = 50)
									) AND b.betdaqid <> -2 AND b.winlostdate >= @SeparateSabaSport_Cutoff THEN m.LeagueGroupID
					ELSE 0 END,
					CASE WHEN b.betdaqid = -2 THEN 1 ELSE 0 END 
		)

		INSERT INTO #AgWinLoss(CustID, TurnOver, GrossComm, MemberWinLost, AgWinLost, PlayerComm, AgComm)
		SELECT	CustID,
		   		SUM(ABS(b.stake)) AS TurnOver,
				SUM(CASE
						WHEN s.RefTable IN (1, 2) THEN 0
						WHEN apositiontaking = 1 THEN 0
						ELSE comm/(1 - apositiontaking)
					END) AS GrossComm,
				SUM(winlost - actual_stake) AS MemberWinLost,
				SUM(awinlost) AS AgWinLost,
				SUM(playercomm) AS PlayerComm,
				SUM(comm - playercomm) AS AgComm
		FROM cte_Bettrans b 
			INNER JOIN @SportBettypeMatrix s ON b.bettype = s.bettype AND (s.ProductID <> 1 OR (s.ProductID = 1 AND b.sporttype = s.SportType AND b.LeagueGroupID = s.LeagueGroupID AND b.TicketType = s.TicketType))
		GROUP BY CustID;

		IF EXISTS (SELECT 1 FROM @SportBettypeMatrix WHERE RefTable = 1) -- bettransRnG
		BEGIN
			INSERT INTO #GrossComm (CustId, GrossComm)
			SELECT b.CustId, SUM(b.BetStake * b.discount) AS GrossComm
			FROM dbo.bettransRnG b WITH (NOLOCK)
				INNER JOIN @SportBettypeMatrix s ON b.gameId = s.Bettype AND s.RefTable = 1
			WHERE b.recommend = @CID 
				AND b.winlostdate BETWEEN @FDate AND @TDate
				AND b.statusID IN (111, 112, 113)
			GROUP BY b.CustId
		END

		IF EXISTS (SELECT 1 FROM @SportBettypeMatrix WHERE RefTable = 2) -- bettransLC
		BEGIN
			INSERT INTO #GrossComm (CustId, GrossComm)
			SELECT b.CustId, SUM(b.NetStake * b.discount) AS GrossComm
			FROM dbo.bettransLC b WITH (NOLOCK)
				INNER JOIN @SportBettypeMatrix s ON b.gameId = s.Bettype AND s.RefTable = 2
			WHERE b.recommend = @CID 
				AND b.winlostdate BETWEEN @FDate AND @TDate
				AND b.statusID IN (111, 112, 113)
			GROUP BY b.CustId
		END

		IF EXISTS (SELECT 1 FROM #GrossComm)
		BEGIN
			UPDATE t
			SET t.GrossComm = ISNULL(t.GrossComm, 0) + ISNULL(c.GrossComm, 0)
			FROM #AgWinLoss t
				INNER JOIN (
					SELECT CustId, SUM(GrossComm) AS GrossComm FROM #GrossComm GROUP BY CustId
				) c ON t.CustId = c.CustId
		END
		
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

		INSERT INTO #AgWinLoss(CustID, TurnOver, GrossComm, MemberWinLost, AgWinLost, PlayerComm, AgComm)
		SELECT	CustID,
				SUM(ABS(TurnOver)) AS TurnOver,
				SUM(grosscomm) AS GrossComm,
				SUM(winlost) AS MemberWinLost,
				SUM(awinlost) AS AgWinLost,
				SUM(playercomm) AS PlayerComm,
				SUM(comm - playercomm) AS AgComm
		FROM  DBO.Sum_WinLoss b WITH(NOLOCK) 
			INNER JOIN #TmpCondSumWL t ON b.sporttype = t.sporttype AND b.bettype = t.bettype AND ISNULL(b.leagueGroupID,0) = t.LeagueGroupID AND ISNULL(b.ticketType,0) = t.TicketType
		WHERE recommend = @CID
			AND Winlostdate BETWEEN @FDate AND @TDate
			AND roleID = 1
		GROUP BY CustID;
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
		;WITH CTE_Winlostdate (winlostdate, sporttype, bettype, LeagueGroupID, TicketType) AS
		(
			SELECT @FDate AS winlostdate, SportType, BetType, LeagueGroupID, TicketType
			FROM #TmpCondSumWL
			UNION ALL
			SELECT DATEADD(DAY, 1, winlostdate), SportType, BetType, LeagueGroupID, TicketType
			FROM CTE_Winlostdate
			WHERE winlostdate < @TDate
		)	
		INSERT INTO #AgWinLoss(CustID, TurnOver, GrossComm, MemberWinLost, AgWinLost, PlayerComm, AgComm)
		SELECT	CustID,
				SUM(ABS(TurnOver)) AS TurnOver,
				SUM(grosscomm) AS GrossComm,
				SUM(winlost) AS MemberWinLost,
				SUM(awinlost) AS AgWinLost,
				SUM(playercomm) AS PlayerComm,
				SUM(comm - playercomm) AS AgComm
		FROM  bodb_Summary.dbo.Sum_WinLoss_Old b WITH(NOLOCK) 
			CROSS APPLY CTE_Winlostdate w
		WHERE b.winlostdate = w.winlostdate 
			AND recommend = @CustID 
			AND srecommend = @Srecommend   --- Add Srecommend, Mrecommend to get the index seek 
			AND mrecommend = @mrecommend
			AND roleID = 1
			AND b.sporttype = w.sporttype
			AND b.bettype = w.bettype 
			AND ISNULL(b.leagueGroupID,0) = w.LeagueGroupID
			AND ISNULL(b.ticketType,0) = w.TicketType
		GROUP BY CustID
		OPTION (MAXRECURSION 0)
	END

	SELECT	w.CustID AS CustId,
			c.UserName AS CustName,
			SUM(TurnOver) AS Turnover,
			SUM(GrossComm) AS GrossComm,
			SUM(MemberWinLost) AS MemberWinLoss,
			SUM(playercomm) AS MemberComm,
			SUM(AgWinLost) AS AgWinLoss,
			SUM(AgComm) AS AgComm
	FROM #AgWinLoss w 
		INNER JOIN dbo.custInfo c WITH(NOLOCK) ON w.CustID = c.CustID 
	GROUP BY w.CustID, c.UserName
	ORDER BY c.Username;

	DROP TABLE #AgWinLoss
	DROP TABLE #GrossComm
	DROP TABLE #TmpCondSumWL

	SET NOCOUNT OFF;
END
GO