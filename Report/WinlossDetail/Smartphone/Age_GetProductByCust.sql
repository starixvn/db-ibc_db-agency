CREATE PROCEDURE [dbo].[Age_GetProductByCust]
	@CustId INT
AS
/*  
 Created: 20161025@Paul  
 Task : Get all products of user
 DB: DBAGE/bodb02  
 Original:  
  
 Revisions:  
  - 20161025@Paul: Smartphone Friendly UI for Microsite Report - [Redmine: #61531]
    
 Param's Explanation:  
 - @CustId: Customer want to get all products
   
 */  
BEGIN
	SET NOCOUNT ON;

	CREATE TABLE #TmpProducts(
		ProductId TINYINT
	);

	CREATE TABLE #StatusSettings(
		ProductId	TINYINT,
		IsSync		BIT,
		IsHide		BIT
	);

	INSERT INTO #TmpProducts(ProductID) VALUES (1), (2), (3), (4), (6); ---SB, Casino, Racing, Number Game, Live Casino: always show

	--Add VirtualSports, Keno, GoldDeluxe, ColossusBet
	INSERT INTO #TmpProducts(ProductID)
	SELECT unp.ProductID
	FROM (
		SELECT	CASE WHEN COALESCE(ci.HideVirtualSports, 1) = 1 THEN 0 ELSE 5 END AS VirtualSports,
				CASE WHEN COALESCE(ci.HideKeno, 1) = 1 THEN 0 ELSE 8 END AS Keno,
				CASE WHEN COALESCE(ci.HideGoldDeluxe, 1) = 1 THEN 0 ELSE 12 END AS GoldDeluxe,
				CASE WHEN COALESCE(ci.HideColossusBet, 1) = 1 THEN 0 ELSE 15 END AS ColossusBet
		FROM dbo.custinfo ci WITH(NOLOCK)
		WHERE ci.custid = @CustID
	) p
	UNPIVOT (ProductID FOR ProductName IN (VirtualSports, Keno, GoldDeluxe, ColossusBet)) AS unp
	WHERE unp.ProductID <> 0;

	--Get customer products in Group 0
	INSERT INTO #StatusSettings(ProductId, IsHide, IsSync)
	SELECT	t.ProductID,
			MIN(CONVERT(TINYINT,dbo.f_GetProductStatus(cps.bitmapIsHidden , t.bitmapOrder))) AS IsHide,
			MAX(CONVERT(TINYINT,dbo.f_GetProductStatus(cps.bitmapHasSynced, t.bitmapOrder))) AS IsSync
	FROM
		dbo.CustProductStatus cps  WITH (NOLOCK)  
		CROSS APPLY
		(
			SELECT p.bitmapOrder , c.ProductID
			FROM
				dbo.f_CustSetting_SportBetTypeSettingSelect (NULL, 4) c
				INNER JOIN dbo.ProductStatusProfile p WITH (NOLOCK)
					ON c.Sporttype = p.SportType AND p.Bettype = c.BetType
		) t
	WHERE cps.CustID = @CustId
	GROUP BY t.ProductID;

	--Only Get Allbet, Macau Games if IsSync = 1 AND IsHide = 0
	DELETE #StatusSettings
	WHERE ProductId IN (21, 22)
		AND (IsSync = 0 OR IsHide = 1);

	--Remove hidden products
	DELETE #StatusSettings
	WHERE IsHide = 1;

	SELECT	p.ProductId,
			p.ProductName
	FROM (
			SELECT ProductId
			FROM #TmpProducts

			UNION ALL	

			SELECT ProductId
			FROM #StatusSettings
		) tmp_p
		INNER JOIN dbo.Products p WITH(NOLOCK) ON tmp_p.ProductID = p.ProductID
	WHERE p.GroupType = 0
	ORDER BY p.ProductId;

	DROP TABLE #TmpProducts;
	DROP TABLE #StatusSettings;

	SET NOCOUNT OFF;
END

GO

GRANT EXECUTE ON [dbo].[Age_GetProductByCust] TO [bodbDownlineNet]
GO

GRANT EXECUTE ON [dbo].[Age_GetProductByCust] TO [bodbDownlineNetView]
GO

GRANT VIEW DEFINITION ON [dbo].[Age_GetProductByCust] TO [vnteam] AS [dbo]
GO