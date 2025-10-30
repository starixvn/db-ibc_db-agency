/*<info serverAlias="DBAGE-bodb02" selecters="" isFunction="1" isNested="1"></info>*/
ALTER FUNCTION [dbo].[f_SportBettype_SumWinloss_Sel]
(
	@ProductIDs	VARCHAR(500) = '',
	@IsTest		BIT			 = 0,
	@RefTable	TINYINT		 = NULL
) 
/*
	Created: 20250922@Bobby
	Task: Enhance report for f_SportBettype_SumWinloss [RedmineId: #235369]	
	DB: DBAGE.bodb02
		
	Revisions:
		- 20240922@Bobby: Initial version [RedmineId: #235369]

	Paramters Explanation:
 		. @ProductIds: list of products
		. @IsTest:
			1: Get all products and bettypes
			0: Get only products and bettypes which are not being tested
		. @RefTable:
			NULL: Get all RefTable
			0: Get bettrans
			1: Get bettransRNG
			2: Get bettransLC
			3: Get translog
			4: Get transfer
*/
RETURNS TABLE
RETURN
	SELECT DISTINCT
		sp.ProductID,
		sp.SportType,
		sp.BetType,
		sp.RefTable,
		ISNULL(saba.Sporttype, ck.SportTypeRef) AS SportTypeRef,
		ck.BettypeRef,
		ck.BettypeGroup,
		ISNULL(saba.LeagueGroupID, 0) AS LeagueGroupID,
		ISNULL(saba.TicketType, 0) AS TicketType
	FROM dbo.SportBettypeMatrix sp WITH (NOLOCK)
	CROSS APPLY (
		SELECT 
			ISNULL(TRY_CAST(JSON_VALUE(sp.ExtraInfo, '$.SportTypeRef') AS INT), 0) AS SportTypeRef,
			ISNULL(TRY_CAST(JSON_VALUE(sp.ExtraInfo, '$.BettypeRef') AS INT), 0) AS BettypeRef,
			ISNULL(TRY_CAST(JSON_VALUE(sp.ExtraInfo, '$.BettypeGroup') AS VARCHAR(50)), '') AS BettypeGroup
	) AS ck
	LEFT JOIN dbo.f_GetSabaSportTypeRef() saba
		ON saba.ProductId = sp.ProductID 
		AND saba.Bettype = ISNULL(ck.BettypeRef, 0)
	WHERE ',' + @ProductIDs + ',' LIKE '%,' + CAST(sp.ProductID AS VARCHAR(3)) + ',%'
		AND (sp.IsTest = 0 OR sp.IsTest = @IsTest)
		AND (@RefTable IS NULL OR sp.RefTable = @RefTable)
GO