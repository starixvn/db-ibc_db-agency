/*<info serverAlias="DBAGE-bodb02" executers="bodbDownlineNet,bodbDownlineNetView" viewers="vnteam" isFunction="0" isNested="0"></info>*/

USE [bodb02]
GO
  
ALTER PROCEDURE [dbo].[Age_CustomerSelTopTurnoverMembers_MAg]
	@custid			INT,
	@BalanceUpDay	DATETIME,
	@MoveBetsDay	DATETIME
AS

/*
	Created: Johnson
	Date: 2011-05-31
	DB: DBAGE/BODB02
	Task: Get top highest turnover members
	Revisions:
	- 20110819@Sophia: Count Negative stake as positive turnover
	- 20130121@Dan: add linked server DBSUM for bodb_Summary
	- 20170503@Percy: add constraint winlostdate due to MB BU process [RedmineID: #75955]
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @currentMonth DATETIME		
	DECLARE @tmpStatistics TABLE(custid INT, turnover MONEY)

	DECLARE @tmpFromDate SMALLDATETIME, @tmpToDate SMALLDATETIME

	DECLARE @ABSDate DATETIME
	SET @ABSDate = '2011-09-01'

	SELECT @currentMonth = CONVERT(VARCHAR(10),CURRENT_TIMESTAMP,120)
	SELECT @currentMonth = DATEADD(DAY,- DATEPART(DAY,@currentMonth)+ 1,@currentMonth)

	IF @currentMonth > @MoveBetsDay
		SELECT @tmpFromDate = @currentMonth
	ELSE
		SELECT @tmpFromDate = DATEADD(DAY, 1, @MoveBetsDay)

	INSERT INTO @tmpStatistics(custid, turnover)
	SELECT b.custid, ISNULL(SUM( CASE WHEN winlostdate >= @ABSDate  
											THEN CASE WHEN b.bettype = 33 AND liveawayscore = 0 THEN ABS(stake)/2 ELSE ABS(stake) END
											ELSE CASE WHEN b.bettype = 33 AND liveawayscore = 0 THEN stake/2 ELSE stake END
											END
											)
										,0)

	FROM bettrans b with(nolock)	
	WHERE b.mrecommend = @custid AND b.winlostdate >= @tmpFromDate
		AND b.bettype < 19999 AND b.statusid NOT IN (101,102,103) AND b.ruben = 1
	GROUP BY b.custid, b.username -- dont remove username due to performance

	IF @moveBetsDay >= @currentMonth
	BEGIN
		SELECT @tmpToDate = @MoveBetsDay

		IF @currentMonth >= @BalanceUpDay
			SELECT @tmpFromDate = @currentMonth
		ELSE
			SELECT @tmpFromDate = @BalanceUpDay

		INSERT INTO @tmpStatistics(custid, turnover)
		SELECT custid, SUM(CASE WHEN winlostdate >= @ABSDate THEN ABS(turnover) ELSE turnover END) as turnover
		FROM sum_winloss with(NOLOCK)
		WHERE mrecommend = @custid AND roleid = 1
			AND winlostdate BETWEEN @tmpFromDate AND @tmpToDate
		GROUP BY custid
	END

	IF @balanceUpDay >= @currentMonth 
	BEGIN
		SELECT @tmpToDate = DATEADD(DAY, -1, @BalanceUpDay)
		SELECT @tmpFromDate = @currentMonth

		INSERT INTO @tmpStatistics(custid, turnover)
		SELECT custid, SUM(CASE WHEN winlostdate >= @ABSDate THEN ABS(turnover) ELSE turnover END) as turnover
		FROM DBSUM.bodb_summary.dbo.sum_winloss_old WITH(nolock)
		WHERE mrecommend = @custid AND roleid = 1
			AND winlostdate BETWEEN @tmpFromDate AND @tmpToDate
		GROUP BY custid 
	END

	;WITH tmp AS (
		SELECT TOP 10 custid, SUM(turnover) AS turnover
		FROM  @tmpStatistics
		GROUP BY custid
		ORDER BY turnover DESC
	)
	SELECT tmp.custid, c.username, tmp.turnover
	FROM tmp
		INNER JOIN dbo.Customer c WITH(NOLOCK) ON tmp.custid = c.custid
END
GO