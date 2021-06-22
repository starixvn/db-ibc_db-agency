/*<info serverAlias="DBAGE-bodb02" executers="bodbDownlineNet,bodbDownlineNetView" isFunction="0" isNested="0"></info>*/  
CREATE PROCEDURE [dbo].[Age_Rpt_WinLossDetailByPT_Super]      
 @CustId         INT = NULL,    
 @FromDate  SMALLDATETIME,    
 @ToDate   SMALLDATETIME,    
 @ProductIds  VARCHAR(MAX) = '',    
 @ProductDetails NVARCHAR(MAX) = 'All',    
 @BalanceUpDay SMALLDATETIME,    
 @MoveBetsDay SMALLDATETIME  
AS    
/*    
Created by: Evan    
Date: 2021-06-23    
Task : Implement New Report Super Win Loss Detail by PT     
DB: DBAGE/bodb02    
Revisions:    
	- 20210623@Evan: Initialize SPs [RedmineID : #157338]  

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
						WHEN b.StatusID IN (112,113) AND b.MOdds IN (-0.25, 0.25) AND s.ProductId = 1 THEN ABS(b.stake)/2
						WHEN b.StatusID = 111 AND s.ProductId IN (1) THEN 0 -- Sportsbook
						WHEN s.ProductID IN (21, 39, 45, 46, 47, 51, 52, 57, 59, 65)  THEN b.oddsspread -- Allbet, SA Gaming, SexyGaming, IBCBet Live Casino, BBIN, WM, ION, GDG, BG, PPL
						ELSE ABS(b.stake) 
					END) AS TurnoverNoDraw,
				SUM(CASE WHEN tpositiontaking = 1 THEN 0 ELSE scomm/(1-tpositiontaking) END), -- GrossComm 
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
				-(SUM(swinlost)+ SUM(mwinlost) +SUM(awinlost) + SUM(winlost)  + SUM(scomm)) -- Company                    
		FROM	dbo.bettrans b WITH (NOLOCK)    
				INNER JOIN ( SELECT ISNULL(p.GroupProductId, f.ProductID) AS ProductID,
									f.BetType
							FROM dbo.f_SportBettypeMatrixByProduct_Sel(@ProductIds, @IsTest) f    
							LEFT JOIN dbo.f_GroupProduct() p ON f.ProductID = p.ProductId    
							LEFT JOIN @ExistingProductDetails e ON e.ProductId = f.ProductID     
							WHERE EXISTS (	SELECT 1    
											WHERE	e.ProductId IS NULL     
													OR  (	e.Bettype = f.BetType     
															OR ( e.Bettype = 0 AND f.BetType NOT IN (SELECT g.Bettype FROM f_GetProductDetail() g))    
														)
										 )                
							) s ON b.bettype = s.Bettype    
		WHERE	b.winlostdate BETWEEN @FDate AND @Tdate    
				AND b.srecommend = @CID   
				AND b.statusID IN (111, 112, 113)     
		GROUP BY s.ProductID ;
		
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
END
