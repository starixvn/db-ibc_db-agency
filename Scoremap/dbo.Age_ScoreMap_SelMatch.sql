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
		- 20140814@Dom:  [Redmine: #19661] Offering 11 new bettypes
		- 20150410@Tom: Modify Forecast function to support new 60 bet types [Feature #32738]
	Parameter's Explanations:
		
*/
BEGIN
	DECLARE @roleid INT
	
	SELECT TOP 1 @roleid = roleid FROM dbo.custinfo WITH(NOLOCK) WHERE custid = @agentid
	
	DECLARE @tblBetType TABLE(BetType INT)

	INSERT INTO @tblBetType(BetType)
	SELECT val AS BetType FROM strSplit('7,8,12,15,21,126,136,138,167,179,181,182,188,191',',') --BETTYPE HT
	UNION ALL
	SELECT val AS BetType FROM strSplit('1,2,3,5,6,13,20,24,25,26,27,28,121,122,123,131,132,137,139,157,159,161,162,163,170',',') --BETTYPE FT

	IF @roleid = 4
	BEGIN
		SELECT m.matchid, m.homeid, m.awayid
		FROM match m WITH(NOLOCK)
		WHERE m.leagueid = @leagueid
			AND m.eventstatus <> 'completed'
			AND matchid IN ( SELECT DISTINCT matchid
							FROM dbo.bettrans b WITH(NOLOCK)
							WHERE b.srecommend = @agentid
								AND b.statusid IN (0,1)
								AND b.ruben = 0 
								--AND bettype IN (1,2,3,4,5,6,7,8,12,13,15,20,21,24,25,26,27,28,30,121,122,123,126,145,146,151,131,132,136,137,138,139)--Dom							
								AND EXISTS (SELECT TOP 1 1 FROM @tblBetType tbl WHERE tbl.bettype = b.bettype )
						)
	END
	ELSE IF @roleid = 3
	BEGIN
		SELECT m.matchid, m.homeid, m.awayid
		FROM match m WITH(NOLOCK)
		WHERE m.leagueid = @leagueid
			AND m.eventstatus <> 'completed'
			AND matchid IN ( SELECT DISTINCT matchid
							FROM dbo.bettrans b WITH(NOLOCK)
							WHERE b.mrecommend = @agentid
								AND b.statusid IN (0,1)
								AND b.ruben = 0 
								--AND bettype IN (1,2,3,4,5,6,7,8,12,13,15,20,21,24,25,26,27,28,30,121,122,123,126,145,146,151,131,132,136,137,138,139)--Dom							
								AND EXISTS (SELECT TOP 1 1 FROM @tblBetType tbl WHERE tbl.bettype = b.bettype )
						)
	END
	IF @roleid = 2
	BEGIN
		SELECT m.matchid, m.homeid, m.awayid
		FROM match m WITH(NOLOCK)
		WHERE m.leagueid = @leagueid
			AND m.eventstatus <> 'completed'
			AND matchid IN ( SELECT DISTINCT matchid
							FROM dbo.bettrans b WITH(NOLOCK)
							WHERE b.recommend = @agentid
								AND b.statusid IN (0,1)
								AND b.ruben = 0 
								--AND bettype IN (1,2,3,4,5,6,7,8,12,13,15,20,21,24,25,26,27,28,30,121,122,123,126,145,146,151,131,132,136,137,138,139)--Dom
								AND EXISTS (SELECT TOP 1 1 FROM @tblBetType tbl WHERE tbl.bettype = b.bettype )
						)
	END
END
GO


GRANT EXECUTE ON [dbo].[Age_ScoreMap_SelMatch] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_ScoreMap_SelMatch] TO [bodbDownlineNetView]
GO
GRANT VIEW DEFINITION ON [dbo].[Age_ScoreMap_SelMatch] TO [vnteam]
GO
 