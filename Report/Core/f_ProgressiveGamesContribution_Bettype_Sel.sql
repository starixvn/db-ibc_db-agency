/*<info serverAlias="DBAGE-bodb02" selecters="bodbAdminNet,bodbDownlineNet,bodbDownlineNetView" viewers="" isFunction="1" isNested="1"></info>*/
USE [bodb02]
GO

ALTER FUNCTION [dbo].[f_ProgressiveGamesContribution_Bettype_Sel]
(
	 @ProductIDs		VARCHAR(MAX) = ''
)
RETURNS TABLE

/*
	Created by Percy
	Date: 2018-02-05
	DB: DBAGE.bodb02
	Task: Select bettype offer Progressive Games Contribution

	Revisions:
		- 20180205@Percy: Initialize SP [RedmineID: #89117]
*/

RETURN
	SELECT ProductId, bettype
	FROM (
		SELECT	DISTINCT s.Bettype, s.ProductID
		FROM	bodb02.dbo.SportBettypeMatrix s WITH (NOLOCK)
				INNER JOIN
					(
						SELECT GameType2 AS Bettype FROM DBPRO.bodb02.dbo.GameListRNG WITH (NOLOCK) WHERE IsJackpotGame = 1
					) g ON s.Bettype = g.Bettype
	) AS A
	WHERE
		@ProductIDs = 'All'
		OR (',' + @ProductIDs + ',' LIKE '%,' + CAST(A.ProductID AS VARCHAR(3)) + ',%')
GO