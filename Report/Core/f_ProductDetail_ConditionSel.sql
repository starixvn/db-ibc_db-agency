/*<info serverAlias="DBAGE-bodb02,DBACC-bodb02,DBARC-bodb_Archive" selecters="bodbDownlineNet,bodbDownlineNetView" isFunction="1" isNested="1"></info>*/
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
			FROM dbo.f_GetProductDetail() f
			WHERE ISNULL(@ProductDetails,'')  = 'All'
	), cte_filter AS 
	(
		SELECT 
					t.c.value('(@ProductId)[1]', 'SMALLINT') AS ProductID
					, t.c.value('(@Sporttype)[1]', 'SMALLINT') AS Sporttype
					, t.c.value('(@Bettype)[1]', 'SMALLINT') AS Bettype
					, t.c.value('(@LeagueGroupId)[1]', 'VARCHAR(500)') AS LeagueGroupID
					, t.c.value('(@TicketType)[1]', 'TINYINT') AS TicketType
		FROM @__ProductDetails.nodes('ROOT/ProductDetail') t(c)
		WHERE  ISNULL(@ProductDetails,'') <> 'All' AND ISNULL(@ProductDetails,'') <> ''
	), cte_data AS
	(
		SELECT d.ProductId,  d.Sporttype, d.Bettype, x.LeagueGroupID, d.TicketType
		FROM (
			SELECT	ProductId,  Sporttype, Bettype, LeagueGroupID, TicketType FROM	cte_empty
			UNION ALL
			SELECT	ProductId,  Sporttype, Bettype, LeagueGroupID, TicketType FROM	cte_full
			UNION ALL
			SELECT	ProductId,  Sporttype, Bettype, LeagueGroupID, TicketType FROM	cte_filter
			) d
		CROSS APPLY (SELECT CAST (val AS INT) LeagueGroupID FROM  strSplit(d.LeagueGroupID, ',') x) x
	)
		SELECT  t.ProductId, t.Sporttype, t.Bettype, t.LeagueGroupID, t.TicketType
		FROM	cte_data t 
		UNION ALl
		SELECT u.ProductId, u.Sporttype, u.Bettype, 0 LeagueGroupID, 1 TicketType
		FROM   cte_data u 
		WHERE  u.ProductId = 1 AND u.Sporttype = 0 AND u.Bettype = 0 AND u.TicketType = 0

)
GO


	