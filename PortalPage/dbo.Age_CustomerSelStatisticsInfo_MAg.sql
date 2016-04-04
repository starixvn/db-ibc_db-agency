ALTER PROCEDURE [dbo].[Age_CustomerSelStatisticsInfo_MAg]
	 @custid INT
AS
/*
	Created: Johnson
	Date: 2011-05-31
	DB: DBAGE/bodb02
	Task: Get Master Statictis Info 
	Revisions:
	- 20110819@Sophia: Count Negative stake as positive turnover
	- 20111017@Tom: 1. Add P2P Transfer (23101)/Outstanding (23102)
					2. Remove variable @ABSDate ('2011-09-01')
	- 20140305@Kathy: modify formula of Outstanding amount to be calculated based on table Bettrans AND TransLog [Redmine:#11550]
	- 20150707@Jim: exclude Metric Gaming running ticket from bettrans (Feature #38789
	- 20151214@Percy: exclude Cock Fighting running ticket from bettrans [Redmine: #48601]
	- 20160113@Percy: expand new bettype for RNG Casino [Redmine: #48283]
*/
SET NOCOUNT ON

DECLARE @roleid INT, 
		@Outstanding MONEY,
		@total_Outstanding MONEY,
		@total_csTransfer MONEY,
		@total_csOutstanding MONEY,
		@total_BITransfer MONEY,
		@total_BIOutstanding MONEY,
		@total_P2PTransfer MONEY,
		@total_P2POutstanding MONEY,		
		@total_memberActive INT,
		@total_memberClosed INT,
		@total_memberSuspended INT,
		@total_agentActive INT,
		@total_agentClosed INT,
		@total_agentSuspended INT,		
		@number_newMembers int,
		@CurrentMonth	DATETIME

DECLARE @translog_outstanding money, @translog_totalOutstanding money

SELECT @translog_outstanding      = ISNULL(SUM(mpositiontaking* ABS(actual_stake)),0),
	   @translog_totalOutstanding = ISNULL(SUM(ABS(actual_stake)),0)
FROM translog WITH(NOLOCK)
WHERE mrecommend = @custid AND statusid = 0

SELECT 
		@OutStanding          = ISNULL(SUM(mpositiontaking* ABS(actual_stake)),0) + @translog_outstanding,
		@total_outstanding    = ISNULL(SUM(ABS(actual_stake)),0) +@translog_totalOutstanding,
		@total_csTransfer     = ISNULL(SUM(CASE WHEN bettype = 23001 THEN actual_stake ELSE 0 END),0),
		@total_csOutstanding  = ISNULL(SUM(CASE WHEN bettype = 23002 THEN actual_stake ELSE 0 END),0),
		@total_BITransfer     = ISNULL(SUM(CASE WHEN bettype = 23201 THEN actual_stake ELSE 0 END),0),
		@total_BIOutstanding  = ISNULL(SUM(CASE WHEN bettype = 23202 THEN actual_stake ELSE 0 END),0),
		@total_P2PTransfer    = ISNULL(SUM(CASE WHEN bettype = 23101 THEN actual_stake ELSE 0 END),0),
		@total_P2POutstanding = ISNULL(SUM(CASE WHEN bettype = 23102 THEN actual_stake ELSE 0 END),0)		
FROM bettrans WITH(NOLOCK)
WHERE mrecommend = @custid AND ruben =0
	AND bettype NOT IN (801,802,803,804,805,806,1003)  -- Exlude Metric gaming, Cock Fighting from bettrans
	AND bettype NOT BETWEEN 2101 AND 2399 -- Exclude new bettype RNG Casino

SELECT 
		@OutStanding          = @OutStanding          + ISNULL(SUM(mpositiontaking* ABS(actual_stake)),0),
		@total_outstanding    = @total_outstanding    + ISNULL(SUM(ABS(actual_stake)),0)
FROM bettransRNG WITH(NOLOCK)
WHERE mrecommend = @custid
	AND statusID IN (0, 1)
	AND gameID BETWEEN 2101 AND 2399

SELECT @Total_memberActive    = ISNULL(SUM(CASE WHEN Closed = 0 AND ISNULL(reject,0) = 0 then 1 else 0 end), 0),
	   @Total_memberClosed    = ISNULL(SUM(CASE WHEN Closed = 1 THEN 1 ELSE 0 END), 0),
	   @Total_memberSuspended = ISNULL(SUM(CASE WHEN ISNULL(reject,0) = 1 AND Closed = 0 THEN 1 ELSE 0 END), 0)
FROM custinfo WITH(NOLOCK)
WHERE mrecommend = @custid AND roleid = 1

SELECT @Total_agentActive    = ISNULL(SUM(CASE WHEN Closed = 0 AND ISNULL(reject,0) = 0 THEN 1 ELSE 0 END), 0),
	   @Total_agentClosed    = ISNULL(SUM(CASE WHEN Closed = 1 THEN 1 ELSE 0 END), 0),
	   @Total_agentSuspended = ISNULL(SUM(CASE WHEN ISNULL(reject,0) = 1 AND Closed = 0 THEN 1 ELSE 0 END), 0)
FROM custinfo WITH(NOLOCK)
WHERE mrecommend = @custid AND roleid = 2

SELECT @currentMonth = CONVERT(DATE, GETDATE())
SELECT @currentMonth = DATEADD(DAY,- DATEPART(DAY,@currentMonth)+ 1,@currentMonth)

SELECT @number_newMembers = count(1)
FROM customer WITH(nolock)
WHERE mrecommend = @custid AND roleid = 1 AND creatdate >= @currentMonth


SELECT @OutStanding as outStanding,
		@total_Outstanding as total_outstanding,
		@total_csTransfer as total_csTransfer,
		@total_csOutstanding as total_csOutstanding,
		@total_BITransfer as total_BITransfer,
		@total_BIOutstanding as total_BIOutstanding,
		@total_P2PTransfer as total_P2PTransfer,
		@total_P2POutstanding as total_P2POutstanding,
		@total_memberActive as total_memberActive,
		@total_memberClosed as total_memberClosed,		
		@total_memberSuspended as total_memberSuspended,
		@total_agentActive as total_agentActive,
		@total_agentClosed as total_agentClosed,		
		@total_agentSuspended as total_agentSuspended,
		@number_newMembers as number_newMembers
GO
GRANT EXECUTE ON [dbo].[Age_CustomerSelStatisticsInfo_MAg] TO [bodbDownlineNet] AS [dbo]
GO
GRANT EXECUTE ON [dbo].[Age_CustomerSelStatisticsInfo_MAg] TO [bodbDownlineNetView] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[Age_CustomerSelStatisticsInfo_MAg] TO [vnteam] AS [dbo]
GO