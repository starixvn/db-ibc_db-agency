/*<info serverAlias="DBAGE-bodb02" executers="bodbDownlineNet,bodbDownlineNetView" isFunction="0" isNested="0"></info>*/
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
		- 20210823@Sol: Alpha - Allow more time to transfer (phase 2b) - [RedmineID: #160440]
		- 20211103@Evan: NapU3 - Report Match Win Loss does not show data range 14 - [RedmineID: #164178]
		- 20211123@Percy: Fix divide by 0 [RedmineID: #164854]
*/

BEGIN 
	SET NOCOUNT ON

	DECLARE @moveBetsDay SMALLDATETIME, @balanceUpDay SMALLDATETIME
	DECLARE @tblMoveBetBalanceUp AS TABLE (BalanceUpDay SMALLDATETIME, MoveBetsDay SMALLDATETIME)

	INSERT INTO @tblMoveBetBalanceUp(BalanceUpDay,MoveBetsDay)
	EXEC bodb02.dbo.Age_SelBalanceUpDay
	
	SELECT @moveBetsDay = MoveBetsDay, @balanceUpDay = BalanceUpDay FROM @tblMoveBetBalanceUp

	DECLARE @FDate SMALLDATETIME, @TDate SMALLDATETIME, @FDate14 SMALLDATETIME, @TDate14 SMALLDATETIME
	SELECT @FDate = @FromDate, @TDate = @ToDate	

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
			,SUM(ISNULL(b.comm / NULLIF(1 - b.apositiontaking, 0), 0)) AS GrossComm
			,SUM(comm - playercomm) AS commission
			,SUM(awinlost) AS positiontaking
		FROM bettrans b WITH (NOLOCK)
			INNER JOIN match m WITH (NOLOCK) ON m.matchid = b.matchid
			INNER JOIN @SportBettype s ON s.Bettype = b.bettype
		WHERE b.recommend = @custid			
			AND b.winlostdate BETWEEN @FDate AND @TDate
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
			,SUM(ISNULL(b.comm / NULLIF(1 - b.apositiontaking, 0), 0)) AS GrossComm
			,SUM(comm - playercomm) AS commission
			,SUM(awinlost) AS positiontaking
		FROM bettrans b WITH (NOLOCK)
			INNER JOIN match m WITH (NOLOCK) ON m.matchid = b.matchid
			INNER JOIN @SportBettype s ON s.Bettype = b.bettype			 
		WHERE b.recommend = @custid
			AND b.winlostdate BETWEEN @FDate AND @TDate
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
	
		UNION ALL
			SELECT m.matchid
			,m.homeid
			,m.awayid
			,b.bettype
			,b.liveindicator
			,m.isNeutral
			,m.matchcode
			,m.showtime
			,SUM(ISNULL(b.comm / NULLIF(1 - b.apositiontaking, 0), 0)) AS GrossComm
			,SUM(comm - playercomm) AS commission
			,SUM(awinlost) AS positiontaking
		FROM bettrans14 b WITH (NOLOCK)
			INNER JOIN match14 m WITH (NOLOCK) ON m.matchid = b.matchid
			INNER JOIN @SportBettype s ON s.Bettype = b.bettype
		WHERE b.recommend = @custid			
			AND b.winlostdate BETWEEN @FDate14 AND @TDate14
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
			,SUM(ISNULL(b.comm / NULLIF(1 - b.apositiontaking, 0), 0)) AS GrossComm
			,SUM(comm - playercomm) AS commission
			,SUM(awinlost) AS positiontaking
		FROM bettrans14 b WITH (NOLOCK)
			INNER JOIN match14 m WITH (NOLOCK) ON m.matchid = b.matchid
			INNER JOIN @SportBettype s ON s.Bettype = b.bettype			 
		WHERE b.recommend = @custid
			AND b.winlostdate BETWEEN @FDate14 AND @TDate14
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