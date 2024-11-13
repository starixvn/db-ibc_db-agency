/*<info serverAlias="DBBOF-bodb02" executers="wsv_alp,wsv_alpv" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Age_Rpt_Outstanding_Agent]
	@CustID		INT, --mrecommend
	@ProductIds	VARCHAR(MAX),
	@IsChatBot BIT = 0,
	@PageSize INT = 0,
	@PageIndex INT = 1,
	@TotalMemberOutstanding	Money = 0 OUTPUT,
	@TotalMasterOutstanding	Money = 0 OUTPUT,
	@TotalSuperOutstanding	Money = 0 OUTPUT
AS

/*
	Created: Paul
	Task : Report Outstanding
	DB: DBBOF.bodb02
	Original: Age_Rpt_Outstanding_MAg
	
	Revisions:
		- 20161219@Paul: Create new [RedmineID: #68723]
		- 20170622@Percy: Combine Betradar Virtual Sports with Virtual Sports [RedmineID: #78339]
		- 20171020@Percy: get both running and waiting tickets [RedmineID: #84690]
		- 20180731@Patrick: indexes revolution [RedmineId: #98757]
		- 20200612@Sol: added index to temp table #SportBettype [RedmineId: #134967]
		- 20201005@Danny: Change to use alias DBBOF alternative to DB042 [RedmineID: #139516]
		- 20220418@Sol: Alpha - Enhance performance of Outstanding [RedmineID: #171382]
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

	-- #OutStanding
	CREATE TABLE #OutStanding (recommend INT, MemberOutstanding MONEY, MasterOutstanding MONEY, SuperOutstanding MONEY, ToWin MONEY, MasterRisk MONEY, SuperRisk MONEY, IsSB BIT);
 
	-- bettrans
	INSERT INTO #OutStanding (recommend, MemberOutstanding, MasterOutstanding, SuperOutstanding, ToWin, MasterRisk, SuperRisk, IsSB)
	SELECT
		recommend,
		SUM(ABS(actual_stake)) AS MemberOutstanding,
		SUM(actual_stake * mpositiontaking) AS MasterOutstanding,
		SUM(actual_stake * spositiontaking) AS SuperOutstanding,
		SUM(pa.PayoutAdjust - actual_stake),
		SUM((pa.PayoutAdjust - actual_stake) * mpositiontaking),
		SUM((pa.PayoutAdjust- actual_stake) * spositiontaking),
		ISNULL(pa.IsSB,0)
	FROM dbo.bettrans b WITH (NOLOCK)  
		OUTER APPLY (
						SELECT 1 AS IsSB
								, ISNULL(CAST(('<xml>' + b.ExtraInfo + '</xml>') AS XML).value('data(/xml/p1/@pa)[1]','MONEY'), 0) AS PayoutAdjust
						WHERE CAST(('<xml>' + b.ExtraInfo + '</xml>') AS XML).exist('/xml/p1') = 1
					) pa
	WHERE statusId IN (0, 1)
		AND EXISTS 
		(
			SELECT 1
			FROM dbo.SportBettypeMatrix s WITH (NOLOCK)
			WHERE ',' + @ProductIds + ',' LIKE '%,' + CONVERT(VARCHAR(3), ProductID) + ',%'
			AND IsTest <= @isTest
			AND s.RefTable = 0
			AND s.BetType = b.bettype
		)
		AND mrecommend =  @CustID		
	GROUP BY recommend,ISNULL(pa.IsSB,0);
	
	-- translog
	INSERT INTO #OutStanding (recommend, MemberOutstanding, MasterOutstanding, SuperOutstanding)
	SELECT
		recommend,
		SUM(ABS(actual_stake)) AS MemberOutstanding,
		SUM(actual_stake * mpositiontaking) AS MasterOutstanding,
		SUM(actual_stake * spositiontaking) AS SuperOutstanding
	FROM dbo.translog t WITH (NOLOCK)
	WHERE t.statusID IN (0, 1)
		AND mrecommend =  @CustID
		AND EXISTS 
		(
			SELECT 1
			FROM dbo.SportBettypeMatrix s WITH (NOLOCK)
			WHERE ',' + @ProductIds + ',' LIKE '%,' + CONVERT(VARCHAR(3), ProductID) + ',%'
			and IsTest <= @isTest
			AND s.RefTable = 3
			AND s.BetType = t.gameID
		)
	GROUP BY recommend;

	-- bettransRnG
	INSERT INTO #OutStanding (recommend, MemberOutstanding, MasterOutstanding, SuperOutstanding)
	SELECT
		recommend,
		SUM(ABS(actual_stake)) AS MemberOutstanding,
		SUM(actual_stake * mpositiontaking) AS MasterOutstanding,
		SUM(actual_stake * spositiontaking) AS SuperOutstanding
	FROM dbo.bettransRnG b WITH (NOLOCK)  
	WHERE b.statusID IN (0, 1)
		AND EXISTS 
		(
			SELECT 1
			FROM dbo.SportBettypeMatrix s WITH (NOLOCK)
			WHERE ',' + @ProductIds + ',' LIKE '%,' + CONVERT(VARCHAR(3), ProductID) + ',%'
			and IsTest <= @isTest
			AND s.RefTable = 1
			AND s.BetType = b.gameID
		)
		AND mrecommend =  @CustID		
	GROUP BY recommend;

	-- bettransLC
	INSERT INTO #OutStanding (recommend, MemberOutstanding, MasterOutstanding, SuperOutstanding)
	SELECT
		recommend,
		SUM(ABS(actual_stake)) AS MemberOutstanding,
		SUM(actual_stake * mpositiontaking) AS MasterOutstanding,
		SUM(actual_stake * spositiontaking) AS SuperOutstanding
	FROM dbo.bettransLC b WITH (NOLOCK)  
	WHERE b.statusID IN (0, 1)
		AND EXISTS 
		(
			SELECT 1
			FROM dbo.SportBettypeMatrix s WITH (NOLOCK)
			WHERE ',' + @ProductIds + ',' LIKE '%,' + CONVERT(VARCHAR(3), ProductID) + ',%'
			and IsTest <= @isTest
			AND s.RefTable = 2
			AND s.BetType = b.gameID
		)
		AND mrecommend =  @CustID		
	GROUP BY recommend;
	
	IF @IsChatBot = 0 -- Using for report IsChatBot = 0, order by Username
		WITH rt AS (
			SELECT
				rt.recommend,
				SUM(ISNULL(MemberOutstanding, 0)) AS MemberOutstanding,
				SUM(ISNULL(MasterOutstanding, 0)) AS MasterOutstanding,
				SUM(ISNULL(SuperOutstanding, 0))  AS SuperOutstanding,
				SUM(IIF(ISNULL(IsSB,0) = 0,NULL,ISNULL(rt.ToWin,0))) AS ToWin,
				SUM(IIF(ISNULL(IsSB,0) = 0,NULL,ISNULL(rt.MasterRisk,0))) AS MasterRisk,
				SUM(IIF(ISNULL(IsSB,0) = 0,NULL,ISNULL(rt.SuperRisk,0))) AS SuperRisk,
				ROW_NUMBER() OVER (ORDER BY c.username) RowNum, 
				c.username
			FROM #OutStanding rt
			INNER JOIN 	dbo.custInfo c WITH (NOLOCK) 
					ON 	rt.recommend = c.custid
			GROUP BY rt.recommend,c.username
		)
		SELECT
			rt.recommend AS CustId,
			rt.username AS CustName,
			rt.MemberOutstanding,
			rt.MasterOutstanding,
			rt.SuperOutstanding,
			rt.ToWin,
			rt.MasterRisk,
			rt.SuperRisk
		FROM	
			rt
		WHERE @PageSize <= 0 OR (RowNum BETWEEN @RowStart AND @RowEnd)
		ORDER BY RowNum;

	ELSE -- Using for chatbot IsChatBot = 1, order by MasterOutstanding
		WITH rt AS (
			SELECT
				recommend,
				SUM(ISNULL(MemberOutstanding, 0)) AS MemberOutstanding,
				SUM(ISNULL(MasterOutstanding, 0)) AS MasterOutstanding,
				SUM(ISNULL(SuperOutstanding, 0))  AS SuperOutstanding,
				SUM(IIF(ISNULL(IsSB,0) = 0,NULL,ISNULL(ToWin,0))) AS ToWin,
				SUM(IIF(ISNULL(IsSB,0) = 0,NULL,ISNULL(MasterRisk,0))) AS MasterRisk,
				SUM(IIF(ISNULL(IsSB,0) = 0,NULL,ISNULL(SuperRisk,0))) AS SuperRisk,
				ROW_NUMBER() OVER(ORDER BY SUM(ISNULL(MasterOutstanding, 0)) DESC) RowNum
			FROM #OutStanding
			GROUP BY recommend
			)
			SELECT
				rt.recommend AS CustId,
				c.username AS CustName,
				rt.MemberOutstanding,
				rt.MasterOutstanding,
				rt.SuperOutstanding,
				rt.ToWin,
				rt.MasterRisk,
				rt.SuperRisk
			FROM 		rt
			INNER JOIN dbo.custInfo c WITH (NOLOCK) 
					ON rt.recommend = c.custid
			WHERE @PageSize <= 0 OR (RowNum BETWEEN @RowStart AND @RowEnd)
			ORDER BY RowNum

	SELECT 	@TotalMemberOutstanding = SUM(ISNULL(MemberOutstanding, 0)),
			@TotalSuperOutstanding = SUM(ISNULL(SuperOutstanding, 0)) ,
			@TotalMasterOutstanding = SUM(ISNULL(MasterOutstanding, 0))
	FROM #OutStanding

	DROP TABLE #OutStanding;

	SET NOCOUNT OFF;
END
GO