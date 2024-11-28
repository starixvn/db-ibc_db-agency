/*<info serverAlias="DBAGE-bodb02" executers="wsv_alp,wsv_alpv" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Age_Rpt_WinLossByProduct_Member]
	@CustID 		INT,
	@FromDate 		SMALLDATETIME,
	@ToDate			SMALLDATETIME,	
	@BalanceUpDay	SMALLDATETIME, 
	@MoveBetsDay	SMALLDATETIME,
	@ProductIds		VARCHAR(MAX),
	@ProductDetails NVARCHAR(MAX) = 'All'
AS

/*
	Created: 
	Task: 
	DB: DBAGE.bodb02
	
	Revisions:
		- 20161224@Paul: Create new [RedmineID: #70450]
		- 20170622@Percy: Combine Betradar Virtual Sports with Virtual Sports [RedmineID: #78339]
		- 20180419@Alvin: Combine Macau Games and Pragmatic [RedmineID: #92647]
		- 20180914@Percy: Poker Games - Modify GrossComm [RedmineID: #101550]
		- 20190826@Percy: Remove inactive products [RedmineID: #118699]
		- 20191029@Percy: Integrate Spadegaming [RedmineID: #122353]
		- 20200622@Sol: Archive VSRaceInfo - changed to use VSRaceInfo14 [RedmineID: #135963]
		- 20200810@Sophia: Exclude these Products: Pragmatic, Card Club, Spadegaming of of Macau Games [Redmine: #137767]
		- 20200909@Malcolm : Report Enhancement for Jackpot Product [RedmineID : #139575]
		- 20201202@Malcolm: Separate Bet Types - MMR Odds [RedmineId : #146159]
		- 20201124@Malcolm: Show sport type name for Virtual Sports 3 [redmine: #131375]
		- 20211122@Percy: Enhance gross comm formula [RedmineID: #164479]
		- 20220208@Danny: Separate Saba Sport Performance [Redmine: #167177]
		- 20221208@Eddie: Add New SABA ESports PinGoal [RedmineID: #181383]
		- 20221229@Bobby: Enhance GrossComm figure [RedmineID: #182155]
		- 20230630@Lewis: Add Saba Tennis [RedmineID: #190459]
		- 20240315@Lewis: Add parlay vs4 10449 [RedmineID: #198621]
		- 20240306@Lewis: Add Virtual Ice Hockey [RedmineID: #201129]
		- 20240515@Lewis: Add SABA Kabaddi [RedmineID: #203763]
		- 20240711@Lewis: Add VS5 - EventType = 5 [RedmineID: #206527]
	
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

	CREATE TABLE #AgWinLoss(
		ProductID		TINYINT,
		bettype			INT, 
		SportType		SMALLINT,
		liveindicator	INT,
		GrossComm		MONEY,
		Turnover		MONEY, 
		MemberWinLoss	MONEY, 
		AgWinLoss		MONEY, 
		MemberComm		MONEY, 
		AgComm			MONEY, 
		NumberOfTickets INT,
		IsMMR			BIT,
		DateRange		TINYINT -- 1: bettrans, 2: bettrans14
	);

	CREATE TABLE #GrossComm (ProductID TINYINT, bettype INT, GrossComm MONEY)

	DECLARE @ExistingProductDetails TABLE (ProductId INT,Sporttype SMALLINT,Bettype INT, LeagueGroupID SMALLINT, ticketType TINYINT)
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

	CREATE TABLE #SportBettype (ProductID TINYINT, Bettype SMALLINT, RefTable TINYINT, GroupTypeId INT, SportType SMALLINT, EventType TINYINT, LeagueGroupID SMALLINT, ticketType TINYINT, sporttype_filter SMALLINT);

	INSERT INTO #SportBettype (ProductID, Bettype, RefTable, GroupTypeId, SportType, EventType, LeagueGroupID, ticketType, sporttype_filter)
	SELECT ISNULL(p.GroupProductId, f.ProductID), f.Bettype, f.RefTable, f.Bettype, s.SportType, f.EventType, ISNULL(e.LeagueGroupID,0), ISNULL(e.ticketType,0), ISNULL(e.Sporttype,0) 
	FROM dbo.f_SportBettypeMatrixByProduct_Sel (@ProductIds, @isTest) f
		LEFT JOIN dbo.SportBettypeMatrix s WITH(NOLOCK)
			ON f.ProductID = s.ProductID AND f.BetType = s.BetType AND s.ProductID IN (23)
		LEFT JOIN dbo.f_GroupProduct() p ON f.ProductID = p.ProductId
		LEFT JOIN @ExistingProductDetails e ON e.ProductId = f.ProductID 
	WHERE f.bettype NOT IN (2799,10449,11099) -- Mix parlay of BRVS
		AND EXISTS(SELECT 1
				   WHERE e.ProductId IS NULL 
					OR 
						(
							e.Bettype = f.BetType 
							OR (e.Bettype = 0 AND f.BetType NOT IN (SELECT g.Bettype FROM f_GetProductDetail() g))
						)
				  )

	UPDATE s
	SET GroupTypeId = f.GroupTypeId
	FROM #SportBettype s
		INNER JOIN dbo.f_GroupBettype() f ON s.Bettype = f.Bettype;

	CREATE CLUSTERED INDEX ix_SportBettype_cl ON #SportBettype(Bettype);

	DECLARE @FDate SMALLDATETIME, @TDate SMALLDATETIME;

	SELECT  @FDate = @FromDate, @TDate = @ToDate;

	IF @ToDate >= @BalanceUpDay 
	BEGIN
		IF @ToDate > @MoveBetsDay
		BEGIN
			IF @FromDate <= @MoveBetsDay
			BEGIN
				SET @FDate = DATEADD(DD, 1, @MoveBetsDay);
			END

			; WITH cte_bettrans AS
			(
				SELECT  
					s.ProductID,
					s.GroupTypeId,
					CASE 
						WHEN s.ProductID = 5 AND s.EventType = 1 THEN ISNULL(m5.sporttype, b.matchid)
						WHEN s.ProductID = 22 THEN s.SportType
						WHEN s.ProductID = 23 THEN s.SportType
					END AS SportType,
					CASE s.ProductID
						WHEN 3 THEN b.liveindicator
						ELSE 0 
					END AS liveindicator,
					CASE WHEN b.bettype IN (1, 3, 7, 8) AND b.oddstype = 6 THEN 1 ELSE 0 END AS IsMMR,
					SUM(CASE
							WHEN s.RefTable IN (1, 2) THEN 0
							WHEN apositiontaking = 1 THEN 0
							ELSE comm / (1 - apositiontaking)
						END) AS GrossComm,
					SUM(ABS(stake)) stake,
					SUM(awinlost) awinlost, 
					SUM(playercomm) playercomm, 
					SUM(winlost) winlost, 
					SUM(actual_stake) actual_stake,
					SUM(comm) comm,
					COUNT(1) AS NumberOfTickets
				FROM dbo.bettrans b WITH(NOLOCK)
					LEFT JOIN dbo.match m WITH(NOLOCK) ON b.matchid = m.matchid AND m.eventdate = b.winlostdate AND m.sporttype IN (1,2,50,43,5,4,47)
					LEFT JOIN (
						SELECT LeagueGroupID, leagueid
						FROM dbo.League l WITH(NOLOCK) WHERE l.LeagueGroupID IN (42,74,108,113,122,151)
					) AS l  ON m.leagueid = l.leagueid
					OUTER APPLY (
						SELECT CASE WHEN ( 
									(l.LeagueGroupID IN (42,74,108,113) AND m.sporttype = 1 ) 
										OR (l.LeagueGroupID IN (122, 42) AND m.sporttype = 2 )
										OR (l.LeagueGroupID = 42 AND m.sporttype = 50)
										OR (l.LeagueGroupID = 42 AND m.sporttype = 5) --SabaTennis
										OR (l.LeagueGroupID = 42 AND m.sporttype = 4) --Virtual Ice Hockey
										OR (l.LeagueGroupID = 42 AND m.sporttype = 47) --SABA Kabaddi
										OR (l.LeagueGroupID = 151 AND m.sporttype = 43)
									) AND b.betdaqid <> -2 AND b.winlostdate >= @SeparateSabaSport_Cutoff THEN m.sporttype
						ELSE 0 END sporttype_filter, 
						CASE WHEN ( 
									(l.LeagueGroupID IN (42,74,108,113) AND m.sporttype = 1 ) 
										OR (l.LeagueGroupID IN (122, 42) AND m.sporttype = 2 )
										OR (l.LeagueGroupID = 42 AND m.sporttype = 50)
										OR (l.LeagueGroupID = 42 AND m.sporttype = 5) --SabaTennis
										OR (l.LeagueGroupID = 42 AND m.sporttype = 4) --Virtual Ice Hockey
										OR (l.LeagueGroupID = 42 AND m.sporttype = 47) --SABA Kabaddi
										OR (l.LeagueGroupID = 151 AND m.sporttype = 43)
									) AND b.betdaqid <> -2 AND b.winlostdate >= @SeparateSabaSport_Cutoff THEN l.LeagueGroupID
						ELSE 0 END LeagueGroupID,
						CASE WHEN b.betdaqid = -2 THEN 1 ELSE 0 END TicketType
					) AS et
					INNER JOIN #SportBettype s ON b.bettype = s.Bettype 
						AND (s.ProductID <> 5 OR s.EventType NOT IN (3,5)) AND (s.ProductID <> 1 OR (s.ProductID = 1 AND et.sporttype_filter = s.sporttype_filter AND et.LeagueGroupID = s.LeagueGroupID AND et.TicketType = s.TicketType))
					LEFT JOIN dbo.match m5 WITH(NOLOCK) ON b.matchid = m5.matchid AND s.ProductID = 5 AND s.EventType = 1
				WHERE winlostdate BETWEEN @FDate AND @TDate
					AND statusID IN (111, 112, 113)
					AND recommend = @custid
				GROUP BY	
					s.ProductID,
					s.GroupTypeId,
					CASE 
						WHEN s.ProductID = 5 AND s.EventType = 1 THEN ISNULL(m5.sporttype, b.matchid)
						WHEN s.ProductID = 22 THEN s.SportType
						WHEN s.ProductID = 23 THEN s.SportType
					END,
					CASE s.ProductID
						WHEN 3 THEN b.liveindicator
						ELSE 0 
					END,
					CASE WHEN b.bettype IN (1, 3, 7, 8) AND b.oddstype = 6 THEN 1 ELSE 0 END
			)
			INSERT INTO #AgWinLoss(ProductID, bettype, SportType, liveindicator, IsMMR, GrossComm, Turnover, MemberWinLoss, AgWinLoss, MemberComm, AgComm, NumberOfTickets, DateRange)
			SELECT	
				b.ProductID,
				b.GroupTypeId,
				b.SportType,
				b.liveindicator,
				b.IsMMR,
				SUM(GrossComm) AS GrossComm,
				SUM(ABS(stake)) AS Turnover,
				SUM(winlost - actual_stake) AS MemberWinLoss,
				SUM(awinlost) AS AgWinLoss,
				SUM(playercomm) AS MemberComm,
				SUM(comm - playercomm) AS AgComm,
				SUM(NumberOfTickets) AS NumberOfTickets,
				1 AS DateRange
			FROM cte_bettrans b WITH(NOLOCK)
			GROUP BY 
				b.ProductID,
				b.GroupTypeId,
				b.SportType,
				b.liveindicator,
				b.IsMMR

			IF EXISTS (SELECT 1 FROM #SportBettype WHERE RefTable = 1) -- bettransRnG
			BEGIN
				INSERT INTO #GrossComm (ProductID, bettype, GrossComm)
				SELECT s.ProductID, s.GroupTypeId, SUM(b.BetStake * b.discount) AS GrossComm
				FROM dbo.bettransRnG b WITH (NOLOCK)
					INNER JOIN #SportBettype s ON b.gameID = s.Bettype AND s.RefTable = 1
				WHERE b.winlostdate BETWEEN @FDate AND @TDate
					AND b.recommend = @custid
					AND b.statusID IN (111, 112, 113)
				GROUP BY s.ProductID, s.GroupTypeId
			END

			IF EXISTS (SELECT 1 FROM #SportBettype WHERE RefTable = 2) -- bettransLC
			BEGIN
				INSERT INTO #GrossComm (ProductID, bettype, GrossComm)
				SELECT s.ProductID, s.GroupTypeId, SUM(b.NetStake * b.discount) AS GrossComm
				FROM dbo.bettransLC b WITH (NOLOCK)
					INNER JOIN #SportBettype s ON b.gameID = s.Bettype AND s.RefTable = 2
				WHERE b.winlostdate BETWEEN @FDate AND @TDate
					AND b.recommend = @custid
					AND b.statusID IN (111, 112, 113)
				GROUP BY s.ProductID, s.GroupTypeId
			END

			IF EXISTS (SELECT 1 FROM #GrossComm)
			BEGIN
				UPDATE t
				SET t.GrossComm = ISNULL(t.GrossComm, 0) + ISNULL(c.GrossComm, 0)
				FROM #AgWinLoss t
					INNER JOIN (
						SELECT ProductID, bettype, SUM(GrossComm) AS GrossComm
						FROM #GrossComm
						GROUP BY ProductID, bettype
					) c ON t.ProductID = c.ProductID AND t.bettype = c.bettype
				WHERE t.DateRange = 1
			END
			
			-- VS Outright
			IF EXISTS (SELECT ProductId FROM #SportBettype WHERE ProductID = 5 AND EventType = 3)
			BEGIN
				INSERT INTO #AgWinLoss(ProductID, bettype, SportType, liveindicator, IsMMR, GrossComm, Turnover, MemberWinLoss, AgWinLoss, MemberComm, AgComm, NumberOfTickets)
				SELECT
					5 AS ProductID,
					s.GroupTypeId,
					r.sporttype,
					0 AS liveindicator,
					0 AS IsMMR,
					SUM(CASE WHEN apositiontaking = 1 THEN 0 ELSE ISNULL(comm/(1 - apositiontaking), 0) END) AS GrossComm,
					SUM(ABS(ISNULL(stake, 0))) AS TurnOver,
					SUM(ISNULL(winlost, 0) - ISNULL(actual_stake, 0)) AS MemberWinLoss,
					SUM(ISNULL(awinlost, 0)) AS AgWinloss,
					SUM(ISNULL(playercomm, 0)) AS MemberComm,
					SUM(ISNULL(comm, 0) - ISNULL(playercomm, 0)) AS AgComm,
					COUNT(transid) AS NumberOfTickets
				FROM dbo.bettrans b WITH (NOLOCK)
					INNER JOIN #SportBettype s ON b.bettype = s.Bettype AND s.ProductID = 5 AND s.EventType = 3
					INNER JOIN dbo.VSOutright o WITH(NOLOCK) ON b.oddsid = o.Orid
					INNER JOIN dbo.VSRaceInfo r WITH(NOLOCK) ON o.EventID = r.EventID
				WHERE winlostdate BETWEEN @FDate AND @TDate
					AND statusID IN (111, 112, 113)
					AND recommend = @custid
				GROUP BY s.GroupTypeId, r.sporttype
			END

			-- VS Match3rd
			IF EXISTS (SELECT ProductId FROM #SportBettype WHERE ProductID = 5 AND EventType = 5)
			BEGIN
				INSERT INTO #AgWinLoss(ProductID, bettype, SportType, liveindicator, IsMMR, GrossComm, Turnover, MemberWinLoss, AgWinLoss, MemberComm, AgComm, NumberOfTickets)
				SELECT
					5 AS ProductID,
					s.GroupTypeId,
					m.SportType,
					0 AS liveindicator,
					0 AS IsMMR,
					SUM(CASE WHEN apositiontaking = 1 THEN 0 ELSE ISNULL(comm/(1 - apositiontaking), 0) END) AS GrossComm,
					SUM(ABS(ISNULL(stake, 0))) AS TurnOver,
					SUM(ISNULL(winlost, 0) - ISNULL(actual_stake, 0)) AS MemberWinLoss,
					SUM(ISNULL(awinlost, 0)) AS AgWinloss,
					SUM(ISNULL(playercomm, 0)) AS MemberComm,
					SUM(ISNULL(comm, 0) - ISNULL(playercomm, 0)) AS AgComm,
					COUNT(transid) AS NumberOfTickets
				FROM dbo.bettrans b WITH (NOLOCK)
					INNER JOIN #SportBettype s ON b.bettype = s.Bettype AND s.ProductID = 5 AND s.EventType = 5
					INNER JOIN Match3rd m WITH (NOLOCK) ON b.matchid = m.Match3rdId
				WHERE winlostdate BETWEEN @FDate AND @TDate
					AND statusID IN (111, 112, 113)
					AND recommend = @custid
				GROUP BY s.GroupTypeId,m.sporttype
			END

			-- Mix parlay of BRVS
			-- (VS - Parlay)->> SportType = bettrans.oddsid
			IF EXISTS (SELECT ProductId FROM #SportBettype WHERE ProductID = 5 AND EventType = 0)
			BEGIN
				INSERT INTO #AgWinLoss(ProductID, bettype, SportType, liveindicator, IsMMR, GrossComm, Turnover, MemberWinLoss, AgWinLoss, MemberComm, AgComm, NumberOfTickets)
				SELECT
					5 AS ProductId,
					b.bettype,
					b.oddsid,
					0 AS liveindicator,
					0 AS IsMMR,
					SUM(CASE WHEN apositiontaking = 1 THEN 0 ELSE ISNULL(comm/(1 - apositiontaking), 0) END) AS GrossComm,
					SUM(ABS(ISNULL(stake, 0))) AS TurnOver,
					SUM(ISNULL(winlost, 0) - ISNULL(actual_stake, 0)) AS MemberWinLoss,
					SUM(ISNULL(awinlost, 0)) AS AgWinloss,
					SUM(ISNULL(playercomm, 0)) AS MemberComm,
					SUM(ISNULL(comm, 0) - ISNULL(playercomm, 0)) AS AgComm,
					COUNT(transid) AS NumberOfTickets
				FROM dbo.bettrans b WITH (NOLOCK)
				WHERE b.matchid IN (2799,10449,11099) AND b.bettype IN (2799,10449,11099)
					AND winlostdate BETWEEN @FDate AND @TDate
					AND statusID IN (111, 112, 113)
					AND recommend = @custid
				GROUP BY b.bettype,b.oddsid
				
			END
		END

		SET @FDate = @FromDate;
		
		IF @FromDate <= @MoveBetsDay
		BEGIN
			IF @ToDate > @MoveBetsDay
			BEGIN
				SET @TDate = @MoveBetsDay;
			END

			; WITH cte_bettrans14 AS
			(
				SELECT  
					s.ProductID,
					s.GroupTypeId,
					CASE s.ProductID
						WHEN 5 THEN ISNULL(m5.sporttype, b.matchid)
						WHEN 22 THEN s.SportType
						WHEN 23 THEN s.SportType
					END AS SportType,
					CASE s.ProductID
						WHEN 3 THEN b.liveindicator
						ELSE 0 
					END AS liveindicator,
					CASE WHEN b.bettype IN (1, 3, 7, 8) AND b.oddstype = 6 THEN 1 ELSE 0 END AS IsMMR,
					SUM(CASE
						WHEN s.RefTable IN (1, 2) THEN 0
						WHEN apositiontaking = 1 THEN 0
						ELSE comm / (1 - apositiontaking)
					END) AS GrossComm,
					SUM(ABS(stake)) stake,
					SUM(awinlost) awinlost, 
					SUM(playercomm) playercomm, 
					SUM(winlost) winlost, 
					SUM(actual_stake) actual_stake,
					SUM(comm) comm,
					COUNT(1) AS NumberOfTickets
				FROM dbo.bettrans14 b WITH(NOLOCK)
					LEFT JOIN dbo.match14 m WITH(NOLOCK) ON b.matchid = m.matchid AND m.eventdate = b.winlostdate AND m.sporttype IN (1,2,50,43,5,4,47)
					LEFT JOIN (
						SELECT LeagueGroupID, leagueid
						FROM dbo.League l WITH(NOLOCK) WHERE l.LeagueGroupID IN (42,74,108,113,122,151)
					) AS l  ON m.leagueid = l.leagueid
					OUTER APPLY (
						SELECT 
							CASE WHEN ( 
										(l.LeagueGroupID IN (42,74,108,113) AND m.sporttype = 1 ) 
											OR (l.LeagueGroupID IN (122, 42) AND m.sporttype = 2 )
											OR (l.LeagueGroupID = 42 AND m.sporttype = 50)
											OR (l.LeagueGroupID = 42 AND m.sporttype = 5) --SabaTennis
											OR (l.LeagueGroupID = 42 AND m.sporttype = 4) --Virtual Ice Hockey
											OR (l.LeagueGroupID = 42 AND m.sporttype = 47) --SABA Kabaddi
											OR (l.LeagueGroupID = 151 AND m.sporttype = 43)
										) AND b.betdaqid <> -2 AND b.winlostdate >= @SeparateSabaSport_Cutoff THEN m.sporttype
							ELSE 0 END sporttype_filter, 
							CASE WHEN ( 
										(l.LeagueGroupID IN (42,74,108,113) AND m.sporttype = 1 ) 
											OR (l.LeagueGroupID IN (122, 42) AND m.sporttype = 2 )
											OR (l.LeagueGroupID = 42 AND m.sporttype = 50)
											OR (l.LeagueGroupID = 42 AND m.sporttype = 5) --SabaTennis
											OR (l.LeagueGroupID = 42 AND m.sporttype = 4) --Virtual Ice Hockey
											OR (l.LeagueGroupID = 42 AND m.sporttype = 47) --SABA Kabaddi
											OR (l.LeagueGroupID = 151 AND m.sporttype = 43)
										) AND b.betdaqid <> -2 AND b.winlostdate >= @SeparateSabaSport_Cutoff THEN l.LeagueGroupID
							ELSE 0 END LeagueGroupID,
							CASE WHEN b.betdaqid = -2 THEN 1 ELSE 0 END TicketType
					) AS et
					INNER JOIN #SportBettype s ON b.bettype = s.Bettype 
						AND (s.ProductID <> 5 OR s.EventType NOT IN (3,5)) AND (s.ProductID <> 1 OR (s.ProductID = 1 AND et.sporttype_filter = s.sporttype_filter AND et.LeagueGroupID = s.LeagueGroupID AND et.TicketType = s.TicketType))
					LEFT JOIN dbo.match14 m5 WITH(NOLOCK) ON b.matchid = m5.matchid AND s.ProductID = 5
				WHERE winlostdate BETWEEN @FDate AND @TDate
					AND statusID IN (111, 112, 113)
					AND recommend = @custid
				GROUP BY	
					s.ProductID,
					s.GroupTypeId,
					CASE s.ProductID
						WHEN 5 THEN ISNULL(m5.sporttype, b.matchid)
						WHEN 22 THEN s.SportType
						WHEN 23 THEN s.SportType
					END,
					CASE s.ProductID
						WHEN 3 THEN b.liveindicator
						ELSE 0 
					END,
					CASE WHEN b.bettype IN (1, 3, 7, 8) AND b.oddstype = 6 THEN 1 ELSE 0 END
			)
			INSERT INTO #AgWinLoss(ProductID, bettype, SportType, liveindicator, IsMMR, GrossComm, Turnover, MemberWinLoss, AgWinLoss, MemberComm, AgComm, NumberOfTickets, DateRange)
			SELECT  
				b.ProductID,
				b.GroupTypeId,
				b.SportType,
				b.liveindicator,
				b.IsMMR,
				SUM(GrossComm) AS GrossComm,
				SUM(ABS(stake)) AS Turnover,
				SUM(winlost - actual_stake) AS MemberWinLoss,
				SUM(awinlost) AS AgWinLoss,
				SUM(playercomm) AS MemberComm,
				SUM(comm - playercomm) AS AgComm,
				SUM(NumberOfTickets) AS NumberOfTickets,
				2 AS DateRange
			FROM cte_bettrans14 b WITH(NOLOCK)
			GROUP BY 
				b.ProductID,
				b.GroupTypeId,
				b.SportType,
				b.liveindicator,
				b.IsMMR

			TRUNCATE TABLE #GrossComm
			
			IF EXISTS (SELECT 1 FROM #SportBettype WHERE RefTable = 1) -- bettransRnG
			BEGIN
				INSERT INTO #GrossComm (ProductID, bettype, GrossComm)
				SELECT s.ProductID, s.GroupTypeId, SUM(b.BetStake * b.discount) AS GrossComm
				FROM dbo.bettransRnG14 b WITH (NOLOCK)
					INNER JOIN #SportBettype s ON b.gameID = s.Bettype AND s.RefTable = 1
				WHERE b.winlostdate BETWEEN @FDate AND @TDate
					AND b.recommend = @custid
					AND b.statusID IN (111, 112, 113)
				GROUP BY s.ProductID, s.GroupTypeId
			END

			IF EXISTS (SELECT 1 FROM #SportBettype WHERE RefTable = 2) -- bettransLC
			BEGIN
				INSERT INTO #GrossComm (ProductID, bettype, GrossComm)
				SELECT s.ProductID, s.GroupTypeId, SUM(b.NetStake * b.discount) AS GrossComm
				FROM dbo.bettransLC14 b WITH (NOLOCK)
					INNER JOIN #SportBettype s ON b.gameID = s.Bettype AND s.RefTable = 2
				WHERE b.winlostdate BETWEEN @FDate AND @TDate
					AND b.recommend = @custid
					AND b.statusID IN (111, 112, 113)
				GROUP BY s.ProductID, s.GroupTypeId
			END

			IF EXISTS (SELECT 1 FROM #GrossComm)
			BEGIN
				UPDATE t
				SET t.GrossComm = ISNULL(t.GrossComm, 0) + ISNULL(c.GrossComm, 0)
				FROM #AgWinLoss t
					INNER JOIN (
						SELECT ProductID, bettype, SUM(GrossComm) AS GrossComm
						FROM #GrossComm
						GROUP BY ProductID, bettype
					) c ON t.ProductID = c.ProductID AND t.bettype = c.bettype
				WHERE t.DateRange = 2
			END

			-- VS Outright
			IF EXISTS (SELECT ProductId FROM #SportBettype WHERE ProductID = 5 AND EventType = 3)
			BEGIN
				INSERT INTO #AgWinLoss(ProductID, bettype, SportType, liveindicator, IsMMR, GrossComm, Turnover, MemberWinLoss, AgWinLoss, MemberComm, AgComm, NumberOfTickets)
				SELECT
					5 AS ProductID,
					s.GroupTypeId,
					r.sporttype,
					0 AS liveindicator,
					0 AS IsMMR,
					SUM(CASE WHEN apositiontaking = 1 THEN 0 ELSE ISNULL(comm/(1 - apositiontaking), 0) END) AS GrossComm,
					SUM(ABS(ISNULL(stake, 0))) AS TurnOver,
					SUM(ISNULL(winlost, 0) - ISNULL(actual_stake, 0)) AS MemberWinLoss,
					SUM(ISNULL(awinlost, 0)) AS AgWinloss,
					SUM(ISNULL(playercomm, 0)) AS MemberComm,
					SUM(ISNULL(comm, 0) - ISNULL(playercomm, 0)) AS AgComm,
					COUNT(transid) AS NumberOfTickets
				FROM dbo.bettrans14 b WITH (NOLOCK)
					INNER JOIN #SportBettype s ON b.bettype = s.Bettype AND s.ProductID = 5 AND s.EventType = 3
					INNER JOIN dbo.VSOutright14 o WITH(NOLOCK) ON b.oddsid = o.Orid
					INNER JOIN dbo.VSRaceInfo14 r WITH(NOLOCK) ON o.EventID = r.EventID
				WHERE winlostdate BETWEEN @FDate AND @TDate
					AND statusID IN (111, 112, 113)
					AND recommend = @custid
				GROUP BY s.GroupTypeId, r.sporttype
			END

			-- VS Match3rd
			IF EXISTS (SELECT ProductId FROM #SportBettype WHERE ProductID = 5 AND EventType = 5)
			BEGIN
				INSERT INTO #AgWinLoss(ProductID, bettype, SportType, liveindicator, IsMMR, GrossComm, Turnover, MemberWinLoss, AgWinLoss, MemberComm, AgComm, NumberOfTickets)
				SELECT
					5 AS ProductID,
					s.GroupTypeId,
					m.SportType,
					0 AS liveindicator,
					0 AS IsMMR,
					SUM(CASE WHEN apositiontaking = 1 THEN 0 ELSE ISNULL(comm/(1 - apositiontaking), 0) END) AS GrossComm,
					SUM(ABS(ISNULL(stake, 0))) AS TurnOver,
					SUM(ISNULL(winlost, 0) - ISNULL(actual_stake, 0)) AS MemberWinLoss,
					SUM(ISNULL(awinlost, 0)) AS AgWinloss,
					SUM(ISNULL(playercomm, 0)) AS MemberComm,
					SUM(ISNULL(comm, 0) - ISNULL(playercomm, 0)) AS AgComm,
					COUNT(transid) AS NumberOfTickets
				FROM dbo.bettrans14 b WITH (NOLOCK)
					INNER JOIN #SportBettype s ON b.bettype = s.Bettype AND s.ProductID = 5 AND s.EventType = 5
					INNER JOIN Match3rd14 m WITH (NOLOCK) ON b.matchid = m.Match3rdId
				WHERE winlostdate BETWEEN @FDate AND @TDate
					AND statusID IN (111, 112, 113)
					AND recommend = @custid
				GROUP BY s.GroupTypeId,m.sporttype
			END			

			-- Mix parlay of BRVS
			-- (VS - Parlay)->> SportType = bettrans.oddsid
			IF EXISTS (SELECT ProductId FROM #SportBettype WHERE ProductID = 5 AND EventType = 0)
			BEGIN
				INSERT INTO #AgWinLoss(ProductID, bettype, SportType, liveindicator, IsMMR, GrossComm, Turnover, MemberWinLoss, AgWinLoss, MemberComm, AgComm, NumberOfTickets)
				SELECT
					5 AS ProductId,
					b.bettype,
					b.oddsid,
					0 AS liveindicator,
					0 AS IsMMR,
					SUM(CASE WHEN apositiontaking = 1 THEN 0 ELSE ISNULL(comm/(1 - apositiontaking), 0) END) AS GrossComm,
					SUM(ABS(ISNULL(stake, 0))) AS TurnOver,
					SUM(ISNULL(winlost, 0) - ISNULL(actual_stake, 0)) AS MemberWinLoss,
					SUM(ISNULL(awinlost, 0)) AS AgWinloss,
					SUM(ISNULL(playercomm, 0)) AS MemberComm,
					SUM(ISNULL(comm, 0) - ISNULL(playercomm, 0)) AS AgComm,
					COUNT(transid) AS NumberOfTickets
				FROM dbo.bettrans14 b WITH (NOLOCK)
				WHERE b.matchid IN (2799,10449,11099) AND b.bettype IN (2799,10449,11099)
					AND winlostdate BETWEEN @FDate AND @TDate
					AND statusID IN (111, 112, 113)
					AND recommend = @custid
				GROUP BY b.bettype,b.oddsid

			END
		END
	END

	SELECT	t.bettype,
			t.ProductID,
			t.SportType,
			liveindicator,
			IsMMR,
			SUM(GrossComm) AS GrossComm,
			SUM(TurnOver) AS Turnover,
			SUM(MemberWinLoss) AS MemberWinLoss,
			SUM(MemberComm) AS MemberComm,
			SUM(AgWinLoss) AS AgWinLoss,
			SUM(AgComm) AS AgComm,
			SUM(NumberOfTickets) AS NumberOfTickets
	FROM #AgWinLoss t
	GROUP BY t.bettype, t.ProductID, t.SportType, liveindicator, IsMMR
	ORDER BY t.bettype, t.ProductID, t.SportType, liveindicator, IsMMR;

	DROP TABLE #AgWinLoss
	DROP TABLE #GrossComm
	DROP TABLE #SportBettype

	SET NOCOUNT OFF;
END

GO
