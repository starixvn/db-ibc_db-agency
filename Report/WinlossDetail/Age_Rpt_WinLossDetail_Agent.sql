/*<info serverAlias="DBAGE-bodb02" executers="bodbDownlineNet,bodbDownlineNetView" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Age_Rpt_WinLossDetail_Agent] 
	@CustID			INT = NULL, --recommend
	@FromDate		SMALLDATETIME,
	@ToDate			SMALLDATETIME,
	@ProductIds		VARCHAR(MAX),
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
	- 20190826@Percy: Remove inactive products [RedmineID: #118699]
	- 20200410@Sophia: Add BBIN, Sexy Gaming, SA Gaming [RedmineId: #131358]
	- 20200422@Sophia: Add IBCBet Live Casino [RedmineId: #130693]
	- 20200521@Sophia: Enhance SP due to bot attack [redmind: #134415]
	- 20200528@Sophia: Add RNG War [Redmine: #132013]
*/

BEGIN
	SET NOCOUNT ON;

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
		NoOfTicket		INT
	)

	CREATE TABLE #TmpCondSumWL(
		SportType	INT,
		BetType		INT
	);

	DECLARE @isTest BIT;
	SELECT  @isTest = dbo.f_CheckSPVersion(@@PROCID);	

	SELECT @ProductIds = dbo.f_AddRelatedProducts(@ProductIds);

	INSERT INTO #TmpCondSumWL(SportType, BetType) 
	SELECT SportType, BetType
	FROM dbo.f_SumWinloss_ConditionSel(@ProductIds);

	------Get @Srecommend
	DECLARE @Srecommend int;

	SELECT @Srecommend = Srecommend 
	FROM dbo.CustInfo WITH(NOLOCK)
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

	
	IF @ToDate >= @BalanceUpDay
	BEGIN 
		IF @FromDate <= @MoveBetsDay
		BEGIN
			SET @FDate = DATEADD(DD, 1, @MoveBetsDay);
		END

		INSERT INTO #MAgWinLossDetails(CustID, TurnOver, TurnoverNoDraw, GrossComm, MemberWinLost, PlayerComm, AgWinLost, AgComm, MAgWinLost, MAgComm, NoOfTicket)
		SELECT	Recommend,			
				SUM(ABS(b.stake)) AS TurnOver, 
				SUM(CASE
						WHEN b.StatusID IN (112,113) AND b.MOdds IN (-0.25, 0.25) AND s.ProductId = 1 THEN ABS(b.stake)/2
						WHEN b.StatusID = 111 AND s.ProductId IN (1) THEN 0 -- Sportsbook
						WHEN s.ProductID IN (21, 39, 45, 46, 47, 50)  THEN b.oddsspread -- Allbet, SA Gaming, SexyGaming, IBCBet Live Casino, BBIN, RNG War
						ELSE ABS(b.stake) 
					END) AS TurnoverNoDraw,
				SUM(CASE WHEN (apositiontaking + mpositiontaking = 1) THEN 0 ELSE acomm/(1 - apositiontaking - mpositiontaking) END) AS GrossComm,
				SUM(winlost - actual_stake) AS MemberWinlost,
				SUM(playercomm) AS PlayerComm,
				SUM(awinlost) AS AgWinlost,
				ISNULL(SUM(comm - playercomm), 0) AS AgComm,
				SUM(mwinlost) AS MAgWinlost,
				SUM(acomm) - SUM(comm) AS MAgComm,
				COUNT(1) AS NoOfTicket
		FROM dbo.bettrans b WITH(NOLOCK)
			INNER JOIN (
						SELECT	ISNULL(p.GroupProductId, f.ProductID) AS ProductID, BetType
						FROM dbo.f_SportBettypeMatrixByProduct_Sel(@ProductIds, @IsTest) f
							LEFT JOIN dbo.f_GroupProduct() p ON f.ProductID = p.ProductId
						) s ON b.bettype = s.Bettype
		WHERE winlostdate BETWEEN @FDate AND @TDate
			AND statusID NOT IN (101, 102, 103)
			AND ruben = 1
			AND mrecommend = @CID
		GROUP BY Recommend, b.bettype;
		
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
			INNER JOIN #TmpCondSumWL t ON b.sporttype = t.sporttype AND b.bettype = t.bettype
		WHERE winlostdate BETWEEN @FDate AND @TDate			
			AND MRecommend = @CID
			AND RoleID = 2
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
		GROUP BY CustID
		OPTION (MAXRECURSION 0);
	END	

	IF ((@PageSize <= 0) AND (@PageIndex <= 0))
	BEGIN
		SELECT	w.CustID AS CustId, 
				c.UserName AS CustName, 
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
			INNER JOIN dbo.custInfo c WITH(NOLOCK) ON w.CustID = c.CustID 
		GROUP BY w.CustID, c.UserName
		ORDER BY c.Username;

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
		FROM #MAgWinLossDetails;

		RETURN;
	END

	IF @TotalRecords = 0  
	BEGIN  
		SELECT @TotalRecords = count(tmp.CustID)
		FROM (
			SELECT CustID
			FROM #MAgWinLossDetails
			GROUP BY CustID
		) tmp; 
	END

	SELECT wl.*
	FROM (
		SELECT	w.CustID AS CustId, 
				c.UserName AS CustName, 
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
				ROW_NUMBER() OVER (ORDER BY c.UserName) AS RowNum
		FROM #MAgWinLossDetails w
			INNER JOIN dbo.custInfo c WITH(NOLOCK) ON w.CustID = c.CustID 
		GROUP BY w.CustID, c.UserName
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
	FROM #MAgWinLossDetails;

	DROP TABLE #MAgWinLossDetails;
	DROP TABLE #TmpCondSumWL;

	SET NOCOUNT OFF;
END
GO