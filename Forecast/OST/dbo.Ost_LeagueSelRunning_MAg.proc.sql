/*<info serverAlias="DBOST-bodb_ost" executers="bodbDownlineNet,bodbDownlineNetView" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Ost_LeagueSelRunning_MAg] 
	@MAgID INT
	, @Language NVARCHAR(2) = 'E'
	, @Bettypes VARCHAR(100) = '0' --0: all, 1:1,3,7,8; 5:5,15 
AS
/*
	Created:20191021@Bobby
	Task: New Forecast at Agent Site 
	DB: DBOST.bodb_ost
	Original:DB042.bodb02.Age_LeagueSelRunning_MAg
	
	Revisions: 
		- 20191021@Bobby: Initialize [Redmine:114231] 
		
*/
BEGIN
	SET NOCOUNT ON

	SELECT @Bettypes = CASE @Bettypes
			WHEN '0'
				THEN '1,3,7,8,301,302,303,304,5,15,167'
			WHEN '1'
				THEN '1,3,7,8,301,302,303,304'
			WHEN '5'
				THEN '5,15,167'
			ELSE '1,3,7,8,301,302,303,304,5,15,167'
			END

	SELECT match.leagueid
		, match.sporttype
	FROM league WITH (NOLOCK)
	INNER JOIN match WITH (NOLOCK)
		ON league.leagueid = match.leagueid
	--inner join odds as O with (nolock) on match.matchid = O.matchid	
	WHERE match.eventstatus IN ('running')
		--and O.oddsstatus = 'running'
		--and (IsNull(o.liveindicator,0) = 1 or match.kickofftime >= CURRENT_TIMESTAMP)
		AND match.matchid IN (
			SELECT DISTINCT matchid
			--FROM bettrans WITH (NOLOCK, INDEX = IX_betrunning_mrecommend)
			FROM dbo.OST_fn_bettrans_running()
			WHERE statusID IN (0, 1)
				AND mrecommend = @MAgID
				AND bettype IN (
					SELECT val
					FROM dbo.strSplit_Key(@Bettypes, ',')
					)
			)
	GROUP BY match.leagueid
		, league.leaguename
		, match.sporttype
	ORDER BY league.leaguename
END
GO


