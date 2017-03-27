/*<info serverAlias="DBACC-bodb02" executers="bodbDownlineNet,bodbDownlineNetView" viewers="vnteam" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Age_Rpt_PlayForFun_ProductSel]
	@CustId INT
AS

/*
	Creator: Percy
	Date: 2017-03-10
	DB: DBACC.bodb02
	Task: Play For Fun - Statistics Report - Select Product List [RedmineID: #72877]

	Revisions:

	Param's Explanation:
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @ProductList TABLE (ProductID TINYINT, ProductName VARCHAR(50), IsDisable BIT DEFAULT (0))
	INSERT INTO @ProductList (ProductID, ProductName)
	SELECT	ProductID, ProductName
	FROM	dbo.Products WITH (NOLOCK)
	WHERE	IsOfferPlayForFun = 1

	UPDATE	@ProductList
	SET		ProductName = 'Casino',
			IsDisable = (SELECT DisableCasino FROM dbo.custInfo WITH(NOLOCK) WHERE custid = @CustId)
	WHERE	ProductID IN (6) -- RNG Casino

	SELECT ProductId, ProductName, IsDisable
	FROM @ProductList
END
GO