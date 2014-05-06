  ALTER PROCEDURE [dbo].[Age_ScoreMap_SelLeague]
 	@agentid INT 	
AS
/*
	Task: Get leagues have bets under this Agent for Score Map function
	Date: 20110919@Johnson
	DB: DB053.bodb02	
	Revisions:
		- 20120626@Sophia: Add new bettype 121, 122, 123 for Home no bet, Away no bet, Draw/No Draw
		- 20130311@Elodie: Get matchs which have eventstatus <> 'completed'
		- 20140417@Dom: Add new bettype 126
	Parameter's Explanations:

*/
	DECLARE @roleid INT
	
	SELECT @roleid = roleid FROM custinfo WITH(NOLOCK) WHERE custid = @agentid 
	
	IF @roleid = 4
	BEGIN
		SELECT m.leagueid, m.sporttype
		FROM match m WITH(NOLOCK)			
		WHERE m.eventstatus <> 'completed'
			AND m.matchid IN (SELECT DISTINCT matchid 
								FROM bettrans WITH(NOLOCK)
								WHERE srecommend = @agentid 
									AND statusid IN (0,1)
									AND ruben = 0
									AND bettype IN (1,2,3,4,5,6,7,8,12,13,15,20,21,24,25,26,27,28,30,121,122,123,126)--Dom														
							)
		GROUP BY m.sporttype, m.leagueid 
	END
	ELSE IF @roleid = 3 
	BEGIN
		SELECT m.leagueid, m.sporttype
		FROM match m WITH(NOLOCK)
		WHERE m.eventstatus <> 'completed'
			AND m.matchid IN (SELECT DISTINCT matchid 
								FROM bettrans WITH(NOLOCK)
								WHERE mrecommend = @agentid 
									AND statusid IN (0,1)
									AND ruben = 0
									AND bettype IN (1,2,3,4,5,6,7,8,12,13,15,20,21,24,25,26,27,28,30,121,122,123,126)--Dom														
							)
		GROUP BY  m.sporttype ,m.leagueid 
	END
	ELSE IF @roleid = 2
	BEGIN 
		SELECT m.leagueid, m.sporttype
		FROM match m WITH(NOLOCK)			
		WHERE m.eventstatus <> 'completed'
			AND m.matchid IN (SELECT DISTINCT matchid 
								FROM bettrans WITH(NOLOCK)
								WHERE recommend = @agentid 
									AND statusid IN (0,1)
									AND ruben = 0
									AND bettype IN (1,2,3,4,5,6,7,8,12,13,15,20,21,24,25,26,27,28,30,121,122,123,126)--Dom														
							)
		GROUP BY m.sporttype ,m.leagueid
	END
	

GO


GRANT EXECUTE ON [dbo].[Age_ScoreMap_SelLeague] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_ScoreMap_SelLeague] TO [bodbDownlineNetView]
GO
GRANT VIEW DEFINITION ON [dbo].[Age_ScoreMap_SelLeague] TO [vnteam]
GO
