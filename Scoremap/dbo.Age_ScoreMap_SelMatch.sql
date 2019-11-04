/*<info serverAlias="DB042-bodb02" executers="bodbDownlineNet,bodbDownlineNetView" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Age_ScoreMap_SelMatch]
 	@agentid	INT, -- SMA
 	@leagueid	INT
AS

/*
	Task: Get matchs have bets for Score Map function
	Date: 20110919@Johnson
	DB: DB042.bodb02	
	
	Revisions:
		- 20120626@Sophia: Add new bettype 121, 122, 123 for Home no bet, Away no bet, Draw/No Draw
		- 20130311@Elodie: Get matchs which have eventstatus <> 'completed'
		- 20140417@Dom: Add new bettype 126
		- 20140814@Dom:  [Redmine: #19661] Offering 11 new bettypes
		- 20150410@Tom: Modify Forecast function to support new 60 bet types [Feature #32738]
		- 20150828@Winnie: Myanmar odds
		- 20160509@Percy: Add 2 bettype Correct Score (AOS) [RedmineID: #48785]
		- 20160607@Percy: Enhance Performance - Remove WITH RECOMPILE [RedmineID: #58288]
		- 20160722@Percy: Support parent-child bettype [RedmineID: #53152]
		- 20171020@Percy: PHAIO 3 - Add bettype 453 [RedmineID: #84913]
		- 20180802@Helen: Update code for adjusting indexes - [Redmine:98757]
		- 20190918@Percy: Remove inactive products [RedmineID: #118699]
*/

BEGIN
	DECLARE @roleid INT
	SELECT  @roleid = roleid FROM dbo.custinfo WITH (NOLOCK) WHERE custid = @agentid 
	
	DECLARE @tblBetType TABLE (BetType INT PRIMARY KEY)

	INSERT INTO @tblBetType (BetType)
	SELECT typeid
	FROM dbo.bettype WITH (NOLOCK)
	WHERE
		typeid IN
		(
			-- half-time bettypes
			7,8,12,15,21,126,136,138,167,179,181,182,188,191,413,151,410,411,427,453,
			 -- full-time bettypes
			1,2,3,4,5,6,13,20,24,25,26,27,28,30,121,122,123,131,132,137,139,157,159,161,162,170,414,406,407,409
		)

	IF @roleid = 4
	BEGIN
		SELECT m.matchid, m.homeid, m.awayid
		FROM match m WITH(NOLOCK)
		WHERE m.leagueid = @leagueid
			AND m.eventstatus <> 'completed'
			AND matchid IN ( SELECT DISTINCT matchid
							FROM dbo.bettrans b WITH(NOLOCK, INDEX=IX_betrunning_srecommend)
							WHERE b.srecommend = @agentid
								AND b.statusid IN (0,1)
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
							FROM dbo.bettrans b WITH(NOLOCK, INDEX=IX_betrunning_mrecommend)
							WHERE b.mrecommend = @agentid
								AND b.statusid IN (0,1)
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
							FROM dbo.bettrans b WITH(NOLOCK, INDEX=IX_betrunning_recommend)
							WHERE b.recommend = @agentid
								AND b.statusid IN (0,1)
								AND EXISTS (SELECT TOP 1 1 FROM @tblBetType tbl WHERE tbl.bettype = b.bettype )
						)
	END
END
GO