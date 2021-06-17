/*<info serverAlias="DBAGE-bodb02" executers="bodbDownlineNet,bodbDownlineNetView" isFunction="0" isNested="0"></info>*/
CREATE PROCEDURE [dbo].[Age_Rpt_WinLossDetail_Master]
	@CustID			INT = NULL, --recommend
	@FromDate		SMALLDATETIME,
	@ToDate			SMALLDATETIME,
	@ProductIds		VARCHAR(MAX),
	@ProductDetails NVARCHAR(MAX) = 'All',
	@BalanceUpDay	SMALLDATETIME,
	@MoveBetsDay	SMALLDATETIME,
	@PageSize		INT = 0,
	@PageIndex		INT = 0,
	@TotalRecords	INT = 0 OUTPUT
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
	- 20181003@Patrick: Index revolution [RedmineID: #101405]
	- 20190826@Percy: Remove inactive products [RedmineID: #118699]
	- 20200410@Sophia: Add BBIN, Sexy Gaming, SA Gaming [RedmineId: #131358]
	- 20200422@Sophia: Add IBCBet Live Casino [RedmineId: #130693]
	- 20200521@Patrick: Enhance SP due to bot attack [redmind: #134415]
	- 20200527@Sophia: Add ION [Redmine: #132325]
	- 20200528@Sophia: Add RNG War [Redmine: #132013]
	- 20200909@Malcolm: Report Enhancement for Jackpot Product [RedmineID : #139575]
	- 20200915@Malcolm: Add WM Live Casino [Redmine : #131584]
	- 20201201@Malcolm : Add Gold Diamond Gaming [Redmine : #144110]
	- 20201210@Malcolm: Add Big Gaming [RedmineId : #142459]
	- 20210310@Malcolm: Add Pragmatic Live Casino [RedmineId : #133717]
	- 20210617@Sol: changed how to calc net turn over - [RedmineId : #156653]
	
	Param's Explanation:
	 @ProductDetails:		
		<ROOT>
				<ProductDetail ProductId = "32" Sporttype = "248" Bettype = "0"/>
				<ProductDetail ProductId = "32" Sporttype = "248" Bettype = "4298"/>
		</ROOT>	
*/

BEGIN
	SET NOCOUNT ON;

	DECLARE @RowStart	INT,
			@RowEnd		INT

	SELECT	@PageIndex = @PageIndex - 1,
			@RowStart = @PageSize * @PageIndex + 1,
			@RowEnd = @RowStart + @PageSize - 1;

	CREATE TABLE #SAgWinLossDetails
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
		SAgWinLost		MONEY,
		SAgComm			MONEY,
		NoOfTicket		INT
	);

	CREATE TABLE #TmpCondSumWL(
		SportType	INT,
		BetType		INT
	);

	DECLARE @ExistingProductDetails TABLE (ProductId INT,Sporttype INT,Bettype INT)
	DECLARE @isTest BIT, @__ProductDetails XML;

	SELECT  @isTest = dbo.f_CheckSPVersion(@@PROCID);	

	SELECT @ProductIds = dbo.f_AddRelatedProducts(@ProductIds);

	IF ISNULL(@ProductDetails,'') = ''
	BEGIN 
		INSERT INTO @ExistingProductDetails
		(
			ProductId
			,Sporttype
			,Bettype
		)
		VALUES(NULL, NULL, NULL)
	END
	ELSE IF ISNULL(@ProductDetails,'')  = 'All'
	BEGIN
		INSERT INTO @ExistingProductDetails
		(
			ProductId
			,Sporttype
			,Bettype
		)
		SELECT 
			ProductId
			,Sporttype
			,Bettype
		FROM dbo.f_GetProductDetail() f
	END
	ELSE 		
	BEGIN	
		SELECT @__ProductDetails = CONVERT(XML, @ProductDetails)

		INSERT INTO @ExistingProductDetails
		(
			ProductId
			,Sporttype
			,Bettype
		)
		SELECT 
			t.c.value('(@ProductId)[1]', 'SMALLINT') AS ProductID
			, t.c.value('(@Sporttype)[1]', 'SMALLINT') AS Sporttype
			, t.c.value('(@Bettype)[1]', 'SMALLINT') AS Bettype
		FROM @__ProductDetails.nodes('ROOT/ProductDetail') t(c)
	END

	INSERT INTO #TmpCondSumWL(SportType, BetType) 
	SELECT f.SportType, f.BetType
	FROM dbo.f_SumWinloss_ConditionSel(@ProductIds) f
		LEFT JOIN @ExistingProductDetails e ON f.ProductID = e.ProductId
	WHERE e.ProductId IS NULL OR (e.Bettype = f.BetType)

	-----Get Special Super to hide data of them before specific date 
	DECLARE @IsHide BIT = 0;

	IF EXISTS (	SELECT 1 
				FROM dbo.f_SpecialSuper() 
				WHERE Srecommend = @CustID)
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

	IF @ToDate >= @BalanceUpDay
	BEGIN 
		IF @FromDate <= @MoveBetsDay
		BEGIN
			SET @FDate = DATEADD(DD, 1, @MoveBetsDay);
		END

		INSERT INTO #SAgWinLossDetails(CustID, TurnOver, TurnoverNoDraw, GrossComm, MemberWinLost, PlayerComm, AgWinLost, AgComm, MAgWinLost, MAgComm, SAgWinLost, SAgComm, NoOfTicket)
		SELECT	MRecommend,
				SUM(ABS(b.stake)) as TurnOver,
				SUM(CASE WHEN cont.ContributionBettype IS NULL 
							THEN
								CASE
									WHEN b.StatusID IN (112,113) AND b.MOdds IN (-0.25, 0.25) AND s.ProductId = 1 THEN ABS(b.stake)/2
									WHEN b.StatusID = 111 AND s.ProductId IN (1) THEN 0 -- Sportsbook
									WHEN s.IsUsingOddsSpread = 1 THEN b.oddsspread -- LC and RNG
									ELSE ABS(b.stake) 
								END
							ELSE 0
						END
					) AS TurnoverNoDraw,
				SUM(CASE WHEN tpositiontaking = 1 THEN 0 ELSE scomm/(1 - tpositiontaking) END) AS GrossComm,
				SUM(winlost - actual_stake) AS MemberWinlost,
				SUM(playercomm) AS PlayerComm,
				SUM(awinlost) AS AgWinlost,
				ISNULL(SUM(comm - playercomm),0) AS AgComm,
				SUM(mwinlost) AS MAgWinlost,
				SUM(acomm)-SUM(comm) AS MAgComm,
				SUM(swinlost) AS SAgWinlost,
				ISNULL(SUM(scomm),0) - ISNULL(SUM(acomm),0) AS SAgComm,
				COUNT(1) AS NoOfTicket
		FROM dbo.bettrans b WITH(NOLOCK)
			INNER JOIN (
						SELECT ISNULL(p.GroupProductId, f.ProductID) AS ProductID, f.BetType, 
								CASE 
									WHEN f.RefTable IN (1, 2) OR ISNULL(p.GroupProductId, f.ProductID) = 47 THEN 1 
									ELSE 0 
								END AS IsUsingOddsSpread
						FROM dbo.f_SportBettypeMatrixByProduct_Sel(@ProductIds, @IsTest) f
							LEFT JOIN dbo.f_GroupProduct() p ON f.ProductID = p.ProductId
							LEFT JOIN @ExistingProductDetails e ON e.ProductId = f.ProductID 
						WHERE EXISTS(SELECT 1
									 WHERE e.ProductId IS NULL 
										OR 
											(
												e.Bettype = f.BetType 
													  OR (
															e.Bettype = 0 AND f.BetType NOT IN (SELECT g.Bettype FROM f_GetProductDetail() g)
													     )
											)
									)												
						) s ON b.bettype = s.Bettype
			OUTER APPLY 
			(
				SELECT f.Bettype AS ContributionBettype
				FROM dbo.f_BettypePrizeGroup() f
				WHERE f.BettypeGroup = 'Contribution'
					AND f.Bettype = b.bettype
			) cont
		WHERE winlostdate BETWEEN @FDate AND @Tdate
			AND srecommend = @CID
			AND b.statusID IN (111, 112, 113) 
		GROUP BY MRecommend, b.bettype

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
		
		INSERT INTO #SAgWinLossDetails(CustID, TurnOver, TurnoverNoDraw, GrossComm, MemberWinLost, PlayerComm, AgWinLost, AgComm, MAgWinLost, MAgComm, SAgWinLost, SAgComm, NoOfTicket)
		SELECT	CustID,			
				SUM(ABS(TurnOver)) AS TurnOver,
				SUM(ABS(TunroverNoDraw)) AS TurnoverNoDraw,
				SUM(grosscomm) AS GrossComm,
				SUM(winlost) AS MemberWinlost,
				SUM(playercomm) AS PlayerComm,
				SUM(awinlost) AS AgWinlost,
				ISNULL(SUM(comm - playercomm),0) AS AgComm,
				SUM(mwinlost) AS MAgWinlost,
				SUM(acomm) - SUM(comm) AS MAgComm,
				SUM(swinlost) AS SAgWinlost,
				ISNULL(SUM(scomm),0) - ISNULL(SUM(acomm),0) AS SAgComm,
				SUM(betcount) AS NoOfTicket
		FROM dbo.SUM_winloss b WITH(NOLOCK)
			INNER JOIN #TmpCondSumWL t ON b.sporttype = t.sporttype AND b.bettype = t.bettype
		WHERE winlostdate BETWEEN @FDate AND @TDate
			AND SRecommend = @CID
			AND RoleID = 3
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
		;WITH CTE_Winlostdate (winlostdate, sporttype, bettype) AS
		(
			SELECT @FDate AS winlostdate, SportType, BetType
			FROM #TmpCondSumWL
			UNION ALL
			SELECT DATEADD(DAY, 1, winlostdate), SportType, BetType
			FROM CTE_Winlostdate
			WHERE winlostdate < @TDate
		)
		INSERT INTO #SAgWinLossDetails(CustID, TurnOver, TurnoverNoDraw, GrossComm, MemberWinLost, PlayerComm, AgWinLost, AgComm, MAgWinLost, MAgComm, SAgWinLost, SAgComm, NoOfTicket)
		SELECT	CustID,			
				SUM(ABS(TurnOver)) AS TurnOver,
				SUM(ABS(TunroverNoDraw)) AS TurnoverNoDraw,
				SUM(grosscomm) AS GrossComm,
				SUM(winlost) AS MemberWinlost,
				SUM(playercomm) AS PlayerComm,
				SUM(awinlost) AS AgWinlost,
				ISNULL(SUM(comm - playercomm),0) AS AgComm,
				SUM(mwinlost) AS MAgWinlost,
				SUM(acomm) - SUM(comm) AS MAgComm,
				SUM(swinlost) AS SAgWinlost,
				ISNULL(SUM(scomm),0) - ISNULL(SUM(acomm),0) AS SAgComm,
				SUM(betcount) AS NoOfTicket
		FROM bodb_Summary.dbo.Sum_WinLoss_Old b WITH(NOLOCK)
			CROSS APPLY CTE_Winlostdate w
		WHERE b.winlostdate = w.winlostdate
			AND b.srecommend = @custid
			AND b.mrecommend = b.mrecommend
			AND b.recommend = b.recommend
			AND b.RoleID = 3
			AND b.sporttype = w.sporttype
			AND b.bettype = w.bettype
		GROUP BY CustID
		OPTION (MAXRECURSION 0);
	END	

	IF ((@PageSize <= 0) AND (@PageIndex <= 0))
	BEGIN
		SELECT	w.CustID AS CustId, 
				c.UserName AS CustName, 
				SUM(TurnOver) as Turnover,
				SUM(TurnoverNoDraw) as NetTurnover,
				SUM(GrossComm) as GrossComm,
				SUM(MemberWinLost) as MemberWinLoss,
				SUM(PlayerComm) as MemberComm,
				SUM(AgWinlost) as AgWinLoss,
				SUM(AgComm) as AgComm,
				SUM(MAgWinlost) as MAgWinLoss,
				SUM(MAgComm) as MAgComm,
				SUM(SAgWinlost) as SAgWinLoss,
				SUM(SAgComm) as SAgComm,
				SUM(NoOfTicket) as NumberOfTickets
		FROM #SAgWinLossDetails w 
			INNER JOIN dbo.custinfo c WITH(NOLOCK) ON w.CustID = c.CustID
		GROUP BY w.CustID, c.UserName
		ORDER BY c.Username;

		SELECT	NULL AS CustId,
				'Total' AS CustName,
				SUM(TurnOver) as Turnover,
				SUM(TurnoverNoDraw) as NetTurnover,
				SUM(GrossComm) as GrossComm,
				SUM(MemberWinLost) as MemberWinLoss,
				SUM(PlayerComm) as MemberComm,
				SUM(AgWinlost) as AgWinLoss,
				SUM(AgComm) as AgComm,
				SUM(MAgWinlost) as MAgWinLoss,
				SUM(MAgComm) as MAgComm,
				SUM(SAgWinlost) as SAgWinLoss,
				SUM(SAgComm) as SAgComm,
				SUM(NoOfTicket) as NumberOfTickets
		FROM #SAgWinLossDetails;

		RETURN;
	END

	IF @TotalRecords = 0  
	BEGIN  
		SELECT @TotalRecords = count(tmp.CustID)
		FROM (
			SELECT CustID
			FROM #SAgWinLossDetails
			GROUP BY CustID
		) tmp;
 
	END

	SELECT wl.*
	FROM (
		SELECT	w.CustID AS CustId, 
				c.UserName AS CustName, 
				SUM(TurnOver) as Turnover,
				SUM(TurnoverNoDraw) as NetTurnover,
				SUM(GrossComm) as GrossComm,
				SUM(MemberWinLost) as MemberWinLoss,
				SUM(PlayerComm) as MemberComm,
				SUM(AgWinlost) as AgWinLoss,
				SUM(AgComm) as AgComm,
				SUM(MAgWinlost) as MAgWinLoss,
				SUM(MAgComm) as MAgComm,
				SUM(SAgWinlost) as SAgWinLoss,
				SUM(SAgComm) as SAgComm,
				SUM(NoOfTicket) as NumberOfTickets,
				ROW_NUMBER() over(order by c.UserName) as RowNum
		FROM #SAgWinLossDetails w 
			INNER JOIN dbo.custinfo c WITH(NOLOCK) ON w.CustID = c.CustID
		GROUP BY w.CustID, c.UserName
	) wl
	WHERE wl.RowNum BETWEEN @RowStart AND @RowEnd;

	SELECT	NULL AS CustId,
			'Total' AS CustName,
			SUM(TurnOver) as Turnover,
			SUM(TurnoverNoDraw) as NetTurnover,
			SUM(GrossComm) as GrossComm,
			SUM(MemberWinLost) as MemberWinLoss,
			SUM(PlayerComm) as MemberComm,
			SUM(AgWinlost) as AgWinLoss,
			SUM(AgComm) as AgComm,
			SUM(MAgWinlost) as MAgWinLoss,
			SUM(MAgComm) as MAgComm,
			SUM(SAgWinlost) as SAgWinLoss,
			SUM(SAgComm) as SAgComm,
			SUM(NoOfTicket) as NumberOfTickets
	FROM #SAgWinLossDetails;

	DROP TABLE #SAgWinLossDetails;
	DROP TABLE #TmpCondSumWL;

	SET NOCOUNT OFF;
END

GO