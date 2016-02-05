ALTER FUNCTION [dbo].[f_NewTotalBetsForecast_GetWinLost_OU]
(	@bettype INT
	, @hdp1 SMALLMONEY = NULL, @hdp2 SMALLMONEY = NULL
	, @betteam VARCHAR(1) = NULL,@PositionTaking SMALLMONEY = 0
	, @totalGoals SMALLINT = NULL
	, @actual_stake MONEY = 0, @stake MONEY = 0
	
)
RETURNS MONEY
AS 
/*      
	Created By: Helen
	Created Date: 20151120
	Task: 	Task: New Total Bet & Forecast [Redmine: 42116] 
	DB: DBAGE/bodb02
	
	Parameter explaination:
		- Home win: @scorediff > 0
		- Home loss: @scorediff < 0
*/	       
BEGIN
		
		DECLARE @Modds INT,@Ratio INT
	
		
		SET @Modds = CASE 
						WHEN @betteam = N'h' THEN @totalGoals - @hdp1
						WHEN @betteam = N'a' THEN @hdp1 - @totalGoals
					 END	
		SET @Ratio = CASE 
				WHEN @Modds >  0.25  THEN -1
				WHEN @Modds =  0.25  THEN -0.5
				WHEN @Modds =  0		THEN 0
				WHEN @Modds = -0.25  THEN 0.5
				WHEN @Modds < -0.25  THEN 1 
			END
		
		IF @Modds >= 0
		BEGIN
			RETURN @Ratio * @PositionTaking * @stake 
		END
		ELSE
			RETURN @Ratio * @PositionTaking * @actual_stake
		
		RETURN 0
	
END

GO
GRANT EXEC ON f_NewTotalBetsForecast_GetWinLost_OU TO [bodbDownlineNet]
GO
GRANT EXEC ON f_NewTotalBetsForecast_GetWinLost_OU TO [bodbDownlineNetView]
GO