/*<info serverAlias="DBCTG-bodb02" executers="wsv_alp,wsv_alpv" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Age_Rpt_Outstanding_Agent_DBTrans]
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
	Created by: 20240611@Bobby
	Task : Switch to DBTrans [RedmineID: #206369]
	DB: DBCTG/bodb02
	Revisions:
		- 20240611@Bobby: Initialize SPs

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

	CREATE TABLE #OutStanding (recommend INT, MemberOutstanding MONEY, MasterOutstanding MONEY, SuperOutstanding MONEY);
 
	-- bettrans
	INSERT INTO #OutStanding (recommend, MemberOutstanding, MasterOutstanding, SuperOutstanding)
	SELECT
		recommend,
		SUM(ABS(actual_stake)) AS MemberOutstanding,
		SUM(actual_stake * mpositiontaking) AS MasterOutstanding,
		SUM(actual_stake * spositiontaking) AS SuperOutstanding
	FROM dbo.bettrans b WITH (NOLOCK)  
	WHERE statusId IN (0, 1) AND SiteDBGroupID IN (3)
		AND EXISTS 
		(
			SELECT 1
			FROM dbo.SportBettypeMatrix s WITH (NOLOCK)
			WHERE ',' + @ProductIds + ',' LIKE '%,' + CONVERT(VARCHAR(3), ProductID) + ',%'
			and IsTest <= @isTest
			AND s.RefTable = 0
			AND s.BetType = b.bettype
		)
		AND mrecommend =  @CustID		
	GROUP BY recommend;
	
	-- translog
	INSERT INTO #OutStanding (recommend, MemberOutstanding, MasterOutstanding, SuperOutstanding)
	SELECT
		recommend,
		SUM(ABS(actual_stake)) AS MemberOutstanding,
		SUM(actual_stake * mpositiontaking) AS MasterOutstanding,
		SUM(actual_stake * spositiontaking) AS SuperOutstanding
	FROM dbo.translog t WITH (NOLOCK)
	WHERE t.statusID IN (0, 1) AND t.SiteDBGroupID IN (3)
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
	WHERE b.statusID IN (0, 1) AND b.SiteDBGroupID IN (3)
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
	WHERE b.statusID IN (0, 1) AND b.SiteDBGroupID IN (3)
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
				ROW_NUMBER() OVER (ORDER BY c.username) RowNum, 
				c.username
			FROM #OutStanding rt
			INNER JOIN 	CustDB.dbo.custInfo c WITH (NOLOCK) 
					ON 	rt.recommend = c.custid
			GROUP BY rt.recommend,c.username
		)
		SELECT
			rt.recommend AS CustId,
			rt.username AS CustName,
			rt.MemberOutstanding,
			rt.MasterOutstanding,
			rt.SuperOutstanding
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
				ROW_NUMBER() OVER(ORDER BY SUM(ISNULL(MasterOutstanding, 0)) DESC) RowNum
			FROM #OutStanding
			GROUP BY recommend
			)
			SELECT
				rt.recommend AS CustId,
				c.username AS CustName,
				rt.MemberOutstanding,
				rt.MasterOutstanding,
				rt.SuperOutstanding
			FROM 		rt
			INNER JOIN CustDB.dbo.custInfo c WITH (NOLOCK) 
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