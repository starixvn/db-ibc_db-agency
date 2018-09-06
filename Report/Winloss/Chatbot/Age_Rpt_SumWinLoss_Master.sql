/*<info serverAlias="DBAGE-bodb02" executers="bodbDownlineNet" viewers="vnteam" isFunction="0"></info>*/
USE bodb02
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
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
	EXEC dbo.Age_Rpt_WinLoss_Master @CustId
		,@FromDate
		,@ToDate
		,@ProductIds
		,@MoveBetsDay
		,@BalanceUpDay;

	IF EXISTS (
			SELECT 1
			FROM #SuperWinLoss
			)
	BEGIN
		SELECT SUM(Turnover) AS Turnover
			,SUM(GrossComm) AS GrossCom
			,SUM(MAgTotal) AS MasterTotal
			,SUM(SAgWinLoss) AS SuperWinLoss
			,SUM(SAgComm) AS SuperComm
		FROM #SuperWinLoss
	END
END;
