USE bodb02
GO

ALTER PROCEDURE [dbo].[Age_Rpt_CommByBettype_HR_Ag]
	@CustID INT, 
	@FromDate SMALLDATETIME,
	@ToDate SMALLDATETIME
AS
/*
--- HORSE RACING
--- 2008-11-21 
--- Phuong Dao
--- DB: DBAGE\bodb02
--- Task : Commission By Bettype 
---        agentComm = comm - playercom
---        turnOver = sum (stake)
--- 20090528@AnhPham: Get HR commisions with PT and remove turnover
--- 20150317@Cody: apply sport bettype matrix [Redmine: #30169]
*/	
	SET NOCOUNT ON 
	
	DECLARE @SportBettype TABLE(
			ProductID INT
			,Bettype INT
			,EventType INT
		)
	INSERT INTO @SportBettype
	EXEC bodb02.dbo.Acc_SportBettypeMatrix_Sel @mode=4
	
	CREATE TABLE #AgentComm(	custID		INT
								,bettype	INT
								,agentComm	MONEY
							)
								 
	INSERT INTO #AgentComm(custid, bettype, agentComm)
	SELECT	bo.custid, bo.bettype, sum(isnull(bo.comm,0) - isnull(bo.playercomm,0)) a_comm
	FROM 
		(	SELECT	winlostdate, custid, bettype, comm, playercomm, recommend, ruben
			FROM bettrans with (NOLOCK)
			--WHERE status not in ('running','waiting','void','reject','refund')
		) bo INNER JOIN @SportBettype s ON bo.bettype = s.Bettype
	WHERE	bo.recommend = @CustID 
			AND bo.ruben = 1 
			AND bo.winlostdate BETWEEN @FromDate AND @ToDate 
			AND s.ProductID = 2
			--and bo.bettype in (31,32,33,41,42,43)
	GROUP BY bo.custid, bo.bettype
	 
	 
	INSERT INTO #AgentComm(custid, bettype, agentComm)
	 
	SELECT	bo.custid, bo.bettype, sum(isnull(bo.comm,0) - isnull(bo.playercomm,0)) a_comm
	FROM 
		(	SELECT	winlostdate, custid, bettype, comm, playercomm, recommend, ruben
			FROM bettrans14 with (NOLOCK)
			--WHERE status not in ('running','waiting','void','reject','refund')
		) bo INNER JOIN @SportBettype s ON bo.bettype = s.Bettype
	WHERE	bo.recommend = @CustID 
			AND bo.ruben = 1 
			AND bo.winlostdate between @FromDate and @ToDate 
			AND s.ProductID = 2
			--and bo.bettype in (31,32,33,41,42,43)
	GROUP BY bo.custid, bo.bettype


	SELECT temp.custid custid,
	    c.username,
	    isnull([31],0) as tote_win,
	    isnull([32],0) as tote_palce,
	    isnull([33],0) as tote_winplace,
	    (isnull([31],0) + isnull([32],0) + isnull([33],0)) as tote_total,
	    isnull([41],0) as fo_win,
	    isnull([42],0) as fo_place,
	    isnull([43],0) as fo_winplace,
	    (isnull([41],0) + isnull([42],0) + isnull([43],0)) as fo_total,
	    ((isnull([31],0) + isnull([32],0) + isnull([33],0)) + (isnull([41],0) + isnull([42],0) + isnull([43],0))) as total
	FROM #AgentComm with (NOLOCK)
	PIVOT
	(
	    SUM(agentComm)
	    FOR bettype IN ([31],[32],[33],[41],[42],[43])
	) as temp
	    INNER JOIN Customer c with (NOLOCK) ON temp.custid = c.custid 
	ORDER BY temp.custid, c.username
	
	
	DROP TABLE #AgentComm	
	
	GO
	GRANT EXECUTE ON [dbo].[Age_Rpt_CommByBettype_HR_Ag] TO [bodbDownlineNet]
	GO
	GRANT EXECUTE ON [dbo].[Age_Rpt_CommByBettype_HR_Ag] TO [bodbDownlineNetView]
	GO
    GRANT VIEW DEFINITION ON [dbo].[Age_Rpt_CommByBettype_HR_Ag] TO [vnteam]