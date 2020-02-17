/*<info serverAlias="DBAGE-bodb02" executers="bodbDownlineNet,bodbDownlineNetView" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Age_NewTotalBetsForeCast_EventSel] (
	@leagueid		INT = 0
	, @IsLive		BIT = 0
	, @sporttype	SMALLINT = 1
)
AS

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
	
	SELECT m.matchid
		, m.matchcode
		, m.homeid
		, m.awayid
	FROM dbo.match m WITH(NOLOCK)
	WHERE m.leagueid = @leagueid 
		AND m.eventstatus NOT IN ('completed','Internal')
		AND EXISTS ( 
			SELECT TOP 1 1 
			FROM dbo.odds o WITH(NOLOCK) 
			WHERE o.matchid	= m.matchid 
				AND o.bettype IN (1,3,7,8,5,15)
				AND o.oddsstatus <> 'closed'
		)
		AND 1 = CASE 
					WHEN @IsLive = 0 AND m.kickofftime > @timeNow	THEN 1
					WHEN @IsLive = 1 AND m.kickofftime <= @timeNow	THEN 1
					ELSE 0
				END
	ORDER BY ISNULL(m.kickofftime,1) DESC, m.eventdate DESC

END
GO