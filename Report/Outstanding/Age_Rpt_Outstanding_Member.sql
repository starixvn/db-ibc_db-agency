/*<info serverAlias="DB042-bodb02" executers="bodbDownlineNet,bodbDownlineNetView" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Age_Rpt_Outstanding_Member] 
	@CustID		INT, --recommend
	@ProductIds	VARCHAR(MAX)
AS

/*
	Created: Paul
	Task : Report Outstanding
	DB: DB042.bodb02
	Original: Age_Rpt_Outstanding_Ag
	
	Revisions:
		- 20161219@Paul: Create new [RedmineID: #68723]
		- 20170622@Percy: Combine Betradar Virtual Sports with Virtual Sports [RedmineID: #78339]
		- 20171020@Percy: get both running and waiting tickets [RedmineID: #84690]
		- 20180731@Patrick: indexes revolution [RedmineId: #98757]
		- 20200612@Sol: added index to temp table #SportBettype [RedmineId: #134967]
*/

BEGIN
	SET NOCOUNT ON;

	DECLARE @isTest BIT;
	SELECT  @isTest = dbo.f_CheckSPVersion(@@PROCID);

	SELECT @ProductIds = dbo.f_AddRelatedProducts(@ProductIds);

	CREATE TABLE #SportBettype (bettype SMALLINT, RefTable TINYINT, PRIMARY KEY CLUSTERED (RefTable, bettype));

	INSERT INTO #SportBettype (bettype, RefTable)
	SELECT bettype, RefTable
	FROM dbo.f_SportBettypeMatrixByProduct(@ProductIds, @isTest);

	CREATE TABLE #OutStanding (custid INT, MemberOutstanding MONEY, AgentOutstanding MONEY, MasterOutstanding MONEY, SuperOutstanding MONEY);
 
	-- bettrans
	INSERT INTO #OutStanding (custid, MemberOutstanding, AgentOutstanding, MasterOutstanding, SuperOutstanding)
	SELECT
		custid,
		SUM(ABS(actual_stake)) AS MemberOutstanding,
		SUM(actual_stake * apositiontaking) AS AgentOutstanding,
		SUM(actual_stake * mpositiontaking) AS MasterOutstanding,
		SUM(actual_stake * spositiontaking) AS SuperOutstanding
	FROM dbo.bettrans b WITH (NOLOCK)  
	WHERE statusId IN (0,1)
		AND EXISTS (
			SELECT 1
			FROM #SportBettype s
			WHERE s.RefTable = 0 AND s.bettype = b.bettype
		) -- bet tickets
		AND recommend =  @CustID		
	GROUP BY custid;
	
	-- translog
	INSERT INTO #OutStanding (custid, MemberOutstanding, AgentOutstanding, MasterOutstanding, SuperOutstanding)
	SELECT
		custid,
		SUM(ABS(actual_stake)) AS MemberOutstanding,
		SUM(actual_stake * apositiontaking) AS AgentOutstanding,
		SUM(actual_stake * mpositiontaking) AS MasterOutstanding,
		SUM(actual_stake * spositiontaking) AS SuperOutstanding
	FROM dbo.translog t WITH (NOLOCK)
	WHERE t.statusID IN (0, 1)
		AND recommend =  @CustID
		AND EXISTS (
			SELECT 1
			FROM #SportBettype s
			WHERE s.RefTable = 3 AND s.bettype = t.gameID
		)
	GROUP BY custid;

	-- bettransRnG
	INSERT INTO #OutStanding (custid, MemberOutstanding, AgentOutstanding, MasterOutstanding, SuperOutstanding)
	SELECT
		custid,
		SUM(ABS(actual_stake)) AS MemberOutstanding,
		SUM(actual_stake * apositiontaking) AS AgentOutstanding,
		SUM(actual_stake * mpositiontaking) AS MasterOutstanding,
		SUM(actual_stake * spositiontaking) AS SuperOutstanding
	FROM dbo.bettransRnG b WITH (NOLOCK)  
	WHERE b.statusID IN (0, 1)
		AND EXISTS (
			SELECT 1
			FROM #SportBettype s
			WHERE s.RefTable = 1 AND s.bettype = b.gameID
		)
		AND recommend =  @CustID		
	GROUP BY custid;

	-- bettransLC
	INSERT INTO #OutStanding (custid, MemberOutstanding, AgentOutstanding, MasterOutstanding, SuperOutstanding)
	SELECT
		custid,
		SUM(ABS(actual_stake)) AS MemberOutstanding,
		SUM(actual_stake * apositiontaking) AS AgentOutstanding,
		SUM(actual_stake * mpositiontaking) AS MasterOutstanding,
		SUM(actual_stake * spositiontaking) AS SuperOutstanding
	FROM dbo.bettransLC b WITH (NOLOCK)  
	WHERE b.statusID IN (0, 1)
		AND EXISTS (
			SELECT 1
			FROM #SportBettype s
			WHERE s.RefTable = 2 AND s.bettype = b.gameID
		)
		AND recommend =  @CustID		
	GROUP BY custid;
	
	WITH rt AS (
		SELECT
			custid,
			SUM(ISNULL(MemberOutstanding, 0)) AS MemberOutstanding,
			SUM(ISNULL(AgentOutstanding, 0))  AS AgentOutstanding,
			SUM(ISNULL(MasterOutstanding, 0)) AS MasterOutstanding,
			SUM(ISNULL(SuperOutstanding, 0))  AS SuperOutstanding
		FROM #OutStanding
		GROUP BY custid
	)
	SELECT
		rt.custid AS CustId,
		c.username AS CustName,
		rt.MemberOutstanding,
		rt.AgentOutstanding,
		rt.MasterOutstanding,
		rt.SuperOutstanding
	FROM rt
		INNER JOIN dbo.custInfo c WITH (NOLOCK) ON rt.custid = c.custid
	ORDER BY c.username;

	DROP TABLE #SportBettype;
	DROP TABLE #OutStanding;

	SET NOCOUNT OFF;
END
GO