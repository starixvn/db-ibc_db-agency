ALTER PROCEDURE [dbo].[Age_Forecast_New_SelByLeague_SAg]
	@BaseOffsetHDP INT,
	@BaseOffsetOU INT,
	@BaseOffsetHTHDP INT,
	@BaseOffsetHTOU INT,
	@LeagueID INT,
	@Srecommend INT,
	@Language VARCHAR(2)
AS
/*
	Task : Retrieve Forecast By League (By Bettype: 1, 3, 7, 8)
	Original:Age_Forecast_SelByLeague_SAg
	DB: DB052.bodb02
	Created: 20111111@Tom
	Revisions:

	WARNING: TAKE A DEEP BREATH BEFORE READING THIS SP
*/
SET NOCOUNT ON

DECLARE @BetTypeHDP INT, @BetTypeOU INT, @VScoreHDP SMALLMONEY, @VScoreOU SMALLMONEY, @BetTypeHTHDP INT, @BetTypeHTOU INT
SELECT @BetTypeHDP = 1, @BetTypeOU = 3, @BetTypeHTHDP = 7, @BetTypeHTOU = 8


--Declare @Result TABLE (ForecastID int, bettype int, liveindicator bit, status varchar(10), offset smallmoney, hometotal money, awaytotal money, homelose money, awaylose money, betcount int, BaseOffset smallmoney, WinLostStatus int, MatchID int, FOffset smallmoney)
--WinlostStatus: 
--	1: home win 1/2
--	2: home win 1
--	3: home lose 1/2
--	2: home lose 1
--	5: draw
SELECT R.MatchID,
	m.homeid,
	m.awayid,	
	R.liveindicator, ISNULL(M.LiveHomeScore, 0) AS livehomescore, ISNULL(M.LiveAwayScore, 0) AS liveawayscore,M.ShowTime,M.MatchCode,

