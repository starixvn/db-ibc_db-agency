/*<info serverAlias="DBAGE-bodb02" executers="bodbAdminNet,bodbDownlineNet,bodbDownlineNetView" viewers="" isFunction="0" isNested="0"></info>*/
USE [bodb02]
GO

ALTER PROCEDURE [dbo].[Age_Rpt_MatchWinLoss_Ag]
	@CustID		INT
	,@FromDate	DATETIME
	,@ToDate	DATETIME	
AS

/*
Created: 
Task : 
DB: DBAGE.bodb02
Original:EnglishAgentSelMatchWinLoss
Revisions:
    - 20090326@Nqminh: get indexname for FI
    - 20090401@Hanh: exclude the refund match(isnull(m.betstatus,'')<>'refund')
    - 20090417@Nqminh: remove Indexname
    - 20090702@AnhPham: include gross commission information
	- 20091126@Jamie: Change the gross commission by level (super/master/agent)
		+ super  = scomm/(1 - tpos)
		+ master = acomm/(1 - apos - mpos)
		+ agent  = comm /(1 - apos)
		Applied on Dec 1, 2009 
	- 20091211@Jamie: Show Casino grosscomm instead of 0 
	- 20101105@Jacob: Add column matchcode, using for number game
	- 20110516@Johnson: Apply new arrange bettype
	- 20110802@Sophia: Add new column liveindicator to separate Fulltime or Deadball, but only for Number Game, if not Number Game not group by liveindicator and return 0 for liveindicator
	- 20120203@Sophia: Add show time for Table- Hand- Shoe For Live Casinio
	- 20120628@Elodie: exclude outright, HR from sportbook ( in case of matchid = orid)
	- 20130312@Elodie: exclude Virtual HR from sportbook
	- 20140926@Sophia: Grouping duplicate bettypes of Sporting Solution and IBC [Redmine: #23444]
	- 20150310@Cody: Apply sport bettype matrix [Redmine: #30169]
	- 20160712@Percy: Using inline function for SportBettypeMatrix [RedmineID: #53152]
	- 20210823@Sol: Alpha - Allow more time to transfer (phase 2b) - [RedmineID: #160440]
	- 20211103@Evan: NapU3 - Report Match Win Loss does not show data range 14 - [RedmineID: #164178]
*/

SET NOCOUNT ON

DECLARE @moveBetsDay SMALLDATETIME, @balanceUpDay SMALLDATETIME
DECLARE @tblMoveBetBalanceUp AS TABLE (BalanceUpDay SMALLDATETIME, MoveBetsDay SMALLDATETIME)

INSERT INTO @tblMoveBetBalanceUp(BalanceUpDay,MoveBetsDay)
EXEC bodb02.dbo.Age_SelBalanceUpDay
	
SELECT @moveBetsDay = MoveBetsDay, @balanceUpDay = BalanceUpDay FROM @tblMoveBetBalanceUp

DECLARE @FDate SMALLDATETIME, @TDate SMALLDATETIME, @FDate14 SMALLDATETIME, @TDate14 SMALLDATETIME
SELECT @FDate = @FromDate, @TDate = @ToDate	

DECLARE @isTest BIT
SELECT  @isTest = dbo.f_CheckSPVersion(@@PROCID)

CREATE TABLE #SportBettype (ProductID INT, Bettype INT, EventType INT)
INSERT INTO #SportBettype (ProductID, Bettype, EventType)
SELECT ProductID, Bettype, EventType FROM dbo.f_SportBettypeMatrix_Sel (0, 0, 0, 2, '', '', @isTest)

IF @FromDate <= @MoveBetsDay
BEGIN
	SET @FDate = DATEADD(DD, 1, @MoveBetsDay);
END

IF @BalanceUpDay < @FromDate
BEGIN
	SET @FDate14 = @FromDate;
END
ELSE
BEGIN
	SET @FDate14 = @BalanceUpDay;
END
		
IF @ToDate > @MoveBetsDay
BEGIN
	SET @TDate14 = @MoveBetsDay;
END
ELSE
BEGIN
	SET @TDate14 = @ToDate;
