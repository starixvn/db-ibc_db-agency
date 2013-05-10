ALTER PROCEDURE [dbo].Age_Forecast_HR_FOdds_MAg
	@CustID INT,
	@Language VARCHAR(2) = 'E'
AS
/*
Created:20090902@Phuc 
Task : Forecast HR fixed odds.

DB: DB052.bodb02
Original:

Revisions:

Param's Explanation:
• @CustID: MasterID
*/

DECLARE @RaceTotal TABLE(Leagueid INT, Race INT, Bettype INT, TotalAmt MONEY)

SET NOCOUNT ON

DECLARE @FromDate DATETIME
SELECT @FromDate = CONVERT(VARCHAR(10), CURRENT_TIMESTAMP,120)

INSERT INTO @RaceTotal(Leagueid, Race, Bettype, TotalAmt)
SELECT m.Leagueid, CAST(m.GroupMatch AS INT) AS Race,
	Bettype,
	SUM(mpositiontaking*stake) AS TotalAmt
FROM 
	bettrans b (NOLOCK) INNER JOIN outright m (NOLOCK) ON b.matchid = m.orid 
WHERE 
	b.mrecommend = @custid AND 
	b.bettype IN (41,42) AND 
	m.eventdate = @fromdate AND 
	b.ruben=0 AND
	b.status IN ('running','waiting')
GROUP BY 
	m.leagueid, CAST(m.GroupMatch AS INT), Bettype	

INSERT INTO @RaceTotal(Leagueid, Race, Bettype, TotalAmt)
SELECT b1.Leagueid, b1.Race, b1.Bettype, SUM(bm.mpositiontaking * bm.stake) AS TotalAmt
FROM 
	bettransm bm (NOLOCK) INNER JOIN 
	(	SELECT 
			transid, b.matchid, m.Leagueid, CAST(m.GroupMatch AS INT) AS Race, Bettype
		FROM 
			bettrans b (NOLOCK) INNER JOIN outright m (NOLOCK) ON b.matchid = m.orid 
		WHERE
			mrecommend = @custid AND 
			b.bettype = 43 AND 
			m.eventdate = @fromdate AND 
			b.ruben=0 AND
			b.status IN ('running','waiting')
	)b1 ON b1.transid = bm.refno 
GROUP BY b1.Leagueid, b1.Race, b1.bettype
	
SELECT 	a.leagueId,
		a.Matchid,
		a.Race,
		a.HorseNo,
		a.TeamId,
		a.oddsstatus,
		a.eventdate,
		a.kickofftime,
		a.total_win,
		a.total_place,
		a.total_winplace,
		SUM(CASE WHEN total.bettype = 41 THEN winloss_win - totalamt ELSE 0 END) AS winloss_win,
		SUM(CASE WHEN total.bettype = 42 THEN winloss_place - totalamt ELSE 0 END) AS winloss_place,
		SUM(CASE WHEN total.bettype = 43 THEN winloss_winplace - totalamt ELSE 0 END) AS winloss_winplace
FROM
(
	SELECT
		b1.leagueId,
		b1.Matchid,
		b1.Race,
		b1.HorseNo,
		b1.TeamId,
		b1.oddsstatus,
		b1.eventdate,
		b1.kickofftime,
		SUM(CASE WHEN b1.bettype = 41 THEN (b1.mpositiontaking * b1.stake ) ELSE 0 END) AS total_win,
		SUM(CASE WHEN b1.bettype = 42 THEN (b1.mpositiontaking * b1.stake ) ELSE 0 END) AS total_place,
		SUM(CASE WHEN b1.bettype = 43 THEN (bm.mpositiontaking * bm.stake ) ELSE 0 END) AS total_winplace,

		SUM(CASE WHEN b1.bettype = 41 THEN (b1.mpositiontaking * b1.stake * b1.odds) ELSE 0 END) AS winloss_win,
		SUM(CASE WHEN b1.bettype = 42 THEN (b1.mpositiontaking * b1.stake * b1.odds) ELSE 0 END) AS winloss_place,
		SUM(CASE WHEN b1.bettype = 43 THEN (bm.mpositiontaking * bm.stake * bm.odds) ELSE 0 END) AS winloss_winplace
	FROM 
		(
			SELECT 
				m.leagueid, b.matchid, CAST(m.GroupMatch AS INT) as race, CAST(m.MatchCode AS INT) AS HorseNo, 
				m.teamid, m.oddsstatus, m.eventdate, m.kickofftime, b.mpositiontaking, b.stake, b.odds, b.bettype, b.transid
			FROM
				bettrans b (NOLOCK) INNER JOIN outright m (NOLOCK) ON b.matchid = m.orid
			WHERE 
				b.mrecommend = @custid AND 
				b.bettype IN (41,42,43) AND 
				m.eventdate = @fromdate AND 
				b.ruben=0 AND
				b.status IN ('running','waiting')
		) b1
		LEFT JOIN bettransm bm (NOLOCK) ON b1.transid = bm.refno 
	GROUP BY 
		b1.leagueId,
		b1.Matchid,
		b1.Race,
		b1.HorseNo,
		b1.TeamId,
		b1.oddsstatus,
		b1.eventdate,
		b1.kickofftime
)a INNER JOIN @RaceTotal total ON total.leagueid = a.leagueid AND a.Race = total.Race
GROUP BY 
	a.leagueId,
	a.Matchid,
	a.Race,
	a.HorseNo,
	a.TeamId,
	a.oddsstatus,
	a.eventdate,
	a.kickofftime,
	a.total_win,
	a.total_place,
	a.total_winplace
ORDER BY 
	a.leagueId,
	a.Race,
	a.HorseNo


GO
GRANT EXECUTE ON [dbo].Age_Forecast_HR_FOdds_MAg TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].Age_Forecast_HR_FOdds_MAg TO [bodbDownlineNetView]
GO
GRANT VIEW DEFINITION ON [dbo].Age_Forecast_HR_FOdds_MAg TO vnteam
