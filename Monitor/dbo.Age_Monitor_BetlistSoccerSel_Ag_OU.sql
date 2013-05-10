    ALTER PROCEDURE [dbo].[Age_Monitor_BetlistSoccerSel_Ag_OU]
	 @custid	INT, 
	 @matchid	NVARCHAR(4000) = '',
	 @transid	BIGINT = 0,
	 @LimitRowCount INT = 20 
	 WITH RECOMPILE
AS

/*	
	Created	: Johnson
	Task: Monitor lastest bets list( all sports and bettype over/under)
	Date: 28/06/2011
	DB: DB053.BODB02
	Revision:
	- 20111122@Sophia: Add Checktime and SecAcceptFlag to show status waiting or running
	
	Parameter's Explanation:
		- @custid : agent's ID
		- @transid: lastest transid 
		- @LimitRowCount: max record return.
		- @matchid : matchid of all soccer matches running
*/ 

BEGIN		
		SET NOCOUNT ON
		
		CREATE TABLE #tmpMatch (matchid INT PRIMARY KEY)
				
		INSERT INTO #tmpMatch  (matchid)
		SELECT val
		FROM dbo.strSplit(@matchid,',')
		
				
		SELECT TOP(@LimitRowCount)
			0 AS sporttype,
			b.matchid,				
			b.Username,	
			0 AS leagueid,			
			b.bettype,
			b.transid,
			b.refno,
			b.transdate,	
			'' AS matchcode,
			0 AS homeid,
			0 AS awayid,
			'' AS race,			
			b.betid,
			b.livehomescore,
			b.liveawayscore,
			b.liveindicator,
			b.hdp1,
			b.hdp2,
			b.odds,
			b.stake,
			CASE WHEN b.status = 'running' AND IsNull(b.SecAcceptFlag, 0) = 1 and IsNull(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
				 ELSE b.status 
				 END as status, 
			b.betteam,				
			b.IP,	
			CONVERT(BIT,0) AS isNeutral,		
			b.oddstype
		FROM dbo.bettrans b WITH(NOLOCK)
			INNER JOIN #tmpMatch m ON b.matchid = m.matchid								
		WHERE b.recommend = @custid
			AND b.bettype IN (3,8)
			AND b.transid >= @transid
			AND b.statusID BETWEEN 0 AND 1				
		ORDER BY b.transid DESC
		
		DROP TABLE #tmpMatch		
END


GO
GRANT EXECUTE ON [dbo].[Age_Monitor_BetlistSoccerSel_Ag_OU] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_Monitor_BetlistSoccerSel_Ag_OU] TO [bodbDownlineNetView]
GO
GRANT VIEW DEFINITION ON [dbo].[Age_Monitor_BetlistSoccerSel_Ag_OU] TO [vnteam]