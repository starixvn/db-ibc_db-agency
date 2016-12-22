USE [bodb02]
GO

CREATE PROCEDURE [dbo].[Age_Rpt_Outstanding_Master]
	@CustID int 
AS

/*
	Created: Paul
	Task : Report Outstanding
	DB: DBAGE.bodb02
	Original: Age_Rpt_Outstanding_SAg
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

	DECLARE @mrecommend TABLE (CustId INT PRIMARY KEY);

	INSERT INTO @mrecommend (CustId)
	SELECT CustId 
	FROM dbo.custInfo (NOLOCK) 
	WHERE roleid = 3 AND srecommend = @CustID;

	WITH rt 
	AS (
		SELECT	mrecommend,  
				SUM(CASE when bettype <=19000 then ABS(actual_stake) END) AS Outstanding,  
				SUM(case when bettype <=19000 then actual_stake * spositiontaking end) AS PositionTaking
		FROM bettrans b with (nolock) 
		WHERE ruben = 0
			AND NOT EXISTS (
				SELECT 1 
				FROM #SportBettype s 
				WHERE s.RefTable <> 0 AND s.bettype = b.bettype
				)
			AND srecommend =  @CustID
		GROUP BY mrecommend
	
		UNION ALL 
		SELECT	mrecommend,  
				SUM(ABS(actual_stake)) AS Outstanding,  
				SUM(actual_stake * spositiontaking) AS PositionTaking
		FROM translog t with (nolock)
			INNER JOIN @mrecommend m ON t.mrecommend = m.CustId
		WHERE statusid = 0
		GROUP BY mrecommend

		UNION ALL -- bettransRNG
		SELECT	mrecommend,  
				SUM(ABS(actual_stake)) AS Outstanding,  
				SUM(actual_stake * spositiontaking) AS PositionTaking
		FROM bettransRNG with (nolock) 
		WHERE statusid = 0
			AND srecommend =  @CustID
		GROUP BY mrecommend

		UNION ALL -- bettransLC
		SELECT	mrecommend,  
				SUM(ABS(actual_stake)) AS Outstanding,  
				SUM(actual_stake * spositiontaking) AS PositionTaking
		FROM bettransLC with (nolock) 
		WHERE statusid = 0
			AND srecommend =  @CustID
		GROUP BY mrecommend
	)
	SELECT	username AS CustName,
			b.mrecommend as CustId, 
			isnull(Outstanding, 0) AS MemberOutstanding,
			isnull(positiontaking,0) AS SuperOutstanding
	FROM custinfo AS c with (nolock)
		INNER JOIN (
			SELECT	mrecommend,
					SUM(ISNULL(Outstanding,0)) AS Outstanding,
					SUM(ISNULL(positiontaking,0)) AS PositionTaking
			FROM rt
			GROUP BY mrecommend
			) b ON c.custid = b.mrecommend
	ORDER BY username;

	DROP TABLE #SportBettype;

	SET NOCOUNT OFF;
END
GO
GRANT EXECUTE ON [dbo].[Age_Rpt_Outstanding_Master] TO [bodbDownlineNet] AS [dbo]
GO
GRANT EXECUTE ON [dbo].[Age_Rpt_Outstanding_Master] TO [bodbDownlineNetView] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[Age_Rpt_Outstanding_Master] TO [vnteam] AS [dbo]
GO