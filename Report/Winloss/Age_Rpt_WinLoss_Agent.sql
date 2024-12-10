/*<info serverAlias="DBAGE-bodb02" executers="wsv_alp,wsv_alpv" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Age_Rpt_WinLoss_Agent]
	@CustID 		INT, --mrecommend
	@FromDate 		SMALLDATETIME,
	@ToDate 		SMALLDATETIME,
	@ProductIds		VARCHAR(MAX),
	@ProductDetails NVARCHAR(MAX) = 'All',
	@MoveBetsDay	SMALLDATETIME,
	@BalanceUpDay	SMALLDATETIME	
AS

/*
    Created:20240219@Bobby
    Task: Alpha Winloss report - Apply CDC bettrans_compact
    DB: DBAGE/bodb_Age
	Original: Age_Rpt_WinLoss_Agent
    
	Revisions:
		- 20161111@Paul: Microsite for Report - [Redmine: #66991]
		- 20170622@Percy: Combine Betradar Virtual Sports with Virtual Sports [RedmineID: #78339]
		- 20180518@Sophia: WC2018 - Enhance Performance at Sum_winloss_old table [Redmind: #91107]
		- 20180914@Percy: Poker Games - Modify GrossComm [RedmineID: #101550]
		- 20181003@Helen: Modify code to adapt indexes changed on DB053 [Redmine:101405]
		- 20190826@Percy: Remove inactive products [RedmineID: #118699]
		- 20200909@Malcolm : Report Enhancement for Jackpot Product [RedmineID : #139575]
		- 20211122@Percy: Enhance gross comm formula [RedmineID: #164479]
		- 20220208@Danny: Separate Saba Sport Performance [Redmine: #167177]
		- 20221207@Eddie: Add New SABA ESports PinGoal [RedmineID: #181383]
		- 20230104@Bobby: Enhance GrossComm figure [RedmineID: #182155]
		- 20230328@Malcolm: Add firstname, lastname [RedmineId: #185313]   
		- 20230630@Lewis: Add Saba Tennis [RedmineID: #190459]
		- 20240125@Lewis: Show Archived User [RedmineID: #199410]
		- 20240306@Lewis: Add Virtual Ice Hockey [RedmineID: #201129]
		- 20240515@Lewis: Add SABA Kabaddi [RedmineID: #203763]
		- 20240424@Lewis: Change old sql account [Redmine: #204021]
		- 20241205@Lewis: Change data source bettrans_compact [Redmine: #214836]
	
	Param's Explanation:
	 @ProductDetails:		
			N'<ROOT>
                <ProductDetail ProductId="32" Sporttype="248" Bettype="0" LeagueGroupId="0" TicketType="0"/>
                <ProductDetail ProductId="32" Sporttype="248" Bettype="4297" LeagueGroupId="0" TicketType="0"/>
                <ProductDetail ProductId="32" Sporttype="248" Bettype="4298" LeagueGroupId="0" TicketType="0"/>
                <ProductDetail ProductId="45" Sporttype="243" Bettype="0" LeagueGroupId="0" TicketType="0"/>
                <ProductDetail ProductId="45" Sporttype="243" Bettype="3150" LeagueGroupId="0" TicketType="0"/>
                <ProductDetail ProductId="36" Sporttype="247" Bettype="0" LeagueGroupId="0" TicketType="0"/>
                <ProductDetail ProductId="36" Sporttype="247" Bettype="4599" LeagueGroupId="0" TicketType="0"/>
                <ProductDetail ProductId="36" Sporttype="247" Bettype="4600" LeagueGroupId="0" TicketType="0"/>
                <ProductDetail ProductId="21" Sporttype="211" Bettype="0" LeagueGroupId="0" TicketType="0"/>
                <ProductDetail ProductId="21" Sporttype="211" Bettype="2499" LeagueGroupId="0" TicketType="0"/>
                <ProductDetail ProductId="1" Sporttype="0" Bettype="0" LeagueGroupId="0" TicketType="0"/>
                <ProductDetail ProductId="1" Sporttype="0" Bettype="0" LeagueGroupId="0" TicketType="1"/>
                <ProductDetail ProductId="1" Sporttype="1" Bettype="0" LeagueGroupId="42" TicketType="0"/>
                <ProductDetail ProductId="1" Sporttype="1" Bettype="0" LeagueGroupId="74" TicketType="0"/>
                <ProductDetail ProductId="1" Sporttype="1" Bettype="0" LeagueGroupId="108" TicketType="0"/>
                <ProductDetail ProductId="1" Sporttype="2" Bettype="0" LeagueGroupId="42" TicketType="0"/>
                <ProductDetail ProductId="1" Sporttype="50" Bettype="0" LeagueGroupId="42" TicketType="0"/>
                <ProductDetail ProductId="1" Sporttype="1" Bettype="0" LeagueGroupId="113" TicketType="0"/>
                <ProductDetail ProductId="1" Sporttype="2" Bettype="0" LeagueGroupId="122" TicketType="0"/>
             </ROOT>'
*/

