ALTER PROCEDURE Age_BetTypeSel   
	@Sporttype int = null,
	@custid INT 
AS    
/*    
Created:    
Task:    
DB: DB05.bodb02    
Original: Bet Types List For Monitor  
    
Revisions:     
 - 20101020@Simon: Get Bet Types List For Monitor.
 - 20101214@Johnson: get bettype which have ticket
Parameter's Explanation:
	@custid : agent login account
	
*/    
    
SET NOCOUNT ON    

DECLARE @roleid INT
CREATE TABLE #tmp(bettype int)

SELECT @roleid = roleid FROM customer WITH(NOLOCK) where custid = @custid

IF @roleid = 4
BEGIN
	IF @sporttype != 151
	BEGIN
		INSERT INTO #tmp
		SELECT distinct bettype 
		FROM bettrans b WITH(NOLOCK)
			INNER JOIN match m WITH(NOLOCK) ON b.matchid = m.matchid
		WHERE b.srecommend = @custid
			 AND b.ruben = 0
			 AND b.statusid IN (0,1)
			 AND m.sporttype = isnull(@sporttype,m.sporttype)
			 AND m.eventstatus != 'completed'
		
		--Mix Parlay
		INSERT INTO #tmp
		SELECT distinct b.bettype 
		FROM bettrans b WITH(NOLOCK)
			INNER JOIN bettransm bm WITH(NOLOCK) ON b.refno = bm.refno
			INNER JOIN match m WITH(NOLOCK) ON bm.matchid = m.matchid
		WHERE b.srecommend = @custid
			AND b.ruben = 0 
			AND b.bettype = 9
			AND b.statusid IN (0,1)
			AND m.sporttype = isnull(@sporttype,m.sporttype)
			AND m.eventstatus != 'completed'
		
		--Outright
		INSERT INTO #tmp
		SELECT distinct b.bettype 
		FROM bettrans b WITH(NOLOCK)
			INNER JOIN outright m WITH(NOLOCK) ON b.matchid = m.orid
			INNER JOIN league l WITH(NOLOCK) ON m.leagueid = l.leagueid 
		WHERE b.srecommend = @custid 
			AND b.ruben = 0 
			AND b.bettype = 10
			AND b.statusid IN (0,1)
			AND m.oddsstatus != 'completed'
			AND l.sporttype = isnull(@sporttype,l.sporttype)
	END
	ELSE IF @sporttype = 151
	BEGIN
		INSERT INTO #tmp
		SELECT distinct bettype 
		FROM bettrans b WITH(NOLOCK)
			INNER JOIN outright m WITH(NOLOCK) ON b.matchid = m.orid
			INNER JOIN league l WITH(NOLOCK) ON m.leagueid = l.leagueid 
		WHERE
			b.srecommend = @custid
			AND b.ruben = 0
			AND b.statusid IN (0,1)
			AND m.oddsstatus != 'completed'
			And l.sporttype = 151			
	END
