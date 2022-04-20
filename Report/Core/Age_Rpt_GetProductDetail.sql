/*<info serverAlias="DBAGE-bodb02" executers="bodbDownlineNet,bodbDownlineNetView,bodbExtAccNet" isFunction="0" isNested="0"></info>*/
CREATE PROC dbo.Age_Rpt_GetProductDetail
AS
/*  
	Created: 20200819@Malcolm  
	Task : Get all product details for report
	DB: DBAGE/bodb02  
  
	Revisions:
		- 20200819@Malcolm: Initialize Sps - [Redmine: #139575]
		- 20220208@Danny: Separate Saba Sport Performance [Redmine: #167177]
		
*/

BEGIN
	;WITH t AS
	(
	SELECT 
			RefId
			,ResourceId
			,ProductId
			,Sporttype
			,Bettype
			,[Order]
			,LeagueGroupID
			,TicketType
			,ROW_NUMBER() over (partition by ProductID, SportType, Bettype, [Order], LeagueGroupID order by LeagueGroupID) as rn_l
			,ROW_NUMBER() over (partition by ProductID, SportType, Bettype,[Order],TicketType order by TicketType) as rn_t
		FROM dbo.f_GetProductDetail()
	)
	SELECT RefId
			,ResourceId
			,ProductId
			,Sporttype
			,Bettype
			,[Order]
			,STRING_AGG(CASE WHEN rn_l = 1 THEN LeagueGroupID END,',') LeagueGroupID
			,STRING_AGG(CASE WHEN rn_t = 1 THEN TicketType END,',')  TicketType
	FROM t
	GROUP BY RefId, ResourceId, ProductId, Sporttype, Bettype, [Order]
	ORDER BY ProductId, [Order]
END