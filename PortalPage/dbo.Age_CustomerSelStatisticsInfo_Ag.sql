/*<info serverAlias="DBBOF-bodb02" executers="bodbDownlineNet,bodbDownlineNetView" viewers="vnteam" isFunction="0" isNested="0"></info>*/
USE [bodb02]
GO

ALTER PROCEDURE [dbo].[Age_CustomerSelStatisticsInfo_Ag]
	 @custid INT
AS

/*
	Created by Percy
	Date: 2017-10-20
	DB: DBBOF.bodb02
	Task: Home page - Agent Statictis Info 
	
	Revisions:
		- 20171020@Percy: Apply core sp [RedmineID: #84690]
		- 20180731@Patrick: indexes revolution [RedmineId: #98757]
		- 20201113@Danny: Change to use alias DBBOF alternative to DB042 [RedmineID: #139516]
*/

BEGIN
	SET NOCOUNT ON

	DECLARE
		-- member
		@total_memberActive		INT,
		@total_memberClosed		INT,
		@total_memberSuspended	INT,
		-- new members
		@number_newMembers		INT

	-- all downline's status
	SELECT
		@Total_memberActive    = ISNULL(SUM(CASE WHEN Closed = 0 AND ISNULL(reject, 0) = 0 THEN 1 ELSE 0 END), 0),
		@Total_memberClosed    = ISNULL(SUM(CASE WHEN Closed = 1 THEN 1 ELSE 0 END), 0),
		@Total_memberSuspended = ISNULL(SUM(CASE WHEN ISNULL(reject, 0) = 1 AND Closed = 0 THEN 1 ELSE 0 END), 0)
	FROM dbo.custInfo WITH (NOLOCK)
	WHERE recommend = @CustId
		AND roleid = 1

	-- new member of this month
	DECLARE @FirstDayOfThisMonth SMALLDATETIME
	SELECT  @FirstDayOfThisMonth = DATEADD(MONTH, DATEDIFF(MONTH, 0, GETDATE()), 0)

	SELECT @number_newMembers = ISNULL(COUNT(1), 0)
	FROM dbo.Customer WITH (NOLOCK)
	WHERE recommend = @custid
		AND roleid = 1
		AND creatdate >= @FirstDayOfThisMonth

	-- Outstanding
	CREATE TABLE #Outstanding (superOutstanding MONEY, masterOutstanding MONEY, agentOutstanding MONEY, memberOutstanding MONEY)

	INSERT INTO #Outstanding (superOutstanding, masterOutstanding, agentOutstanding, memberOutstanding)
		EXEC dbo.Age_CustomerSelOutstanding @CustId = @CustId

	SELECT
		SUM(agentOutstanding)	AS outStanding,
		SUM(memberOutstanding)	AS total_outstanding,
		@number_newMembers		AS number_newMembers,
		-- member
		@total_memberActive		AS total_memberActive,
		@total_memberClosed		AS total_memberClosed,
		@total_memberSuspended	AS total_memberSuspended
	FROM #Outstanding

	DROP TABLE #Outstanding
END
GO