/*<info serverAlias="DBAGE-bodb02" executers="bodbAdminNet,bodbDownlineNet,bodbDownlineNetView" isFunction="0" isNested="0"></info>*/
CREATE PROCEDURE [dbo].[Age_Rpt_MatchWinLoss_Member]
	@CustID		INT,
	@FromDate	DATETIME,
	@ToDate		DATETIME	
AS

/*
	Created: 
	Task : 
	DB: DBAGE.bodb02
	Original: Age_Rpt_MatchWinLoss_Ag
	Revisions:
		- 20161219@Paul: Create new [RedmineID: #70554]
		- 20210305@Malcolm: Gather child matchs into a match (for cricket product)  - [RedminedId : #148454]

*/

BEGIN
	SET NOCOUNT ON;

	DECLARE @isTest BIT;
	SELECT  @isTest = dbo.f_CheckSPVersion(@@PROCID);

	CREATE TABLE #SportBettype (ProductID INT, Bettype SMALLINT, EventType INT, GroupTypeId INT);

	INSERT INTO #SportBettype (ProductID, Bettype, EventType, GroupTypeId)
	SELECT ProductID, s.Bettype, EventType, ISNULL(g.GroupTypeId, s.BetType)
	FROM dbo.f_SportBettypeMatrix_Sel (0, 0, 0, 2, '', '', @isTest) s
		LEFT JOIN dbo.f_GroupBettype () g ON s.BetType = g.Bettype;

	CREATE CLUSTERED INDEX ix_SportBettype_cl ON #SportBettype(Bettype);
	
	CREATE TABLE #bettrans(
		matchid INT,
		ParentID INT,
		ChildMatchType TINYINT,
		homeid INT,
		awayid INT,
		bettype SMALLINT,
		liveindicator BIT,
		isNeutral BIT,
		matchcode NVARCHAR(50),
		showtime NVARCHAR(50),
		comm MONEY,
		apositiontaking SMALLMONEY,
		playercomm MONEY,
		awinlost MONEY
	);

	INSERT INTO #bettrans(matchid, ParentID, ChildMatchType, homeid, awayid, bettype, liveindicator, isNeutral, matchcode, showtime, comm, apositiontaking, playercomm, awinlost)
	SELECT	m.matchid,
			m.ParentID,
			m.ChildMatchType,
			m.homeid,
			m.awayid,
			b.bettype,
			b.liveindicator,
			m.isNeutral,
			m.matchcode,
			m.showtime,
			b.comm,
			b.apositiontaking,
			b.playercomm,
			b.awinlost
	FROM bettrans b WITH (NOLOCK)		
		INNER JOIN match m WITH (NOLOCK) ON m.matchid = b.matchid
	WHERE b.recommend = @custid
		AND m.eventdate >= @fromdate
		AND m.eventdate <= @todate
		AND m.eventstatus = 'completed'
		AND ISNULL(m.betstatus, '') <> 'refund';
	
	CREATE TABLE #bettrans14(
		matchid INT,
		ParentID INT,
		ChildMatchType TINYINT,
		homeid INT,
		awayid INT,
		bettype SMALLINT,
		liveindicator BIT,
		isNeutral BIT,
		matchcode NVARCHAR(50),
		showtime NVARCHAR(50),
		comm MONEY,
		apositiontaking SMALLMONEY,
		playercomm MONEY,
		awinlost MONEY
	);

	INSERT INTO #bettrans14(matchid, ParentID, ChildMatchType, homeid, awayid, bettype, liveindicator, isNeutral, matchcode, showtime, comm, apositiontaking, playercomm, awinlost)
	SELECT	m.matchid,
			m.ParentID,
			m.ChildMatchType,
			m.homeid,
			m.awayid,
			b.bettype,
			b.liveindicator,
			m.isNeutral,
			m.matchcode,
			m.showtime,
			b.comm,
			b.apositiontaking,
			b.playercomm,
			b.awinlost
	FROM bettrans14 b WITH (NOLOCK)		
		INNER JOIN match14 m WITH (NOLOCK) ON m.matchid = b.matchid
	WHERE b.recommend = @custid
		AND m.eventdate >= @fromdate
		AND m.eventdate <= @todate
		AND m.eventstatus = 'completed'
		AND ISNULL(m.betstatus, '') <> 'refund';

	SELECT	matchid,
			homeid,
			awayid,
			bettype,
			liveindicator,
			ISNULL(isNeutral, CONVERT(BIT, 0)) AS isNeutral,
			matchcode,
			showtime,
			GrossComm,
			Comm,
			PositionTaking
	FROM
	(
		SELECT	MAX(b.matchid) AS matchid,
				b.homeid,
				b.awayid,
				b.bettype,
				b.liveindicator,
				b.isNeutral,
				b.matchcode,
				b.showtime,
				SUM(b.comm/(1 - b.apositiontaking)) AS GrossComm,
				SUM(comm - playercomm) AS Comm,
				SUM(awinlost) AS PositionTaking
		FROM #bettrans b WITH (NOLOCK)
		WHERE EXISTS (
			SELECT 1
			FROM #SportBettype s
			WHERE s.ProductID = 3
				AND b.bettype = s.Bettype
		)
		GROUP BY CASE WHEN b.ChildMatchType = 200 THEN b.ParentID ELSE b.matchid END, b.homeid, b.awayid, b.matchcode, b.bettype, b.isNeutral, b.liveindicator, b.showtime

		UNION ALL --- Not Number Game not Group By liveindicator

		SELECT	MAX(b.matchid) AS matchid,
				b.homeid,
				b.awayid,
				s.GroupTypeId AS bettype,
				CAST(0 AS BIT) AS liveindicator,
				b.isNeutral,
				b.matchcode,
				b.showtime,
				SUM(b.comm/(1 - b.apositiontaking)) AS GrossComm,
				SUM(b.comm - b.playercomm) AS Comm,
				SUM(b.awinlost) AS PositionTaking
		FROM #bettrans b WITH (NOLOCK)
			INNER JOIN #SportBettype s ON b.bettype = s.Bettype
		WHERE s.ProductID <> 3
			AND s.EventType NOT IN (2, 3)
		GROUP BY CASE WHEN b.ChildMatchType = 200 THEN b.ParentID ELSE b.matchid END, b.homeid, b.awayid, b.matchcode, s.GroupTypeId, b.isNeutral, b.showtime
				
		UNION ALL

		SELECT	MAX(b.matchid) AS matchid,
				b.homeid,
				b.awayid,
				b.bettype,
				b.liveindicator,
				b.isNeutral,
				b.matchcode,
				b.showtime,
				SUM(b.comm/(1 - b.apositiontaking)) AS GrossComm,
				SUM(comm - playercomm) AS Comm,
				SUM(awinlost) AS PositionTaking
		FROM #bettrans14 b WITH (NOLOCK)
		WHERE EXISTS (
				SELECT 1
				FROM #SportBettype s
				WHERE s.ProductID = 3
					AND b.bettype = s.Bettype
			)
		GROUP BY CASE WHEN ChildMatchType = 200 THEN ParentID ELSE b.matchid END, b.homeid, b.awayid, b.matchcode, b.bettype, b.isNeutral, b.liveindicator, b.showtime

		UNION ALL --- Not Number Game not Group By liveindicator

		SELECT	MAX(b.matchid) AS matchid,
				b.homeid,
				b.awayid,
				s.GroupTypeId AS bettype,
				CAST(0 AS BIT) AS liveindicator,
				b.isNeutral,
				b.matchcode,
				b.showtime,
				SUM(b.comm/(1 - b.apositiontaking)) AS GrossComm,
				SUM(b.comm - b.playercomm) AS Comm,
				SUM(b.awinlost) AS PositionTaking		
		FROM #bettrans14 b WITH (NOLOCK)	
			INNER JOIN #SportBettype s ON b.bettype = s.Bettype
		WHERE s.ProductID <> 3
			AND s.EventType NOT IN (2, 3)
		GROUP BY CASE WHEN b.ChildMatchType = 200 THEN b.ParentID ELSE b.matchid END, b.homeid, b.awayid, b.matchcode, s.GroupTypeId, b.isNeutral, b.showtime
	) x
	ORDER BY x.showtime;

	DROP TABLE #SportBettype;

	SET NOCOUNT OFF;
END

GO

GRANT EXECUTE ON [dbo].[Age_Rpt_MatchWinLoss_Member] TO [bodbDownlineNet] AS [dbo]
GO

GRANT EXECUTE ON [dbo].[Age_Rpt_MatchWinLoss_Member] TO [bodbDownlineNetView] AS [dbo]
GO

GRANT VIEW DEFINITION ON [dbo].[Age_Rpt_MatchWinLoss_Member] TO [vnteam] AS [dbo]
GO


