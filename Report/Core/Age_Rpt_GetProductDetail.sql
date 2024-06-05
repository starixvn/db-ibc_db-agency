/*<info serverAlias="DBAGE-bodb02" executers="wsv_alp,wsv_alpv,wsv_xnap" isFunction="0" isNested="0"></info>*/
CREATE PROC dbo.Age_Rpt_GetProductDetail
AS
/*  
	Created: 20200819@Malcolm  
	Task : Get all product details for report
	DB: DBAGE/bodb02  
  
	Revisions:
		- 20200819@Malcolm: Initialize Sps - [Redmine: #139575]
		- 20220208@Danny: Separate Saba Sport Performance [Redmine: #167177]
		- 20240513@Lewis: Remove string_agg for product details [RedmineID: #203763]

*/

BEGIN
	SELECT 
			f.RefId
			,f.ResourceId
			,f.ProductId
			,f.Sporttype
			,f.Bettype
			,f.[Order]
			,f.LeagueGroupID
			,f.TicketType
			,f.ChildResourceId
	FROM dbo.f_GetProductDetail() f
	ORDER BY ProductId, [Order], Sporttype, LeagueGroupID, TicketType
END