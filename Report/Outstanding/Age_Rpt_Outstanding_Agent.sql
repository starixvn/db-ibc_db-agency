/*<info serverAlias="DBBOF-bodb02" executers="wsv_alp,wsv_alpv" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Age_Rpt_Outstanding_Agent]
	@CustID		INT, --mrecommend
	@ProductIds	VARCHAR(MAX),
	@IsChatBot BIT = 0,
	@PageSize INT = 0,
	@PageIndex INT = 1,
	@TotalMemberOutstanding	MONEY = 0 OUTPUT,
	@TotalMasterOutstanding	MONEY = 0 OUTPUT,
	@TotalSuperOutstanding	MONEY = 0 OUTPUT,
	@TotalMemberRiskAmount	MONEY = 0 OUTPUT,
	@TotalMasterRiskAmount	MONEY = 0 OUTPUT,
	@TotalSuperRiskAmount	MONEY = 0 OUTPUT,
	@LevelType TINYINT = 0
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
		- 20241119@Lewis: Direct Member [RedmineId: #211969]  
		- 20250626@Bobby: Tuning Perf [RedmineId: #231590]  
		

	Param Explanation:
		- @LevelType:	0: All; 1: Master Agent/ Agent; 2: Direct Member
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
	CREATE TABLE #OutStanding (recommend INT, MemberOutstanding MONEY, MasterOutstanding MONEY, SuperOutstanding MONEY, ToWin MONEY, MasterRisk MONEY, SuperRisk MONEY);

	-- bettrans
	INSERT INTO #OutStanding (recommend, MemberOutstanding, MasterOutstanding, SuperOutstanding, ToWin, MasterRisk, SuperRisk)
	SELECT
		CASE WHEN recommend = -3 THEN custid ELSE recommend END,
		SUM(ABS(actual_stake)) AS MemberOutstanding,
		SUM(actual_stake * mpositiontaking) AS MasterOutstanding,
		SUM(actual_stake * spositiontaking) AS SuperOutstanding,
		SUM(pa.PayoutAdjust - actual_stake),
		SUM((pa.PayoutAdjust - actual_stake) * mpositiontaking),
		SUM((pa.PayoutAdjust- actual_stake) * spositiontaking)
	FROM dbo.bettrans b WITH (NOLOCK) 
		INNER JOIN (
            SELECT DISTINCT sbm.ProductID, sbm.BetType
            FROM dbo.SportBettypeMatrix sbm WITH (NOLOCK)
            WHERE ',' + @ProductIds + ',' LIKE '%,' + CONVERT(VARCHAR(3), sbm.ProductID) + ',%'
                AND IsTest <= @IsTest
                AND RefTable = 0
        
        ) s ON s.bettype = b.bettype
		OUTER APPLY (
			SELECT 
				CAST(('<xml>' + b.ExtraInfo + '</xml>') AS XML).value('data(/xml/p1/@pa)[1]','MONEY') AS PayoutAdjust
			WHERE s.ProductId = 1
		) pa	
	WHERE statusId IN (0, 1)
		AND mrecommend =  @CustID
		AND (
				(@LevelType IN (0,2) AND recommend = -3)
				OR (@LevelType IN (0,1) AND recommend <> -3)
			)
	GROUP BY 
		CASE WHEN recommend = -3 THEN custid ELSE recommend END;

	-- translog
	INSERT INTO #OutStanding (recommend, MemberOutstanding, MasterOutstanding, SuperOutstanding)
	SELECT
		CASE WHEN recommend = -3 THEN custid ELSE recommend END,
		SUM(ABS(actual_stake)) AS MemberOutstanding,
		SUM(actual_stake * mpositiontaking) AS MasterOutstanding,
		SUM(actual_stake * spositiontaking) AS SuperOutstanding
	FROM dbo.translog t WITH (NOLOCK)
		CROSS APPLY (
			SELECT TOP 1 productID
			FROM dbo.SportBettypeMatrix sbm WITH (NOLOCK)
			WHERE ',' + @ProductIds + ',' LIKE '%,' + CONVERT(VARCHAR(3), sbm.ProductID) + ',%'
				AND IsTest <= @IsTest
				AND RefTable = 3
				AND sbm.bettype = t.gameID
		) s
	WHERE t.statusID IN (0, 1)
		AND mrecommend =  @CustID
		AND (
				(@LevelType IN (0,2) AND recommend = -3)
				OR (@LevelType IN (0,1) AND recommend <> -3)
			)
	GROUP BY 
		CASE WHEN recommend = -3 THEN custid ELSE recommend END;

	-- bettransRnG
	INSERT INTO #OutStanding (recommend, MemberOutstanding, MasterOutstanding, SuperOutstanding)
	SELECT
		CASE WHEN recommend = -3 THEN custid ELSE recommend END,
		SUM(ABS(actual_stake)) AS MemberOutstanding,
		SUM(actual_stake * mpositiontaking) AS MasterOutstanding,
		SUM(actual_stake * spositiontaking) AS SuperOutstanding
	FROM dbo.bettransRnG b WITH (NOLOCK)  
		CROSS APPLY (
			SELECT TOP 1 productID
			FROM dbo.SportBettypeMatrix sbm WITH (NOLOCK)
			WHERE ',' + @ProductIds + ',' LIKE '%,' + CONVERT(VARCHAR(3), sbm.ProductID) + ',%'
				AND IsTest <= @IsTest
				AND RefTable = 1
				AND sbm.bettype = b.gameID
		) s
	WHERE b.statusID IN (0, 1)
		AND mrecommend =  @CustID
		AND (
				(@LevelType IN (0,2) AND recommend = -3)
				OR (@LevelType IN (0,1) AND recommend <> -3)
			)		
	GROUP BY 
		CASE WHEN recommend = -3 THEN custid ELSE recommend END;

	-- bettransLC
	INSERT INTO #OutStanding (recommend, MemberOutstanding, MasterOutstanding, SuperOutstanding)
	SELECT
		CASE WHEN recommend = -3 THEN custid ELSE recommend END,
		SUM(ABS(actual_stake)) AS MemberOutstanding,
		SUM(actual_stake * mpositiontaking) AS MasterOutstanding,
		SUM(actual_stake * spositiontaking) AS SuperOutstanding
	FROM dbo.bettransLC b WITH (NOLOCK)  
		CROSS APPLY (
			SELECT TOP 1 productID
			FROM dbo.SportBettypeMatrix sbm WITH (NOLOCK)
			WHERE ',' + @ProductIds + ',' LIKE '%,' + CONVERT(VARCHAR(3), sbm.ProductID) + ',%'
				AND IsTest <= @IsTest
				AND RefTable = 2
				AND sbm.bettype = b.gameID
		) s
	WHERE b.statusID IN (0, 1)
		AND mrecommend =  @CustID	
		AND (
				(@LevelType IN (0,2) AND recommend = -3)
				OR (@LevelType IN (0,1) AND recommend <> -3)
			)
	GROUP BY
		CASE WHEN recommend = -3 THEN custid ELSE recommend END;
	
	--TODO: Result
	IF @IsChatBot = 0 -- Using for report IsChatBot = 0, order by Username
	BEGIN
		WITH rt AS (
			SELECT
				rt.recommend,
				CASE WHEN c.recommend = -3 THEN 1 ELSE 0 END AS IsDirectMember,
				SUM(ISNULL(MemberOutstanding, 0)) AS MemberOutstanding,
				SUM(ISNULL(MasterOutstanding, 0)) AS MasterOutstanding,
				SUM(ISNULL(SuperOutstanding, 0))  AS SuperOutstanding,
				SUM(rt.ToWin) AS ToWin,
				SUM(rt.MasterRisk) AS MasterRisk,
				SUM(rt.SuperRisk) AS SuperRisk,
				ROW_NUMBER() OVER (ORDER BY c.username) RowNum, 
				c.username
			FROM #OutStanding rt
			INNER JOIN 	dbo.custInfo c WITH (NOLOCK) 
					ON 	rt.recommend = c.custid
			GROUP BY rt.recommend,CASE WHEN c.recommend = -3 THEN 1 ELSE 0 END,c.username
		)
		SELECT
			rt.recommend AS CustId,
			rt.username AS CustName,
			rt.IsDirectMember,
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
	END
	ELSE -- Using for chatbot IsChatBot = 1, order by MasterOutstanding
	BEGIN
		WITH rt AS (
			SELECT
				recommend,
				SUM(ISNULL(MemberOutstanding, 0)) AS MemberOutstanding,
				SUM(ISNULL(MasterOutstanding, 0)) AS MasterOutstanding,
				SUM(ISNULL(SuperOutstanding, 0))  AS SuperOutstanding,
				SUM(ToWin) AS ToWin,
				SUM(MasterRisk) AS MasterRisk,
				SUM(SuperRisk) AS SuperRisk,
				ROW_NUMBER() OVER(ORDER BY SUM(ISNULL(MasterOutstanding, 0)) DESC) RowNum
			FROM #OutStanding
			GROUP BY recommend
			)
			SELECT
				rt.recommend AS CustId,
				c.username AS CustName,
				CASE WHEN c.recommend = -3 THEN 1 ELSE 0 END AS IsDirectMember,
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
	END
	SELECT 	@TotalMemberOutstanding = SUM(ISNULL(MemberOutstanding, 0)),
			@TotalSuperOutstanding 	= SUM(ISNULL(SuperOutstanding, 0)) ,
			@TotalMasterOutstanding = SUM(ISNULL(MasterOutstanding, 0)),
			@TotalMemberRiskAmount 	= SUM(ToWin),
			@TotalSuperRiskAmount 	= SUM(SuperRisk) ,
			@TotalMasterRiskAmount 	= SUM(MasterRisk)
	FROM #OutStanding

	DROP TABLE #OutStanding;

	SET NOCOUNT OFF;
END
GO