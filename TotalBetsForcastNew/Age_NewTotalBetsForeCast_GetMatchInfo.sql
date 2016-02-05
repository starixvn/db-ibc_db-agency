ALTER PROCEDURE [dbo].[Age_NewTotalBetsForeCast_GetMatchInfo]   
    @MatchID  INT
    ,@IsLive BIT = 1  
      
AS  
/*  
	Created By: Helen  
	Created Date: 20151223  
	Task:  Task: New Total Bet & Forecast [Redmine: 42116]   
	DB: DBAGE/bodb02  
	  
	Revisions:  
*/
BEGIN  
	
	SELECT m.homeid, m.awayid  
		, m.livehomescore  
		, m.liveawayscore
	FROM match m WITH (NOLOCK)
	WHERE M.matchid = @Matchid 
		AND EXISTS ( SELECT TOP 1 1   
					 FROM dbo.odds o WITH(NOLOCK)   
					 WHERE o.matchid = m.matchid   
							AND o.bettype IN (1,7,3,8,5,15)  
							AND o.oddsstatus <> 'closed'  
		)  
		  
		AND 1 = CASE   
					WHEN @IsLive = 0 AND m.kickofftime > GETDATE()  THEN 1  
					WHEN @IsLive = 1 AND m.kickofftime <= GETDATE()  THEN 1  
					ELSE 0  
				END  
END 
GO
GRANT EXEC ON Age_NewTotalBetsForeCast_GetMatchInfo TO [bodbDownlineNet]
GO
GRANT EXEC ON Age_NewTotalBetsForeCast_GetMatchInfo TO [bodbDownlineNetView]
GO

