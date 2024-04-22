/*<info serverAlias="DBBOF-bodb02" executers="wsv_alp,wsv_alpv" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Age_TotalBets_ChatBot_SelDetail] 	
	@CustId		INT = 1176086, --recommend
	@MatchId	INT = 83524706,
	@IsApplyPT	BIT = 1
AS
/*
	Created by: 20240408@Bobby
	Task : Implement new totalbet chatbot [RedmineID: #202421]
	DB: DBBOF/bodb02
	Revisions:
		- 20240408@Bobby: Initialize SPs

*/
BEGIN
	SET NOCOUNT ON;

	--- SB only
	DECLARE @srecommend	INT
		,@mrecommend	INT
		,@recommend		INT
		,@roleId		TINYINT
		,@eventId		INT;

	DROP TABLE IF EXISTS #eventTotalBet;
	CREATE TABLE #eventTotalBet (
		bettype		INT
		,hdp		SMALLMONEY
		,teamhdp	TINYINT
		,homeTO		MONEY
		,awayTO		MONEY
		,drawTO		MONEY
		,overTO		MONEY
		,underTO	MONEY
		,totalTO	MONEY
		,maxtransId	BIGINT
		,UNIQUE CLUSTERED (bettype, hdp, teamhdp)
	);

	SELECT TOP(1)
		@srecommend		= srecommend
		,@mrecommend	= mrecommend
		,@recommend		= recommend
		,@roleId		= roleId
	FROM dbo.Customer WITH(NOLOCK)
	WHERE custid = @CustId;

	SELECT @eventId		= @MatchId
		,@IsApplyPT 	= ISNULL(@IsApplyPT, 1);

	--TODO: match totalbets detail
	WITH CTE_bettrans AS (
		SELECT bettype, betteam, hdp1, hdp2, SUM(actual_stake * IIF(@IsApplyPT = 1, apositiontaking, 1)) AS stakeTO
		FROM dbo.bettrans b WITH(NOLOCK) 
		WHERE b.statusId IN (0, 1) 
			AND b.matchid = @eventId
			AND b.recommend = @recommend
			AND @roleId = 2
		GROUP BY bettype, betteam, hdp1, hdp2
		UNION ALL
		SELECT bettype, betteam, hdp1, hdp2, SUM(actual_stake * IIF(@IsApplyPT = 1, mpositiontaking, 1)) AS stakeTO
		FROM dbo.bettrans b WITH(NOLOCK) 
		WHERE b.statusId IN (0, 1) 
			AND b.matchid = @eventId
			AND b.mrecommend = @mrecommend
			AND @roleId = 3
		GROUP BY bettype, betteam, hdp1, hdp2
		UNION ALL
		SELECT bettype, betteam, hdp1, hdp2, SUM(actual_stake * IIF(@IsApplyPT = 1, spositiontaking, 1)) AS stakeTO
		FROM dbo.bettrans b WITH(NOLOCK) 
		WHERE b.statusId IN (0, 1) 
			AND b.matchid = @eventId
			AND b.srecommend = @srecommend
			AND @roleId = 4
		GROUP BY bettype, betteam, hdp1, hdp2
	)
	INSERT INTO #eventTotalBet (bettype, hdp, teamhdp, homeTO, awayTO, drawTO, overTO, underTO, totalTO)
	SELECT bettype, ISNULL(hdp, 0) AS hdp, ISNULL(teamhdp, 0) AS teamhdp
		,SUM(homeTO) AS homeTO, SUM(awayTO) AS awayTO, SUM(drawTO) AS drawTO
		,SUM(overTO) AS overTO, SUM(underTO) AS underTO
		,SUM(totalTO) AS totalTO
	FROM (
		SELECT bettype, 
			ck.teamhdp AS teamhdp,
			ck.hdp AS hdp,
			SUM(IIF(b.bettype IN(1,7,5,15) AND b.betteam IN('h', '1'), b.stakeTO, 0)) AS homeTO,
			SUM(IIF(b.bettype IN(1,7,5,15) AND b.betteam IN('a', '2'), b.stakeTO, 0)) AS awayTO,
			SUM(IIF(b.bettype IN(5,15) AND b.betteam IN('x'), b.stakeTO, 0)) AS drawTO,
			SUM(IIF(b.bettype IN(3,8) AND b.betteam IN('h'), b.stakeTO, 0)) AS overTO,
			SUM(IIF(b.bettype IN(3,8) AND b.betteam IN('a'), b.stakeTO, 0)) AS underTO,
			COUNT(1) AS BetCount,
			SUM(b.stakeTO) AS totalTO
		FROM CTE_bettrans b
		OUTER APPLY (
			SELECT MAX(bt.teamhdp) AS teamhdp, MAX(bt.hdp) AS hdp
			FROM (
				SELECT teamhdp, hdp
				FROM (VALUES(IIF(b.hdp1 <> 0, 1, 0), b.hdp1),(IIF(b.hdp2 <> 0, 2, 0), b.hdp2)) AS t (teamhdp, hdp)
				WHERE b.bettype IN (1, 7)
				UNION ALL
				SELECT teamhdp, hdp
				FROM (VALUES(0, b.hdp1)) AS t (teamhdp, hdp) 
				WHERE b.bettype IN (3, 8)
			) AS bt
		) AS ck
		GROUP BY bettype
			,ck.teamhdp
			,ck.hdp
	) AS tb
	GROUP BY bettype, hdp, teamhdp;

	--TODO: get max transid of match
	DECLARE @maxtransid BIGINT;
	SELECT @maxtransid = MAX(transid)
	FROM dbo.bettrans b WITH(NOLOCK) 
	WHERE b.matchid = @eventId 
		AND b.statusID IN (0, 1)

	UPDATE m
	SET m.maxtransid = @maxtransid
	FROM #eventTotalBet m;

	--TODO: match info
	WITH CTE_matchTO AS (
		SELECT @eventId			AS matchid
			,MAX(maxtransId)	AS maxtransId
			,SUM(totalTO)		AS totalTO
		FROM #eventTotalBet
	)
	SELECT l.leagueid, l.leagueCode, m.matchid, m.matchcode, m.homeid, m.awayid, m.IsNeutral, m.showtime, m.GlobalShowTime
		, b.livehomescore, b.liveawayscore
		, CASE 
			WHEN m.showtime LIKE '%LIVE%' AND b.liveindicator = 0 THEN 1
			WHEN b.liveindicator = 1 THEN 2
			ELSE b.liveindicator 
		END AS liveindicator
		,cte.totalTO
	FROM CTE_matchTO cte
	INNER JOIN dbo.match m WITH(NOLOCK) ON m.matchid = cte.matchid
	INNER JOIN dbo.League l WITH(NOLOCK) ON l.leagueid = m.leagueid
	INNER JOIN dbo.bettrans b WITH(NOLOCK) ON b.transid = cte.maxtransid
	WHERE m.eventstatus	= 'running'

	--TODO: sum subtotal
	SELECT 
		CASE WHEN tb.bettype IN (1,7,3,8,5,15) THEN tb.bettype ELSE 0 END AS bettype
		,SUM(totalTO) AS totalTO
	FROM #eventTotalBet tb
	GROUP BY
		CASE WHEN tb.bettype IN (1,7,3,8,5,15) THEN tb.bettype ELSE 0 END
		,CASE 
			WHEN tb.bettype IN (1,7) THEN 1 
			WHEN tb.bettype IN (3,8) THEN 3
			WHEN tb.bettype IN (5,15) THEN 5
			ELSE 99 
		END
	ORDER BY 
		CASE 
			WHEN tb.bettype IN (1,7) THEN 1 
			WHEN tb.bettype IN (3,8) THEN 3
			WHEN tb.bettype IN (5,15) THEN 5
			ELSE 99 
		END, bettype;
	
	--TODO: totalbet detail
	SELECT bettype, hdp, teamhdp, homeTO, awayTO, drawTO, overTO, underTO
	FROM #eventTotalBet tb
	WHERE tb.bettype IN (1,7,3,8,5,15)
	ORDER BY 
		CASE 
			WHEN tb.bettype IN (1,7) THEN 1 
			WHEN tb.bettype IN (3,8) THEN 3
			WHEN tb.bettype IN (5,15) THEN 5
			ELSE 99 
		END
		, bettype, hdp, teamhdp;
END
GO