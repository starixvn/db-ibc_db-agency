/*<info serverAlias="DBBOF-bodb02" executers="wsv_alp,wsv_alpv" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Age_TotalBets_ChatBot_SelEvent] 	
	@CustId		INT = 1176086, --recommend
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
		,@ckIsTest		BIT;
		
	SELECT TOP(1)
		@srecommend		= srecommend
		,@mrecommend	= mrecommend
		,@recommend		= recommend
		,@roleId		= roleId
	FROM dbo.Customer WITH(NOLOCK)
	WHERE custid = @CustId;

	SELECT @ckIsTest	= 1
		,@IsApplyPT 	= ISNULL(@IsApplyPT, 1);

	DROP TABLE IF EXISTS #matchTO;
	CREATE TABLE #matchTO (matchid INT PRIMARY KEY, stakeTO MONEY, maxtransid BIGINT);

	INSERT INTO #matchTO(matchid, stakeTO)
	SELECT b.matchid, b.stakeTO AS Turnover
	FROM (
		SELECT matchid, SUM(actual_stake * IIF(@IsApplyPT = 1, apositiontaking, 1)) AS stakeTO
		FROM dbo.bettrans b WITH(NOLOCK) 
		WHERE statusID IN (0, 1)
			AND b.recommend = @recommend
			AND @roleId = 2
		GROUP BY matchid
		UNION ALL
		SELECT matchid, SUM(actual_stake * IIF(@IsApplyPT = 1, mpositiontaking, 1)) AS stakeTO
		FROM dbo.bettrans b WITH(NOLOCK) 
		WHERE statusID IN (0, 1)
			AND b.mrecommend = @mrecommend
			AND @roleId = 3
		GROUP BY matchid
		UNION ALL
		SELECT matchid, SUM(actual_stake * IIF(@IsApplyPT = 1, spositiontaking, 1)) AS stakeTO
		FROM dbo.bettrans b WITH(NOLOCK) 
		WHERE statusID IN (0, 1)
			AND b.srecommend = @srecommend
			AND @roleId = 4
		GROUP BY matchid
	) AS b
	WHERE b.stakeTO > 0;

	--TODO: get max transid of match
	UPDATE m
	SET m.maxtransid = ck.maxtransid
	FROM #matchTO m
	CROSS APPLY (
		SELECT MAX(transid) AS maxtransid
		FROM dbo.bettrans b WITH(NOLOCK) 
		WHERE b.matchid = m.matchid AND b.statusID IN (0, 1)
	) AS ck;

	--TODO: return output
	SELECT TOP(10) l.leagueid, l.leagueCode, m.matchid, m.matchcode, m.homeid, m.awayid, m.IsNeutral, m.showtime, m.GlobalShowTime
		, b.livehomescore, b.liveawayscore, tmp.stakeTO AS Turnover
		, CASE 
			WHEN m.showtime LIKE '%LIVE%' AND b.liveindicator = 0 THEN 1
			WHEN b.liveindicator = 1 THEN 2
			ELSE b.liveindicator 
		END AS liveindicator
	FROM #matchTO tmp
	INNER JOIN dbo.match m WITH(NOLOCK) ON m.matchid = tmp.matchid
	INNER JOIN dbo.League l WITH(NOLOCK) ON l.leagueid = m.leagueid
	INNER JOIN dbo.bettrans b WITH(NOLOCK) ON b.transid = tmp.maxtransid
	WHERE l.sporttype		= 1
		AND m.eventstatus	= 'running'
		--AND m.eventstatus NOT IN ('completed','Internal')
		AND l.IsActive		= 1
		--- filter major leagues
		AND l.IsTest		= IIF(@ckIsTest = 1, l.IsTest, @ckIsTest)
		AND l.LeagueGroupID  NOT IN (113 ) -- Exclude Saba PinGoal
		AND l.leagueid	<> 28412 -- Arsenal & Over 2.5
		AND leaguename NOT LIKE '%special%'
		AND leaguename NOT LIKE '%specific%'
		AND leaguename NOT LIKE '%corner%'
		AND leaguename NOT LIKE '%booking%'
		AND leaguename NOT LIKE '%winner%'
		AND leaguename NOT LIKE '%goal%'
		AND leaguename NOT LIKE '%team%'
		AND leaguename NOT LIKE '%injury%'
		AND leaguename NOT LIKE 'z*%'
		AND leaguename NOT LIKE 'z-%'
		AND leaguename NOT LIKE '%half%'
		AND leaguename NOT LIKE '%advance%'
		AND leaguename NOT LIKE '%reach%'
		AND leaguename NOT LIKE '%?%'
		AND leaguename NOT LIKE '%final%'
		AND leaguename NOT LIKE '%promot%'
		AND leaguename NOT LIKE '%method%'
		AND leaguename NOT LIKE '%relegat%'
		AND leaguename NOT LIKE '%double chance%'
		AND leaguename NOT LIKE '%hockey%'
		AND leaguename NOT LIKE '%yellow card%'
		AND leaguename NOT LIKE '%red card%'
		AND leaguename NOT LIKE '%winning%'
		AND leaguename NOT LIKE '%scor%'
		AND leaguename NOT LIKE '%penalty%'
		AND leaguename NOT LIKE '%fantasy%'
		AND leaguename NOT LIKE '%half%'
		AND leaguename NOT LIKE '%Substitution%'
		AND leaguename NOT LIKE '%offside%'
		AND leaguename NOT LIKE '%free kick%'
		AND leaguename NOT LIKE '%throw in%'
		AND leaguename NOT LIKE '%extra%'
		AND leaguename NOT LIKE '%rock bottom%'
		AND leaguename NOT LIKE '%post split%'
		AND leaguename NOT LIKE '%no use%'
	ORDER BY tmp.stakeTO DESC
END
GO