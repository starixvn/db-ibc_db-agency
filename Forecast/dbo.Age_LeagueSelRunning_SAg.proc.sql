/*<info serverAlias="DBBOF-bodb02" executers="bodbDownlineNet,bodbDownlineNetView" isFunction="0"></info>*/	
ALTER PROCEDURE [dbo].[Age_LeagueSelRunning_SAg]
	@SAgID int,	
	@Bettypes varchar(100) = '0'--0: all, 1:1,3,7,8; 5:5,15 
AS
/*
Task: Select running Leagues for 1,3,5,7,8, and 15 bet types
DB: DBBOF.bodb02

Revisions:
	- 20090213@Kiwi: Use ruben = 0 instead of status in ('running','waiting').
	- 20090325@Phuc: add para bettypes, remove unused code
	- 20110516@Johnson: expand length of @Bettypes parameter
	- 20150408@Cody: Apply bet radar bettype (167) [Remine: #32734]
	- 20150826@Winnie: Myanmar Odds
	- 20180802@Helen: Update code for adjusting indexes - [Redmine:98757]
	- 20190918@Percy: Remove inactive products [RedmineID: #118699]
	- 20201005@Danny: Change to use alias DBBOF alternative to DB042 [RedmineID: #139516]
	- 20240109@Lewis: Add LeagueGroupId [RedmineID: #197160]
*/
BEGIN
	SET NOCOUNT ON

	Select @Bettypes = case @Bettypes when '1' then '1,3,7,8' when '5' then '5,15,167' else '1,3,7,8,5,15,167' end

	select
		m.leagueid
		,l.LeagueGroupID
		,m.sporttype
	from 	
		league l with (nolock) 
		inner join match m with (nolock) on l.leagueid = m.leagueid
	where  m.eventstatus in ('running')
		and m.matchid IN (select distinct matchid 
							from bettrans WITH (NOLOCK,INDEX = IX_betrunning_srecommend) 
							where statusID IN (0,1) and srecommend = @SAgID  
								and bettype in (select val from dbo.strSplit_Key(@Bettypes,',')))    
	group by m.leagueid, l.leagueid, m.sporttype,l.LeagueGroupID
	order by l.leagueid
END
GO
