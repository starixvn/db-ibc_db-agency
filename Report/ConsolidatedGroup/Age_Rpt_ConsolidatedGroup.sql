/*<info serverAlias="DBAGE-bodb02" executers="wsv_alp,wsv_alpv" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Age_Rpt_ConsolidatedGroup]
	@CustID			INT, 
	@Currency		INT,
	@FromDate		SMALLDATETIME,  
	@ToDate			SMALLDATETIME,   
	@ProductIDs		VARCHAR(MAX),
	@ProductDetails NVARCHAR(MAX) = 'All',
	@ReportType		TINYINT = 1,  
	@BalanceUpDay	SMALLDATETIME,
	@MoveBetsDay	SMALLDATETIME
AS  

/*	
	Created: Elodie
	Date: 2013-06-12
	Task : Consolidated Report
	DB: DBAGE/bodb02
	Original:  

	Revisions:   
		- 20140303@Kathy: Apply Keno product (from 1501 -> 1599)[Redmine:#12691]
		- 20150513@Sophia: Apply Gold Deluxe [Redmine: #35278] and support matrix Sporttype - Bettype
		- 20150831@Winnie: Include CB [Redmine: #42409]
		- 20151110@Percy: Include CustID in select result [RedmineID: #47201]
		- 20151209@Percy: Add new bettype: Cock Fighting Sabong [Redmine: #48601]
		- 20160108@Percy: Include new bettype range into the current RNG Casino [Redmine: #48283]
		- 20160129@Percy: Support new sport Cricket [Redmine: #50027]
		- 20160318@Percy: Support AllBet [Redmine: #50605]
		- 20160413@Percy: Support Voidbridge single wallet [Redmine: #55259]
		- 20160607@Percy: Enhance Performance - Remove WITH RECOMPILE, link-server DBSUM [Redmine: #58288]
		- 20160809@Johnson: Integrate NG2 [Redmine: #61397]			
		- 20161028@Percy: Support Fishing World [RedmineID: #65731]
		- 20170622@Percy: Combine Betradar Virtual Sports with Virtual Sports [RedmineID: #78339]
		- 20170705@Percy: Support Keno Lottery [RedmineID: #78064]
		- 20170905@Percy: Expand bettype range of OneRnG Casino [RedmineID: #78424]
		- 20170908@Paul: Change report by Sport to report by Product; Enhance code [RedmineID: #77598]
		- 20190826@Percy: Remove inactive products [RedmineID: #118699]
		- 20200310@Malcolm : Add gross comm column [RedmineID : #129918]
		- 20200316@Malcolm : fix bug show incorrect grosscomm value on range sum [Redmine : #129918]
		- 20200909@Malcolm : Report Enhancement for Jackpot Product [RedmineID : #139575]
		- 20211122@Percy: Enhance gross comm formula [RedmineID: #164479]
		- 20220208@Danny: Separate Saba Sport Performance [Redmine: #167177]
		- 20221208@Eddie: Add New SABA ESports PinGoal [RedmineID: #181383]
		- 20221229@Bobby: Enhance GrossComm figure [RedmineID: #182155]
		- 20230302@Danny: Group VS product in range14, bk [RedmineID: #184618]
		- 20230630@Lewis: Add Saba Tennis [RedmineID: #190459]
		- 20240103@Lewis: Hotfix - Incorrect Owner's Turnover formula at Master, Agent Level [RedmineID: #199262]
		- 20240306@Lewis: Add Virtual Ice Hockey [RedmineID: #201129]
		- 20240515@Lewis: Add SABA Kabaddi [RedmineID: #203763]
		- 20241119@Lewis: Direct Member [RedmineId: #211969]
		- 20250512@Dave: Change datatype for ExchangeID [RedmineID: #226762]
		- 20250514@Dave: Add Saba Soccer Marble Spinner - leaguegroupid = 252 [RedmineID: #223130]
	
	Param's Explanation:
		. @ReportType:  1: Report by UserName
						2: Report by Daily
						3: Report by Product
					
		. @Currency: If @Currency <> 0 then filter this @currency
					 If @Currency = 0 then show all currency
		. @ProductDetails:		
			N'<ROOT>
                <ProductDetail ProductId="32" Sporttype="248" Bettype="0" LeagueGroupId="0" TicketType="0"/>
                <ProductDetail ProductId="32" Sporttype="248" Bettype="4297" LeagueGroupId="0" TicketType="0"/>
                <ProductDetail ProductId="32" Sporttype="248" Bettype="4298" LeagueGroupId="0" TicketType="0"/>
                <ProductDetail ProductId="45" Sporttype="243" Bettype="0" LeagueGroupId="0" TicketType="0"/>
                <ProductDetail ProductId="45" Sporttype="243" Bettype="3150" LeagueGroupId="0" TicketType="0"/>
                <ProductDetail ProductId="36" Sporttype="247" Bettype="0" LeagueGroupId="0" TicketType="0"/>
                <ProductDetail ProductId="36" Sporttype="247" Bettype="4599" LeagueGroupId="0" TicketType="0"/>
                <ProductDetail ProductId="36" Sporttype="247" Bettype="4600" LeagueGroupId="0" TicketType="0"/>
                <ProductDetail ProductId="21" Sporttype="211" Bettype="0" LeagueGroupId="0" TicketType="0"/>
                <ProductDetail ProductId="21" Sporttype="211" Bettype="2499" LeagueGroupId="0" TicketType="0"/>
                <ProductDetail ProductId="1" Sporttype="0" Bettype="0" LeagueGroupId="0" TicketType="0"/>
                <ProductDetail ProductId="1" Sporttype="0" Bettype="0" LeagueGroupId="0" TicketType="1"/>
                <ProductDetail ProductId="1" Sporttype="1" Bettype="0" LeagueGroupId="42" TicketType="0"/>
                <ProductDetail ProductId="1" Sporttype="1" Bettype="0" LeagueGroupId="74" TicketType="0"/>
                <ProductDetail ProductId="1" Sporttype="1" Bettype="0" LeagueGroupId="108" TicketType="0"/>
                <ProductDetail ProductId="1" Sporttype="2" Bettype="0" LeagueGroupId="42" TicketType="0"/>
                <ProductDetail ProductId="1" Sporttype="50" Bettype="0" LeagueGroupId="42" TicketType="0"/>
                <ProductDetail ProductId="1" Sporttype="1" Bettype="0" LeagueGroupId="113" TicketType="0"/>
                <ProductDetail ProductId="1" Sporttype="2" Bettype="0" LeagueGroupId="122" TicketType="0"/>
             </ROOT>'
*/  

