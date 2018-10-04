/*<info serverAlias="DBAGE-bodb02" selecters="bodbAdminNet,bodbDownlineNet,bodbDownlineNetView,bodbExtAccNet" isFunction="1" isNested="1"></info>*/
USE [bodb02]
GO

ALTER FUNCTION [dbo].[f_Get_ExcludeProduct_SiteCurrency]
(
)
RETURNS TABLE
AS

/*
	Created: 20181004@Percy
	DB: DBAGE.bodb02
	Task: Core function - Get Special Product - Site/Currency

	Revisions:
		- 20181004@Percy: Initialize function [RedmineID: #101644]
*/

RETURN
	SELECT 33 AS ProductId, Site, Currency
	FROM (
		VALUES
			-- 789y
			('789y', 16), -- Yen
			('789y', 64), -- UT
			-- Best-Odds
			('Best-Odds', 16), -- Yen
			('Best-Odds', 64) -- UT
		) AS t(site, currency)
GO