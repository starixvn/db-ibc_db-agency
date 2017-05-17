USE [bodb02]
GO

ALTER PROCEDURE [dbo].[Age_Rpt_CommByBettype_Agent]
	@CustID			INT, 
	@FromDate		SMALLDATETIME,
	@ToDate			SMALLDATETIME,
	@MoveBetsDay	SMALLDATETIME 
AS

/*
	Created: 
	Task : Smartphone friendly - Win Loss Detail Report
	DB: DBAGE/bodb02
	Original SP: Age_Rpt_CommByBettype_MAg

	Revisions:
		- 20170213@Paul: Create new [RedmineID: #70629]
*/

BEGIN
	SET NOCOUNT ON;

	DECLARE @FDate SMALLDATETIME,
			@TDate SMALLDATETIME,
			@CID   INT;

	SELECT  @CID = @CustID;

	CREATE TABLE #tmp(
		ma_comm		MONEY,
		CommGroup	TINYINT,
		recommend	INT
	);

	CREATE TABLE #Bettype_CommGroup (Bettype INT, CommGroup TINYINT);

	INSERT INTO #Bettype_CommGroup (Bettype, CommGroup)
	SELECT Bettype, CommGroup
	FROM dbo.f_Bettype_CommGroup ();

	CREATE CLUSTERED INDEX CIX_bettype ON #Bettype_CommGroup (Bettype)

	IF @Todate > @MoveBetsDay
	BEGIN
		IF @FromDate <= @MoveBetsDay
			SET @FDate = DATEADD(DAY, 1, @MoveBetsDay);
		ELSE
			SET @FDate = @FromDate;

		INSERT INTO #tmp(ma_comm, CommGroup, recommend)
		SELECT  SUM(ISNULL(acomm,0) - ISNULL(comm,0)) AS ma_comm,
				CommGroup,
				recommend
		FROM dbo.bettrans b WITH(NOLOCK) 
			INNER JOIN #Bettype_CommGroup s ON b.bettype = s.Bettype
		WHERE b.mrecommend = @CustID 
			AND ruben = 1 
			AND winlostdate BETWEEN @FDate AND @ToDate 
		GROUP BY
			CommGroup,
			recommend;
	END

	IF @Fromdate <= @MoveBetsDay		
	BEGIN
		IF @ToDate > @MoveBetsDay
			SET @TDate = @MoveBetsDay;
		ELSE
			SET @TDate = @ToDate;
		
		INSERT INTO #tmp(ma_comm, CommGroup, recommend)
		SELECT  SUM(ISNULL(acomm,0) - ISNULL(comm,0)) AS ma_comm,
				CommGroup,
				b.recommend
		FROM dbo.bettrans14 b with(nolock) 
			INNER JOIN #Bettype_CommGroup s ON b.bettype = s.Bettype
			INNER JOIN (SELECT custid AS recommend FROM custInfo WITH (NOLOCK) WHERE mrecommend = @CID AND roleid = 2) r ON b.recommend = r.recommend -- to use faster index: recommend
		WHERE winlostdate BETWEEN @FromDate AND @TDate
		GROUP BY
			CommGroup,
			b.recommend;
	END
		
	SELECT	pvt.recommend AS CustId,
			c.username AS CustName, 
			
			ISNULL([1],0) AS Comm1,
			ISNULL([2],0) AS Comm2,
			ISNULL([3],0) AS Comm3,
			ISNULL([4],0) AS CasinoComm,
			ISNULL([5],0) AS MOComm,
			ISNULL([6],0) AS ChargeComm
	
	FROM #tmp AS p
		PIVOT
		(
			SUM(ma_comm)
			FOR CommGroup IN ([1],[2],[3],[4],[5],[6])  
		) AS pvt
		INNER JOIN customer c WITH(NOLOCK) On c.custid = pvt.recommend 
	ORDER BY c.username;

	DROP TABLE #tmp;
	DROP TABLE #Bettype_CommGroup;

	SET NOCOUNT OFF;
END
GO

GRANT EXECUTE ON [dbo].[Age_Rpt_CommByBettype_Agent] TO [bodbDownlineNetView] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[Age_Rpt_CommByBettype_Agent] TO [vnteam] AS [dbo]
GO
GRANT EXECUTE ON [dbo].[Age_Rpt_CommByBettype_Agent] TO [bodbDownlineNet] AS [dbo]
GO