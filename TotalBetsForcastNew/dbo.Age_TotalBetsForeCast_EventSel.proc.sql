Use bodb02
GO

ALTER PROCEDURE [dbo].[Age_TotalBetsForeCast_EventSel] (
	@LeagueList		VARCHAR(1000) = NULL
	,@IsLive		BIT = 0
) AS
/*	
Created: 20151216@Bobby
Task: Alpha site - New total bets AND forecast events filtering
DB: DBAGE/BODB02
Revision:
	- 20151216@Bobby: Initial
	
Parameter's Explanation:
			
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @timeNow	DATETIME
		,@roleId		TINYINT
		,@sporttype		SMALLINT

	CREATE TABLE #custRecommend (
		custid		INT
	)
	
	CREATE TABLE #bettypes ( bettype SMALLINT )
	
	CREATE TABLE #matchEvent (
		matchid			INT
		, matchcode		NVARCHAR(50)
		, homeid		INT
		, awayid		INT
		, leagueid		INT
		, leaguename	NVARCHAR(120)
		, IdxRow		INT
	)

	SELECT @leagueList	= ISNULL(@leagueList, 'ALL')
		, @timeNow		= GETDATE()		
	
	INSERT INTO #bettypes
	SELECT bettype
	FROM ( 
		VALUES 
		(1)		--HANDicap
		, (7)	-- 1H HANDicap
		, (3)	-- Over/Under
		, (8)	-- 1H Over/Under
		, (5)	-- FT.1X2
		, (15)	-- 1H 1X2
	) AS T(bettype)
	
	SET @sporttype	= 1 


	IF(@leagueList = 'ALL')
	BEGIN
		
		INSERT INTO #matchEvent
		SELECT m.matchid
			, m.matchcode
			, m.homeid
			, m.awayid
			, l.leagueid
			, l.leaguename
			, ROW_NUMBER() OVER(ORDER BY ISNULL(m.kickofftime,1) DESC, m.eventdate DESC) 
		FROM dbo.match m WITH(NOLOCK)
			INNER JOIN dbo.League l WITH(NOLOCK)
			ON m.leagueid	= l.leagueid

		WHERE l.sporttype	= @sporttype
			AND l.IsActive	= 1
			AND l.IsTest	= 0
			AND l.outright 	= 0
			AND l.leagueid	<> 28412 -- Arsenal & Over 2.5
			AND m.eventstatus = 'running'
			AND EXISTS ( 
				SELECT TOP 1 1 
				FROM dbo.odds o WITH(NOLOCK) 
				WHERE o.matchid			= m.matchid 
					AND EXISTS(
						SELECT TOP 1 1 
						FROM #bettypes bt 
						WHERE bt.bettype = o.bettype
					)
					AND o.oddsstatus	<> 'closed'
			)
			AND 1 = CASE 
						WHEN @IsLive = 0 AND m.kickofftime > @timeNow	THEN 1
						WHEN @IsLive = 1 AND m.kickofftime <= @timeNow	THEN 1
						ELSE 0
					END
	END
	ELSE
	BEGIN	
		INSERT INTO #matchEvent
		SELECT m.matchid
			, m.matchcode
			, m.homeid
			, m.awayid
			, l.leagueid
			, l.leaguename
			, ROW_NUMBER() OVER(ORDER BY ISNULL(m.kickofftime,1) DESC, m.eventdate DESC) 
		FROM dbo.match m WITH(NOLOCK)
			INNER JOIN dbo.League l WITH(NOLOCK)
			ON m.leagueid	= l.leagueid
			INNER JOIN [dbo].[Age_f_SplitString] (@leagueList, ',') AS t
			ON l.leagueid 	= t.Val
		WHERE l.sporttype	= @sporttype
			AND l.IsActive	= 1
			AND l.IsTest	= 0
			AND l.outright 	= 0
			AND l.leagueid	<> 28412 -- Arsenal & Over 2.5
			AND m.eventstatus = 'running'
			AND EXISTS ( 
				SELECT TOP 1 1 
				FROM dbo.odds o WITH(NOLOCK) 
				WHERE o.matchid			= m.matchid 
					AND EXISTS(
						SELECT TOP 1 1 
						FROM #bettypes bt 
						WHERE bt.bettype = o.bettype
					)
					AND o.oddsstatus	<> 'closed'
			)
			AND 1 = CASE 
						WHEN @IsLive = 0 AND m.kickofftime > @timeNow	THEN 1
						WHEN @IsLive = 1 AND m.kickofftime <= @timeNow	THEN 1
						ELSE 0
					END
	END
	
	-- filter by main league
	DELETE d
	FROM #matchEvent d
	WHERE leaguename LIKE '%special%'
		OR leaguename LIKE '%specific%'
		OR leaguename LIKE '%corner%'
		OR leaguename LIKE '%booking%'
		OR leaguename LIKE '%winner%'
		OR leaguename LIKE '%goal%'
		OR leaguename LIKE '%team%'
		OR leaguename LIKE '%injury%'
		OR leaguename LIKE 'z*%'
		OR leaguename LIKE 'z-%'
		OR leaguename LIKE '%half%'
		OR leaguename LIKE '%advance%'
		OR leaguename LIKE '%reach%'
		OR leaguename LIKE '%?%'
		OR leaguename LIKE '%final%'
		OR leaguename LIKE '%promot%'
		OR leaguename LIKE '%method%'
		OR leaguename LIKE '%relegat%'
		OR leaguename LIKE '%double chance%'
		OR leaguename LIKE '%hockey%'
		OR leaguename LIKE '%yellow card%'
		OR leaguename LIKE '%red card%'
		OR leaguename LIKE '%winning%'
		OR leaguename LIKE '%scor%'
		OR leaguename LIKE '%penalty%'
		OR leaguename LIKE '%fantasy%'
		OR leaguename LIKE '%half%'
		OR leaguename LIKE '%Substitution%'
		OR leaguename LIKE '%offside%'
		OR leaguename LIKE '%free kick%'
		OR leaguename LIKE '%throw in%'
		OR leaguename LIKE '%extra%'
		OR leaguename LIKE '%rock bottom%'
		OR leaguename LIKE '%post split%'
		OR leaguename LIKE '%test%'
		OR leaguename LIKE '%no use%'
	
	--return league	
	SELECT 
		DISTINCT
		leagueid
		, leaguename
	FROM #matchEvent
	ORDER BY leagueid

	-- return match
	SELECT matchid
		, matchcode
		, homeid
		, awayid
	FROM #matchEvent
	ORDER BY IdxRow

	DROP TABLE #bettypes
	DROP TABLE #custRecommend
	DROP TABLE #matchEvent

	RETURN
END
GO
GRANT EXECUTE ON [dbo].[Age_TotalBetsForeCast_EventSel] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_TotalBetsForeCast_EventSel] TO [bodbDownlineNetView]
GO
GRANT VIEW DEFINITION ON [dbo].[Age_TotalBetsForeCast_EventSel] TO [vnteam]
GO
exec [dbo].[Age_TotalBetsForeCast_EventSel]