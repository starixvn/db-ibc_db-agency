ALTER PROCEDURE [dbo].[Age_Rpt_ConsolidatedGroupProductSel_xpre]
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
	
	Param's Explanation:

*/

BEGIN 
	SET NOCOUNT ON 
	
	DECLARE @TmpCustID TABLE(CustID INT)
	DECLARE @ProductList TABLE (ProductID TINYINT, ProductName VARCHAR(50), isShow BIT DEFAULT (0))

	INSERT INTO @TmpCustID
	SELECT	B.CustID
	FROM	dbo.custAccount A WITH (NOLOCK) 
	INNER JOIN dbo.custAccount B WITH (NOLOCK)ON A.GroupID = B.GroupID
	WHERE	A.CustID = @CustID AND A.IsGroupHeadLine = 1 and A.IsRptConsol = 1

	INSERT INTO @ProductList (ProductID, ProductName)
	SELECT	ProductID, ProductName
	FROM	dbo.Products WITH (NOLOCK)
	WHERE	ProductID IN (1,6,2,3,7,4,5,8,12,15,19,21) 

	UPDATE	@ProductList
	SET		isShow = 1
	WHERE	ProductID IN (1,6,2,3,4) ---SB, Casino, Racing, Number Game, Live Casino: always show

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

	-----4. Colossus Bets
	IF EXISTS (	SELECT	1
				FROM	dbo.CustInfo C WITH (NOLOCK)
				INNER JOIN @TmpCustID T 
						ON T.CustID = C.CustID
				WHERE	C.HideColossusBet = 0)
	BEGIN 
		UPDATE @ProductList
		SET		isShow = 1
		WHERE	ProductID = 15
	END 

	-----------------------------------------------------------
	----------------------------DCS---------------------------
	
	 SELECT t.ProductID,
		MIN(CONVERT(TINYINT,dbo.f_GetProductStatus(cps.bitmapIsHidden, t.bitmapOrder))) AS IsHide,
		MAX(CONVERT(TINYINT,dbo.f_GetProductStatus(cps.bitmapHasSynced, t.bitmapOrder))) AS IsSync
	 INTO #T
	 FROM dbo.CustProductStatus cps  WITH (NOLOCK)  
	 CROSS APPLY (	SELECT psp.bitmapOrder , psd.ProductID
					FROM dbo.ProductSettingDetail psd WITH(NOLOCK)  
					INNER JOIN dbo.ProductStatusProfile psp WITH (NOLOCK) 
							ON psp.Sporttype = psd.SportType AND psp.Bettype = psd.BetType
					WHERE psd.SettingType = 4) t
	 INNER JOIN @TmpCustID C 
			ON C.CustID = cps.CustID
	 GROUP BY t.ProductID 

	 
	UPDATE	P
	SET		isShow = 1
	FROM	@ProductList P
	INNER JOIN #T T
		ON T.ProductID = P.ProductID
	WHERE T.IsHide = 0
		AND T.ProductID <> 21 -- AllBet

	-- AllBet
	UPDATE	P
	SET		isShow = 1
	FROM	@ProductList P
	INNER JOIN #T T
		ON T.ProductID = P.ProductID
	WHERE T.IsHide = 0 AND T.IsSync = 1
		AND T.ProductID = 21 -- AllBet

	--------------------------------------------
	SELECT * 
	FROM @ProductList
	DROP TABLE #T

END
GO

GRANT EXECUTE ON [dbo].[Age_Rpt_ConsolidatedGroupProductSel] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_Rpt_ConsolidatedGroupProductSel] TO [bodbDownlineNetView]
GO
GRANT VIEW DEFINITION ON [dbo].[Age_Rpt_ConsolidatedGroupProductSel] TO [vnteam]