--R.status,
--	Sum(case when R.bettype = @BettypeHDP and R.FOffset = 0 then R.HomeTotal else 0 end) as HomeTotal_HDP, 
--	Sum(case when R.bettype = @BettypeHDP and R.FOffset = 0 then R.AwayTotal else 0 end) as AwayTotal_HDP, 
--	sum(case when R.bettype = @BettypeHDP and R.FOffset = 0 then R.BetCount else 0 end) as BetCount_HDP, 
--	Sum(case when R.bettype = @BettypeOU and R.FOffset = 0 then R.HomeTotal else 0 end) as HomeTotal_OU, 
--	Sum(case when R.bettype = @BettypeOU and R.FOffset = 0 then R.AwayTotal else 0 end) as AwayTotal_OU, 
--	sum(case when R.bettype = @BettypeOU and R.FOffset = 0 then R.BetCount else 0 end) as BetCount_OU, 
	SUM(CASE WHEN R.bettype = @BettypeHDP AND R.FOffset = -1 THEN CASE R.WinLostStatus WHEN 1 THEN R.AwayLose/2 WHEN 2 THEN R.AwayLose WHEN 3 THEN R.HomeLose/2 WHEN 4 THEN R.HomeLose ELSE 0 END ELSE 0 END)  AS WinLost_M1_HDP,
	SUM(CASE WHEN R.bettype = @BettypeHDP AND R.FOffset =  0 THEN CASE R.WinLostStatus WHEN 1 THEN R.AwayLose/2 WHEN 2 THEN R.AwayLose WHEN 3 THEN R.HomeLose/2 WHEN 4 THEN R.HomeLose ELSE 0 END ELSE 0 END)  AS WinLost_0_HDP,
	SUM(CASE WHEN R.bettype = @BettypeHDP AND R.FOffset =  1 THEN CASE R.WinLostStatus WHEN 1 THEN R.AwayLose/2 WHEN 2 THEN R.AwayLose WHEN 3 THEN R.HomeLose/2 WHEN 4 THEN R.HomeLose ELSE 0 END ELSE 0 END)  AS WinLost_1_HDP,

	SUM(CASE WHEN R.bettype = @BettypeOU  AND R.FOffset =  0 THEN CASE R.WinLostStatus WHEN 1 THEN R.AwayLose/2 WHEN 2 THEN R.AwayLose WHEN 3 THEN R.HomeLose/2 WHEN 4 THEN R.HomeLose ELSE 0 END END)  AS WinLost_0_OU,
	SUM(CASE WHEN R.bettype = @BettypeOU  AND R.FOffset =  1 THEN CASE R.WinLostStatus WHEN 1 THEN R.AwayLose/2 WHEN 2 THEN R.AwayLose WHEN 3 THEN R.HomeLose/2 WHEN 4 THEN R.HomeLose ELSE 0 END END)  AS WinLost_1_OU,
	SUM(CASE WHEN R.bettype = @BettypeOU  AND R.FOffset =  2 THEN CASE R.WinLostStatus WHEN 1 THEN R.AwayLose/2 WHEN 2 THEN R.AwayLose WHEN 3 THEN R.HomeLose/2 WHEN 4 THEN R.HomeLose ELSE 0 END END)  AS WinLost_2_OU,

	SUM(CASE WHEN R.bettype = @BettypeHTHDP AND R.FOffset = -1 THEN CASE R.WinLostStatus WHEN 1 THEN R.AwayLose/2 WHEN 2 THEN R.AwayLose WHEN 3 THEN R.HomeLose/2 WHEN 4 THEN R.HomeLose ELSE 0 END ELSE 0 END)  AS WinLost_M1_HTHDP,
	SUM(CASE WHEN R.bettype = @BettypeHTHDP AND R.FOffset =  0 THEN CASE R.WinLostStatus WHEN 1 THEN R.AwayLose/2 WHEN 2 THEN R.AwayLose WHEN 3 THEN R.HomeLose/2 WHEN 4 THEN R.HomeLose ELSE 0 END ELSE 0 END)  AS WinLost_0_HTHDP,
	SUM(CASE WHEN R.bettype = @BettypeHTHDP AND R.FOffset =  1 THEN CASE R.WinLostStatus WHEN 1 THEN R.AwayLose/2 WHEN 2 THEN R.AwayLose WHEN 3 THEN R.HomeLose/2 WHEN 4 THEN R.HomeLose ELSE 0 END ELSE 0 END)  AS WinLost_1_HTHDP,

	SUM(CASE WHEN R.bettype = @BettypeHTOU  AND R.FOffset =  0 THEN CASE R.WinLostStatus WHEN 1 THEN R.AwayLose/2 WHEN 2 THEN R.AwayLose WHEN 3 THEN R.HomeLose/2 WHEN 4 THEN R.HomeLose ELSE 0 END END)  AS WinLost_0_HTOU,
 	SUM(CASE WHEN R.bettype = @BettypeHTOU  AND R.FOffset =  1 THEN CASE R.WinLostStatus WHEN 1 THEN R.AwayLose/2 WHEN 2 THEN R.AwayLose WHEN 3 THEN R.HomeLose/2 WHEN 4 THEN R.HomeLose ELSE 0 END END)  AS WinLost_1_HTOU,
	SUM(CASE WHEN R.bettype = @BettypeHTOU  AND R.FOffset =  2 THEN CASE R.WinLostStatus WHEN 1 THEN R.AwayLose/2 WHEN 2 THEN R.AwayLose WHEN 3 THEN R.HomeLose/2 WHEN 4 THEN R.HomeLose ELSE 0 END END)  AS WinLost_2_HTOU,
	ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral
