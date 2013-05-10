ALTER PROCEDURE [dbo].[Age_TotalBets_Sel430_MAg]
	@CustID int,
	@Language varchar(2) = 'E'
 AS
/*
Created: 20110915@TOM
Task : Retrieve total bet of 1St Correct Score/Correct Score. (BetType: 4,30)
DB: DB053.bodb02
Original:Age_BetList_SelRunningByBettype_MAg

Revisions:
	- 21Nov2011@Johnson: get matchid column
	- 20111122@Sophia: Add Checktime and SecAcceptFlag to show status waiting or running
	- 20111216@Sopha: Remove function f_GetOddsByBettype , f_GetChoice , f_ShowOddsByBettype
	- 20121004@Johnson: get comstatus to check double comm losing 	
*/

SET NOCOUNT ON

	select 
		m.sporttype,
		b.username,
		m.leagueID, 
		b.bettype,		
		b.transid,
		b.refno,
		m.matchid,
		m.matchcode,
		m.homeID,
		m.awayID,
		convert(float, b.hdp1) as hdp1, 
		convert(float, b.hdp2) as hdp2, 
		b.odds,
		b.modds,
		CASE WHEN b.status = 'running' AND IsNull(b.SecAcceptFlag, 0) = 1 and IsNull(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
				 ELSE b.status 
				 END as status,
		CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END as comstatus,
		b.stake,
		b.actual_stake,
		b.transdate,		
		b.betteam,
		b.betID,
		b.spositiontaking,
		b.mpositiontaking,
		b.apositiontaking,
		b.discount as adiscount,
		b.adiscount as mdiscount,
		b.sdiscount as sdiscount,
		b.livehomescore,
		b.liveawayscore,
		b.liveindicator, 
		IP as IP,
		isnull(m.isNeutral, CONVERT(BIT,0)) as IsNeutral,
		b.OddsType
 	from 
		bettrans b with (nolock)
		inner join match m with (nolock) on  b.matchid=m.matchid 
	where 
		b.MRecommend=@custid
		AND b.bettype IN (4,30)
		and b.statusID in (0,1)
		
	order by b.status, b.transid


GO
GRANT EXECUTE ON [dbo].[Age_TotalBets_Sel430_MAg] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_TotalBets_Sel430_MAg] TO [bodbDownlineNetView]
GO
GRANT VIEW DEFINITION ON [dbo].[Age_TotalBets_Sel430_MAg] TO vnteam
GO