BEGIN
	SET NOCOUNT ON
	
	DECLARE @fdate SMALLDATETIME, @tdate SMALLDATETIME
	SELECT @fdate = @FromDate, @tdate = @ToDate

	DECLARE @SeparateSabaSport_Cutoff SMALLDATETIME 

	SELECT @SeparateSabaSport_Cutoff = CutoffDate
	FROM dbo.f_GetCutoffDate()
	WHERE TypeName = 'SabaSport'

	DECLARE @AgencyWinloss AS TABLE 
	(
		winlostdate     DATETIME,
		custid		    INT,	
		username		VARCHAR(30),	
		currency		SMALLINT,								
		ProductID	    TINYINT,
		RoleID		    INT,
		turnover	    MONEY,
		winlost		    MONEY,
		playercomm	    MONEY,
		ownerturnover   MONEY,
		ownerwinlost    MONEY,
		ownercomm	    MONEY,
		precomm		    MONEY,
		company		    MONEY,
		betcount	    INT,
		GrossComm       MONEY
	)

	DECLARE @GrossComm TABLE (winlostdate DATETIME, custid INT, ProductId TINYINT, GrossComm MONEY)
	DECLARE @ExistingProductDetails TABLE (ProductId INT,Sporttype SMALLINT,Bettype INT, LeagueGroupID SMALLINT, TicketType TINYINT)
	CREATE TABLE #TmpCondSumWL (ProductID TINYINT, sporttype SMALLINT, bettype SMALLINT, LeagueGroupID SMALLINT, TicketType TINYINT)
	CREATE TABLE #TmpCust (CustID INT, RoleID INT, username VARCHAR(30), currency SMALLINT)

	DECLARE	@isSAg	INT,
			@isMAg	INT,
			@isAg	INT,
			@isMem	INT,
			@__ProductDetails XML;

	DECLARE @GroupID INT 
	SELECT @GroupID = GRoupID FROM custAccount WITH (NOLOCK) WHERE CustID = @CustID AND IsGroupHeadLine = 1
	SELECT @__ProductDetails = CONVERT(XML, @ProductDetails)

	SELECT	@isSAg = MAX(CASE WHEN RoleID = 4 THEN 1 ELSE 0 END),
			@isMAg = MAX(CASE WHEN RoleID = 3 THEN 1 ELSE 0 END),
			@isAg  = MAX(CASE WHEN RoleID = 2 THEN 1 ELSE 0 END),
			@isMem = MAX(CASE WHEN RoleID = 1 THEN 1 ELSE 0 END)
	FROM	custAccount WITH (NOLOCK)
		INNER JOIN custInfo c WITH (NOLOCK) ON c.custid = custAccount.custid
	WHERE	GroupID = @GroupID 

	INSERT INTO #TmpCust (CustID, RoleID, username, currency)
	SELECT c.custid, c.roleid, c.username, c.currency
	FROM custAccount WITH (NOLOCK)
		INNER JOIN Customer c WITH (NOLOCK) ON c.custid = custAccount.custid
	WHERE groupID = @GroupID
		AND c.currency = CASE WHEN @currency = 0 THEN c.Currency ELSE @currency END

	CREATE CLUSTERED INDEX ix_TmpCust_cl ON #TmpCust(CustID)

	DECLARE @isTest BIT = 0
	SELECT  @isTest = dbo.f_CheckSPVersion(@@PROCID)

	CREATE TABLE #SportBettype (ProductID INT, Bettype INT, RefTable TINYINT, LeagueGroupID INT, TicketType SMALLINT, SportType SMALLINT)

	CREATE CLUSTERED INDEX ix_SportBettype_cl ON #SportBettype(Bettype)

	SELECT @ProductIds = dbo.f_AddRelatedProducts(@ProductIds)

	INSERT INTO @ExistingProductDetails(ProductId,Sporttype,Bettype,LeagueGroupID,TicketType)
	SELECT ProductId,Sporttype,Bettype,LeagueGroupID,TicketType
	FROM dbo.f_ProductDetail_ConditionSel(@ProductDetails, @__ProductDetails)

	INSERT INTO #SportBettype (ProductID, Bettype, RefTable, LeagueGroupID, TicketType, SportType)
	SELECT ISNULL(p.GroupProductId, s.ProductID), s.Bettype, s.RefTable, ISNULL(e.LeagueGroupID,0), ISNULL(e.TicketType,0), ISNULL(e.Sporttype,0)
	FROM dbo.f_SportBettypeMatrixByProduct(@ProductIds, @isTest) s
		LEFT JOIN dbo.f_GroupProduct() p ON s.ProductID = p.ProductId
		LEFT JOIN @ExistingProductDetails e ON e.ProductId = s.ProductID
	WHERE EXISTS(SELECT 1
				 WHERE e.ProductId IS NULL 
					OR 
						(
							e.Bettype = s.BetType 
								OR (
										e.Bettype = 0  AND  (e.ProductId = 1 OR  s.BetType NOT IN (SELECT g.Bettype FROM f_GetProductDetail() g WHERE g.ProductId <> 1) )
									)
						)
				 )

	IF (@FromDate <= @MoveBetsDay)
	BEGIN
		INSERT INTO #TmpCondSumWL(SportType, BetType, LeagueGroupID, TicketType, ProductID)  
		SELECT f.SportType, f.BetType, f.LeagueGroupID, f.TicketType, ISNULL(p.GroupProductId, f.ProductID) ProductID
		FROM dbo.f_SumWinloss_ConditionSel(@ProductIds) f
			LEFT JOIN dbo.f_GroupProduct() p ON f.ProductID = p.ProductId
			LEFT JOIN @ExistingProductDetails e ON f.ProductID = e.ProductId 
		WHERE e.ProductId IS NULL OR (e.Bettype = f.BetType AND e.Sporttype = f.SportType AND e.TicketType = f.TicketType AND e.LeagueGroupID = f.LeagueGroupID AND e.ProductID = f.ProductId)
	END
		
	IF @ToDate >= @BalanceUpDay
	BEGIN
		IF @FromDate <= @MoveBetsDay
		BEGIN
			SET @fdate = DATEADD(DD, 1, @MoveBetsDay)
		END

		IF @isSAg = 1 
		BEGIN 
			---Super agent 
			;WITH cte_bettrans  AS
			(
				SELECT  b.srecommend, 
						b.winlostdate, 
						c.username, 
						c.currency,
						s.ProductID,
						SUM(ABS(b.stake)) AS Stake,
						SUM(winlost) AS winlost,
						SUM(actual_stake) AS actual_stake,
						SUM(playercomm) playercomm,
						SUM(ABS(b.stake)*spositiontaking) ownerturnover,
						SUM(swinlost) swinlost,
						SUM(mwinlost) mwinlost,
						SUM(awinlost) awinlost,
						SUM(scomm) scomm,
						SUM(acomm) acomm,
						COUNT(1) betcount,
						SUM(CASE
							WHEN s.RefTable IN (1, 2) THEN 0
							WHEN b.tpositiontaking = 1 THEN 0
							ELSE scomm / (1 - b.tpositiontaking)
						END) AS GrossComm

				FROM dbo.bettrans b WITH(NOLOCK) 
					INNER JOIN #TmpCust c ON b.srecommend = c.CustID
					LEFT JOIN dbo.match m WITH(NOLOCK) ON b.matchid = m.matchid AND m.eventdate = b.winlostdate AND m.sporttype IN (1,2,50,43,5,4,47)
					LEFT JOIN (
						SELECT LeagueGroupID, leagueid
						FROM dbo.League l WITH(NOLOCK) WHERE l.LeagueGroupID IN (42,74,108,113,122,151,252)
					 ) AS l  ON m.leagueid = l.leagueid
					 OUTER APPLY (
						SELECT CASE WHEN ( 
									(l.LeagueGroupID IN (42,74,108,113,252) AND m.sporttype = 1 ) 
									 OR (l.LeagueGroupID IN (122, 42) AND m.sporttype = 2 )
									 OR (l.LeagueGroupID = 42 AND m.sporttype = 50)
									 OR (l.LeagueGroupID = 42 AND m.sporttype = 5) --SabaTennis
									 OR (l.LeagueGroupID = 42 AND m.sporttype = 4) --Virtual Ice Hockey
									 OR (l.LeagueGroupID = 42 AND m.sporttype = 47) --SABA Kabaddi
									 OR (l.LeagueGroupID = 151 AND m.sporttype = 43)
								  ) AND b.betdaqid <> -2 AND b.winlostdate >= @SeparateSabaSport_Cutoff THEN m.sporttype
						ELSE 0 END sporttype, 
						CASE WHEN ( 
									(l.LeagueGroupID IN (42,74,108,113,252) AND m.sporttype = 1 ) 
									 OR (l.LeagueGroupID IN (122, 42) AND m.sporttype = 2 )
									 OR (l.LeagueGroupID = 42 AND m.sporttype = 50)
									 OR (l.LeagueGroupID = 42 AND m.sporttype = 5) --SabaTennis
									 OR (l.LeagueGroupID = 42 AND m.sporttype = 4) --Virtual Ice Hockey
									 OR (l.LeagueGroupID = 42 AND m.sporttype = 47) --SABA Kabaddi
									 OR (l.LeagueGroupID = 151 AND m.sporttype = 43)
								  ) AND b.betdaqid <> -2 AND b.winlostdate >= @SeparateSabaSport_Cutoff THEN l.LeagueGroupID
						ELSE 0 END LeagueGroupID,
						CASE WHEN b.betdaqid = -2 THEN 1 ELSE 0 END TicketType
					 ) AS et
					INNER JOIN #SportBettype s ON b.bettype = s.bettype AND (s.ProductID <> 1 OR (s.ProductID = 1 AND et.sporttype = s.SportType AND et.LeagueGroupID = s.LeagueGroupID AND et.TicketType = s.TicketType))
				WHERE	b.winlostdate BETWEEN @fdate AND @tdate
						AND b.StatusID IN (111, 112, 113) 
						AND c.roleID = 4
				GROUP BY  b.srecommend, b.winlostdate, c.username, c.currency, s.ProductID
			)

			INSERT INTO @AgencyWinloss
			(
				winlostdate,
				custid,	
				username,		
				currency,							
				ProductID,
				RoleID,
				turnover,
				winlost,
				playercomm,
				ownerturnover,
				ownerwinlost,
				ownercomm,
				precomm,
				company,
				betcount,
				GrossComm
			)
			SELECT b.winlostdate, b.srecommend, b.username, b.currency
				,b.ProductID
				,4 RoleID
				,SUM(ABS(b.stake)) as TurnOver
				,SUM(winlost-actual_stake) winlost
				,SUM(playercomm) playercomm
				,SUM(ownerturnover) ownerturnover
				,SUM(swinlost) ownerwinlost
				,SUM(scomm) ownercomm
				,SUM(acomm) precomm
				,SUM(awinlost) + SUM(mwinlost) + SUM(swinlost) + SUM(scomm) + SUM(winlost-actual_stake) company
				,SUM(betcount) betcount
				,SUM(GrossComm) AS GrossComm
			FROM cte_bettrans b 
			GROUP BY  b.srecommend, b.winlostdate, b.username, b.currency, b.ProductID

			IF EXISTS (SELECT 1 FROM #SportBettype WHERE RefTable = 1) -- bettransRnG
			BEGIN
				INSERT INTO @GrossComm (custid, winlostdate, ProductId, GrossComm)
				SELECT b.srecommend, b.winlostdate, s.ProductID, SUM(b.BetStake * b.sdiscount) AS GrossComm
				FROM dbo.bettransRnG b WITH (NOLOCK)
					INNER JOIN #SportBettype s ON b.GameId = s.bettype AND s.RefTable = 1
					INNER JOIN #TmpCust c ON b.srecommend = c.CustId
				WHERE b.winlostdate BETWEEN @fdate AND @tdate
					AND b.StatusId IN (111, 112, 113)
					AND c.roleID = 4
				GROUP BY b.srecommend, b.winlostdate, s.ProductID
			END

			IF EXISTS (SELECT 1 FROM #SportBettype WHERE RefTable = 2) -- bettransLC
			BEGIN
				INSERT INTO @GrossComm (custid, winlostdate, ProductId, GrossComm)
				SELECT b.srecommend, b.winlostdate, s.ProductID, SUM(b.NetStake * b.sdiscount) AS GrossComm
				FROM dbo.bettransLC b WITH (NOLOCK)
					INNER JOIN #SportBettype s ON b.GameId = s.bettype AND s.RefTable = 2
					INNER JOIN #TmpCust c ON b.srecommend = c.CustId
				WHERE b.winlostdate BETWEEN @fdate AND @tdate
					AND b.StatusId IN (111, 112, 113)
					AND c.roleID = 4
				GROUP BY b.srecommend, b.winlostdate, s.ProductID
			END

			IF EXISTS (SELECT 1 FROM @GrossComm)
			BEGIN
				UPDATE a
				SET a.GrossComm = ISNULL(a.GrossComm, 0) + ISNULL(c.GrossComm, 0)
				FROM @AgencyWinloss a
					INNER JOIN @GrossComm c ON a.custid = c.custid AND a.winlostdate = c.winlostdate AND a.ProductID = c.ProductID
			END
		END

		IF @isMAg = 1 
		BEGIN
			--- Master agent 
			;WITH cte_bettrans AS
			(	
				SELECT  b.mrecommend, 
						b.winlostdate, 
						c.username, 
						c.currency,
						s.ProductID,
						SUM(ABS(b.stake)) AS Stake,
						SUM(winlost) AS winlost,
						SUM(actual_stake) AS actual_stake,
						SUM(playercomm) playercomm,
						SUM(ABS(b.stake)*mpositiontaking) ownerturnover,
						SUM(swinlost) swinlost,
						SUM(mwinlost) mwinlost,
						SUM(awinlost) awinlost,
						SUM(scomm) scomm,
						SUM(acomm) acomm,
						SUM(comm) comm,
						COUNT(1) betcount,
						SUM(CASE
							WHEN s.RefTable IN (1, 2) THEN 0
							WHEN b.apositiontaking + b.mpositiontaking = 1 THEN 0
							ELSE b.acomm / (1 - b.apositiontaking - b.mpositiontaking)
						END) AS GrossComm

				FROM dbo.bettrans b WITH(NOLOCK) 
					INNER JOIN #TmpCust c ON b.mrecommend = c.CustID
					LEFT JOIN dbo.match m WITH(NOLOCK) ON b.matchid = m.matchid AND m.eventdate = b.winlostdate AND m.sporttype IN (1,2,50,43,5,4,47)
					LEFT JOIN (
						SELECT LeagueGroupID, leagueid
						FROM dbo.League l WITH(NOLOCK) WHERE l.LeagueGroupID IN (42,74,108,113,122,151,252)
					 ) AS l  ON m.leagueid = l.leagueid
					OUTER APPLY (
						SELECT CASE WHEN ( 
									(l.LeagueGroupID IN (42,74,108,113,252) AND m.sporttype = 1 ) 
									 OR (l.LeagueGroupID IN (122, 42) AND m.sporttype = 2 )
									 OR (l.LeagueGroupID = 42 AND m.sporttype = 50)
									 OR (l.LeagueGroupID = 42 AND m.sporttype = 5) --SabaTennis
									 OR (l.LeagueGroupID = 42 AND m.sporttype = 4) --Virtual Ice Hockey
									 OR (l.LeagueGroupID = 42 AND m.sporttype = 47) --SABA Kabaddi
									 OR (l.LeagueGroupID = 151 AND m.sporttype = 43)
								  ) AND b.betdaqid <> -2 AND b.winlostdate >= @SeparateSabaSport_Cutoff THEN m.sporttype
						ELSE 0 END sporttype, 
						CASE WHEN ( 
									(l.LeagueGroupID IN (42,74,108,113,252) AND m.sporttype = 1 ) 
									 OR (l.LeagueGroupID IN (122, 42) AND m.sporttype = 2 )
									 OR (l.LeagueGroupID = 42 AND m.sporttype = 50)
									 OR (l.LeagueGroupID = 42 AND m.sporttype = 5) --SabaTennis
									 OR (l.LeagueGroupID = 42 AND m.sporttype = 4) --Virtual Ice Hockey
									 OR (l.LeagueGroupID = 42 AND m.sporttype = 47) --SABA Kabaddi
									 OR (l.LeagueGroupID = 151 AND m.sporttype = 43)
								  ) AND b.betdaqid <> -2 AND b.winlostdate >= @SeparateSabaSport_Cutoff THEN l.LeagueGroupID
						ELSE 0 END LeagueGroupID,
						CASE WHEN b.betdaqid = -2 THEN 1 ELSE 0 END TicketType
					) AS et
					INNER JOIN #SportBettype s ON b.bettype = s.bettype AND (s.ProductID <> 1 OR (s.ProductID = 1 AND et.sporttype = s.SportType AND et.LeagueGroupID = s.LeagueGroupID AND et.TicketType = s.TicketType))
				WHERE	b.winlostdate BETWEEN @fdate AND @tdate
						AND b.StatusID IN (111, 112, 113) 
						AND c.roleID = 3
				GROUP BY  b.mrecommend, b.winlostdate, c.username, c.currency, s.ProductID
					
			)

			INSERT INTO @AgencyWinloss
			(
				winlostdate,
				custid,	
				username,	
				currency,								
				ProductID,
				RoleID,
				turnover,
				winlost,
				playercomm,
				ownerturnover,
				ownerwinlost,
				ownercomm,
				precomm,
				company,
				betcount, 
				GrossComm
			)
			SELECT b.winlostdate, b.mrecommend, b.username, b.currency
				,b.ProductID
				,3 RoleID 
				,SUM(ABS(b.stake)) as TurnOver
				,SUM(winlost-actual_stake) winlost
				,SUM(playercomm) playercomm
				,SUM(ownerturnover) ownerturnover
				,SUM(mwinlost) ownerwinlost
				,SUM(acomm) ownercomm 
				,SUM(comm) precomm
				,SUM(ISNULL(awinlost,0)) + SUM(ISNULL(mwinlost,0)) + SUM(ISNULL(acomm,0)) + SUM(ISNULL(winlost,0)-ISNULL(actual_stake,0)) company
				,SUM(betcount) betcount
				,SUM(GrossComm) AS GrossComm
			FROM	cte_bettrans b  
			GROUP BY  b.mrecommend, b.winlostdate, b.username, b.currency, b.ProductID

			DELETE @GrossComm

			IF EXISTS (SELECT 1 FROM #SportBettype WHERE RefTable = 1) -- bettransRnG
			BEGIN
				INSERT INTO @GrossComm (custid, winlostdate, ProductId, GrossComm)
				SELECT b.mrecommend, b.winlostdate, s.ProductID, SUM(b.BetStake * b.adiscount) AS GrossComm
				FROM dbo.bettransRnG b WITH (NOLOCK)
					INNER JOIN #SportBettype s ON b.GameId = s.bettype AND s.RefTable = 1
					INNER JOIN #TmpCust c ON b.mrecommend = c.CustId
				WHERE b.winlostdate BETWEEN @fdate AND @tdate
					AND b.StatusId IN (111, 112, 113)
					AND c.roleID = 3
				GROUP BY b.mrecommend, b.winlostdate, s.ProductID
			END

			IF EXISTS (SELECT 1 FROM #SportBettype WHERE RefTable = 2) -- bettransLC
			BEGIN
				INSERT INTO @GrossComm (custid, winlostdate, ProductId, GrossComm)
				SELECT b.mrecommend, b.winlostdate, s.ProductID, SUM(b.NetStake * b.adiscount) AS GrossComm
				FROM dbo.bettransLC b WITH (NOLOCK)
					INNER JOIN #SportBettype s ON b.GameId = s.bettype AND s.RefTable = 2
					INNER JOIN #TmpCust c ON b.mrecommend = c.CustId
				WHERE b.winlostdate BETWEEN @fdate AND @tdate
					AND b.StatusId IN (111, 112, 113)
					AND c.roleID = 3
				GROUP BY b.mrecommend, b.winlostdate, s.ProductID
			END

			IF EXISTS (SELECT 1 FROM @GrossComm)
			BEGIN
				UPDATE a
				SET a.GrossComm = ISNULL(a.GrossComm, 0) + ISNULL(c.GrossComm, 0)
				FROM @AgencyWinloss a
					INNER JOIN @GrossComm c ON a.custid = c.custid AND a.winlostdate = c.winlostdate AND a.ProductID = c.ProductID
			END
		END

		IF @isAg = 1
		BEGIN
			--- Agent 
			; WITH cte_bettrans AS
			(
					SELECT  b.recommend, 
						b.winlostdate, 
						c.username, 
						c.currency,
						s.ProductID,
						SUM(ABS(b.stake)) AS Stake,
						SUM(winlost) AS winlost,
						SUM(actual_stake) AS actual_stake,
						SUM(playercomm) playercomm,
						SUM(ABS(b.stake)*apositiontaking) ownerturnover,
						SUM(swinlost) swinlost,
						SUM(mwinlost) mwinlost,
						SUM(awinlost) awinlost,
						SUM(scomm) scomm,
						SUM(acomm) acomm,
						SUM(comm) comm,
						COUNT(1) betcount,
						SUM(CASE
							WHEN s.RefTable IN (1, 2) THEN 0
							WHEN b.apositiontaking = 1 THEN 0
							ELSE b.comm / (1 - b.apositiontaking)
						END) AS GrossComm

				FROM dbo.bettrans b WITH(NOLOCK) 
					INNER JOIN #TmpCust c ON b.recommend = c.CustID
					LEFT JOIN dbo.match m WITH(NOLOCK) ON b.matchid = m.matchid AND m.eventdate = b.winlostdate AND m.sporttype IN (1,2,50,43,5,4,47)
					LEFT JOIN (
						SELECT LeagueGroupID, leagueid
						FROM dbo.League l WITH(NOLOCK) WHERE l.LeagueGroupID IN (42,74,108,113,122,151,252)
					) AS l  ON m.leagueid = l.leagueid
					OUTER APPLY (
						SELECT CASE WHEN ( 
									(l.LeagueGroupID IN (42,74,108,113,252) AND m.sporttype = 1 ) 
									 OR (l.LeagueGroupID IN (122, 42) AND m.sporttype = 2 )
									 OR (l.LeagueGroupID = 42 AND m.sporttype = 50)
									 OR (l.LeagueGroupID = 42 AND m.sporttype = 5) --SabaTennis
									 OR (l.LeagueGroupID = 42 AND m.sporttype = 4) --Virtual Ice Hockey
									 OR (l.LeagueGroupID = 42 AND m.sporttype = 47) --SABA Kabaddi
									 OR (l.LeagueGroupID = 151 AND m.sporttype = 43)
								  ) AND b.betdaqid <> -2 AND b.winlostdate >= @SeparateSabaSport_Cutoff THEN m.sporttype
						ELSE 0 END sporttype, 
						CASE WHEN ( 
									(l.LeagueGroupID IN (42,74,108,113,252) AND m.sporttype = 1 ) 
									 OR (l.LeagueGroupID IN (122, 42) AND m.sporttype = 2 )
									 OR (l.LeagueGroupID = 42 AND m.sporttype = 50)
									 OR (l.LeagueGroupID = 42 AND m.sporttype = 5) --SabaTennis
									 OR (l.LeagueGroupID = 42 AND m.sporttype = 4) --Virtual Ice Hockey
									 OR (l.LeagueGroupID = 42 AND m.sporttype = 47) --SABA Kabaddi
									 OR (l.LeagueGroupID = 151 AND m.sporttype = 43)
								  ) AND b.betdaqid <> -2 AND b.winlostdate >= @SeparateSabaSport_Cutoff THEN l.LeagueGroupID
						ELSE 0 END LeagueGroupID,
						CASE WHEN b.betdaqid = -2 THEN 1 ELSE 0 END TicketType
					) AS et
					INNER JOIN #SportBettype s ON b.bettype = s.bettype AND (s.ProductID <> 1 OR (s.ProductID = 1 AND et.sporttype = s.SportType AND et.LeagueGroupID = s.LeagueGroupID AND et.TicketType = s.TicketType))
				WHERE	b.winlostdate BETWEEN @fdate AND @tdate
						AND b.StatusID IN (111, 112, 113) 
						AND c.roleID = 2
				GROUP BY  b.recommend, b.winlostdate, c.username, c.currency, s.ProductID
			)

			INSERT INTO @AgencyWinloss
			(
				winlostdate,
				custid,	
				username,	
				currency,								
				ProductID,
				RoleID,
				turnover,
				winlost,
				playercomm,
				ownerturnover,
				ownerwinlost,
				ownercomm,
				precomm,
				company,
				betcount,
				GrossComm
			)
			SELECT b.winlostdate,  b.recommend, b.username, b.currency
				,b.ProductID
				,2 RoleID
				,SUM(ABS(b.stake)) as TurnOver
				,SUM(winlost-actual_stake) winlost
				,SUM(playercomm) playercomm
				,SUM(ownerturnover) ownerturnover
				,SUM(awinlost) ownerwinlost
				,SUM(comm) ownercomm
				,SUM(playercomm) precomm
				,SUM(ISNULL(awinlost,0)) + SUM(ISNULL(comm,0)) + SUM(ISNULL(winlost,0)-ISNULL(actual_stake,0)) company
				,SUM(betcount) betcount
				,SUM(GrossComm) AS GrossComm
			FROM	cte_bettrans b 
			GROUP BY  b.recommend, b.winlostdate, b.username, b.currency, b.ProductID

			DELETE @GrossComm

			IF EXISTS (SELECT 1 FROM #SportBettype WHERE RefTable = 1) -- bettransRnG
			BEGIN
				INSERT INTO @GrossComm (custid, winlostdate, ProductId, GrossComm)
				SELECT b.recommend, b.winlostdate, s.ProductID, SUM(b.BetStake * b.discount) AS GrossComm
				FROM dbo.bettransRnG b WITH (NOLOCK)
					INNER JOIN #SportBettype s ON b.GameId = s.bettype AND s.RefTable = 1
					INNER JOIN #TmpCust c ON b.recommend = c.CustId
				WHERE b.winlostdate BETWEEN @fdate AND @tdate
					AND b.StatusId IN (111, 112, 113)
					AND c.roleID = 2
				GROUP BY b.recommend, b.winlostdate, s.ProductID
			END

			IF EXISTS (SELECT 1 FROM #SportBettype WHERE RefTable = 2) -- bettransLC
			BEGIN
				INSERT INTO @GrossComm (custid, winlostdate, ProductId, GrossComm)
				SELECT b.recommend, b.winlostdate, s.ProductID, SUM(b.NetStake * b.discount) AS GrossComm
				FROM dbo.bettransLC b WITH (NOLOCK)
					INNER JOIN #SportBettype s ON b.GameId = s.bettype AND s.RefTable = 2
					INNER JOIN #TmpCust c ON b.recommend = c.CustId
				WHERE b.winlostdate BETWEEN @fdate AND @tdate
					AND b.StatusId IN (111, 112, 113)
					AND c.roleID = 2
				GROUP BY b.recommend, b.winlostdate, s.ProductID
			END

			IF EXISTS (SELECT 1 FROM @GrossComm)
			BEGIN
				UPDATE a
				SET a.GrossComm = ISNULL(a.GrossComm, 0) + ISNULL(c.GrossComm, 0)
				FROM @AgencyWinloss a
					INNER JOIN @GrossComm c ON a.custid = c.custid AND a.winlostdate = c.winlostdate AND a.ProductID = c.ProductID
			END
		END

		IF @isMem = 1
		BEGIN
			--- member
			; WITH cte_bettrans AS
			(
				SELECT  b.CustID, 
						b.winlostdate, 
						c.username, 
						c.currency,
						s.ProductID,
						SUM(ABS(b.stake)) AS Stake,
						SUM(winlost) AS winlost,
						SUM(actual_stake) AS actual_stake,
						SUM(playercomm) playercomm,
						SUM(ABS(b.stake)) ownerturnover,
						SUM(swinlost) swinlost,
						SUM(mwinlost) mwinlost,
						SUM(awinlost) awinlost,
						SUM(scomm) scomm,
						SUM(acomm) acomm,
						SUM(comm) comm,
						COUNT(1) betcount,
						SUM(CASE
							WHEN s.RefTable IN (1, 2) THEN 0
							ELSE b.playercomm
						END) AS GrossComm
				FROM bettrans b WITH(NOLOCK) 
					INNER JOIN #TmpCust c ON b.custid = c.CustID
					LEFT JOIN dbo.match m WITH(NOLOCK) ON b.matchid = m.matchid AND m.eventdate = b.winlostdate AND m.sporttype IN (1,2,50,43,5,4,47)
					LEFT JOIN (
						SELECT LeagueGroupID, leagueid
						FROM dbo.League l WITH(NOLOCK) WHERE l.LeagueGroupID IN (42,74,108,113,122,151,252)
					) AS l  ON m.leagueid = l.leagueid
					OUTER APPLY (
						SELECT CASE WHEN ( 
									(l.LeagueGroupID IN (42,74,108,113,252) AND m.sporttype = 1 ) 
									 OR (l.LeagueGroupID IN (122, 42) AND m.sporttype = 2 )
									 OR (l.LeagueGroupID = 42 AND m.sporttype = 50)
									 OR (l.LeagueGroupID = 42 AND m.sporttype = 5) --SabaTennis
									 OR (l.LeagueGroupID = 42 AND m.sporttype = 4) --Virtual Ice Hockey
									 OR (l.LeagueGroupID = 42 AND m.sporttype = 47) --SABA Kabaddi
									 OR (l.LeagueGroupID = 151 AND m.sporttype = 43)
								  ) AND b.betdaqid <> -2 AND b.winlostdate >= @SeparateSabaSport_Cutoff THEN m.sporttype
						ELSE 0 END sporttype, 
						CASE WHEN ( 
									(l.LeagueGroupID IN (42,74,108,113,252) AND m.sporttype = 1 ) 
									 OR (l.LeagueGroupID IN (122, 42) AND m.sporttype = 2 )
									 OR (l.LeagueGroupID = 42 AND m.sporttype = 50)
									 OR (l.LeagueGroupID = 42 AND m.sporttype = 5) --SabaTennis
									 OR (l.LeagueGroupID = 42 AND m.sporttype = 4) --Virtual Ice Hockey
									 OR (l.LeagueGroupID = 42 AND m.sporttype = 47) --SABA Kabaddi
									 OR (l.LeagueGroupID = 151 AND m.sporttype = 43)
								  ) AND b.betdaqid <> -2 AND b.winlostdate >= @SeparateSabaSport_Cutoff THEN l.LeagueGroupID
						ELSE 0 END LeagueGroupID,
						CASE WHEN b.betdaqid = -2 THEN 1 ELSE 0 END TicketType
					) AS et
					INNER JOIN #SportBettype s ON b.bettype = s.bettype AND (s.ProductID <> 1 OR (s.ProductID = 1 AND et.sporttype = s.SportType AND et.LeagueGroupID = s.LeagueGroupID AND et.TicketType = s.TicketType))
				WHERE	b.winlostdate BETWEEN @fdate AND @tdate
						AND b.StatusID IN (111, 112, 113) 
						AND c.roleID = 1
				GROUP BY  b.CustID, b.winlostdate, c.username, c.currency, s.ProductID
			)

			INSERT INTO @AgencyWinloss
			(
				winlostdate,
				custid,	
				username,		
				currency,							
				ProductID,
				RoleID,
				turnover,
				winlost,
				playercomm,
				ownerturnover,
				ownerwinlost,
				ownercomm,
				precomm,
				company,
				betcount,
				GrossComm
			)
			SELECT b.winlostdate, b.CustID, b.username, b.currency
				,b.ProductID
				,1 RoleID 
				,SUM(ABS(b.stake)) as TurnOver
				,0 as winlost
				,0 as playercomm
				,SUM(ownerturnover) as ownerturnover
				,SUM(winlost-actual_stake) ownerwinlost
				,SUM(playercomm) as ownercomm
				,0 as precomm
				,SUM(ISNULL(winlost,0)-ISNULL(actual_stake,0)) +SUM(playercomm) company
				,SUM(betcount) betcount
				,SUM(GrossComm) AS GrossComm
			FROM	cte_bettrans b
			GROUP BY b.CustID, b.winlostdate, b.username, b.currency, b.ProductID

			DELETE @GrossComm

			IF EXISTS (SELECT 1 FROM #SportBettype WHERE RefTable = 1) -- bettransRnG
			BEGIN
				INSERT INTO @GrossComm (custid, winlostdate, ProductId, GrossComm)
				SELECT b.custid, b.winlostdate, s.ProductID, SUM(b.BetStake * b.playerdiscount) AS GrossComm
				FROM dbo.bettransRnG b WITH (NOLOCK)
					INNER JOIN #SportBettype s ON b.GameId = s.bettype AND s.RefTable = 1
					INNER JOIN #TmpCust c ON b.custid = c.CustId
				WHERE b.winlostdate BETWEEN @fdate AND @tdate
					AND b.StatusId IN (111, 112, 113)
					AND c.roleID = 1
				GROUP BY b.custid, b.winlostdate, s.ProductID
			END

			IF EXISTS (SELECT 1 FROM #SportBettype WHERE RefTable = 2) -- bettransLC
			BEGIN
				INSERT INTO @GrossComm (custid, winlostdate, ProductId, GrossComm)
				SELECT b.custid, b.winlostdate, s.ProductID, SUM(b.NetStake * b.playerdiscount) AS GrossComm
				FROM dbo.bettransLC b WITH (NOLOCK)
					INNER JOIN #SportBettype s ON b.GameId = s.bettype AND s.RefTable = 2
					INNER JOIN #TmpCust c ON b.custid = c.CustId
				WHERE b.winlostdate BETWEEN @fdate AND @tdate
					AND b.StatusId IN (111, 112, 113)
					AND c.roleID = 1
				GROUP BY b.custid, b.winlostdate, s.ProductID
			END

			IF EXISTS (SELECT 1 FROM @GrossComm)
			BEGIN
				UPDATE a
				SET a.GrossComm = ISNULL(a.GrossComm, 0) + ISNULL(c.GrossComm, 0)
				FROM @AgencyWinloss a
					INNER JOIN @GrossComm c ON a.custid = c.custid AND a.winlostdate = c.winlostdate AND a.ProductID = c.ProductID
			END
		END


		--**** get data from sum_winloss
		IF @BalanceUpDay < @FromDate --if this case occurs then there is no data from sum_winloss_old
		BEGIN
			SET @fdate = @FromDate
		END
		ELSE
		BEGIN
			SET @fdate = @BalanceUpDay
		END

		IF @ToDate > @MoveBetsDay
		BEGIN
			SET @tdate = @MoveBetsDay
		END

		---Insert tmptable
		CREATE TABLE #Tmpsum_winloss ( winlostdate Datetime, custid int, recommend INT, mrecommend INT, srecommend INT, 
		                          username VARCHAR(30), currency SMALLINT, RoleID int, 								  
								  ProductID TINYINT, sporttype smallint,bettype smallint, BetCount int,
								  turnover Money, playercomm Money, scomm Money, acomm Money, Comm Money,
								  awinlost Money, mwinlost Money, swinlost Money, winlost Money, netTurnover Money, grosscomm Money, LeagueGroupID SMALLINT, ticketType TINYINT
								)

		INSERT INTO #Tmpsum_winloss
		( 
			winlostdate, custid, recommend, mrecommend, srecommend ,username, currency, RoleID, 
			ProductID, sporttype, bettype, BetCount,
			turnover, playercomm, scomm, acomm, Comm,
			awinlost, mwinlost, swinlost, winlost, netTurnover, grosscomm, LeagueGroupID,ticketType
		)
		SELECT      b.winlostdate, b.custid, b.recommend, b.mrecommend, b.srecommend,
		            c.username, c.currency, b.RoleID, 
					t.ProductID, b.sporttype ,b.bettype, b.betCount,
					ABS(b.turnover) as turnover, b.playercomm, b.scomm, b.acomm, b.Comm,
					b.awinlost, b.mwinlost, b.swinlost, b.winlost, ABS(b.netTurnover) as netTurnover,
					b.grosscomm , ISNULL(b.LeagueGroupID,0), ISNULL(b.ticketType,0)
		FROM	dbo.sum_winloss b WITH(NOLOCK) 		
			INNER JOIN #TmpCondSumWL t ON b.sporttype = t.sporttype AND b.bettype = t.bettype  AND ISNULL(b.leagueGroupID,0) = t.leagueGroupID AND ISNULL(b.ticketType,0) = t.TicketType
			INNER JOIN #TmpCust c ON b.custid = c.CustID
		WHERE	winlostdate BETWEEN @fdate AND @tdate

		UPDATE t
		SET t.grosscomm = CASE WHEN t.RoleID = 1 THEN  t.playercomm
							   ELSE s.grosscomm END
		FROM #Tmpsum_winloss t
		     CROSS APPLY (
			     SELECT  SUM(s.grosscomm) grosscomm
				 FROM sum_winloss s WITH (NOLOCK)
				 WHERE s.winlostdate = t.winlostdate 
					   AND s.srecommend = t.srecommend
					   AND t.sporttype = s.sporttype
					   AND t.bettype = s.bettype
					   AND t.LeagueGroupID = ISNULL(s.leagueGroupID,0)
					   AND t.ticketType = ISNULL(s.ticketType,0)
				       AND ( 
					        (t.RoleID = 2 AND s.recommend = t.custid AND s.roleid = 1) OR 
							(t.RoleID = 3 AND s.mrecommend = t.custid AND s.recommend > 0 AND s.roleid = 2) OR
							(t.RoleID = 3 AND s.mrecommend = t.custid AND s.recommend < 0 AND s.roleid = 1) OR
							(t.RoleID = 4 AND s.srecommend = t.custid AND s.mrecommend > 0 AND s.roleid = 3) OR
							(t.RoleID = 4 AND s.srecommend = t.custid AND s.mrecommend < 0 AND s.roleid = 1)
							)
						) s
		
		IF @isSAg = 1
		BEGIN
			INSERT INTO @AgencyWinloss
			(
				winlostdate,
				custid,	
				username,	
				currency,								
				ProductID,
				RoleID,
				turnover,
				winlost,
				playercomm,
				ownerturnover,
				ownerwinlost,
				ownercomm,
				precomm,
				company,
				betcount,
				GrossComm
			)
			SELECT b.winlostdate, b.custid, b.username, b.currency, b.ProductID, b.RoleID
				,b.turnover
				,winlost
				,playercomm		
				,isnull(netTurnover,0) as ownerturnover
				,swinlost as ownerwinlost 
				,scomm as ownercomm
				,acomm as precomm
				,awinlost + mwinlost + swinlost + scomm + winlost
				,betcount
				,b.grosscomm
			FROM #Tmpsum_winloss b WITH(NOLOCK) 
			WHERE b.roleid = 4
		END 
	
		---Master 
		IF @isMAg = 1 
		BEGIN
			INSERT INTO @AgencyWinloss
			(
				winlostdate,
				custid,	
				username,
				currency,									
				ProductID,
				RoleID,
				turnover,
				winlost,
				playercomm,
				ownerturnover,
				ownerwinlost,
				ownercomm,
				precomm,
				company,
				betcount,
				GrossComm
			)
			SELECT b.winlostdate, b.custid, b.username, b.currency, b.ProductID, b.RoleID
				,b.turnover
				,winlost
				,playercomm		
				,isnull(netTurnover,0) as ownerturnover
				,mwinlost as ownerwinlost 
				,acomm as ownercomm
				,comm as precomm
				,awinlost + mwinlost + acomm + winlost
				,betcount
				,b.grosscomm
			FROM #Tmpsum_winloss b WITH(NOLOCK) 							 
			WHERE b.roleid = 3
		END	 
		---Agent  
		IF @isAg = 1 
		BEGIN
			INSERT INTO @AgencyWinloss
			(
				winlostdate,
				custid,	
				username,
				currency,									
				ProductID,
				RoleID,
				turnover,
				winlost,
				playercomm,
				ownerturnover,
				ownerwinlost,
				ownercomm,
				precomm,
				company,
				betcount,
				GrossComm
			)
			SELECT b.winlostdate, b.custid, b.username, b.currency, b.ProductID, b.RoleID
				,b.turnover
				,winlost
				,playercomm		
				,isnull(netTurnover,0) as ownerturnover
				,awinlost as ownerwinlost 
				,comm as ownercomm
				,playercomm as precomm
				,awinlost + comm + winlost
				,betcount
				,b.grosscomm
			FROM #Tmpsum_winloss b WITH(NOLOCK)  							 
			WHERE b.roleid = 2
		END		 

		---member  
		IF @isMem = 1
		BEGIN
			INSERT INTO @AgencyWinloss
			(
				winlostdate,
				custid,	
				username,	
				currency,								
				ProductID,
				RoleID,
				turnover,
				winlost,
				playercomm,
				ownerturnover,
				ownerwinlost,
				ownercomm,
				precomm,
				company,
				betcount,
				GrossComm
			)
			SELECT b.winlostdate, b.custid, b.username, b.currency, b.ProductID, b.RoleID
				,b.turnover
				,0 as winlost
				,0 as playercomm	
				,isnull(b.turnover,0) as ownerturnover
				,winlost as ownerwinlost 
				,playercomm as ownercomm
				,0 as precomm
				,winlost + playercomm
				,betcount
				,b.grosscomm
			FROM #Tmpsum_winloss b WITH(NOLOCK) 						 
			WHERE b.roleid = 1
		END

		DROP TABLE #TmpSum_WinLoss
	END

	SELECT	@fdate = @FromDate,
			@tdate = @ToDate;

	IF @FromDate < @BalanceUpDay
	BEGIN
		IF @ToDate >= DATEADD(DD, -1, @BalanceUpDay)
		BEGIN
			SELECT @tdate = DATEADD(DD, -1, @BalanceUpDay)
		END


		---Insert tmptable
		CREATE TABLE #TmpSum_WinLoss_Old ( winlostdate Datetime, custid int,recommend INT, mrecommend INT, srecommend INT,username VARCHAR(30), currency SMALLINT, RoleID int, 
									  ProductID TINYINT, sporttype smallint,bettype smallint, BetCount int,
									  turnover Money, playercomm Money, scomm Money, acomm Money, Comm Money,
									  awinlost Money, mwinlost Money, swinlost Money, winlost Money, netTurnover Money, grosscomm Money, LeagueGroupID SMALLINT, ticketType TINYINT
									)

		INSERT INTO #TmpSum_WinLoss_Old
		(
			winlostdate, custid, recommend, mrecommend, srecommend ,username, currency, RoleID, 
			ProductID, sporttype, bettype, BetCount,
			turnover, playercomm, scomm, acomm, Comm,
			awinlost, mwinlost, swinlost, winlost, netTurnover, grosscomm, LeagueGroupID, ticketType
		)
		SELECT      b.winlostdate, b.custid, b.recommend, b.mrecommend, b.srecommend ,c.username, c.currency, b.RoleID, 
					t.ProductID, b.sporttype, b.bettype, b.betCount,
					ABS(b.turnover) as turnover, b.playercomm, b.scomm, b.acomm, b.Comm,
					b.awinlost, b.mwinlost, b.swinlost, b.winlost, ABS(b.netTurnover) as netTurnover, b.grosscomm, ISNULL(b.leagueGroupID,0), ISNULL(b.ticketType,0)
		FROM	bodb_Summary.dbo.Sum_WinLoss_Old b WITH(NOLOCK) 		
			INNER JOIN #TmpCondSumWL t ON b.sporttype = t.sporttype AND b.bettype = t.bettype  AND ISNULL(b.leagueGroupID,0) = t.LeagueGroupID AND ISNULL(b.ticketType,0) = t.TicketType
			INNER JOIN #TmpCust c ON b.custid = c.CustID
		WHERE	winlostdate BETWEEN @fdate AND @tdate

		UPDATE t
		SET  t.grosscomm = CASE WHEN t.RoleID = 1 THEN  t.playercomm 
		                        ELSE s.grosscomm END
		FROM #TmpSum_WinLoss_Old t
		     CROSS APPLY (
			     SELECT SUM(s.grosscomm)  grosscomm
				 FROM bodb_Summary.dbo.Sum_WinLoss_Old s WITH (NOLOCK)
				 WHERE s.winlostdate = t.winlostdate 
                       AND s.srecommend = t.srecommend
					   AND s.sporttype = t.sporttype
					   AND ISNULL(s.leagueGroupID,0) = t.LeagueGroupID
					   AND s.bettype = t.bettype
					   AND ISNULL(s.ticketType,0) = t.ticketType
					   AND ( 
					        (t.RoleID = 2 AND s.recommend = t.custid AND s.roleid = 1) OR 
							(t.RoleID = 3 AND s.mrecommend = t.custid AND s.recommend > 0 AND s.roleid = 2) OR
							(t.RoleID = 3 AND s.mrecommend = t.custid AND s.recommend < 0 AND s.roleid = 1) OR
							(t.RoleID = 4 AND s.srecommend = t.custid AND s.mrecommend > 0 AND s.roleid = 3) OR
							(t.RoleID = 4 AND s.srecommend = t.custid AND s.mrecommend < 0 AND s.roleid = 1)
							)
						) s
	--Super	
		IF @isSAg = 1
		BEGIN
			INSERT INTO @AgencyWinloss
			(
				winlostdate,
				custid,	
				username,	
				currency,								
				ProductID,
				RoleID,
				turnover,
				winlost,
				playercomm,
				ownerturnover,
				ownerwinlost,
				ownercomm,
				precomm,
				company,
				betcount,
				GrossComm
			)
			SELECT b.winlostdate, b.custid, b.username, b.currency, b.ProductID, b.RoleID
				,b.turnover
				,winlost
				,playercomm
				,isnull(netTurnover,0) as ownerturnover
				,swinlost as ownerwinlost 
				,scomm as ownercomm
				,acomm as precomm
				,awinlost + mwinlost + swinlost + scomm + winlost
				,betcount
				,b.grosscomm
			FROM	#TmpSum_WinLoss_Old b WITH(NOLOCK) 	   
			WHERE	b.roleid = 4
		END
		 
	--Master
		IF @isMAg = 1	
		BEGIN
			INSERT INTO @AgencyWinloss
			(
				winlostdate,
				custid,	
				username,	
				currency,								
				ProductID,
				RoleID,
				turnover,
				winlost,
				playercomm,
				ownerturnover,
				ownerwinlost,
				ownercomm,
				precomm,
				company,
				betcount,
				GrossComm
			)
			SELECT winlostdate, b.custid, b.username, b.currency, b.ProductID, b.RoleID
				,b.turnover
				,winlost
				,playercomm
				,isnull(netTurnover,0) as ownerturnover
				,mwinlost as ownerwinlost 
				,acomm as ownercomm
				,comm as precomm
				,awinlost + mwinlost + acomm + winlost
				,betcount
				,b.grosscomm
			FROM	#TmpSum_WinLoss_Old b WITH(NOLOCK) 
			WHERE	b.roleid = 3
		END
	--Agent	
		IF @isAg = 1
		BEGIN 
			INSERT INTO @AgencyWinloss
			(
				winlostdate,
				custid,	
				username,	
				currency,								
				ProductID,
				RoleID,
				turnover,
				winlost,
				playercomm,
				ownerturnover,
				ownerwinlost,
				ownercomm,
				precomm,
				company,
				betcount,
				GrossComm
			)
			SELECT winlostdate, b.custid, b.username, b.currency, b.ProductID, b.RoleID
				,b.turnover
				,winlost
				,playercomm
				,isnull(netTurnover,0) as ownerturnover
				,awinlost as ownerwinlost 
				,comm as ownercomm
				,playercomm as precomm
				,awinlost + comm + winlost
				,betcount
				,b.grosscomm
			FROM	#TmpSum_WinLoss_Old b WITH(NOLOCK) 
			WHERE	b.roleid = 2
		END 
	--Member	
		IF @isMem = 1
		BEGIN
			INSERT INTO @AgencyWinloss
			(
				winlostdate,
				custid,	
				username,	
				currency,								
				ProductID,
				RoleID,
				turnover,
				winlost,
				playercomm,
				ownerturnover,
				ownerwinlost,
				ownercomm,
				precomm,
				company,
				betcount,
				GrossComm
			)
			SELECT winlostdate, b.custid, b.username, b.currency, b.ProductID, b.RoleID
				,b.turnover
				,0 as winlost
				,0 as playercomm
				,isnull(b.turnover,0) as ownerturnover
				,winlost as ownerwinlost 
				,playercomm as ownercomm
				,0 as precomm
				,winlost + playercomm
				,betcount
				,b.grosscomm
			FROM #TmpSum_WinLoss_Old b WITH(NOLOCK) 
			WHERE b.roleid = 1

		END

		DROP TABLE #TmpSum_WinLoss_Old
	END

	IF @ReportType = 1
	BEGIN
		SELECT	custID AS breakdown
				,custID 
				,username
				,currency
				,roleid
				,SUM(turnover) AS turnover
				,SUM(winlost) AS member_winlost
				,SUM(playercomm) AS member_comm
				,SUM(winlost + playercomm) AS member_total
				,SUM(ownerturnover) AS owner_turnover	
				,SUM(ownerwinlost) AS owner_winlost
				,SUM(ownercomm - precomm) AS owner_comm
				,SUM(ownerwinlost + ownercomm - precomm) AS owner_total
				,-SUM(company) AS company
				,SUM(betcount) AS betcount 
				,SUM(GrossComm) AS GrossComm
		FROM @AgencyWinloss A
		GROUP BY custID, username, currency, roleid
		ORDER BY username
	END
	
	IF @ReportType = 2
	BEGIN
		SELECT	CONVERT(VARCHAR(10), winlostdate, 111) AS breakdown
				,custID 
				,username
				,currency
				,roleid
				,SUM(turnover) AS turnover
				,SUM(winlost) AS member_winlost
				,SUM(playercomm) AS member_comm
				,SUM(winlost + playercomm) AS member_total
				,SUM(ownerturnover) AS owner_turnover	
				,SUM(ownerwinlost) AS owner_winlost
				,SUM(ownercomm - precomm) AS owner_comm
				,SUM(ownerwinlost + ownercomm - precomm) AS owner_total
				,-SUM(company) AS company
				,SUM(betcount) AS betcount 
				,SUM(GrossComm) AS GrossComm
		FROM @AgencyWinloss A
		GROUP BY CONVERT(VARCHAR(10), winlostdate, 111)  
				, custID, username, currency, roleid
		ORDER BY breakdown, username
	END

	IF @ReportType = 3
	BEGIN
		SELECT	ProductID AS breakdown
				,custID 
				,username
				,currency
				,roleid
				,SUM(turnover) AS turnover
				,SUM(winlost) AS member_winlost
				,SUM(playercomm) AS member_comm
				,SUM(winlost + playercomm) AS member_total
				,SUM(ownerturnover) AS owner_turnover	
				,SUM(ownerwinlost) AS owner_winlost
				,SUM(ownercomm - precomm) AS owner_comm
				,SUM(ownerwinlost + ownercomm - precomm) AS owner_total
				,-SUM(company) AS company
				,SUM(betcount) AS betcount 
				,SUM(GrossComm) AS GrossComm
		FROM @AgencyWinloss A
		GROUP BY ProductID, custID, username, currency, roleid
		ORDER BY breakdown, username
	END
	
	DROP TABLE #TmpCondSumWL
	DROP TABLE #TmpCust
	DROP TABLE #SportBettype
END
GO