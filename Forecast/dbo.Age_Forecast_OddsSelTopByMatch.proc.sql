/*<info serverAlias="DBAGE-bodb02" executers="bodbDownlineNet,bodbDownlineNetView" viewers="" isFunction="0" isNested="0"></info>*/
USE [bodb02]
GO

ALTER PROCEDURE [dbo].[Age_Forecast_OddsSelTopByMatch]
	@matchid INT,
	@Language NVARCHAR(2) = 'E',
	@bettype INT = 1
AS
/*
	Task: Forecast at Agent Site 
	DB: DBAGE.bodb02 - DBEXT.bodb02
	Original:OddsSelTopByMatch
	
	Revisions: 
		- 20100721@Jacob: Add param @bettype 
		- 20130730@Lukas: get live score from match instead odds		
		- 20181226@Percy: Add table OddsES for E-Sports [RedmineID: #106994]
		- 20211115@Malcolm: Exclude odds are deleted [Redmine: #164321]
*/
SET NOCOUNT ON

SELECT TOP 1 matchid, hdp1, hdp2, odds1a, odds2a, switch, oddsstatus
INTO #odds
FROM dbo.odds WITH (NOLOCK)
WHERE bettype = @bettype AND matchid = @matchid AND ISNULL(IsDeleted, 0) <> 1
ORDER BY oddsid DESC

IF @@ROWCOUNT = 0
	INSERT INTO #odds
	SELECT TOP 1 matchid, hdp1, hdp2, odds1a, odds2a, switch, oddsstatus
	FROM dbo.oddsES WITH (NOLOCK)
	WHERE bettype = @bettype AND matchid = @matchid AND ISNULL(IsDeleted, 0) <> 1
	ORDER BY oddsid DESC

SELECT o.hdp1, o.hdp2, o.odds1a, o.odds2a,
	ISNULL(m.livehomescore, 0) livehomescore,
	ISNULL(m.liveawayscore, 0) liveawayscore, 
	o.switch, 
	o.oddsstatus,
	m.homeid,
	m.awayid,
	isnull(m.isNeutral, CONVERT(BIT, 0)) AS IsNeutral	
FROM #odds o
	LEFT JOIN dbo.match m WITH (NOLOCK) ON o.matchid = m.matchid AND ISNULL(m.IsDeleted, 0) <> 1
	
DROP TABLE #odds	
GO