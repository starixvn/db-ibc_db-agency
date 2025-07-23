/*<info serverAlias="DBAGE-bodb02" executers="wsv_alp,wsv_alpv" isFunction="0" isNested="0"></info>*/
CREATE PROCEDURE [dbo].[Age_Rpt_ConsolidatedGroupProductSel_Extra]
	@CustId INT
	,@CashServiceSites VARCHAR(MAX)
	,@SettingStatus TINYINT = 0
AS
/*
    Created: 20250708@Virgil
    DB: DBAGE-bodb02
    Task: Cash Service Billing - Update ProductList filter of Consolidation Report [RedmineId: #232418]

	Revisions:
		- 20250708@Virgil: Initial SP [Redmine: #232418]

	Param's Explanation:

*/
BEGIN 
	SET NOCOUNT ON 
	
	DECLARE @TmpSiteCurrency TABLE(OrderID INT IDENTITY (1,1), Site VARCHAR(10))
	DECLARE @CheckEnableProduct TABLE (ProductID TINYINT, ProductName VARCHAR(50), EndOfSupportDate date, isShow BIT,[Type] tinyint,OrderNo int)

	INSERT INTO @CheckEnableProduct (ProductID, ProductName, isShow, EndOfSupportDate, OrderNo, [Type])
	SELECT p.ProductID,
			p.ProductName, 
			0 AS isShow, 
			p.EndOfSupportDate,
			p.OrderNo,
			0
	FROM Products p
	WHERE ProductID = 111

	--Get: site/currency of all lines belong to a group headline
	INSERT INTO @TmpSiteCurrency (Site)
	SELECT DISTINCT C.site
	FROM dbo.custAccount A WITH (NOLOCK) 
	INNER JOIN dbo.custAccount B WITH (NOLOCK)ON A.GroupID = B.GroupID
	INNER JOIN dbo.Customer C WITH (NOLOCK) ON C.custid=B.custid
	WHERE A.CustID = @CustID AND A.IsGroupHeadLine = 1 and A.IsRptConsol = 1
	
	--Check Show product by Site/Currency
	DECLARE @Site VARCHAR(10), @IsUpdated BIT = 0, @ID INT= 1;
	 
	WHILE EXISTS (SELECT 1 FROM	@TmpSiteCurrency WHERE OrderID = @ID) AND @IsUpdated = 0
	BEGIN 
		SELECT	@site = c.site 
		FROM	@TmpSiteCurrency  c
		WHERE	OrderID = @ID

		IF ',' + @CashServiceSites + ',' LIKE '%,' + @Site + ',%' OR @CashServiceSites = '*'
		BEGIN
			UPDATE @CheckEnableProduct
			SET isShow = 1
			WHERE ProductID = 111;

			SET @IsUpdated = 1
			BREAK;
		END

		SET @ID = @ID + 1
	END	 
	
	--------------------------------------------
	SELECT p.ProductID, 
	       p.ProductName, 
		   p.EndOfSupportDate, 
		   P.isShow,
		   p.OrderNo,
		   p.[Type]
	FROM @CheckEnableProduct p
END
GO 