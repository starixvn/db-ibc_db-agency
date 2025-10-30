/*<info serverAlias="DBAGE-bodb02,DBACC-bodb02,DBARC-bodb_Archive" selecters="wsv_alp,wsv_alpv" isFunction="1" isNested="1"></info>*/
ALTER FUNCTION dbo.f_GetSabaSportTypeRef()
RETURNS TABLE
AS
/*
	Created: 20250922@Bobby
	Task : Get SB and SABA SportTypeRef [RedmineId: #237223]
	DB: DBAGE/bodb02

	Revisions:
		- 20240922@Bobby: Initial version [RedmineId: #235369]
*/
RETURN
	SELECT 'ProductDetail' AS RefId
		, ResourceId, ProductId, Sporttype, Bettype, [Order], LeagueGroupID, TicketType, ChildResourceId
	FROM (VALUES
		('11', 1, 0, 0, 11, 0, 0, NULL), -- SB Normal ticket
		('11', 1, 0, 0, 11, 0, 1, NULL), -- Cashout
		('12', 1, 1, 0, 12, 42, 0, NULL), -- SABA Soccer
		('12', 1, 1, 0, 12, 74, 0, NULL), -- SABA Soccer
		('12', 1, 1, 0, 12, 108, 0, NULL), -- SABA Soccer
		('13', 1, 2, 0, 13, 42, 0, NULL), -- SABA Basketball
		('24', 1, 50, 0, 16, 42, 0, 14), -- SABA Cricket
		('20', 1, 5, 0, 15, 42, 0, NULL), -- SABA Tennis
		('24', 1, 4, 0, 16, 42, 0, 23), -- Virtual Ice Hockey
		('24', 1, 47, 0, 16, 42, 0, 25), -- SABA Kabaddi
		('15', 1, 1, 0, 18, 113, 0, NULL), -- SABA Soccer PinGoal
		('15', 1, 1, 0, 18, 252, 0, 45), -- Saba Soccer Marble
		('16', 1, 2, 0, 19, 122, 0, NULL), -- SABA Basketball PinGoal
		('19', 1, 43, 0, 21, 151, 0, NULL) -- SABA ESports PinGoal
	) AS PD (
		ResourceId, ProductId, Sporttype, Bettype, [Order], LeagueGroupID, TicketType, ChildResourceId
	)
