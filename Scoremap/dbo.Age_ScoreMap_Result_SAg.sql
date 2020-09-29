/*<info serverAlias="DB042-bodb02" executers="bodbDownlineNet,bodbDownlineNetView" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Age_ScoreMap_Result_SAg]
 	@srecommend		INT, 	
 	@matchids		VARCHAR(4000) = '',
 	@bettypes_live	VARCHAR(500),
 	@bettypes_dead	VARCHAR(500),
	@homeBeginScore INT = 0,
	@homeEndScore	INT = 6,
	@awayBeginScore	INT = 0,
	@awayEndScore	INT = 6
AS
/*
	Task: Forecast this Super's winloss based on match's score preset
	Date: 20110919@Johnson
	DB: DBAGE.bodb02	
	
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
		- 20151127@Percy: Add AOS choice for Correct Score [RedmineID: #48050]
		- 20160509@Percy: Re-calculate 1H Correct Score [RedmineID: #48785]
		- 20160722@Percy: Support parent-child bettype [RedmineID: #53152]
		- 20171020@Percy: PHAIO 3 - Add bettype 453 [RedmineID: #84913]
		- 20180802@Helen: Update code for adjusting indexes - [Redmine:98757] 
		- 20180802@Helen: Wrongly calculation for bettype correct score half time  - [Redmine:99508]
		- 20190918@Percy: Remove inactive products [RedmineID: #118699]
		- 20200929@Malcolm : Offer Myanmar Odds for bettype in (1,3,7,8) [RedmineId : #141956]
		
	Parameter's Explanations:
		@bettypes_live : live ball bet types 
		@bettypes_dead : dead ball bet types
*/

