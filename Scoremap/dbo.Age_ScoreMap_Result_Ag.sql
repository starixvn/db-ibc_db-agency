USE [bodb02]
GO
/****** Object:  StoredProcedure [dbo].[Age_ScoreMap_Result_Ag]    Script Date: 10/7/2015 11:20:01 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[Age_ScoreMap_Result_Ag]
 	@recommend INT, 	
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
		- 20140417@Dom: Add new bettype 126
		- 20140616@Dom: Support BetRadar [Redmine: #17148]
		- 20140814@Dom:  [Redmine: #19661] Offering 11 new bettypes
		- 20150410@Tom: Modify Forecast function to support new 60 bet types [Feature #32738]
		- 20150903@Winnie: Myanmar Odds 
	Parameter's Explanations:
		@bettypes_live : live ball bet types 
		@bettypes_dead : dead ball bet types
*/
BEGIN

	SET NOCOUNT ON;
	
	DECLARE @tmpScores TABLE(home INT, away INT)
	DECLARE @tmpBettrans TABLE(transid BIGINT PRIMARY KEY, betteam NVARCHAR(10), matchid INT, custid INT, bettype SMALLINT, hdp1 SMALLMONEY, hdp2 SMALLMONEY, 
							   odds SMALLMONEY, stake MONEY, liveindicator BIT, livehomescore SMALLINT, liveawayscore SMALLINT, apositiontaking SMALLMONEY,oddsspread MONEY)
	DECLARE @tblBetTypeHT_FT TABLE(BetType INT,isHT BIT)

	INSERT INTO @tblBetTypeHT_FT(BetType,isHT)
	SELECT val AS BetType,1 AS isHT  FROM strSplit('7,303, 8,304, 12, 15, 21, 30 ,126, 136, 138,167, 179, 181, 182, 188, 191',',') 
	
	-- get scores template
	INSERT INTO @tmpScores (home, away) SELECT home, away FROM scores WITH(NOLOCK) WHERE (home BETWEEN @homeBeginScore AND @homeEndScore) AND (away BETWEEN @awayBeginScore AND @awayEndScore )	
	
	-- get member tickets INTO temp TABLE	
	INSERT INTO @tmpBettrans 
	SELECT transid, betteam, b.matchid, custid, bettype, hdp1, hdp2, odds, stake, liveindicator, b.livehomescore, b.liveawayscore, apositiontaking,oddsspread
	FROM bettrans b WITH (nolock)			
	WHERE b.matchid IN (SELECT val FROM strSplit(@matchids , ','))
		AND b.recommend = @recommend
		AND (( b.bettype IN (SELECT val FROM strSplit(@bettypes_live,',')) AND liveindicator = 1) 
				OR (b.bettype IN (SELECT val FROM strSplit(@bettypes_dead,',')) AND liveindicator = 0)
			)
		AND b.ruben = 0
		AND b.statusid IN (0,1)
		AND b.apositiontaking > 0 -- get tickets that agent get PT on these.
		
				
		SELECT matchid, home, away,
				ISNULL(-SUM(CASE
							WHEN r<=-0.5 AND bt IN (1,3,7,8,301,302,303,304) THEN 1
							WHEN r<0 AND bt IN (1,3,7,8,25,301,302,303,304) THEN 1+(r*2)
							ELSE 0
						END * risk) 
						+SUM(CASE
							WHEN r>=0.5 AND bt IN (1,3,7,8,301,302,303,304) THEN 1
							WHEN r>0 AND bt IN (1,3,7,8,301,302,303,304) THEN 1-(r*2)
							ELSE 0
						END * risk * trueodds),0)
					+/*once bt = 1,3,7,8 will calculate equation above ,the other way will calculate below*/
						ISNULL(-SUM(CASE
							WHEN r=0 AND bt IN (2,4,5,6,12,13,15,24,26,27,28,30,123,126,151,145,146,131,132,136,137,138,139
												,157,167,170,188,159,161,162,165,166,179,181,182 --Bet Radar
												)THEN 1 --Dom
							WHEN r = 0 AND bt IN (20,21,25,191) AND home <> away THEN 1			--Bet Radar
							WHEN r = 0 AND bt = 121 THEN CASE WHEN home > away THEN 0 ELSE 1 END
							WHEN r = 0 AND bt = 122 THEN CASE WHEN away > home THEN 0 ELSE 1 END							
							ELSE 0
						END * risk) 
						+SUM(CASE
							WHEN r=1 AND bt IN (2,4,5,6,12,13,15,20,21,24,25,26,27,28,30,121,122,123,126,151,145,146,131,132,136,137,138,139
												,157,167,170,188,159,161,162,165,166,179,181,182,191--Bet Radar
												)THEN 1 --Dom
							ELSE 0
						END * risk * trueodds)
						+SUM(CASE
							WHEN r=0 AND bt IN (301,302,303,304)
							THEN 1 
							ELSE 0
						END *drawMO),0)
				  total
				  ,CASE WHEN tmpBetType.BetType IS NOT NULL THEN 1 ELSE 0 END isHT
		INTO #ScoreMap_Agent
		FROM
			(
				SELECT 
					matchid, home, away,
					r.risk,
					r.trueodds,
					r.MOwin+r.MOlose AS drawMO,
					CASE WHEN betteam  = 'h' AND bt IN (1,7,301,303) THEN (home+hc) - (away) 
						WHEN betteam <> 'h' AND bt IN (1,7,301,303) THEN (away+hc) - (home) 						
						WHEN betteam  = 'h' AND bt IN (2, 12,136,137,138,139,157) THEN (home+away)&1  --Dom & Radar
						WHEN betteam <> 'h' AND bt IN (2, 12,136,137,138,139,157) THEN 1-( (home+away)&1) --Dom & Radar
						WHEN betteam  = 'h' AND bt IN (3, 8,302,304) THEN (home+away) - hc 
						WHEN betteam <> 'h' AND bt IN (3, 8,302,304) THEN hc - (home+away)
						WHEN home < 5 AND away < 5 AND hc=home AND hd=away AND bt IN (4,30,165,166) THEN 1  
						WHEN ((home >= 5 AND hc = 5 AND home - away >= hc ) OR (away >= 5 AND hd = 5 AND away - home >= hd)) AND bt IN (4,30,165,166) THEN 1 
						WHEN home>away AND betteam = '1' AND bt IN (5, 15,167) THEN 1	--Radar
						WHEN away>home AND betteam = '2' AND bt IN (5, 15,167) THEN 1	--Radar
						WHEN home=away AND betteam = 'x' AND bt IN (5, 15,167) THEN 1	--Radar 
						
						WHEN home+away>= hc AND home+away<=hd AND bt in (6,126,131,132) THEN 1 	--Dom	 & Radar
						
						WHEN home+away>= hc AND hc = 6 AND bt = 159 THEN 1 	--Dom	 & Radar
						WHEN home+away= hc AND bt = 159 THEN 1 	--Dom	 & Radar
						
						WHEN home>= hc AND hc = 3 AND bt = 161 THEN 1 
						WHEN home= hc AND bt = 161 THEN 1 
						
						WHEN away>= hc AND hc = 3 AND bt = 162 THEN 1 
						WHEN away= hc AND bt = 162 THEN 1 
						
						WHEN home+away>= hc AND hc = 4 AND bt = 179 THEN 1 
						WHEN home+away= hc AND bt = 179 THEN 1 
						
						WHEN home>= hc AND hc = 3 AND bt = 181 THEN 1 
						WHEN home= hc AND bt = 181 THEN 1 
						
						WHEN away>= hc AND hc = 3 AND bt = 182 THEN 1 
						WHEN away= hc AND bt = 182 THEN 1
				
						
						WHEN betteam = 'hy' AND away = 0 AND bt = 13 THEN 1
						WHEN betteam = 'hn' AND away > 0 AND bt = 13 THEN 1
						WHEN betteam = 'ay' AND home = 0 AND bt = 13 THEN 1
						WHEN betteam = 'an' AND home > 0 AND bt = 13 THEN 1
						WHEN home > away AND betteam = 'h' AND bt IN (20, 21) THEN 1
						WHEN away > home AND betteam = 'a' AND bt IN (20, 21) THEN 1						
						WHEN betteam = '1x' AND (home >= away) AND bt IN (24,151) THEN 1
						WHEN betteam = '2x' AND (away >= home) AND bt IN (24,151) THEN 1
						WHEN betteam = '12' AND (home <> away) AND bt IN (24,151) THEN 1
						WHEN betteam = 'h' AND (home > away) AND bt IN (25, 191) THEN 1 --Radar
						WHEN betteam = 'a' AND (away > home) AND bt IN (25, 191) THEN 1 --Radar
						WHEN betteam = 'n' AND home = 0 AND away = 0 AND bt in(26,145,146,170,188) THEN 1							--Radar
						WHEN betteam = 'o' AND (home = 0 or away = 0) AND home + away >=1 AND bt in(26,145,146) THEN 1		--Radar
						WHEN betteam = 'b' AND home + away >= 2 AND home <> 0 AND away <> 0  AND bt in(26,145,146) THEN 1	--Radar		
												
						WHEN betteam = 'h' AND (home > 0) AND bt in(170) THEN 1		--Radar
						WHEN betteam = 'a' AND (away > 0) AND bt in(170) THEN 1		--Radar
						WHEN betteam = 'b' AND (home > 0 or away > 0) AND bt in(170) THEN 1		--Radar
						WHEN betteam = 'n' AND (home = 0 AND away = 0)AND bt in(170) THEN 1		--Radar						
						
						WHEN betteam = 'y' AND (home > 0 AND away > 0) AND bt in(188) THEN 1		--Radar
						WHEN betteam = 'n' AND (home = 0 AND away = 0)AND bt in(188) THEN 1		--Radar
										
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
								SUM( ( (stake * apositiontaking * CASE WHEN odds<0 THEN -odds ELSE 1 END)) * CASE WHEN odds <0 THEN 1/-CAST(odds AS FLOAT) ELSE odds END ) / SUM( (stake* apositiontaking *CASE WHEN odds<0 THEN -odds ELSE 1 END) ) trueodds,
								SUM( (stake * apositiontaking * CASE WHEN odds<0 THEN -odds ELSE 1 END) ) risk,
								sum(case when b.bettype IN(301,303) AND oddsspread>0 then (case when odds < 0 then 1 else odds end) * stake * (b.apositiontaking)*(oddsspread/100) else 0 end) MOwin,
								sum(case when b.bettype IN(301,303) AND oddsspread<0 then (case when odds < 0 then abs(odds) else 1 end)  * stake * (b.apositiontaking)*(oddsspread/100) else 0 end) MOlose,
								CASE WHEN betteam = 'h' AND liveindicator = 1 THEN (hdp2+liveawayscore)-(hdp1 + livehomescore)
									 WHEN betteam = 'h' AND liveindicator <> 1 THEN hdp2-hdp1
									 WHEN betteam <> 'h' AND liveindicator = 1 THEN (hdp1+livehomescore)-(hdp2+liveawayscore) 
									 ELSE hdp1-hdp2	 
								END hc,
								0 hd,
								bettype bt
						FROM @tmpBettrans b 
						WHERE bettype IN (1 ,7,301,303)
						GROUP BY betteam, bettype, hdp1, hdp2, liveindicator, livehomescore, liveawayscore,matchid
					UNION ALL
						SELECT	matchid, betteam,
							SUM( (stake * apositiontaking * CASE WHEN odds<0 THEN -odds ELSE 1 END ) * CASE WHEN odds <0 THEN 1/-CAST(odds AS FLOAT) ELSE odds END ) / SUM(stake * apositiontaking * CASE WHEN odds<0 THEN -odds ELSE 1 END) trueodds,
							SUM(stake * apositiontaking * CASE WHEN odds<0 THEN -odds ELSE 1 END) risk,
							0 MOwin,
							0 MOlose,
							0 hc,
							0 hd,
							bettype bt
						FROM @tmpBettrans b 
						WHERE bettype IN (2 ,12,136,137,138,139,157) --Dom & Radar
						GROUP BY betteam, bettype, hdp1, matchid
					UNION ALL
						SELECT	matchid , betteam,
							SUM( ( (stake * apositiontaking * CASE WHEN odds<0 THEN -odds ELSE 1 END) ) * CASE WHEN odds <0 THEN 1/-CAST(odds AS FLOAT) ELSE odds END ) / SUM( (stake * apositiontaking *CASE WHEN odds<0 THEN -odds ELSE 1 END) ) trueodds,
							SUM( (stake * apositiontaking *CASE WHEN odds<0 THEN -odds ELSE 1 END) ) risk,
							sum(case when b.bettype IN(302,304) AND oddsspread>0 then (case when odds < 0 then 1 else odds end) * stake * (b.apositiontaking)*(oddsspread/100) else 0 end) MOwin,
							sum(case when b.bettype IN(302,304) AND oddsspread<0 then (case when odds < 0 then abs(odds) else 1 end)  * stake * (b.apositiontaking)*(oddsspread/100) else 0 end) MOlose,
							hdp1,
							0 hd,
							bettype bt
						FROM @tmpBettrans b 
						WHERE bettype IN (3,8,302,304)
						GROUP BY betteam, bettype, hdp1, liveindicator, livehomescore, liveawayscore, matchid
					UNION ALL
						SELECT	matchid, betteam,
							SUM(stake * apositiontaking * (odds-1)) / SUM(stake * apositiontaking) trueodds,
							SUM(stake * apositiontaking) risk,
							0 MOwin,
							0 MOlose,
							hdp1,
							hdp2,
							bettype bt
						FROM @tmpBettrans b
						WHERE bettype IN (4,30)
						--WHERE bettype IN (4,30,165,166)
						GROUP BY betteam, bettype, hdp1,hdp2, matchid
					UNION ALL
						SELECT	matchid , betteam,
							SUM( stake * apositiontaking * ( odds-1)) / SUM(stake * apositiontaking) trueodds,
							SUM( stake * apositiontaking) risk,
							0 MOwin,
							0 MOlose,
							0 hc,
							0 hd,
							bettype bt
						FROM @tmpBettrans b 
						WHERE bettype IN (5,15,167) --Radar
						GROUP BY betteam, bettype, matchid
					Union all
						SELECT	matchid, betteam, 
								SUM( stake * apositiontaking * (odds-1)) / SUM(stake * apositiontaking) trueodds,
								SUM(stake * apositiontaking) risk,
								0 MOwin,
								0 MOlose,
								CASE WHEN bettype IN  (159,161,162,179,181,182) THEN cast(right(betteam,1)AS INT) 
									ELSE cast(left(betteam,1)AS INT) END
								AS hc,
								CASE right(betteam,1) 
									WHEN 'r' THEN 999
									ELSE cast(right(betteam,1) AS INT) 
								END AS hd,
								bettype bt
						FROM @tmpBettrans b 
						WHERE bettype IN (6,126,131,132,159,161,162,179,181,182) --Dom & Radar
						GROUP BY betteam, matchid,bettype				
					UNION ALL
						SELECT	matchid, betteam, 
								SUM( stake * apositiontaking * (odds-1)) / SUM(stake * apositiontaking) trueodds,
								SUM(stake * apositiontaking) risk,
								0 MOwin,
								0 MOlose,
								0 hc,
								0 hd,
								13 bt
						FROM @tmpBettrans b 
						WHERE bettype = 13
						GROUP BY betteam, matchid					
					UNION ALL
						SELECT	matchid, betteam,
							SUM( (stake * apositiontaking * CASE WHEN odds<0 THEN -odds ELSE 1 END ) * CASE WHEN odds <0 THEN 1/-CAST(odds AS FLOAT) ELSE odds END ) / SUM(stake * apositiontaking * CASE WHEN odds<0 THEN -odds ELSE 1 END) trueodds,
							SUM(stake * apositiontaking * CASE WHEN odds<0 THEN -odds ELSE 1 END) risk,
							0 MOwin,
							0 MOlose,
							0 hc,
							0 hd,
							bettype bt
						FROM @tmpBettrans b 
						WHERE bettype IN (20 ,21)
						GROUP BY betteam,bettype, matchid					
					UNION ALL
						SELECT	matchid, betteam, 
							SUM( stake * apositiontaking * (odds-1)) / SUM(stake * apositiontaking) trueodds,
							SUM(stake * apositiontaking) risk,
							0 MOwin,
							0 MOlose,
							0 hc,
							0 hd,
							24 bt
						FROM @tmpBettrans b 
						WHERE bettype IN (24,151)
						GROUP BY betteam, matchid
					UNION ALL
						SELECT	matchid, betteam, 
								SUM( stake * apositiontaking * (odds-1)) / SUM(stake * apositiontaking) trueodds,
								SUM(stake * apositiontaking ) risk,
								0 MOwin,
								0 MOlose,
								0 hc,
								0 hd,
								bettype bt
						FROM @tmpBettrans b 
						WHERE bettype  IN (25,191) --Radar
						GROUP BY betteam, matchid,bettype
					UNION ALL
						SELECT	matchid, betteam, 
								SUM( stake * apositiontaking * (odds-1)) / SUM(stake * apositiontaking) trueodds,
								SUM(stake * apositiontaking) risk,
								0 MOwin,
								0 MOlose,
								0 hc,
								0 hd,
								b.bettype bt
						FROM @tmpBettrans b 
						WHERE bettype IN (26,145,146,170,188)--Radar
						GROUP BY betteam, matchid, b.bettype
					UNION ALL
						SELECT	matchid, betteam, 
								SUM( stake * apositiontaking * (odds-1)) / SUM(stake * apositiontaking) trueodds,
								SUM(stake * apositiontaking) risk,
								0 MOwin,
								0 MOlose,
								0 hc,
								0 hd,
								27 bt
						FROM @tmpBettrans b 
						WHERE bettype = 27
						GROUP BY betteam, matchid 
					UNION ALL
						SELECT	matchid, betteam, 
								SUM( stake * apositiontaking * (odds-1)) / SUM(stake * apositiontaking) trueodds,
								SUM(stake * apositiontaking) risk,
								0 MOwin,
								0 MOlose,
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
							SUM( stake * apositiontaking * ( odds-1)) / SUM(stake * apositiontaking) trueodds,
							SUM( stake * apositiontaking) risk,
							0 MOwin,
							0 MOlose,
							0 hc,
							0 hd,
							bettype bt
						FROM @tmpBettrans b 
						WHERE bettype IN (121,122,123)
						GROUP BY betteam, bettype, matchid			
					)r
				)u
		LEFT JOIN @tblBetTypeHT_FT tmpBetType ON u.bt =  tmpBetType.BetType
			GROUP BY home, away, matchid
				,CASE WHEN  tmpBetType.BetType IS NOT NULL THEN 1 ELSE 0 END
			--ORDER BY matchid ,away, home
	
		SELECT matchid	
			,home	
			,away	
			,SUM(CASE WHEN isHT = 1 THEN total ELSE NULL END) HT
			,SUM(CASE WHEN isHT = 1 THEN NULL ELSE total END) FT
		FROM #ScoreMap_Agent data
		GROUP BY matchid, home, away
		ORDER BY matchid ,away, home
	
			-- get matchs to refer in score map
		SELECT matchid, homeid, awayid
		FROM match WITH(NOLOCK)
		WHERE eventstatus <> 'completed'
			AND matchid IN (SELECT val FROM strSplit(@matchids,','))
			
		DROP TABLE #ScoreMap_Agent
END
