   ALTER PROCEDURE [dbo].[Age_ScoreMap_Result_MAg]
 	@mrecommend INT, 	
 	@matchids	VARCHAR(4000) = '',
 	@bettypes_live	VARCHAR(500),
 	@bettypes_dead	VARCHAR(500),
	@homeBeginScore INT = 0,
	@homeEndScore	INT = 6,
	@awayBeginScore	INT = 0,
	@awayEndScore	INT = 6
AS
/*
	Task: Forecast this Agent's winloss based on match's score preset
	Date: 20110919@Johnson
	DB: DB053.bodb02	
	Revisions:
		- 20120626@Sophia: Add new bettype 121, 122, 123 for Home no bet, Away no bet, Draw/No Draw
		- 20121003@Dan: update betteam for 121,122 bettype
		- 20121011@Johnson: correct forecast winloss for bettype 121,122
		- 20130311@Elodie: Get matchs which have eventstatus <> 'completed'
		
	Parameter's Explanations:
		@bettypes_live : live ball bet types 
		@bettypes_dead : dead ball bet types
*/


SET NOCOUNT ON;
	
	DECLARE @tmpScores TABLE(home INT, away INT)
	DECLARE @tmpBettrans TABLE(transid BIGINT PRIMARY KEY, betteam NVARCHAR(10), matchid INT, custid INT, bettype SMALLINT, hdp1 SMALLMONEY, hdp2 SMALLMONEY, 
							   odds SMALLMONEY, stake MONEY, liveindicator BIT, livehomescore SMALLINT, liveawayscore SMALLINT, mpositiontaking SMALLMONEY)

	-- get scores template
	Insert INTO @tmpScores (home, away) SELECT home, away FROM scores WITH(NOLOCK) WHERE (home BETWEEN @homeBeginScore AND @homeEndScore) AND (away BETWEEN @awayBeginScore AND @awayEndScore )	
	
	-- get member tickets INTO temp TABLE		
	INSERT INTO @tmpBettrans 
	SELECT transid, betteam, b.matchid, custid, bettype, hdp1, hdp2, odds, stake, liveindicator, b.livehomescore, b.liveawayscore, mpositiontaking
	FROM bettrans b WITH (nolock)			
	WHERE b.matchid IN (SELECT val FROM strSplit(@matchids , ','))
		AND mrecommend = @mrecommend
		AND (( bettype IN (SELECT val FROM strSplit(@bettypes_live,',')) AND liveindicator = 1) 
				OR (bettype IN (SELECT val FROM strSplit(@bettypes_dead,',')) AND liveindicator = 0)
			)
		AND b.ruben = 0
		AND statusid IN (0,1)
		AND mpositiontaking > 0 -- get tickets that agent get PT on these.

				
		SELECT matchid, home, away,
				ISNULL(-SUM(CASE
							WHEN r<=-0.5 AND bt IN (1,3,7,8) THEN 1
							WHEN r<0 AND bt IN (1,3,7,8) THEN 1+(r*2)
							ELSE 0
						END * risk) 
						+SUM(CASE
							WHEN r>=0.5 AND bt IN (1,3,7,8) THEN 1
							WHEN r>0 AND bt IN (1,3,7,8) THEN 1-(r*2)
							ELSE 0
						END * risk * trueodds),0)
					+/*once bt = 1,3,7,8,25 will calculate equation above ,the other way will calculate below*/
						ISNULL(-SUM(CASE
							WHEN r=0 AND bt IN (2,4,5,6,12,13,15,24,26,27,28,30,123)THEN 1
							WHEN r = 0 AND bt IN (20,21,25) AND home <> away THEN 1
							WHEN r = 0 AND bt = 121 THEN CASE WHEN home > away THEN 0 ELSE 1 END
							WHEN r = 0 AND bt = 122 THEN CASE WHEN away > home THEN 0 ELSE 1 END														
							ELSE 0
						END * risk) 
						+SUM(CASE
							WHEN r=1 AND bt IN (2,4,5,6,12,13,15,20,21,24,25,26,27,28,30,121,122,123)THEN 1
							ELSE 0
						END * risk * trueodds),0)
				  total
		FROM
			(
				SELECT 
					matchid, home, away,
					r.risk,
					r.trueodds,
					CASE WHEN betteam  = 'h' AND bt IN (1, 7) THEN (home+hc) - (away) 
						WHEN betteam <> 'h' AND bt IN (1, 7) THEN (away+hc) - (home) 
						WHEN betteam  = 'h' AND bt IN (2, 12) THEN (home+away)&1  
						WHEN betteam <> 'h' AND bt IN (2, 12) THEN 1-( (home+away)&1)
						WHEN betteam  = 'h' AND bt IN (3, 8) THEN (home+away) - hc 
						WHEN betteam <> 'h' AND bt IN (3, 8) THEN hc - (home+away)
						WHEN home < 5 AND away < 5 AND hc=home AND hd=away AND bt IN (4,30) THEN 1  
						WHEN (home >= 5 AND hc = 5 AND home - away >= hc ) OR (away >= 5 AND hd = 5 AND away - home >= hd) AND bt IN (4,30) THEN 1 
						WHEN home>away AND betteam = '1' AND bt IN (5, 15) THEN 1 
						WHEN away>home AND betteam = '2' AND bt IN (5, 15) THEN 1
						WHEN home=away AND betteam = 'x' AND bt IN (5, 15) THEN 1 
						WHEN home+away>= hc AND home+away<=hd AND bt = 6 THEN 1 											
						WHEN betteam = 'hy' AND away = 0 AND bt = 13 THEN 1
						WHEN betteam = 'hn' AND away > 0 AND bt = 13 THEN 1
						WHEN betteam = 'ay' AND home = 0 AND bt = 13 THEN 1
						WHEN betteam = 'an' AND home > 0 AND bt = 13 THEN 1
						WHEN home > away AND betteam = 'h' AND bt IN (20, 21) THEN 1
						WHEN away > home AND betteam = 'a' AND bt IN (20, 21) THEN 1						
						WHEN betteam = '1x' AND (home >= away) AND bt = 24 THEN 1
						WHEN betteam = '2x' AND (away >= home) AND bt = 24 THEN 1
						WHEN betteam = '12' AND (home <> away) AND bt = 24 THEN 1
						WHEN betteam = 'h' AND (home > away) AND bt = 25 THEN 1
						WHEN betteam = 'a' AND (away > home) AND bt = 25 THEN 1
						WHEN betteam = 'n' AND home = 0 AND away = 0 AND bt= 26 THEN 1
						WHEN betteam = 'o' AND (home = 0 or away = 0) AND home + away >=1 AND bt= 26 THEN 1
						WHEN betteam = 'b' AND home + away >= 2 AND home <> 0 AND away <> 0  AND bt= 26 THEN 1
						WHEN betteam = 'h' AND away = 0 AND home >= 1 AND bt = 27 THEN 1
						WHEN betteam = 'a' AND home = 0 AND away >= 1 AND bt = 27 THEN 1
						WHEN betteam = '1' AND hc + home - away > 0 AND  bt = 28 THEN 1 
						WHEN betteam = '2' AND hc + away - home > 0 AND  bt = 28 THEN 1
						WHEN betteam = 'x' AND hc - (home - away) = 0 AND bt = 28 THEN 1 	
						WHEN betteam = 'x' AND (home = away) AND bt = 121 THEN 1
						WHEN betteam = 'a' AND (away > home) AND bt = 121 THEN 1						
						WHEN betteam = 'h' AND (home > away) AND bt = 122 THEN 1
						WHEN betteam = 'x' AND (home = away) AND bt = 122 THEN 1						
						WHEN betteam = 'h' AND (home = away) AND bt = 123 THEN 1
						WHEN betteam = 'a' AND (home <> away) AND bt = 123 THEN 1				
						ELSE 0
					END  r,
					bt
			FROM @tmpScores CROSS JOIN 
					(
						SELECT	matchid, betteam,
								SUM( ( (stake * mpositiontaking * CASE WHEN odds<0 THEN -odds ELSE 1 END)) * CASE WHEN odds <0 THEN 1/-CAST(odds AS FLOAT) ELSE odds END ) / SUM( (stake* mpositiontaking *CASE WHEN odds<0 THEN -odds ELSE 1 END) ) trueodds,
								SUM( (stake * mpositiontaking * CASE WHEN odds<0 THEN -odds ELSE 1 END) ) risk,
								CASE WHEN betteam = 'h' AND liveindicator = 1 THEN (hdp2+liveawayscore)-(hdp1 + livehomescore)
									 WHEN betteam = 'h' AND liveindicator <> 1 THEN hdp2-hdp1
									 WHEN betteam <> 'h' AND liveindicator = 1 THEN (hdp1+livehomescore)-(hdp2+liveawayscore) 
									 ELSE hdp1-hdp2	 
								END hc,
								0 hd,
								bettype bt
						FROM @tmpBettrans b 
						WHERE bettype IN (1,7) 
						GROUP BY betteam, bettype, hdp1, hdp2, liveindicator, livehomescore, liveawayscore,matchid
					UNION ALL
						SELECT	matchid, betteam,
							SUM( (stake * mpositiontaking * CASE WHEN odds<0 THEN -odds ELSE 1 END ) * CASE WHEN odds <0 THEN 1/-CAST(odds AS FLOAT) ELSE odds END ) / SUM(stake * mpositiontaking * CASE WHEN odds<0 THEN -odds ELSE 1 END) trueodds,
							SUM(stake * mpositiontaking * CASE WHEN odds<0 THEN -odds ELSE 1 END) risk,
							0 hc,
							0 hd,
							bettype bt
						FROM @tmpBettrans b 
						WHERE bettype IN (2 ,12)
						GROUP BY betteam, bettype, hdp1, matchid
					UNION ALL
						SELECT	matchid , betteam,
							SUM( ( (stake * mpositiontaking * CASE WHEN odds<0 THEN -odds ELSE 1 END) ) * CASE WHEN odds <0 THEN 1/-CAST(odds AS FLOAT) ELSE odds END ) / SUM( (stake * mpositiontaking *CASE WHEN odds<0 THEN -odds ELSE 1 END) ) trueodds,
							SUM( (stake * mpositiontaking *CASE WHEN odds<0 THEN -odds ELSE 1 END) ) risk,
							hdp1,
							0 hd,
							bettype bt
						FROM @tmpBettrans b 
						WHERE bettype IN (3,8)
						GROUP BY betteam, bettype, hdp1, liveindicator, livehomescore, liveawayscore, matchid
					UNION ALL
						SELECT	matchid, betteam,
							SUM(stake * mpositiontaking * (odds-1)) / SUM(stake * mpositiontaking) trueodds,
							SUM(stake * mpositiontaking) risk,
							hdp1,
							hdp2,
							bettype bt
						FROM @tmpBettrans b
						WHERE bettype IN (4 ,30)
						GROUP BY betteam, bettype, hdp1,hdp2, matchid
					UNION ALL
						SELECT	matchid , betteam,
							SUM( stake * mpositiontaking * ( odds-1)) / SUM(stake * mpositiontaking) trueodds,
							SUM( stake * mpositiontaking) risk,
							0 hc,
							0 hd,
							bettype bt
						FROM @tmpBettrans b 
						WHERE bettype IN (5, 15)
						GROUP BY betteam, bettype, matchid
					Union all
						SELECT	matchid, betteam, 
								SUM( stake * mpositiontaking * (odds-1)) / SUM(stake * mpositiontaking) trueodds,
								SUM(stake * mpositiontaking) risk,
								cast(left(betteam,1)AS INT) AS hc,
								CASE right(betteam,1) 
									WHEN 'r' THEN 999
									ELSE cast(right(betteam,1) AS INT) 
								END AS hd,
								6 bt
						FROM @tmpBettrans b 
						WHERE bettype = 6
						GROUP BY betteam, matchid					
					UNION ALL
						SELECT	matchid, betteam, 
								SUM( stake * mpositiontaking * (odds-1)) / SUM(stake * mpositiontaking) trueodds,
								SUM(stake * mpositiontaking) risk,
								0 hc,
								0 hd,
								13 bt
						FROM @tmpBettrans b 
						WHERE bettype = 13
						GROUP BY betteam, matchid					
					UNION ALL
						SELECT	matchid, betteam,
							SUM( (stake * mpositiontaking * CASE WHEN odds<0 THEN -odds ELSE 1 END ) * CASE WHEN odds <0 THEN 1/-CAST(odds AS FLOAT) ELSE odds END ) / SUM(stake * mpositiontaking * CASE WHEN odds<0 THEN -odds ELSE 1 END) trueodds,
							SUM(stake * mpositiontaking * CASE WHEN odds<0 THEN -odds ELSE 1 END) risk,
							0 hc,
							0 hd,
							bettype bt
						FROM @tmpBettrans b 
						WHERE bettype IN (20 , 21)
						GROUP BY betteam, bettype, matchid					
					UNION ALL
						SELECT	matchid, betteam, 
							SUM( stake * mpositiontaking * (odds-1)) / SUM(stake * mpositiontaking) trueodds,
							SUM(stake * mpositiontaking) risk,
							0 hc,
							0 hd,
							24 bt
						FROM @tmpBettrans b 
						WHERE bettype = 24
						GROUP BY betteam, matchid
					UNION ALL
						SELECT	matchid, betteam, 
								SUM( stake * mpositiontaking * (odds-1)) / SUM(stake * mpositiontaking) trueodds,
								SUM(stake * mpositiontaking ) risk,
								0 hc,
								0 hd,
								25 bt
						FROM @tmpBettrans b 
						WHERE bettype = 25
						GROUP BY betteam, matchid
					UNION ALL
						SELECT	matchid, betteam, 
								SUM( stake * mpositiontaking * (odds-1)) / SUM(stake * mpositiontaking) trueodds,
								SUM(stake * mpositiontaking) risk,
								0 hc,
								0 hd,
								26 bt
						FROM @tmpBettrans b 
						WHERE bettype = 26
						GROUP BY betteam, matchid
					UNION ALL
						SELECT	matchid, betteam, 
								SUM( stake * mpositiontaking * (odds-1)) / SUM(stake * mpositiontaking) trueodds,
								SUM(stake * mpositiontaking) risk,
								0 hc,
								0 hd,
								27 bt
						FROM @tmpBettrans b 
						WHERE bettype = 27
						GROUP BY betteam, matchid 
					UNION ALL
						SELECT	matchid, betteam, 
								SUM( stake * mpositiontaking * (odds-1)) / SUM(stake * mpositiontaking) trueodds,
								SUM(stake * mpositiontaking) risk,
								CASE WHEN betteam = '1' THEN hdp2-hdp1
									 ELSE hdp1-hdp2	 
								END hc,
								0 hd,
								28 bt
						FROM @tmpBettrans b 
						WHERE bettype = 28
						GROUP BY betteam, hdp1, hdp2, matchid	
					UNION ALL
						SELECT	matchid , betteam,
							SUM( stake * mpositiontaking * ( odds-1)) / SUM(stake * mpositiontaking) trueodds,
							SUM( stake * mpositiontaking) risk,
							0 hc,
							0 hd,
							bettype bt
						FROM @tmpBettrans b 
						WHERE bettype IN (121,122,123)
						GROUP BY betteam, bettype, matchid				
					)r
				)u
			GROUP BY home, away, matchid
			ORDER BY matchid ,away, home
	
				
		SELECT matchid, homeid, awayid
		FROM match WITH(NOLOCK)
		WHERE eventstatus <> 'completed'
			AND matchid IN (SELECT val FROM strSplit(@matchids,','))
GO

GRANT EXECUTE ON [dbo].[Age_ScoreMap_Result_MAg] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_ScoreMap_Result_MAg] TO [bodbDownlineNetView]
GO
GRANT VIEW DEFINITION ON [dbo].[Age_ScoreMap_Result_MAg] TO [vnteam]
GO