END	
SELECT x.*, ISNULL(x.isNeutral, CONVERT(BIT, 0)) AS IsNeutral
FROM
(
	SELECT
		m.matchid
		,m.homeid
		,m.awayid
		,b.bettype
		,b.liveindicator
		,m.isNeutral
		,m.matchcode
		,m.showtime
		,SUM(b.comm/(1 - b.apositiontaking)) AS GrossComm
		,SUM(comm - playercomm) AS  commission
		,SUM(awinlost) AS  positiontaking		
	FROM 
		bettrans b WITH (NOLOCK)		
		INNER JOIN match m WITH (NOLOCK) ON m.matchid = b.matchid
		INNER JOIN #SportBettype s ON b.bettype = s.Bettype
	WHERE 
		b.recommend = @custid
		AND b.winlostdate BETWEEN @FDate AND @TDate
		AND m.eventstatus = 'completed'
		AND ISNULL(m.betstatus, '') <> 'refund'
		AND s.ProductID = 3
	GROUP BY 
		m.matchid, m.homeid, m.awayid, m.matchcode, b.bettype, m.isNeutral, b.liveindicator, m.showtime

	UNION ALL --- Not Number Game not Group By liveindicator
	SELECT
		b.matchid
		,b.homeid
		,b.awayid
		,b.bettype
		,0 AS liveindicator
		,b.isNeutral
		,b.matchcode
		,b.showtime
		,SUM(b.comm/(1 - b.apositiontaking)) AS GrossComm
		,SUM(b.comm - b.playercomm) AS Commission
		,SUM(b.awinlost) AS Positiontaking		
	FROM (
			SELECT
				m.matchid
				,m.homeid
				,m.awayid
				,CASE WHEN ISNULL(f.bettype, 0) = 0 THEN b.bettype ELSE f.GroupTypeId END AS bettype
				,m.isNeutral
				,m.matchcode
				,m.showtime
				,b.comm
				,b.apositiontaking
				,b.playercomm
				,b.awinlost	
			FROM 
				bettrans b	WITH (NOLOCK)		
				INNER JOIN match m 	WITH (NOLOCK) ON m.matchid = b.matchid 	
				LEFT JOIN (SELECT * FROM [dbo].[f_GroupBettype] ()) f ON f.bettype = b.bettype
				INNER JOIN #SportBettype s ON b.bettype = s.Bettype
			WHERE 
				b.recommend = @custid
				AND b.winlostdate BETWEEN @FDate AND @TDate
				AND m.eventstatus = 'completed'
				AND ISNULL(m.betstatus, '') <> 'refund'
				AND s.ProductID <> 3
				AND s.EventType NOT IN (2, 3)
			) b	 		
	GROUP BY b.matchid, b.homeid, b.awayid, b.matchcode, b.bettype, b.isNeutral, b.showtime
				
	UNION ALL
	SELECT
		m.matchid
		,m.homeid
		,m.awayid
		,b.bettype
		,b.liveindicator
		,m.isNeutral
		,m.matchcode
		,m.showtime
		,SUM(b.comm/(1 - b.apositiontaking)) AS GrossComm
		,SUM(comm - playercomm) AS  commission
		,SUM(awinlost) AS  positiontaking
	FROM 
		bettrans14 b WITH (NOLOCK)		
		INNER JOIN match14 m WITH (NOLOCK) ON m.matchid = b.matchid 
		INNER JOIN #SportBettype s ON b.bettype = s.Bettype
	WHERE 
		b.recommend = @custid
		AND b.winlostdate BETWEEN @FDate14 AND @TDate14
		AND m.eventstatus = 'completed'  
		AND ISNULL(m.betstatus, '') <> 'refund' 
		AND S.ProductID = 3
	GROUP BY 
		m.matchid, m.homeid, m.awayid, m.matchcode, b.bettype, m.isNeutral, b.liveindicator, m.showtime

	UNION ALL --- Not Number Game not Group By liveindicator
	SELECT
		b.matchid
		,b.homeid
		,b.awayid
		,b.bettype
		,0 AS liveindicator
		,b.isNeutral
		,b.matchcode
		,b.showtime
		,SUM(b.comm/(1 - b.apositiontaking)) AS GrossComm
		,SUM(b.comm - b.playercomm) AS Commission
		,SUM(b.awinlost) AS Positiontaking		
	FROM (
			SELECT
				m.matchid
				,m.homeid
				,m.awayid
				,CASE WHEN ISNULL(f.bettype, 0) = 0 THEN b.bettype ELSE f.GroupTypeId END AS bettype
				,m.isNeutral
				,m.matchcode
				,m.showtime
				,b.comm
				,b.apositiontaking
				,b.playercomm
				,b.awinlost	
			FROM 
				bettrans14 b WITH (NOLOCK)		
				INNER JOIN match14 m WITH (NOLOCK) ON m.matchid = b.matchid 	
				LEFT JOIN (SELECT * FROM [dbo].[f_GroupBettype]()) f ON f.bettype = b.bettype
				INNER JOIN #SportBettype s ON b.bettype = s.Bettype
			WHERE 
				b.recommend = @custid
				AND b.winlostdate BETWEEN @FDate14 AND @TDate14
				AND m.eventstatus = 'completed' 
				AND ISNULL(m.betstatus, '') <> 'refund'
				AND s.ProductID <> 3
				AND s.EventType NOT IN (2, 3)
			) b	 		
	GROUP BY b.matchid, b.homeid, b.awayid, b.matchcode, b.bettype, b.isNeutral, b.showtime
	) x
	ORDER BY x.showtime

	DROP TABLE #SportBettype

GO