BEGIN
	SET NOCOUNT ON;
	
	-- half-time bettypes
	DECLARE @hafltimeBettypes TABLE (BetType INT PRIMARY KEY)
	INSERT INTO @hafltimeBettypes (BetType)
	SELECT typeid
	FROM dbo.bettype WITH (NOLOCK)
	WHERE typeid IN (7,8,12,15,21,126,136,138,167,179,181,182,188,191,414,151,410,411,427,453)
	
	-- get scores template
	DECLARE @tmpScores TABLE (home INT, away INT)
	INSERT INTO @tmpScores (home, away)
	SELECT home, away
	FROM dbo.Scores WITH (NOLOCK)
	WHERE
		(home BETWEEN @homeBeginScore AND @homeEndScore)
		AND (away BETWEEN @awayBeginScore AND @awayEndScore )	
	

	DECLARE @tmpBettrans TABLE
	(
		transid BIGINT PRIMARY KEY,
		betteam NVARCHAR(10),
		matchid INT,
		custid INT,
		bettype SMALLINT,
		hdp1 SMALLMONEY,
		hdp2 SMALLMONEY,
		odds SMALLMONEY,
		stake MONEY,
		liveindicator BIT,
		livehomescore SMALLINT,
		liveawayscore SMALLINT,
		spositiontaking SMALLMONEY,
		oddsspread MONEY,
		oddstype TINYINT	
	)
	
	;WITH bettype_tmp (bettype, liveindicator) as 
	(
		SELECT val, 1 FROM strSplit(@bettypes_live,',')
		UNION ALL
		SELECT val, 0 FROM strSplit(@bettypes_dead,',')
	)
	-- get member tickets INTO temp TABLE	
	INSERT INTO @tmpBettrans 
	SELECT
		transid,
		betteam,
		matchid,
		custid,
		b.bettype,
		hdp1,
		hdp2,
		odds,
		stake,
		b.liveindicator,
		livehomescore,
		liveawayscore,
		spositiontaking,
		oddsspread,
		oddstype
	FROM bettrans b WITH (NOLOCK)	
		INNER JOIN bettype_tmp bt ON bt.bettype = b.bettype AND bt.liveindicator = b.liveindicator
	WHERE b.matchid IN (SELECT val FROM strSplit(@matchids , ','))
		AND b.srecommend = @srecommend
		AND b.statusid IN (0,1)
		AND b.spositiontaking > 0 -- get tickets that agent get PT on these.
				
	
		SELECT matchid, home , away,
				ISNULL(-SUM(CASE
							WHEN r<=-0.5 AND bt IN (1,3,7,8) THEN risk
							WHEN r<0 AND bt IN (1,3,7,8) THEN 0.5 * (risk + MYO_Won + MYO_Lose)
							ELSE 0
						END)  
						+SUM(CASE
							WHEN r>=0.5 AND bt IN (1,3,7,8) THEN  risk * trueodds
							WHEN r>0 AND bt IN (1,3,7,8) THEN 0.5 * (risk * trueodds + MYO_Won + MYO_Lose)
							ELSE 0
						END),0)
					+/*once bt = 1,3,7,8 will calculate equation above ,the other way will calculate below*/
						ISNULL(-SUM(CASE
							WHEN r=0 AND bt IN (2,4,5,6,12,13,15,24,26,27,28,30,123,126,151,145,146,131,132,136,137,138,139
												,157,167,170,188,159,161,162,179,181,182 --Bet Radar
												,413,414 -- AOS choice
												,406,407,409,410,427
												,453
												)THEN 1--Dom
							WHEN r = 0 AND bt IN (20,21,25,191,411) AND home <> away THEN 1		--Bet Radar
							WHEN r = 0 AND bt = 121 THEN CASE WHEN home > away THEN 0 ELSE 1 END
							WHEN r = 0 AND bt = 122 THEN CASE WHEN away > home THEN 0 ELSE 1 END																					
							ELSE 0
						END * risk) 
						+SUM(CASE
							WHEN r=1 AND bt IN (2,4,5,6,12,13,15,20,21,24,25,26,27,28,30,121,122,123,126,151,145,146,131,132,136,137,138,139
												,157,167,170,188,159,161,162,179,181,182,191--Bet Radar
												,413,414 -- AOS choice
												,406,407,409,410,411,427
												,453
												)THEN 1 --Dom
							ELSE 0
						END * risk * trueodds),0)
				  total
				  ,CASE WHEN tmpBetType.BetType IS NOT NULL THEN 1 ELSE 0 END isHT
		INTO #ScoreMap_Super
		FROM
			(
				SELECT 
					matchid, home, away,
					r.risk,
					r.trueodds,
					r.MYO_Won,
					r.MYO_Lose,
					CASE WHEN betteam  = 'h' AND bt IN (1,7) THEN (home+hc) - (away) 
						WHEN betteam <> 'h' AND bt IN (1,7) THEN (away+hc) - (home) 
						WHEN betteam  = 'h' AND bt IN (2,12,136,137,138,139,157) THEN (home+away)&1  --Dom & Radar
						WHEN betteam <> 'h' AND bt IN (2,12,136,137,138,139,157) THEN 1-( (home+away)&1) --Dom & Radar
						WHEN betteam  = 'h' AND bt IN (3,8) THEN (home+away) - hc 
						WHEN betteam <> 'h' AND bt IN (3,8) THEN hc - (home+away)
						--- Correct Score 0:0 --> 5:5 (4,413) and 0:0 --> 4:4 (30,414) ---
						WHEN betteam <> 'AOS' AND home < 5 AND away < 5 AND hc=home AND hd=away AND bt IN (4,413) THEN 1
						WHEN betteam <> 'AOS' AND home < 4 AND away < 4 AND hc=home AND hd=away AND bt IN (30,414) THEN 1
						--- 5:0UP, 0:5UP (4) and 4:0UP, 0:4UP (30) ---
						WHEN ((home >= 5 AND hc = 5 AND home - away >= hc ) OR (away >= 5 AND hd = 5 AND away - home >= hd)) AND bt IN (4) THEN 1
						WHEN ((home >= 4 AND hc = 4 AND home - away >= hc ) OR (away >= 4 AND hd = 4 AND away - home >= hd)) AND bt IN (30) THEN 1
						--- AOS choice ---
						WHEN betteam  = 'AOS' AND (home >= 5 OR away >= 5) AND bt IN (413) THEN 1
						WHEN betteam  = 'AOS' AND (home >= 4 OR away >= 4) AND bt IN (414) THEN 1

						WHEN home>away AND betteam = '1' AND bt IN (5,15,167) THEN 1 	--Radar
						WHEN away>home AND betteam = '2' AND bt IN (5,15,167) THEN 1	--Radar
						WHEN home=away AND betteam = 'x' AND bt IN (5,15,167) THEN 1 	--Radar
						
						WHEN home+away>= hc AND home+away<=hd AND bt in (6,126,131,132) THEN 1 	--Dom	 & Radar						
						
						WHEN home+away>= hc AND hc = 6 AND bt IN (159, 406) THEN 1 	--Dom	 & Radar
						WHEN home+away= hc AND bt IN (159, 406) THEN 1 	--Dom	 & Radar
						
						WHEN home>= hc AND hc = 3 AND bt IN (161, 407) THEN 1 
						WHEN home= hc AND bt IN (161, 407) THEN 1 
						
						WHEN away>= hc AND hc = 3 AND bt IN (162, 409) THEN 1 
						WHEN away= hc AND bt IN (162, 409) THEN 1 
						
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
						WHEN betteam = '1x' AND (home >= away) AND bt IN (24,151,410) THEN 1
						WHEN betteam = '2x' AND (away >= home) AND bt IN (24,151,410) THEN 1
						WHEN betteam = '12' AND (home <> away) AND bt IN (24,151,410) THEN 1
						WHEN betteam = 'h' AND (home > away) AND bt  IN (25, 191,411) THEN 1	--Radar
						WHEN betteam = 'a' AND (away > home) AND bt  IN (25, 191,411) THEN 1	--Radar
						WHEN betteam = 'n' AND home = 0 AND away = 0 AND bt in(26,145,146,188,427) THEN 1					--Radar
						WHEN betteam = 'o' AND (home = 0 or away = 0) AND home + away >=1 AND bt in(26,145,146) THEN 1		--Radar
						WHEN betteam = 'b' AND home + away >= 2 AND home <> 0 AND away <> 0  AND bt in(26,145,146) THEN 1	--Radar
						
						WHEN betteam = 'h' AND (home > 0) AND bt in(170) THEN 1		--Radar
						WHEN betteam = 'a' AND (away > 0) AND bt in(170) THEN 1		--Radar
						WHEN betteam = 'b' AND (home > 0 or away > 0) AND bt in(170) THEN 1		--Radar
						WHEN betteam = 'n' AND (home = 0 AND away = 0)AND bt in(170) THEN 1		--Radar						
						
						WHEN betteam = 'y' AND (home > 0 AND away > 0) AND bt in(188,427) THEN 1	--Radar
						WHEN betteam = 'n' AND (home = 0 AND away = 0)AND bt in(188,427) THEN 1		--Radar
						
						WHEN betteam = 'h' AND away = 0 AND home >= 1 AND bt = 27 THEN 1
						WHEN betteam = 'a' AND home = 0 AND away >= 1 AND bt = 27 THEN 1
						WHEN betteam = '1' AND hc + home - away > 0 AND  bt IN (28, 453) THEN 1 
						WHEN betteam = '2' AND hc + away - home > 0 AND  bt IN (28, 453) THEN 1
						WHEN betteam = 'x' AND hc - (home - away) = 0 AND bt IN (28, 453) THEN 1 
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
								SUM( ( (stake * spositiontaking * CASE WHEN odds<0 THEN -odds ELSE 1 END)) * CASE WHEN odds <0 THEN 1/-CAST(odds AS FLOAT) ELSE odds END ) / SUM( (stake* spositiontaking *CASE WHEN odds<0 THEN -odds ELSE 1 END) ) trueodds,
								SUM( (stake * spositiontaking * CASE WHEN odds<0 THEN -odds ELSE 1 END) ) risk,
								SUM( (b.stake * b.spositiontaking * CASE WHEN b.oddstype = 6 THEN (CASE WHEN b.oddsspread > 0 THEN (CASE WHEN b.odds < 0 THEN 1 ELSE -b.odds END) ELSE 0 END) ELSE 0 END)) MYO_Won,
								SUM( (b.stake * b.spositiontaking * CASE WHEN b.oddstype = 6 THEN (CASE WHEN b.oddsspread < 0 THEN (CASE WHEN b.odds < 0 THEN -b.odds ELSE 1 END) ELSE 0 END) ELSE 0 END)) MYO_Lose,
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
							SUM( (stake * spositiontaking * CASE WHEN odds<0 THEN -odds ELSE 1 END ) * CASE WHEN odds <0 THEN 1/-CAST(odds AS FLOAT) ELSE odds END ) / SUM(stake * spositiontaking * CASE WHEN odds<0 THEN -odds ELSE 1 END) trueodds,
							SUM(stake * spositiontaking * CASE WHEN odds<0 THEN -odds ELSE 1 END) risk,
							0 AS MYO_Won,
							0 AS MYO_Lose,
							0 hc,
							0 hd,
							bettype bt
						FROM @tmpBettrans b 
						WHERE bettype IN (2,12,136,137,138,139,157) --Dom & Radar
						GROUP BY betteam, bettype, hdp1, matchid
					UNION ALL
						SELECT	matchid , betteam,
							SUM( ( (stake * spositiontaking * CASE WHEN odds<0 THEN -odds ELSE 1 END) ) * CASE WHEN odds <0 THEN 1/-CAST(odds AS FLOAT) ELSE odds END ) / SUM( (stake * spositiontaking *CASE WHEN odds<0 THEN -odds ELSE 1 END) ) trueodds,
							SUM( (stake * spositiontaking *CASE WHEN odds<0 THEN -odds ELSE 1 END) ) risk,
							SUM( (b.stake * b.spositiontaking * CASE WHEN b.oddstype = 6 THEN (CASE WHEN b.oddsspread > 0 THEN (CASE WHEN b.odds < 0 THEN 1 ELSE -b.odds END) ELSE 0 END) ELSE 0 END)) MYO_Won,
							SUM( (b.stake * b.spositiontaking * CASE WHEN b.oddstype = 6 THEN (CASE WHEN b.oddsspread < 0 THEN (CASE WHEN b.odds < 0 THEN -b.odds ELSE 1 END) ELSE 0 END) ELSE 0 END)) MYO_Lose,
							hdp1,
							0 hd,
							bettype bt
						FROM @tmpBettrans b 
						WHERE bettype IN (3,8)
						GROUP BY betteam, bettype, hdp1, liveindicator, livehomescore, liveawayscore, matchid
					UNION ALL
						SELECT	matchid, betteam,
							SUM(stake * spositiontaking * (odds-1)) / SUM(stake * spositiontaking) trueodds,
							SUM(stake * spositiontaking) risk,
							0 AS MYO_Won,
							0 AS MYO_Lose,
							hdp1,
							hdp2,
							bettype bt
						FROM @tmpBettrans b
						WHERE bettype IN (4,30,413,414)
						GROUP BY betteam, bettype, hdp1,hdp2, matchid
					UNION ALL
						SELECT	matchid , betteam,
							SUM( stake * spositiontaking * ( odds-1)) / SUM(stake * spositiontaking) trueodds,
							SUM( stake * spositiontaking) risk,
							0 AS MYO_Won,
							0 AS MYO_Lose,
							0 hc,
							0 hd,
							bettype bt
						FROM @tmpBettrans b 
						WHERE bettype IN (5, 15,167) --Radar
						GROUP BY betteam, bettype, matchid
					Union all
						SELECT	matchid, betteam, 
								SUM( stake * spositiontaking * (odds-1)) / SUM(stake * spositiontaking) trueodds,
								SUM(stake * spositiontaking) risk,
								0 AS MYO_Won,
								0 AS MYO_Lose,
								CASE WHEN bettype IN  (159,406,161,407,162,409,179,181,182) THEN cast(right(betteam,1)AS INT) 
									ELSE cast(left(betteam,1)AS INT) END
								AS hc,
								CASE right(betteam,1) 
									WHEN 'r' THEN 999
									ELSE cast(right(betteam,1) AS INT) 
								END AS hd,
								b.bettype bt
						FROM @tmpBettrans b 
						WHERE bettype IN (6,126,131,132,159,406,161,407,162,409,179,181,182) --Dom & Radar
						GROUP BY b.betteam, b.matchid,b.bettype
					UNION ALL
						SELECT	matchid, betteam, 
								SUM( stake * spositiontaking * (odds-1)) / SUM(stake * spositiontaking) trueodds,
								SUM(stake * spositiontaking) risk,
								0 AS MYO_Won,
								0 AS MYO_Lose,
								0 hc,
								0 hd,
								13 bt
						FROM @tmpBettrans b 
						WHERE bettype = 13
						GROUP BY betteam, matchid					
					UNION ALL
						SELECT	matchid, betteam,
							SUM( (stake * spositiontaking * CASE WHEN odds<0 THEN -odds ELSE 1 END ) * CASE WHEN odds <0 THEN 1/-CAST(odds AS FLOAT) ELSE odds END ) / SUM(stake * spositiontaking * CASE WHEN odds<0 THEN -odds ELSE 1 END) trueodds,
							SUM(stake * spositiontaking * CASE WHEN odds<0 THEN -odds ELSE 1 END) risk,
							0 AS MYO_Won,
							0 AS MYO_Lose,
							0 hc,
							0 hd,
							bettype bt
						FROM @tmpBettrans b 
						WHERE bettype IN (20, 21) 
						GROUP BY betteam,bettype, matchid					
					UNION ALL
						SELECT	matchid, betteam, 
							SUM( stake * spositiontaking * (odds-1)) / SUM(stake * spositiontaking) trueodds,
							SUM(stake * spositiontaking) risk,
							0 AS MYO_Won,
							0 AS MYO_Lose,
							0 hc,
							0 hd,
							24 bt
						FROM @tmpBettrans b 
						WHERE bettype IN( 24, 151, 410) 
						GROUP BY betteam, matchid
					UNION ALL
						SELECT	matchid, betteam, 
								SUM( stake * spositiontaking * (odds-1)) / SUM(stake * spositiontaking) trueodds,
								SUM(stake * spositiontaking ) risk,
								0 AS MYO_Won,
								0 AS MYO_Lose,
								0 hc,
								0 hd,
								bettype bt
						FROM @tmpBettrans b 
						WHERE bettype  IN (25,191,411) --Radar
						GROUP BY betteam, matchid,bettype
					UNION ALL
						SELECT	matchid, betteam, 
								SUM( stake * spositiontaking * (odds-1)) / SUM(stake * spositiontaking) trueodds,
								SUM(stake * spositiontaking) risk,
								0 AS MYO_Won,
								0 AS MYO_Lose,
								0 hc,
								0 hd,
								b.bettype bt
						FROM @tmpBettrans b 
						WHERE bettype IN (26,145,146,170,188,427)--Radar
						GROUP BY betteam, matchid,b.bettype
					UNION ALL
						SELECT	matchid, betteam, 
								SUM( stake * spositiontaking * (odds-1)) / SUM(stake * spositiontaking) trueodds,
								SUM(stake * spositiontaking) risk,
								0 AS MYO_Won,
								0 AS MYO_Lose,
								0 hc,
								0 hd,
								27 bt
						FROM @tmpBettrans b 
						WHERE bettype = 27
						GROUP BY betteam, matchid 
					UNION ALL
						SELECT	matchid, betteam, 
								SUM( stake * spositiontaking * (odds-1)) / SUM(stake * spositiontaking) trueodds,
								SUM(stake * spositiontaking) risk,
								0 AS MYO_Won,
								0 AS MYO_Lose,
								CASE WHEN betteam = '1' THEN hdp2-hdp1
									 ELSE hdp1-hdp2	 
								END hc,
								0 hd,
								bettype bt
						FROM @tmpBettrans b 
						WHERE bettype IN (28, 453)
						GROUP BY betteam, hdp1, hdp2, matchid, bettype
					UNION ALL
						SELECT	matchid , betteam,
							SUM( stake * spositiontaking * ( odds-1)) / SUM(stake * spositiontaking) trueodds,
							SUM( stake * spositiontaking) risk,
							0 AS MYO_Won,
							0 AS MYO_Lose,
							0 hc,
							0 hd,
							bettype bt
						FROM @tmpBettrans b 
						WHERE bettype IN (121,122,123)
						GROUP BY betteam, bettype, matchid						
					)r
				)u
			LEFT JOIN @hafltimeBettypes tmpBetType ON u.bt =  tmpBetType.BetType
			GROUP BY home, away, matchid, CASE WHEN  tmpBetType.BetType IS NOT NULL THEN 1 ELSE 0 END
		
	SELECT matchid	
		,home	
		,away	
		,SUM(CASE WHEN isHT = 1 THEN total ELSE NULL END) HT
		,SUM(CASE WHEN isHT = 1 THEN NULL ELSE total END) FT
	FROM #ScoreMap_Super
	GROUP BY matchid, home, away
	ORDER BY matchid ,away, home
		
	SELECT matchid, homeid, awayid
	FROM match WITH(NOLOCK)
	WHERE eventstatus <> 'completed'
		AND matchid IN (SELECT val FROM strSplit(@matchids,','))

	DROP TABLE #ScoreMap_Super
END
GO