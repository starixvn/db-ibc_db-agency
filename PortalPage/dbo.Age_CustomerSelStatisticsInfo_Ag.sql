ALTER PROCEDURE [dbo].[Age_CustomerSelStatisticsInfo_Ag]
	 @custid INT
AS
/*
	Created: Johnson
	Date: 2011-05-31
	DB: DBAGE/bodb02
	Task: Get Agent Statictis Info 
	Revisions:
	- 20110819@Sophia: Count Negative stake as positive turnover
	- 20111017@Tom: 1. Add P2P Transfer (23101)/Outstanding (23102)
					2. Remove variable @ABSDate ('2011-09-01')	
	- 20140305@Kathy: modify formula of Outstanding amount to be calculated based on table Bettrans and TransLog [Redmine:#11550]
	- 20150707@Jim: exclude Metric Gaming running ticket from bettrans (Feature #38789
	- 20151214@Percy: exclude Cock Fighting running ticket from bettrans [Redmine: #48601]
	- 20160113@Percy: expand new bettype for RNG Casino [Redmine: #48283]
	- 20160318@Percy: Support AllBet [Redmine: #50605]
	- 20160413@Percy: Support Voidbridge single wallet [Redmine: #55259]
	- 20161003@Sophia: Remove redundant info of CS, BI, P2P [Redmine: #64636]
*/
SET NOCOUNT ON

DECLARE @roleid INT, 
		@Outstanding MONEY,
		@total_Outstanding MONEY,				
		@total_memberActive INT,
		@total_memberClosed INT,
		@total_memberSuspended INT,
		@number_newMembers INT,				
		@CurrentMonth	DATETIME

DECLARE @today DATE,
		@yesterday DATE
SELECT @today = CONVERT(DATE, GETDATE())
SELECT @yesterday = DATEADD(DD, -1, @today)

SELECT @currentMonth = convert(varchar(10),current_timestamp,120)
SELECT @currentMonth = dateadd(day,- datepart(day,@currentMonth)+ 1,@currentMonth)

DECLARE @translog_outstanding money, @translog_totalOutstanding money

SELECT @translog_outstanding      = ISNULL(SUM(apositiontaking* ABS(actual_stake)),0),
	   @translog_totalOutstanding = ISNULL(SUM(ABS(actual_stake)),0)
FROM translog with(NOLOCK)
WHERE recommend = @custid AND statusid = 0

SELECT 
		@OutStanding          = ISNULL(SUM(apositiontaking* ABS(actual_stake)),0) + @translog_outstanding,
		@total_outstanding    = ISNULL(SUM(ABS(actual_stake)),0) + @translog_totalOutstanding		
FROM bettrans WITH(NOLOCK)
WHERE recommend = @custid AND ruben = 0 
		AND bettype NOT IN (801,802,803,804,805,806,1003) -- Exclude Metric gaming, Cockfighting from bettrans
		AND bettype NOT BETWEEN 2101 AND 2499 -- Exclude new bettype RNG Casino + Allbet
		AND bettype NOT BETWEEN 4001 AND 7999 -- Voidbridge

SELECT  
		@OutStanding       = @OutStanding       + ISNULL(SUM(apositiontaking* ABS(actual_stake)),0),
		@total_outstanding = @total_outstanding + ISNULL(SUM(ABS(actual_stake)),0)
FROM bettransRNG WITH(NOLOCK)
WHERE recommend = @custid AND statusID IN (0, 1)
	AND (gameID BETWEEN 2101 AND 2399 OR gameID BETWEEN 4001 AND 7999)

SELECT  
		@OutStanding       = @OutStanding       + ISNULL(SUM(apositiontaking* ABS(actual_stake)),0),
		@total_outstanding = @total_outstanding + ISNULL(SUM(ABS(actual_stake)),0)
FROM bettransLC WITH(NOLOCK)
WHERE recommend = @custid AND statusID IN (0, 1)
	AND gameID BETWEEN 2401 AND 2499
			 
SELECT @Total_memberActive = ISNULL(SUM(CASE WHEN Closed = 0 AND ISNULL(reject,0) = 0 THEN 1 ELSE 0 END), 0),
	@Total_memberClosed = ISNULL(SUM(CASE WHEN Closed = 1 THEN 1 ELSE 0 END), 0),
	@Total_memberSuspended = ISNULL(SUM(CASE WHEN ISNULL(reject,0) = 1 AND Closed = 0 tHEN 1 ELSE 0 END), 0)
FROM custinfo WITH(NOLOCK)
WHERE recommend = @custid AND roleid = 1

SELECT @number_newMembers = count(1)
	FROM customer with(nolock)
	WHERE recommend = @custid and roleid = 1 and creatdate >= @currentMonth
	
SELECT @OutStanding AS outStanding,
		@total_Outstanding AS total_outstanding,				
		@total_memberActive AS total_memberActive,
		@total_memberClosed AS total_memberClosed,
		@total_memberSuspended AS total_memberSuspended,
		@number_newMembers AS number_newMembers
GO
GRANT EXECUTE ON [dbo].[Age_CustomerSelStatisticsInfo_Ag] TO [bodbDownlineNet] AS [dbo]
GO
GRANT EXECUTE ON [dbo].[Age_CustomerSelStatisticsInfo_Ag] TO [bodbDownlineNetView] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[Age_CustomerSelStatisticsInfo_Ag] TO [vnteam] AS [dbo]
GO