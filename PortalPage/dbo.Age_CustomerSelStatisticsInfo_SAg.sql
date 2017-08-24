/*<info serverAlias="DBAGE-bodb02" executers="bodbDownlineNet,bodbDownlineNetView" viewers="vnteam" isFunction="0" isNested="0"></info>*/
USE [bodb02]
GO

ALTER PROCEDURE [dbo].[Age_CustomerSelStatisticsInfo_SAg]
	 @custid INT
AS
/*
	Created: Johnson
	Date: 2011-04-27
	DB: DBAGE/bodb02
	Task: Get Super Statictis Info 
	Revisions:
	- 20110819@Sophia: Count Negative stake as positive turnover
	- 20111017@Tom: 1. Add P2P Transfer (23101)/Outstanding (23102)
					2. Remove variable @ABSDate ('2011-09-01')	
	- 20140305@Kathy: modify formula of Outstanding amount to be calculated based on table Bettrans and TransLog [Redmine:#11550]
	- 20150707@Jim: exclude Metric Gaming running ticket from bettrans (Feature #38789)
	- 20151214@Percy: exclude Cock Fighting running ticket from bettrans [Redmine: #48601]
	- 20160113@Percy: expand new bettype for RNG Casino [Redmine: #48283]
	- 20160318@Percy: Support AllBet [Redmine: #50605]
	- 20160413@Percy: Support Voidbridge single wallet [Redmine: #55259]
	- 20161003@Sophia: Remove redundant info of CS, BI, P2P [Redmine: #64636]
	- 20161028@Percy: Support Fishing World [RedmineID: #65731]
*/
SET NOCOUNT ON

-- SportBettypeMatrix
DECLARE @isTest BIT
SELECT  @isTest = dbo.f_CheckSPVersion(@@PROCID)

CREATE TABLE #SportBettype (ProductID INT, bettype INT, RefTable TINYINT)
INSERT INTO #SportBettype (ProductID, bettype, RefTable)
SELECT ProductID, bettype, RefTable FROM dbo.f_SportBettypeMatrix_Sel(0,0,0,2,'','',@isTest)

DECLARE @roleid INT, 
		@Outstanding MONEY,
		@total_Outstanding MONEY,			
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

DECLARE @translog_outstanding money, @translog_totalOutstanding money

SELECT @translog_outstanding      = ISNULL(SUM(spositiontaking* ABS(actual_stake)),0),
	   @translog_totalOutstanding = ISNULL(SUM(ABS(actual_stake)),0)
FROM translog with(NOLOCK)
WHERE srecommend = @custid AND statusid = 0

SELECT 
		@OutStanding          = ISNULL(SUM(spositiontaking * ABS(actual_stake)),0) + @translog_outstanding,
		@total_outstanding    = ISNULL(SUM(ABS(actual_stake)),0) + @translog_totalOutstanding			
FROM bettrans WITH(NOLOCK)
WHERE srecommend = @custid AND ruben =0
	AND bettype NOT IN (SELECT bettype FROM #SportBettype WHERE RefTable <> 0)
	/*
	AND bettrans.bettype NOT IN (801,802,803,804,805,806,1003) -- Exlude Metric gaming, Cock Fighting from bettrans
	AND bettype NOT BETWEEN 2101 AND 2499 -- Exclude new bettype RNG Casino + Allbet
	AND bettype NOT BETWEEN 4001 AND 7999 -- Voidbridge
	*/

SELECT 
		@Outstanding          = @Outstanding          + ISNULL(SUM(spositiontaking * ABS(actual_stake)),0),
		@total_outstanding    = @total_outstanding    + ISNULL(SUM(ABS(actual_stake)),0)		
FROM bettransRNG WITH(NOLOCK)
WHERE srecommend = @custid
	AND statusID IN (0, 1)
	--AND (gameID BETWEEN 2101 AND 2399 OR gameID BETWEEN 4001 AND 7999)

SELECT 
		@Outstanding          = @Outstanding          + ISNULL(SUM(spositiontaking * ABS(actual_stake)),0),
		@total_outstanding    = @total_outstanding    + ISNULL(SUM(ABS(actual_stake)),0)		
FROM bettransLC WITH(NOLOCK)
WHERE srecommend = @custid
	AND statusID IN (0, 1)
	--AND gameID BETWEEN 2401 AND 2499

SELECT @Total_memberActive    = ISNULL(SUM(CASE WHEN Closed = 0 AND ISNULL(reject,0) = 0 THEN 1 ELSE 0 END), 0),
	   @Total_memberClosed    = ISNULL(SUM(CASE WHEN Closed = 1 THEN 1 ELSE 0 END), 0),
	   @Total_memberSuspended = ISNULL(SUM(CASE WHEN ISNULL(reject,0) = 1 AND Closed = 0 THEN 1 ELSE 0 END), 0)
FROM custinfo WITH(NOLOCK)
WHERE srecommend = @custid AND roleid = 1


SELECT @Total_agentActive    = ISNULL(SUM(CASE WHEN Closed = 0 AND ISNULL(reject,0) = 0 THEN 1 ELSE 0 END), 0),
	   @Total_agentClosed    = ISNULL(SUM(CASE WHEN Closed = 1 THEN 1 ELSE 0 END), 0),
	   @Total_agentSuspended = ISNULL(SUM(CASE WHEN ISNULL(reject,0) = 1 AND Closed = 0 THEN 1 ELSE 0 END), 0)
FROM custinfo WITH(NOLOCK)
WHERE srecommend = @custid AND roleid = 2


SELECT @Total_masterActive    = ISNULL(SUM(CASE WHEN Closed = 0 AND ISNULL(reject,0) = 0 THEN 1 ELSE 0 END), 0),
	   @Total_masterClosed    = ISNULL(SUM(CASE WHEN Closed = 1 THEN 1 ELSE 0 END), 0),
	   @Total_masterSuspended = ISNULL(SUM(CASE WHEN ISNULL(reject,0) = 1 AND Closed = 0 THEN 1 ELSE 0 END), 0)
FROM custinfo WITH(NOLOCK)
WHERE srecommend = @custid AND roleid = 3


SELECT @currentMonth = CONVERT(DATE, GETDATE())
SELECT @currentMonth = DATEADD(DAY,- DATEPART(DAY,@currentMonth)+ 1,@currentMonth)

SELECT @number_newMembers = COUNT(1)
FROM customer WITH(NOLOCK)
WHERE srecommend = @custid AND roleid = 1 AND creatdate >= @currentMonth

SELECT  @OutStanding as outStanding,
		@total_Outstanding as total_outstanding,					
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
DROP TABLE #SportBettype
GO