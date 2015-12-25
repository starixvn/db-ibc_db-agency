Use bodb02
GO

--ALTER PROCEDURE [dbo].[Age_TotalBetsForeCast_LiveData] (
DECLARE
	@CustId				INT	= 0
	,@MatchList			VARCHAR(1000) = NULL
	,@TrackingChange	XML	 = NULL
--) AS
/*	
Created: 20151216@Bobby
Task: Alpha site - New total bets and forecast events filtering
DB: DBAGE/BODB02
Revision:
	- 20151216@Bobby: Initial
	
Parameter's Explanation:
			
*/
BEGIN
	SET NOCOUNT ON

	select @custid = 14182763--52466--14182461--19000970 
		,@MatchList = '15929910,15929835,16047677,15929837'

	DECLARE @timeNow	DATETIME
		,@roleId		TINYINT
		,@sporttype		SMALLINT

	CREATE TABLE #custRecommend (
		custid		INT
	)
	
	CREATE TABLE #bettypes ( bettype SMALLINT )
	
	CREATE TABLE #matchEvent (
		matchid			INT
	)

	INSERT INTO #bettypes
	SELECT bettype
	FROM ( 
		VALUES 
		(1)		--Handicap
		, (7)	-- 1H Handicap
		, (3)	-- Over/Under
		, (8)	-- 1H Over/Under
		, (5)	-- FT.1X2
		, (15)	-- 1H 1X2
	) AS T(bettype)
	
	SET @sporttype	= 1 
	
	INSERT INTO #matchEvent
	SELECT t.Val
	FROM [dbo].[Age_f_SplitString] (@matchList, ',') AS t
	
	SELECT TOP 1
		@roleId			= roleId
		, @sporttype	= 1 
	FROM dbo.Customer c WITH (NOLOCK)
	WHERE c.custid = @custid
	
	IF(ISNULL(@roleId, 0) <= 1) RETURN
		
	--agent
	INSERT INTO #custRecommend
	SELECT @CustId
	WHERE @roleId	= 2

	--master
	UNION ALL
	SELECT cr.custId
	FROM dbo.Customer cr WITH (NOLOCK)
	WHERE cr.mrecommend		= @custid
		AND cr.roleid		= 2
		AND @roleId			= 3

	--super
	UNION ALL
	SELECT cr.custId
	FROM dbo.Customer cr WITH (NOLOCK)
	WHERE cr.srecommend		= @custid
		AND cr.roleid		= 2
		AND @roleId			= 4
	
	--SELECT b.matchid
	--	, b.bettype
	--	, b.betcount
	--	, b.WinLost
	--	, b.WinLost2
	--	, b.WinLost3
	--FROM #bettypes bt
	--CROSS APPLY (
	SELECT m.matchid
			, m.livehomescore
			, m.liveawayscore
			, b.bettype
			, b.betteam
			, COUNT(1) 		AS betcount
			, SUM(b.stake) 	AS Turnover
			, SUM(
				CASE
					WHEN mo.modds >  0.25 	THEN stake * (case when b.odds<0 then 1 else b.odds end) * -pt.positiontaking
					WHEN mo.modds =  0.25 	THEN stake * (case when b.odds<0 then 1 else b.odds end) * -pt.positiontaking * 0.5
					WHEN mo.modds =  0    	THEN 0
					WHEN mo.modds = -0.25 	THEN actual_stake * pt.positiontaking * 0.5
					WHEN mo.modds < -0.25 	THEN actual_stake * pt.positiontaking
				END
			) AS FWL_CurrentScore
			, SUM(
				CASE
					WHEN ISNULL(mo.modds2, mo.modds) >  0.25 	THEN stake * (case when b.odds<0 then 1 else b.odds end) * -pt.positiontaking
					WHEN ISNULL(mo.modds2, mo.modds) =  0.25 	THEN stake * (case when b.odds<0 then 1 else b.odds end) * -pt.positiontaking * 0.5
					WHEN ISNULL(mo.modds2, mo.modds) =  0    	THEN 0
					WHEN ISNULL(mo.modds2, mo.modds) = -0.25 	THEN actual_stake * pt.positiontaking * 0.5
					WHEN ISNULL(mo.modds2, mo.modds) < -0.25 	THEN actual_stake * pt.positiontaking
				END
			) AS FWL_HomeScore1
			, SUM(
				CASE
					WHEN ISNULL(mo.modds3, mo.modds) >  0.25 	THEN stake * (case when b.odds<0 then 1 else b.odds end) * -pt.positiontaking
					WHEN ISNULL(mo.modds3, mo.modds) =  0.25 	THEN stake * (case when b.odds<0 then 1 else b.odds end) * -pt.positiontaking * 0.5
					WHEN ISNULL(mo.modds3, mo.modds) =  0    	THEN 0
					WHEN ISNULL(mo.modds3, mo.modds) = -0.25 	THEN actual_stake * pt.positiontaking * 0.5
					WHEN ISNULL(mo.modds3, mo.modds) < -0.25 	THEN actual_stake * pt.positiontaking
				END
			) AS FWL_AwayScore1
		FROM dbo.bettrans b WITH(NOLOCK)
			INNER JOIN #custRecommend c 
			ON b.recommend = c.custId
			INNER JOIN #matchEvent mt
			ON b.matchid = mt.matchid
			INNER JOIN dbo.match m
			ON m.matchid = mt.matchid
			CROSS APPLY (
				select 
				CASE betteam
					--WHEN N'h' THEN (hdp2 - hdp1) + (@fth - livehomescore) - (@fta - liveawayscore)
					WHEN N'h' THEN (b.hdp2 - b.hdp1) + (m.livehomescore - b.livehomescore) - (m.liveawayscore - b.liveawayscore)
					--WHEN N'a' THEN (hdp1 - hdp2) - (@fth - livehomescore) + (@fta - liveawayscore)
					WHEN N'a' THEN (b.hdp1 - b.hdp2) - (m.livehomescore - b.livehomescore) + (m.liveawayscore - b.liveawayscore)
                END  AS modds
				,CASE betteam
					WHEN N'h' THEN (b.hdp2 - b.hdp1) + ((m.livehomescore+1) - b.livehomescore) - (m.liveawayscore - b.liveawayscore)
					WHEN N'a' THEN (b.hdp1 - b.hdp2) - ((m.livehomescore+1) - b.livehomescore) + (m.liveawayscore - b.liveawayscore)
                END  AS modds2
				,CASE betteam
					WHEN N'h' THEN (b.hdp2 - b.hdp1) + (m.livehomescore - b.livehomescore) - ((m.liveawayscore+1) - b.liveawayscore)
					WHEN N'a' THEN (b.hdp1 - b.hdp2) - (m.livehomescore - b.livehomescore) + ((m.liveawayscore+1) - b.liveawayscore)
                END  AS modds3
			) as mo
			CROSS APPLY (
				SELECT case 
					when @roleid = 2 THEN b.apositiontaking
					when @roleid = 3 THEN b.mpositiontaking
					when @roleid = 4 THEN b.spositiontaking
					Else 0
				END AS positiontaking
			) as pt
			
		WHERE b.bettype IN (1, 7)
			AND b.statusId IN (0,1)
		GROUP BY 
			m.matchid
			, m.livehomescore
			, m.liveawayscore
			, b.bettype
			, b.betteam
	--) AS b
	--WHERE bt.bettype IN (1, 7)
	
	/* Start Over/Under Calculation */
	SELECT m.matchid
		, (m.livehomescore + m.liveawayscore) AS totalgoal
		, b.bettype
		, b.betteam
		, b.hdp1
		, b.stake
		, b.actual_stake
		, b.odds
		, case 
			when @roleid = 2 THEN b.apositiontaking
			when @roleid = 3 THEN b.mpositiontaking
			when @roleid = 4 THEN b.spositiontaking
			Else 0
		END AS positiontaking
	INTO #OUDataRaw
	FROM dbo.bettrans b WITH(NOLOCK)
		INNER JOIN #custRecommend c 
		ON b.recommend = c.custId
		INNER JOIN #matchEvent mt
		ON b.matchid = mt.matchid
		INNER JOIN dbo.match m
		ON m.matchid = mt.matchid
			
	WHERE b.bettype IN (3, 8)
		AND b.statusId IN (0,1)
	
	CREATE TABLE #EventCurrentScore (matchid INT, score TINYINT, Idx INT IDENTITY(1,1))
	
	SELECT
		m.matchid
		, MAX(o.hdp1) AS MaxScore
	INTO #EventMaxScore
	FROM dbo.odds o WITH (NOLOCK)
	INNER JOIN #matchEvent m
		ON o.matchid = m.matchid
	WHERE o.bettype IN (3, 8)
	GROUP BY m.matchid
	
	INSERT INTO #EventCurrentScore(matchid, score)
	SELECT DISTINCT
		r.matchid
		, (r.livehomescore + r.liveawayscore) AS CurrentScore 
	FROM #OUDataRaw r
	
	DECLARE @OUCountIdx INT
		,@OUCountMatchIdx INT
		,@scoreOne		TINYINT
		,@scoreTwo		TINYINT
		,@wlCountIdx	MONEY
		,@matchVal		INT
		,@scoreMatchMax	TINYINT
		,@predictCount	TINYINT
	
	--INSERT INTO #matchScoreDiff
	SELECT matchid
		, totalgoal
		, bettype
		, SUM(
			CASE WHEN betteam = N'h' THEN 
				CASE
					WHEN mo.modds >  0.25 	THEN stake * (case when odds<0 then 1 else odds end) * -positiontaking
					WHEN mo.modds =  0.25 	THEN stake * (case when b.odds<0 then 1 else b.odds end) * -positiontaking * 0.5
					WHEN mo.modds =  0    	THEN 0
					WHEN mo.modds = -0.25 	THEN actual_stake * positiontaking * 0.5
					WHEN mo.modds < -0.25 	THEN actual_stake * positiontaking
				END 
			ELSE 0 END
		) AS homewinlost
		, SUM(
			CASE WHEN betteam = N'a' THEN 
				CASE
					WHEN mo.modds >  0.25 	THEN stake * (case when odds<0 then 1 else odds end) * -positiontaking
					WHEN mo.modds =  0.25 	THEN stake * (case when b.odds<0 then 1 else b.odds end) * -positiontaking * 0.5
					WHEN mo.modds =  0    	THEN 0
					WHEN mo.modds = -0.25 	THEN actual_stake * positiontaking * 0.5
					WHEN mo.modds < -0.25 	THEN actual_stake * positiontaking
				END 
			ELSE 0 END
		) AS awaywinlost
	INTO #matchScoreDiff
	FROM #OUDataRaw r
	CROSS APPLY (
		SELECT 
			CASE 
				WHEN betteam = N'h' THEN totalgoal - hdp1
				WHEN betteam = N'a' THEN hdp1 - totalgoal
				ELSE -1
			END AS modds
	) AS mo
	GROUP BY matchid, bettype
		
	WHILE (EXISTS SELECT 1 FROM #EventCurrentScore WHERE Idx = @OUCountIdx)
	BEGIN
		SELECT @matchVal 		= matchid 
			, @OUCountMatchIdx 	= totalgoal
		FROM #EventCurrentScore 
		WHERE Idx = @OUCountIdx
		
		SELECT @scoreMatchMax 	= MaxScore 
		FROM #EventMaxScore 
		WHERE matchid = @matchVal
		
		IF(@scoreMatchMax > 0)
		BEGIN
			SET @predictCount = 1
			WHILE (@OUCountMatchIdx <= @scoreMatchMax)
			BEGIN
				;WITH CTE_matchCoreDiff AS (
					SELECT matchid, (totalgoal + @predictCount) AS totalgoal
						, bettype
						, SUM(
							CASE WHEN betteam = N'h' THEN 
								CASE
									WHEN mo.modds >  0.25 	THEN stake * (case when odds<0 then 1 else odds end) * -positiontaking
									WHEN mo.modds =  0.25 	THEN stake * (case when b.odds<0 then 1 else b.odds end) * -positiontaking * 0.5
									WHEN mo.modds =  0    	THEN 0
									WHEN mo.modds = -0.25 	THEN actual_stake * positiontaking * 0.5
									WHEN mo.modds < -0.25 	THEN actual_stake * positiontaking
								END 
							ELSE 0 END
						) AS homewinlost
						, SUM(
							CASE WHEN betteam = N'a' THEN 
								CASE
									WHEN mo.modds >  0.25 	THEN stake * (case when odds<0 then 1 else odds end) * -positiontaking
									WHEN mo.modds =  0.25 	THEN stake * (case when b.odds<0 then 1 else b.odds end) * -positiontaking * 0.5
									WHEN mo.modds =  0    	THEN 0
									WHEN mo.modds = -0.25 	THEN actual_stake * positiontaking * 0.5
									WHEN mo.modds < -0.25 	THEN actual_stake * positiontaking
								END 
							ELSE 0 END
						) AS awaywinlost
					WHERE matchid = @matchVal
					CROSS APPLY (
						SELECT 
							CASE 
								WHEN betteam = N'h' THEN (totalgoal + @predictCount) - hdp1
								WHEN betteam = N'a' THEN hdp1 - (totalgoal + @predictCount)
								ELSE -1
							END AS modds
					) AS mo
					GROUP BY matchid, bettype
				)
				INSERT INTO #matchScoreDiff
				SELECT matchid,totalgoal
					, bettype
					, homewinlost
					, awaywinlost
				FROM #matchScoreDiff mdiff
				INNER JOIN CTE_matchCoreDiff cdiff 
				ON mdiff.matchid = cdiff.matchid
					AND mdiff.bettype = cdiff.bettype
				WHERE mdiff.matchid = @matchVal
					AND (mdiff.homewinlost <> cdiff.homewinlost
						OR mdiff.awaywinlost <> cdiff.awaywinlost
					)
					
				SELECT @OUCountMatchIdx += 1
					, @predictCount 	+= 1
			END
		END
		
		
		SET @OUCountIdx += 1
	END
	
	
	
	SELECT m.matchid
			, m.livehomescore
			, m.liveawayscore
			, b.bettype
			, b.betteam
			, COUNT(1) 		AS betcount
			, SUM(b.stake) 	AS Turnover
			, SUM(
				CASE
					WHEN mo.modds >  0.25 	THEN stake * (case when b.odds<0 then 1 else b.odds end) * -pt.positiontaking
					WHEN mo.modds =  0.25 	THEN stake * (case when b.odds<0 then 1 else b.odds end) * -pt.positiontaking * 0.5
					WHEN mo.modds =  0    	THEN 0
					WHEN mo.modds = -0.25 	THEN actual_stake * pt.positiontaking * 0.5
					WHEN mo.modds < -0.25 	THEN actual_stake * pt.positiontaking
				END
			) AS [Current Goal]
			, SUM(
				CASE
					WHEN ISNULL(mo.modds2, mo.modds) >  0.25 	THEN stake * (case when b.odds<0 then 1 else b.odds end) * -pt.positiontaking
					WHEN ISNULL(mo.modds2, mo.modds) =  0.25 	THEN stake * (case when b.odds<0 then 1 else b.odds end) * -pt.positiontaking * 0.5
					WHEN ISNULL(mo.modds2, mo.modds) =  0    	THEN 0
					WHEN ISNULL(mo.modds2, mo.modds) = -0.25 	THEN actual_stake * pt.positiontaking * 0.5
					WHEN ISNULL(mo.modds2, mo.modds) < -0.25 	THEN actual_stake * pt.positiontaking
				END
			) AS [Current Goals+1]
			, SUM(
				CASE
					WHEN ISNULL(mo.modds3, mo.modds) >  0.25 	THEN stake * (case when b.odds<0 then 1 else b.odds end) * -pt.positiontaking
					WHEN ISNULL(mo.modds3, mo.modds) =  0.25 	THEN stake * (case when b.odds<0 then 1 else b.odds end) * -pt.positiontaking * 0.5
					WHEN ISNULL(mo.modds3, mo.modds) =  0    	THEN 0
					WHEN ISNULL(mo.modds3, mo.modds) = -0.25 	THEN actual_stake * pt.positiontaking * 0.5
					WHEN ISNULL(mo.modds3, mo.modds) < -0.25 	THEN actual_stake * pt.positiontaking
				END
			) AS [Current Goals+2]
		FROM dbo.bettrans b WITH(NOLOCK)
			INNER JOIN #custRecommend c 
			ON b.recommend = c.custId
			INNER JOIN #matchEvent mt
			ON b.matchid = mt.matchid
			INNER JOIN dbo.match m
			ON m.matchid = mt.matchid
			CROSS APPLY (
				select 
					CASE 
						--WHEN betteam = N'h' THEN @totalgoal - hdp1
						WHEN betteam = N'h' THEN (m.livehomescore + m.liveawayscore)-b.hdp1
						--WHEN betteam = N'a' THEN hdp1 - @totalgoal
						WHEN betteam = N'a' THEN b.hdp1-(m.livehomescore + m.liveawayscore)
						ELSE -1
					END AS modds
					,CASE 
						--WHEN betteam = N'h' THEN @totalgoal - hdp1
						WHEN betteam = N'h' THEN ((m.livehomescore + m.liveawayscore) + 1) - b.hdp1
						--WHEN betteam = N'a' THEN hdp1 - @totalgoal
						WHEN betteam = N'a' THEN b.hdp1-((m.livehomescore + m.liveawayscore) + 1)
						ELSE -1
					END  AS modds2
					,CASE 
						--WHEN betteam = N'h' THEN @totalgoal - hdp1
						WHEN betteam = N'h' THEN ((m.livehomescore + m.liveawayscore) + 2) - b.hdp1
						--WHEN betteam = N'a' THEN hdp1 - @totalgoal
						WHEN betteam = N'a' THEN b.hdp1-((m.livehomescore + m.liveawayscore) + 2)
						ELSE -1
					END  AS modds3
			) as mo
			CROSS APPLY (
				SELECT case 
					when @roleid = 2 THEN b.apositiontaking
					when @roleid = 3 THEN b.mpositiontaking
					when @roleid = 4 THEN b.spositiontaking
					Else 0
				END AS positiontaking
			) as pt
			
		WHERE b.bettype IN (3, 8)
			AND b.statusId IN (0,1)
		GROUP BY 
			m.matchid
			, m.livehomescore
			, m.liveawayscore
			, b.bettype
			, b.betteam
	/* End */
	
	SELECT m.matchid
			, m.livehomescore
			, m.liveawayscore
			, b.bettype
			, b.betteam
			, COUNT(1) 		AS betcount
			, SUM(b.stake) 	AS Turnover
			, SUM (
				CASE 
					WHEN b.betteam = '1' THEN stake * (CASE WHEN b.odds<0 THEN 1 ELSE b.odds END) * -pt.positiontaking 
					ELSE 0 
				END
			) AS HomeWL
			, SUM(
				CASE 
					WHEN b.betteam = '2' THEN stake * (CASE WHEN b.odds<0 THEN 1 ELSE b.odds END) * -pt.positiontaking 
					ELSE 0 
				END
			) AS AwayWL
			, SUM(
				CASE 
					WHEN b.betteam = 'X' THEN stake * (CASE WHEN b.odds<0 THEN 1 ELSE b.odds END) * -pt.positiontaking 
					ELSE 0 
				END
			) AS DrawWL
		FROM dbo.bettrans b WITH(NOLOCK)
			INNER JOIN #custRecommend c 
			ON b.recommend = c.custId
			INNER JOIN #matchEvent mt
			ON b.matchid = mt.matchid
			INNER JOIN dbo.match m
			ON m.matchid = mt.matchid
			CROSS APPLY (
				SELECT case 
					when @roleid = 2 THEN b.apositiontaking
					when @roleid = 3 THEN b.mpositiontaking
					when @roleid = 4 THEN b.spositiontaking
					Else 0
				END AS positiontaking
			) as pt
			
		WHERE b.bettype IN (5, 15)
			AND b.statusId IN (0,1)
		GROUP BY 
			m.matchid
			, m.livehomescore
			, m.liveawayscore
			, b.bettype
			, b.betteam

	DROP TABLE #bettypes
	DROP TABLE #custRecommend
	DROP TABLE #matchEvent

	RETURN

	RETURN
END
GO
