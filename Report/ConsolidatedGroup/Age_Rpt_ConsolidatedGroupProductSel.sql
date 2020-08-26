/*<info serverAlias="DBAGE-bodb02" executers="bodbDownlineNet,bodbDownlineNetView" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Age_Rpt_ConsolidatedGroupProductSel]
	@CustId INT
AS
/*
	Created: Sophia
	Date: 20160113
	Task : Product List supported for Consolidated Report [Redmine: #50337]
	DB: DBAGE/bodb02
	Original:  

	Revisions:
		- 20160318@Percy: Support AllBet [Redmine: #50605]
		- 20160413@Percy: Support Voidbridge single wallet [Redmine: #55259]
		- 20160809@Johnson: Integrate NG2 [Redmine: #61397]	
		- 20161028@Percy: Support Fishing World [RedmineID: #65731]
		- 20170309@Sophia: Fishing World change Setting type from 4 to 13 [Redmine: #70722]
		- 20170622@Percy: Combine Betradar Virtual Sports with Virtual Sports - using DCS [RedmineID: #78339]
		- 20170705@Percy: Support Keno Lottery [RedmineID: #78064]
		- 20170829@Paul: Return EndOfSupportDate; Change Hard-coded ProductID values to GroupType [RedmineID: #77598]
		- 20190826@Percy: Remove inactive products [RedmineID: #118699]
		- 20200328@Sophia: Add hardcode for Sexy Gamng and SA Gaming [#130809]
		- 20200408@Sophia: Add Table Games [RedmineId: #129438]
		- 20200410@Sophia: Add BBIN [RedmineId: #131358]	
		- 20200428@Malcolm : re-order products [Redmine : #132760]
		- 20200422@Sophia: Add IBC Live Casino - apply new code for CustProductStatus [RedmineId: #130693]
		- 20200810@Sophia: Exclude these Products: Pragmatic, Card Club, Spadegaming of of Macau Games [Redmine: #137767]
		
	Param's Explanation:

*/

