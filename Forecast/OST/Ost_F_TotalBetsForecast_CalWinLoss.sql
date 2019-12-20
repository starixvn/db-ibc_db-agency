/*<info serverAlias="DBOST-bodb_ost" executers="bodbDownlineNet,bodbDownlineNetView" viewers="" isFunction="1" isNested="1"></info>*/
ALTER FUNCTION [dbo].[Ost_F_TotalBetsForecast_CalWinLoss]
(	
	@bettype			INT
	, @fValue			SMALLINT
	, @betteam			NVARCHAR(10) = NULL
	, @hdp1				SMALLMONEY = NULL
	, @hdp2				SMALLMONEY = NULL
	, @stake			MONEY = 0
	, @actual_stake		MONEY = 0
	, @odds				SMALLMONEY = 1
	, @livehomescore	SMALLINT = NULL
	, @liveawayscore	SMALLINT = NULL
	
)
RETURNS TABLE 
AS 
/*  
	Created By: 20191219@Bobby  
	Task: New Total Bet & Forecast [Redmine: 121898]   
	DB: DBOST/bodb_ost
	  
	Revisions:  
		- 20191219@Bobby : Move to bodb_ost - [Redmine:121898] 
*/       
RETURN (
	SELECT
		CASE  
			WHEN mo.Modds >= 0 THEN (ra.Ratio * b.stake)
			ELSE (ra.Ratio * b.actual_stake)
		END AS Winloss
	--- bettrans
	FROM (
		VALUES (
			@bettype
			, @FValue
			, @FValue
			, @betteam
			, @hdp2
			, @hdp1
			, @stake
			, @actual_stake
			, @odds
			, @livehomescore
			, @liveawayscore
		)
	) AS b (bettype, scorediff, totalGoals, betteam, hdp2, hdp1, stake, actual_stake, odds, livehomescore, liveawayscore)
	--- call modds
	CROSS APPLY
	(
		SELECT 
			CASE 
				WHEN b.bettype IN (1,7) THEN 
					CASE b.betteam 
						WHEN 'h' THEN (b.hdp2 - b.hdp1) + (b.scorediff - b.livehomescore  + b.liveawayscore)
						WHEN 'a' THEN (b.hdp1 - b.hdp2) + (-b.scorediff + b.livehomescore  - b.liveawayscore)
					END
				WHEN b.bettype IN (3,8) THEN 
					CASE b.betteam 
						WHEN 'h' THEN b.totalGoals - b.hdp1
						WHEN 'a' THEN b.hdp1 - b.totalGoals
					END
				ELSE 0 -- not support
			END AS Modds
	) AS mo
	-- call ratio
	CROSS APPLY (
		SELECT CASE 
			WHEN mo.Modds >  0.25	THEN b.odds
			WHEN mo.Modds =  0.25	THEN 0.5 * b.odds
			WHEN mo.Modds =  0		THEN 0.00
			WHEN mo.Modds = -0.25	THEN -0.5
			WHEN mo.Modds < -0.25	THEN -1.00 
		END Ratio
	) AS ra
)
GO

