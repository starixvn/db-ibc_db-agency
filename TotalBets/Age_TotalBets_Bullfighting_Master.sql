/*<info serverAlias="DBBOF-bodb02" executers="bodbDownlineNet,bodbDownlineNetView" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Age_TotalBets_Bullfighting_Master]
	@CustID INT --srecommend
AS

/*
	Created: 
	Task: 
	DB: DBBOF-bodb02
	Original: 
	Revisions:
		- 20171024@Paul: Create new [RedmineID: #84690]
		- 20180522@Paul: Get matches with EventStatus <> 'completed' [RedmineID: #95524]
		- 20201005@Danny: Change to use alias DBBOF alternative to DB042 [RedmineID: #139516]

*/

BEGIN
	SET NOCOUNT ON;

	SELECT	EventDate,
			Match3rdId,
			d.League3rdId,
			l.LeagueCode,
			HasLive,
			HomeId,
			AwayId,
			BetCount,
			Turnover,
			Banker,
			Player
	FROM (
		SELECT	m.EventDate,
				m.Match3rdId,
				m.League3rdId,
				m.HasLive,
				m.HomeId,
				m.AwayId,
				COUNT(1) AS BetCount,
				SUM(stake * spositiontaking) AS Turnover,
				SUM(CASE WHEN b.custom3 = 'b' THEN stake * (CASE WHEN b.odds < 0 THEN 1 ELSE b.odds END) * spositiontaking ELSE - b.actual_stake * spositiontaking END) AS Banker,
				SUM(CASE WHEN b.custom3 = 'p' THEN stake * (CASE WHEN b.odds < 0 THEN 1 ELSE b.odds END) * spositiontaking ELSE - b.actual_stake * spositiontaking END) AS Player
		FROM dbo.translog b WITH(NOLOCK)
			JOIN dbo.match3rd m WITH(NOLOCK) ON b.eventID = m.Match3rdId
		WHERE b.srecommend = @CustID
			AND b.gameID = 1004
			AND b.statusID IN (0, 1)
			AND m.EventStatus <> 'completed'
		GROUP BY m.EventDate, m.Match3rdId,
				m.League3rdId, m.HasLive, m.HomeId, m.AwayId
		) d
		JOIN dbo.League3rd l WITH(NOLOCK) ON d.League3rdId = l.League3rdId;

	SET NOCOUNT OFF;
END
GO