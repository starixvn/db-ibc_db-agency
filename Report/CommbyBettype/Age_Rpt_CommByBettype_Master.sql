/*<info serverAlias="DBAGE-bodb02" executers="wsv_alp,wsv_alpv" isFunction="0" isNested="0"></info>*/
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
		- 20190826@Percy: Remove inactive products [RedmineID: #118699]
		- 20200929@Malcolm : Offer Myanmar Odds for bettype in (1,3,7,8) [RedmineId : #141956]
		- 20230328@Malcolm: Add firstname, lastname [RedmineId: #185313]  
		- 20240717@Lewis: Change Old SQL account [Redmine: #207510] 
		- 20241030@Lewis: Remove column MyanmarOddsComm [Redmine: #201396]
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
			INNER JOIN #Bettype_CommGroup s ON b.bettype = s.Bettype --AND (b.oddstype = s.oddstype OR s.oddstype= 0)
		WHERE b.srecommend = @CID
			AND winlostdate BETWEEN @FromDate AND @TDate
		GROUP BY
			CommGroup,
			mrecommend;
	END

	SELECT	pvt.mrecommend AS CustId,
			c.username AS CustName, 
			c.FirstName,
			c.LastName,
			ISNULL([1],0) AS Comm1,
			ISNULL([2],0) AS Comm2,
			ISNULL([3],0) AS Comm3,
			ISNULL([4],0) AS CasinoComm
	FROM #tmp AS p
		PIVOT
		(
			SUM(sa_comm)
			FOR CommGroup IN ([1],[2],[3],[4])
		) AS pvt
		INNER JOIN customer c WITH(NOLOCK) on c.custid = pvt.mrecommend 
	ORDER BY c.username;
 
	DROP TABLE #tmp;
	DROP TABLE #Bettype_CommGroup;
	
	SET NOCOUNT OFF;
END
GO