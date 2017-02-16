USE [bodb02]
GO

ALTER PROCEDURE [dbo].[Age_Rpt_Outstanding_Agent]
	@CustID		INT, --mrecommend
	@ProductIds	VARCHAR(MAX)
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
	FROM dbo.f_SportBettypeMatrix_Sel(0,0,0,2,'','',@isTest)
	WHERE ',' + @ProductIds + ',' LIKE '%,' + CAST(ProductID AS VARCHAR(3)) + ',%';
 
	WITH rt 
	AS (
		SELECT	recommend,  
			SUM(CASE WHEN bettype <=19000 THEN ABS(actual_stake) END) AS MemberOutstanding,  
			SUM(CASE WHEN bettype <=19000 THEN actual_stake * mpositiontaking END) AS MasterOutstanding,  
			SUM(CASE WHEN bettype <=19000 THEN actual_stake * spositiontaking END) AS SuperOutstanding
		FROM bettrans b WITH (NOLOCK) 
		WHERE ruben = 0
			AND EXISTS (
				SELECT 1 
				FROM #SportBettype s 
				WHERE s.RefTable = 0 AND s.bettype = b.bettype
				)
			AND mrecommend =  @CustID
		GROUP BY recommend

		UNION ALL
		SELECT	recommend,  
			SUM(ABS(actual_stake)) AS MemberOutstanding,  
			SUM(actual_stake * mpositiontaking) AS MasterOutstanding,  
			SUM(actual_stake * spositiontaking) AS SuperOutstanding
		FROM translog t WITH (NOLOCK) 
		WHERE statusid = 0
			AND mrecommend =  @CustID
			AND EXISTS (
				SELECT 1 
				FROM #SportBettype s 
				WHERE s.RefTable = 3 AND s.bettype = t.gameID
			)
		GROUP BY recommend

		UNION ALL -- bettransRNG
		SELECT	recommend,  
			SUM(ABS(actual_stake)) AS MemberOutstanding,  
			SUM(actual_stake * mpositiontaking) AS MasterOutstanding,  
			SUM(actual_stake * spositiontaking) AS SuperOutstanding
		FROM bettransRNG b WITH (NOLOCK) 
		WHERE statusid = 0
			AND mrecommend = @CustID
			AND EXISTS (
				SELECT 1 
				FROM #SportBettype s 
				WHERE s.RefTable = 1 AND s.bettype = b.gameID
			)
		GROUP BY recommend

		UNION ALL -- bettransLC
		SELECT	recommend,  
			SUM(ABS(actual_stake)) AS MemberOutstanding,  
			SUM(actual_stake * mpositiontaking) AS MasterOutstanding,  
			SUM(actual_stake * spositiontaking) AS SuperOutstanding
		FROM bettransLC b WITH (NOLOCK) 
		WHERE statusid = 0
			AND mrecommend = @CustID
			AND EXISTS (
				SELECT 1 
				FROM #SportBettype s 
				WHERE s.RefTable = 2 AND s.bettype = b.gameID
			)
		GROUP BY recommend
	)
	SELECT	b.recommend AS CustId, 
			username AS CustName,
			ISNULL(MemberOutstanding, 0) AS MemberOutstanding,
			ISNULL(MasterOutstanding,0) AS MasterOutstanding,
			ISNULL(SuperOutstanding,0) AS SuperOutstanding
	FROM custinfo AS c WITH (NOLOCK)
	INNER JOIN (
					SELECT 	recommend,
						SUM(ISNULL(MemberOutstanding,0)) AS MemberOutstanding,
						SUM(ISNULL(MasterOutstanding,0)) AS MasterOutstanding,
						SUM(ISNULL(SuperOutstanding,0)) AS SuperOutstanding
					FROM rt
					GROUP BY recommend
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