/*<info serverAlias="DBAGE-bodb02" executers="bodbDownlineNet" isFunction="0"></info>*/
USE bodb02
GO

ALTER PROCEDURE [dbo].[Age_Rpt_SumWinLoss_Master] @CustID INT
	,@FromDate SMALLDATETIME
	,@ToDate SMALLDATETIME
	,@ProductIds VARCHAR(MAX)
	,@MoveBetsDay SMALLDATETIME
	,@BalanceUpDay SMALLDATETIME
AS
/*
	Creator:	20180905@Alvin
	Task:		Sum WinLoss Master - [Redmine: #95940]
	Database:	DBAGE/bodb02
	
	Revisions:
		- 20180912@Alvin: Correct GrossComm column name - [Redmine: #95940]
		- 20200909@Malcolm : Report Enhancement for Jackpot Product [RedmineID : #139575]
		
	Parameter's Explaination:
		
	Developer's Notes:
	Example:
*/
BEGIN
	SET NOCOUNT ON;

	CREATE TABLE #SuperWinLoss (
		CustID INT
		,CustName NVARCHAR(50)
		,Turnover MONEY
		,GrossComm MONEY
		,MAgTotal MONEY
		,SAgWinLoss MONEY
		,SAgComm MONEY
		);

	INSERT INTO #SuperWinLoss
	EXEC dbo.Age_Rpt_WinLoss_Master @CustId = @CustId
		,@FromDate = @FromDate
		,@ToDate = @ToDate
		,@ProductIds = @ProductIds
		,@MoveBetsDay = @MoveBetsDay
		,@BalanceUpDay = @BalanceUpDay;

	IF EXISTS (
			SELECT 1
			FROM #SuperWinLoss
			)
	BEGIN
		SELECT SUM(Turnover) AS Turnover
			,SUM(GrossComm) AS GrossComm
			,SUM(MAgTotal) AS MasterTotal
			,SUM(SAgWinLoss) AS SuperWinLoss
			,SUM(SAgComm) AS SuperComm
		FROM #SuperWinLoss
	END
END;
