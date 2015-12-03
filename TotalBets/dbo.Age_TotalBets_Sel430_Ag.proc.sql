USE bodb02
GO

ALTER PROCEDURE [dbo].[Age_TotalBets_Sel430_Ag]
	@custid INT,
	@Language VARCHAR(2) = 'E'
AS

/*
	Created: 20110915@TOM
	Task : Retrieve total bet of 1St Correct Score/Correct Score. (BetType: 4,30)
	DB: DBAGE.bodb02
	Original:Age_BetList_SelRunningByBettype_Ag

	Revisions:
		- 21Nov2011@Johnson: get matchid column
		- 20111122@Sophia: Add Checktime and SecAcceptFlag to show status waiting or running
		- 20111216@Sophia: Remove function f_GetOddsByBettype , f_GetChoice , f_ShowOddsByBettype
		- 20121004@Johnson: get comstatus to check double comm losing 	
		- 20140611@Dom: Add new bettype ht correct score 152 [Redmine: #17148]
		- 20150407@Cody: Integrate new 60 bet types from BetRadar [Redmine: #32734]
		- 20151203@Kos: Include bet type 405 2H Correct Score [Redmine: #47959]
*/

SET NOCOUNT ON
	SELECT 
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
		CONVERT(FLOAT, b.hdp1) AS hdp1, 
		CONVERT(FLOAT, b.hdp2) AS hdp2, 
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
		b.discount AS adiscount,
		b.adiscount AS mdiscount,
		b.sdiscount AS sdiscount,
		b.livehomescore,
		b.liveawayscore,
		b.liveindicator, 
		ip AS ip,
		ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
		b.oddstype
 	FROM 
		bettrans b WITH (NOLOCK)
		INNER JOIN match m WITH (NOLOCK) ON  b.matchid=m.matchid
	WHERE 
		b.Recommend=@custid
		AND b.bettype IN (4,30,152,165,166, 405)
		AND b.statusID IN (0,1)
	Order BY b.status, b.transid

GO

GRANT EXECUTE ON [dbo].[Age_TotalBets_Sel430_Ag] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_TotalBets_Sel430_Ag] TO [bodbDownlineNetView]
GO
GRANT VIEW definition ON [dbo].[Age_TotalBets_Sel430_Ag] TO vnteam
