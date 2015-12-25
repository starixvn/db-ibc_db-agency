Use bodb02
GO

ALTER PROCEDURE [dbo].[Age_TotalBetsForeCast_EventSel] (
	@CustId			INT	= 0
	,@LeagueList	VARCHAR(1000) = NULL
	,@IsLive		BIT = 1
) AS
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
		(1)		--Handicap
		, (7)	-- 1H Handicap
		, (3)	-- Over/Under
		, (8)	-- 1H Over/Under
		, (5)	-- FT.1X2
		, (15)	-- 1H 1X2
	) AS T(bettype)
	
	SET @sporttype	= 1 

	/*SELECT TOP 1
		@roleId			= roleId
		, @sporttype	= 1 
	FROM dbo.Customer c WITH (NOLOCK)
	WHERE c.custid = @custid
	
	IF(ISNULL(@roleId, 0) = 0) RETURN
	
	--select @roleId RoleId
	
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
	*/
	
	--select count(1) TotalRec
	--from #custRecommend

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
			--AND l.leaguename LIKE '*%' --main league
			/*AND EXISTS (
				SELECT TOP 1 1 
				FROM dbo.bettrans b WITH(NOLOCK) 
					--INNER JOIN #custRecommend c
					--ON b.recommend = c.custId
				WHERE EXISTS(
						SELECT 1 
						FROM #custRecommend c 
						WHERE c.custId = b.recommend
					)
					AND b.matchid = m.matchid 
					AND EXISTS(
						SELECT 1 
						FROM #bettypes bt 
						WHERE bt.bettype = b.bettype
					)
			)*/
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
			ON l.leagueid = t.Val
		WHERE l.sporttype	= @sporttype
			AND l.IsActive	= 1
			AND l.IsTest	= 0
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
			--AND l.leaguename LIKE '*%' --main league
			/*AND EXISTS (
				SELECT TOP 1 1 
				FROM dbo.bettrans b WITH(NOLOCK) 
					--INNER JOIN #custRecommend c
					--ON b.recommend = c.custId
				WHERE 
					EXISTS(
						SELECT 1 
						FROM #custRecommend c 
						WHERE c.custId = b.recommend
					)
					AND b.matchid = m.matchid 
					AND EXISTS(
						SELECT 1 
						FROM #bettypes bt 
						WHERE bt.bettype = b.bettype
					)
			)*/
	END

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

	RETURN
END
GO
GRANT EXECUTE ON [dbo].[Age_TotalBetsForeCast_EventSel] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_TotalBetsForeCast_EventSel] TO [bodbDownlineNetView]
GO
GRANT VIEW DEFINITION ON [dbo].[Age_TotalBetsForeCast_EventSel] TO [vnteam]
GO