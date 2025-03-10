/*<info serverAlias="DBBOF-bodb02" executers="wsv_alp,wsv_alpv" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Age_Rpt_Outstanding_Member] 
	@CustID		INT, --recommend
	@ProductIds	VARCHAR(MAX),
	@IsChatBot BIT = 0,
	@PageSize INT = 0,
	@PageIndex INT = 1,
	@TotalMemberOutstanding	MONEY = 0 OUTPUT,
	@TotalMasterOutstanding	MONEY = 0 OUTPUT,
	@TotalAgentOutstanding	MONEY = 0 OUTPUT,
	@TotalMemberRiskAmount	MONEY = 0 OUTPUT,
	@TotalMasterRiskAmount	MONEY = 0 OUTPUT,
	@TotalAgentRiskAmount	MONEY = 0 OUTPUT,
	@TotalSuperRiskAmount	MONEY = 0 OUTPUT
AS

/*
	Created: Paul
	Task : Report Outstanding
	DB: DBBOF.bodb02
	Original: Age_Rpt_Outstanding_Ag
	
	Revisions:
		- 20161219@Paul: Create new [RedmineID: #68723]
		- 20170622@Percy: Combine Betradar Virtual Sports with Virtual Sports [RedmineID: #78339]
		- 20171020@Percy: get both running and waiting tickets [RedmineID: #84690]
		- 20180731@Patrick: indexes revolution [RedmineId: #98757]
		- 20200612@Sol: added index to temp table #SportBettype [RedmineId: #134967]
		- 20201005@Danny: Change to use alias DBBOF alternative to DB042 [RedmineID: #139516]
		- 20220520@Evan: Add parameters for telegram bot service [RedmineId: #167819]  
		- 20240523@Lewis: Potential Winning [RedmineId: #202427]  
*/

