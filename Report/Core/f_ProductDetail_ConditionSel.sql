/*<info serverAlias="DBAGE-bodb02,DBACC-bodb02,DBARC-bodb_Archive" selecters="wsv_alp,wsv_alpv" isFunction="1" isNested="1"></info>*/
CREATE FUNCTION f_ProductDetail_ConditionSel
(
	@ProductDetails		NVARCHAR(MAX) ,
	@__ProductDetails	XML
)
/*  
	Created: 20220208@Danny 
	Task : Get product details for report
	DB: DBAGE/bodb02  
  
	Revisions:
		- 20220208@Danny: Initialize func - [Redmine: #167177]
		- 20251029@Virgil: Changes impact on core func f_GetProductDetail [RedmineID: #235369]
*/
RETURNS TABLE 
AS
RETURN 
(
	 WITH cte_empty AS
	(
			SELECT 
				NULL AS ProductId,
				NULL AS Sporttype,
				NULL AS Bettype,
				NULL AS LeagueGroupID,
				NULL AS TicketType
			WHERE ISNULL(@ProductDetails,'') = ''
	), cte_full AS 
	(
		SELECT 
				ProductId
				,Sporttype
				,Bettype
				,LeagueGroupID
				,TicketType
			FROM dbo.f_GetProductDetail_Old() f
			WHERE ISNULL(@ProductDetails,'')  = 'All'
	), cte_filter AS 
	(
		SELECT 
					t.c.value('./@ProductId', 'SMALLINT') AS ProductID
					, t.c.value('./@Sporttype', 'SMALLINT') AS Sporttype
					, t.c.value('./@Bettype', 'SMALLINT') AS Bettype
					, t.c.value('./@LeagueGroupId', 'SMALLINT') AS LeagueGroupID
					, t.c.value('./@TicketType', 'TINYINT') AS TicketType
		FROM @__ProductDetails.nodes('//ProductDetail') t(c)
		WHERE  ISNULL(@ProductDetails,'') <> 'All' AND ISNULL(@ProductDetails,'') <> ''
	)
	SELECT d.ProductId,  d.Sporttype, d.Bettype, LeagueGroupID, d.TicketType
	FROM (
		SELECT	ProductId,  Sporttype, Bettype, LeagueGroupID, TicketType FROM	cte_empty
		UNION ALL
		SELECT	ProductId,  Sporttype, Bettype, LeagueGroupID, TicketType FROM	cte_full
		UNION ALL
		SELECT	ProductId,  Sporttype, Bettype, LeagueGroupID, TicketType FROM	cte_filter
		) d
		
)
GO


	