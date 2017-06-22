USE [bodb02]
GO

/****** Object:  StoredProcedure [dbo].[Age_Rpt_CommByBettype_HR_Master]    Script Date: 1/23/2017 9:32:57 AM ******/
DROP PROCEDURE [dbo].[Age_Rpt_CommByBettype_HR_Master]
GO

/****** Object:  StoredProcedure [dbo].[Age_Rpt_CommByBettype_HR_Master]    Script Date: 1/23/2017 9:32:57 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[Age_Rpt_CommByBettype_HR_Master]
	@CustID		INT,
	@FromDate	SMALLDATETIME,
	@ToDate		SMALLDATETIME
AS

/*
	Created: 
	Task : 
	DB: DBAGE.bodb02
	Original: Age_Rpt_CommByBettype_HR_SAg
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

	CREATE TABLE #SuperComm(
		mrecommend	INT,
		bettype		INT,
		superComm	MONEY
	);
								 
	INSERT INTO #SuperComm(
		mrecommend,
		bettype,
		superComm
	)
	SELECT	b.mrecommend,
			b.bettype,
			SUM(ISNULL(b.scomm, 0) - ISNULL(b.acomm, 0)) sa_comm
	FROM bettrans b WITH(NOLOCK)
	WHERE b.srecommend = @CustID 
		AND b.ruben = 1 
		AND b.winlostdate BETWEEN @FromDate AND @ToDate
		AND EXISTS(
			SELECT 1
			FROM #SportBettype s
			WHERE s.ProductID = 2
				AND b.bettype = s.Bettype
		)
	GROUP BY b.mrecommend, b.bettype;
	
	INSERT INTO #SuperComm(
		mrecommend,
		bettype,
		superComm
	)
	SELECT	b.mrecommend,
			b.bettype,
			SUM(ISNULL(b.scomm, 0) - ISNULL(b.acomm, 0)) sa_comm
	FROM bettrans14 b WITH(NOLOCK)
	WHERE b.srecommend = @CustID 
		AND b.ruben = 1 
		AND b.winlostdate BETWEEN @FromDate AND @ToDate 
		AND EXISTS(
			SELECT 1
			FROM #SportBettype s
			WHERE s.ProductID = 2
				AND b.bettype = s.Bettype
		)
	GROUP BY b.mrecommend, b.bettype;

    SELECT	temp.mrecommend AS CustId,
			c.username AS CustName,
			ISNULL([31], 0) AS ToteWin,
			ISNULL([32], 0) AS TotePlace,
			ISNULL([33], 0) AS ToteWinPlace
	FROM #SuperComm WITH(NOLOCK)
	PIVOT
	(
	    SUM(superComm)
	    FOR bettype IN ([31],[32],[33])
	) AS temp
	    INNER JOIN Customer c WITH(NOLOCK) ON temp.mrecommend = c.custid 
	ORDER BY temp.mrecommend, c.username;
	
	DROP TABLE #SuperComm;
	
	SET NOCOUNT OFF;
END

GO

GRANT EXECUTE ON [dbo].[Age_Rpt_CommByBettype_HR_Master] TO [bodbDownlineNet] AS [dbo]
GO

GRANT EXECUTE ON [dbo].[Age_Rpt_CommByBettype_HR_Master] TO [bodbDownlineNetView] AS [dbo]
GO

GRANT VIEW DEFINITION ON [dbo].[Age_Rpt_CommByBettype_HR_Master] TO [vnteam] AS [dbo]
GO


