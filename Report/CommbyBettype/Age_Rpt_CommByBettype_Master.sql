/*<info serverAlias="DBAGE-bodb02" executers="bodbDownlineNet,bodbDownlineNetView" viewers="" isFunction="0" isNested="0"></info>*/
USE [bodb02]
GO

ALTER PROCEDURE [dbo].[Age_Rpt_CommByBettype_Master]
	@CustID			INT, 
	@FromDate		SMALLDATETIME,
	@ToDate			SMALLDATETIME,
	@MoveBetsDay	SMALLDATETIME 
AS

/*
	Created: 
	Task : Smartphone friendly - Win Loss Detail Report
	DB: DBAGE/bodb02
	Original SP: Age_Rpt_CommByBettype_SAg

	Revisions:
		- 20170213@Paul: Create new [RedmineID: #70629]
		- 20171020@Percy: Add OthersComm [RedmineID: #84690]
		- 20181003@Patrick: Index revolution [RedmineID: #101405]
*/

BEGIN
	SET NOCOUNT ON;

	DECLARE @FDate SMALLDATETIME,
			@TDate SMALLDATETIME,
			@CID   INT;

	SELECT  @CID = @CustID;

	CREATE TABLE #tmp(
		sa_comm		MONEY,
		CommGroup	TINYINT,
		mrecommend	INT
	);

	CREATE TABLE #Bettype_CommGroup (Bettype INT, CommGroup TINYINT);

	INSERT INTO #Bettype_CommGroup (Bettype, CommGroup)
	SELECT Bettype, CommGroup
	FROM dbo.f_Bettype_CommGroup ();

	CREATE CLUSTERED INDEX CIX_bettype ON #Bettype_CommGroup (Bettype)

	IF @Todate > @MoveBetsDay
	BEGIN
		IF @FromDate <= @MoveBetsDay
			SET @FDate = DATEADD(day,1,@MoveBetsDay);
		ELSE
			SET @FDate = @FromDate;

		INSERT INTO #tmp(sa_comm, CommGroup, mrecommend)
		SELECT  SUM(ISNULL(scomm,0) - ISNULL(acomm,0)) AS sa_comm,
				CommGroup,
				mrecommend
		FROM dbo.bettrans b WITH(NOLOCK) 
			INNER JOIN #Bettype_CommGroup s ON b.bettype = s.Bettype
		WHERE b.srecommend = @CustID 
			AND ruben = 1
			AND winlostdate BETWEEN @FDate AND @ToDate
		GROUP BY
			CommGroup,
			mrecommend;
	END

	IF @Fromdate <= @MoveBetsDay		
	BEGIN
		IF @ToDate > @MoveBetsDay
			SET @TDate = @MoveBetsDay;
		ELSE
			SET @TDate = @ToDate;

		INSERT INTO #tmp(sa_comm, CommGroup, mrecommend)
		SELECT  SUM(ISNULL(scomm,0) - ISNULL(acomm,0)) AS sa_comm,
				CommGroup,
				mrecommend
		FROM dbo.bettrans14 b WITH(NOLOCK) 
			INNER JOIN #Bettype_CommGroup s ON b.bettype = s.Bettype
			--INNER JOIN (SELECT custid AS recommend FROM custInfo WITH (NOLOCK) WHERE srecommend = @CID AND roleid = 2) r ON b.recommend = r.recommend -- to use faster index: recommend
		WHERE b.srecommend = @CID
			AND winlostdate BETWEEN @FromDate AND @TDate
		GROUP BY
			CommGroup,
			mrecommend;
	END

	SELECT	pvt.mrecommend AS CustId,
			c.username AS CustName, 
	
			ISNULL([1],0) AS Comm1,
			ISNULL([2],0) AS Comm2,
			ISNULL([3],0) AS Comm3,
			ISNULL([4],0) AS CasinoComm,
			ISNULL([5],0) AS MOComm,
			ISNULL([6],0) AS ChargeComm,
			ISNULL([7],0) AS OthersComm
	FROM #tmp AS p
		PIVOT
		(
			SUM(sa_comm)
			FOR CommGroup IN ([1],[2],[3],[4],[5],[6],[7])
		) AS pvt
		INNER JOIN customer c WITH(NOLOCK) on c.custid = pvt.mrecommend 
	ORDER BY c.username;
 
	DROP TABLE #tmp;
	DROP TABLE #Bettype_CommGroup;
	
	SET NOCOUNT OFF;
END
GO