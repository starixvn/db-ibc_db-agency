USE [bodb02]
GO

/****** Object:  StoredProcedure [dbo].[Age_Rpt_WinLossDetail_Agent]    Script Date: 10/26/2016 8:20:21 AM ******/
IF OBJECT_ID('[dbo].[Age_Rpt_WinLossDetail_Agent]') IS NOT NULL
	DROP PROCEDURE [dbo].[Age_Rpt_WinLossDetail_Agent]
GO

/****** Object:  StoredProcedure [dbo].[Age_Rpt_WinLossDetail_Agent]    Script Date: 10/26/2016 8:20:21 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[Age_Rpt_WinLossDetail_Agent] 
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
Original SP: Age_Rpt_WinLossDetail_MAg_New
			Change SP name suffix to match with web function
Revisions:
	- 20161024@Paul: Smartphone Friendly UI for Microsite Report [RedmineID: #61531]
*/

BEGIN

	SET NOCOUNT ON

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

	CREATE TABLE #SelectedProducts(
		ProductID TINYINT
	);

	CREATE TABLE #TmpCondSumWL(
		ProductID	TINYINT,
		SportType	INT,
		BetType		INT
	);

	INSERT INTO #SelectedProducts(ProductID)
	SELECT CAST(Val AS TINYINT)
	FROM dbo.Age_f_SplitString(@ProductIds, ',');

	INSERT INTO #TmpCondSumWL(ProductID, SportType, BetType) VALUES
	(1, 0, 0), --Sportsbook
	(6, 251, 71), (6, 208, 0), (6, 209, 0), (6, 210, 0), --RNG Casino
	--(9, 253, 1000), --P2P
	(2, 151, 0), --Racing
	(3, 161, 0), --Number Game
	--(7, 252, 73), --Bingo
	(4, 162, 0), --Live Casino
	(5, 180, 0), --Virtual Sports
	(8, 202, 0), --Keno
	(12, 255, 0), --Gold Deluxe
	(15, 204, 0), --Colossus Bets
	--(19, 206, 1003), --Cockfighting
	(21, 211, 0), --Allbet
	(22, 212, 0), --Macau Games
	(23, 213, 0), --NG2
	(24, 219, 0); --Fishing World

	DELETE tmp
	FROM #TmpCondSumWL tmp
		LEFT JOIN #SelectedProducts sp ON tmp.ProductID = sp.ProductID
	WHERE sp.ProductID IS NULL;

	DECLARE @isTest BIT;

	SELECT  @isTest = dbo.f_CheckSPVersion(@@PROCID);

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

	DECLARE @SportBettypeMatrix TABLE(
		ProductID	tinyint,
		BetType	smallint,
		EventType	tinyint,
		SubProduct	varchar(500),
		RefTable	tinyint,
		CasinoType	tinyint
	);

	INSERT INTO @SportBettypeMatrix(
		ProductID,
		BetType,
		EventType,
		SubProduct,
		RefTable,
		CasinoType
	)
	SELECT	s.ProductID,
			BetType,
			EventType,
			SubProduct,
			RefTable,
			CasinoType
	FROM dbo.f_SportBettypeMatrix_Sel(0, 0, 0, 2, '', '', @IsTest) s
		INNER JOIN #SelectedProducts p on p.ProductID = s.ProductID;

	IF @ToDate >= @BalanceUpDay
	BEGIN 
		IF @FromDate <= @MoveBetsDay
		BEGIN
			SET @FDate = DATEADD(DD, 1, @MoveBetsDay);
		END

		INSERT INTO #MAgWinLossDetails(CustID, TurnOver, TurnoverNoDraw, GrossComm, MemberWinLost, PlayerComm, AgWinLost, AgComm, MAgWinLost, MAgComm, NoOfTicket)
		SELECT	Recommend,			
				SUM(CASE WHEN b.liveawayscore = 0 AND b.bettype IN (33, 43) THEN ABS(b.stake)/2 ELSE ABS(b.stake) END) AS TurnOver, 
				SUM(CASE WHEN b.liveawayscore = 0 and b.bettype in(33,43) THEN ABS(b.stake)/2 
						WHEN b.StatusID IN (112,113) AND b.MOdds IN (-0.25, 0.25) AND s.ProductId = 1 THEN ABS(b.stake)/2
						WHEN b.StatusID = 111 AND s.ProductId = 1 THEN 0 
						WHEN s.ProductID = 21 THEN b.oddsspread -- Allbet
						ELSE ABS(b.stake) 
					END) AS TurnoverNoDraw,
				SUM(CASE WHEN b.bettype = 1000 THEN oddsspread ELSE CASE WHEN (apositiontaking + mpositiontaking = 1) THEN 0 ELSE acomm/(1 - apositiontaking - mpositiontaking) END END) AS GrossComm,
				SUM(winlost - actual_stake) AS MemberWinlost,
				SUM(playercomm) AS PlayerComm,
				SUM(awinlost) AS AgWinlost,
				ISNULL(SUM(comm - playercomm), 0) AS AgComm,
				SUM(mwinlost) AS MAgWinlost,
				SUM(acomm) - SUM(comm) AS MAgComm,
				COUNT(CASE WHEN b.bettype = 500 THEN NULL ELSE b.transid END) AS NoOfTicket
		FROM dbo.bettrans b WITH(NOLOCK)
			INNER JOIN @SportBettypeMatrix s ON b.bettype = s.Bettype
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
			INNER JOIN #TmpCondSumWL t ON b.sporttype = t.sporttype AND b.bettype = t.bettype
		WHERE winlostdate BETWEEN @FDate AND @TDate			
			AND Srecommend = @Srecommend --- Add Srecommend to get the index seek 
			AND MRecommend = @custid
			AND recommend = recommend
			AND RoleID = 2
		GROUP BY CustID;
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
	DROP TABLE #SelectedProducts;
	DROP TABLE #TmpCondSumWL;

	SET NOCOUNT OFF;
END
GO

GRANT EXECUTE ON [dbo].[Age_Rpt_WinLossDetail_Agent] TO [bodbDownlineNet] AS [dbo]
GO

GRANT EXECUTE ON [dbo].[Age_Rpt_WinLossDetail_Agent] TO [bodbDownlineNetView] AS [dbo]
GO