BEGIN
	SET NOCOUNT ON;

	DECLARE @RowStart	INT,
			@RowEnd		INT;
		
	SELECT	@PageIndex = @PageIndex - 1,
			@RowStart = @PageSize * @PageIndex + 1,
			@RowEnd = @RowStart + @PageSize - 1;

	DECLARE @isTest BIT;
	SELECT  @isTest = dbo.f_CheckSPVersion(@@PROCID);

	SELECT @ProductIds = dbo.f_AddRelatedProducts(@ProductIds);

	CREATE TABLE #SportBettype (bettype SMALLINT, RefTable TINYINT, ProductId INT, PRIMARY KEY CLUSTERED (RefTable, bettype));

	INSERT INTO #SportBettype (bettype, RefTable, ProductId)
	SELECT bettype, RefTable, ProductId
	FROM dbo.f_SportBettypeMatrixByProduct(@ProductIds, @isTest)
	;

	-- #OutStanding
	CREATE TABLE #OutStanding (custid INT, MemberOutstanding MONEY, AgentOutstanding MONEY, MasterOutstanding MONEY, SuperOutstanding MONEY, ToWin MONEY, AgentRisk MONEY, MasterRisk MONEY, SuperRisk MONEY);

	-- bettrans
	INSERT INTO #OutStanding (custid, MemberOutstanding, AgentOutstanding, MasterOutstanding, SuperOutstanding, ToWin, AgentRisk, MasterRisk, SuperRisk)
	SELECT
		custid,
		SUM(ABS(actual_stake)) AS MemberOutstanding,
		SUM(actual_stake * apositiontaking) AS AgentOutstanding,
		SUM(actual_stake * mpositiontaking) AS MasterOutstanding,
		SUM(actual_stake * spositiontaking) AS SuperOutstanding,
		SUM(pa.PayoutAdjust - actual_stake),
		SUM((pa.PayoutAdjust - actual_stake) * apositiontaking),
		SUM((pa.PayoutAdjust - actual_stake) * mpositiontaking),
		SUM((pa.PayoutAdjust- actual_stake) * spositiontaking)
	FROM dbo.bettrans b WITH (NOLOCK)	
		INNER JOIN #SportBettype s
			ON s.RefTable = 0 AND s.bettype = b.bettype
		OUTER APPLY (
			SELECT 
				CAST(('<xml>' + b.ExtraInfo + '</xml>') AS XML).value('data(/xml/p1/@pa)[1]', 'MONEY') AS PayoutAdjust
			WHERE s.ProductId = 1
		) pa
	WHERE statusId IN (0,1)
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
		AND EXISTS 
		(
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
		AND EXISTS 
		(
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
		AND EXISTS 
		(
			SELECT 1
			FROM #SportBettype s
			WHERE s.RefTable = 2 AND s.bettype = b.gameID
		)
		AND recommend =  @CustID		
	GROUP BY custid;

	IF @IsChatBot = 0 -- Using for report IsChatBot = 0, order by Username
	BEGIN
		WITH rt AS (
				SELECT
					rt.custid,
					SUM(ISNULL(MemberOutstanding, 0)) AS MemberOutstanding,
					SUM(ISNULL(AgentOutstanding, 0))  AS AgentOutstanding,
					SUM(ISNULL(MasterOutstanding, 0)) AS MasterOutstanding,
					SUM(ISNULL(SuperOutstanding, 0))  AS SuperOutstanding,
					SUM(rt.ToWin)AS ToWin,
					SUM(rt.AgentRisk) AS AgentRisk,
					SUM(rt.MasterRisk) AS MasterRisk,
					SUM(rt.SuperRisk) AS SuperRisk,
					ROW_NUMBER() OVER(ORDER BY c.username ) RowNum ,
					c.username
				FROM #OutStanding rt
				INNER JOIN 	dbo.custInfo c WITH (NOLOCK) 
						ON 	rt.custid = c.custid
				GROUP BY rt.custid,c.username
			)
			SELECT
				rt.custid AS CustId,
				rt.username AS CustName,
				rt.MemberOutstanding,
				rt.AgentOutstanding,
				rt.MasterOutstanding,
				rt.SuperOutstanding,
				rt.ToWin,
				rt.AgentRisk,
				rt.MasterRisk,
				rt.SuperRisk
			FROM	
				rt
			WHERE @PageSize <= 0 OR (RowNum BETWEEN @RowStart AND @RowEnd)
			ORDER BY RowNum;
	END
	ELSE -- Using for chatbot IsChatBot = 1, order by AgentOutstanding
	BEGIN
		WITH rt AS (
		SELECT
			custid,
			SUM(ISNULL(MemberOutstanding, 0)) AS MemberOutstanding,
			SUM(ISNULL(AgentOutstanding, 0))  AS AgentOutstanding,
			SUM(ISNULL(MasterOutstanding, 0)) AS MasterOutstanding,
			SUM(ToWin) AS ToWin,
			SUM(AgentRisk) AS AgentRisk,
			SUM(MasterRisk) AS MasterRisk,
			SUM(SuperRisk) AS SuperRisk,
			ROW_NUMBER() OVER(ORDER BY SUM(ISNULL(AgentOutstanding, 0)) DESC) RowNum
		FROM #OutStanding
		GROUP BY custid
		)
		SELECT
			rt.custid AS CustId,
			c.username AS CustName,
			rt.MemberOutstanding,
			rt.AgentOutstanding,
			rt.MasterOutstanding,
			rt.ToWin,
			rt.AgentRisk,
			rt.MasterRisk,
			rt.SuperRisk
		FROM 		rt
		INNER JOIN dbo.custInfo c WITH (NOLOCK) 
				ON rt.custid = c.custid
		WHERE @PageSize <= 0 OR (RowNum BETWEEN @RowStart AND @RowEnd)
		ORDER BY RowNum
	END

	SELECT 	@TotalMemberOutstanding = SUM(ISNULL(MemberOutstanding, 0)),
			@TotalMasterOutstanding	= SUM(ISNULL(MasterOutstanding, 0)),
			@TotalAgentOutstanding 	= SUM(ISNULL(AgentOutstanding, 0)),
			@TotalMemberRiskAmount 	= SUM(ToWin),
			@TotalAgentRiskAmount 	= SUM(AgentRisk),
			@TotalMasterRiskAmount 	= SUM(MasterRisk),
			@TotalSuperRiskAmount 	= SUM(SuperRisk)
	FROM #OutStanding

	DROP TABLE #OutStanding;
	DROP TABLE #SportBettype;

	SET NOCOUNT OFF;
END
GO