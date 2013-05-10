ALTER PROCEDURE [dbo].[Age_Forecast1x2_New_SelByLeague_SAg]    
 @leagueid int,    
 @custid int    
AS

/*    
Original: Age_Forecast1x2_SelByLeague_SAg    
Task: Forecast for 1x2 bettype.    
DB: DB052.bodb02    
Created: 20120328@Hurri    
Revisions:    
    
    
*/

SET NOCOUNT ON    
Declare @BetType1x2 int, @BetTypeHT1x2 int 
SELECT @BetType1x2 = 5, @BetTypeHT1x2 = 15

SELECT x.MatchID,
	   x.homeid,
	   x.awayid,
	   x.liveindicator,
	   isnull(x.LiveHomeScore, 0) AS livehomescore,
	   isnull(x.LiveAwayScore, 0) AS liveawayscore,
	   x.ShowTime,
	   x.MatchCode,
	   isNeutral,
	   (x.awaywin) 'al',
	   (x.homewin) 'hl',
	   (x.drawwin) 'dl',
	   (x.ht_awaywin) 'ht_al',
	   (x.ht_homewin) 'ht_hl',
	   (x.ht_drawwin) 'ht_dl'
FROM
	(SELECT m.MatchID,
			m.homeid,
			m.awayid,
			b.liveindicator,
			isnull(b.LiveHomeScore, 0) AS livehomescore,
			isnull(b.LiveAwayScore, 0) AS liveawayscore,
			M.ShowTime,
			M.MatchCode,
			isnull(m.isNeutral, convert(BIT, 0)) AS IsNeutral,
			sum(CASE WHEN bettype = @BetType1x2 THEN homewinS ELSE 0 END) homewin,
			sum(CASE WHEN bettype = @BetType1x2 THEN awaywinS ELSE 0 END) awaywin,
			sum(CASE WHEN bettype = @BetType1x2 THEN drawwinS ELSE 0 END) drawwin,
			sum(CASE WHEN bettype = @BetTypeHT1x2 THEN homewinS ELSE 0 END) ht_homewin,
			sum(CASE WHEN bettype = @BetTypeHT1x2 THEN awaywinS ELSE 0 END) ht_awaywin,
			sum(CASE WHEN bettype = @BetTypeHT1x2 THEN drawwinS ELSE 0 END) ht_drawwin
	 FROM
		 dbo.bettrans_Forecast_Agent b WITH (NOLOCK)
		 INNER JOIN Match M WITH (NOLOCK)
			 ON b.MatchID = M.MatchID AND M.EventStatus = 'running'
	 WHERE
		 b.bettype IN (@Bettype1x2, @BettypeHT1x2)
		 AND LeagueID = @LeagueID
		 AND b.srecommend = @custid
	 GROUP BY
		 liveindicator, m.MatchID, m.homeid, m.awayid, b.liveindicator, b.LiveHomeScore, b.LiveAwayScore, M.ShowTime, M.MatchCode, isNeutral) As x     
GO
GRANT EXEC ON Age_Forecast1x2_New_SelByLeague_SAg TO [bodbDownlineNet]
GO
GRANT EXEC ON Age_Forecast1x2_New_SelByLeague_SAg TO [bodbDownlineNetView]
GO