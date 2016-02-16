ALTER PROCEDURE dbo.Age_CustomerSelWinLimitProduct @CustId INT
AS
/*  
	Created: 20150714@Patrick
	Task : Get product list
	DB: DBAGE/bodb02
	Revisions: 
		- 20151223@Patrick:	Add Max/Loss limit for RnG Casino [Redmine: #49528]
		- 20160216@Billy:	Integrate to support DCS Products - [Redmine: #52268]

	Param's Explanation: 
*/  
BEGIN
	DECLARE @Products TABLE(BetType SMALLINT, SportType SMALLINT, ProductName VARCHAR(50))
	--live cs
	IF EXISTS (SELECT 1	FROM dbo.custInfo WITH(NOLOCK)	WHERE CustId = @CustId AND SyncLiveCasino = 1)
	BEGIN
		INSERT INTO @Products(BetType, SportType, ProductName)
		SELECT 1101, 162, ProductName
		FROM dbo.Products WITH(NOLOCK) WHERE ProductID = 4
		--VALUES(1101, 162, 'Live Casino')
	END
	--gold deluxe
	IF EXISTS (SELECT 1	FROM dbo.custInfo WITH(NOLOCK)	WHERE CustId = @CustId AND HideGoldDeluxe = 0)
	BEGIN
		INSERT INTO @Products(BetType, SportType, ProductName)
		SELECT 1701, 255, ProductName
		FROM dbo.Products WITH(NOLOCK) WHERE ProductID = 12
		--VALUES(1701, 255, 'Gold Deluxe')
	END

	--RnG Casino
	IF EXISTS (SELECT 1	FROM dbo.custInfo WITH(NOLOCK)	WHERE CustId = @CustId AND SyncCasino = 1)
	BEGIN
		INSERT INTO @Products(BetType, SportType, ProductName)
		SELECT 2101, 208, ProductName
		FROM dbo.Products WITH(NOLOCK) WHERE ProductID = 6
	END

	-- For DCS Product
	INSERT INTO	@Products
				(	BetType    , SportType    , ProductName)
	SELECT DISTINCT psd.BetType, psd.SportType, p.ProductName
	FROM		dbo.CustProductStatus		AS cps	WITH (NOLOCK)
	CROSS JOIN	dbo.ProductStatusProfile	AS psp	WITH (NOLOCK)
	INNER JOIN	dbo.ProductSettingDetail	AS psd	WITH (NOLOCK)
			ON	psd.SportType = psp.Sporttype
			AND	psd.BetType = psp.Bettype
			AND	psd.SettingType = 6
	INNER JOIN	dbo.Products				AS p	WITH (NOLOCK)
			ON	p.ProductID = psd.ProductID
	CROSS APPLY	(
		SELECT	dbo.f_GetProductStatus(cps.bitmapHasSynced, psp.bitmapOrder)
			,	dbo.f_GetProductStatus(cps.bitmapIsHidden, psp.bitmapOrder)
	) ps(isSynced, isHidden)
	WHERE	cps.CustID = 1176070
		AND	ps.isSynced = 1
		AND	ps.isHidden = 0

	SELECT BetType, SportType, ProductName
	FROM @Products
END

GO

GRANT EXECUTE ON [dbo].[Age_CustomerSelWinLimitProduct] TO [bodbDownlineNet] AS [dbo]
GO

GRANT EXECUTE ON [dbo].[Age_CustomerSelWinLimitProduct] TO [bodbDownlineNetView] AS [dbo]
GO

GRANT VIEW DEFINITION ON [dbo].[Age_CustomerSelWinLimitProduct] TO [vnteam] AS [dbo]
GO
