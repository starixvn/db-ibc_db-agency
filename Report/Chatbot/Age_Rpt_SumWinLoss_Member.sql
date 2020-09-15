/*<info serverAlias="DBAGE-bodb02" executers="bodbDownlineNet" isFunction="0"></info>*/
USE bodb02
GO
 
ALTER PROCEDURE [dbo].[Age_Rpt_SumWinLoss_Member] @CustID INT
	,@FromDate SMALLDATETIME
	,@ToDate SMALLDATETIME
	,@ProductIds VARCHAR(MAX)
	,@MoveBetsDay SMALLDATETIME
	,@BalanceUpDay SMALLDATETIME
AS
/*
	Creator:	20180905@Alvin
	Task:		Sum WinLoss Member - [Redmine: #95940]
	Database:	DBAGE/bodb02
	
	Revisions:
		
	Parameter's Explaination:
		- 20180912@Alvin: Correct GrossComm column name - [Redmine: #95940]
		- 20200909@Malcolm : Report Enhancement for Jackpot Product [RedmineID : #139575]
		
	Developer's Notes:
	Example:
*/
BEGIN
	SET NOCOUNT ON;

	CREATE TABLE #AgentWinLoss (
		CustID INT
		,CustName NVARCHAR(50)
		,Turnover MONEY
		,GrossComm MONEY
		,MemberWinLoss MONEY
		,MemberComm MONEY
		,AgWinLoss MONEY
		,AgComm MONEY
		);

	INSERT INTO #AgentWinLoss
	EXEC dbo.Age_Rpt_WinLoss_Member @CustId
		,@FromDate = @FromDate
		,@ToDate = @ToDate
		,@ProductIds = @ProductIds
		,@MoveBetsDay = @MoveBetsDay
		,@BalanceUpDay = @BalanceUpDay;

	IF EXISTS (
			SELECT 1
			FROM #AgentWinLoss
			)
	BEGIN
		SELECT SUM(Turnover) AS Turnover
			,SUM(GrossComm) AS GrossComm
			,SUM(MemberWinLoss) AS MemberWinLoss
			,SUM(MemberComm) AS MemberComm
			,SUM(AgWinLoss) AS AgentWinLoss
			,SUM(AgComm) AS AgentComm
		FROM #AgentWinLoss
	END
END;
