ALTER PROCEDURE [dbo].[Agw_Rpt_ResultSelMatch]
	@leagueID int=0,
	@matchID int=0,
	@FromDate DATETIME,
	@CustID int = 0 
	/*
	DB: DB053.bodb02
	Creator: TerryNguyen
	Date: 3/3/2009
	Task: Get information's Match from MatchID and LeagueID
	- 20110406@Henry: Not show BetDaq's match in result page
	- 20110907@Sophia: Add column IsHTCal, calculate for Pending Status
	- 20110923@Sophia: Add condition OR to show the row which have eventstatus = 'running' and (mr.ishtcal=1 OR mr.calculate=1)
	- 20111003@Sophia: . Add column IsPending Pending Status. 
					   . Edit condition OR to show the row which have eventstatus IN ('running','closed') 
	*/
AS
	SET NOCOUNT ON
	
	declare @site varchar(50)
	if @CustID <> 0
	select @site = site from customer (nolock)
	where CustID = @CustID


	declare @ToDate datetime
	Select @ToDate = dateadd(s,-1, dateadd(d, 1, @FromDate))

	SELECT m.*
	FROM 
	(
	SELECT m.matchid, betstatus, sporttype, leagueid, eventdate,
		kickofftime, homeid, awayid, hthomescore, htawayscore,
		finalhomescore, finalawayscore,   
		
		case when betstatus like 'Refund FT%' then 'Refund FT'   
			when betstatus like 'Refund HT%' then 'Refund HT'  
			when betstatus like 'Refund%' then 'Refund'   
		else eventstatus end as eventstatus, 
		
		matchcode,
		ISNULL(m.IsNeutral, CONVERT(BIT,0)) AS IsNeutral, GoalRecord,
		ISNULL(mr.IsHTCal,0) as IsHTCal,
		ISNULL(mr.calculate,0) as calculate	,
		ISNULL(mr.IsPending,0) as IsPending
	FROM dbo.match m with (nolock)
	LEFT OUTER JOIN match_remark mr WITH(NOLOCK) ON m.matchid = mr.matchid 
	WHERE eventdate >= @FromDate and eventdate <= @ToDate 
		and (eventstatus not in ('internal','closed','running')
				OR ( mr.IsPending=1 AND m.eventstatus IN ('running','closed') )
			    OR ( mr.IsHTCal = 1 AND m.eventstatus ='running')		
			)						
		and leagueid = case @leagueID when 0 then 1 else @leagueID end
		and m.matchid = case @matchID when 0 then 1 else @matchID end
		and matchcode not like '%hedge%'
		and matchcode not like '%betdaq%'
		and (isnull(@site,'')='789y' OR  (matchcode not like '%(LR)%' and isnull(@site,'')<>'789y'))
	UNION ALL
	SELECT m.matchid, betstatus, sporttype, leagueid, eventdate,
		kickofftime, homeid, awayid, hthomescore, htawayscore,
		finalhomescore, finalawayscore, 
		
		case when betstatus like 'Refund FT%' then 'Refund FT'   
			when betstatus like 'Refund HT%' then 'Refund HT'  
			when betstatus like 'Refund%' then 'Refund'   
		else eventstatus end as eventstatus, 
		
		matchcode,
		ISNULL(m.IsNeutral, CONVERT(BIT,0)) AS IsNeutral, GoalRecord,
		ISNULL(mr.IsHTCal,0) as IsHTCal,
		ISNULL(mr.calculate,0) as calculate	,
		ISNULL(mr.IsPending,0) as IsPending
	FROM dbo.match14 m with (nolock)
	LEFT OUTER JOIN match_remark mr WITH(NOLOCK) ON m.matchid = mr.matchid
	WHERE eventdate >= @FromDate and eventdate <= @ToDate 
		and ( eventstatus not in ('internal','closed','running')
				OR ( mr.IsPending=1 AND m.eventstatus IN ('running','closed') )
			    OR ( mr.IsHTCal = 1 AND m.eventstatus ='running')
			)
		and leagueid = case @leagueID when 0 then 1 else @leagueID end
		and m.matchid = case @matchID when 0 then 1 else @matchID end
		and matchcode not like '%hedge%'
		and matchcode not like '%betdaq%'
		and (isnull(@site,'')='789y' OR  (matchcode not like '%(LR)%' and isnull(@site,'')<>'789y'))
	) m	
	order by m.eventdate,m.matchcode
GO
GRANT EXECUTE ON [dbo].[Agw_Rpt_ResultSelMatch] TO [bodbDownlineNet]