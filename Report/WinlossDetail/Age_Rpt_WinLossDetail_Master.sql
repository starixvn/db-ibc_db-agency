USE [bodb02]
GO

/****** Object:  StoredProcedure [dbo].[Age_Rpt_WinLossDetail_Master]    Script Date: 10/26/2016 10:34:04 AM ******/
IF OBJECT_ID('[dbo].[Age_Rpt_WinLossDetail_Master]') IS NOT NULL
	DROP PROCEDURE [dbo].[Age_Rpt_WinLossDetail_Master]
GO

/****** Object:  StoredProcedure [dbo].[Age_Rpt_WinLossDetail_Master]    Script Date: 10/26/2016 10:34:04 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[Age_Rpt_WinLossDetail_Master]
	@CustID			INT = NULL, --recommend
	@FromDate		SMALLDATETIME,
	@ToDate			SMALLDATETIME,
	@ProductIds		VARCHAR(MAX),
	@BalanceUpDay	SMALLDATETIME,
	@PageSize		INT = 0,
	@PageIndex		INT = 0,
	@TotalRecords	INT = 0 OUTPUT


AS

/*
Created: 
Task : Smartphone friendly - Win Loss Detail Report
DB: DBAGE/bodb02
Original SP: Age_Rpt_WinLossDetail_SAg
			Change SP name suffix to match with web function
Revisions:
	- 20161024@Paul: Smartphone Friendly UI for Microsite Report - [Redmine: #61531]
	
*/

BEGIN
	SET NOCOUNT ON;

	DECLARE @RowStart INT,
			@RowEnd INT;  

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
	(9, 253, 1000), --P2P
	(2, 151, 0), --Racing
	(3, 161, 0), --Number Game
	(7, 252, 73), --Bingo
	(4, 162, 0), --Live Casino
	(5, 180, 0), --Virtual Sports
	(8, 202, 0), --Keno
	(12, 255, 0), --Gold Deluxe
	(15, 204, 0), --Colossus Bets
	--(19, 206, 1003), --Cockfighting
	(21, 211, 0), --Allbet
	(22, 212, 0); --Macau Games

	DELETE tmp
	FROM #TmpCondSumWL tmp
		LEFT JOIN #SelectedProducts sp ON tmp.ProductID = sp.ProductID
	WHERE sp.ProductID IS NULL;

	DECLARE @isTest BIT;

	SELECT  @isTest = dbo.f_CheckSPVersion(@@PROCID);

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
			@BUDate	SMALLDATETIME,
			@CID	INT;
	    
	SELECT	@FDate = @FromDate,
			@TDate = @ToDate,
			@BUDate = @BalanceUpDay,
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

	IF @TDate >= @BUDate
	BEGIN 
		INSERT INTO #SAgWinLossDetails(CustID, TurnOver, TurnoverNoDraw, GrossComm, MemberWinLost, PlayerComm, AgWinLost, AgComm, MAgWinLost, MAgComm, SAgWinLost, SAgComm, NoOfTicket)
		SELECT	MRecommend,
				SUM(case when b.liveawayscore = 0 and b.bettype in (33, 43) then ABS(b.stake)/2 else ABS(b.stake) end) as TurnOver,
				SUM(CASE WHEN b.liveawayscore = 0 and b.bettype in(33,43) THEN ABS(b.stake)/2 
						WHEN b.StatusID IN (112,113) AND b.MOdds IN (-0.25, 0.25) AND s.ProductId = 1 THEN ABS(b.stake)/2
						WHEN b.StatusID = 111 AND s.ProductId = 1 THEN 0 
						WHEN s.ProductID = 21 THEN b.oddsspread -- Allbet
						ELSE ABS(b.stake) 
					END) AS TurnoverNoDraw,
				SUM(case when b.bettype = 1000 then oddsspread else case when tpositiontaking = 1 then 0 else scomm/(1 - tpositiontaking) end end) as GrossComm,
				SUM(winlost - actual_stake) AS MemberWinlost,
				SUM(playercomm) AS PlayerComm,
				SUM(awinlost) AS AgWinlost,
				ISNULL(SUM(comm - playercomm),0) AS AgComm,
				SUM(mwinlost) AS MAgWinlost,
				SUM(acomm)-SUM(comm) AS MAgComm,
				SUM(swinlost) AS SAgWinlost,
				ISNULL(SUM(scomm),0) - ISNULL(SUM(acomm),0) AS SAgComm,
				COUNT(CASE WHEN b.bettype = 500 THEN NULL ELSE b.transid END) AS NoOfTicket
		FROM dbo.bettrans b WITH(NOLOCK, index = IX_srecommend)
			INNER JOIN @SportBettypeMatrix s ON b.bettype = s.Bettype
		WHERE winlostdate between @FDate and @Tdate
			AND srecommend = @CID
			AND b.statusID not in (0, 1, 101, 102, 103) 
		GROUP BY MRecommend, b.bettype;

		IF @BUDate < @FDate
		BEGIN
			SELECT @BUDate=@FDate;
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
		WHERE winlostdate BETWEEN @BUDate AND @TDate
			AND SRecommend = @CID
			AND RoleID = 3
		GROUP BY CustID;
	END

	IF @FDate < @BUDate 
	BEGIN
		IF @TDate >= DATEADD(dd, -1, @BUDate)
		BEGIN
			SELECT @TDate = DATEADD(dd, -1, @BUDate);
		END
		
		IF @FDate < '2016-06-01' AND @IsHide = 1 AND @LoginName <> 'bodbDownlineNetView' --- acc internal login 
		BEGIN
			SELECT @FDate = '2016-06-01';
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
		FROM bodb_Summary.dbo.Sum_WinLoss_Old b WITH(NOLOCK)
			INNER JOIN #TmpCondSumWL t ON b.sporttype = t.sporttype AND b.bettype = t.bettype
		WHERE winlostdate BETWEEN @FDate AND @TDate			
			AND Srecommend = @custid
			AND Mrecommend = Mrecommend
			AND recommend = recommend
			AND RoleID = 3
		GROUP BY CustID;
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
	DROP TABLE #SelectedProducts;
	DROP TABLE #TmpCondSumWL;

	SET NOCOUNT OFF;
END
GO

GRANT EXECUTE ON [dbo].[Age_Rpt_WinLossDetail_Master] TO [bodbDownlineNet] AS [dbo]
GO

GRANT EXECUTE ON [dbo].[Age_Rpt_WinLossDetail_Master] TO [bodbDownlineNetView] AS [dbo]
GO


