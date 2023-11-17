/*<info serverAlias="DBAGE-bodb02" executers="bodbDownlineNet,bodbDownlineNetView" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Age_Rpt_ConsolidatedGroupProductSel]
	@CustId INT
	,@SettingStatus TINYINT = 0
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
		- 20200918@Malcolm: Add Joker [redmine: #131609]
		- 20201009@Malcolm: Add @SettingStatus param for this Sp [redmine: #143077]
		- 20220216@Evan: Remove unused columns - [Redmine: #164280]
		- 20220803@Eden:  Implement the dependency between Macau Games Product Status and Jackpot Status [Redmine: #171715]
		- 20221121@Eden: Unify RNG Lottery Customer Settings [RedmineID: #180640]
		- 20230323@Eden: Migrate NG and Keno to DCS structure [Redmine: #179711]
		- 20230731@Eden: Simplify Live Casino Customer Setting - [Redmine: #189389]
		- 20230928@Luke: Modify SPs to adapt in-house replication setup [Redmine: #194414]
		- 20231117@Tacy: ExtNAP/Alpha - Return Offered product lists by site/currency [Redmine: #196141]

	Param's Explanation:

*/

BEGIN 
	SET NOCOUNT ON 
	
	DECLARE @TmpSiteCurrency TABLE(OrderID INT IDENTITY (1,1),Currency TINYINT, Site VARCHAR(10))
	DECLARE @CheckEnableProduct TABLE (ProductID TINYINT, ProductName VARCHAR(50), EndOfSupportDate date, IsHidden BIT,[Type] tinyint,OrderNo int)

	--Get: site/currency of all lines belong to a group headline
	INSERT INTO @TmpSiteCurrency (Currency, Site)
	SELECT DISTINCT C.currency, C.site
	FROM dbo.custAccount A WITH (NOLOCK) 
	INNER JOIN dbo.custAccount B WITH (NOLOCK)ON A.GroupID = B.GroupID
	INNER JOIN dbo.Customer C WITH (NOLOCK) ON C.custid=B.custid
	WHERE A.CustID = @CustID AND A.IsGroupHeadLine = 1 and A.IsRptConsol = 1
	
	--Check Show product by Site/Currency
	DECLARE @Site VARCHAR(10), @Currency TINYINT, @ID INT= 1
	 
	WHILE EXISTS (SELECT 1 FROM	@TmpSiteCurrency WHERE OrderID = @ID)
	BEGIN 
		SELECT	@Currency = c.currency,
				@site = c.site 
		FROM	@TmpSiteCurrency  c
		WHERE	OrderID = @ID

		INSERT INTO @CheckEnableProduct (ProductID, ProductName, IsHidden, EndOfSupportDate, OrderNo, [Type])
		EXEC dbo.Age_GetOfferedProductBySiteCurrency @Site = @Site, @Currency = @Currency, @SettingStatus = @SettingStatus

		SET @ID = @ID + 1
	END	 
	
	--------------------------------------------
	;WITH ProductList AS (
		SELECT p.ProductID, 
			   p.ProductName, 
			   p.EndOfSupportDate, 
			   MIN(CAST(IsHidden AS TINYINT)) AS IsHidden,
			   p.OrderNo,
			   p.[Type]
		FROM @CheckEnableProduct p
		GROUP BY p.ProductID, 
			   p.ProductName, 
			   p.EndOfSupportDate, 
			   p.OrderNo,
			   p.[Type]
	)
	SELECT p.ProductID, 
	       p.ProductName, 
		   p.EndOfSupportDate, 
		   CASE WHEN p.IsHidden=0 THEN 1 ELSE 0 END AS isShow,
		   p.OrderNo,
		   p.[Type]
	FROM ProductList p
	ORDER BY p.[Type], p.OrderNo
END
GO 