FROM 	
	(
		SELECT 
			1 AS ForecastID, F.bettype, liveindicator, '' AS status, F.offset, 
--			hometotal, awaytotal, 
			homelose, awaylose, 
--			betcount, 
			BaseOffset + ForecastOffset.offset AS BaseOffset, 
			CASE WHEN F.BetType IN (@BetTypeHDP,@BetTypeHTHDP) THEN
						CASE 
							WHEN F.VScoreHDP + BaseOffset + ForecastOffset.offset - F.Offset > 0 AND F.VScoreHDP + BaseOffset + ForecastOffset.offset - F.Offset <0.5 THEN 1
							WHEN F.VScoreHDP + BaseOffset + ForecastOffset.offset - F.Offset > 0.25 THEN 2
							WHEN F.VScoreHDP + BaseOffset + ForecastOffset.offset - F.Offset < 0 AND F.VScoreHDP + BaseOffset + ForecastOffset.offset - F.Offset >-0.5 THEN 3
							WHEN F.VScoreHDP + BaseOffset + ForecastOffset.offset - F.Offset < -0.25 THEN 4
							ELSE 5
						END
					WHEN F.BetType IN (@BetTypeOU,@BetTypeHTOU) THEN
						CASE 
							WHEN F.VScoreOU + BaseOffset + ForecastOffset.offset - F.Offset = 0.25 THEN 1
							WHEN F.VScoreOU + BaseOffset + ForecastOffset.offset - F.Offset > 0.25 THEN 2
							WHEN F.VScoreOU + BaseOffset + ForecastOffset.offset - F.Offset = -0.25 THEN 3
							WHEN F.VScoreOU + BaseOffset + ForecastOffset.offset - F.Offset < -0.25 THEN 4
							ELSE 5
						END
					END AS WinlostStatus,
			F.MatchID, ForecastOffset.Offset AS fOffset
		FROM (
				SELECT
					b.matchid, b.bettype, b.liveindicator,
					ISNULL(m.livehomescore,0) - ISNULL(m.liveawayscore, 0) AS VScoreHDP,
					0 AS VScoreOU,
					(b.livehomescore - b.liveawayscore) - (hdp2 - hdp1) AS offset,
					SUM(b.HomeWinS) AS AwayLose,
					SUM(b.AwayWinS) AS HomeLose,
					CASE b.bettype 
						WHEN @BetTypeHDP THEN @BaseOffsetHDP
						WHEN @BetTypeHTHDP THEN @BaseOffsetHTHDP
						END AS BaseOffset
				FROM
					dbo.bettrans_Forecast_Agent b WITH (NOLOCK)
					INNER JOIN dbo.match m WITH (NOLOCK) ON b.matchid = m.matchid AND m.leagueid = @LeagueID AND m.eventstatus = N'running'
				WHERE
					b.srecommend = @srecommend
					AND b.bettype IN (@BetTypeHDP, @BetTypeHTHDP)
				GROUP BY
					b.matchid, b.bettype, b.liveindicator, m.livehomescore, m.liveawayscore,
					(b.livehomescore - b.liveawayscore) - (hdp2 - hdp1)
				
				UNION ALL

				SELECT
					b.matchid, b.bettype, b.liveindicator,
					0 AS VScoreHDP,
					ISNULL(m.livehomescore,0) + ISNULL(m.liveawayscore, 0) AS VScoreOU,
					hdp1 AS offset,
					SUM(b.HomeWinS) AS AwayLose,
					SUM(b.AwayWinS) AS HomeLose,
					CASE b.bettype 
						WHEN @BetTypeOU   THEN @BaseOffsetOU
						WHEN @BetTypeHTOU THEN @BaseOffsetHTOU
						END AS BaseOffset
				FROM
					dbo.bettrans_Forecast_Agent b WITH (NOLOCK)
					INNER JOIN dbo.match m WITH (NOLOCK) ON b.matchid = m.matchid AND m.leagueid = @LeagueID AND m.eventstatus = N'running'
				WHERE
					b.srecommend = @srecommend
					AND b.bettype IN (@BetTypeOU, @BetTypeHTOU)
				GROUP BY
					b.matchid, b.bettype, b.liveindicator, m.livehomescore, m.liveawayscore,
					hdp1
			) AS F 
			INNER JOIN 	(
						SELECT 1 AS bettype,-1 AS offset UNION ALL
						SELECT 1 AS bettype,0  AS offset UNION ALL
						SELECT 1 AS bettype,1  AS offset UNION ALL
						SELECT 3 AS bettype,0  AS offset UNION ALL
						SELECT 3 AS bettype,1  AS offset UNION ALL
						SELECT 3 AS bettype,2  AS offset UNION ALL
						SELECT 7 AS bettype,-1 AS offset UNION ALL
						SELECT 7 AS bettype,0  AS offset UNION ALL
						SELECT 7 AS bettype,1  AS offset UNION ALL
						SELECT 8 AS bettype,0  AS offset UNION ALL
						SELECT 8 AS bettype,1  AS offset UNION ALL
						SELECT 8 AS bettype,2  AS offset
					) AS ForecastOffset ON F.bettype = ForecastOffset.bettype	
	) AS R 
	INNER JOIN match AS M WITH (NOLOCK) ON R.MatchID = M.MatchID	
GROUP BY R.MatchID,  R.liveindicator, 
	m.homeid,
	m.awayid,	
	M.LiveHomeScore, M.LiveAwayScore, 	
	M.ShowTime, M.MatchCode,
	m.isNeutral
ORDER BY R.LiveIndicator DESC, M.MatchCode


GO
GRANT EXECUTE ON [dbo].[Age_Forecast_New_SelByLeague_SAg] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_Forecast_New_SelByLeague_SAg] TO [bodbDownlineNetView]