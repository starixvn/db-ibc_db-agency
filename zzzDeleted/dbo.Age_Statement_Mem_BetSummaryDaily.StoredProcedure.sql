ALTER PROCEDURE [dbo].Age_Statement_Mem_BetSummaryDaily 
	@FromDate datetime,
	@CustID int,
	@Language varchar(2) = 'E'

AS
--Original SP: BetTransSelDSummary
--AGENT SITE
--UPDATED 02/22/2006: remove refno
--UPDATED 03/10/2006: remove odds depend
SET NOCOUNT ON 
select 
	match.eventstatus status,match.matchid,bettrans.bettype,match.eventdate eventdate,
	case @Language when 'E' then bettype.typenamee when 'J' then isnull(bettype.typenamej, bettype.typenamee) else isnull(bettype.typenamec_uni, bettype.typenamee) end as typenamee,
	case @Language when 'E' then a.teamname when 'J' then isnull(a.teamnamej, a.teamname) else isnull(a.teamnamec_uni, a.teamname) end as home,
	case @Language when 'E' then b.teamname when 'J' then isnull(b.teamnamej, b.teamname) else isnull(b.teamnamec_uni, b.teamname) end as away,
	sum(bettrans.stake) as totalbet,
	sum(case when bettrans.odds<0 then bettrans.stake*-bettrans.odds else bettrans.stake end) as totalstake,
	sum(bettrans.winlost) as winning 
from 
	bettrans with (NOLOCK)
--	INNER JOIN odds with (NOLOCK) ON odds.oddsid=bettrans.oddsid 
	INNER JOIN match with (NOLOCK) ON  bettrans.matchid=match.matchid 
	INNER JOIN team AS a with (NOLOCK) ON a.teamid=match.homeid
	INNER JOIN team AS b with (NOLOCK) ON b.teamid=match.awayid 
	INNER JOIN bettype  with (NOLOCK) ON bettype.typeid=bettrans.bettype 
where
	bettrans.custid=@CustID  
	and match.eventdate=@FromDate
	and bettrans.bettype in (1,2,3,4,5) 
	and bettrans.comstatus='s' 
group by 
	bettrans.bettype,match.matchcode,a.teamname,b.teamname,match.eventdate,bettype.typenamee,
	match.eventstatus,match.matchid ,a.teamnamec_uni,b.teamnamec_uni,bettype.typenamec_uni
	,a.teamnamej,b.teamnamej,bettype.typenamej

Union ALL

select 
	bettrans.status AS status,'0' AS matchid,'5' AS bettype,convert(char(10),bettrans.transdate,110) eventdate,case @Language when 'E' then 'Combination' else 'Combination' end as home,
	' 1 X 2' AS away,case @Language when 'E' then 'Combination' else 'Combination' end as typenamee,
	sum(bettrans.stake) as totalbet,
	sum(case when bettrans.odds<0 then bettrans.stake*-bettrans.odds else bettrans.stake end) as totalstake,
	sum(bettrans.winlost) as winning 
from bettrans with (NOLOCK)
where
	bettrans.custid=@CustID
	and bettrans.transdate >= @FromDate 
	and bettrans.transdate < dateadd(dd,1,@FromDate) 
	and bettrans.comstatus='m' 
	and bettrans.oddsid=0 
group by convert(char(10),bettrans.transdate,110), bettrans.status





GO

SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 


GO
GRANT  EXECUTE  ON [dbo].Age_Statement_Mem_BetSummaryDaily  TO [bodbDownlineNet]
GO
GRANT  EXECUTE  ON [dbo].Age_Statement_Mem_BetSummaryDaily  TO [bodbDownlineNetView]
GO
