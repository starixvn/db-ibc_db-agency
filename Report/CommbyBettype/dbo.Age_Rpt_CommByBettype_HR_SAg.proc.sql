ALTER PROCEDURE [dbo].[Age_Rpt_CommByBettype_HR_SAg]
	@CustID		INT 
	,@FromDate	SMALLDATETIME
	,@ToDate	SMALLDATETIME
AS
	SET NOCOUNT ON 
	
/*
HORSE RACING
2008-11-21 
Phuong Dao
Task : Master's Commission By Bettype 
        superComm = scomm - acomm
        turnOver = sum (stake)
	- 20090528@AnhPham: Get HR commisions with PT and remove turnover
	- 20150317@Cody: apply sport bettype matrix [Redmine: #30169]
*/
	
	DECLARE @SportBettype TABLE(
			ProductID INT
			,Bettype INT
			,EventType INT
		)
		
	INSERT INTO @SportBettype
	EXEC bodb02.dbo.Acc_SportBettypeMatrix_Sel @mode=4

	CREATE TABLE #SuperComm(	mrecommend	INT
								,bettype	INT
								,superComm	MONEY
							)
								 
	INSERT INTO #SuperComm(
			mrecommend
			,bettype
			,superComm
		)
	SELECT	bo.mrecommend
			,bo.bettype
			,SUM(ISNULL(bo.scomm, 0) - ISNULL(bo.acomm, 0)) sa_comm
	FROM 
		(	SELECT	
				winlostdate
				,mrecommend
				,bettype
				,scomm
				,acomm
				,srecommend
				,ruben
			FROM bettrans WITH(NOLOCK)
			--WHERE status not in ('running','waiting','void','reject','refund')
			-- 'running' or 'waiting' status is unneccessary so the outer select has condition 'ruben = 1'
			-- for 'void', 'reject' or 'refund' status, commission values is set 0 when settlement occurs
		) bo INNER JOIN @SportBettype s ON bo.bettype = s.Bettype
	WHERE	bo.srecommend = @CustID 
			AND bo.ruben = 1 
			AND bo.winlostdate BETWEEN @FromDate AND @ToDate
			AND s.ProductID = 2
			--AND bo.bettype IN (31, 32, 33, 41, 42, 43) -- productID = 2
	GROUP BY bo.mrecommend, bo.bettype
	
	INSERT INTO #SuperComm(
			mrecommend
			,bettype
			,superComm
		)
	SELECT	
			bo.mrecommend
			,bo.bettype,
			SUM(ISNULL(bo.scomm, 0) - ISNULL(bo.acomm, 0)) sa_comm
	FROM 
		(	SELECT	
				winlostdate
				,mrecommend
				,bettype
				,scomm
				,acomm
				,srecommend
				,ruben
			FROM bettrans14 WITH(NOLOCK)
			--WHERE status not in ('running','waiting','void','reject','refund')
		) bo INNER JOIN @SportBettype s ON bo.bettype = s.Bettype
	WHERE	bo.srecommend = @CustID 
			AND bo.ruben = 1 
			AND bo.winlostdate BETWEEN @FromDate AND @ToDate 
			AND s.ProductID = 2
			--AND bo.bettype IN (31, 32, 33, 41, 42, 43) -- productID = 2
	GROUP BY bo.mrecommend, bo.bettype

    SELECT temp.mrecommend custid,
	    c.username,
	    ISNULL([31],0) as tote_win,
	    ISNULL([32],0) as tote_palce,
	    ISNULL([33],0) as tote_winplace,
	    (ISNULL([31],0) + ISNULL([32],0) + ISNULL([33],0)) as tote_total,
	    ISNULL([41],0) as fo_win,
	    ISNULL([42],0) as fo_place,
	    ISNULL([43],0) as fo_winplace,
	    (ISNULL([41],0) + ISNULL([42],0) + ISNULL([43],0)) as fo_total,
	    ((ISNULL([31],0) + ISNULL([32],0) + ISNULL([33],0)) + (ISNULL([41],0) + ISNULL([42],0) + ISNULL([43],0))) as total
	FROM #SuperComm with (NOLOCK)
	PIVOT
	(
	    SUM(superComm)
	    FOR bettype IN ([31],[32],[33],[41],[42],[43])
	) as temp
	    INNER JOIN Customer c WITH(NOLOCK) ON temp.mrecommend = c.custid 
	ORDER BY temp.mrecommend, c.username
	
	DROP TABLE #SuperComm	
	
	GO
	GRANT EXECUTE ON [dbo].[Age_Rpt_CommByBettype_HR_SAg] TO [bodbDownlineNet]
	GO
	GRANT EXECUTE ON [dbo].[Age_Rpt_CommByBettype_HR_SAg] TO [bodbDownlineNetView]
	GO
    GRANT VIEW DEFINITION ON [dbo].[Age_Rpt_CommByBettype_HR_SAg] TO [vnteam]