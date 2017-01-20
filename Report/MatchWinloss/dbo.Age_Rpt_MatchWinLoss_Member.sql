USE [bodb02]
GO

/****** Object:  StoredProcedure [dbo].[Age_Rpt_MatchWinLoss_Member]    Script Date: 1/20/2017 9:20:47 AM ******/
DROP PROCEDURE [dbo].[Age_Rpt_MatchWinLoss_Member]
GO

/****** Object:  StoredProcedure [dbo].[Age_Rpt_MatchWinLoss_Member]    Script Date: 1/20/2017 9:20:47 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


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
		- 20161219@Paul: Create new [RedmineID: #68723]

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

	INSERT INTO #bettrans(matchid, homeid, awayid, bettype, liveindicator, isNeutral, matchcode, showtime, comm, apositiontaking, playercomm, awinlost)
	SELECT	m.matchid,
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

	INSERT INTO #bettrans14(matchid, homeid, awayid, bettype, liveindicator, isNeutral, matchcode, showtime, comm, apositiontaking, playercomm, awinlost)
	SELECT	m.matchid,
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
		SELECT	b.matchid,
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
		GROUP BY b.matchid, b.homeid, b.awayid, b.matchcode, b.bettype, b.isNeutral, b.liveindicator, b.showtime

		UNION ALL --- Not Number Game not Group By liveindicator

		SELECT	b.matchid,
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
		GROUP BY b.matchid, b.homeid, b.awayid, b.matchcode, s.GroupTypeId, b.isNeutral, b.showtime
				
		UNION ALL

		SELECT	b.matchid,
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
		GROUP BY b.matchid, b.homeid, b.awayid, b.matchcode, b.bettype, b.isNeutral, b.liveindicator, b.showtime

		UNION ALL --- Not Number Game not Group By liveindicator

		SELECT	b.matchid,
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
		GROUP BY b.matchid, b.homeid, b.awayid, b.matchcode, s.GroupTypeId, b.isNeutral, b.showtime
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


