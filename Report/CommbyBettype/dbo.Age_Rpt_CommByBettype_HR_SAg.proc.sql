ALTER PROCEDURE [dbo].[Age_Rpt_CommByBettype_HR_SAg]
	@CustID INT, 
	@FromDate SMALLDATETIME,
	@ToDate SMALLDATETIME
AS
	SET NOCOUNT ON 
	--------------------------------------------
	--- HORSE RACING
	--- 2008-11-21 
	--- Phuong Dao
	--- Task : Master's Commission By Bettype 
	---        superComm = scomm - acomm
	---        turnOver = sum (stake)
	--- 20090528@AnhPham: Get HR commisions with PT and remove turnover
	--------------------------------------------
	CREATE TABLE #SuperComm(	mrecommend	int,
								bettype		int,
								superComm	money)
								 
	INSERT INTO #SuperComm(mrecommend, bettype, superComm)
	 
	SELECT	bo.mrecommend, bo.bettype,
			sum(isnull(bo.scomm,0) - isnull(bo.acomm,0)) sa_comm
	FROM 
		(	SELECT	winlostdate, mrecommend, bettype, scomm, acomm, srecommend, ruben
			FROM bettrans with (NOLOCK)
			--WHERE status not in ('running','waiting','void','reject','refund')
			-- 'running' or 'waiting' status is unneccessary so the outer select has condition 'ruben = 1'
			-- for 'void', 'reject' or 'refund' status, commission values is set 0 when settlement occurs
		) bo
	WHERE	bo.srecommend = @CustID 
			and bo.ruben = 1 
			and bo.winlostdate between @FromDate and @ToDate 
			and bo.bettype in (31,32,33,41,42,43) -- productID = 2
	GROUP BY bo.mrecommend, bo.bettype
	
	
	INSERT INTO #SuperComm(mrecommend, bettype, superComm)
	 
	SELECT	bo.mrecommend, bo.bettype,
			sum(isnull(bo.scomm,0) - isnull(bo.acomm,0)) sa_comm
	FROM 
		(	SELECT	winlostdate, mrecommend, bettype, scomm, acomm, srecommend, ruben
			FROM bettrans14 with (NOLOCK)
			--WHERE status not in ('running','waiting','void','reject','refund')
		) bo
	WHERE	bo.srecommend = @CustID 
			and bo.ruben = 1 
			and bo.winlostdate between @FromDate and @ToDate 
			and bo.bettype in (31,32,33,41,42,43) -- productID = 2
	GROUP BY bo.mrecommend, bo.bettype
	

    SELECT temp.mrecommend custid,
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
	FROM #SuperComm with (NOLOCK)
	PIVOT
	(
	    SUM(superComm)
	    FOR bettype IN ([31],[32],[33],[41],[42],[43])
	) as temp
	    INNER JOIN Customer c with (NOLOCK) ON temp.mrecommend = c.custid 
	ORDER BY temp.mrecommend, c.username
	

	DROP TABLE #SuperComm	
	
	GO
	GRANT EXECUTE ON [dbo].[Age_Rpt_CommByBettype_HR_SAg] TO [bodbDownlineNet]
	GO
	GRANT EXECUTE ON [dbo].[Age_Rpt_CommByBettype_HR_SAg] TO [bodbDownlineNetView]
	GO
    GRANT VIEW DEFINITION ON [dbo].[Age_Rpt_CommByBettype_HR_SAg] TO [vnteam]