BEGIN 
	SET NOCOUNT ON 
	
	DECLARE @TmpCustID TABLE(OrderID INT IDENTITY (1,1), CustID INT)
	DECLARE @ProductList TABLE (ProductID TINYINT, ProductName VARCHAR(50), EndOfSupportDate date, isShow BIT DEFAULT (0))

	INSERT INTO @TmpCustID
	SELECT	B.CustID
	FROM	dbo.custAccount A WITH (NOLOCK) 
	INNER JOIN dbo.custAccount B WITH (NOLOCK)ON A.GroupID = B.GroupID
	WHERE	A.CustID = @CustID AND A.IsGroupHeadLine = 1 and A.IsRptConsol = 1

	INSERT INTO @ProductList (ProductID, ProductName, EndOfSupportDate)
	SELECT	ProductID, ProductName, EndOfSupportDate
	FROM	dbo.Products WITH (NOLOCK)
	WHERE GroupType = 0		

	UPDATE	@ProductList
	SET		isShow = 1
	WHERE	ProductID IN (1,6,3) ---SB, Casino, Number Game: always show

	/*
	-----1. Virtual Sports
	IF EXISTS (	SELECT	1
				FROM	dbo.CustInfo C WITH (NOLOCK)
				INNER JOIN @TmpCustID T 
						ON T.CustID = C.CustID
				WHERE	C.HideVirtualSports = 0)
	BEGIN 
		UPDATE @ProductList
		SET		isShow = 1
		WHERE	ProductID = 5
	END 
	*/

	-----2. Keno
	IF EXISTS (	SELECT	1
				FROM	dbo.CustInfo C WITH (NOLOCK)
				INNER JOIN @TmpCustID T 
						ON T.CustID = C.CustID
				WHERE	C.HideKeno = 0)
	BEGIN 
		UPDATE @ProductList
		SET		isShow = 1
		WHERE	ProductID = 8
	END 

	-----3. Gold Deluxe
	IF EXISTS (	SELECT	1
				FROM	dbo.CustInfo C WITH (NOLOCK)
				INNER JOIN @TmpCustID T 
						ON T.CustID = C.CustID
				WHERE	C.HideGoldDeluxe = 0)
	BEGIN 
		UPDATE @ProductList
		SET		isShow = 1
		WHERE	ProductID = 12
	END 

	-----------------------------------------------------------
	----------------------------DCS---------------------------
	SELECT t.ProductID,
	MIN(CONVERT(TINYINT,dbo.f_GetProductStatus(cps.bitmapIsHidden , t.bitmapOrder))) AS IsHide,
	MAX(CONVERT(TINYINT,dbo.f_GetProductStatus(cps.bitmapHasSynced, t.bitmapOrder))) AS IsSync
	INTO #T
	FROM
		dbo.CustProductStatus cps  WITH (NOLOCK)  
		CROSS APPLY
		(
			SELECT p.bitmapOrder , 
					RealProductID AS ProductID 
			FROM
				(SELECT RealProductID, sporttype, bettype FROM dbo.f_CustSetting_SportBetTypeSettingSelect (NULL, 4) 
				UNION SELECT RealProductID, sporttype, bettype FROM dbo.f_CustSetting_SportBetTypeSettingSelect (NULL, 11) --NG2
				UNION SELECT RealProductID, sporttype, bettype FROM dbo.f_CustSetting_SportBetTypeSettingSelect (NULL, 13) --FW, BetradarVS, Keno Lottery
				)c
				INNER JOIN dbo.ProductStatusProfile p WITH (NOLOCK)
					ON c.Sporttype = p.SportType AND p.Bettype = c.BetType
		) t
		INNER JOIN @TmpCustID c ON c.CustID = cps.CustID
	GROUP BY t.ProductID

	-- Check IsHidden only --
	UPDATE	P
	SET		isShow = 1
	FROM	@ProductList P
	INNER JOIN #T T
		ON T.ProductID = P.ProductID
	WHERE T.IsHide = 0
		AND T.ProductID NOT IN (21, 22, 24)

	-- Check IsHidden and IsSync --
	UPDATE	P
	SET		isShow = 1
	FROM	@ProductList P
	INNER JOIN #T T
		ON T.ProductID = P.ProductID
	WHERE T.IsHide = 0 AND T.IsSync = 1
		AND T.ProductID IN (21, 22, 24)
		
	
	----Check Show product by Site
	DECLARE @Site VARCHAR(10), @Currency INT, @CID INT, @ID INT= 1
	DECLARE @CheckPGSoftEnable AS TABLE (ProductID INT, SportType INT, BetType INT)
	 
	
	WHILE EXISTS (SELECT 1 FROM	@TmpCustID WHERE OrderID = @ID)
	BEGIN 
		SELECT	@CID = CustID 
		FROM	@TmpCustID 
		WHERE	OrderID = @ID

		SELECT @Site = CASE WHEN m.roleID = 1 THEN up.site ELSE m.site END, @Currency = CASE WHEN m.roleID = 1 THEN up.Currency ELSE m.Currency END  
		FROM bodb02.dbo.Customer c WITH (NOLOCK) 
			LEFT JOIN bodb02.dbo.Customer m WITH (NOLOCK) 
				ON c.CustID = m.CustID  
			LEFT JOIN bodb02.dbo.Customer up WITH (NOLOCK) 
				ON up.CustID = m.recommend and up.roleID = 2  
		WHERE c.CustID = @CID	
		 
		INSERT INTO @CheckPGSoftEnable (ProductID, SportType, BetType)
		EXEC dbo.Acc_CustSetting_CheckPGSoftEnable @Site = @Site, @Currency = @Currency, @CustID = @CID

		SET @ID = @ID + 1
		
	END	 

	UPDATE	P
	SET		isShow = 1
	FROM	@ProductList P
	WHERE 	EXISTS (SELECT 1 FROM @CheckPGSoftEnable T WHERE T.ProductID = P.ProductID)
	
	--------------------------------------------
	SELECT p.ProductID, 
	       p.ProductName, 
		   p.EndOfSupportDate, 
		   p.isShow,
		   ISNULL(d.OrderNo,0) AS OrderNo,
		   CASE WHEN d.CasinoType = 1 THEN 53
		        WHEN d.CasinoType = 2 THEN 41
				ELSE 0 END AS [Type]
	FROM @ProductList p
		INNER JOIN Products d WITH(NOLOCK) ON p.ProductID = d.ProductID
	ORDER BY d.OrderNo
	
	DROP TABLE #T
END

 