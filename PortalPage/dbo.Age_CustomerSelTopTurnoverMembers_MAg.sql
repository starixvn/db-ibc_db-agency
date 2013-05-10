  
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
*/
SET NOCOUNT ON

DECLARE @currentMonth DATETIME		
DECLARE @tmpStatistics TABLE(custid INT,username nvarchar(50), turnover MONEY, winlost MONEY)

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
WHERE b.mrecommend = @custid AND b.winlostdate >= @currentMonth 
and b.bettype < 19999 AND b.statusid NOT IN (101,102,103)
GROUP BY b.custid , b.username

IF @moveBetsDay >= @currentMonth
BEGIN
	INSERT INTO @tmpStatistics(custid, username, turnover)
	SELECT custid , username , SUM(CASE WHEN winlostdate >= @ABSDate THEN ABS(turnover) ELSE turnover END) as turnover
	FROM sum_winloss with(NOLOCK)
	WHERE mrecommend = @custid AND roleid = 1 AND winlostdate >= @currentMonth
	GROUP BY custid , username
END

IF @balanceUpDay >= @currentMonth 
BEGIN
	INSERT INTO @tmpStatistics(custid, username, turnover)
	SELECT custid , username , SUM(CASE WHEN winlostdate >= @ABSDate THEN ABS(turnover) ELSE turnover END) as turnover
	FROM DBSUM.bodb_summary.dbo.sum_winloss_old WITH(nolock)
	WHERE mrecommend = @custid AND roleid = 1 AND winlostdate >= @currentMonth
	GROUP BY custid ,username 
END

SELECT TOP 10 custid , username , SUM(turnover) AS turnover
FROM  @tmpStatistics
GROUP BY custid , username
ORDER BY turnover DESC



GO
GRANT EXECUTE ON [dbo].[Age_CustomerSelTopTurnoverMembers_MAg] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_CustomerSelTopTurnoverMembers_MAg] TO [bodbDownlineNetView]
GO
GRANT VIEW DEFINITION ON [dbo].[Age_CustomerSelTopTurnoverMembers_MAg] TO [vnteam]