USE bodb02
GO
ALTER PROCEDURE dbo.Age_CustomerSelWinLimitProduct @CustId INT
AS
/*  
	Created: 20150714@Patrick
	Task : Get product list
	DB: DBAGE/bodb02
	Revisions: 

	Param's Explanation: 
*/  
BEGIN
	DECLARE @Products TABLE(BetType SMALLINT, SportType SMALLINT, ProductName VARCHAR(50))
	--live cs
	IF EXISTS (SELECT 1	FROM dbo.custInfo WITH(NOLOCK)	WHERE CustId = @CustId AND SyncLiveCasino = 1)
	BEGIN
		INSERT INTO @Products(BetType, SportType, ProductName)
		VALUES(1101, 162, 'Live Casino')
	END
	--gold deluxe
	IF EXISTS (SELECT 1	FROM dbo.custInfo WITH(NOLOCK)	WHERE CustId = @CustId AND HideGoldDeluxe = 0)
	BEGIN
		INSERT INTO @Products(BetType, SportType, ProductName)
		VALUES(1701, 255, 'Gold Deluxe')
	END

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
