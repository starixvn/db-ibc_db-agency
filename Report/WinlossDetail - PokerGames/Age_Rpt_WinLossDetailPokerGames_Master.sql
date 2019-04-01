/*<info serverAlias="DBAGE-bodb02" executers="bodbDownlineNet,bodbDownlineNetView" isFunction="0" isNested="0"></info>*/
USE [bodb02]
GO

ALTER PROCEDURE [dbo].[Age_Rpt_WinLossDetailPokerGames_Master]
	@CustID			INT = NULL, --srecommend
	@FromDate		SMALLDATETIME,
	@ToDate			SMALLDATETIME,
	@ProductIds		VARCHAR(MAX) = '33',
	@BalanceUpDay	SMALLDATETIME,
	@MoveBetsDay	SMALLDATETIME,
	@PageSize		INT = 0,
	@PageIndex		INT = 0,
	@TotalRecords	INT = 0 OUTPUT
AS

/*
	Created: 	20180912@Sophia
	Task : 		Poker Games Win Loss Detail Report [RedmineID: #101376]
	DB: 		DBAGE/bodb02
	
	Revisions:
		- 20180912@Sophia: Initial SP [RedmineID: #101376]
		- 20190327@Percy: Add Video Poker Games [RedmineID: #107703]
*/

BEGIN
	SET NOCOUNT ON;

	DECLARE @RowStart	INT,
			@RowEnd		INT;
		
	SELECT	@PageIndex = @PageIndex - 1,
			@RowStart = @PageSize * @PageIndex + 1,
			@RowEnd = @RowStart + @PageSize - 1;

	CREATE TABLE #TempData
	(
		mrecommend				INT
		,bettype				INT
		,roundCount				INT
		,turnover				MONEY
		,netTurnover			MONEY
		,taxComm				MONEY
		,InsGemMemberWinLoss	MONEY
		,winlost				MONEY
		,awinlost				MONEY
		,mwinlost				MONEY
		,swinlost				MONEY
		,playercomm				MONEY
		,comm					MONEY
		,acomm					MONEY
		,scomm					MONEY
		
	)

	---- Avoid Parameter Sniffing
	DECLARE @FDate	SMALLDATETIME,
			@TDate	SMALLDATETIME,
			@CID	INT;
	    
	SELECT	@FDate = @FromDate,
			@TDate = @ToDate, 
			@CID = @custid;

	---- SportBettypeMatrix
	DECLARE @isTest BIT;
	SELECT  @isTest = dbo.f_CheckSPVersion(@@PROCID);
	
	DECLARE @SportBettypeMatrix TABLE (BetType SMALLINT);

	INSERT INTO @SportBettypeMatrix (BetType)
	SELECT DISTINCT BetType
	FROM dbo.f_SportBettypeMatrixByProduct_Sel(@ProductIds, @IsTest);

	---- Get data
	IF @ToDate > @MoveBetsDay
	BEGIN
		SELECT	@TDate = @ToDate,
				@FDate = CASE WHEN @FromDate <= @MoveBetsDay THEN DATEADD(DAY, 1, @MoveBetsDay) ELSE @FromDate END;

		INSERT INTO #TempData
		(
			mrecommend, bettype, roundCount
			,turnover, netTurnover, taxComm, InsGemMemberWinLoss
			,winlost, awinlost, mwinlost, swinlost
			,playercomm, comm, acomm, scomm
		)
		SELECT
			b.mrecommend
			,CASE WHEN b.bettype BETWEEN 1901 AND 1999 THEN 1901 ELSE 0 END AS bettype
			,SUM(ISNULL(b.betid, 0)) AS roundCount
			,SUM(ABS(ISNULL(b.stake, 0))) AS turnover
			,SUM(CASE
					WHEN b.bettype = 1499 OR b.bettype BETWEEN 1901 AND 1999 THEN ABS(b.stake)
					ELSE ISNULL(CAST(('<xml>' + b.ExtraInfo + '</xml>') AS XML).value('data(/xml/p33/@to)[1]','MONEY'), 0)
					END) AS netTurnover
			,SUM(ISNULL(b.oddsspread, 0)) AS taxComm
			,SUM(ISNULL(b.transid2, 0) / CONVERT(DECIMAL(19, 8), 10000)) AS InsGemMemberWinLoss
			,SUM(ISNULL(b.winlost, 0) - ISNULL(b.actual_stake, 0)) AS winlost
			,SUM(ISNULL(b.awinlost, 0)) AS awinlost
			,SUM(ISNULL(b.mwinlost, 0)) AS mwinlost
			,SUM(ISNULL(b.swinlost, 0)) AS swinlost
			,SUM(ISNULL(b.playercomm, 0)) AS playercomm
			,SUM(ISNULL(b.comm, 0)) AS comm
			,SUM(ISNULL(b.acomm, 0)) AS acomm
			,SUM(ISNULL(b.scomm, 0)) AS scomm
		FROM dbo.bettrans b WITH(NOLOCK)
		WHERE b.winlostdate BETWEEN @FDate AND @TDate
			AND b.statusID IN (111, 112, 113)
			AND b.srecommend = @CID
			AND EXISTS (SELECT 1 FROM @SportBettypeMatrix s WHERE b.bettype = s.Bettype)
		GROUP BY
			b.mrecommend
			,CASE WHEN b.bettype BETWEEN 1901 AND 1999 THEN 1901 ELSE 0 END;
	END	
	
	IF @FromDate <= @MoveBetsDay
	BEGIN
		SELECT  @FDate = @FromDate,
				@TDate = CASE WHEN @ToDate > @MoveBetsDay THEN @MoveBetsDay ELSE @ToDate END;
	
		INSERT INTO #TempData
		(
			mrecommend, bettype, roundCount
			,turnover, netTurnover, taxComm, InsGemMemberWinLoss
			,winlost, awinlost, mwinlost, swinlost
			,playercomm, comm, acomm, scomm
		)
		SELECT
			r.CustID AS mrecommend
			,CASE WHEN r.bettype BETWEEN 1901 AND 1999 THEN 1901 ELSE 0 END AS bettype
			,SUM(ISNULL(r.RoundCount, 0)) AS roundCount
			,SUM(ISNULL(r.Turnover, 0)) AS turnover
			,SUM(ISNULL(r.NetTurnover, 0)) AS netTurnover
			,SUM(ISNULL(r.TotalComm, 0)) AS taxComm
			,SUM(ISNULL(r.InsGemMemberWinLoss, 0)) AS InsGemMemberWinLoss
			,SUM(ISNULL(r.WinLoss, 0)) AS winlost
			,SUM(ISNULL(r.AgWinLoss, 0)) AS awinlost
			,SUM(ISNULL(r.MAgWinLoss, 0)) AS mwinlost
			,SUM(ISNULL(r.SAgWinLoss, 0)) AS swinlost
			,SUM(ISNULL(r.PlayerComm, 0)) AS playercomm
			,SUM(ISNULL(r.AgComm, 0)) AS comm
			,SUM(ISNULL(r.MAgComm, 0)) AS acomm
			,SUM(ISNULL(r.SAgComm, 0)) AS scomm
		FROM bodb_Summary.dbo.rptPokerGamesSumWinloss r WITH(NOLOCK)
		WHERE r.winlostdate BETWEEN @FDate AND @TDate
			AND r.srecommend = @CID
			AND r.RoleID = 3
		GROUP BY
			r.CustID
			,CASE WHEN r.bettype BETWEEN 1901 AND 1999 THEN 1901 ELSE 0 END;
	END

	---- Total rows
	SELECT @TotalRecords = COUNT(DISTINCT mrecommend) FROM #TempData;

	---- Detail data
	;WITH CTE_Sum AS
	(
		SELECT
			mrecommend			AS CustId
			,SUM(turnover)		AS Turnover
			,SUM(netTurnover)	AS NetTurnover
			,SUM(taxComm)		AS TaxComm
			,SUM(roundCount)	AS RoundCount
			-- member
			,SUM(CASE WHEN bettype = 0 THEN winlost - InsGemMemberWinLoss ELSE 0 END)	AS MemberWinLoss
			,SUM(InsGemMemberWinLoss)													AS InsGemMemberWinLoss
			,SUM(CASE WHEN bettype = 1901 THEN winlost ELSE 0 END)						AS VideoMemberWinLoss
			,SUM(playercomm)															AS MemberComm
			-- agent
			,SUM(CASE WHEN bettype = 0 THEN awinlost ELSE 0 END)						AS InsGemAgWinLoss
			,SUM(CASE WHEN bettype = 1901 THEN awinlost ELSE 0 END)						AS VideoAgWinLoss
			,SUM(comm - playercomm)														AS AgComm
			-- master
			,SUM(CASE WHEN bettype = 0 THEN mwinlost ELSE 0 END)						AS InsGemMAgWinLoss
			,SUM(CASE WHEN bettype = 1901 THEN mwinlost ELSE 0 END)						AS VideoMAgWinLoss
			,SUM(acomm - comm)															AS MAgComm
			-- super
			,SUM(CASE WHEN bettype = 0 THEN swinlost ELSE 0 END)						AS InsGemSAgWinLoss
			,SUM(CASE WHEN bettype = 1901 THEN swinlost ELSE 0 END)						AS VideoSAgWinLoss
			,SUM(scomm - acomm)															AS SAgComm
		FROM #TempData
		GROUP BY
			mrecommend
	)
	,CTE_Data AS
	(
		SELECT
			d.CustId
			,c.UserName AS CustName
			,Turnover
			,NetTurnover
			,TaxComm
			,RoundCount
			-- member
			,MemberWinLoss
			,InsGemMemberWinLoss
			,VideoMemberWinLoss
			,MemberComm
			-- agent
			,InsGemAgWinLoss
			,VideoAgWinLoss
			,AgComm
			-- master
			,InsGemMAgWinLoss
			,VideoMAgWinLoss
			,MAgComm
			-- super
			,InsGemSAgWinLoss
			,VideoSAgWinLoss
			,SAgComm
			,ROW_NUMBER() OVER(ORDER BY c.username) AS rn
		FROM CTE_Sum d
			INNER JOIN dbo.custInfo c WITH (NOLOCK) ON d.CustId = c.custid 
	)
	SELECT
		CustId
		,CustName
		,Turnover
		,NetTurnover
		,TaxComm
		,RoundCount
		-- member
		,MemberWinLoss
		,InsGemMemberWinLoss
		,VideoMemberWinLoss
		,MemberComm
		-- agent
		,InsGemAgWinLoss
		,VideoAgWinLoss
		,AgComm
		-- master
		,InsGemMAgWinLoss
		,VideoMAgWinLoss
		,MAgComm
		-- super
		,InsGemSAgWinLoss
		,VideoSAgWinLoss
		,SAgComm
	FROM CTE_Data
	WHERE rn BETWEEN @RowStart AND @RowEnd;

	---- Total data
	SELECT
		NULL				AS CustId
		,'Total'			AS CustName
		,SUM(turnover)		AS Turnover
		,SUM(netTurnover)	AS NetTurnover
		,SUM(taxComm)		AS TaxComm
		,SUM(roundCount)	AS RoundCount
		-- member
		,SUM(CASE WHEN bettype = 0 THEN winlost - InsGemMemberWinLoss ELSE 0 END)	AS MemberWinLoss
		,SUM(InsGemMemberWinLoss)													AS InsGemMemberWinLoss
		,SUM(CASE WHEN bettype = 1901 THEN winlost ELSE 0 END)						AS VideoMemberWinLoss
		,SUM(playercomm)															AS MemberComm
		-- agent
		,SUM(CASE WHEN bettype = 0 THEN awinlost ELSE 0 END)						AS InsGemAgWinLoss
		,SUM(CASE WHEN bettype = 1901 THEN awinlost ELSE 0 END)						AS VideoAgWinLoss
		,SUM(comm - playercomm)														AS AgComm
		-- master
		,SUM(CASE WHEN bettype = 0 THEN mwinlost ELSE 0 END)						AS InsGemMAgWinLoss
		,SUM(CASE WHEN bettype = 1901 THEN mwinlost ELSE 0 END)						AS VideoMAgWinLoss
		,SUM(acomm - comm)															AS MAgComm
		-- super
		,SUM(CASE WHEN bettype = 0 THEN swinlost ELSE 0 END)						AS InsGemSAgWinLoss
		,SUM(CASE WHEN bettype = 1901 THEN swinlost ELSE 0 END)						AS VideoSAgWinLoss
		,SUM(scomm - acomm)															AS SAgComm
	FROM #TempData;

	DROP TABLE #TempData;
END
GO