/*<info serverAlias="DBAGE-bodb02" executers="bodbDownlineNet,bodbDownlineNetView" viewers="" isFunction="1" isNested="1"></info>*/
USE [bodb02]
GO

ALTER FUNCTION [dbo].[f_GetBettypeScoreMap]
(
)
RETURNS TABLE
AS

/*
	Created by Percy
	Date: 2017-10-20
	DB: DBAGE.bodb02
	Task: Get bettypes supported score map function

	Revisions:
		- 20171020@Percy: Create new function [RedmineID: #84913]
*/

RETURN
	SELECT t.TypeId, t.bettypes, ISNULL(i.infoBettypes, t.bettypes) AS infoBettypes, t.isLive, t.OrderId
	FROM
	(
		VALUES 
		-- Handicap Group
		(1, '1,7,301,303', 0, 10), (1, '1,7', 1, 10),
		-- Odd/Even Group
		(2, '2,12,136,137,138,139', 0, 20), (2, '2,12,136,137,138,139,157', 1, 20),
		-- Over/Under Group
		(3, '3,8,302,304', 0, 30), (3, '3,8', 1, 30),
		-- 1x2
		(5, '5,15', 0, 40), (5, '5,15,167', 1, 40),
		-- Money line
		(20, '20,21', 0, 50), (20, '20,21', 1, 50),
		(24, '24,151,410', 0, 60), (24, '24,410', 1, 60),
		(26, '26,170,188,427', 0, 70), (26, '26', 1, 70),
		(25, '25,191,411', 0, 80), (25, '25,411', 1, 80),
		(13, '13', 0, 90), (13, '13', 1, 90),
		(27, '27', 0, 100), (27, '27', 1, 100),
		(28, '28,453', 0, 110), (28, '28,453', 1, 110),
		(4, '4,30,413,414', 0, 120), (4, '4,30,413,414', 1, 120),
		(6, '6,126,131,132,159,406,161,407,162,409', 0, 130), (6, '6,126,131,132,159,406,161,407,162,409,179,181,182', 1, 130),
		(121, '121', 0, 140), (121, '121', 1, 140),
		(122, '122', 0, 150), (122, '122', 1, 150),
		(123, '123', 0, 160), (123, '123', 1, 160)
	) AS t (TypeId, bettypes, isLive, OrderId)
		LEFT JOIN
		(
			-- Odd/Even Group
			VALUES (2, '2,12,136,137,138,139', 1)
		) AS i (TypeId, infoBettypes, isLive) ON t.TypeId = i.TypeId AND t.isLive = i.isLive
GO