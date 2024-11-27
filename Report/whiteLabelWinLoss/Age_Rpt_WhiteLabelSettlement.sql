/*<info serverAlias="DBAGE-bodb02" executers="wsv_alp,wsv_alpv" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Age_Rpt_WhiteLabelSettlement] 	
	@CustID 		INT, --recommend/ mrecommend/ srecommend
	@FromDate		SMALLDATETIME,
	@ToDate			SMALLDATETIME,
	@UserName		NVARCHAR(50) = '',
	@WhiteLabelList VARCHAR(MAX) = ''
AS
/*
	 DB: DBAGE/bodb02
   
	Revisions:
        - 20240826@Danny: White Label settlement report - [Redmine: #209633]

	-- super
		EXEC Age_Rpt_WhiteLabelSettlement 
				@CustID 		= 4,
				@UserName		= '',
				@FromDate 		= '2024-01-01',
				@ToDate 		= '2024-07-31',
				@WhiteLabelList = '113125,133152,133234,5979,120809,31912,71345,64209,64207,114951'
	-- master
		EXEC Age_Rpt_WhiteLabelSettlement 
			@CustID 		= 15517,
			@UserName		= '',
			@WhiteLabelList = '64209,64207',
			@FromDate 		= '2024-01-01',
			@ToDate 		= '2024-07-31'
	-- agent
		EXEC Age_Rpt_WhiteLabelSettlement 
			@CustID 		= 64207,
			@UserName		= '',
			@FromDate 		= '2024-01-01',
			@ToDate 		= '2024-07-31'
*/
BEGIN
	SET NOCOUNT ON
	DECLARE @FDate	SMALLDATETIME, @TDate SMALLDATETIME, @UserName_CustId INT, @UserName_RoleID TINYINT, @RoleID TINYINT

	DROP TABLE IF EXISTS #WhiteLabelList 
	CREATE TABLE #WhiteLabelList (custID INT, WhiteLabel NVARCHAR(50), LaunchedDate SMALLDATETIME, Recommend INT, Mrecommend INT, Srecommend INT)

	DROP TABLE IF EXISTS #tmpWhiteLabelSettingByMonth
	CREATE TABLE #tmpWhiteLabelSettingByMonth (
		CustID			INT,
		WhiteLabel		NVARCHAR(50),
		Recommend		INT,
		Mrecommend		INT,
		Srecommend		INT,
		LaunchedDate	SMALLDATETIME,
		AgentRate		SMALLMONEY,
		MasterRate		SMALLMONEY,
		SuperRate		SMALLMONEY,
		HeadlineRate	SMALLMONEY,
		FromDate		DATETIME,
		ToDate			DATETIME
	)

	SELECT	@FDate = DATEADD(DAY,1,EOMONTH(@FromDate,-1))
	SELECT  @TDate = CASE WHEN  EOMONTH(@ToDate) >= EOMONTH(GETDATE()) THEN DATEADD(MONTH, DATEDIFF(MONTH, -1, GETDATE())-1, -1) ELSE EOMONTH(@ToDate) END
	SELECT @RoleID = RoleID FROM bodb02.dbo.CustInfo WITH(NOLOCK) WHERE CustID = @CustID

	IF @Username <> ''
	BEGIN
		SELECT @UserName_CustId = ISNULL(Custid, -1), @UserName_RoleID = RoleID
		FROM  bodb02.dbo.Customer WITH (NOLOCK) WHERE username = @UserName
	END
	ELSE				
	BEGIN
		SELECT @UserName_CustId = 0
	END

	INSERT INTO #WhiteLabelList (custID, WhiteLabel, LaunchedDate, Recommend, Mrecommend, Srecommend)
	SELECT wl.custID, wl.WhiteLabel, wl.LaunchedDate, ci.Recommend, ci.Mrecommend, ci.srecommend
	FROM  WhiteLabelInfo wl WITH(NOLOCK)
	INNER JOIN CustInfo ci WITH(NOLOCK) ON wl.CustID = ci.custid
	WHERE ( wl.CustID IN (SELECT CAST(value AS INT) FROM STRING_SPLIT (@WhiteLabelList,',')) OR (wl.CustID = @CustID AND @RoleID =2 ) )
		AND (
				(	
					(
						@UserName_CustId = 0 
						OR ( ci.MRecommend = @UserName_CustId AND  @UserName_RoleID = 3)
						OR ( ci.Recommend = @UserName_CustId AND  @UserName_RoleID = 2)
					) AND @RoleID = 4
				)
			OR (	
					(
						@UserName_CustId = 0 
						OR ( ci.Recommend = @UserName_CustId AND  @UserName_RoleID = 2)
					) AND @RoleID = 3
				)
			OR ( @RoleID = 2 AND @UserName_CustId = 0 )
		)
		AND (
			ci.srecommend = @CustID AND @RoleID = 4
			OR ci.mrecommend = @CustID AND @RoleID = 3
			OR ci.recommend = @CustID AND @RoleID = 2
		)

	/*GET earning setting*/
	;WITH cte AS (
		SELECT @FDate as _start, EOMONTH (@FDate) as _end
		UNION ALL
		SELECT DATEADD(MONTH,1,_start), EOMONTH (DATEADD(MONTH,1,_start))
		FROM cte
		WHERE EOMONTH (DATEADD(MONTH,1,_start)) <= @TDate
	), wls AS
	(
		SELECT	ws.CustID, 
			ws.AgentRate /100. AgentRate, 
			ws.MasterRate/ 100. MasterRate, 
			ws.SuperRate/ 100. SuperRate, 
			ws.HeadlineRate/ 100. HeadlineRate, 
			CAST(ws.FromDate AS DATE) FromDate, 
			CAST(ws.ToDate AS DATE) ToDate
		FROM WhiteLabelSetting ws WITH(NOLOCK)
		INNER JOIN #WhiteLabelList wl ON ws.CustID = wl.custID
		WHERE ws.FromDate <= @TDate AND ws.ToDate >= @FDate
	)
	,t AS
	(
		SELECT  s.*,
				CASE WHEN s.FromDate BETWEEN d._start AND d._end THEN s.FromDate
					 WHEN d._start BETWEEN s.FromDate AND s.ToDate THEN d._start
				END r_f_date,
				CASE WHEN s.ToDate BETWEEN d._start AND d._end THEN s.ToDate
					 WHEN d._end BETWEEN s.FromDate AND s.ToDate THEN d._end
				END r_t_date
		FROM		wls s
		LEFT JOIN	cte d ON s.FromDate BETWEEN d._start AND d._end 
						OR s.FromDate BETWEEN d._start AND d._end
						OR d._start BETWEEN s.FromDate AND s.ToDate
						OR d._end BETWEEN s.FromDate AND s.ToDate
	), s AS
	(
		SELECT CustID, AgentRate, MasterRate, SuperRate, HeadlineRate, r_f_date FromDate, r_t_date ToDate,  
		      CAST (DAY(EOMONTH(r_t_date)) AS MONEY) TotalDayOfMonth,  
			  CAST ( datediff(day, r_f_date, r_t_date) + 1  AS MONEY) NumberAffectedDay,
			  FORMAT(r_t_date,'MM/yyyy') Month_
		FROM t
	), d AS
	(
		SELECT CustID, 
				SUM(AgentRate * (NumberAffectedDay / TotalDayOfMonth)) AgentRate, 
				SUM(MasterRate * (NumberAffectedDay / TotalDayOfMonth)) MasterRate, 
				SUM(SuperRate * (NumberAffectedDay / TotalDayOfMonth)) SuperRate,
				SUM(HeadlineRate * (NumberAffectedDay / TotalDayOfMonth)) HeadlineRate,
				Month_,
				DATEADD(DAY,1,EOMONTH(FromDate,-1)) FromDate,
				EOMONTH(ToDate) ToDate
	    FROM s
		GROUP BY CustID, Month_, DATEADD(DAY,1,EOMONTH(FromDate,-1)), EOMONTH(ToDate)
	) INSERT INTO #tmpWhiteLabelSettingByMonth(CustID, WhiteLabel, Recommend, Mrecommend, Srecommend, LaunchedDate, AgentRate, MasterRate, SuperRate, HeadlineRate, FromDate, ToDate )
		SELECT	ws.CustID, 
			wl.WhiteLabel,
			wl.Recommend,
			wl.Mrecommend,
			wl.srecommend,
			wl.LaunchedDate, 
			ws.AgentRate, 
			ws.MasterRate, 
			ws.SuperRate, 
			ws.HeadlineRate, 
			ws.FromDate , 
			ws.ToDate
	FROM d ws WITH(NOLOCK)
	INNER JOIN #WhiteLabelList wl ON ws.CustID = wl.custID
	OPTION (MAXRECURSION 0)

	/*GET reset carried forward setting*/
	/* Calculate Accum. Carried Foward before date range input */
	DROP TABLE IF EXISTS #tmpWLList 
	CREATE TABLE #tmpWLList (
		CustID			INT,
		LaunchedDate	SMALLDATETIME
	)

	INSERT INTO #tmpWLList (CustID, LaunchedDate)
	SELECT DISTINCT CustID, LaunchedDate
	FROM #tmpWhiteLabelSettingByMonth

	DROP TABLE IF EXISTS #tmpCustWLByMonth 
	CREATE TABLE #tmpCustWLByMonth (
		CustID				INT,
		EndOfMonth			SMALLDATETIME,
		MemberWL			MONEY,
		Promotion			MONEY,
		PromotionShare		MONEY,
		LossCarryforward	MONEY,
		rn INT
	)

	;WITH t AS
	(
		SELECT  tw.CustID,  
				EOMONTH (w.WinlostDate)  EndOfMonth, 
				SUM(CASE WHEN w.TypeId = 0 THEN Winloss ELSE 0 END ) MemberWL,
				SUM(CASE WHEN w.TypeId IN (2,3,4,5,6) THEN Winloss ELSE 0 END ) Promotion,
				SUM(CASE WHEN w.TypeId = 1 THEN Winloss 
						 WHEN w.TypeID = 5 THEN -Winloss * 0.3 ELSE 0 END ) PromotionShare
		FROM	WhiteLabelWinloss w WITH(NOLOCK)
		INNER JOIN #tmpWLList tw ON w.CustID = tw.CustID 
		WHERE w.WinlostDate <= @TDate AND w.WinlostDate >= tw.LaunchedDate
		GROUP BY tw.CustID, EOMONTH (w.WinlostDate)
	)
	INSERT INTO #tmpCustWLByMonth 
	(
		CustID,
		EndOfMonth,
		MemberWL,
		Promotion,
		PromotionShare,
		rn
	)SELECT CustID, EndOfMonth, MemberWL, Promotion, PromotionShare, ROW_NUMBER() OVER (PARTITION BY CustID ORDER BY EndOfMonth ASC) rn
	FROM t

	; WITH u AS
	(
		SELECT t.CustID, t.EndOfMonth, t.MemberWL, t.Promotion, t.PromotionShare, ISNULL(t.LossCarryforward,0) LossCarryforward , t.rn from  #tmpCustWLByMonth t WHERE rn = 1
		UNION ALL
		SELECT t.CustID, 
			   t.EndOfMonth,
			   t.MemberWL, 
			   t.Promotion, 
			   t.PromotionShare, 
			   CASE WHEN  (u.LossCarryforward - u.MemberWL) > 0  OR x.CustID IS NOT NULL THEN 0 ELSE u.LossCarryforward - u.MemberWL END, t.rn  from #tmpCustWLByMonth t
		INNER JOIN u ON t.rn - 1  = u.rn AND u.CustID = t.CustID
		OUTER APPLY ( SELECT wr.CustID FROM WhiteLabelResetLossCarryForward wr WITH(NOLOCK) WHERE t.CustID = wr.CustID AND t.EndOfMonth = EOMONTH(wr.YearMonth) AND wr.IsDisabled = 0 ) x
	)	UPDATE t
		SET t.LossCarryforward = ISNULL(u.LossCarryforward,0)
		FROM  #tmpCustWLByMonth t
		LEFT JOIN u  ON t.CustID = u.CustID AND t.rn = u.rn
	OPTION (MAXRECURSION 0)

	IF @RoleID = 4 
	BEGIN
		; WITH t AS
		(
		SELECT FORMAT(t.EndOfMonth,'MM/yyyy') "Month", 
			  tls.WhiteLabel AS WhiteLabel, 
			  t.CustID,
			  cr.username AS Agent,
			  cm.username AS Master,
			  t.LossCarryforward,
			  t.MemberWL,
			  t.Promotion AS MemberPromotion,
			  t.LossCarryforward - t.MemberWL AS WhiteLabelNetWinloss,
			  -CASE WHEN  t.LossCarryforward - t.MemberWL < 0 THEN 0 ELSE  
				CASE WHEN tls.CustID = tls.Recommend THEN (t.LossCarryforward - t.MemberWL) * (1 - tls.AgentRate) END 
			  END WhiteLabelFee,
			  t.PromotionShare AS WhiteLabelPromotionShare,
			  t.Promotion +  t.PromotionShare AS WhiteLabelPromotionSettlement,
			  CASE WHEN  t.LossCarryforward - t.MemberWL < 0 THEN 0 ELSE (t.LossCarryforward - t.MemberWL) * tls.MasterRate END MasterEarning,
			  CASE WHEN  t.LossCarryforward - t.MemberWL < 0 THEN 0 ELSE (t.LossCarryforward - t.MemberWL) * tls.SuperRate END SuperEarning,
			  CASE WHEN  t.LossCarryforward - t.MemberWL < 0 THEN 0 ELSE (t.LossCarryforward - t.MemberWL) * (1 - tls.AgentRate -tls.MasterRate -tls.SuperRate) END CompanyIncome

		FROM #tmpCustWLByMonth t
		INNER JOIN #tmpWhiteLabelSettingByMonth tls ON t.CustID = tls.CustID AND t.EndOfMonth BETWEEN tls.FromDate and tls.Todate
		LEFT JOIN bodb02.dbo.Customer cm WITH(NOLOCK) ON tls.MRecommend = cm.CustID
		LEFT JOIN bodb02.dbo.Customer cr WITH(NOLOCK) ON tls.Recommend = cr.CustID
		WHERE t.EndOfMonth BETWEEN @FDate AND @TDate
		)
		SELECT  "Month",
				WhiteLabel,
				Agent,
				Master,
				LossCarryforward,
				MemberWL,
				MemberPromotion,
				WhiteLabelNetWinloss,
				WhiteLabelFee,
				- t.MemberWL + WhiteLabelFee AS WhiteLabelIncome,
				WhiteLabelPromotionShare,
				WhiteLabelPromotionSettlement,
				WhiteLabelFee + WhiteLabelPromotionSettlement AS WhiteLabelTotal,
				MasterEarning,
				SuperEarning,
				CompanyIncome  AS CompanyIncome,
				-WhiteLabelPromotionSettlement AS CompanyPromotionShare,
				CompanyIncome  -WhiteLabelPromotionSettlement CompanyTotal
		FROM	t
		ORDER BY  t."Month", Master, WhiteLabel
	END

	IF @RoleID = 3 
	BEGIN
		; WITH t AS
		(
		SELECT FORMAT(t.EndOfMonth,'MM/yyyy') "Month", 
			  tls.WhiteLabel AS WhiteLabel, 
			  t.CustID,
			  cr.username AS Agent,
			  t.LossCarryforward,
			  t.MemberWL,
			  t.Promotion AS MemberPromotion,
			  t.LossCarryforward - t.MemberWL AS WhiteLabelNetWinloss,
			  -CASE WHEN  t.LossCarryforward - t.MemberWL < 0 THEN 0 ELSE  
				CASE WHEN tls.CustID = tls.Recommend THEN (t.LossCarryforward - t.MemberWL) * (1 - tls.AgentRate) END 
			  END WhiteLabelFee,
			  t.PromotionShare AS WhiteLabelPromotionShare,
			  t.Promotion +  t.PromotionShare AS WhiteLabelPromotionSettlement,
			  CASE WHEN  t.LossCarryforward - t.MemberWL < 0 THEN 0 ELSE (t.LossCarryforward - t.MemberWL) * tls.MasterRate END MasterEarning,
			  CASE WHEN  t.LossCarryforward - t.MemberWL < 0 THEN 0 ELSE (t.LossCarryforward - t.MemberWL) * (1 - tls.AgentRate -tls.MasterRate) END CompanyIncome

		FROM #tmpCustWLByMonth t
		INNER JOIN #tmpWhiteLabelSettingByMonth tls ON t.CustID = tls.CustID AND t.EndOfMonth BETWEEN tls.FromDate and tls.Todate
		LEFT JOIN bodb02.dbo.Customer cr WITH(NOLOCK) ON tls.Recommend = cr.CustID
		WHERE t.EndOfMonth BETWEEN @FDate AND @TDate
		)
		SELECT  "Month",
				WhiteLabel,
				Agent,
				LossCarryforward,
				MemberWL,
				MemberPromotion,
				WhiteLabelNetWinloss,
				WhiteLabelFee,
				- t.MemberWL + WhiteLabelFee AS WhiteLabelIncome,
				WhiteLabelPromotionShare,
				WhiteLabelPromotionSettlement,
				WhiteLabelFee + WhiteLabelPromotionSettlement AS WhiteLabelTotal,
				MasterEarning,
				CompanyIncome   AS CompanyIncome,
				-WhiteLabelPromotionSettlement AS CompanyPromotionShare,
				CompanyIncome  -WhiteLabelPromotionSettlement CompanyTotal
		FROM	t
		ORDER BY t."Month", WhiteLabel
	END
	
	IF @RoleID = 2 
	BEGIN
		; WITH t AS
		(
		SELECT FORMAT(t.EndOfMonth,'MM/yyyy') "Month", 
			  tls.WhiteLabel AS WhiteLabel, 
			  t.CustID,
			  t.LossCarryforward,
			  t.MemberWL,
			  t.Promotion AS MemberPromotion,
			  t.LossCarryforward - t.MemberWL AS WhiteLabelNetWinloss,
			  -CASE WHEN  t.LossCarryforward - t.MemberWL < 0 THEN 0 ELSE  
				CASE WHEN tls.CustID = tls.Recommend THEN (t.LossCarryforward - t.MemberWL) * (1 - tls.AgentRate) END 
			  END WhiteLabelFee,
			  t.PromotionShare AS WhiteLabelPromotionShare,
			  t.Promotion +  t.PromotionShare AS WhiteLabelPromotionSettlement,
			  CASE WHEN  t.LossCarryforward - t.MemberWL < 0 THEN 0 ELSE (t.LossCarryforward - t.MemberWL) * (1 - tls.AgentRate) END CompanyIncome
		FROM #tmpCustWLByMonth t
		INNER JOIN #tmpWhiteLabelSettingByMonth tls ON t.CustID = tls.CustID AND t.EndOfMonth BETWEEN tls.FromDate and tls.Todate
		WHERE t.EndOfMonth BETWEEN @FDate AND @TDate
		)
		SELECT  "Month",
				WhiteLabel,
				LossCarryforward,
				MemberWL,
				MemberPromotion,
				WhiteLabelNetWinloss,
				WhiteLabelFee,
				- t.MemberWL + WhiteLabelFee AS WhiteLabelIncome,
				WhiteLabelPromotionShare,
				WhiteLabelPromotionSettlement,
				WhiteLabelFee + WhiteLabelPromotionSettlement AS WhiteLabelTotal,
				CompanyIncome    AS CompanyIncome,
				-WhiteLabelPromotionSettlement AS CompanyPromotionShare,
				CompanyIncome  - WhiteLabelPromotionSettlement CompanyTotal
		FROM	t
		ORDER BY t."Month"
	END

END

GO