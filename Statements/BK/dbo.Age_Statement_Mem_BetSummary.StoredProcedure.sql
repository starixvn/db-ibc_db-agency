Alter PROCEDURE [dbo].[Age_Statement_Mem_BetSummary]
	@CustID int=null,
	@FromDate datetime,
	@ToDate datetime,
	@Language varchar(2) = 'E',
	@username varchar(50) = NULL -- for API
AS
SET NOCOUNT ON
--DB: DB05.bodb02
--Revision:
	--20111229@Jim: remove function : f_GetChoice 
	
--Original: BetTransSelSummaryPB
--Bet summary in Misc Page

--AGENT SITE
--UPDATED 02/22/2006: remove refno
--UPDATED 03/10/2006: remove odds depend
--update@phuc 2007/12/11 for API


if @custid is null
	select @custid = custid from customer with (nolock) where username = @username

select 
	match.eventdate,bettrans.bettype,match.matchcode,
	match.homeid,
	match.awayid,
	--case @Language when 'E' then a.teamname when 'J' then isnull(a.teamnamej, a.teamname) else isnull(a.teamnamec_uni, a.teamname) end as home,
	--case @Language when 'E' then b.teamname when 'J' then isnull(b.teamnamej, b.teamname) else isnull(b.teamnamec_uni, b.teamname) end as away,
	bettrans.status,sum(bettrans.stake) as totalbet,
	sum(case when bettrans.odds<0 then bettrans.stake*-bettrans.odds else bettrans.stake end) as totalstake,
	sum(bettrans.winlost) as winning,
	bettrans.betteam,
--	dbo.f_GetChoice(bettrans.betteam, bettrans.bettype,@Language) betteam,
	isnull(match.isNeutral, CONVERT(BIT,0)) as IsNeutral
from 	bettrans with (NOLOCK)
	INNER JOIN match with (NOLOCK) ON bettrans.matchid=match.matchid	
	--INNER JOIN team AS a with (NOLOCK) ON a.teamid=match.homeid
	--INNER JOIN team AS b  with (NOLOCK) ON b.teamid=match.awayid
where
	bettrans.custid=@CustID  
	and bettrans.transdate>=@FromDate  
	and bettrans.transdate<= dateadd(dd,1,@ToDate)  
	and bettrans.bettype in (1,2,3,7,8)  
group by bettrans.bettype,match.matchcode,
	match.homeid,
	match.awayid,
	--a.teamname,b.teamname,
	bettrans.status,bettrans.betteam,match.eventdate, match.isNeutral
	--a.teamnamec_uni,b.teamnamec_uni,a.teamnamej,b.teamnamej
order by match.eventdate

GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO


GRANT  EXECUTE  ON [dbo].[Age_Statement_Mem_BetSummary]  TO [bodbDownlineNet]
GO
GRANT  EXECUTE  ON [dbo].[Age_Statement_Mem_BetSummary]  TO [bodbDownlineNetView]
GO
