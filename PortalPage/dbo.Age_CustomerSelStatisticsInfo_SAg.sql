/*<info serverAlias="DBAGE-bodb02" executers="bodbDownlineNet,bodbDownlineNetView" viewers="vnteam" isFunction="0" isNested="0"></info>*/
USE [bodb02]
GO

ALTER PROCEDURE [dbo].[Age_CustomerSelStatisticsInfo_SAg]
	 @custid INT
AS

/*
	Created by Percy
	Date: 2017-10-20
	DB: DBAGE.bodb02
	Task: Home page - Super Statictis Info 
	
	Revisions:
		- 20171020@Percy: Apply core sp [RedmineID: #84690]
		- 20180731@Patrick: indexes revolution [RedmineId: #98757]
*/

BEGIN
	SET NOCOUNT ON

	DECLARE
		-- member
		@total_memberActive		INT,
		@total_memberClosed		INT,
		@total_memberSuspended	INT,
		-- agent	
		@total_agentActive		INT,
		@total_agentClosed		INT,
		@total_agentSuspended	INT,
		-- master				
		@total_masterActive		INT,
		@total_masterClosed		INT,
		@total_masterSuspended	INT,
		-- new members
		@number_newMembers		INT

	-- all downlines's status
	;WITH custStatus AS
	(
		SELECT
			roleid,
			SUM(CASE WHEN Closed = 0 AND ISNULL(reject,0) = 0 THEN 1 ELSE 0 END) AS Active,
			SUM(CASE WHEN Closed = 1 THEN 1 ELSE 0 END) AS Closed,
			SUM(CASE WHEN ISNULL(reject,0) = 1 AND Closed = 0 THEN 1 ELSE 0 END) AS Suspended
		FROM dbo.custInfo WITH (NOLOCK)
		WHERE srecommend = @CustId
			AND roleid <> 4
		GROUP BY roleid
	)
	SELECT
		-- member
		@Total_memberActive    = ISNULL(CASE WHEN roleId = 1 THEN Active	ELSE @Total_memberActive	END, 0),
		@Total_memberClosed    = ISNULL(CASE WHEN roleId = 1 THEN Closed	ELSE @Total_memberClosed	END, 0),
		@Total_memberSuspended = ISNULL(CASE WHEN roleId = 1 THEN Suspended ELSE @Total_memberSuspended END, 0),
		-- agent
		@Total_agentActive     = ISNULL(CASE WHEN roleId = 2 THEN Active	ELSE @Total_agentActive		END, 0),
		@Total_agentClosed     = ISNULL(CASE WHEN roleId = 2 THEN Closed	ELSE @Total_agentClosed		END, 0),
		@Total_agentSuspended  = ISNULL(CASE WHEN roleId = 2 THEN Suspended ELSE @Total_agentSuspended	END, 0),
		-- master
		@Total_masterActive    = ISNULL(CASE WHEN roleId = 3 THEN Active	ELSE @Total_masterActive	END, 0),
		@Total_masterClosed    = ISNULL(CASE WHEN roleId = 3 THEN Closed	ELSE @Total_masterClosed	END, 0),
		@Total_masterSuspended = ISNULL(CASE WHEN roleId = 3 THEN Suspended ELSE @Total_masterSuspended END, 0)
	FROM custStatus

	-- new member of this month
	DECLARE @FirstDayOfThisMonth SMALLDATETIME
	SELECT  @FirstDayOfThisMonth = DATEADD(MONTH, DATEDIFF(MONTH, 0, GETDATE()), 0)

	SELECT @number_newMembers = ISNULL(COUNT(1), 0)
	FROM dbo.Customer WITH (NOLOCK)
	WHERE srecommend = @custid
		AND roleid = 1
		AND creatdate >= @FirstDayOfThisMonth

	-- Outstanding
	CREATE TABLE #Outstanding (superOutstanding MONEY, masterOutstanding MONEY, agentOutstanding MONEY, memberOutstanding MONEY)

	INSERT INTO #Outstanding (superOutstanding, masterOutstanding, agentOutstanding, memberOutstanding)
		EXEC dbo.Age_CustomerSelOutstanding @CustId = @CustId

	SELECT
		SUM(superOutstanding)	AS outStanding,
		SUM(memberOutstanding)	AS total_outstanding,
		@number_newMembers		AS number_newMembers,
		-- member
		@total_memberActive		AS total_memberActive,
		@total_memberClosed		AS total_memberClosed,
		@total_memberSuspended	AS total_memberSuspended,
		-- agent
		@total_agentActive		AS total_agentActive,
		@total_agentClosed		AS total_agentClosed,
		@total_agentSuspended	AS total_agentSuspended,
		-- master
		@total_masterActive		AS total_masterActive,
		@total_masterClosed		AS total_masterClosed,
		@total_masterSuspended	AS total_masterSuspended
	FROM #Outstanding

	DROP TABLE #Outstanding
END
GO