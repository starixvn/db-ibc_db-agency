CREATE PROCEDURE [dbo].[Acc_GetProductByCust]
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
		ProductId TINYINT,
		IsDisabled	BIT,
		IsHidden	BIT,
		IsSynced	BIT
	);

	CREATE TABLE #TmpCustInfo(
		CustID					INT,
		DisableVirtualSports	BIT,
		HideVirtualSports		BIT,
		HideKeno				BIT,
		DisableGoldDeluxe		BIT,
		HideGoldDeluxe			BIT,
		DisableColossusBet		BIT,
		HideColossusBet			BIT
	);

	INSERT INTO #TmpProducts(ProductID, IsDisabled, IsHidden, IsSynced) 
	VALUES (1, 0, 0, 1), (2, 0, 0, 1), (3, 0, 0, 1), (4, 0, 0, 1), (6, 0, 0, 1); ---SB, Casino, Racing, Number Game, Live Casino: always show

	INSERT INTO #TmpCustInfo(CustID, DisableVirtualSports, HideVirtualSports, HideKeno, DisableGoldDeluxe, HideGoldDeluxe, DisableColossusBet, HideColossusBet)
	SELECT CustID, DisableVirtualSports, HideVirtualSports, HideKeno, DisableGoldDeluxe, HideGoldDeluxe, DisableColossusBet, HideColossusBet
	FROM dbo.custinfo ci WITH(NOLOCK)
	WHERE ci.custid = @CustID;

	--Add VirtualSports, Keno, GoldDeluxe, ColossusBet
	INSERT INTO #TmpProducts(ProductID, IsDisabled, IsHidden, IsSynced)
	SELECT	5 AS ProductID, --VirtualSports
			ISNULL(DisableVirtualSports, 1) AS IsDisabled,
			ISNULL(HideVirtualSports, 1) AS IsHidden,
			1 AS IsSynced
	FROM #TmpCustInfo
	UNION ALL
	SELECT	8 AS ProductID, --Keno
			0 AS IsDisabled,
			ISNULL(HideKeno, 1),
			1 AS IsSynced
	FROM #TmpCustInfo
	UNION ALL
	SELECT	12 AS ProductID, --GoldDeluxe
			ISNULL(DisableGoldDeluxe, 1) AS IsDisabled,
			ISNULL(HideGoldDeluxe, 1) AS IsHidden,
			1 AS IsSynced
	FROM #TmpCustInfo
	UNION ALL
	SELECT	15 AS ProductID, --ColossusBet
			ISNULL(DisableColossusBet, 1) AS IsDisabled,
			ISNULL(HideColossusBet, 1) AS IsHidden,
			1 AS IsSynced
	FROM #TmpCustInfo;

	--Get customer products based on DCS
	INSERT INTO #TmpProducts(ProductID, IsDisabled, IsHidden, IsSynced)
	SELECT	t.ProductID,
			MIN(CONVERT(TINYINT,dbo.f_GetProductStatus(cps.bitmapIsDisabled, t.bitmapOrder))) AS IsDisabled,
			MIN(CONVERT(TINYINT,dbo.f_GetProductStatus(cps.bitmapIsHidden, t.bitmapOrder))) AS IsHidden,
			MAX(CONVERT(TINYINT,dbo.f_GetProductStatus(cps.bitmapHasSynced, t.bitmapOrder))) AS IsSynced
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

	SELECT	p.ProductId,
			p.ProductName,
			tmp_p.IsDisabled,
			tmp_p.IsHidden,
			tmp_p.IsSynced
	FROM #TmpProducts tmp_p
		INNER JOIN dbo.Products p WITH(NOLOCK) ON tmp_p.ProductID = p.ProductID
	ORDER BY p.ProductId;

	DROP TABLE #TmpProducts;
	DROP TABLE #TmpCustInfo;

	SET NOCOUNT OFF;
END

GO

GRANT EXECUTE ON [dbo].[Acc_GetProductByCust] TO [bodbDownlineNet]
GO

GRANT EXECUTE ON [dbo].[Acc_GetProductByCust] TO [bodbDownlineNetView]
GO

GRANT VIEW DEFINITION ON [dbo].[Acc_GetProductByCust] TO [vnteam] AS [dbo]
GO