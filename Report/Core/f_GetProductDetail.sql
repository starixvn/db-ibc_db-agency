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
		
*/
RETURN
	SELECT 'ProductDetail' AS RefId, '1' AS ResourceId, 32 AS ProductId, 248 AS Sporttype, 0 AS Bettype, 1 AS [Order], 0 AS LeagueGroupID,  0 AS TicketType
	UNION ALL 
	SELECT 'ProductDetail' AS RefId, '2' AS ResourceId, 32 AS ProductId, 248 AS Sporttype, 4297 AS Bettype, 2 AS [Order], 0 AS LeagueGroupID,  0 AS TicketType
	UNION ALL 
	SELECT 'ProductDetail' AS RefId, '3' AS ResourceId, 32 AS ProductId, 248 AS Sporttype, 4298 AS Bettype, 3 AS [Order], 0 AS LeagueGroupID,  0 AS TicketType
	UNION ALL 
	SELECT 'ProductDetail' AS RefId, '4' AS ResourceId, 45 AS ProductId, 243 AS Sporttype, 0 AS Bettype, 4 AS [Order], 0 AS LeagueGroupID,  0 AS TicketType
	UNION ALL 
	SELECT 'ProductDetail' AS RefId, '5' AS ResourceId, 45 AS ProductId, 243 AS Sporttype, 3150 AS Bettype, 5 AS [Order], 0 AS LeagueGroupID,  0 AS TicketType
	UNION ALL 
	SELECT 'ProductDetail' AS RefId, '6' AS ResourceId, 36 AS ProductId, 247 AS Sporttype, 0 AS Bettype, 6 AS [Order], 0 AS LeagueGroupID,  0 AS TicketType
	UNION ALL 
	SELECT 'ProductDetail' AS RefId, '7' AS ResourceId, 36 AS ProductId, 247 AS Sporttype, 4599 AS Bettype, 7 AS [Order], 0 AS LeagueGroupID,  0 AS TicketType
	UNION ALL 
	SELECT 'ProductDetail' AS RefId, '8' AS ResourceId, 36 AS ProductId, 247 AS Sporttype, 4600 AS Bettype, 8 AS [Order], 0 AS LeagueGroupID,  0 AS TicketType
	UNION ALL 
	SELECT 'ProductDetail' AS RefId, '9' AS ResourceId, 21 AS ProductId, 211 AS Sporttype, 0 AS Bettype, 9 AS [Order], 0 AS LeagueGroupID,  0 AS TicketType
	UNION ALL 
	SELECT 'ProductDetail' AS RefId, '10' AS ResourceId, 21 AS ProductId, 211 AS Sporttype, 2499 AS Bettype, 10 AS [Order], 0 AS LeagueGroupID,  0 AS TicketType

	--- SB
	UNION ALL 
	SELECT 'ProductDetail' AS RefId, '11' AS ResourceId, 1 AS ProductId, 0 AS Sporttype, 0 AS Bettype, 11 AS [Order], 0 AS LeagueGroupID,  0 AS TicketType -- SB Normal ticket
	UNION ALL 
	SELECT 'ProductDetail' AS RefId, '11' AS ResourceId, 1 AS ProductId, 0 AS Sporttype, 0 AS Bettype, 11 AS [Order], 0 AS LeagueGroupID,  1 AS TicketType -- Cashout
	UNION ALL 
	SELECT 'ProductDetail' AS RefId, '12' AS ResourceId, 1 AS ProductId, 1 AS Sporttype, 0 AS Bettype, 12 AS [Order], 42 AS LeagueGroupID,  0 AS TicketType -- SABA Soccer
	UNION ALL 
	SELECT 'ProductDetail' AS RefId, '12' AS ResourceId, 1 AS ProductId, 1 AS Sporttype, 0 AS Bettype, 12 AS [Order], 74 AS LeagueGroupID,  0 AS TicketType -- SABA Soccer
	UNION ALL 
	SELECT 'ProductDetail' AS RefId, '12' AS ResourceId, 1 AS ProductId, 1 AS Sporttype, 0 AS Bettype, 12 AS [Order], 108 AS LeagueGroupID,  0 AS TicketType -- SABA Soccer
	UNION ALL 
	SELECT 'ProductDetail' AS RefId, '13' AS ResourceId, 1 AS ProductId, 2 AS Sporttype, 0 AS Bettype, 13 AS [Order], 42 AS LeagueGroupID,  0 AS TicketType -- SABA Basketball
	UNION ALL 
	SELECT 'ProductDetail' AS RefId, '14' AS ResourceId, 1 AS ProductId, 50 AS Sporttype, 0 AS Bettype, 14 AS [Order], 42 AS LeagueGroupID,  0 AS TicketType -- SABA Cricket
	UNION ALL 
	SELECT 'ProductDetail' AS RefId, '20' AS ResourceId, 1 AS ProductId, 5 AS Sporttype, 0 AS Bettype, 15 AS [Order], 42 AS LeagueGroupID,  0 AS TicketType -- SABA Tennis
	UNION ALL 
	SELECT 'ProductDetail' AS RefId, '23' AS ResourceId, 1 AS ProductId, 4 AS Sporttype, 0 AS Bettype, 16 AS [Order], 42 AS LeagueGroupID,  0 AS TicketType -- Virtual Ice Hockey
	UNION ALL 
	SELECT 'ProductDetail' AS RefId, '15' AS ResourceId, 1 AS ProductId, 1 AS Sporttype, 0 AS Bettype, 17 AS [Order], 113 AS LeagueGroupID,  0 AS TicketType -- SABA Soccer PinGoal
	UNION ALL 
	SELECT 'ProductDetail' AS RefId, '16' AS ResourceId, 1 AS ProductId, 2 AS Sporttype, 0 AS Bettype, 18 AS [Order], 122 AS LeagueGroupID,  0 AS TicketType -- SABA Basketball PinGoal
	UNION ALL 
	SELECT 'ProductDetail' AS RefId, '19' AS ResourceId, 1 AS ProductId, 43 AS Sporttype, 0 AS Bettype, 21 AS [Order], 151 AS LeagueGroupID,  0 AS TicketType -- SABA ESports PinGoal
	
	--- MG RNG
	UNION ALL 
	SELECT 'ProductDetail' AS RefId, '17' AS ResourceId, 73 AS ProductId, 155 AS Sporttype, 0 AS Bettype, 17 AS [Order], 0 AS LeagueGroupID, 0 AS TicketType -- Normal Bets
	UNION ALL 
	SELECT 'ProductDetail' AS RefId, '18' AS ResourceId, 73 AS ProductId, 155 AS Sporttype, 8695 AS Bettype, 18 AS [Order], 0 AS LeagueGroupID, 0 AS TicketType -- Promotion Prize

	--- Live22
	UNION ALL 
	SELECT 'ProductDetail' AS RefId, '21' AS ResourceId, 79 AS ProductId, 227 AS Sporttype, 0 AS Bettype, 21 AS [Order], 0 AS LeagueGroupID, 0 AS TicketType -- Normal Bets
	UNION ALL 
	SELECT 'ProductDetail' AS RefId, '22' AS ResourceId, 79 AS ProductId, 227 AS Sporttype, 7698 AS Bettype, 22 AS [Order], 0 AS LeagueGroupID, 0 AS TicketType -- Promotion Bets
