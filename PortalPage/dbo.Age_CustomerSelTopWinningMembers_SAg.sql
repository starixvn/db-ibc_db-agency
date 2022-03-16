/*<info serverAlias="DBAGE-bodb02" executers="bodbDownlineNet,bodbDownlineNetView" viewers="" isFunction="0" isNested="0"></info>*/
USE [bodb02]
GO

ALTER PROCEDURE [dbo].[Age_CustomerSelTopWinningMembers_SAg]
	@custid			INT,
	@BalanceUpDay	DATETIME,
	@MoveBetsDay	DATETIME
AS

/*
	Created: Johnson
	Date: 2011-05-31
	DB: DBAGE/BODB02
	Task: Get top highest winning members
	
	Revisions:	
		- 20130121@Dan: add linked server DBSUM for bodb_Summary
		- 20170503@Percy: add constraint winlostdate due to MB BU process [RedmineID: #75955]
		- 20181120@Percy: Remove linked-server DBSUM [RedmineID: #105170]
		- 20210505@Sol: NAP - Alpha - Allow more time for transfer - [Redmine: #149927]
		- 20211111@Evan: Split transfer tickets out of bettrans - [Redmine: #164196]
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @currentMonth DATETIME
	DECLARE @tmpStatistics TABLE(custid INT, winlost MONEY)

	DECLARE @tmpFromDate SMALLDATETIME, @tmpToDate SMALLDATETIME

	SELECT @currentMonth = CONVERT(VARCHAR(10),CURRENT_TIMESTAMP,120)
	SELECT @currentMonth = DATEADD(DAY,- DATEPART(DAY,@currentMonth)+ 1,@currentMonth)

	IF @currentMonth > @MoveBetsDay
		SELECT @tmpFromDate = @currentMonth
	ELSE
		SELECT @tmpFromDate = DATEADD(DAY, 1, @MoveBetsDay)

	INSERT INTO @tmpStatistics(custid, winlost)
	SELECT b.custid, ISNULL(SUM(winlost-actual_stake),0)
	FROM bettrans b with(nolock)	
	WHERE b.srecommend = @custid 
		AND b.winlostdate >= @tmpFromDate
		AND b.winlostdate > @moveBetsDay
		AND b.bettype < 19999
		AND b.statusID IN (111,112,113)
	GROUP BY b.custid

	IF @moveBetsDay >= @currentMonth
	BEGIN
		SELECT @tmpToDate = @MoveBetsDay

		IF @currentMonth >= @BalanceUpDay
			SELECT @tmpFromDate = @currentMonth
		ELSE
			SELECT @tmpFromDate = @BalanceUpDay

		INSERT INTO @tmpStatistics(custid, winlost)
		SELECT custid, SUM(winlost)
		FROM sum_winloss with(NOLOCK)
		WHERE srecommend = @custid and roleid = 1
			AND winlostdate BETWEEN @tmpFromDate AND @tmpToDate
		GROUP BY custid
	END

	IF @balanceUpDay >= @currentMonth 
	BEGIN
		SELECT @tmpToDate = DATEADD(DAY, -1, @BalanceUpDay)
		SELECT @tmpFromDate = @currentMonth

		INSERT INTO @tmpStatistics(custid, winlost)
		SELECT custid, SUM(winlost)
		FROM bodb_summary.dbo.sum_winloss_old WITH(NOLOCK)
		WHERE srecommend = @custid 
			AND roleid = 1
			AND winlostdate BETWEEN @tmpFromDate AND @tmpToDate
		GROUP BY custid 
	END

	;WITH tmp AS (
		SELECT TOP 10 custid, ISNULL(SUM(winlost),0) AS winlost
		FROM  @tmpStatistics
		GROUP BY custid
		HAVING ISNULL(SUM(winlost),0) > 0
		ORDER BY winlost DESC
	)
	SELECT tmp.custid, c.username, tmp.winlost
	FROM tmp
		INNER JOIN dbo.Customer c WITH(NOLOCK) ON tmp.custid = c.custid
END
GO