ALTER PROCEDURE [dbo].[Age_LeagueSelRunning_Ag]
	@AgID int,	
	@Language NVARCHAR(2) = 'E',
	@Bettypes varchar(100) = '0'--0: all, 1:1,3,7,8; 5:5,15 
AS
SET NOCOUNT ON
--Original: LeagueSelRunning
/*
Original: LeagueSelRunning
Task: Select running Leagues for 1,3,5,7,8, and 15 bet types
DB: DB05.bodb02
Revisions: 
	- 20090213@Kiwi: Use ruben = 0 instead of status in ('running','waiting').
	- 20090325@Phuc: add para bettypes, remove unused code
	- 20110516@Johnson: expand length of @bettypes parameter
*/

Select @Bettypes = case @Bettypes when '0' then '1,3,7,8,5,15' when '1' then '1,3,7,8' when '5' then '5,15' else '1,3,7,8,5,15' end 

select 
	match.leagueid
	,match.sporttype
from 
	league with(nolock) 
	inner join match with (nolock) on league.leagueid = match.leagueid
	--inner join odds as O with (nolock) on match.matchid = O.matchid	
where  match.eventstatus in ('running')
	--and O.oddsstatus = 'running'
	--and (IsNull(o.liveindicator,0) = 1 or match.kickofftime >= CURRENT_TIMESTAMP)
	and match.matchid IN(select distinct matchid from bettrans with (nolock) where status in ('running','waiting') and recommend = @AgID and bettype in (select val from dbo.strSplit_Key(@Bettypes,',')))  
group by  match.leagueid, league.leaguename, match.sporttype
order by league.leaguename
GO

GRANT EXECUTE ON [dbo].[Age_LeagueSelRunning_Ag] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_LeagueSelRunning_Ag] TO [bodbDownlineNetView]
GO
