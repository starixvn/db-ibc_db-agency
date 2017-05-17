USE [bodb02]
GO

/****** Object:  StoredProcedure [dbo].[Age_Rpt_CommByBettype_HR_Agent]    Script Date: 1/23/2017 9:32:09 AM ******/
DROP PROCEDURE [dbo].[Age_Rpt_CommByBettype_HR_Agent]
GO

/****** Object:  StoredProcedure [dbo].[Age_Rpt_CommByBettype_HR_Agent]    Script Date: 1/23/2017 9:32:09 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[Age_Rpt_CommByBettype_HR_Agent]
	@CustID INT, 
	@FromDate SMALLDATETIME,
	@ToDate SMALLDATETIME
AS

/*
	Created: 
	Task : 
	DB: DBAGE.bodb02
	Original: Age_Rpt_CommByBettype_HR_MAg
	Revisions:
		- 20161220@Paul: Create new [RedmineID: #70629]

*/

BEGIN
	SET NOCOUNT ON;
	
	DECLARE @isTest BIT;
	SELECT  @isTest = dbo.f_CheckSPVersion(@@PROCID);

	CREATE TABLE #SportBettype (ProductID INT, Bettype SMALLINT, EventType INT);

	INSERT INTO #SportBettype (ProductID, Bettype, EventType)
	SELECT ProductID, Bettype, EventType
	FROM dbo.f_SportBettypeMatrix_Sel (0, 0, 0, 2, '', '', @isTest)
	WHERE bettype IN (31, 32, 33);
	
	CREATE CLUSTERED INDEX ix_SportBettype_cl ON #SportBettype(Bettype);
	
	CREATE TABLE #MasterComm(
		recommend	INT,
		bettype		INT,
		masterComm	MONEY
	);
								 
	INSERT INTO #MasterComm(
		recommend,
		bettype,
		masterComm
	)
	SELECT	b.recommend,
			b.bettype,
			SUM(ISNULL(b.acomm,0) - ISNULL(b.comm,0)) ma_comm
	FROM bettrans b WITH(NOLOCK)
	WHERE b.mrecommend = @CustID
		AND b.ruben = 1 
		AND b.winlostdate BETWEEN @FromDate AND @ToDate
		AND EXISTS(
			SELECT 1
			FROM #SportBettype s
			WHERE s.ProductID = 2
				AND b.bettype = s.Bettype
		)
	GROUP BY b.recommend, b.bettype;
	 
	INSERT INTO #MasterComm(
		recommend,
		bettype,
		masterComm
	)
	SELECT	b.recommend,
			b.bettype,
			SUM(ISNULL(b.acomm,0) - ISNULL(b.comm,0)) ma_comm
	FROM bettrans14 b WITH(NOLOCK)
	WHERE b.mrecommend = @CustID
		AND b.ruben = 1 
		AND b.winlostdate BETWEEN @FromDate AND @ToDate
		AND EXISTS(
			SELECT 1
			FROM #SportBettype s
			WHERE s.ProductID = 2
				AND b.bettype = s.Bettype
		)
	GROUP BY b.recommend, b.bettype;

	SELECT	temp.recommend AS CustId,
			c.username AS CustName,
			ISNULL([31], 0) AS ToteWin,
			ISNULL([32], 0) AS TotePlace,
			ISNULL([33], 0) AS ToteWinPlace
	FROM #MasterComm WITH(NOLOCK)
	PIVOT
	(
	    SUM(masterComm)
	    FOR bettype IN ([31],[32],[33])
	) AS temp
	    INNER JOIN Customer c WITH(NOLOCK) ON temp.recommend = c.custid 
	ORDER BY temp.recommend, c.username;	
	
	DROP TABLE #MasterComm;

	SET NOCOUNT OFF;
END

GO

GRANT EXECUTE ON [dbo].[Age_Rpt_CommByBettype_HR_Agent] TO [bodbDownlineNet] AS [dbo]
GO

GRANT EXECUTE ON [dbo].[Age_Rpt_CommByBettype_HR_Agent] TO [bodbDownlineNetView] AS [dbo]
GO

GRANT VIEW DEFINITION ON [dbo].[Age_Rpt_CommByBettype_HR_Agent] TO [vnteam] AS [dbo]
GO


