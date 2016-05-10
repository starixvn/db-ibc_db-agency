USE [bodb02]
GO
/****** Object:  StoredProcedure [dbo].[Age_ScoreMap_SelLeague]    Script Date: 10/7/2015 11:18:03 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[Age_ScoreMap_SelLeague]
 	@agentid INT 	
AS
/*
	Task: Get leagues have bets under this Agent for Score Map function
	Date: 20110919@Johnson
	DB: DB053.bodb02	
	Revisions:
		- 20120626@Sophia: Add new bettype 121,122,123 for Home no bet,Away no bet,Draw/No Draw
		- 20130311@Elodie: Get matchs which have eventstatus <> 'completed'
		- 20140417@Dom: Add new bettype 126
		- 20140814@Dom: [Redmine: #19661] Offering 11 new bettypes		
		- 20150410@Tom: Modify Forecast function to support new 60 bet types [Feature #32738]
		- 20150828@Winnie: Myanmar odds
		- 20160509@Percy: Add 2 bettype Correct Score (AOS) [RedmineID: #48785]
	Parameter's Explanations:

*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @roleid INT
	
	SELECT TOP 1 @roleid = roleid FROM dbo.custinfo WITH(NOLOCK) WHERE custid = @agentid 
	
	DECLARE @tblBetType TABLE(BetType INT)

	INSERT INTO @tblBetType(BetType)
	SELECT val AS BetType FROM strSplit('7,303,8,304,12,15,21,126,136,138,167,179,181,182,188,191,413',',') --BETTYPE HT
	UNION ALL
	SELECT val AS BetType FROM strSplit('1,301,2,3,302,4,5,6,13,20,24,25,26,27,28,30,121,122,123,131,132,137,139,151,157,159,161,162,170,414',',') --BETTYPE FT

	IF @roleid = 4
	BEGIN
		SELECT m.leagueid,m.sporttype
		FROM match m WITH(NOLOCK)			
		WHERE m.eventstatus <> 'completed'
			AND m.matchid IN (SELECT DISTINCT matchid 
								FROM dbo.bettrans b WITH(NOLOCK)
								WHERE b.srecommend = @agentid 
									AND b.statusid IN (0,1)
									AND b.ruben = 0
									--AND bettype IN (1,2,3,4,5,6,7,8,12,13,15,20,21,24,25,26,27,28,30,121,122,123,126,145,146,151,131,132,136,137,138,139)--Dom														
									AND EXISTS (SELECT TOP 1 1 FROM @tblBetType tbl WHERE tbl.bettype = b.bettype )
							)
		GROUP BY m.sporttype,m.leagueid 
	END
	ELSE IF @roleid = 3 
	BEGIN
		SELECT m.leagueid,m.sporttype
		FROM match m WITH(NOLOCK)
		WHERE m.eventstatus <> 'completed'
			AND m.matchid IN (SELECT DISTINCT matchid 
								FROM dbo.bettrans b WITH(NOLOCK)
								WHERE b.mrecommend = @agentid 
									AND b.statusid IN (0,1)
									AND b.ruben = 0
									--AND bettype IN (1,2,3,4,5,6,7,8,12,13,15,20,21,24,25,26,27,28,30,121,122,123,126,145,146,151,131,132,136,137,138,139)--Dom														
									AND EXISTS (SELECT TOP 1 1 FROM @tblBetType tbl WHERE tbl.bettype = b.bettype )
							)
		GROUP BY  m.sporttype ,m.leagueid 
	END
	ELSE IF @roleid = 2
	BEGIN 
		SELECT m.leagueid,m.sporttype
		FROM match m WITH(NOLOCK)			
		WHERE m.eventstatus <> 'completed'
			AND m.matchid IN (SELECT DISTINCT matchid 
								FROM dbo.bettrans b WITH(NOLOCK)
								WHERE b.recommend = @agentid 
									AND b.statusid IN (0,1)
									AND b.ruben = 0
									--AND bettype IN (1,2,3,4,5,6,7,8,12,13,15,20,21,24,25,26,27,28,30,121,122,123,126,145,146,151,131,132,136,137,138,139)--Dom														
									AND EXISTS (SELECT TOP 1 1 FROM @tblBetType tbl WHERE tbl.bettype = b.bettype )
							)
		GROUP BY m.sporttype ,m.leagueid
	END
END
GO

GRANT EXECUTE ON [dbo].[Age_ScoreMap_SelLeague] TO [bodbDownlineNet] AS [dbo]
GO

GRANT EXECUTE ON [dbo].[Age_ScoreMap_SelLeague] TO [bodbDownlineNetView] AS [dbo]
GO

GRANT VIEW DEFINITION ON [dbo].[Age_ScoreMap_SelLeague] TO [vnteam] AS [dbo]
GO