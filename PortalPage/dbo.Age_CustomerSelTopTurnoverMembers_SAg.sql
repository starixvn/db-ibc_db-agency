 
ALTER PROCEDURE [dbo].[Age_CustomerSelTopTurnoverMembers_SAg]
	@custid			INT,
	@BalanceUpDay	DATETIME,
	@MoveBetsDay	DATETIME
AS
/*
	Created: Johnson
	Date: 2011-05-23
	DB: DBAGE/BODB02
	Task: Get top highest turnover members
	Revisions:
	- 20110819@Sophia: Count Negative stake as positive turnover
	- 20130121@Dan: add linked server DBSUM for bodb_Summary
*/
SET NOCOUNT ON

DECLARE @currentMonth DATETIME
DECLARE @tmpStatistics TABLE(custid INT,username NVARCHAR(50), turnover MONEY)

DECLARE @ABSDate DATETIME
SET @ABSDate = '2011-09-01'	

SELECT @currentMonth = CONVERT(VARCHAR(10),CURRENT_TIMESTAMP,120)
SELECT @currentMonth = DATEADD(DAY,- DATEPART(DAY,@currentMonth)+ 1,@currentMonth)

INSERT INTO @tmpStatistics(custid, username, turnover)
SELECT b.custid, b.username,ISNULL(SUM( CASE WHEN winlostdate >= @ABSDate  
										THEN CASE WHEN b.bettype = 33 AND liveawayscore = 0 THEN ABS(stake)/2 ELSE ABS(stake) END
										ELSE CASE WHEN b.bettype = 33 AND liveawayscore = 0 THEN stake/2 ELSE stake END
										END
										)
								    ,0)
FROM bettrans b with(nolock)	
WHERE b.srecommend = @custid 	
	AND b.winlostdate >= @currentMonth 
	AND b.bettype < 19999 
	AND b.statusid NOT IN (101,102,103)
GROUP BY b.custid , b.username

IF @moveBetsDay >= @currentMonth
BEGIN
	INSERT INTO @tmpStatistics(custid, username, turnover)
	SELECT custid , username , SUM(CASE WHEN winlostdate >= @ABSDate THEN ABS(turnover) ELSE turnover END) as turnover
	FROM sum_winloss WITH(NOLOCK)
	WHERE srecommend = @custid
		AND roleid = 1 
		AND winlostdate >= @currentMonth
	GROUP BY custid , username
END

IF @balanceUpDay >= @currentMonth 
BEGIN
	INSERT INTO @tmpStatistics(custid, username, turnover)
	SELECT custid , username , SUM(CASE WHEN winlostdate >= @ABSDate THEN ABS(turnover) ELSE turnover END) as turnover
	FROM DBSUM.bodb_summary.dbo.sum_winloss_old WITH(NOLOCK)
	WHERE srecommend = @custid
		AND roleid = 1
		AND winlostdate >= @currentMonth
	GROUP BY custid ,username 
END

SELECT TOP 10 custid , username , ISNULL(SUM(turnover),0) as turnover
FROM @tmpStatistics
GROUP BY custid , username
ORDER BY turnover DESC




GO
GRANT EXECUTE ON [dbo].[Age_CustomerSelTopTurnoverMembers_SAg] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_CustomerSelTopTurnoverMembers_SAg] TO [bodbDownlineNetView]
GO
GRANT VIEW DEFINITION ON [dbo].[Age_CustomerSelTopTurnoverMembers_SAg] TO [vnteam]