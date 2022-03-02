/*<info serverAlias="DBAGE-bodb02" executers="bodbDownlineNet,bodbDownlineNetView" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Age_Rpt_WinLoss_Master]  
	@CustID 		INT, --srecommend
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

	+ Note: Review index=IX_srecommend when modifying this SP   
*/  
 
BEGIN
	SET NOCOUNT ON;
 
	CREATE TABLE #SAgWinLoss(
		CustID		INT,
		TurnOver	MONEY,
		GrossComm	MONEY,
		MAgTotal	MONEY,
		SAgWinlost	MONEY,
		Comm		MONEY
	);

	CREATE TABLE #GrossComm (CustId INT, GrossComm MONEY)
  
	CREATE TABLE #TmpCondSumWL(
		SportType		INT,
		BetType			INT,
		LeagueGroupID	SMALLINT,
		TicketType		TINYINT
	);
	DECLARE @ExistingProductDetails TABLE (ProductId INT,Sporttype INT,Bettype INT,LeagueGroupID SMALLINT, TicketType TINYINT)
	DECLARE @isTest BIT = 0, @__ProductDetails XML;
	SELECT  @isTest = dbo.f_CheckSPVersion(@@PROCID);	

	DECLARE @SeparateSabaSport_Cutoff DATE 

	SELECT @SeparateSabaSport_Cutoff = CutoffDate
	FROM dbo.f_GetCutoffDate()
	WHERE TypeName = 'SabaSport'

	SELECT @ProductIds = dbo.f_AddRelatedProducts(@ProductIds);
	SELECT @__ProductDetails = CONVERT(XML, @ProductDetails)

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

	-----Get Special Super to hide data of them before specific date 
	DECLARE @IsHide BIT = 0;

	IF EXISTS (	SELECT 1
				FROM dbo.f_SpecialSuper()
				WHERE Srecommend = @CustId)
	BEGIN
		SELECT @IsHide = 1;
	END

	----Get Account Login to detect Interal or not
	DECLARE @LoginName NVARCHAR(128);
	SELECT @LoginName = SUSER_NAME();

	--Avoid Parameter Sniffing for bettrans and sum_winloss
	DECLARE @FDate	SMALLDATETIME,
			@TDate	SMALLDATETIME,
			@CID	INT;
			    	    
	SELECT	@FDate = @FromDate,
			@TDate = @ToDate,
			@CID = @custid;

	DECLARE @SportBettypeMatrix TABLE (BetType SMALLINT, RefTable TINYINT, SportType SMALLINT, 	LeagueGroupID SMALLINT, TicketType TINYINT, ProductID INT);

	INSERT INTO @SportBettypeMatrix (BetType, RefTable, SportType, LeagueGroupID, TicketType, ProductID)
	SELECT f.BetType, f.RefTable , ISNULL(e.SportType,0), ISNULL(e.LeagueGroupID,0), ISNULL(e.TicketType,0), f.ProductID
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

		;WITH cte_bettrans AS
		(
			SELECT	b.MRecommend,
					b.tpositiontaking,
					b.bettype,
					CASE WHEN b.betdaqid = -2 THEN 1 ELSE 0 END TicketType, 
					SUM(ABS(b.stake)) AS stake,
					SUM(scomm) AS scomm,
					SUM(winlost) AS winlost,
					SUM(actual_stake) AS actual_stake,
					SUM(playercomm) AS playercomm,
					SUM(awinlost) AS awinlost,
					SUM(comm) AS comm,
					SUM(acomm) AS acomm,
					SUM(mwinlost) AS mwinlost,
					SUM(swinlost) AS swinlost,
					CASE WHEN ( 
									(l.LeagueGroupID IN (42,74,108,113) AND m.sporttype = 1 ) 
										OR (l.LeagueGroupID IN (122, 42) AND m.sporttype = 2 )
										OR (l.LeagueGroupID = 42 AND m.sporttype = 50)
									) AND b.betdaqid <> -2 AND b.winlostdate >= @SeparateSabaSport_Cutoff  THEN m.sporttype
					ELSE 0 END sporttype, 
					CASE WHEN ( 
									(l.LeagueGroupID IN (42,74,108,113) AND m.sporttype = 1 ) 
										OR (l.LeagueGroupID IN (122, 42) AND m.sporttype = 2 )
										OR (l.LeagueGroupID = 42 AND m.sporttype = 50)
									) AND b.betdaqid <> -2 AND b.winlostdate >= @SeparateSabaSport_Cutoff THEN l.LeagueGroupID
					ELSE 0 END LeagueGroupID
			FROM		dbo.bettrans b WITH (NOLOCK, index = IX_srecommend)  
			LEFT JOIN	dbo.match m WITH(NOLOCK)  ON b.matchid = m.matchid
			LEFT JOIN   dbo.League l WITH(NOLOCK) ON m.leagueid = l.leagueid
			WHERE SRecommend = @CID 
				AND  winlostdate BETWEEN @FDate AND @TDate 
				AND  b.statusID IN (111, 112, 113)  
			GROUP BY MRecommend, b.tpositiontaking, b.bettype, CASE WHEN b.betdaqid = -2 THEN 1 ELSE 0 END ,
					CASE WHEN ( 
									(l.LeagueGroupID IN (42,74,108,113) AND m.sporttype = 1 ) 
										OR (l.LeagueGroupID IN (122, 42) AND m.sporttype = 2 )
										OR (l.LeagueGroupID = 42 AND m.sporttype = 50)
									) AND b.betdaqid <> -2 AND b.winlostdate >= @SeparateSabaSport_Cutoff THEN m.sporttype
					ELSE 0 END, 
					CASE WHEN ( 
									(l.LeagueGroupID IN (42,74,108,113) AND m.sporttype = 1 ) 
										OR (l.LeagueGroupID IN (122, 42) AND m.sporttype = 2 )
										OR (l.LeagueGroupID = 42 AND m.sporttype = 50)
									) AND b.betdaqid <> -2 AND b.winlostdate >= @SeparateSabaSport_Cutoff THEN l.LeagueGroupID
					ELSE 0 END
			)
		INSERT INTO #SAgWinLoss(CustID, TurnOver, GrossComm, MAgTotal, SAgWinlost, Comm)
		SELECT  mrecommend AS CustID,
				SUM(ABS(b.stake)) AS TurnOver,
				SUM(CASE
						WHEN s.RefTable IN (1, 2) THEN 0
						WHEN tpositiontaking = 1 THEN 0
						ELSE scomm/(1 - tpositiontaking)
					END) AS GrossComm,
				SUM(mwinlost + awinlost + acomm + winlost - actual_stake) AS MAgTotal,
				SUM(swinlost) AS SAgWinlost,
				ISNULL(SUM(scomm), 0) - ISNULL(SUM(acomm), 0) AS Comm
		FROM cte_bettrans b
			INNER JOIN @SportBettypeMatrix s ON b.bettype = s.bettype AND (s.ProductID <> 1 OR (s.ProductID = 1 AND b.sporttype = s.SportType AND b.LeagueGroupID = s.LeagueGroupID AND b.TicketType = s.TicketType))
		GROUP BY mrecommend;

		IF EXISTS (SELECT 1 FROM @SportBettypeMatrix WHERE RefTable = 1) -- bettransRnG
		BEGIN
			INSERT INTO #GrossComm (CustId, GrossComm)
			SELECT b.mrecommend AS CustId, SUM(b.BetStake * b.sdiscount) AS GrossComm
			FROM dbo.bettransRnG b WITH (NOLOCK)
				INNER JOIN @SportBettypeMatrix s ON b.gameId = s.Bettype AND s.RefTable = 1
			WHERE b.srecommend = @CID 
				AND b.winlostdate BETWEEN @FDate AND @TDate
				AND b.statusID IN (111, 112, 113)
			GROUP BY b.mrecommend
		END

		IF EXISTS (SELECT 1 FROM @SportBettypeMatrix WHERE RefTable = 2) -- bettransLC
		BEGIN
			INSERT INTO #GrossComm (CustId, GrossComm)
			SELECT b.mrecommend AS CustId, SUM(b.NetStake * b.sdiscount) AS GrossComm
			FROM dbo.bettransLC b WITH (NOLOCK)
				INNER JOIN @SportBettypeMatrix s ON b.gameId = s.Bettype AND s.RefTable = 2
			WHERE b.srecommend = @CID 
				AND b.winlostdate BETWEEN @FDate AND @TDate
				AND b.statusID IN (111, 112, 113)
			GROUP BY b.mrecommend
		END

		IF EXISTS (SELECT 1 FROM #GrossComm)
		BEGIN
			UPDATE t
			SET t.GrossComm = ISNULL(t.GrossComm, 0) + ISNULL(c.GrossComm, 0)
			FROM #SAgWinLoss t
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
  
		INSERT INTO #SAgWinLoss(CustID, TurnOver, GrossComm, MAgTotal, SAgWinlost, Comm)
		SELECT  CustID,
				SUM(ABS(TurnOver)) AS TurnOver,
				SUM(ISNULL(grosscomm, 0)) AS GrossComm,
				SUM(mwinlost + awinlost + acomm + winlost) AS MAgTotal,
				SUM(swinlost) AS SAgWinlost,
				ISNULL(SUM(scomm), 0) - ISNULL(SUM(acomm), 0) AS Comm
		FROM dbo.sum_winloss b WITH (NOLOCK) 
			INNER JOIN #TmpCondSumWL t ON b.sporttype = t.sporttype AND b.bettype = t.bettype  AND b.leagueGroupID = t.LeagueGroupID AND b.ticketType = t.TicketType
		WHERE winlostdate BETWEEN @FDate AND @TDate
			AND Srecommend = @CID
			AND roleid = 3  
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
		;WITH CTE_Winlostdate (winlostdate, sporttype, bettype, LeagueGroupID, TicketType) AS
		(
			SELECT @FDate AS winlostdate, SportType, BetType, LeagueGroupID, TicketType
			FROM #TmpCondSumWL
			UNION ALL
			SELECT DATEADD(DAY, 1, winlostdate), SportType, BetType, LeagueGroupID, TicketType
			FROM CTE_Winlostdate
			WHERE winlostdate < @TDate
		)		
		INSERT INTO #SAgWinLoss(CustID, TurnOver, GrossComm, MAgTotal, SAgWinlost, Comm)
		SELECT  CustID,
				SUM(ABS(TurnOver)) AS TurnOver,
				SUM(ISNULL(grosscomm,0)) AS GrossComm,
				SUM(mwinlost + awinlost + acomm + winlost) AS MAgTotal,
				SUM(swinlost) AS SAgWinlost,
				ISNULL(SUM(scomm), 0) - ISNULL(SUM(acomm), 0) AS Comm
		FROM bodb_Summary.dbo.Sum_WinLoss_Old b WITH(NOLOCK) 
			CROSS APPLY CTE_Winlostdate w
		WHERE b.winlostdate = w.winlostdate 
			AND SRecommend = @CustID  
			AND mrecommend = mrecommend
			AND recommend = recommend
			AND RoleID = 3  
			AND b.sporttype = w.sporttype
			AND b.bettype = w.bettype
			AND b.leagueGroupID = w.LeagueGroupID
			AND b.ticketType = w.TicketType
		GROUP BY CustID
		OPTION (MAXRECURSION 0)
	END  
  
	SELECT	w.CustID AS CustId,
			c.UserName AS CustName,
			SUM(TurnOver) AS Turnover,
			SUM(GrossComm) AS GrossComm,
			SUM(MAgTotal) AS MAgTotal,
			SUM(SAgWinlost) AS SAgWinLoss,
			SUM(Comm) AS SAgComm  
	FROM #SAgWinLoss w 
		INNER JOIN Customer c WITH(NOLOCK) ON w.CustID = c.CustID   
	GROUP BY w.CustID, c.UserName  
	ORDER BY c.Username;

	DROP TABLE #GrossComm
	DROP TABLE #SAgWinLoss
	DROP TABLE #TmpCondSumWL

	SET NOCOUNT OFF;
END
GO