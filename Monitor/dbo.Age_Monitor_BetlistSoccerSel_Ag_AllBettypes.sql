  ALTER PROCEDURE [dbo].[Age_Monitor_BetlistSoccerSel_Ag_AllBettypes]
	 @custid	INT, 
	 @matchid	NVARCHAR(4000) = '',
	 @transid	BIGINT = 0,
	 @LimitRowCount INT = 20 
	 WITH RECOMPILE
AS
SET NOCOUNT ON
/*	
	Created	: Johnson
	Task: Monitor lastest bets list( all bettypes and all sports)
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
		DECLARE @transid_min BIGINT
		--CREATE TABLE #tmpMatch (matchid INT PRIMARY KEY)
		
		CREATE TABLE #BetsList(			
			matchid		INT,				
			Username	NVARCHAR(100),				
			bettype		INT,
			transid		BIGINT PRIMARY KEY,
			refno		BIGINT,
			transdate	DATETIME,				
			betid		BIGINT,			
			livehomescore INT,
			liveawayscore INT,
			liveindicator INT,
			hdp1		SMALLMONEY,
			hdp2		SMALLMONEY,
			odds		SMALLMONEY,
			stake		MONEY,
			STATUS		NVARCHAR(10),
			betteam		NVARCHAR(20),				
			IP			NVARCHAR(30),			
			oddstype	TINYINT
		)
		
		SELECT @transid_min = @transid
		
		--INSERT INTO #tmpMatch  (matchid)
		SELECT val AS matchid
		INTO #tmpMatch
		FROM dbo.strSplit(@matchid,',')
		
		INSERT INTO #BetsList			        
		SELECT TOP(@LimitRowCount)
			b.matchid,				
			b.Username,				
			b.bettype,
			b.transid,
			b.refno,
			b.transdate,				
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
			b.oddstype
		FROM dbo.bettrans b WITH(NOLOCK)
			INNER JOIN #tmpMatch m ON b.matchid = m.matchid								
		WHERE b.recommend = @custid
			AND b.bettype < 19001 
			AND b.transid >= @transid_min
			AND b.statusID BETWEEN 0 AND 1				
		ORDER BY b.transid DESC
		
		SELECT @transid_min = MIN(transid)
		FROM #BetsList		
		
		IF EXISTS (
			SELECT TOP (1) 1
			FROM dbo.bettrans b WITH(NOLOCK)
			WHERE b.recommend = @custid 
				AND b.transid >= @transid_min
				AND b.bettype = 9 
				AND b.matchid = 9
				AND b.statusID BETWEEN 0 AND 1	
		)
		INSERT INTO #BetList
		SELECT TOP(@LimitRowCount)
			9 AS matchid,
			b.Username,
			9 AS bettype,
			b.transid,
			b.refno,
			b.transdate,
			b.betid,
			0 AS livehomescore,
			0 AS liveawayscore,
			0 AS liveindicator,
			'' AS hdp1,
			'' AS hdp2,
			b.odds,
			b.stake,
			b.status,
			b.betteam,
			b.ip,
			b.oddstype			
		FROM dbo.bettrans b WITH(NOLOCK)
			INNER JOIN dbo.bettransm bm WITH(NOLOCK) ON b.refno = bm.refno
			INNER JOIN #tmpMatch m ON bm.matchid = m.matchid
		WHERE 
			b.recommend = @custid 
			AND b.transid >= @transid_min
			AND b.bettype = 9 
			AND b.matchid = 9
			AND b.statusID BETWEEN 0 AND 1				
		ORDER BY b.transid DESC
	
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
			b.STATUS,
			b.betteam,
			b.IP,
			0 AS isNeutral,
			b.oddstype		
		FROM #BetsList b
		ORDER BY b.transid DESC
			
		DROP TABLE #tmpMatch
		DROP TABLE #BetsList
END


GO
GRANT EXECUTE ON [dbo].[Age_Monitor_BetlistSoccerSel_Ag_AllBettypes] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_Monitor_BetlistSoccerSel_Ag_AllBettypes] TO [bodbDownlineNetView]
GO
GRANT VIEW DEFINITION ON [dbo].[Age_Monitor_BetlistSoccerSel_Ag_AllBettypes] TO [vnteam]