/*<info serverAlias="DBAGE-bodb02" executers="bodbDownlineNet,bodbDownlineNetView" isFunction="0" isNested="0"></info>*/
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
	
	Param's Explanation:
		. @ReportType:  1: Report by UserName
						2: Report by Daily
						3: Report by Product
					
		. @Currency: If @Currency <> 0 then filter this @currency
					 If @Currency = 0 then show all currency
		. @ProductDetails:		
			<ROOT>
					<ProductDetail ProductId = "32" Sporttype = "248" Bettype = "0"/>
					<ProductDetail ProductId = "32" Sporttype = "248" Bettype = "4298"/>
			</ROOT>
*/  

BEGIN
	SET NOCOUNT ON
	
	DECLARE @fdate SMALLDATETIME, @tdate SMALLDATETIME
	SELECT @fdate = @FromDate, @tdate = @ToDate

	DECLARE @AgencyWinloss AS TABLE 
	(
		winlostdate     DATETIME,
		custid		    INT,	
		username		VARCHAR(30),	
		currency		TINYINT,								
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
	DECLARE @ExistingProductDetails TABLE (ProductId INT,Sporttype INT,Bettype INT)
	CREATE TABLE #TmpCondSumWL (ProductID TINYINT, sporttype SMALLINT, bettype SMALLINT)
	CREATE TABLE #TmpCust (CustID INT, RoleID INT, username VARCHAR(30), currency TINYINT)

	DECLARE	@isSAg	INT,
			@isMAg	INT,
			@isAg	INT,
			@isMem	INT,
			@__ProductDetails XML;

	DECLARE @GroupID INT 
	SELECT @GroupID = GRoupID FROM custAccount WITH (NOLOCK) WHERE CustID = @CustID AND IsGroupHeadLine = 1

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

	CREATE TABLE #SportBettype (ProductID INT, Bettype INT, RefTable TINYINT)

	CREATE CLUSTERED INDEX ix_SportBettype_cl ON #SportBettype(Bettype)

	SELECT @ProductIds = dbo.f_AddRelatedProducts(@ProductIds)

	IF ISNULL(@ProductDetails,'') = ''
	BEGIN 
		INSERT INTO @ExistingProductDetails
		(
			ProductId
			,Sporttype
			,Bettype
		)
		VALUES(NULL, NULL, NULL)
	END
	ELSE IF ISNULL(@ProductDetails,'')  = 'All'
	BEGIN
		INSERT INTO @ExistingProductDetails
		(
			ProductId
			,Sporttype
			,Bettype
		)
		SELECT 
			ProductId
			,Sporttype
			,Bettype
		FROM dbo.f_GetProductDetail() f
	END
	ELSE 		
	BEGIN	
		SELECT @__ProductDetails = CONVERT(XML, @ProductDetails)

		INSERT INTO @ExistingProductDetails
		(
			ProductId
			,Sporttype
			,Bettype
		)
		SELECT 
			t.c.value('(@ProductId)[1]', 'SMALLINT') AS ProductID
			, t.c.value('(@Sporttype)[1]', 'SMALLINT') AS Sporttype
			, t.c.value('(@Bettype)[1]', 'SMALLINT') AS Bettype
		FROM @__ProductDetails.nodes('ROOT/ProductDetail') t(c)
	END

	INSERT INTO #SportBettype (ProductID, Bettype, RefTable)
	SELECT ISNULL(p.GroupProductId, s.ProductID), s.Bettype, s.RefTable
	FROM dbo.f_SportBettypeMatrixByProduct(@ProductIds, @isTest) s
		LEFT JOIN dbo.f_GroupProduct() p ON s.ProductID = p.ProductId
		LEFT JOIN @ExistingProductDetails e ON e.ProductId = s.ProductID
	WHERE EXISTS(SELECT 1
				 WHERE e.ProductId IS NULL 
					OR 
						(
							e.Bettype = s.BetType 
							OR (e.Bettype = 0 AND s.BetType NOT IN (SELECT g.Bettype FROM f_GetProductDetail() g))
						)
				 )

	INSERT INTO #TmpCondSumWL(ProductID, sporttype, bettype)
	SELECT ISNULL(p.GroupProductId, s.ProductID), s.SportType, s.BetType
	FROM dbo.f_SumWinloss_ConditionSel(@ProductIds) s
		LEFT JOIN dbo.f_GroupProduct() p ON s.ProductID = p.ProductId
		LEFT JOIN @ExistingProductDetails e ON s.ProductID = e.ProductId
	WHERE e.ProductId IS NULL OR (e.Bettype = s.BetType)
		
	IF @ToDate >= @BalanceUpDay
	BEGIN
		IF @FromDate <= @MoveBetsDay
		BEGIN
			SET @fdate = DATEADD(DD, 1, @MoveBetsDay)
		END

		IF @isSAg = 1 
		BEGIN 
			---Super agent 
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
			SELECT b.winlostdate, b.srecommend, c.username, c.currency
				,s.ProductID
				,4 RoleID
				,SUM(ABS(b.stake)) as TurnOver
				,SUM(winlost-actual_stake) winlost
				,SUM(playercomm) playercomm
				,SUM(ABS(b.stake)*spositiontaking) ownerturnover
				,SUM(swinlost) ownerwinlost
				,SUM(scomm) ownercomm
				,SUM(acomm) precomm
				,SUM(ISNULL(awinlost,0)) + SUM(ISNULL(mwinlost,0)) + SUM(ISNULL(swinlost,0)) + SUM(ISNULL(scomm,0)) + SUM(ISNULL(winlost,0)-ISNULL(actual_stake,0)) company
				,COUNT(1) betcount
				,SUM(CASE
						WHEN s.RefTable IN (1, 2) THEN 0
						WHEN b.tpositiontaking = 1 THEN 0
						ELSE scomm / (1 - b.tpositiontaking)
					END) AS GrossComm
			FROM	bettrans b WITH(NOLOCK) 
				INNER JOIN #SportBettype s ON b.bettype = s.bettype
				INNER JOIN #TmpCust c ON b.srecommend = c.CustID
			WHERE	winlostdate BETWEEN @fdate AND @tdate
				AND StatusID IN (111, 112, 113) 
				AND c.roleID = 4
			GROUP BY  b.srecommend, b.winlostdate, s.ProductID, c.username, c.currency

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
			SELECT b.winlostdate, b.mrecommend, c.username, c.currency
				,s.ProductID
				,3 RoleID 
				,SUM(ABS(b.stake)) as TurnOver
				,SUM(winlost-actual_stake) winlost
				,SUM(playercomm) playercomm
				,SUM(ABS(b.stake)*mpositiontaking) ownerturnover
				,SUM(mwinlost) ownerwinlost
				,SUM(acomm) ownercomm 
				,SUM(comm) precomm
				,SUM(ISNULL(awinlost,0)) + SUM(ISNULL(mwinlost,0)) + SUM(ISNULL(acomm,0)) + SUM(ISNULL(winlost,0)-ISNULL(actual_stake,0)) company
				,COUNT(1) betcount
				,SUM(CASE
						WHEN s.RefTable IN (1, 2) THEN 0
						WHEN b.apositiontaking + b.mpositiontaking = 1 THEN 0
						ELSE b.acomm / (1 - b.apositiontaking - b.mpositiontaking)
					END) AS GrossComm
			FROM	bettrans b WITH(NOLOCK) 
				INNER JOIN #SportBettype s ON b.bettype = s.bettype
				INNER JOIN #TmpCust c ON b.mrecommend = c.CustID
			WHERE	winlostdate BETWEEN @fdate AND @tdate
				AND StatusID IN (111, 112, 113) 
				AND c.roleID = 3
			GROUP BY 
				b.mrecommend, b.winlostdate, s.ProductID, c.username, c.currency

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
			SELECT b.winlostdate,  b.recommend, c.username, c.currency
				,s.ProductID
				,2 RoleID
				,SUM(ABS(b.stake)) as TurnOver
				,SUM(winlost-actual_stake) winlost
				,SUM(playercomm) playercomm
				,SUM(ABS(b.stake)*apositiontaking) ownerturnover
				,SUM(awinlost) ownerwinlost
				,SUM(comm) ownercomm
				,SUM(playercomm) precomm
				,SUM(ISNULL(awinlost,0)) + SUM(ISNULL(comm,0)) + SUM(ISNULL(winlost,0)-ISNULL(actual_stake,0)) company
				,COUNT(1) betcount
				,SUM(CASE
						WHEN s.RefTable IN (1, 2) THEN 0
						WHEN b.apositiontaking = 1 THEN 0
						ELSE b.comm / (1 - b.apositiontaking)
					END) AS GrossComm
			FROM	bettrans b WITH(NOLOCK) 
				INNER JOIN #SportBettype s ON b.bettype = s.bettype
				INNER JOIN #TmpCust c ON b.recommend = c.CustID
			WHERE	b.winlostdate BETWEEN @fdate AND @tdate
				AND b.StatusID IN (111, 112, 113) 
				AND c.roleID = 2
			GROUP BY 
				b.recommend, b.winlostdate, s.ProductID, c.username, c.currency

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
			SELECT b.winlostdate, b.CustID, c.username, c.currency
				,s.ProductID
				,1 RoleID 
				,SUM(ABS(b.stake)) as TurnOver
				,0 as winlost
				,0 as playercomm
				,SUM(ABS(b.stake)) as ownerturnover
				,SUM(winlost-actual_stake) ownerwinlost
				,SUM(playercomm) as ownercomm
				,0 as precomm
				,SUM(ISNULL(winlost,0)-ISNULL(actual_stake,0)) +SUM(playercomm) company
				,COUNT(1) betcount
				,SUM(CASE
						WHEN s.RefTable IN (1, 2) THEN 0
						ELSE b.playercomm
					END) AS GrossComm
			FROM	bettrans b WITH(NOLOCK) 
				INNER JOIN #SportBettype s ON b.bettype = s.bettype
				INNER JOIN #TmpCust c ON b.custid = c.CustID
			WHERE	winlostdate BETWEEN @fdate AND @tdate
				AND StatusID IN (111, 112, 113) 
				AND roleID = 1
			GROUP BY 
				b.CustID, b.winlostdate, s.ProductID, c.username, c.currency

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
		                          username VARCHAR(30), currency TINYINT, RoleID int, 								  
								  ProductID TINYINT, sporttype smallint,bettype smallint, BetCount int,
								  turnover Money, playercomm Money, scomm Money, acomm Money, Comm Money,
								  awinlost Money, mwinlost Money, swinlost Money, winlost Money, netTurnover Money, grosscomm Money
								)

		INSERT INTO #Tmpsum_winloss
		( 
			winlostdate, custid, recommend, mrecommend, srecommend ,username, currency, RoleID, 
			ProductID, sporttype, bettype, BetCount,
			turnover, playercomm, scomm, acomm, Comm,
			awinlost, mwinlost, swinlost, winlost, netTurnover, grosscomm
		)
		SELECT      b.winlostdate, b.custid, b.recommend, b.mrecommend, b.srecommend,
		            c.username, c.currency, b.RoleID, 
					t.ProductID, b.sporttype ,b.bettype, b.betCount,
					ABS(b.turnover) as turnover, b.playercomm, b.scomm, b.acomm, b.Comm,
					b.awinlost, b.mwinlost, b.swinlost, b.winlost, ABS(b.netTurnover) as netTurnover,
					b.grosscomm 
		FROM	sum_winloss b WITH(NOLOCK) 		
			INNER JOIN #TmpCondSumWL t ON b.sporttype = t.sporttype AND b.bettype = t.bettype  
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
				       AND ( 
					        (t.RoleID = 2 AND s.recommend = t.custid AND s.roleid = 1) OR 
							(t.RoleID = 3 AND s.mrecommend = t.custid AND s.roleid = 2) OR
							(t.RoleID = 4 AND s.srecommend = t.custid AND s.roleid = 3))
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
		CREATE TABLE #TmpSum_WinLoss_Old ( winlostdate Datetime, custid int,recommend INT, mrecommend INT, srecommend INT,username VARCHAR(30), currency TINYINT, RoleID int, 
									  ProductID TINYINT, sporttype smallint,bettype smallint, BetCount int,
									  turnover Money, playercomm Money, scomm Money, acomm Money, Comm Money,
									  awinlost Money, mwinlost Money, swinlost Money, winlost Money, netTurnover Money, grosscomm Money
									)

		INSERT INTO #TmpSum_WinLoss_Old
		(
			winlostdate, custid, recommend, mrecommend, srecommend ,username, currency, RoleID, 
			ProductID, sporttype, bettype, BetCount,
			turnover, playercomm, scomm, acomm, Comm,
			awinlost, mwinlost, swinlost, winlost, netTurnover, grosscomm
		)
		SELECT      b.winlostdate, b.custid, b.recommend, b.mrecommend, b.srecommend ,c.username, c.currency, b.RoleID, 
					t.ProductID, b.sporttype, b.bettype, b.betCount,
					ABS(b.turnover) as turnover, b.playercomm, b.scomm, b.acomm, b.Comm,
					b.awinlost, b.mwinlost, b.swinlost, b.winlost, ABS(b.netTurnover) as netTurnover, b.grosscomm
		FROM	bodb_Summary.dbo.Sum_WinLoss_Old b WITH(NOLOCK) 		
			INNER JOIN #TmpCondSumWL t ON b.sporttype = t.sporttype AND b.bettype = t.bettype  
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
					   AND s.bettype = t.bettype
					   AND ( 
					         (t.RoleID = 2 AND s.recommend = t.custid AND s.roleid = 1) OR 
							 (t.RoleID = 3 AND s.mrecommend = t.custid AND s.roleid = 2) OR
				             (t.RoleID = 4 AND s.srecommend = t.custid AND s.roleid = 3))
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
END
GO