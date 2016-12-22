USE [bodb02]
GO

CREATE PROCEDURE [dbo].[Age_Rpt_Outstanding_Agent]
	@CustID int
AS

/*
	Created: Paul
	Task : Report Outstanding
	DB: DBAGE.bodb02
	Original: Age_Rpt_Outstanding_MAg
	Revisions:
		- 20161219@Paul: Create new [RedmineID: #68723]
*/

BEGIN
	SET NOCOUNT ON;

	DECLARE @isTest BIT;
	SELECT  @isTest = dbo.f_CheckSPVersion(@@PROCID);

	CREATE TABLE #SportBettype (ProductID TINYINT, bettype SMALLINT, RefTable TINYINT);

	INSERT INTO #SportBettype (ProductID, bettype, RefTable)
	SELECT ProductID, bettype, RefTable
	FROM dbo.f_SportBettypeMatrix_Sel(0,0,0,2,'','',@isTest);
 
	WITH rt 
	AS (
		SELECT	recommend,  
			SUM(CASE when bettype <=19000 then ABS(actual_stake) END) AS Outstanding,  
			SUM(case when bettype <=19000 then actual_stake * mpositiontaking end) AS PositionTaking
		FROM bettrans b with (nolock) 
		WHERE ruben = 0
			AND NOT EXISTS (
				SELECT 1 
				FROM #SportBettype s 
				WHERE s.RefTable <> 0 AND s.bettype = b.bettype
				)
			AND mrecommend =  @CustID
		GROUP BY recommend

		UNION ALL
		SELECT	recommend,  
			SUM(ABS(actual_stake)) AS Outstanding,  
			SUM(actual_stake * mpositiontaking) AS PositionTaking
		FROM translog with (nolock) 
		WHERE statusid = 0
			AND mrecommend =  @CustID
		GROUP BY recommend

		UNION ALL -- bettransRNG
		SELECT	recommend,  
			SUM(ABS(actual_stake)) AS Outstanding,  
			SUM(actual_stake * mpositiontaking) AS PositionTaking
		FROM bettransRNG with (nolock) 
		WHERE statusid = 0
			AND mrecommend = @CustID
		GROUP BY recommend

		UNION ALL -- bettransLC
		SELECT	recommend,  
			SUM(ABS(actual_stake)) AS Outstanding,  
			SUM(actual_stake * mpositiontaking) AS PositionTaking
		FROM bettransLC with (nolock) 
		WHERE statusid = 0
			AND mrecommend = @CustID
		GROUP BY recommend
	)
	SELECT	username AS CustName,
			b.recommend AS CustId, 
			isnull(Outstanding, 0) AS MemberOutstanding,
			isnull(positiontaking,0) AS MasterOutstanding
	FROM custinfo AS c with (nolock)
	INNER JOIN (
					SELECT 	recommend,
						SUM(ISNULL(Outstanding,0)) AS Outstanding,
						SUM(ISNULL(positiontaking,0)) AS PositionTaking
					FROM rt
					group BY recommend
				) b ON c.custid = b.recommend
	ORDER BY username;

	DROP TABLE #SportBettype;

	SET NOCOUNT OFF;
END
GO

GRANT EXECUTE ON [dbo].[Age_Rpt_Outstanding_Agent] TO [bodbDownlineNet] AS [dbo]
GO

GRANT EXECUTE ON [dbo].[Age_Rpt_Outstanding_Agent] TO [bodbDownlineNetView] AS [dbo]
GO

GRANT VIEW DEFINITION ON [dbo].[Age_Rpt_Outstanding_Agent] TO [vnteam] AS [dbo]
GO