/*<info serverAlias="DBAGE-bodb02" executers="bodbDownlineNet,bodbDownlineNetView" isFunction="0" isNested="0"></info>*/
CREATE PROCEDURE [dbo].[Age_Rpt_API_WinLossDetail_Member]
	@CustID			 INT = NULL --recommend
	,@FromDate		 SMALLDATETIME
	,@ToDate		 SMALLDATETIME
	,@ProductIds	 VARCHAR(MAX)
	,@ProductDetails NVARCHAR(MAX) = 'All'
	,@BalanceUpDay	 SMALLDATETIME
	,@MoveBetsDay	 SMALLDATETIME
AS

/*
Created: 
Task : Support data through API - Win Loss Detail Report
DB: DBAGE/bodb02

Revisions:
	- 20221128@Eddie: Change from SP "Age_Rpt_WinLossDetail_Member" [RedmineID: #171247]
	- 20230511@Eddie: Enhance data range [RedmineID: #188033]
	- 20230707@Bobby: Support NetTO & GrossComm [RedmineID: #188035]
	
Param's Explanation:

*/

BEGIN
	SET NOCOUNT ON
	
	DECLARE @DateLimit SMALLDATETIME, @CurrentDate SMALLDATETIME
	SET @CurrentDate = CAST(GETDATE() AS DATE)
	
	SELECT @DateLimit = ISNULL(MinDate, DATEADD(DAY, - 1 * LimitDays, @CurrentDate))
	FROM dbo.Age_CustDateLimit l WITH (NOLOCK)
		INNER JOIN dbo.custInfo c WITH (NOLOCK) ON l.CustId = c.srecommend
	WHERE c.custId = @CustID
	
	IF @FromDate < @DateLimit
	BEGIN
		SELECT @FromDate = @DateLimit
	END

	CREATE TABLE #AgWinLossDetails(
		CustID			INT
		,TurnOver		MONEY
		,TurnoverNoDraw	MONEY
		,GrossComm		MONEY
		,MemberWinLost	MONEY
		,PlayerComm		MONEY
		,AgWinLost		MONEY
		,AgComm			MONEY
		,NoOfTicket		INT
	)

	CREATE TABLE #TmpCondSumWL(
		SportType		INT
		,BetType		INT
		,LeagueGroupID	SMALLINT
		,TicketType		TINYINT
	)

	DECLARE @ExistingProductDetails TABLE (ProductId INT, Sporttype INT, Bettype INT, LeagueGroupID SMALLINT, TicketType TINYINT)
	DECLARE @isTest BIT = 0, @__ProductDetails XML

	SELECT  @isTest = dbo.f_CheckSPVersion(@@PROCID)

	SELECT @ProductIds = dbo.f_AddRelatedProducts(@ProductIds)
	SELECT @__ProductDetails = CONVERT(XML, @ProductDetails)

	DECLARE @SeparateSabaSport_Cutoff SMALLDATETIME 

	SELECT @SeparateSabaSport_Cutoff = CutoffDate
	FROM dbo.f_GetCutoffDate()
	WHERE TypeName = 'SabaSport'

	INSERT INTO @ExistingProductDetails(ProductId, Sporttype, Bettype, LeagueGroupID, TicketType)
	SELECT ProductId, Sporttype, Bettype, LeagueGroupID, TicketType
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
	DECLARE @Srecommend INT, @Mrecommend INT
	  
	SELECT	@Srecommend  =  Srecommend
			,@Mrecommend =  Mrecommend 
	FROM dbo.CustInfo WITH(NOLOCK) 
	WHERE CustID = @CustID

	-----Get Special Super to hide data of them before specific date 
	DECLARE @IsHide BIT = 0

	IF EXISTS (SELECT 1 FROM dbo.f_SpecialSuper() WHERE Srecommend = @Srecommend)
	BEGIN
		SELECT @IsHide = 1
	END
		
	----Get Account Login to detect Interal or not
	DECLARE @LoginName NVARCHAR(128)
	SELECT @LoginName = SUSER_NAME()

	--Avoid Parameter Sniffing
	DECLARE @FDate SMALLDATETIME, @TDate SMALLDATETIME, @CID INT
	    
	SELECT	@FDate  = @FromDate
			,@TDate = @ToDate
			,@CID   = @custid
			
	IF @ToDate >= @BalanceUpDay
	BEGIN 
		IF @FromDate <= @MoveBetsDay
		BEGIN
			SET @FDate = DATEADD(DD, 1, @MoveBetsDay)
		END

		INSERT INTO #AgWinLossDetails(CustID, TurnOver, TurnoverNoDraw, GrossComm, MemberWinLost, PlayerComm, AgWinLost, AgComm, NoOfTicket)
		SELECT b.custid
			   ,SUM(ABS(b.stake)) 				AS TurnOver
			   ,SUM(CASE
						WHEN s.RefTable IN (1, 2) THEN 0 -- bettransRnG/bettransLC
						WHEN s.ProductId = 47 THEN b.oddsspread -- BBIN
						WHEN s.ProductId = 1 AND b.statusId = 111 THEN 0 -- SB draw
						WHEN s.ProductId = 1 AND b.StatusId IN (112, 113) AND b.modds IN (-0.25, 0.25) THEN ABS(b.stake)/2 -- SB half won/lose
						ELSE ABS(b.stake)
					END) AS TurnoverNoDraw
				,SUM(CASE
						WHEN s.RefTable IN (1, 2) THEN 0
						WHEN b.apositiontaking = 1 THEN 0
						ELSE b.comm/(1 - b.apositiontaking)
					END) AS GrossComm
			   ,SUM(b.winlost - b.actual_stake) AS MemberWinLost
			   ,SUM(b.playercomm) 				AS PlayerComm
			   ,SUM(b.awinlost) 				AS AgWinlost
			   ,SUM(b.comm - b.playercomm) 		AS AgComm
			   ,COUNT(1) 						AS NoOfTicket
		FROM dbo.bettrans b WITH (NOLOCK)
			INNER JOIN (
				SELECT f.ProductID, f.BetType, f.RefTable
				FROM (  
						SELECT DISTINCT ma.ProductID, ma.BetType, ma.RefTable
						FROM  dbo.SportBettypeMatrix ma WITH(NOLOCK)
						WHERE ',' + @ProductIDs + ',' LIKE '%,' + cast(ma.ProductID as varchar(3)) + ',%'
							AND (ma.IsTest = 0 OR ma.IsTest = @IsTest)
						) f
			) s ON b.bettype = s.bettype
		WHERE b.winlostdate BETWEEN @FDate AND @TDate
			AND b.recommend = @CID
			AND b.statusID IN (111, 112, 113)
		GROUP BY b.custid, b.bettype

		IF @BalanceUpDay < @FromDate
		BEGIN
			SET @FDate = @FromDate
		END
		ELSE
		BEGIN
			SET @FDate = @BalanceUpDay
		END
		
		IF @ToDate > @MoveBetsDay
		BEGIN
			SET @TDate = @MoveBetsDay
		END
		
		INSERT INTO #AgWinLossDetails(CustID, TurnOver, TurnoverNoDraw, GrossComm, MemberWinLost, PlayerComm, AgWinLost, AgComm, NoOfTicket)
		SELECT	b.custid		
				,SUM(ABS(b.turnover)) 		AS TurnOver
				,SUM(TunroverNoDraw)		AS TurnoverNoDraw
				,SUM(GrossComm)				AS GrossComm
				,SUM(b.winlost) 			AS MemberWinLost
				,SUM(b.playercomm) 			AS PlayerComm
				,SUM(b.awinlost) 			AS AgWinLost
				,SUM(b.comm - b.playercomm) AS AgComm
				,SUM(b.BetCount) 			AS NoOfTicket
		FROM dbo.sum_winloss b WITH (NOLOCK) 
			INNER JOIN #TmpCondSumWL t ON b.sporttype = t.sporttype AND b.bettype = t.bettype AND ISNULL(b.leagueGroupID,0) = t.LeagueGroupID AND ISNULL(b.ticketType,0) = t.TicketType
		WHERE b.winlostdate BETWEEN @FDate AND @TDate			
			AND b.recommend = @CID
			AND b.roleid = 1
		GROUP BY b.custid
	END

	SELECT	@FDate = @FromDate,
			@TDate = @ToDate

	IF @FromDate < @BalanceUpDay 
	BEGIN
		IF @ToDate >= DATEADD(DD, -1, @BalanceUpDay)
		BEGIN
			SELECT @TDate = DATEADD(DD, -1, @BalanceUpDay)
		END
	
		IF @FromDate < '2016-06-01' AND @IsHide = 1 AND @LoginName <> 'bodbDownlineNetView' --- acc internal login 
		BEGIN
			SELECT @FDate = '2016-06-01'
		END

		-- using cte to remove predicate when seek on sum_winloss_old
		;WITH CTE_Winlostdate (winlostdate, sporttype, bettype, LeagueGroupID, TicketType) AS
		(
			SELECT @FDate AS winlostdate, SportType, BetType, LeagueGroupID, TicketType
			FROM #TmpCondSumWL
			WHERE @FDate <= @TDate
			UNION ALL
			SELECT DATEADD(DAY, 1, winlostdate), SportType, BetType, LeagueGroupID, TicketType
			FROM CTE_Winlostdate
			WHERE winlostdate < @TDate
		)
		INSERT INTO #AgWinLossDetails(CustID, TurnOver, TurnoverNoDraw, GrossComm, MemberWinLost, PlayerComm, AgWinLost, AgComm, NoOfTicket)
		SELECT b.custid	
			   ,SUM(ABS(b.turnover)) 		AS TurnOver
			   ,SUM(TunroverNoDraw)			AS TurnoverNoDraw
			   ,SUM(GrossComm)				AS GrossComm
			   ,SUM(b.winlost) 				AS MemberWinLost
			   ,SUM(b.playercomm) 			AS PlayerComm
			   ,SUM(b.awinlost) 			AS AgWinLost
			   ,SUM(b.comm - b.playercomm) 	AS AgComm
			   ,SUM(b.BetCount) 			AS NoOfTicket
		FROM bodb_Summary.dbo.Sum_WinLoss_Old b WITH(NOLOCK) 
			CROSS APPLY CTE_Winlostdate w
		WHERE b.winlostdate = w.winlostdate
			AND b.srecommend = @srecommend
			AND b.mrecommend = @mrecommend
			AND b.recommend = @custid
			AND b.roleid = 1
			AND b.sporttype = w.sporttype
			AND b.bettype = w.bettype
			AND ISNULL(b.leagueGroupID,0) = w.leagueGroupID
			AND ISNULL(b.ticketType,0) = w.ticketType
			AND ISNULL(b.LeagueGroupID,0) = w.LeagueGroupID
			AND ISNULL(b.TicketType,0) = w.TicketType
		GROUP BY b.custid
		OPTION (MAXRECURSION 0)
	END

	SELECT wl.CustId, wl.CustName, wl.Turnover, wl.TurnoverNoDraw, wl.GrossComm, wl.MemberWinLoss, wl.MemberComm, wl.AgWinLoss, wl.AgComm, wl.NumberOfTickets, wl.RowNum
	FROM (
		SELECT w.CustID 			AS CustId
			   ,c.UserName 			AS CustName
			   ,SUM(TurnOver) 		AS Turnover
			   ,SUM(TurnoverNoDraw)	AS TurnoverNoDraw
			   ,SUM(GrossComm)		AS GrossComm
			   ,SUM(MemberWinLost) 	AS MemberWinLoss
			   ,SUM(PlayerComm) 	AS MemberComm
			   ,SUM(AgWinlost) 		AS AgWinLoss
			   ,SUM(AgComm) 		AS AgComm
			   ,SUM(NoOfTicket) 	AS NumberOfTickets
			   ,ROW_NUMBER() OVER (ORDER BY c.UserName) AS RowNum	
		FROM #AgWinLossDetails w 
			INNER JOIN dbo.custInfo c WITH(NOLOCK) ON w.CustID = c.CustID 
		GROUP BY w.CustID, c.UserName
	) wl

	SELECT NULL 				AS CustId
		   ,'Total' 			AS CustName
		   ,SUM(TurnOver) 		AS Turnover
		   ,SUM(TurnoverNoDraw)	AS TurnoverNoDraw
		   ,SUM(GrossComm)		AS GrossComm
		   ,SUM(MemberWinLost) 	AS MemberWinLoss
		   ,SUM(PlayerComm) 	AS MemberComm
		   ,SUM(AgWinlost) 		AS AgWinLoss
		   ,SUM(AgComm) 		AS AgComm
		   ,SUM(NoOfTicket) 	AS NumberOfTickets
	FROM #AgWinLossDetails

	DROP TABLE #AgWinLossDetails
	DROP TABLE #TmpCondSumWL

	SET NOCOUNT OFF
END 
GO