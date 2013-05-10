
ALTER PROCEDURE [dbo].[Age_CustomerSelStatisticsInfo_SAg]
	 @custid INT
AS
/*
	Created: Johnson
	Date: 2011-04-27
	DB: DB053.BODB02
	Task: Get Super Statictis Info 
	Revisions:
	- 20110819@Sophia: Count Negative stake as positive turnover
	- 20111017@Tom: 1. Add P2P Transfer (23101)/Outstanding (23102)
					2. Remove variable @ABSDate ('2011-09-01')	
	
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
		@total_masterActive INT,
		@total_masterClosed INT,
		@total_masterSuspended INT,
		@number_newMembers INT,
		@CurrentMonth	DATETIME	
		
/*DECLARE @ABSDate DATETIME
SET @ABSDate = '2011-09-01'*/

SELECT --@OutStanding = ISNULL(SUM(spositiontaking * CASE WHEN winlostdate >= @ABSDate THEN ABS(actual_stake) ELSE actual_stake END),0),
		@OutStanding = ISNULL(SUM(spositiontaking * ABS(actual_stake)),0),
		--@total_outstanding = ISNULL(SUM(CASE WHEN winlostdate >= @ABSDate THEN ABS(actual_stake) ELSE actual_stake END),0),
		@total_outstanding = ISNULL(SUM(ABS(actual_stake)),0),
		@total_csTransfer = ISNULL(SUM(CASE WHEN bettype = 23001 THEN actual_stake ELSE 0 END),0),
		@total_csOutstanding = ISNULL(SUM(CASE WHEN bettype IN (23002,23101) THEN actual_stake ELSE 0 END),0),
		@total_BITransfer = ISNULL(SUM(CASE WHEN bettype = 23201 THEN actual_stake ELSE 0 END),0),
		@total_BIOutstanding = ISNULL(SUM(CASE WHEN bettype = 23202 THEN actual_stake ELSE 0 END),0),
		@total_P2PTransfer = ISNULL(SUM(CASE WHEN bettype = 23101 THEN actual_stake ELSE 0 END),0),
		@total_P2POutstanding = ISNULL(SUM(CASE WHEN bettype = 23102 THEN actual_stake ELSE 0 END),0)		
FROM bettrans WITH(NOLOCK)
WHERE srecommend = @custid AND ruben =0 


SELECT @Total_memberActive = ISNULL(SUM(CASE WHEN Closed = 0 AND ISNULL(reject,0) = 0 THEN 1 ELSE 0 END), 0),
	@Total_memberClosed = ISNULL(SUM(CASE WHEN Closed = 1 THEN 1 ELSE 0 END), 0),
	@Total_memberSuspended = ISNULL(SUM(CASE WHEN ISNULL(reject,0) = 1 AND Closed = 0 THEN 1 ELSE 0 END), 0)
FROM custinfo WITH(NOLOCK)
WHERE srecommend = @custid AND roleid = 1


SELECT @Total_agentActive = ISNULL(SUM(CASE WHEN Closed = 0 AND ISNULL(reject,0) = 0 THEN 1 ELSE 0 END), 0),
	@Total_agentClosed = ISNULL(SUM(CASE WHEN Closed = 1 THEN 1 ELSE 0 END), 0),
	@Total_agentSuspended = ISNULL(SUM(CASE WHEN ISNULL(reject,0) = 1 AND Closed = 0 THEN 1 ELSE 0 END), 0)
FROM custinfo WITH(NOLOCK)
WHERE srecommend = @custid AND roleid = 2


SELECT @Total_masterActive = ISNULL(SUM(CASE WHEN Closed = 0 AND ISNULL(reject,0) = 0 THEN 1 ELSE 0 END), 0),
	@Total_masterClosed = ISNULL(SUM(CASE WHEN Closed = 1 THEN 1 ELSE 0 END), 0),
	@Total_masterSuspended = ISNULL(SUM(CASE WHEN ISNULL(reject,0) = 1 AND Closed = 0 THEN 1 ELSE 0 END), 0)
FROM custinfo WITH(NOLOCK)
WHERE srecommend = @custid AND roleid = 3


SELECT @currentMonth = CONVERT(VARCHAR(10),CURRENT_TIMESTAMP,120)
SELECT @currentMonth = DATEADD(DAY,- DATEPART(DAY,@currentMonth)+ 1,@currentMonth)

SELECT @number_newMembers = COUNT(1)
FROM customer WITH(NOLOCK)
WHERE srecommend = @custid AND roleid = 1 AND creatdate >= @currentMonth

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
		@total_masterActive as total_masterActive,
		@total_masterClosed as total_masterClosed,
		@total_masterSuspended as total_masterSuspended,
		@number_newMembers as number_newMembers

GO
GRANT EXECUTE ON [dbo].[Age_CustomerSelStatisticsInfo_SAg] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_CustomerSelStatisticsInfo_SAg] TO [bodbDownlineNetView]
GO
GRANT VIEW DEFINITION ON [dbo].[Age_CustomerSelStatisticsInfo_SAg] TO [vnteam]