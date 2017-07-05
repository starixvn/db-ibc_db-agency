/*<info serverAlias="DBAGE-bodb02" executers="bodbDownlineNet,bodbDownlineNetView" viewers="vnteam" isFunction="0" isNested="0"></info>*/
USE [bodb02]
GO

ALTER PROCEDURE [dbo].[Age_Rpt_Outstanding_Master]
	@CustID		INT, --srecommend
	@ProductIds	VARCHAR(MAX)
AS

/*
	Created: Paul
	Task : Report Outstanding
	DB: DBAGE.bodb02
	Original: Age_Rpt_Outstanding_SAg
	Revisions:
		- 20161219@Paul: Create new [RedmineID: #68723]
		- 20170622@Percy: Combine Betradar Virtual Sports with Virtual Sports [RedmineID: #78339]
*/

BEGIN
	SET NOCOUNT ON;

	DECLARE @isTest BIT;
	SELECT  @isTest = dbo.f_CheckSPVersion(@@PROCID);

	SELECT @ProductIds = dbo.f_AddRelatedProducts(@ProductIds);

	CREATE TABLE #SportBettype (bettype SMALLINT, RefTable TINYINT);

	INSERT INTO #SportBettype (bettype, RefTable)
	SELECT bettype, RefTable
	FROM dbo.f_SportBettypeMatrixByProduct_Sel(@ProductIds, @isTest);

	DECLARE @mrecommend TABLE (CustId INT PRIMARY KEY);

	INSERT INTO @mrecommend (CustId)
	SELECT CustId 
	FROM dbo.custInfo (NOLOCK) 
	WHERE roleid = 3 AND srecommend = @CustID;

	WITH rt 
	AS (
		SELECT	mrecommend,  
				SUM(CASE WHEN bettype <=19000 THEN ABS(actual_stake) END) AS Outstanding,  
				SUM(case WHEN bettype <=19000 THEN actual_stake * spositiontaking END) AS PositionTaking
		FROM bettrans b WITH (NOLOCK) 
		WHERE ruben = 0
			AND EXISTS (
				SELECT 1 
				FROM #SportBettype s 
				WHERE s.RefTable = 0 AND s.bettype = b.bettype
				)
			AND srecommend =  @CustID
		GROUP BY mrecommend
	
		UNION ALL 
		SELECT	mrecommend,  
				SUM(ABS(actual_stake)) AS Outstanding,  
				SUM(actual_stake * spositiontaking) AS PositionTaking
		FROM translog t WITH (NOLOCK)
			INNER JOIN @mrecommend m ON t.mrecommend = m.CustId
		WHERE statusid = 0
			AND EXISTS (
				SELECT 1 
				FROM #SportBettype s 
				WHERE s.RefTable = 3 AND s.bettype = t.gameID
			)
		GROUP BY mrecommend

		UNION ALL -- bettransRNG
		SELECT	mrecommend,  
				SUM(ABS(actual_stake)) AS Outstanding,  
				SUM(actual_stake * spositiontaking) AS PositionTaking
		FROM bettransRNG b WITH (NOLOCK) 
		WHERE statusid = 0
			AND srecommend =  @CustID
			AND EXISTS (
				SELECT 1 
				FROM #SportBettype s 
				WHERE s.RefTable = 1 AND s.bettype = b.gameID
			)
		GROUP BY mrecommend

		UNION ALL -- bettransLC
		SELECT	mrecommend,  
				SUM(ABS(actual_stake)) AS Outstanding,  
				SUM(actual_stake * spositiontaking) AS PositionTaking
		FROM bettransLC b WITH (NOLOCK) 
		WHERE statusid = 0
			AND srecommend =  @CustID
			AND EXISTS (
				SELECT 1 
				FROM #SportBettype s 
				WHERE s.RefTable = 2 AND s.bettype = b.gameID
			)
		GROUP BY mrecommend
	)
	SELECT	b.mrecommend as CustId, 
			username AS CustName,
			ISNULL(Outstanding, 0) AS MemberOutstanding,
			ISNULL(positiontaking,0) AS SuperOutstanding
	FROM custinfo AS c WITH (NOLOCK)
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