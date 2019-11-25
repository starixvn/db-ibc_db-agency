/*<info serverAlias="DBOST-bodb_ost" executers="bodbDownlineNet,bodbDownlineNetView" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Ost_LeagueSelRunning_MAg] @MAgID INT
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
			WHEN '1'
				THEN '1,3,7,8'
			WHEN '5'
				THEN '5,15,167'
			ELSE '1,3,7,8,5,15,167'
			END

	SELECT m.leagueid
		, m.sporttype
	FROM league l WITH (NOLOCK)
	INNER JOIN match m WITH (NOLOCK)
		ON l.leagueid = m.leagueid
	WHERE m.eventstatus IN ('running')
		AND m.matchid IN (
			SELECT DISTINCT matchid
			FROM
				--bettrans WITH (NOLOCK, INDEX = IX_betrunning_mrecommend ) 
				dbo.Ost_f_bettrans_running() AS b
			WHERE statusID IN (0, 1)
				AND mrecommend = @MAgID
				AND bettype IN (
					SELECT val
					FROM dbo.strSplit_Key(@Bettypes, ',')
					)
			)
	GROUP BY m.leagueid
		, l.leaguename
		, m.sporttype
	ORDER BY l.leaguename
END
GO


