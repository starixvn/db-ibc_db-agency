USE bodb02
GO

ALTER PROCEDURE [dbo].[Age_Rpt_CommByBettype_HR_MAg]
	@CustID INT, 
	@FromDate SMALLDATETIME,
	@ToDate SMALLDATETIME
AS

/*
	--- HORSE RACING
	--- 2008-11-21 
	--- Phuong Dao
	--- DB: DBAGE\bodb02
	--- Task : Master's Commission By Bettype 
	---        masterComm = acomm - comm
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
	
	
	CREATE TABLE #MasterComm(	recommend		INT
								,bettype		INT
								,masterComm		MONEY
							)
								 
	INSERT INTO #MasterComm(
					recommend
					,bettype
					,masterComm
				)
	SELECT	
			bo.recommend
			,bo.bettype
			,SUM(ISNULL(bo.acomm,0) - ISNULL(bo.comm,0)) ma_comm
	FROM 
		(	SELECT	winlostdate, recommend, bettype, acomm, comm, mrecommend, ruben
			FROM bettrans WITH(NOLOCK)
			--WHERE status not in ('running','waiting','void','reject','refund')
		) bo INNER JOIN @SportBettype s ON bo.bettype = s.Bettype
	WHERE	bo.mrecommend = @CustID
			AND bo.ruben = 1 
			AND bo.winlostdate BETWEEN @FromDate AND @ToDate 
			AND s.ProductID = 2
			--and bo.bettype in (31,32,33,41,42,43)
	GROUP BY bo.recommend, bo.bettype
	 
	 
	INSERT INTO #MasterComm(
					recommend
					,bettype
					,masterComm
				)
	SELECT	
			bo.recommend
			,bo.bettype
			,SUM(ISNULL(bo.acomm,0) - ISNULL(bo.comm,0)) ma_comm
	FROM 
		(	SELECT	winlostdate, recommend, bettype, acomm, comm, mrecommend, ruben
			FROM bettrans14 WITH(NOLOCK)
			--WHERE status not in ('running','waiting','void','reject','refund')
		) bo INNER JOIN @SportBettype s ON bo.bettype = s.Bettype
	WHERE	bo.mrecommend = @CustID
			AND bo.ruben = 1 
			AND bo.winlostdate BETWEEN @FromDate AND @ToDate 
			AND s.ProductID = 2
			--and bo.bettype in (31,32,33,41,42,43)
	GROUP BY bo.recommend, bo.bettype


	SELECT temp.recommend custid,
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
	FROM #MasterComm with (NOLOCK)
	PIVOT
	(
	    SUM(masterComm)
	    FOR bettype IN ([31],[32],[33],[41],[42],[43])
	) as temp
	    INNER JOIN Customer c with (NOLOCK) ON temp.recommend = c.custid 
	ORDER BY temp.recommend, c.username
	
	
	DROP TABLE #MasterComm
	
	GO
	GRANT EXECUTE ON [dbo].[Age_Rpt_CommByBettype_HR_MAg] TO [bodbDownlineNet]
	GO
	GRANT EXECUTE ON [dbo].[Age_Rpt_CommByBettype_HR_MAg] TO [bodbDownlineNetView]
	GO
    GRANT VIEW DEFINITION ON [dbo].[Age_Rpt_CommByBettype_HR_MAg] TO [vnteam]