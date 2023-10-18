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
		
	Param's Explanation:

*/

BEGIN 
	SET NOCOUNT ON 
	
	DECLARE @TmpCustID TABLE(OrderID INT IDENTITY (1,1), CustID INT)
	DECLARE @ProductList TABLE (ProductID TINYINT, ProductName VARCHAR(50), EndOfSupportDate date, isShow BIT DEFAULT (0),[Type] tinyint,OrderNo int)

	INSERT INTO @TmpCustID
	SELECT	B.CustID
	FROM	dbo.custAccount A WITH (NOLOCK) 
	INNER JOIN dbo.custAccount B WITH (NOLOCK)ON A.GroupID = B.GroupID
	WHERE	A.CustID = @CustID AND A.IsGroupHeadLine = 1 and A.IsRptConsol = 1

	INSERT INTO @ProductList (ProductID, ProductName, EndOfSupportDate,OrderNo,[Type])
	SELECT	ProductID, 
			ProductName, 
			EndOfSupportDate,
			ISNULL(d.OrderNo,0) AS OrderNo,
			CASE WHEN d.CasinoType = 1 THEN 53
				WHEN d.CasinoType = 2 THEN 41
				ELSE 0 END AS [Type]
	FROM dbo.Products d WITH (NOLOCK)
	WHERE GroupType = 0	-- Real product
	
	CREATE TABLE #SportBettypeFilter (RealProductId TINYINT, SportType SMALLINT,Bettype SMALLINT,IsLive BIT, SettingType TINYINT)
	CREATE TABLE #ProductSettingType(
		SettingType	tinyint,
		SettingName	varchar(30)
	)

	INSERT INTO #ProductSettingType(SettingType,SettingName)
	SELECT SettingType,SettingName 
	FROM DBCUST.CUSTDB.dbo.ProductSettingType WITH(NOLOCK) 
	WHERE SettingName IN('Product Status','Bet Setting','Stake Level')

	INSERT INTO #SportBettypeFilter (RealProductId,SportType,Bettype,IsLive, SettingType)
	SELECT p.RealProductId,p.SportType,p.Bettype,p.IsLive, p.SettingType   
	FROM dbo.f_CustSetting_ProductSettingDetailSel(@SettingStatus) p
		INNER JOIN #ProductSettingType t ON p.SettingType = t.SettingType
	WHERE t.SettingName = 'Product Status'

	UPDATE	@ProductList
	SET		isShow = 1
	WHERE	ProductID IN (1) ---SB: always show

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
			FROM #SportBettypeFilter c
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
	DECLARE @Site VARCHAR(10), @Currency INT, @CID INT, @ID INT= 1, @SiteID INT
	DECLARE @CheckPGSoftEnable AS TABLE (ProductID INT, SportType INT, BetType INT)
	CREATE TABLE #SportBettypeDummy(RealProductId TINYINT, SportType SMALLINT,Bettype SMALLINT, IsHidden BIT DEFAULT(1))
	--Insert sports of Live Casino
	INSERT INTO #SportBettypeDummy (RealProductId,SportType,Bettype)
	SELECT mt.RealProductId,p.SportType,p.Bettype
	FROM dbo.f_CustSetting_ProductSettingDetailSel(@SettingStatus) p
		INNER JOIN #ProductSettingType t ON p.SettingType = t.SettingType
		INNER JOIN SportBettypeSettingMatrix mt WITH(NOLOCK) ON mt.SportType = p.SportType AND mt.BetType = p.BetType AND mt.isLicensee = 0 AND mt.Site = 'ALL' AND mt.isDeleted = 0
	WHERE SettingName IN('Bet Setting','Stake Level')
		AND p.ProductID IN (41) --Live Casino
		AND EXISTS( SELECT 1 FROM #T dm WHERE p.ProductID = dm.ProductID AND dm.IsHide = 0)
	 
	WHILE EXISTS (SELECT 1 FROM	@TmpCustID WHERE OrderID = @ID)
	BEGIN 
		SELECT	@CID = CustID 
		FROM	@TmpCustID 
		WHERE	OrderID = @ID

		--Product Status
		SELECT	@SiteID = s.siteid,
				@Currency = c.currency,
				@site = c.site
		FROM customer c WITH (NOLOCK)
			INNER JOIN Site s WITH (NOLOCK) ON c.site = s.site	
		WHERE c.custid = @CID
		 
		INSERT INTO @CheckPGSoftEnable (ProductID, SportType, BetType)
		EXEC dbo.Acc_CustSetting_CheckMacauEnable @Site = @Site, @Currency = @Currency, @CustID = @CID, @SettingStatus = @SettingStatus

		--START - Process for Live Casino
		IF EXISTS ( SELECT 1 FROM #SportBettypeDummy) 
		BEGIN
			
			UPDATE t
			SET t.IsHidden = dbo.f_CustSetting_GetSportOfferStatusBySiteCurrency(@SiteID,@Currency,t.Sporttype,t.Bettype,@SettingStatus)
			FROM #SportBettypeDummy t
			WHERE t.IsHidden = 1

			UPDATE	P
			SET		isShow = 1
			FROM	@ProductList P
				INNER JOIN #SportBettypeDummy t ON p.ProductID = t.RealProductId
			WHERE t.IsHidden = 0

			DELETE t
			FROM #SportBettypeDummy t
			WHERE t.IsHidden = 0
		END
		--END - Process for Live Casino

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
		   p.OrderNo,
		   p.[Type]
	FROM @ProductList p
	ORDER BY p.OrderNo
	
	DROP TABLE #T
	DROP TABLE #ProductSettingType
	DROP TABLE #SportBettypeFilter
	DROP TABLE #SportBettypeDummy
END
GO

 