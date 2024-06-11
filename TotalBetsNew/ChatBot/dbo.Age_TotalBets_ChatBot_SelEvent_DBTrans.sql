/*<info serverAlias="DBCTG-bodb02" executers="wsv_alp,wsv_alpv" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Age_TotalBets_ChatBot_SelEvent_DBTrans] 	
	@CustId		INT, --SMA
	@IsApplyPT	BIT = 1
AS
/*
	Created by: 20240611@Bobby
	Task : Switch DBTrans [RedmineID: #206369]
	DB: DBCTG/bodb02
	Revisions:
		- 20240611@Bobby: Initialize SPs

*/
BEGIN
	SET NOCOUNT ON;

	--- SB only
	DECLARE @srecommend	INT
		,@mrecommend	INT
		,@recommend		INT
		,@roleId		TINYINT;
		
	SELECT TOP(1)
		@srecommend		= srecommend
		,@mrecommend	= mrecommend
		,@recommend		= recommend
		,@roleId		= roleId
	FROM dbo.Customer WITH(NOLOCK)
	WHERE custid = @CustId;

	SELECT @IsApplyPT 	= ISNULL(@IsApplyPT, 1);

	SELECT TOP(10) l.leagueid, l.leagueCode, m.matchid, m.matchcode, m.homeid, m.awayid, m.IsNeutral, m.showtime, m.GlobalShowTime
		, ISNULL(m.livehomescore, 0) AS livehomescore, ISNULL(m.liveawayscore, 0) AS liveawayscore, tmp.stakeTO AS Turnover
		, CASE 
			WHEN m.showtime LIKE '%LIVE%' AND ck.isLive = 0 THEN 1
			WHEN ck.isLive = 1 THEN 2
			ELSE ck.isLive 
		END AS liveindicator
	FROM (
		SELECT matchid, SUM(actual_stake * IIF(@IsApplyPT = 1, apositiontaking, 1)) AS stakeTO
		FROM dbo.bettrans b WITH(NOLOCK) 
		WHERE statusID IN (0, 1) AND SiteDBGroupID IN (3)
			AND b.recommend = @recommend
			AND @roleId = 2
		GROUP BY matchid
		UNION ALL
		SELECT matchid, SUM(actual_stake * IIF(@IsApplyPT = 1, mpositiontaking, 1)) AS stakeTO
		FROM dbo.bettrans b WITH(NOLOCK) 
		WHERE statusID IN (0, 1) AND SiteDBGroupID IN (3)
			AND b.mrecommend = @mrecommend
			AND @roleId = 3
		GROUP BY matchid
		UNION ALL
		SELECT matchid, SUM(actual_stake * IIF(@IsApplyPT = 1, spositiontaking, 1)) AS stakeTO
		FROM dbo.bettrans b WITH(NOLOCK) 
		WHERE statusID IN (0, 1) AND SiteDBGroupID IN (3)
			AND b.srecommend = @srecommend
			AND @roleId = 4
		GROUP BY matchid
	) AS tmp
	INNER JOIN dbo.match m WITH(NOLOCK) ON m.matchid = tmp.matchid
	INNER JOIN dbo.League l WITH(NOLOCK) ON l.leagueid = m.leagueid
	CROSS APPLY (
		SELECT IIF(m.kickofftime <= CURRENT_TIMESTAMP, 1, 0) AS isLive
	) AS ck
	WHERE l.sporttype		= 1
		AND tmp.stakeTO		> 0
		AND m.eventstatus	= 'running'
		AND l.IsActive		= 1
		--- filter major leagues
		AND l.LeagueGroupID  NOT IN (113 ) -- Exclude Saba PinGoal
		AND l.leagueid	<> 28412 -- Arsenal & Over 2.5
		AND l.leaguename NOT LIKE '%special%'
		AND l.leaguename NOT LIKE '%specific%'
		AND l.leaguename NOT LIKE '%corner%'
		AND l.leaguename NOT LIKE '%booking%'
		AND l.leaguename NOT LIKE '%winner%'
		AND l.leaguename NOT LIKE '%goal%'
		AND l.leaguename NOT LIKE '%team%'
		AND l.leaguename NOT LIKE '%injury%'
		AND l.leaguename NOT LIKE 'z*%'
		AND l.leaguename NOT LIKE 'z-%'
		AND l.leaguename NOT LIKE '%half%'
		AND l.leaguename NOT LIKE '%advance%'
		AND l.leaguename NOT LIKE '%reach%'
		AND l.leaguename NOT LIKE '%?%'
		AND l.leaguename NOT LIKE '%final%'
		AND l.leaguename NOT LIKE '%promot%'
		AND l.leaguename NOT LIKE '%method%'
		AND l.leaguename NOT LIKE '%relegat%'
		AND l.leaguename NOT LIKE '%double chance%'
		AND l.leaguename NOT LIKE '%hockey%'
		AND l.leaguename NOT LIKE '%yellow card%'
		AND l.leaguename NOT LIKE '%red card%'
		AND l.leaguename NOT LIKE '%winning%'
		AND l.leaguename NOT LIKE '%scor%'
		AND l.leaguename NOT LIKE '%penalty%'
		AND l.leaguename NOT LIKE '%fantasy%'
		AND l.leaguename NOT LIKE '%half%'
		AND l.leaguename NOT LIKE '%Substitution%'
		AND l.leaguename NOT LIKE '%offside%'
		AND l.leaguename NOT LIKE '%free kick%'
		AND l.leaguename NOT LIKE '%throw in%'
		AND l.leaguename NOT LIKE '%extra%'
		AND l.leaguename NOT LIKE '%rock bottom%'
		AND l.leaguename NOT LIKE '%post split%'
		AND l.leaguename NOT LIKE '%no use%'
	ORDER BY tmp.stakeTO DESC;
END
GO