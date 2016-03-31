ALTER FUNCTION [dbo].[f_NewTotalBetsForecast_GetWinLost_OU]
(	
	@hdp1 SMALLMONEY = NULL
	, @hdp2 SMALLMONEY = NULL
	, @betteam NVARCHAR(10) = NULL
	, @totalGoals SMALLINT = NULL
	, @TurnOver_Actualstake MONEY = 0
	, @TurnOver_stake MONEY = 0
	, @Odds SMALLMONEY = 1
	
)
RETURNS TABLE 
AS 
/*      
	Created By: Helen
	Created Date: 20151120
	Task: 	Task: New Total Bet & Forecast [Redmine: 42116] 
	DB: DBAGE/bodb02
	
	Parameter explaination:
		- Home win: @scorediff > 0
		- Home loss: @scorediff < 0
		- Member View
			Negative number in black indicates the amount SMA may win and Members may lose.	
			Positive number in red indicates the amount SMA may lose and Members may win.
				WHEN Modds >  0.25  THEN 1
				WHEN Modds =  0.25  THEN 0.5
				WHEN Modds =  0		THEN 0
				WHEN Modds = -0.25  THEN -0.5
				WHEN Modds < -0.25  THEN -1 
			
*/	       
RETURN (
	SELECT
		CASE  
			WHEN Modds >= 0 THEN (Ratio * @TurnOver_stake)
			ELSE (Ratio * @TurnOver_Actualstake)
		END AS outputNumber
	FROM 
		(
			SELECT 
				Modds
				,CASE 
					WHEN Modds >  0.25  THEN @Odds
					WHEN Modds =  0.25  THEN 0.5 * @Odds
					WHEN Modds =  0		THEN 0.00
					WHEN Modds = -0.25  THEN -0.5
					WHEN Modds < -0.25  THEN -1.00 
				END Ratio
			FROM
				(
					SELECT
						CASE @betteam 
							WHEN 'h' THEN @totalGoals - @hdp1
							WHEN 'a' THEN @hdp1 - @totalGoals
						END AS Modds
				) tmp01
		) tmp02
)

GO

