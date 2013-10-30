ALTER PROCEDURE [dbo].[Age_CustomerSelPositionTakingByAg]  
(
	@Recommend INT,
	@PageIndex	INT = 1,
	@PageSize	INT = 100,
	@TotalPages	INT = 0 OUTPUT
)
AS
/*  
	Task : Select Member PT List  
	DB: DBAGE/bodb02, DBTXN/bodb02

	Revisions:  
		- UPDATED 02/22/2006: remove refno  
		- 20090331@Kiwi: Improve Reads by removing inner join customer  
		- 20091204@Kiwi: Retrieve data from CustSetting3rd.  
		- 20100311@Jamie: Edit to get HR Settings  
		- 20100916@Kiwi: Retrieve data for Mix Parlay of Mixed Sports and remove Mix Parlay Basketball  
		- 20100917@Kaden: Remove Mix Parlay of Basketball (field v2spositiontaking_9, v2apositiontaking_9, v2mpositiontaking_9).  
		- 20110114@Johnson: separate get setting from  custseting and custsetting3rd for performance and use temporary table  
		- 20110122@Daniel: Remove constraint in temp table #setting3rd to avoid constraint name conficts caused by concurrent calls
		- 20110323@Lukas: Remove horse racing & FI
		- 20111128@Lukas: Add paging
		- 20131021@Kathy: Add HR Fixed Odds (154) [Redmine:#6505]
	Param's Explanation:  
	• @Recommend: AgentID  
*/  
BEGIN

	SET NOCOUNT ON  
	  
	/*
	CREATE TABLE #setting3rd(custid INT PRIMARY KEY, 
	 v201apt_3  smallmoney, v201mpt_3  smallmoney,  v201spt_3  smallmoney,
	 v201apt_2  smallmoney, v201mpt_2  smallmoney,  v201spt_2  smallmoney,

	--
	 v151apt_31 smallmoney, v151apt_32 smallmoney, v151apt_41 smallmoney, v151apt_42 smallmoney,  
	 v151mpt_31 smallmoney, v151mpt_32 smallmoney, v151mpt_41 smallmoney, v151mpt_42 smallmoney,  
	 v151spt_31 smallmoney, v151spt_32 smallmoney, v151spt_41 smallmoney, v151spt_42 smallmoney
	 )  
	  
	  
	INSERT INTO #setting3rd  
	SELECT  
	 ci.custid ,  
	-- Finance  
	MAX(CASE WHEN cs3rd.bettype = 3 AND cs3rd.sporttype=201 THEN cs3rd.apositiontaking ELSE 0 END) v201apositiontaking_3,  
	MAX(CASE WHEN cs3rd.bettype = 3 AND cs3rd.sporttype=201 THEN cs3rd.mpositiontaking ELSE 0 END) v201mpositiontaking_3,  
	MAX(CASE WHEN cs3rd.bettype = 3 AND cs3rd.sporttype=201 THEN cs3rd.spositiontaking ELSE 0 END)v201spositiontaking_3,  
	  
	MAX(CASE WHEN cs3rd.bettype = 2 AND cs3rd.sporttype=201 THEN cs3rd.apositiontaking ELSE 0 END) v201apositiontaking_2,  
	MAX(CASE WHEN cs3rd.bettype = 2 AND cs3rd.sporttype=201 THEN cs3rd.mpositiontaking ELSE 0 END) v201mpositiontaking_2,  
	MAX(CASE WHEN cs3rd.bettype = 2 AND cs3rd.sporttype=201 THEN cs3rd.spositiontaking ELSE 0 END)v201spositiontaking_2
	--   
	 --Horse  
	-- MAX(CASE WHEN cs3rd.bettype = 31 AND cs3rd.sporttype=151 THEN cs3rd.apositiontaking ELSE 0 END) v151apt_31,  
	-- MAX(CASE WHEN cs3rd.bettype = 32 AND cs3rd.sporttype=151 THEN cs3rd.apositiontaking ELSE 0 END) v151apt_32,  
	-- MAX(CASE WHEN cs3rd.bettype = 41 AND cs3rd.sporttype=151 THEN cs3rd.apositiontaking ELSE 0 END) v151apt_41,  
	-- MAX(CASE WHEN cs3rd.bettype = 42 AND cs3rd.sporttype=151 THEN cs3rd.apositiontaking ELSE 0 END) v151apt_42,  
	--  
	-- MAX(CASE WHEN cs3rd.bettype = 31 AND cs3rd.sporttype=151 THEN cs3rd.mpositiontaking ELSE 0 END) v151mpt_31,  
	-- MAX(CASE WHEN cs3rd.bettype = 32 AND cs3rd.sporttype=151 THEN cs3rd.mpositiontaking ELSE 0 END) v151mpt_32,  
	-- MAX(CASE WHEN cs3rd.bettype = 41 AND cs3rd.sporttype=151 THEN cs3rd.mpositiontaking ELSE 0 END) v151mpt_41,  
	-- MAX(CASE WHEN cs3rd.bettype = 42 AND cs3rd.sporttype=151 THEN cs3rd.mpositiontaking ELSE 0 END) v151mpt_42,  
	--   
	-- MAX(CASE WHEN cs3rd.bettype = 31 AND cs3rd.sporttype=151 THEN cs3rd.spositiontaking ELSE 0 END)v151spt_31,  
	-- MAX(CASE WHEN cs3rd.bettype = 32 AND cs3rd.sporttype=151 THEN cs3rd.spositiontaking ELSE 0 END)v151spt_32,  
	-- MAX(CASE WHEN cs3rd.bettype = 41 AND cs3rd.sporttype=151 THEN cs3rd.spositiontaking ELSE 0 END) v151spt_41,  
	-- MAX(CASE WHEN cs3rd.bettype = 42 AND cs3rd.sporttype=151 THEN cs3rd.spositiontaking ELSE 0 END) v151spt_42  
	FROM  
	 custinfo AS ci WITH (NOLOCK)   
	 INNER JOIN CustSetting3rd AS cs3rd WITH (NOLOCK) ON ci.custid = cs3rd.custid   
	WHERE   
	 ci.Recommend = @recommend AND ci.roleid=1   
	GROUP BY  
	 ci.enabled, ci.closed, ci.reject, ci.username, ci.custid  
	ORDER BY   
	CASE WHEN ISNULL(ci.enabled,0) = 0 THEN 3 WHEN ISNULL(ci.closed,0) = 1 THEN 2 WHEN ISNULL(ci.reject,0) = 1 THEN 1 ELSE 0 END,   
	ci.username  
	*/  
	SELECT 
		@TotalPages = COUNT(ci.custid),@TotalPages=@TotalPages/@PageSize + CASE WHEN @TotalPages%@PageSize > 0 THEN 1 ELSE 0 END
	FROM 
		custinfo AS ci WITH (NOLOCK)		
	WHERE 
		ci.Recommend = @recommend AND ci.roleid=1   
	
	SELECT *
	FROM 
	(
		SELECT   
		 ROW_NUMBER() OVER(ORDER BY CASE WHEN ISNULL(ci.enabled,0) = 0 THEN 3 
										WHEN ISNULL(ci.closed,0) = 1 THEN 2 
										WHEN ISNULL(ci.reject,0) = 1 THEN 1 
										ELSE 0 
									END, ci.username  ) AS RowNumber,
		 ci.enabled, ci.closed, ISNULL(ci.reject,0) AS suspended, ci.username, ci.custid,   
		 MAX(CASE WHEN cs.bettype = 1 AND cs.sporttype=1 THEN cs.apositiontaking ELSE 0 END) AS apositiontaking_1,  
		 MAX(CASE WHEN cs.bettype = 2 AND cs.sporttype=1 THEN cs.apositiontaking ELSE 0 END) AS apositiontaking_2,  
		 MAX(CASE WHEN cs.bettype = 3 AND cs.sporttype=1 THEN cs.apositiontaking ELSE 0 END) AS apositiontaking_3,  
		 MAX(CASE WHEN cs.bettype = 4 AND cs.sporttype=1 THEN cs.apositiontaking ELSE 0 END) AS apositiontaking_4,  
		 MAX(CASE WHEN cs.bettype = 5 AND cs.sporttype=1 THEN cs.apositiontaking ELSE 0 END) AS apositiontaking_5,  
		 MAX(CASE WHEN cs.bettype = 6 AND cs.sporttype=1 THEN cs.apositiontaking ELSE 0 END) AS apositiontaking_6,  
		 MAX(CASE WHEN cs.bettype = 7 AND cs.sporttype=1 THEN cs.apositiontaking ELSE 0 END) AS apositiontaking_7,  
		 MAX(CASE WHEN cs.bettype = 8 AND cs.sporttype=1 THEN cs.apositiontaking ELSE 0 END) AS apositiontaking_8,  
		 MAX(CASE WHEN cs.bettype = 9 AND cs.sporttype=1 THEN cs.apositiontaking ELSE 0 END) AS apositiontaking_9,  
		 MAX(CASE WHEN cs.bettype = 10 AND cs.sporttype=1 THEN cs.apositiontaking ELSE 0 END) AS apositiontaking_10,  
		  
		 MAX(CASE WHEN cs.bettype = 1 AND cs.sporttype=1 THEN cs.mpositiontaking ELSE 0 END) AS mpositiontaking_1,  
		 MAX(CASE WHEN cs.bettype = 2 AND cs.sporttype=1 THEN cs.mpositiontaking ELSE 0 END) AS mpositiontaking_2,  
		 MAX(CASE WHEN cs.bettype = 3 AND cs.sporttype=1 THEN cs.mpositiontaking ELSE 0 END) AS mpositiontaking_3,  
		 MAX(CASE WHEN cs.bettype = 4 AND cs.sporttype=1 THEN cs.mpositiontaking ELSE 0 END) AS mpositiontaking_4,  
		 MAX(CASE WHEN cs.bettype = 5 AND cs.sporttype=1 THEN cs.mpositiontaking ELSE 0 END) AS mpositiontaking_5,  
		 MAX(CASE WHEN cs.bettype = 6 AND cs.sporttype=1 THEN cs.mpositiontaking ELSE 0 END) AS mpositiontaking_6,  
		 MAX(CASE WHEN cs.bettype = 7 AND cs.sporttype=1 THEN cs.mpositiontaking ELSE 0 END) AS mpositiontaking_7,  
		 MAX(CASE WHEN cs.bettype = 8 AND cs.sporttype=1 THEN cs.mpositiontaking ELSE 0 END) AS mpositiontaking_8,  
		 MAX(CASE WHEN cs.bettype = 9 AND cs.sporttype=1 THEN cs.mpositiontaking ELSE 0 END) AS mpositiontaking_9,   
		 MAX(CASE WHEN cs.bettype = 10 AND cs.sporttype=1 THEN cs.mpositiontaking ELSE 0 END) AS mpositiontaking_10,   
		  
		 MAX(CASE WHEN cs.bettype = 1 AND cs.sporttype=1 THEN cs.spositiontaking ELSE 0 END) AS spositiontaking_1,  
		 MAX(CASE WHEN cs.bettype = 2 AND cs.sporttype=1 THEN cs.spositiontaking ELSE 0 END) AS spositiontaking_2,  
		 MAX(CASE WHEN cs.bettype = 3 AND cs.sporttype=1 THEN cs.spositiontaking ELSE 0 END) AS spositiontaking_3,  
		 MAX(CASE WHEN cs.bettype = 4 AND cs.sporttype=1 THEN cs.spositiontaking ELSE 0 END) AS spositiontaking_4,  
		 MAX(CASE WHEN cs.bettype = 5 AND cs.sporttype=1 THEN cs.spositiontaking ELSE 0 END) AS spositiontaking_5,  
		 MAX(CASE WHEN cs.bettype = 6 AND cs.sporttype=1 THEN cs.spositiontaking ELSE 0 END) AS spositiontaking_6,  
		 MAX(CASE WHEN cs.bettype = 7 AND cs.sporttype=1 THEN cs.spositiontaking ELSE 0 END) AS spositiontaking_7,  
		 MAX(CASE WHEN cs.bettype = 8 AND cs.sporttype=1 THEN cs.spositiontaking ELSE 0 END) AS spositiontaking_8,  
		 MAX(CASE WHEN cs.bettype = 9 AND cs.sporttype=1 THEN cs.spositiontaking ELSE 0 END) AS spositiontaking_9,  
		 MAX(CASE WHEN cs.bettype = 10 AND cs.sporttype=1 THEN cs.spositiontaking ELSE 0 END) AS spositiontaking_10,  
		  
		 MAX(CASE WHEN cs.bettype = 1 AND cs.sporttype=1 THEN cs.alivepositiontaking ELSE 0 END) AS alivepositiontaking_1,  
		 MAX(CASE WHEN cs.bettype = 3 AND cs.sporttype=1 THEN cs.alivepositiontaking ELSE 0 END) AS alivepositiontaking_3,  
		 MAX(CASE WHEN cs.bettype = 7 AND cs.sporttype=1 THEN cs.alivepositiontaking ELSE 0 END) AS alivepositiontaking_7,  
		 MAX(CASE WHEN cs.bettype = 8 AND cs.sporttype=1 THEN cs.alivepositiontaking ELSE 0 END) AS alivepositiontaking_8,  
		  
		 MAX(CASE WHEN cs.bettype = 1 AND cs.sporttype=1 THEN cs.mlivepositiontaking ELSE 0 END) AS mlivepositiontaking_1,  
		 MAX(CASE WHEN cs.bettype = 3 AND cs.sporttype=1 THEN cs.mlivepositiontaking ELSE 0 END) AS mlivepositiontaking_3,  
		 MAX(CASE WHEN cs.bettype = 7 AND cs.sporttype=1 THEN cs.mlivepositiontaking ELSE 0 END) AS mlivepositiontaking_7,  
		 MAX(CASE WHEN cs.bettype = 8 AND cs.sporttype=1 THEN cs.mlivepositiontaking ELSE 0 END) AS mlivepositiontaking_8,  
		  
		 MAX(CASE WHEN cs.bettype = 1 AND cs.sporttype=1 THEN cs.slivepositiontaking ELSE 0 END) AS slivepositiontaking_1,  
		 MAX(CASE WHEN cs.bettype = 3 AND cs.sporttype=1 THEN cs.slivepositiontaking ELSE 0 END) AS slivepositiontaking_3,  
		 MAX(CASE WHEN cs.bettype = 7 AND cs.sporttype=1 THEN cs.slivepositiontaking ELSE 0 END) AS slivepositiontaking_7,  
		 MAX(CASE WHEN cs.bettype = 8 AND cs.sporttype=1 THEN cs.slivepositiontaking ELSE 0 END) AS slivepositiontaking_8,  
		  
		 --basketball  
		 MAX(CASE WHEN cs.bettype = 1 AND cs.sporttype=2 THEN cs.apositiontaking ELSE 0 END) AS v2apositiontaking_1,  
		 MAX(CASE WHEN cs.bettype = 2 AND cs.sporttype=2 THEN cs.apositiontaking ELSE 0 END) AS v2apositiontaking_2,  
		 MAX(CASE WHEN cs.bettype = 3 AND cs.sporttype=2 THEN cs.apositiontaking ELSE 0 END) AS v2apositiontaking_3,  
		 MAX(CASE WHEN cs.bettype = 7 AND cs.sporttype=2 THEN cs.apositiontaking ELSE 0 END) AS v2apositiontaking_7,  
		 MAX(CASE WHEN cs.bettype = 8 AND cs.sporttype=2 THEN cs.apositiontaking ELSE 0 END) AS v2apositiontaking_8,  
		 MAX(CASE WHEN cs.bettype = 20 AND cs.sporttype=2 THEN cs.apositiontaking ELSE 0 END) AS v2apositiontaking_20,  
		  
		 MAX(CASE WHEN cs.bettype = 1 AND cs.sporttype=2 THEN cs.mpositiontaking ELSE 0 END) AS v2mpositiontaking_1,  
		 MAX(CASE WHEN cs.bettype = 2 AND cs.sporttype=2 THEN cs.mpositiontaking ELSE 0 END) AS v2mpositiontaking_2,  
		 MAX(CASE WHEN cs.bettype = 3 AND cs.sporttype=2 THEN cs.mpositiontaking ELSE 0 END) AS v2mpositiontaking_3,  
		 MAX(CASE WHEN cs.bettype = 7 AND cs.sporttype=2 THEN cs.mpositiontaking ELSE 0 END) AS v2mpositiontaking_7,  
		 MAX(CASE WHEN cs.bettype = 8 AND cs.sporttype=2 THEN cs.mpositiontaking ELSE 0 END) AS v2mpositiontaking_8,  
		 MAX(CASE WHEN cs.bettype = 20 AND cs.sporttype=2 THEN cs.mpositiontaking ELSE 0 END) AS v2mpositiontaking_20,  
		  
		 MAX(CASE WHEN cs.bettype = 1 AND cs.sporttype=2 THEN cs.spositiontaking ELSE 0 END) AS v2spositiontaking_1,  
		 MAX(CASE WHEN cs.bettype = 2 AND cs.sporttype=2 THEN cs.spositiontaking ELSE 0 END) AS v2spositiontaking_2,  
		 MAX(CASE WHEN cs.bettype = 3 AND cs.sporttype=2 THEN cs.spositiontaking ELSE 0 END) AS v2spositiontaking_3,  
		 MAX(CASE WHEN cs.bettype = 7 AND cs.sporttype=2 THEN cs.spositiontaking ELSE 0 END) AS v2spositiontaking_7,  
		 MAX(CASE WHEN cs.bettype = 8 AND cs.sporttype=2 THEN cs.spositiontaking ELSE 0 END) AS v2spositiontaking_8,  
		 MAX(CASE WHEN cs.bettype = 20 AND cs.sporttype=2 THEN cs.spositiontaking ELSE 0 END) AS v2spositiontaking_20,  
		  
		 --football  
		 MAX(CASE WHEN cs.bettype = 1 AND cs.sporttype=3 THEN cs.apositiontaking ELSE 0 END) AS v3apositiontaking_1,  
		 MAX(CASE WHEN cs.bettype = 2 AND cs.sporttype=3 THEN cs.apositiontaking ELSE 0 END) AS v3apositiontaking_2,  
		 MAX(CASE WHEN cs.bettype = 3 AND cs.sporttype=3 THEN cs.apositiontaking ELSE 0 END) AS v3apositiontaking_3,  
		 MAX(CASE WHEN cs.bettype = 20 AND cs.sporttype=3 THEN cs.apositiontaking ELSE 0 END) AS v3apositiontaking_20,  
		  
		 MAX(CASE WHEN cs.bettype = 1 AND cs.sporttype=3 THEN cs.mpositiontaking ELSE 0 END) AS v3mpositiontaking_1,  
		 MAX(CASE WHEN cs.bettype = 2 AND cs.sporttype=3 THEN cs.mpositiontaking ELSE 0 END) AS v3mpositiontaking_2,  
		 MAX(CASE WHEN cs.bettype = 3 AND cs.sporttype=3 THEN cs.mpositiontaking ELSE 0 END) AS v3mpositiontaking_3,  
		 MAX(CASE WHEN cs.bettype = 20 AND cs.sporttype=3 THEN cs.mpositiontaking ELSE 0 END) AS v3mpositiontaking_20,  
		  
		 MAX(CASE WHEN cs.bettype = 1 AND cs.sporttype=3 THEN cs.spositiontaking ELSE 0 END) AS v3spositiontaking_1,  
		 MAX(CASE WHEN cs.bettype = 2 AND cs.sporttype=3 THEN cs.spositiontaking ELSE 0 END) AS v3spositiontaking_2,  
		 MAX(CASE WHEN cs.bettype = 3 AND cs.sporttype=3 THEN cs.spositiontaking ELSE 0 END) AS v3spositiontaking_3,  
		 MAX(CASE WHEN cs.bettype = 20 AND cs.sporttype=3 THEN cs.spositiontaking ELSE 0 END) AS v3spositiontaking_20,  
		  
		 --tennis  
		 MAX(CASE WHEN cs.bettype = 1 AND cs.sporttype=5 THEN cs.apositiontaking ELSE 0 END) AS v5apositiontaking_1,  
		 MAX(CASE WHEN cs.bettype = 2 AND cs.sporttype=5 THEN cs.apositiontaking ELSE 0 END) AS v5apositiontaking_2,  
		 MAX(CASE WHEN cs.bettype = 3 AND cs.sporttype=5 THEN cs.apositiontaking ELSE 0 END) AS v5apositiontaking_3,  
		 MAX(CASE WHEN cs.bettype = 20 AND cs.sporttype=5 THEN cs.apositiontaking ELSE 0 END) AS v5apositiontaking_20,  
		  
		 MAX(CASE WHEN cs.bettype = 1 AND cs.sporttype=5 THEN cs.mpositiontaking ELSE 0 END) AS v5mpositiontaking_1,  
		 MAX(CASE WHEN cs.bettype = 2 AND cs.sporttype=5 THEN cs.mpositiontaking ELSE 0 END) AS v5mpositiontaking_2,  
		 MAX(CASE WHEN cs.bettype = 3 AND cs.sporttype=5 THEN cs.mpositiontaking ELSE 0 END) AS v5mpositiontaking_3,  
		 MAX(CASE WHEN cs.bettype = 20 AND cs.sporttype=5 THEN cs.mpositiontaking ELSE 0 END) AS v5mpositiontaking_20,  
		  
		 MAX(CASE WHEN cs.bettype = 1 AND cs.sporttype=5 THEN cs.spositiontaking ELSE 0 END) AS v5spositiontaking_1,  
		 MAX(CASE WHEN cs.bettype = 2 AND cs.sporttype=5 THEN cs.spositiontaking ELSE 0 END) AS v5spositiontaking_2,  
		 MAX(CASE WHEN cs.bettype = 3 AND cs.sporttype=5 THEN cs.spositiontaking ELSE 0 END) AS v5spositiontaking_3,  
		 MAX(CASE WHEN cs.bettype = 20 AND cs.sporttype=5 THEN cs.spositiontaking ELSE 0 END) AS v5spositiontaking_20,  
		  
		 --baseball  
		 MAX(CASE WHEN cs.bettype = 1 AND cs.sporttype=8 THEN cs.apositiontaking ELSE 0 END) AS v8apositiontaking_1,  
		 MAX(CASE WHEN cs.bettype = 3 AND cs.sporttype=8 THEN cs.apositiontaking ELSE 0 END) AS v8apositiontaking_3,  
		 MAX(CASE WHEN cs.bettype = 20 AND cs.sporttype=8 THEN cs.apositiontaking ELSE 0 END) AS v8apositiontaking_20,  
		  
		 MAX(CASE WHEN cs.bettype = 1 AND cs.sporttype=8 THEN cs.mpositiontaking ELSE 0 END) AS v8mpositiontaking_1,  
		 MAX(CASE WHEN cs.bettype = 3 AND cs.sporttype=8 THEN cs.mpositiontaking ELSE 0 END) AS v8mpositiontaking_3,  
		 MAX(CASE WHEN cs.bettype = 20 AND cs.sporttype=8 THEN cs.mpositiontaking ELSE 0 END) AS v8mpositiontaking_20,  
		  
		 MAX(CASE WHEN cs.bettype = 1 AND cs.sporttype=8 THEN cs.spositiontaking ELSE 0 END) AS v8spositiontaking_1,  
		 MAX(CASE WHEN cs.bettype = 3 AND cs.sporttype=8 THEN cs.spositiontaking ELSE 0 END) AS v8spositiontaking_3,  
		 MAX(CASE WHEN cs.bettype = 20 AND cs.sporttype=8 THEN cs.spositiontaking ELSE 0 END) AS v8spositiontaking_20,  
		  
		 --golf  
		 MAX(CASE WHEN cs.bettype = 1 AND cs.sporttype=10 THEN cs.apositiontaking ELSE 0 END) AS v10apositiontaking_1,  
		 MAX(CASE WHEN cs.bettype = 2 AND cs.sporttype=10 THEN cs.apositiontaking ELSE 0 END) AS v10apositiontaking_2,  
		 MAX(CASE WHEN cs.bettype = 3 AND cs.sporttype=10 THEN cs.apositiontaking ELSE 0 END) AS v10apositiontaking_3,  
		 MAX(CASE WHEN cs.bettype = 20 AND cs.sporttype=10 THEN cs.apositiontaking ELSE 0 END) AS v10apositiontaking_20,  
		  
		 MAX(CASE WHEN cs.bettype = 1 AND cs.sporttype=10 THEN cs.mpositiontaking ELSE 0 END) AS v10mpositiontaking_1,  
		 MAX(CASE WHEN cs.bettype = 2 AND cs.sporttype=10 THEN cs.mpositiontaking ELSE 0 END) AS v10mpositiontaking_2,  
		 MAX(CASE WHEN cs.bettype = 3 AND cs.sporttype=10 THEN cs.mpositiontaking ELSE 0 END) AS v10mpositiontaking_3,  
		 MAX(CASE WHEN cs.bettype = 20 AND cs.sporttype=10 THEN cs.mpositiontaking ELSE 0 END) AS v10mpositiontaking_20,  
		  
		 MAX(CASE WHEN cs.bettype = 1 AND cs.sporttype=10 THEN cs.spositiontaking ELSE 0 END) AS v10spositiontaking_1,  
		 MAX(CASE WHEN cs.bettype = 2 AND cs.sporttype=10 THEN cs.spositiontaking ELSE 0 END) AS v10spositiontaking_2,  
		 MAX(CASE WHEN cs.bettype = 3 AND cs.sporttype=10 THEN cs.spositiontaking ELSE 0 END) AS v10spositiontaking_3,  
		 MAX(CASE WHEN cs.bettype = 20 AND cs.sporttype=10 THEN cs.spositiontaking ELSE 0 END) AS v10spositiontaking_20,  
		  
		 --motosports  
		 MAX(CASE WHEN cs.bettype = 1 AND cs.sporttype=11 THEN cs.apositiontaking ELSE 0 END) AS v11apositiontaking_1,  
		 MAX(CASE WHEN cs.bettype = 20 AND cs.sporttype=11 THEN cs.apositiontaking ELSE 0 END) AS v11apositiontaking_20,  
		  
		 MAX(CASE WHEN cs.bettype = 1 AND cs.sporttype=11 THEN cs.mpositiontaking ELSE 0 END) AS v11mpositiontaking_1,  
		 MAX(CASE WHEN cs.bettype = 20 AND cs.sporttype=11 THEN cs.mpositiontaking ELSE 0 END) AS v11mpositiontaking_20,  
		  
		 MAX(CASE WHEN cs.bettype = 1 AND cs.sporttype=11 THEN cs.spositiontaking ELSE 0 END) AS v11spositiontaking_1,  
		 MAX(CASE WHEN cs.bettype = 20 AND cs.sporttype=11 THEN cs.spositiontaking ELSE 0 END) AS v11spositiontaking_20,  
		  
		 --other sports  
		 MAX(CASE WHEN cs.bettype = 1 AND cs.sporttype=99 THEN cs.apositiontaking ELSE 0 END) AS v99apositiontaking_1,  
		 MAX(CASE WHEN cs.bettype = 2 AND cs.sporttype=99 THEN cs.apositiontaking ELSE 0 END) AS v99apositiontaking_2,  
		 MAX(CASE WHEN cs.bettype = 3 AND cs.sporttype=99 THEN cs.apositiontaking ELSE 0 END) AS v99apositiontaking_3,  
		 MAX(CASE WHEN cs.bettype = 20 AND cs.sporttype=99 THEN cs.apositiontaking ELSE 0 END) AS v99apositiontaking_20,  
		  
		 MAX(CASE WHEN cs.bettype = 1 AND cs.sporttype=99 THEN cs.mpositiontaking ELSE 0 END) AS v99mpositiontaking_1,  
		 MAX(CASE WHEN cs.bettype = 2 AND cs.sporttype=99 THEN cs.mpositiontaking ELSE 0 END) AS v99mpositiontaking_2,  
		 MAX(CASE WHEN cs.bettype = 3 AND cs.sporttype=99 THEN cs.mpositiontaking ELSE 0 END) AS v99mpositiontaking_3,  
		 MAX(CASE WHEN cs.bettype = 20 AND cs.sporttype=99 THEN cs.mpositiontaking ELSE 0 END) AS v99mpositiontaking_20,  
		  
		 MAX(CASE WHEN cs.bettype = 1 AND cs.sporttype=99 THEN cs.spositiontaking ELSE 0 END) AS v99spositiontaking_1,  
		 MAX(CASE WHEN cs.bettype = 2 AND cs.sporttype=99 THEN cs.spositiontaking ELSE 0 END) AS v99spositiontaking_2,  
		 MAX(CASE WHEN cs.bettype = 3 AND cs.sporttype=99 THEN cs.spositiontaking ELSE 0 END) AS v99spositiontaking_3,  
		 MAX(CASE WHEN cs.bettype = 20 AND cs.sporttype=99 THEN cs.spositiontaking ELSE 0 END) AS v99spositiontaking_20,  
		  
		 -- MixParlay of Mixed Sports  
		 MAX(CASE WHEN cs.bettype = 9 AND cs.sporttype=99 THEN cs.apositiontaking ELSE 0 END) AS v99apositiontaking_9,  
		 MAX(CASE WHEN cs.bettype = 9 AND cs.sporttype=99 THEN cs.mpositiontaking ELSE 0 END) AS v99mpositiontaking_9,  
		 MAX(CASE WHEN cs.bettype = 9 AND cs.sporttype=99 THEN cs.spositiontaking ELSE 0 END) AS v99spositiontaking_9 ,
		 
		 -- HR Fixed Odds
		 max(case when cs.bettype = 20 and cs.sporttype = 154 then cs.apositiontaking else 0 end) as v154apositiontaking_20,
		 max(case when cs.bettype = 20 and cs.sporttype = 154 then cs.mpositiontaking else 0 end) as v154mpositiontaking_20,
		 max(case when cs.bettype = 20 and cs.sporttype = 154 then cs.spositiontaking else 0 end) as v154spositiontaking_20
		   
		 -- Finance
		-- MAX(cs3rd.v201apt_3) as v201apositiontaking_3,	
		-- MAX(cs3rd.v201mpt_3) as v201mpositiontaking_3,	
		-- MAX(cs3rd.v201spt_3) as v201spositiontaking_3, 
		--
		-- MAX(cs3rd.v201apt_2) as v201apositiontaking_2,	
		-- MAX(cs3rd.v201mpt_2) as v201mpositiontaking_2,	
		-- MAX(cs3rd.v201spt_2) as v201spositiontaking_2
		 
		---- Horse  
		-- MAX(cs3rd.v151apt_31) as v151apositiontaking_31,  
		-- MAX(cs3rd.v151apt_32) as v151apositiontaking_32,  
		-- MAX(cs3rd.v151apt_41) as v151apositiontaking_41,  
		-- MAX(cs3rd.v151apt_41) as v151apositiontaking_42,  
		--   
		-- MAX(cs3rd.v151mpt_31) as v151mpositiontaking_31,  
		-- MAX(cs3rd.v151mpt_32) as v151mpositiontaking_32,  
		-- MAX(cs3rd.v151mpt_41) as v151mpositiontaking_41,  
		-- MAX(cs3rd.v151mpt_41) as v151mpositiontaking_42,  
		--   
		-- MAX(cs3rd.v151spt_31) as v151spositiontaking_31,  
		-- MAX(cs3rd.v151spt_32) as v151spositiontaking_32,  
		-- MAX(cs3rd.v151spt_41) as v151spositiontaking_41,  
		-- MAX(cs3rd.v151spt_41) as v151spositiontaking_42  
		   
		FROM   
		 custinfo AS ci WITH (NOLOCK)  
		 INNER JOIN CustSetting AS cs WITH (NOLOCK) ON ci.custid = cs.custid  
		 --INNER JOIN #setting3rd AS cs3rd WITH (NOLOCK) ON ci.custid = cs3rd.custid   
		WHERE   
		 ci.Recommend = @recommend AND ci.roleid=1   
		GROUP BY  
		 ci.enabled, ci.closed, ci.reject, ci.username, ci.custid  				
	) t
	WHERE RowNumber >= (@PageIndex-1)*@PageSize + 1 AND RowNumber <= @PageIndex*@PageSize	

END

GO
GRANT EXECUTE ON [dbo].[Age_CustomerSelPositionTakingByAg] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_CustomerSelPositionTakingByAg] TO [bodbDownlineNetView]
GO
GRANT VIEW DEFINITION ON [dbo].[Age_CustomerSelPositionTakingByAg] TO [VNTeam]
GO 