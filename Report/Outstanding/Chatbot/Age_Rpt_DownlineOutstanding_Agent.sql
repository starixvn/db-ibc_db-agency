/*<info serverAlias="DB042-bodb02" executers="bodbDownlineNet" viewers="vnteam" isFunction="0" isNested="0"></info>*/
USE [bodb02]
GO

ALTER PROCEDURE [dbo].[Age_Rpt_DownlineOutstanding_Agent]
	@CustID		INT, --mrecommend
	@ProductIds	VARCHAR(MAX),
	@DownlineId INT -- agent
AS

/*
	Created: Kan
	Task : Report Outstanding
	DB: DB042.bodb02
	
	Revisions:
		- 20181102@Kan: Create new [RedmineId: #103467]
*/

BEGIN
	SET NOCOUNT ON;

	DECLARE @isTest BIT;
	SELECT @isTest = dbo.f_CheckSPVersion(@@PROCID);

	SELECT @ProductIds = dbo.f_AddRelatedProducts(@ProductIds);

	CREATE TABLE #SportBettype
	(
		bettype SMALLINT,
		RefTable TINYINT
	);

	INSERT INTO #SportBettype
		(bettype, RefTable)
	SELECT bettype, RefTable
	FROM dbo.f_SportBettypeMatrixByProduct(@ProductIds, @isTest);

	CREATE TABLE #OutStanding
	(
		recommend INT,
		MemberOutstanding MONEY,
		MasterOutstanding MONEY,
		SuperOutstanding MONEY
	);

	-- bettrans
	INSERT INTO #OutStanding
		(recommend, MemberOutstanding, MasterOutstanding, SuperOutstanding)
	SELECT
		recommend,
		SUM(ABS(actual_stake)) AS MemberOutstanding,
		SUM(actual_stake * mpositiontaking) AS MasterOutstanding,
		SUM(actual_stake * spositiontaking) AS SuperOutstanding
	FROM dbo.bettrans b WITH (NOLOCK)
	WHERE statusId IN (0, 1)
		AND EXISTS (
			SELECT 1
		FROM #SportBettype s
		WHERE s.RefTable = 0 AND s.bettype = b.bettype
		) -- bet tickets
		AND mrecommend =  @CustID
		AND b.recommend = @DownlineId
	GROUP BY recommend;

	-- translog
	INSERT INTO #OutStanding
		(recommend, MemberOutstanding, MasterOutstanding, SuperOutstanding)
	SELECT
		recommend,
		SUM(ABS(actual_stake)) AS MemberOutstanding,
		SUM(actual_stake * mpositiontaking) AS MasterOutstanding,
		SUM(actual_stake * spositiontaking) AS SuperOutstanding
	FROM dbo.translog t WITH (NOLOCK)
	WHERE t.statusID IN (0, 1)
		AND mrecommend =  @CustID
		AND t.recommend = @DownlineId
		AND EXISTS (
			SELECT 1
		FROM #SportBettype s
		WHERE s.RefTable = 3 AND s.bettype = t.gameID
		)
	GROUP BY recommend;

	-- bettransRnG
	INSERT INTO #OutStanding
		(recommend, MemberOutstanding, MasterOutstanding, SuperOutstanding)
	SELECT
		recommend,
		SUM(ABS(actual_stake)) AS MemberOutstanding,
		SUM(actual_stake * mpositiontaking) AS MasterOutstanding,
		SUM(actual_stake * spositiontaking) AS SuperOutstanding
	FROM dbo.bettransRnG b WITH (NOLOCK)
	WHERE b.statusID IN (0, 1)
		AND EXISTS (
			SELECT 1
		FROM #SportBettype s
		WHERE s.RefTable = 1 AND s.bettype = b.gameID
		)
		AND mrecommend =  @CustID
		AND b.recommend = @DownlineId
	GROUP BY recommend;

	-- bettransLC
	INSERT INTO #OutStanding
		(recommend, MemberOutstanding, MasterOutstanding, SuperOutstanding)
	SELECT
		recommend,
		SUM(ABS(actual_stake)) AS MemberOutstanding,
		SUM(actual_stake * mpositiontaking) AS MasterOutstanding,
		SUM(actual_stake * spositiontaking) AS SuperOutstanding
	FROM dbo.bettransLC b WITH (NOLOCK)
	WHERE b.statusID IN (0, 1)
		AND EXISTS (
			SELECT 1
		FROM #SportBettype s
		WHERE s.RefTable = 2 AND s.bettype = b.gameID
		)
		AND mrecommend =  @CustID
		AND b.recommend = @DownlineId
	GROUP BY recommend;


	WITH
		rt
		AS
		(
			SELECT
				recommend,
				SUM(ISNULL(MemberOutstanding, 0)) AS MemberOutstanding,
				SUM(ISNULL(MasterOutstanding, 0)) AS MasterOutstanding,
				SUM(ISNULL(SuperOutstanding, 0))  AS SuperOutstanding
			FROM #OutStanding
			GROUP BY recommend
		)
	SELECT
		rt.recommend AS CustId,
		c.username AS CustName,
		rt.MemberOutstanding,
		rt.MasterOutstanding,
		rt.SuperOutstanding
	FROM rt
		INNER JOIN dbo.custInfo c WITH (NOLOCK) ON rt.recommend = c.custid
	ORDER BY c.username;

	DROP TABLE #SportBettype;
	DROP TABLE #OutStanding;

	SET NOCOUNT OFF;
END
GO