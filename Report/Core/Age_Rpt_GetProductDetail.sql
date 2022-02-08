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
	SELECT 
		RefId
		,ResourceId
		,ProductId
		,Sporttype
		,Bettype
		,[Order]
		,LeagueGroupID
		,TicketType
	FROM dbo.f_GetProductDetail()
END