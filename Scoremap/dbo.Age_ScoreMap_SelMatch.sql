ALTER PROCEDURE [dbo].[Age_ScoreMap_SelMatch]
 	@agentid INT,
 	@leagueid	INT
 WITH RECOMPILE
AS
/*
	Task: Get matchs have bets under this Agent for Score Map function
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
		SELECT m.matchid, m.homeid, m.awayid
		FROM match m WITH(NOLOCK)
		WHERE m.leagueid = @leagueid
			AND m.eventstatus <> 'completed'
			AND matchid IN ( SELECT DISTINCT matchid
							FROM bettrans WITH(NOLOCK)
							WHERE srecommend = @agentid
								AND statusid IN (0,1)
								AND ruben = 0 
								AND bettype IN (1,2,3,4,5,6,7,8,12,13,15,20,21,24,25,26,27,28,30,121,122,123,126)--Dom							
						)
	END
	ELSE IF @roleid = 3
	BEGIN
		SELECT m.matchid, m.homeid, m.awayid
		FROM match m WITH(NOLOCK)
		WHERE m.leagueid = @leagueid
			AND m.eventstatus <> 'completed'
			AND matchid IN ( SELECT DISTINCT matchid
							FROM bettrans WITH(NOLOCK)
							WHERE mrecommend = @agentid
								AND statusid IN (0,1)
								AND ruben = 0 
								AND bettype IN (1,2,3,4,5,6,7,8,12,13,15,20,21,24,25,26,27,28,30,121,122,123,126)--Dom							
						)
	END
	IF @roleid = 2
	BEGIN
		SELECT m.matchid, m.homeid, m.awayid
		FROM match m WITH(NOLOCK)
		WHERE m.leagueid = @leagueid
			AND m.eventstatus <> 'completed'
			AND matchid IN ( SELECT DISTINCT matchid
							FROM bettrans WITH(NOLOCK)
							WHERE recommend = @agentid
								AND statusid IN (0,1)
								AND ruben = 0 
								AND bettype IN (1,2,3,4,5,6,7,8,12,13,15,20,21,24,25,26,27,28,30,121,122,123,126)--Dom							
						)
	END
GO


GRANT EXECUTE ON [dbo].[Age_ScoreMap_SelMatch] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_ScoreMap_SelMatch] TO [bodbDownlineNetView]
GO
GRANT VIEW DEFINITION ON [dbo].[Age_ScoreMap_SelMatch] TO [vnteam]
GO
 