/*<info serverAlias="DBAGE-bodb02,DBACC-bodb02,DBARC-bodb_Archive" selecters="wsv_alp,wsv_alpv" isFunction="1" isNested="1"></info>*/
ALTER FUNCTION dbo.f_GetProductDetail()
RETURNS TABLE
AS
/*  
	Created: 20200819@Malcolm  
	Task : Get all product details for report
	DB: DBAGE/bodb02  
  
	Revisions:
		- 20200819@Malcolm: Initialize Sps - [Redmine: #139575]	
		- 20200908@Malcolm : Report Enhancement for Jackpot Product Filter [RedmineID : #139575]
		- 20210609@Malcolm: Add AE Sexy - [Redmine: #156239]	
		- 20220106@Evan: Add SG Jackpot - [Redmine: #166685]	
		- 20220124@Evan: Add Allbet Promotion - [Redmine: #166981]
		- 20220208@Danny: Add Saba Sport - [Redmine: #167177]
		- 20221004@Eddie: Add Tournament Prize [RedmineID: #178335]
		- 20221207@Eddie: Add New SABA ESports PinGoal [RedmineID: #181383]
		- 20221215@Eddie: Change Tournament Prize to Promotion Prize [RedmineID: #181578]
		- 20230630@Lewis: Add Saba Tennis [RedmineID: #190459]
		- 20231211@Lewis: Add Live22 [RedmineID: #194529]
		- 20231211@Lewis: Add Live22 - fix bettype7698 [RedmineID: #194530]
		- 20240306@Lewis: Add Virtual Ice Hockey [RedmineID: #201129]
		- 20240513@Lewis: Add Virtual Kabaddi [RedmineID: #203763]
		- 20240626@Lewis: Add FastSpin [RedmineID: #205740]
		- 20240718@Lewis: Add VGaming PromotionPrize [RedmineID: #203763]
		- 20240826@Lewis: Add FA CHAI - Promotion Prize [RedmineID: #209893]
		- 20250213@Lewis: Add ASKMESLOT [RedmineID: #219675]
		- 20250326@Bobby: 3rdProduct Integration [RedmineID: #221188]
		- 20250421@Dave: Add Rich Gaming [Redmine: #224863]
		- 20250509@Dave:  Add Saba Soccer Marble Spinner [Redmine: #223130]
		- 20250724@Virgil: Remove ODIN GAMING - Promotion Prize [Redmine: #234058]
		- 20250829@Virgil: Revise core function report to use SportBettypeMatrix [Redmine: #237223]	
*/
RETURN
	--- SB & SABA SportTypes
	SELECT RefId, ResourceId, ProductId, Sporttype, Bettype, [Order], LeagueGroupID, TicketType, ChildResourceId
	FROM f_GetSabaSportTypeRef()
	--- Other Products
	UNION ALL
	SELECT DISTINCT 
			'ProductDetail' AS RefId,
			TRY_CAST(JSON_VALUE(ExtraInfo, '$.ResourceId') AS VARCHAR(20)) AS ResourceId,
			ProductID,
			SportType, 
			TRY_CAST(ISNULL(JSON_VALUE(ExtraInfo, '$.BettypeRef'), 0) AS INT) AS Bettype,
			TRY_CAST(JSON_VALUE(ExtraInfo, '$.ResourceId') AS INT) AS [Order],
			0 AS LeagueGroupID,
			0 AS TicketType,
			NULL AS ChildResourceId
	FROM bodb02.dbo.SportBettypeMatrix (NOLOCK)
	WHERE JSON_VALUE(ExtraInfo, '$.ResourceId') IS NOT NULL 