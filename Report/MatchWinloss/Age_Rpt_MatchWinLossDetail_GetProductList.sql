/*<info serverAlias="DBAGE-bodb02" executers="bodbAdminNet,bodbDownlineNet,bodbDownlineNetView" viewers="vnteam" isFunction="0" isNested="0"></info>*/
USE [bodb02]
GO

ALTER PROCEDURE [dbo].[Age_Rpt_MatchWinLossDetail_GetProductList]
AS

/*
	Created by Percy
	DB: DBAGE.bodb02
	Task: Match Win Loss Detail - Get product list

	Revisions:
		- 20171020@Percy: Create new SP [RedmineID: #84690]
		- 20180130@Percy: Remove Racing [RedmineID: #86086]
*/

BEGIN
	SET NOCOUNT ON

	SELECT ProductId
	FROM (
		-- Sportbook, Number Game, Virtual Sport + Virtual Sport 2, Lucky 3, Bullfighting
		VALUES (1), (3), (5), (26), (30)
	) AS P (ProductId)
END
GO