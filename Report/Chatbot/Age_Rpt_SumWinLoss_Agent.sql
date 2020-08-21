/*<info serverAlias="DBAGE-bodb02" executers="bodbDownlineNet" isFunction="0"></info>*/
USE bodb02
GO

ALTER PROCEDURE [dbo].[Age_Rpt_SumWinLoss_Agent] @CustID INT
	,@FromDate SMALLDATETIME
	,@ToDate SMALLDATETIME
	,@ProductIds VARCHAR(MAX)
	,@MoveBetsDay SMALLDATETIME
	,@BalanceUpDay SMALLDATETIME
AS
/*
	Creator:	20180905@Alvin
	Task:		Sum WinLoss Agent - [Redmine: #95940]
	Database:	DBAGE/bodb02
	
	Revisions:
		- 20180912@Alvin: Correct GrossComm column name - [Redmine: #95940]
		
	Parameter's Explaination:
		
	Developer's Notes:
	Example:
*/
BEGIN
	SET NOCOUNT ON;

	CREATE TABLE #MasterWinLoss (
		CustID INT
		,CustName NVARCHAR(50)
		,Turnover MONEY
		,GrossComm MONEY
		,AgTotal MONEY
		,MAgWinLoss MONEY
		,MAgComm MONEY
		);

	INSERT INTO #MasterWinLoss
	EXEC dbo.Age_Rpt_WinLoss_Agent @CustId
		,@FromDate
		,@ToDate
		,@ProductIds
		,@MoveBetsDay
		,@BalanceUpDay;

	IF EXISTS (
			SELECT 1
			FROM #MasterWinLoss
			)
	BEGIN
		SELECT SUM(Turnover) AS Turnover
			,SUM(GrossComm) AS GrossComm
			,SUM(AgTotal) AS AgentTotal
			,SUM(MAgWinLoss) AS MasterWinLoss
			,SUM(MAgComm) AS MasterComm
		FROM #MasterWinLoss
	END
END;
