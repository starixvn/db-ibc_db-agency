 
ALTER PROCEDURE [dbo].[Age_CustomerSelTopWinningMembers_MAg]
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
*/
SET NOCOUNT ON

DECLARE @currentMonth DATETIME
DECLARE @tmpStatistics TABLE(custid INT,username NVARCHAR(50),winlost MONEY)

SELECT @currentMonth = CONVERT(VARCHAR(10),CURRENT_TIMESTAMP,120)
SELECT @currentMonth = DATEADD(DAY,- DATEPART(DAY,@currentMonth)+ 1,@currentMonth)

INSERT INTO @tmpStatistics(custid, username, winlost)
SELECT b.custid, b.username, ISNULL(SUM( winlost-actual_stake),0)
FROM bettrans b WITH(NOLOCK)	
WHERE b.mrecommend = @custid 	
	AND b.winlostdate >= @currentMonth 
	AND b.ruben = 1
	AND b.bettype < 19999
	AND b.statusid NOT IN (101,102,103)
GROUP BY b.custid , b.username

IF @moveBetsDay >= @currentMonth
BEGIN
	INSERT INTO @tmpStatistics(custid, username, winlost)
	SELECT custid , username , SUM(winlost)
	FROM sum_winloss WITH(NOLOCK)
	WHERE mrecommend = @custid AND roleid = 1 AND winlostdate >= @currentMonth
	GROUP BY custid , username
END

IF @balanceUpDay >= @currentMonth 
BEGIN
	INSERT INTO @tmpStatistics(custid, username, winlost)
	SELECT custid , username , SUM(winlost)
	FROM DBSUM.bodb_summary.dbo.sum_winloss_old WITH(NOLOCK)
	WHERE mrecommend = @custid AND roleid = 1 AND winlostdate >= @currentMonth
	GROUP BY custid ,username 
END

SELECT TOP 10 custid , username , ISNULL(SUM(winlost),0) as winlost
FROM @tmpStatistics
GROUP BY custid , username
HAVING ISNULL(SUM(winlost),0) > 0
ORDER BY winlost DESC




GO
GRANT EXECUTE ON [dbo].[Age_CustomerSelTopWinningMembers_MAg] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_CustomerSelTopWinningMembers_MAg] TO [bodbDownlineNetView]
GO
GRANT VIEW DEFINITION ON [dbo].[Age_CustomerSelTopWinningMembers_MAg] TO [vnteam]