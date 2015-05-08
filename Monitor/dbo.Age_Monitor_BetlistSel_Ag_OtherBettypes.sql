ALTER PROCEDURE [dbo].[Age_Monitor_BetlistSel_Ag_OtherBettypes]
 @custid	INT, 
 @transid BIGINT = 0,
 @LimitRowCount int = 20 
  WITH RECOMPILE
AS
BEGIN
/*	
	Created	: Johnson
	Task: Monitor lastest bets list( all bettypes and others bettype not handicap and over/under)
	Date: 28/06/2011
	DB: DB053.BODB02
	Revision:
		- 20111122@Sophia: Add Checktime and SecAcceptFlag to show status waiting or running
		- 20120827@Jamie: Add actual_stake for System Parlay Bet list 
		- 20130222@Elodie: Get custid value
		- 20130222@Elodie: Get oddsid value to use for Virtual HR
		
	Parameter's Explanation:
		- @custid : agent's ID
		- @transid: lastest transid 
		- @LimitRowCount: max record return.
*/ 
	SET NOCOUNT ON
	SELECT TOP(@LimitRowCount)
		b.custid,
		0 AS sporttype,
		b.matchid,	
		0 AS leagueid,			
		b.Username,				
		b.bettype,
		b.transid,
		b.refno,
		b.transdate,
		'' AS matchcode,
		0 AS homeid,
		0 AS awayid,
		b.oddsid as Race,				
		b.betid,
		b.livehomescore,
		b.liveawayscore,
		b.liveindicator,
		b.hdp1,
		b.hdp2,
		b.odds,
		b.stake,
		b.actual_stake, 
		CASE WHEN b.status = 'running' AND IsNull(b.SecAcceptFlag, 0) = 1 and IsNull(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
				 ELSE b.status 
				 END as status, 
		b.betteam,				
		b.IP,
		CONVERT(BIT,0) AS isNeutral,			
		b.oddstype,
		ISNULL(b.Betcheck,'') Betcheck
	FROM dbo.bettrans b WITH(NOLOCK)				
	WHERE b.recommend = @custid 
		AND b.statusID BETWEEN 0 AND 1	
		AND b.bettype NOT IN (1,3,7,8)	
		AND b.bettype < 19001
		AND b.transid > @transid		
	ORDER BY b.transid DESC
END

GO
GRANT EXECUTE ON [dbo].[Age_Monitor_BetlistSel_Ag_OtherBettypes] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_Monitor_BetlistSel_Ag_OtherBettypes] TO [bodbDownlineNetView]
GO
GRANT VIEW DEFINITION ON [dbo].[Age_Monitor_BetlistSel_Ag_OtherBettypes] TO [vnteam]