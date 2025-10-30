/*<info serverAlias="DBAGE-bodb02" selecters="" isFunction="1" isNested="1"></info>*/
ALTER FUNCTION [dbo].[f_SportBettypeRefByProduct_Sel]
(
	@ProductIDs	VARCHAR(500) = ''
) 
/*
	Created: 20250926@Virgil
	Task: Enhance report for f_SportBettype_SumWinloss [RedmineId: #235369]	
	DB: DBAGE.bodb02
		
	Revisions:
		- 20240926@Virgil: Initial version [RedmineId: #235369]

	Paramters Explanation:
 		. @ProductIds: list of products
*/
RETURNS TABLE
RETURN
	SELECT DISTINCT ProductID,
			SportTypeRef,
			BettypeRef,
			0 AS LeagueGroupID,
			0 AS TicketType
	FROM [dbo].[vw_SportBettype_ExtraInfo] sp WITH (NOLOCK)
	WHERE ',' + @ProductIDs + ',' LIKE '%,' + CAST(sp.ProductID AS VARCHAR(3)) + ',%'
	/* SABA and SB */
	UNION ALL
	SELECT ProductID,
			SportType,
			Bettype,
			LeagueGroupID,
			TicketType
	FROM dbo.f_GetSabaSportTypeRef() 
	WHERE ',' + @ProductIDs + ',' LIKE '%,' + CAST(ProductID AS VARCHAR(3)) + ',%'
GO