END
ELSE IF @roleid = 3
BEGIN
	IF @sporttype != 151
	BEGIN
		INSERT INTO #tmp
		SELECT distinct bettype 
		FROM bettrans b WITH(NOLOCK)
			INNER JOIN match m WITH(NOLOCK) ON b.matchid = m.matchid
		WHERE b.mrecommend = @custid
			 AND b.ruben = 0
			 AND b.statusid IN (0,1)
			 AND m.sporttype = isnull(@sporttype,m.sporttype)
			 AND m.eventstatus != 'completed'
		
		--Mix Parlay
		INSERT INTO #tmp
		SELECT distinct b.bettype 
		FROM bettrans b WITH(NOLOCK)
			INNER JOIN bettransm bm WITH(NOLOCK) ON b.refno = bm.refno
			INNER JOIN match m WITH(NOLOCK) ON bm.matchid = m.matchid
		WHERE b.mrecommend = @custid
			AND b.ruben = 0 
			AND b.bettype = 9
			AND b.statusid IN (0,1)
			AND m.sporttype = isnull(@sporttype,m.sporttype)
			AND m.eventstatus != 'completed'
		
		--Outright
		INSERT INTO #tmp
		SELECT distinct b.bettype 
		FROM bettrans b WITH(NOLOCK)
			INNER JOIN outright m WITH(NOLOCK) ON b.matchid = m.orid
			INNER JOIN league l WITH(NOLOCK) ON m.leagueid = l.leagueid 
		WHERE b.mrecommend = @custid 
			AND b.ruben = 0 
			AND b.bettype = 10
			AND b.statusid IN (0,1)
			AND m.oddsstatus != 'completed'
			AND l.sporttype = isnull(@sporttype,l.sporttype)
	END
	ELSE IF @sporttype = 151
	BEGIN
		INSERT INTO #tmp
		SELECT distinct bettype 
		FROM bettrans b WITH(NOLOCK)
			INNER JOIN outright m WITH(NOLOCK) ON b.matchid = m.orid
			INNER JOIN league l WITH(NOLOCK) ON m.leagueid = l.leagueid 
		WHERE
			b.mrecommend = @custid
			AND b.ruben = 0
			AND b.statusid IN (0,1)
			AND m.oddsstatus != 'completed'
			And l.sporttype = 151			
	END
END
ELSE IF @roleid = 2
BEGIN
	IF @sporttype != 151
	BEGIN
		INSERT INTO #tmp
		SELECT distinct bettype 
		FROM bettrans b WITH(NOLOCK)
			INNER JOIN match m WITH(NOLOCK) ON b.matchid = m.matchid
		WHERE b.recommend = @custid
			 AND b.ruben = 0
			 AND b.statusid IN (0,1)
			 AND m.sporttype = isnull(@sporttype,m.sporttype)
			 AND m.eventstatus != 'completed'
		
		--Mix Parlay
		INSERT INTO #tmp
		SELECT distinct b.bettype 
		FROM bettrans b WITH(NOLOCK)
			INNER JOIN bettransm bm WITH(NOLOCK) ON b.refno = bm.refno
			INNER JOIN match m WITH(NOLOCK) ON bm.matchid = m.matchid
		WHERE b.recommend = @custid
			AND b.ruben = 0 
			AND b.bettype = 9
			AND b.statusid IN (0,1)
			AND m.sporttype = isnull(@sporttype,m.sporttype)
			AND m.eventstatus != 'completed'
		
		--Outright
		INSERT INTO #tmp
		SELECT distinct b.bettype 
		FROM bettrans b WITH(NOLOCK)
			INNER JOIN outright m WITH(NOLOCK) ON b.matchid = m.orid
			INNER JOIN league l WITH(NOLOCK) ON m.leagueid = l.leagueid 
		WHERE b.recommend = @custid 
			AND b.ruben = 0 
			AND b.bettype = 10
			AND b.statusid IN (0,1)
			AND m.oddsstatus != 'completed'
			AND l.sporttype = isnull(@sporttype,l.sporttype)
	END
	ELSE IF @sporttype = 151
	BEGIN
		INSERT INTO #tmp
		SELECT distinct bettype 
		FROM bettrans b WITH(NOLOCK)
			INNER JOIN outright m WITH(NOLOCK) ON b.matchid = m.orid
			INNER JOIN league l WITH(NOLOCK) ON m.leagueid = l.leagueid 
		WHERE
			b.recommend = @custid
			AND b.ruben = 0
			AND b.statusid IN (0,1)
			AND m.oddsstatus != 'completed'
			And l.sporttype = 151			
	END
END

SELECT distinct t.bettype,b.typenamee
FROM #tmp t
	INNER JOIN bettype b WITH(NOLOCK) ON t.bettype = b.typeid

DROP TABLE #tmp
GO
GRANT EXECUTE ON [dbo].Age_BetTypeSel TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].Age_BetTypeSel TO [bodbDownlineNetView]
GO
GRANT VIEW DEFINITION ON [dbo].Age_BetTypeSel TO [vnteam]
GO