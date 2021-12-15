/*<info serverAlias="DBAGE-bodb02" executers="bodbDownlineNet,bodbDownlineNetView" isFunction="0" isNested="0"></info>*/  
ALTER PROCEDURE [dbo].[Age_Rpt_WinLossDetailByPT_Super]      
	@CustId         INT = NULL,
	@FromDate		SMALLDATETIME,
	@ToDate			SMALLDATETIME,
	@ProductIds		VARCHAR(MAX) = '',
	@ProductDetails NVARCHAR(MAX) = 'All',
	@BalanceUpDay	SMALLDATETIME,
	@MoveBetsDay	SMALLDATETIME
AS
/*    
Created by: Evan    
Date: 2021-06-23    
Task : Implement New Report Super Win Loss Detail by PT     
DB: DBAGE/bodb02    
Revisions:    
	- 20210623@Evan: Initialize SPs [RedmineID : #157338]
	- 20211122@Percy: Enhance gross comm formula [RedmineID: #164479]

Param's Explanation:  
	@CustId: srecommend  
	@FromDate, @ToDate: date range  
	@ProductIds: list of products  
	@ProductDetails:    
		<ROOT>  
			<ProductDetail ProductId = "32" Sporttype = "248" Bettype = "0"/>  
			<ProductDetail ProductId = "32" Sporttype = "248" Bettype = "4298"/>  
		</ROOT>  
	@IsTest:  
		1: Get all products and bettypes  
		0: Get only products and bettypes which are not being tested  
*/    
BEGIN
	SET NOCOUNT ON  
	DECLARE @ExistingProductDetails TABLE 
		(
			ProductId INT,
		    Sporttype INT,
		    Bettype INT
		)    
	DECLARE @isTest BIT, @__ProductDetails XML;   

	SELECT  @isTest = dbo.f_CheckSPVersion(@@PROCID);     
	SELECT @ProductIds = dbo.f_AddRelatedProducts(@ProductIds);    
    
	IF ISNULL(@ProductDetails,'') = ''    
	BEGIN
		INSERT INTO @ExistingProductDetails
				( ProductId, Sporttype, Bettype )     	
		VALUES ( NULL, NULL, NULL )
	END    
	ELSE IF ISNULL(@ProductDetails,'')  = 'All'    
	BEGIN   
		INSERT INTO @ExistingProductDetails    
			( 
				ProductId ,   
				Sporttype ,   
				Bettype  
			)    
		SELECT	ProductId ,   
				Sporttype ,   
				Bettype    
		FROM dbo.f_GetProductDetail() f;  
	END    
	ELSE       
	BEGIN 
		SELECT @__ProductDetails = CONVERT(XML, @ProductDetails)    
		INSERT INTO @ExistingProductDetails    
			( 
				ProductId ,   
				Sporttype ,   
				Bettype    
			)    
		SELECT	t.c.value('(@ProductId)[1]', 'SMALLINT') AS ProductID ,    
				t.c.value('(@Sporttype)[1]', 'SMALLINT') AS Sporttype ,    
				t.c.value('(@Bettype)[1]', 'SMALLINT') AS Bettype    
		FROM @__ProductDetails.nodes('ROOT/ProductDetail') t(c);    
	END    
	
	CREATE TABLE #TmpCondSumWL
	(	    
		SportType INT,    
		BetType  INT,    
		ProductID INT    
	);    
	INSERT INTO #TmpCondSumWL ( SportType, BetType,ProductID )     
	SELECT	f.SportType,
			f.BetType,
			ISNULL(p.GroupProductId, f.ProductID)    
	FROM dbo.f_SumWinloss_ConditionSel(@ProductIds) f    
		LEFT JOIN @ExistingProductDetails e ON f.ProductID = e.ProductId    
		LEFT JOIN dbo.f_GroupProduct() p ON f.ProductID = p.ProductId    
	WHERE	e.ProductId IS NULL 
			OR (e.Bettype = f.BetType)    
	
	CREATE TABLE #ComWinLossDetails     
		(     
			ProductID		INT,
			Turnover		MONEY,
			TurnoverNoDraw	MONEY,
			GrossComm		MONEY, 
			MemberWinLost	MONEY,
			PlayerComm		MONEY,
			MemberTotal		MONEY,
			AgWinLost		MONEY,
			AgComm			MONEY,
			AgTotal			MONEY,
			MAgWinLost		MONEY,
			MAgComm			MONEY,
			MAgTotal		MONEY,
			SAgWinLost		MONEY, 
			SAgComm			MONEY, 
			SAgTotal		MONEY, 
			Company			MONEY
		);
	
	CREATE TABLE #GrossComm (ProductID INT, TurnoverNoDraw MONEY, GrossComm MONEY)
	
	--Avoid Parameter Sniffing for bettrans and sum_winloss    
	DECLARE @FDate SMALLDATETIME,    
			@TDate SMALLDATETIME,    
			@CID	INT;    
         
	SELECT	@FDate = @FromDate,    
			@TDate = @ToDate ,  
			@CID = @CustID;  

	IF @ToDate >= @BalanceUpDay    
	BEGIN    
		IF @FromDate <= @MoveBetsDay    
		BEGIN    
			SET @FDate = DATEADD(DD, 1, @MoveBetsDay);    
		END    
		
		INSERT INTO #ComWinLossDetails(ProductID,Turnover,TurnoverNoDraw,GrossComm,MemberWinLost,PlayerComm,MemberTotal,AgWinLost,AgComm,AgTotal,MAgWinLost,MAgComm,MAgTotal,SAgWinLost, SAgComm, SAgTotal, Company)    
		SELECT	s.ProductID, 
				SUM(ABS(b.stake)), -- Turnover  
				SUM(CASE
						WHEN s.RefTable IN (1, 2) THEN 0 -- bettransRnG/bettransLC
						WHEN s.ProductId = 47 THEN b.oddsspread -- BBIN
						WHEN s.ProductId = 1 AND b.statusId = 111 THEN 0 -- SB draw
						WHEN s.ProductId = 1 AND b.StatusId IN (112, 113) AND b.modds IN (-0.25, 0.25) THEN ABS(b.stake)/2 -- SB half won/lose
						ELSE ABS(b.stake)
					END), -- TurnoverNoDraw
				SUM(CASE
						WHEN s.RefTable IN (1, 2) THEN 0
						WHEN tpositiontaking = 1 THEN 0
						ELSE scomm/(1-tpositiontaking)
					END), -- GrossComm 
				SUM(winlost - actual_stake), -- MemberWinLost	
				SUM(playercomm), -- PlayerComm		
				SUM(winlost - actual_stake) + SUM(playercomm), -- MemberTotal		
				SUM(awinlost), -- AgWinLost		
				ISNULL(SUM(comm - playercomm),0), -- AgComm			
				SUM(awinlost) + ISNULL(SUM(comm - playercomm),0), -- AgTotal			
				SUM(mwinlost), -- MAgWinLost		
				SUM(acomm)-SUM(comm), -- MAgComm			
				SUM(mwinlost) + SUM(acomm)-SUM(comm), -- MAgTotal		
				SUM(swinlost), -- SAgWinLost  
				SUM(scomm - acomm), -- SAgComm   
				SUM(swinlost + scomm - acomm), -- SAgTotal  
				-(SUM(swinlost)+ SUM(mwinlost) +SUM(awinlost) + SUM(winlost-actual_stake)  + SUM(scomm)) -- Company                    
		FROM	dbo.bettrans b WITH (NOLOCK)    
				INNER JOIN (
							SELECT	ISNULL(p.GroupProductId, f.ProductID) AS ProductID, f.BetType, f.RefTable
							FROM dbo.f_SportBettypeMatrixByProduct_Sel(@ProductIds, @IsTest) f
								LEFT JOIN dbo.f_GroupProduct() p ON f.ProductID = p.ProductId
								LEFT JOIN @ExistingProductDetails e ON e.ProductId = f.ProductID 
							WHERE EXISTS(SELECT 1
										 WHERE e.ProductId IS NULL 
											OR 
												(
													e.Bettype = f.BetType 
														  OR (
																e.Bettype = 0 AND f.BetType NOT IN (SELECT g.Bettype FROM f_GetProductDetail() g)
														     )
												)
										)
						) s ON b.bettype = s.Bettype
		WHERE	b.winlostdate BETWEEN @FDate AND @Tdate    
				AND b.srecommend = @CID   
				AND b.statusID IN (111, 112, 113)     
		GROUP BY s.ProductID;

		-- bettransRnG
		INSERT INTO #GrossComm (ProductID, TurnoverNoDraw, GrossComm)
		SELECT s.ProductID
			,SUM(CASE WHEN cont.ContributionBettype IS NULL THEN b.BetStake ELSE 0 END) AS TurnoverNoDraw
			,SUM(b.BetStake * b.sdiscount) AS GrossComm
		FROM dbo.bettransRnG b WITH(NOLOCK)
			INNER JOIN (
							SELECT	ISNULL(p.GroupProductId, f.ProductID) AS ProductID, f.BetType
							FROM dbo.f_SportBettypeMatrixByProduct_Sel(@ProductIds, @IsTest) f
								LEFT JOIN dbo.f_GroupProduct() p ON f.ProductID = p.ProductId
								LEFT JOIN @ExistingProductDetails e ON e.ProductId = f.ProductID 
							WHERE EXISTS(SELECT 1
										 WHERE e.ProductId IS NULL 
											OR 
												(
													e.Bettype = f.BetType 
														  OR (
																e.Bettype = 0 AND f.BetType NOT IN (SELECT g.Bettype FROM f_GetProductDetail() g)
														     )
												)
										)
								AND f.RefTable = 1
						) s ON b.gameID = s.Bettype
			OUTER APPLY 
			(
				SELECT f.Bettype AS ContributionBettype
				FROM dbo.f_BettypePrizeGroup() f
				WHERE f.BettypeGroup = 'Contribution'
					AND f.Bettype = b.gameID
			) cont
		WHERE winlostdate BETWEEN @FDate AND @TDate
			AND srecommend = @CID
			AND statusID IN (111, 112, 113) 
		GROUP BY s.ProductID

		-- bettransLC
		INSERT INTO #GrossComm (ProductID, TurnoverNoDraw, GrossComm)
		SELECT s.ProductID
			,SUM(CASE WHEN cont.ContributionBettype IS NULL THEN b.NetStake ELSE 0 END) AS TurnoverNoDraw
			,SUM(b.NetStake * b.sdiscount) AS GrossComm
		FROM dbo.bettransLC b WITH(NOLOCK)
			INNER JOIN (
							SELECT	ISNULL(p.GroupProductId, f.ProductID) AS ProductID, f.BetType
							FROM dbo.f_SportBettypeMatrixByProduct_Sel(@ProductIds, @IsTest) f
								LEFT JOIN dbo.f_GroupProduct() p ON f.ProductID = p.ProductId
								LEFT JOIN @ExistingProductDetails e ON e.ProductId = f.ProductID 
							WHERE EXISTS(SELECT 1
										 WHERE e.ProductId IS NULL 
											OR 
												(
													e.Bettype = f.BetType 
														  OR (
																e.Bettype = 0 AND f.BetType NOT IN (SELECT g.Bettype FROM f_GetProductDetail() g)
														     )
												)
										)
								AND f.RefTable = 2
						) s ON b.gameID = s.Bettype
			OUTER APPLY 
			(
				SELECT f.Bettype AS ContributionBettype
				FROM dbo.f_BettypePrizeGroup() f
				WHERE f.BettypeGroup = 'Contribution'
					AND f.Bettype = b.gameID
			) cont
		WHERE winlostdate BETWEEN @FDate AND @TDate
			AND srecommend = @CID
			AND statusID IN (111, 112, 113) 
		GROUP BY s.ProductID

		IF EXISTS (SELECT 1 FROM #GrossComm)
		BEGIN
			UPDATE t
			SET t.TurnoverNoDraw = ISNULL(t.TurnoverNoDraw, 0) + ISNULL(c.TurnoverNoDraw, 0)
				,t.GrossComm = ISNULL(t.GrossComm, 0) + ISNULL(c.GrossComm, 0)
			FROM #ComWinLossDetails t
				INNER JOIN (
					SELECT ProductID, SUM(GrossComm) AS GrossComm, SUM(TurnoverNoDraw) AS TurnoverNoDraw FROM #GrossComm GROUP BY ProductID
				) c ON t.ProductID = c.ProductID
		END
		
		IF @BalanceUpDay < @FromDate    
		BEGIN    
			SET @FDate = @FromDate;    
		END    
		ELSE    
		BEGIN    
			SET @FDate = @BalanceUpDay;    
		END    
      
		IF @ToDate > @MoveBetsDay    
		BEGIN    
			SET @TDate = @MoveBetsDay;    
		END    
		
		INSERT INTO #ComWinLossDetails( ProductID,Turnover,TurnoverNoDraw,GrossComm,MemberWinLost,PlayerComm,MemberTotal,AgWinLost,AgComm,AgTotal,MAgWinLost,MAgComm,MAgTotal,SAgWinLost, SAgComm, SAgTotal, Company)    
		SELECT	t.ProductID, -- ProductID 
				SUM(Turnover), -- Turnover  
				SUM(TunroverNoDraw), -- TunroverNoDraw
				SUM(GrossComm), -- GrossComm 
				SUM(winlost), -- MemberWinLost	
				SUM(playercomm), -- PlayerComm		
				SUM(winlost) + SUM(playercomm), -- MemberTotal		
				SUM(awinlost), -- AgWinLost		
				ISNULL(SUM(comm - playercomm),0), -- AgComm			
				SUM(awinlost) + ISNULL(SUM(comm - playercomm),0), -- AgTotal			
				SUM(mwinlost), -- MAgWinLost		
				SUM(acomm)-SUM(comm), -- MAgComm			
				SUM(mwinlost) + SUM(acomm)-SUM(comm), -- MAgTotal	
				SUM(swinlost), -- SAgWinLost  
				SUM(scomm - acomm), -- SAgComm   
				SUM(swinlost + scomm - acomm), -- SAgTotal  
				-(SUM(swinlost)+ SUM(mwinlost) +SUM(awinlost) + SUM(winlost)  + SUM(scomm)) -- Company                    
		FROM	dbo.SUM_winloss b WITH(NOLOCK)    
				INNER JOIN #TmpCondSumWL t ON b.sporttype = t.sporttype 
											AND b.bettype = t.bettype    
		WHERE	b.winlostdate BETWEEN @FDate AND @TDate    
				AND b.custid  = @CID   
				AND RoleID = 4    
		GROUP BY  ProductID;
	END    
   
	SELECT	@FDate = @FromDate,    
			@TDate = @ToDate;    
     
	IF @FromDate < @BalanceUpDay    
	BEGIN    
		IF @ToDate >= DATEADD(dd, -1, @BalanceUpDay)    
		BEGIN    
			SELECT @TDate = DATEADD(dd, -1, @BalanceUpDay);    
		END    
    
		DECLARE @winlostdateTable TABLE (winlostdate smalldatetime)    
		-- using cte to remove predicate when seek on sum_winloss_old    
		;WITH CTE_Winlostdate (winlostdate ) AS    
		(    
			SELECT @FDate AS winlostdate    
			UNION ALL    
			SELECT DATEADD(DAY, 1, winlostdate)    
			FROM CTE_Winlostdate    
			WHERE winlostdate < @TDate    
		)    
			INSERT INTO @winlostdateTable(winlostdate)    
			SELECT winlostdate FROM CTE_Winlostdate    
			OPTION (MAXRECURSION 0);    
		
		INSERT INTO #ComWinLossDetails( ProductID,Turnover,TurnoverNoDraw,GrossComm,MemberWinLost,PlayerComm,MemberTotal,AgWinLost,AgComm,AgTotal,MAgWinLost,MAgComm,MAgTotal,SAgWinLost, SAgComm, SAgTotal, Company)    
		SELECT	w.ProductID,
				SUM(Turnover), -- Turnover  
				SUM(TunroverNoDraw), -- TunroverNoDraw
				SUM(GrossComm), -- GrossComm 
				SUM(winlost), -- MemberWinLost	
				SUM(playercomm), -- PlayerComm		
				SUM(winlost) + SUM(playercomm), -- MemberTotal		
				SUM(awinlost), -- AgWinLost		
				ISNULL(SUM(comm - playercomm),0), -- AgComm			
				SUM(awinlost) + ISNULL(SUM(comm - playercomm),0), -- AgTotal			
				SUM(mwinlost), -- MAgWinLost		
				SUM(acomm)-SUM(comm), -- MAgComm			
				SUM(mwinlost) + SUM(acomm)-SUM(comm), -- MAgTotal	
				SUM(swinlost), -- SAgWinLost  
				SUM(scomm - acomm), -- SAgComm   
				SUM(swinlost + scomm - acomm), -- SAgTotal  
				-(SUM(swinlost)+ SUM(mwinlost) +SUM(awinlost) + SUM(winlost)  + SUM(scomm)) -- Company   
		FROM bodb_Summary.dbo.Sum_WinLoss_Old b WITH(NOLOCK)    
			CROSS APPLY (	SELECT  t.winlostdate, u.SportType, u.BetType, u.ProductID    
							FROM #TmpCondSumWL u    
							CROSS JOIN @winlostdateTable t    
						) w    
		WHERE	b.winlostdate = w.winlostdate    
				AND b.custid  = @CID     
				AND b.RoleID = 4    
				AND b.sporttype = w.sporttype    
				AND b.bettype = w.bettype    
		GROUP BY  w.ProductID;  
	END    
	
	SELECT	w.ProductID,    
			SUM(Turnover) Turnover,    
			SUM(TurnoverNoDraw) TurnoverNoDraw,    
			SUM(GrossComm) GrossComm,   
			SUM(MemberWinLost) MemberWinLost,
			SUM(PlayerComm) PlayerComm,
			SUM(MemberTotal) MemberTotal,
			SUM(AgWinLost) AgWinLost,
			SUM(AgComm) AgComm,
			SUM(AgTotal) AgTotal,
			SUM(MAgWinLost) MAgWinLost,
			SUM(MAgComm) MAgComm,
			SUM(MAgTotal) MAgTotal,     
			SUM(SAgWinLost) SAgWinLost,     
			SUM(SAgComm) SAgComm ,     
			SUM(SAgTotal) SAgTotal,     
			SUM(Company) Company   
	FROM #ComWinLossDetails w    
	GROUP BY w.ProductID  
	ORDER BY Turnover DESC;  
    
	DROP TABLE #TmpCondSumWL    
	DROP TABLE #ComWinLossDetails
	DROP TABLE #GrossComm
END
