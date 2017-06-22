USE [bodb02]
GO

/****** Object:  StoredProcedure [dbo].[Age_Rpt_CommByBettype_HR_Member]    Script Date: 1/23/2017 9:33:34 AM ******/
DROP PROCEDURE [dbo].[Age_Rpt_CommByBettype_HR_Member]
GO

/****** Object:  StoredProcedure [dbo].[Age_Rpt_CommByBettype_HR_Member]    Script Date: 1/23/2017 9:33:34 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[Age_Rpt_CommByBettype_HR_Member]
	@CustID INT, 
	@FromDate SMALLDATETIME,
	@ToDate SMALLDATETIME
AS

/*
	Created: 
	Task : 
	DB: DBAGE.bodb02
	Original: Age_Rpt_CommByBettype_HR_Ag
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

	CREATE TABLE #AgentComm(
		custID		INT,
		bettype		INT,
		agentComm	MONEY
	);
								 
	INSERT INTO #AgentComm(custid, bettype, agentComm)
	SELECT	b.custid,
			b.bettype,
			SUM(ISNULL(b.comm, 0) - ISNULL(b.playercomm, 0)) AS a_comm
	FROM bettrans b WITH(NOLOCK)
	WHERE b.recommend = @CustID 
		AND b.ruben = 1 
		AND b.winlostdate BETWEEN @FromDate AND @ToDate 
		AND EXISTS(
			SELECT 1
			FROM #SportBettype s
			WHERE s.ProductID = 2
				AND b.bettype = s.Bettype
		)
	GROUP BY b.custid, b.bettype;	 
	 
	INSERT INTO #AgentComm(custid, bettype, agentComm)	 
	SELECT	b.custid,
			b.bettype,
			SUM(ISNULL(b.comm, 0) - ISNULL(b.playercomm, 0)) AS a_comm
	FROM bettrans14 b WITH(NOLOCK)
	WHERE b.recommend = @CustID 
		AND b.ruben = 1 
		AND b.winlostdate BETWEEN @FromDate AND @ToDate 
		AND EXISTS(
			SELECT 1
			FROM #SportBettype s
			WHERE s.ProductID = 2
				AND b.bettype = s.Bettype
		)
	GROUP BY b.custid, b.bettype;

	SELECT	temp.custid AS CustId,
			c.username AS CustName,
			ISNULL([31], 0) AS ToteWin,
			ISNULL([32], 0) AS TotePlace,
			ISNULL([33], 0) AS ToteWinPlace
	FROM #AgentComm WITH(NOLOCK)
	PIVOT
	(
	    SUM(agentComm)
	    FOR bettype IN ([31], [32], [33])
	) AS temp
	    INNER JOIN Customer c WITH(NOLOCK) ON temp.custid = c.custid 
	ORDER BY temp.custid, c.username;	
	
	DROP TABLE #AgentComm;

	SET NOCOUNT OFF;
END

GO

GRANT EXECUTE ON [dbo].[Age_Rpt_CommByBettype_HR_Member] TO [bodbDownlineNet] AS [dbo]
GO

GRANT EXECUTE ON [dbo].[Age_Rpt_CommByBettype_HR_Member] TO [bodbDownlineNetView] AS [dbo]
GO

GRANT VIEW DEFINITION ON [dbo].[Age_Rpt_CommByBettype_HR_Member] TO [vnteam] AS [dbo]
GO


