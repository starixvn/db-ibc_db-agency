/*<info serverAlias="DBAGE-bodb02" executers="bodbDownlineNet,bodbDownlineNetView" viewers="" isFunction="0" isNested="0"></info>*/
USE [bodb02]
GO

ALTER PROCEDURE [dbo].[U3_Rpt_MatchWinLoss_Ag]
	@CustID   INT,
	@FromDate DATETIME,
	@ToDate   DATETIME	
AS

/*
	Created: 20150303@Sophia
	Task: U3 Report WinLoss By bettype - for Number game, Bingo, Live Casino
	DB: DBAGE/bodb02
	Original: Age_Rpt_MatchWinLoss_Ag

	Revisions:
		- 20170830@Percy: Integrate Lucky 3 [RedmineID: #76770]
		- 20210817@Sol: Allow more time to transfer (phase 2) - [RedmineID: #160019]
*/

BEGIN 
	SET NOCOUNT ON

	-- get move bet date
	DECLARE @balanceUpDay SMALLDATETIME, @moveBetsDay SMALLDATETIME
	DECLARE @tblMoveBetBalanceUp AS TABLE (BalanceUpDay SMALLDATETIME, MoveBetsDay SMALLDATETIME)

	INSERT INTO @tblMoveBetBalanceUp(BalanceUpDay,MoveBetsDay)
	EXEC bodb02.dbo.Age_SelBalanceUpDay

	SELECT @balanceUpDay = BalanceUpDay, @moveBetsDay = MoveBetsDay FROM @tblMoveBetBalanceUp
	----

	----Get Sport Bettype Matrix------
	DECLARE @ProductIds VARCHAR(MAX), @isTest BIT
	SELECT  @ProductIds = dbo.U3_f_GetProductList(), @isTest = dbo.f_CheckSPVersion(@@PROCID)

	DECLARE @SportBettype TABLE (ProductID INT, Bettype INT)
	INSERT INTO @SportBettype (ProductID, Bettype)
	SELECT ProductID, Bettype FROM dbo.f_SportBettypeMatrixByProduct_Sel (@ProductIds, @isTest)

	SELECT x.* ,isnull(x.isNeutral, CONVERT(BIT, 0)) AS IsNeutral
	FROM (
		SELECT m.matchid
			,m.homeid
			,m.awayid
			,b.bettype
			,b.liveindicator
			,m.isNeutral
			,m.matchcode
			,m.showtime
			,SUM(b.comm / (1 - b.apositiontaking)) AS GrossComm
			,SUM(comm - playercomm) AS commission
			,SUM(awinlost) AS positiontaking
		FROM bettrans b WITH (NOLOCK)
			INNER JOIN match m WITH (NOLOCK) ON m.matchid = b.matchid
			INNER JOIN @SportBettype s ON s.Bettype = b.bettype
		WHERE b.recommend = @custid			
			AND m.eventdate >= @fromdate
			AND m.eventdate <= @todate
			AND m.eventstatus = 'completed'
			AND isnull(m.betstatus, '') <> 'refund'
			AND s.ProductID IN (3) --- Number Game
			AND 1 = CASE 
						WHEN b.bettype = 19999 and winlostdate > @moveBetsDay THEN 0 --> get data from ticket detail
						WHEN b.bettype < 19999 and winlostdate <= @moveBetsDay THEN 0 --> get data from sum record
					ELSE 1 END
		GROUP BY m.matchid
			,m.homeid
			,m.awayid
			,m.matchcode
			,b.bettype
			,m.isNeutral
			,b.liveindicator
			,m.showtime	

		UNION ALL --- Not Number Game not Group By liveindicator	 
		SELECT m.matchid
			,m.homeid
			,m.awayid
			,b.bettype
			,0 AS liveindicator
			,m.isNeutral
			,m.matchcode
			,m.showtime
			,SUM(b.comm / (1 - b.apositiontaking)) AS GrossComm
			,SUM(comm - playercomm) AS commission
			,SUM(awinlost) AS positiontaking
		FROM bettrans b WITH (NOLOCK)
			INNER JOIN match m WITH (NOLOCK) ON m.matchid = b.matchid
			INNER JOIN @SportBettype s ON s.Bettype = b.bettype			 
		WHERE b.recommend = @custid
			AND m.eventdate >= @fromdate
			AND m.eventdate <= @todate
			AND m.eventstatus = 'completed'
			AND isnull(m.betstatus, '') <> 'refund'
			AND s.ProductID <> 3 -- Not Number Game
			AND 1 = CASE 
						WHEN b.bettype = 19999 and winlostdate > @moveBetsDay THEN 0 --> get data from ticket detail
						WHEN b.bettype < 19999 and winlostdate <= @moveBetsDay THEN 0 --> get data from sum record
					ELSE 1 END
		GROUP BY m.matchid
			,m.homeid
			,m.awayid
			,m.matchcode
			,b.bettype
			,m.isNeutral
			,m.showtime
	
		UNION ALL
			SELECT m.matchid
			,m.homeid
			,m.awayid
			,b.bettype
			,b.liveindicator
			,m.isNeutral
			,m.matchcode
			,m.showtime
			,SUM(b.comm / (1 - b.apositiontaking)) AS GrossComm
			,SUM(comm - playercomm) AS commission
			,SUM(awinlost) AS positiontaking
		FROM bettrans14 b WITH (NOLOCK)
			INNER JOIN match14 m WITH (NOLOCK) ON m.matchid = b.matchid
			INNER JOIN @SportBettype s ON s.Bettype = b.bettype
		WHERE b.recommend = @custid			
			AND m.eventdate >= @fromdate
			AND m.eventdate <= @todate
			AND m.eventstatus = 'completed'
			AND isnull(m.betstatus, '') <> 'refund'
			AND s.ProductID IN (3) --- Number Game
		GROUP BY m.matchid
			,m.homeid
			,m.awayid
			,m.matchcode
			,b.bettype
			,m.isNeutral
			,b.liveindicator
			,m.showtime	

		UNION ALL --- Not Number Game not Group By liveindicator	 
		SELECT m.matchid
			,m.homeid
			,m.awayid
			,b.bettype
			,0 AS liveindicator
			,m.isNeutral
			,m.matchcode
			,m.showtime
			,SUM(b.comm / (1 - b.apositiontaking)) AS GrossComm
			,SUM(comm - playercomm) AS commission
			,SUM(awinlost) AS positiontaking
		FROM bettrans14 b WITH (NOLOCK)
			INNER JOIN match14 m WITH (NOLOCK) ON m.matchid = b.matchid
			INNER JOIN @SportBettype s ON s.Bettype = b.bettype			 
		WHERE b.recommend = @custid
			AND m.eventdate >= @fromdate
			AND m.eventdate <= @todate
			AND m.eventstatus = 'completed'
			AND isnull(m.betstatus, '') <> 'refund'
			AND s.ProductID <> 3 -- Not Number Game
		GROUP BY m.matchid
			,m.homeid
			,m.awayid
			,m.matchcode
			,b.bettype
			,m.isNeutral
			,m.showtime
		) x
	ORDER BY x.showtime
END
GO