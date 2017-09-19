/*<info serverAlias="DBAGE-bodb02" executers="bodbDownlineNet,bodbDownlineNetView" viewers="" isFunction="0" isNested="0"></info>*/
USE [bodb02]
GO

ALTER PROCEDURE [dbo].[Age_NewTotalBetsForeCast_LeagueSel] (
	@sporttype SMALLINT = 1
	,@IsLive BIT = 1
	,@isShowAll BIT = 1 -- 1: Show All; 0: is NOT show Test
) AS

/*	
	Created: 20151216@Bobby
	Task: Alpha site - New total bets AND forecast events filtering
	DB: DBAGE/BODB02
	
	Revision:
		- 20151216@Bobby: Initial
		- 20170816@Percy: Change data type of Sporttype [RedmineID: #73545]
	
	Parameter's Explanation:
			
*/

BEGIN
	SET NOCOUNT ON
	
	DECLARE @timeNow	DATETIME
	SELECT @timeNow		= GETDATE()		
	
	CREATE TABLE #league (leagueid	INT, leaguename	NVARCHAR(120))
	
	INSERT INTO #league
	SELECT l.leagueid
			, l.leaguename
	FROM dbo.League l WITH(NOLOCK)
	WHERE l.sporttype	= @sporttype
			AND l.IsActive	= 1
			--AND l.outright = 0  (No need to check this since bettype (1,7,3,8,5,15) -> outright = 0)
			AND l.leagueid	<> 28412 -- Arsenal & Over 2.5
			AND EXISTS (SELECT 1 FROM dbo.match m WITH(NOLOCK) 
							INNER JOIN dbo.odds o WITH(NOLOCK) ON o.matchid	= m.matchid 
						WHERE m.leagueid	= l.leagueid AND m.eventstatus NOT IN ('completed','Internal')
								AND o.bettype IN (1,7,3,8,5,15)
									
							AND o.oddsstatus	<> 'closed'
							AND 1 = CASE 
										WHEN @IsLive = 0 AND m.kickofftime > @timeNow	THEN 1
										WHEN @IsLive = 1 AND m.kickofftime <= @timeNow	THEN 1
									ELSE 0
								END	
				)
			AND l.isTest= CASE WHEN @isshowall = 1 THEN l.isTest ELSE @isshowall END
	
	-- filter by main league
	DELETE d
	FROM #league d
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
		--OR leaguename LIKE '%test%'
		OR leaguename LIKE '%no use%'
	
	--return league	
	SELECT leagueid
			, leaguename
	FROM #league
	ORDER BY leagueid
	
	DROP TABLE #league
END
GO