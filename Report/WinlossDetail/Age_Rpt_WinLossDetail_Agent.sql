/*<info serverAlias="DBAGE-bodb02" executers="wsv_alp,wsv_alpv" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Age_Rpt_WinLossDetail_Agent]
	@CustID			INT = NULL, --recommend
	@FromDate		SMALLDATETIME,
	@ToDate			SMALLDATETIME,
	@ProductIds		VARCHAR(MAX),
	@ProductDetails NVARCHAR(MAX) = 'All',
	@BalanceUpDay	SMALLDATETIME,
	@MoveBetsDay	SMALLDATETIME,
	@PageSize		INT = 0,
	@PageIndex		INT = 0,
	@TotalRecords	INT = 0 OUTPUT,
	@UserName		VARCHAR(30) = '',
	@IsReward		BIT = 1

AS

/*
Created: 
Task : Smartphone friendly - Win Loss Detail Report
DB: DBAGE/bodb02

Revisions:
	- 20161024@Paul: Smartphone Friendly UI for Microsite Report [RedmineID: #61531]
	- 20170110@Paul: Use new functions to get sum_winloss condition and SportBettypeMatrix [RedmineID: #69515]
	- 20170622@Percy: Combine Betradar Virtual Sports with Virtual Sports [RedmineID: #78339]
	- 20170914@Percy: Enhance performance on sum_winloss_old [RedmineID: #83171]
	- 20180913@Percy: Bullfighting - Add data into TurnoverNoDraw column [RedmineID: #101288]
	- 20180914@Percy: Poker Games - Modify GrossComm [RedmineID: #101550]
	- 20190826@Percy: Remove inactive products [RedmineID: #118699]
	- 20200410@Sophia: Add BBIN, Sexy Gaming, SA Gaming [RedmineId: #131358]
	- 20200422@Sophia: Add IBCBet Live Casino [RedmineId: #130693]
	- 20200521@Sophia: Enhance SP due to bot attack [redmind: #134415]
	- 20200527@Sophia: Add ION [Redmine: #132325]
	- 20200528@Sophia: Add RNG War [Redmine: #132013]
	- 20200909@Malcolm: Report Enhancement for Jackpot Product [RedmineID : #139575]
	- 20200915@Malcolm: Add WM Live Casino [Redmine : #131584]
	- 20201201@Malcolm : Add Gold Diamond Gaming [Redmine : #144110]
	- 20201210@Malcolm: Add Big Gaming [RedmineId : #142459]
	- 20210310@Malcolm: Add Pragmatic Live Casino [RedmineId : #133717]
	- 20210617@Sol: changed how to calc net turn over - [RedmineId : #156653]
	- 20211122@Percy: Enhance gross comm formula [RedmineID: #164479]
	- 20220208@Danny: Separate Saba Sport Performance [Redmine: #167177]
	- 20221207@Eddie: Add New SABA ESports PinGoal [RedmineID: #181383]
	- 20221229@Bobby: Enhance GrossComm figure [RedmineID: #182155]
	- 20230331@Malcolm: Add first name, last name [RedmineID : #184752]
	- 20230526@Lewis: Add Search by Username [RedmineID : #184752 - Phase 2]
	- 20230630@Lewis: Add Saba Tennis [RedmineID: #190459]
	- 20240125@Lewis: Show Archived User [RedmineID: #199410]
	- 20240306@Lewis: Add Virtual Ice Hockey [RedmineID: #201129]
	- 20240515@Lewis: Add SABA Kabaddi [RedmineID: #203763]
	- 20240424@Lewis: Change old sql account [Redmine: #204021]
	- 20240703@Lewis: Switch data source - from bettrans to bettranscompact [Redmine: #207517]
    - 20240918@Lewis: Rebate Retention - Reward [RedmineId: #208503]
	
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

	DECLARE @UserName_CustId INT

	IF @Username <> ''	--@USERNAME IS NOT NULL		=> -1: No Data || >0: Exactly Username
	BEGIN
		SET @UserName_CustId = ISNULL((SELECT Custid FROM Customer WITH (NOLOCK) WHERE username = @UserName),-1)
	END
	ELSE				--@USERNAME IS NULL			=> Run all
	BEGIN
		SET @UserName_CustId = 0
	END

	DECLARE @RowStart	INT,
			@RowEnd		INT;
		
	SELECT	@PageIndex = @PageIndex - 1,
			@RowStart = @PageSize * @PageIndex + 1,
			@RowEnd = @RowStart + @PageSize - 1;

	CREATE TABLE #MAgWinLossDetails
	(
		CustID			INT,
		TurnOver		MONEY,
		TurnoverNoDraw	MONEY,
		GrossComm		MONEY,
		MemberWinLost	MONEY,
		PlayerComm		MONEY,
		AgWinLost		MONEY,
		AgComm			MONEY,
		MAgWinLost		MONEY,
		MAgComm			MONEY,
		NoOfTicket		INT,
		RewardAmount	MONEY
	)

	CREATE TABLE #GrossComm (CustId INT, TurnoverNoDraw MONEY, GrossComm MONEY)

	CREATE TABLE #TmpCondSumWL(
		SportType		INT,
		BetType			INT,
		LeagueGroupID	SMALLINT, 
		TicketType		TINYINT
	);

	DECLARE @ExistingProductDetails TABLE (ProductId INT,Sporttype INT,Bettype INT, LeagueGroupID SMALLINT, TicketType TINYINT)
	DECLARE @isTest BIT, @__ProductDetails XML;
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

	IF @FromDate <= @MoveBetsDay
	BEGIN
		INSERT INTO #TmpCondSumWL(SportType, BetType, LeagueGroupID, TicketType) 
		SELECT f.SportType, f.BetType, f.LeagueGroupID, f.TicketType
		FROM dbo.f_SumWinloss_ConditionSel(@ProductIds) f
			LEFT JOIN @ExistingProductDetails e ON f.ProductID = e.ProductId 
		WHERE e.ProductId IS NULL OR (e.Bettype = f.BetType AND e.Sporttype = f.SportType AND e.TicketType = f.TicketType AND e.LeagueGroupID = f.LeagueGroupID AND e.ProductID = f.ProductId)
	END

	------Get @Srecommend
	DECLARE @Srecommend int;
	DECLARE @CurrencyCode VARCHAR(12);

	SELECT @Srecommend = Srecommend
			,@CurrencyCode = e.Code
	FROM dbo.CustInfo c WITH(NOLOCK)
	INNER JOIN dbo.Exchange e WITH (NOLOCK)
		ON c.currency = e.ExchangeId
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
			@CID	INT;
	    
	SELECT	@FDate = @FromDate,
			@TDate = @ToDate, 
			@CID = @custid;

				
	--TODO: bettrans range
	IF @ToDate > @MoveBetsDay
	BEGIN 	
		SELECT @FDate	= IIF(@FromDate <= @MoveBetsDay, DATEADD(DD, 1, @MoveBetsDay), @FromDate)
			,@TDate		= @ToDate

		-- TODO: get data from bettrans_compact	
		;WITH CTE_Agent AS (
			SELECT custid
			FROM dbo.Customer WITH(NOLOCK)
			WHERE mrecommend = @CID
				AND RoleId = 2
		)
		INSERT INTO #MAgWinLossDetails(CustID, TurnOver, TurnoverNoDraw, GrossComm, MemberWinLost, PlayerComm, AgWinLost, AgComm, MAgWinLost, MAgComm, NoOfTicket)
		SELECT	b.custid,			
				SUM(b.turnover) AS TurnOver, 
				SUM(b.TurnoverNoDraw) AS TurnoverNoDraw,
				SUM(b.GrossComm) AS GrossComm,
				SUM(b.winlost) AS MemberWinlost,
				SUM(b.playercomm) AS PlayerComm,
				SUM(b.awinlost) AS AgWinlost,
				SUM(b.comm - b.playercomm) AS AgComm,
				SUM(b.mwinlost) AS MAgWinlost,
				SUM(b.acomm - b.comm) AS MAgComm,
				SUM(b.betcount) AS NoOfTicket
		FROM bodb_Age.dbo.bettrans_compact b WITH (NOLOCK)
		INNER JOIN CTE_Agent m ON m.custid = b.custid
		INNER JOIN (
			SELECT	ISNULL(p.GroupProductId, f.ProductID) AS ProductID, f.BetType, f.RefTable, ISNULL(e.LeagueGroupID,0) AS LeagueGroupID, ISNULL(e.TicketType,0) AS TicketType, ISNULL(SportType,0) AS SportType
			FROM (	
					SELECT DISTINCT ma.ProductID, ma.BetType, ma.RefTable
					FROM  dbo.SportBettypeMatrix ma WITH(NOLOCK)
					WHERE ',' + @ProductIDs + ',' LIKE '%,' + cast(ma.ProductID as varchar(3)) + ',%'
							AND (ma.IsTest = 0 OR ma.IsTest = @IsTest)
					) f
				LEFT JOIN dbo.f_GroupProduct() p ON f.ProductID = p.ProductId
				LEFT JOIN @ExistingProductDetails e ON e.ProductId = f.ProductID 
			WHERE EXISTS(SELECT 1 WHERE e.ProductId IS NULL 
					OR 
						(
							e.Bettype = f.BetType 
									OR (
											e.Bettype = 0  AND  (e.ProductId = 1 OR  f.BetType NOT IN (SELECT g.Bettype FROM f_GetProductDetail() g WHERE g.ProductId <> 1) )
										)
						)
					)
		) s ON b.bettype = s.bettype 
			AND (s.ProductID <> 1 OR (s.ProductID = 1 AND b.sporttype = s.SportType AND b.LeagueGroupID = s.LeagueGroupID AND b.TicketType = s.TicketType))
		WHERE	b.winlostdate BETWEEN @FDate AND @TDate
		GROUP BY b.custid;

		-- bettransRnG
		INSERT INTO #GrossComm (CustId, TurnoverNoDraw, GrossComm)
		SELECT b.recommend AS CustId
			,SUM(CASE WHEN cont.ContributionBettype IS NULL THEN b.BetStake ELSE 0 END) AS TurnoverNoDraw
			,SUM(b.BetStake * b.adiscount) AS GrossComm
		FROM dbo.bettransRnG b WITH(NOLOCK)
			INNER JOIN (
							SELECT	ISNULL(p.GroupProductId, f.ProductID) AS ProductID, f.BetType
							FROM (	
									SELECT DISTINCT ma.ProductID, ma.BetType, ma.RefTable
									FROM  dbo.SportBettypeMatrix ma WITH(NOLOCK)
									WHERE ',' + @ProductIDs + ',' LIKE '%,' + cast(ma.ProductID as varchar(3)) + ',%'
											AND (ma.IsTest = 0 OR ma.IsTest = @IsTest) 	AND ma.RefTable = 1
								 ) f
								LEFT JOIN dbo.f_GroupProduct() p ON f.ProductID = p.ProductId
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
							
						) s ON b.gameID = s.Bettype
			OUTER APPLY 
			(
				SELECT f.Bettype AS ContributionBettype
				FROM dbo.f_BettypePrizeGroup() f
				WHERE f.BettypeGroup = 'Contribution'
					AND f.Bettype = b.gameID
			) cont
		WHERE winlostdate BETWEEN @FDate AND @TDate
			AND statusID IN (111, 112, 113) 
			AND mrecommend = @CID
		GROUP BY b.recommend
		
		-- bettransLC
		INSERT INTO #GrossComm (CustId, TurnoverNoDraw, GrossComm)
		SELECT b.recommend AS CustId
			,SUM(CASE WHEN cont.ContributionBettype IS NULL THEN b.NetStake ELSE 0 END) AS TurnoverNoDraw
			,SUM(b.NetStake * b.adiscount) AS GrossComm
		FROM dbo.bettransLC b WITH(NOLOCK)
			INNER JOIN (
							SELECT	ISNULL(p.GroupProductId, f.ProductID) AS ProductID, f.BetType
							FROM (	
									SELECT DISTINCT ma.ProductID, ma.BetType, ma.RefTable
									FROM  dbo.SportBettypeMatrix ma WITH(NOLOCK)
									WHERE ',' + @ProductIDs + ',' LIKE '%,' + cast(ma.ProductID as varchar(3)) + ',%'
											AND (ma.IsTest = 0 OR ma.IsTest = @IsTest) 	AND ma.RefTable = 2
								 ) f
								LEFT JOIN dbo.f_GroupProduct() p ON f.ProductID = p.ProductId
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
							
						) s ON b.gameID = s.Bettype
			OUTER APPLY 
			(
				SELECT f.Bettype AS ContributionBettype
				FROM dbo.f_BettypePrizeGroup() f
				WHERE f.BettypeGroup = 'Contribution'
					AND f.Bettype = b.gameID
			) cont
		WHERE winlostdate BETWEEN @FDate AND @TDate
			AND statusID IN (111, 112, 113) 
			AND mrecommend = @CID
		GROUP BY b.recommend

		IF EXISTS (SELECT 1 FROM #GrossComm)
		BEGIN
			UPDATE t
			SET t.TurnoverNoDraw = ISNULL(t.TurnoverNoDraw, 0) + ISNULL(c.TurnoverNoDraw, 0)
				,t.GrossComm = ISNULL(t.GrossComm, 0) + ISNULL(c.GrossComm, 0)
			FROM #MAgWinLossDetails t
				INNER JOIN (
					SELECT CustId, SUM(GrossComm) AS GrossComm, SUM(TurnoverNoDraw) AS TurnoverNoDraw FROM #GrossComm GROUP BY CustId
				) c ON t.CustId = c.CustId
		END
	END		
	--TODO: sum_winloss range
	IF @FromDate <= @MoveBetsDay
	BEGIN
		SELECT @FDate	= IIF(@FromDate >= @BalanceUpDay, @FromDate, @BalanceUpDay)
			, @TDate	= IIF(@ToDate > @MoveBetsDay, @MoveBetsDay, @ToDate);
	
		INSERT INTO #MAgWinLossDetails(CustID, TurnOver, TurnoverNoDraw, GrossComm, MemberWinLost, PlayerComm, AgWinLost, AgComm, MAgWinLost, MAgComm, NoOfTicket)
		SELECT	CustID,			
				SUM(ABS(TurnOver)) AS TurnOver,
				SUM(ABS(TunroverNoDraw)) as TurnoverNoDraw,
				SUM(grosscomm) AS GrossComm,
				SUM(winlost) AS MemberWinlost,
				SUM(playercomm) AS PlayerComm,
				SUM(awinlost) AS AgWinlost,
				ISNULL(SUM(comm - playercomm), 0) AS AgComm,
				SUM(mwinlost) AS MAgWinlost,
				SUM(acomm) - SUM(comm) AS MAgComm,
				SUM(betcount) AS NoOfTicket
		FROM dbo.SUM_winloss b WITH(NOLOCK)
			INNER JOIN #TmpCondSumWL t ON b.sporttype = t.sporttype AND b.bettype = t.bettype AND ISNULL(b.leagueGroupID,0) = t.LeagueGroupID AND ISNULL(b.ticketType,0) = t.TicketType
		WHERE winlostdate BETWEEN @FDate AND @TDate			
			AND MRecommend = @CID
			AND RoleID = 2
		GROUP BY CustID;
	END

	--TODO: sum_winloss_old range
	IF @FromDate < @BalanceUpDay 
	BEGIN
		SELECT @FDate	= @FromDate
			,@TDate		= IIF(@ToDate >= @BalanceUpDay, DATEADD(DD, -1, @BalanceUpDay), @ToDate);


		-- using cte to remove predicate when seek on sum_winloss_old
		;WITH CTE_Winlostdate (winlostdate, sporttype, bettype, leagueGroupID, ticketType) AS
		(
			SELECT @FDate AS winlostdate, SportType, BetType, leagueGroupID, ticketType
			FROM #TmpCondSumWL
			UNION ALL
			SELECT DATEADD(DAY, 1, winlostdate), SportType, BetType, leagueGroupID, ticketType
			FROM CTE_Winlostdate
			WHERE winlostdate < @TDate
		)
		INSERT INTO #MAgWinLossDetails(CustID, TurnOver, TurnoverNoDraw, GrossComm, MemberWinLost, PlayerComm, AgWinLost, AgComm, MAgWinLost, MAgComm, NoOfTicket)
		SELECT	CustID,			
				SUM(ABS(TurnOver)) AS TurnOver,
				SUM(ABS(TunroverNoDraw)) as TurnoverNoDraw,
				SUM(grosscomm) AS GrossComm,
				SUM(winlost) AS MemberWinlost,
				SUM(playercomm) AS PlayerComm,
				SUM(awinlost) AS AgWinlost,
				ISNULL(SUM(comm - playercomm), 0) AS AgComm,
				SUM(mwinlost) AS MAgWinlost,
				SUM(acomm) - SUM(comm) AS MAgComm,
				SUM(betcount) AS NoOfTicket
		FROM bodb_Summary.dbo.Sum_WinLoss_Old b WITH(NOLOCK) 
			CROSS APPLY CTE_Winlostdate w
		WHERE b.winlostdate = w.winlostdate
			AND b.srecommend = @srecommend
			AND b.mrecommend = @custid
			AND b.recommend = b.recommend
			AND b.RoleID = 2
			AND b.sporttype = w.sporttype
			AND b.bettype = w.bettype
			AND ISNULL(b.leagueGroupID,0) = w.leagueGroupID
			AND ISNULL(b.ticketType,0) = w.ticketType
		GROUP BY CustID
		OPTION (MAXRECURSION 0);
	END	


	--TODO: SabaWalletTicket
	IF @IsReward = 1
	BEGIN
		SELECT @FDate = @FromDate, @TDate = @ToDate

		INSERT INTO #MAgWinLossDetails(CustID,RewardAmount)
		SELECT Recommend,SUM(Amount)
		FROM SabaWalletTicket b WITH (NOLOCK)
		WHERE b.winlostdate BETWEEN @FDate AND @TDate
			AND b.WalletID= 2
			AND b.Mrecommend = @CID
			AND (@UserName_CustId = 0 OR b.Recommend = @UserName_CustId)
		GROUP BY Recommend
	END
	
	--TODO: Result
	IF ((@PageSize <= 0) AND (@PageIndex <= 0))
	BEGIN
		IF @IsReward = 1
		BEGIN
			SELECT	c.CustID AS CustId, 
					c.UserName AS CustName, 
					c.FirstName,
					c.LastName,
					SUM(TurnOver) AS Turnover,
					SUM(TurnoverNoDraw) as NetTurnover,
					SUM(GrossComm) AS GrossComm,
					SUM(MemberWinLost) AS MemberWinLoss,
					SUM(PlayerComm) AS MemberComm,
					SUM(AgWinlost) AS AgWinLoss,
					SUM(AgComm) AS AgComm,
					SUM(MAgWinlost) AS MAgWinLoss,
					SUM(MAgComm) AS MAgComm,
					SUM(NoOfTicket) AS NumberOfTickets,
					SUM(w.RewardAmount) AS RewardAmount,
					@CurrencyCode AS RewardCurrency
			FROM #MAgWinLossDetails w 
				LEFT JOIN dbo.Customer c WITH(NOLOCK) ON w.CustID = c.CustID 
			WHERE @UserName_CustId = 0 OR w.custid = @UserName_CustId
			GROUP BY c.CustID, c.UserName, c.FirstName, c.LastName
			ORDER BY IIF(c.Username IS NULL,1,0),c.Username;

			SELECT	NULL AS CustId,
					'Total' AS CustName,
					SUM(TurnOver) AS Turnover,
					SUM(TurnoverNoDraw) as NetTurnover,
					SUM(GrossComm) AS GrossComm,
					SUM(MemberWinLost) AS MemberWinLoss,
					SUM(PlayerComm) AS MemberComm,
					SUM(AgWinlost) AS AgWinLoss,
					SUM(AgComm) AS AgComm,
					SUM(MAgWinlost) AS MAgWinLoss,
					SUM(MAgComm) AS MAgComm,
					SUM(NoOfTicket) AS NumberOfTickets,
					SUM(RewardAmount) AS RewardAmount,
					@CurrencyCode AS RewardCurrency
			FROM #MAgWinLossDetails
			WHERE @UserName_CustId = 0 OR custid = @UserName_CustId;
		END
		ELSE
		BEGIN
			SELECT	c.CustID AS CustId, 
					c.UserName AS CustName, 
					c.FirstName,
					c.LastName,
					SUM(TurnOver) AS Turnover,
					SUM(TurnoverNoDraw) as NetTurnover,
					SUM(GrossComm) AS GrossComm,
					SUM(MemberWinLost) AS MemberWinLoss,
					SUM(PlayerComm) AS MemberComm,
					SUM(AgWinlost) AS AgWinLoss,
					SUM(AgComm) AS AgComm,
					SUM(MAgWinlost) AS MAgWinLoss,
					SUM(MAgComm) AS MAgComm,
					SUM(NoOfTicket) AS NumberOfTickets
			FROM #MAgWinLossDetails w 
				LEFT JOIN dbo.Customer c WITH(NOLOCK) ON w.CustID = c.CustID 
			WHERE @UserName_CustId = 0 OR w.custid = @UserName_CustId
			GROUP BY c.CustID, c.UserName, c.FirstName, c.LastName
			ORDER BY IIF(c.Username IS NULL,1,0),c.Username;

			SELECT	NULL AS CustId,
					'Total' AS CustName,
					SUM(TurnOver) AS Turnover,
					SUM(TurnoverNoDraw) as NetTurnover,
					SUM(GrossComm) AS GrossComm,
					SUM(MemberWinLost) AS MemberWinLoss,
					SUM(PlayerComm) AS MemberComm,
					SUM(AgWinlost) AS AgWinLoss,
					SUM(AgComm) AS AgComm,
					SUM(MAgWinlost) AS MAgWinLoss,
					SUM(MAgComm) AS MAgComm,
					SUM(NoOfTicket) AS NumberOfTickets
			FROM #MAgWinLossDetails
			WHERE @UserName_CustId = 0 OR custid = @UserName_CustId;
		END
	END
	ELSE
	BEGIN
		IF @TotalRecords = 0  
		BEGIN  
			SELECT @TotalRecords = count(tmp.CustID)
			FROM (
				SELECT CustID
				FROM #MAgWinLossDetails
				WHERE @UserName_CustId = 0 OR custid = @UserName_CustId
				GROUP BY CustID
			) tmp; 
		END

		IF @IsReward = 1
		BEGIN
			SELECT wl.*
			FROM (
				SELECT	c.CustID AS CustId, 
						c.UserName AS CustName, 
						c.FirstName,
						c.LastName,
						SUM(TurnOver) AS Turnover,
						SUM(TurnoverNoDraw) AS NetTurnover,
						SUM(GrossComm) AS GrossComm,
						SUM(MemberWinLost) AS MemberWinLoss,
						SUM(PlayerComm) AS MemberComm,
						SUM(AgWinlost) AS AgWinLoss,
						SUM(AgComm) AS AgComm,
						SUM(MAgWinlost) AS MAgWinLoss,
						SUM(MAgComm) AS MAgComm,
						SUM(NoOfTicket) AS NumberOfTickets,
						SUM(w.RewardAmount) AS RewardAmount,
						@CurrencyCode AS RewardCurrency,
						ROW_NUMBER() OVER (ORDER BY IIF(c.Username IS NULL,1,0),c.UserName) AS RowNum
				FROM #MAgWinLossDetails w
					LEFT JOIN dbo.Customer c WITH(NOLOCK) ON w.CustID = c.CustID 
				WHERE @UserName_CustId = 0 OR w.custid = @UserName_CustId
				GROUP BY c.CustID, c.UserName, c.FirstName, c.LastName
			) wl
			WHERE wl.RowNum BETWEEN @RowStart AND @RowEnd;

			SELECT	NULL AS CustId,
					'Total' AS CustName,
					SUM(TurnOver) AS Turnover,
					SUM(TurnoverNoDraw) as NetTurnover,
					SUM(GrossComm) AS GrossComm,
					SUM(MemberWinLost) AS MemberWinLoss,
					SUM(PlayerComm) AS MemberComm,
					SUM(AgWinlost) AS AgWinLoss,
					SUM(AgComm) AS AgComm,
					SUM(MAgWinlost) AS MAgWinLoss,
					SUM(MAgComm) AS MAgComm,
					SUM(NoOfTicket) AS NumberOfTickets,
					SUM(RewardAmount) AS RewardAmount,
					@CurrencyCode AS RewardCurrency
			FROM #MAgWinLossDetails
			WHERE @UserName_CustId = 0 OR custid = @UserName_CustId;
		END
		ELSE
		BEGIN
			SELECT wl.*
			FROM (
				SELECT	c.CustID AS CustId, 
						c.UserName AS CustName, 
						c.FirstName,
						c.LastName,
						SUM(TurnOver) AS Turnover,
						SUM(TurnoverNoDraw) AS NetTurnover,
						SUM(GrossComm) AS GrossComm,
						SUM(MemberWinLost) AS MemberWinLoss,
						SUM(PlayerComm) AS MemberComm,
						SUM(AgWinlost) AS AgWinLoss,
						SUM(AgComm) AS AgComm,
						SUM(MAgWinlost) AS MAgWinLoss,
						SUM(MAgComm) AS MAgComm,
						SUM(NoOfTicket) AS NumberOfTickets,
						ROW_NUMBER() OVER (ORDER BY IIF(c.Username IS NULL,1,0),c.UserName) AS RowNum
				FROM #MAgWinLossDetails w
					LEFT JOIN dbo.Customer c WITH(NOLOCK) ON w.CustID = c.CustID 
				WHERE @UserName_CustId = 0 OR w.custid = @UserName_CustId
				GROUP BY c.CustID, c.UserName, c.FirstName, c.LastName
			) wl
			WHERE wl.RowNum BETWEEN @RowStart AND @RowEnd;

			SELECT	NULL AS CustId,
					'Total' AS CustName,
					SUM(TurnOver) AS Turnover,
					SUM(TurnoverNoDraw) as NetTurnover,
					SUM(GrossComm) AS GrossComm,
					SUM(MemberWinLost) AS MemberWinLoss,
					SUM(PlayerComm) AS MemberComm,
					SUM(AgWinlost) AS AgWinLoss,
					SUM(AgComm) AS AgComm,
					SUM(MAgWinlost) AS MAgWinLoss,
					SUM(MAgComm) AS MAgComm,
					SUM(NoOfTicket) AS NumberOfTickets
			FROM #MAgWinLossDetails
			WHERE @UserName_CustId = 0 OR custid = @UserName_CustId;
		END
		
	END


	DROP TABLE #MAgWinLossDetails;
	DROP TABLE #TmpCondSumWL;
	DROP TABLE #GrossComm;

	SET NOCOUNT OFF;
END
GO