BEGIN
	SET NOCOUNT ON;

	DROP TABLE IF EXISTS #GrossComm;
	DROP TABLE IF EXISTS #MAgWinLoss;
	DROP TABLE IF EXISTS #TmpCondSumWL;

	CREATE TABLE #MAgWinLoss(
		CustID		INT,
		TurnOver	MONEY,
		GrossComm	MONEY,
		AgTotal		MONEY,
		MAgWinlost	MONEY,
		Comm		MONEY
	);

	CREATE TABLE #GrossComm (CustId INT, GrossComm MONEY)

	CREATE TABLE #TmpCondSumWL(
		SportType		SMALLINT,
		BetType			INT,
		LeagueGroupID	SMALLINT,
		TicketType		TINYINT
	);
	
	DECLARE @ExistingProductDetails TABLE (ProductId INT,Sporttype SMALLINT, Bettype INT,LeagueGroupID SMALLINT, TicketType TINYINT)
	DECLARE @isTest BIT = 0, @__ProductDetails XML;
	SELECT  @isTest = dbo.f_CheckSPVersion(@@PROCID);

	DECLARE @SeparateSabaSport_Cutoff SMALLDATETIME 

	SELECT @SeparateSabaSport_Cutoff = CutoffDate
	FROM dbo.f_GetCutoffDate()
	WHERE TypeName = 'SabaSport'

	SELECT @ProductIds = dbo.f_AddRelatedProducts(@ProductIds);
	SELECT @__ProductDetails = CONVERT(XML, @ProductDetails)

	INSERT INTO @ExistingProductDetails(ProductId,Sporttype,Bettype,LeagueGroupID,TicketType)
	SELECT ProductId,Sporttype,Bettype,LeagueGroupID,TicketType
	FROM dbo.f_ProductDetail_ConditionSel(@ProductDetails, @__ProductDetails)

	IF (@FromDate <= @MoveBetsDay)
	BEGIN
		INSERT INTO #TmpCondSumWL(SportType, BetType, LeagueGroupID, TicketType) 
		SELECT f.SportType, f.BetType, f.LeagueGroupID, f.TicketType
		FROM dbo.f_SumWinloss_ConditionSel(@ProductIds) f
			LEFT JOIN @ExistingProductDetails e ON f.ProductID = e.ProductId 
		WHERE e.ProductId IS NULL OR (e.Bettype = f.BetType AND e.Sporttype = f.SportType AND e.TicketType = f.TicketType AND e.LeagueGroupID = f.LeagueGroupID AND e.ProductID = f.ProductId)
	END

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

	DECLARE @SportBettypeMatrix TABLE (BetType SMALLINT, RefTable TINYINT, SportType SMALLINT, LeagueGroupID SMALLINT, ticketType TINYINT, ProductID INT);

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

		--TODO: bettrans_compact
		;WITH CTE_Agent AS (
			SELECT custid
			FROM dbo.Customer WITH(NOLOCK)
			WHERE mrecommend = @CID
				AND RoleId = 2
		)
		INSERT INTO #MAgWinLoss(CustID, TurnOver, GrossComm, AgTotal, MAgWinlost, Comm)
		SELECT	b.CustID,
			SUM(TurnOver) AS TurnOver,
			SUM(GrossComm) AS GrossComm,
			SUM(winlost+ awinlost+ comm) AS AgTotal,
			SUM(mwinlost) AS MAgWinlost,
			SUM(acomm-comm) AS Comm
		FROM bodb_AGE.dbo.bettrans_compact b WITH(NOLOCK)
			INNER JOIN CTE_Agent m ON m.custid = b.custid
			INNER JOIN @SportBettypeMatrix s ON b.bettype = s.bettype 
				AND (s.ProductID <> 1 OR (s.ProductID = 1 AND b.sporttype = s.SportType AND b.LeagueGroupID = s.LeagueGroupID AND b.TicketType = s.TicketType))
		WHERE 
			b.winlostdate BETWEEN @FDate AND @TDate
		GROUP BY b.custid;

		IF EXISTS (SELECT 1 FROM @SportBettypeMatrix WHERE RefTable = 1) -- bettransRnG
		BEGIN
			INSERT INTO #GrossComm (CustId, GrossComm)
			SELECT b.recommend AS CustId, SUM(b.BetStake * b.adiscount) AS GrossComm
			FROM dbo.bettransRnG b WITH (NOLOCK)
				INNER JOIN @SportBettypeMatrix s ON b.gameId = s.Bettype AND s.RefTable = 1
			WHERE b.mrecommend = @CID 
				AND b.winlostdate BETWEEN @FDate AND @TDate
				AND b.statusID IN (111, 112, 113)
			GROUP BY b.recommend
		END

		IF EXISTS (SELECT 1 FROM @SportBettypeMatrix WHERE RefTable = 2) -- bettransLC
		BEGIN
			INSERT INTO #GrossComm (CustId, GrossComm)
			SELECT b.recommend AS CustId, SUM(b.NetStake * b.adiscount) AS GrossComm
			FROM dbo.bettransLC b WITH (NOLOCK)
				INNER JOIN @SportBettypeMatrix s ON b.gameId = s.Bettype AND s.RefTable = 2
			WHERE b.mrecommend = @CID 
				AND b.winlostdate BETWEEN @FDate AND @TDate
				AND b.statusID IN (111, 112, 113)
			GROUP BY b.recommend
		END

		IF EXISTS (SELECT 1 FROM #GrossComm)
		BEGIN
			UPDATE t
			SET t.GrossComm = ISNULL(t.GrossComm, 0) + ISNULL(c.GrossComm, 0)
			FROM #MAgWinLoss t
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
		
		INSERT INTO #MAgWinLoss(CustID, TurnOver, GrossComm, AgTotal, MAgWinlost, Comm)
		SELECT	CustID,
				SUM(ABS(TurnOver)) AS TurnOver,
				SUM(grosscomm) AS GrossComm,
				ISNULL(SUM(winlost),0) + ISNULL(SUM(awinlost), 0) + ISNULL(SUM(comm), 0) AS AgTotal,
				SUM(mwinlost) AS MAgWinlost,
				ISNULL(SUM(acomm), 0) - ISNULL(SUM(comm), 0) AS Comm
		FROM  dbo.sum_winloss b WITH (NOLOCK) 
			INNER JOIN #TmpCondSumWL t ON b.sporttype = t.sporttype AND b.bettype = t.bettype AND ISNULL(b.leagueGroupID,0) = t.LeagueGroupID AND ISNULL(b.ticketType,0) = t.TicketType
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
			
				

		-- using cte to remove predicate when seek on sum_winloss_old
		;WITH CTE_Winlostdate (winlostdate, sporttype, bettype, LeagueGroupID, ticketType) AS
		(
			SELECT @FDate AS winlostdate, SportType, BetType, LeagueGroupID, TicketType
			FROM #TmpCondSumWL
			UNION ALL
			SELECT DATEADD(DAY, 1, winlostdate), SportType, BetType, LeagueGroupID, TicketType
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
			AND ISNULL(b.leagueGroupID,0) = w.LeagueGroupID
			AND ISNULL(b.ticketType,0) = w.ticketType
		GROUP BY CustID
		OPTION (MAXRECURSION 0)
	END

	SELECT	c.CustID AS CustId,
			c.UserName AS CustName,
			c.FirstName,
			c.LastName,
			SUM(TurnOver) AS Turnover,
			SUM(GrossComm) AS GrossComm,
			SUM(AgTotal) AS AgTotal,
			SUM(MAgWinlost) AS MAgWinLoss,
			SUM(Comm) AS MAgComm
	FROM  #MAgWinLoss w 
		LEFT JOIN Customer c WITH(NOLOCK) ON w.CustID = c.CustID 
	GROUP BY c.CustID, c.UserName, c.FirstName, c.LastName
	ORDER BY IIF(c.Username IS NULL,1,0),c.Username;

	SET NOCOUNT OFF;
END
GO