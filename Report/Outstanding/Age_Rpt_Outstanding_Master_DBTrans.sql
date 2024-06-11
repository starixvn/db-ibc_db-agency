/*<info serverAlias="DBCTG-bodb02" executers="wsv_alp,wsv_alpv" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Age_Rpt_Outstanding_Master_DBTrans]
	@CustID		INT, --srecommend
	@ProductIds	VARCHAR(MAX),
	@IsChatBot BIT = 0,
	@PageSize INT = 0,
	@PageIndex INT = 1,
	@TotalMemberOutstanding	Money = 0 OUTPUT,
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

	CREATE TABLE #SportBettype (bettype SMALLINT, RefTable TINYINT, PRIMARY KEY CLUSTERED (RefTable, bettype));

	INSERT INTO #SportBettype (bettype, RefTable)
	SELECT bettype, RefTable
	FROM dbo.f_SportBettypeMatrixByProduct(@ProductIds, @isTest);

	CREATE TABLE #OutStanding (mrecommend INT, MemberOutstanding MONEY, SuperOutstanding MONEY);

	-- bettrans
	INSERT INTO #OutStanding (mrecommend, MemberOutstanding, SuperOutstanding)
	SELECT
		mrecommend,
		SUM(ABS(actual_stake)) AS MemberOutstanding,
		SUM(actual_stake * spositiontaking) AS SuperOutstanding
	FROM dbo.bettrans b WITH (NOLOCK)  
	WHERE statusId IN (0, 1) AND SiteDBGroupID IN (3)
		AND EXISTS (
			SELECT 1
			FROM #SportBettype s
			WHERE s.RefTable = 0 AND s.bettype = b.bettype
		) -- bet tickets
		AND srecommend = @CustID		
	GROUP BY mrecommend;
	
	-- translog
	INSERT INTO #OutStanding (mrecommend, MemberOutstanding, SuperOutstanding)
	SELECT
		t.mrecommend,
		SUM(ABS(actual_stake)) AS MemberOutstanding,
		SUM(actual_stake * spositiontaking) AS SuperOutstanding
	FROM dbo.translog t WITH (NOLOCK)
	WHERE t.statusID IN (0, 1) AND t.SiteDBGroupID IN (3)
		AND t.srecommend = @CustID
		AND EXISTS (
			SELECT 1
			FROM #SportBettype s
			WHERE s.RefTable = 3 AND s.bettype = t.gameID
		)
	GROUP BY t.mrecommend;

	-- bettransRnG
	INSERT INTO #OutStanding (mrecommend, MemberOutstanding, SuperOutstanding)
	SELECT
		mrecommend,
		SUM(ABS(actual_stake)) AS MemberOutstanding,
		SUM(actual_stake * spositiontaking) AS SuperOutstanding
	FROM dbo.bettransRnG b WITH (NOLOCK)  
	WHERE b.statusID IN (0, 1) AND b.SiteDBGroupID IN (3)
		AND EXISTS (
			SELECT 1
			FROM #SportBettype s
			WHERE s.RefTable = 1 AND s.bettype = b.gameID
		)
		AND srecommend =  @CustID		
	GROUP BY mrecommend;

	-- bettransLC
	INSERT INTO #OutStanding (mrecommend, MemberOutstanding, SuperOutstanding)
	SELECT
		mrecommend,
		SUM(ABS(actual_stake)) AS MemberOutstanding,
		SUM(actual_stake * spositiontaking) AS SuperOutstanding
	FROM dbo.bettransLC b WITH (NOLOCK)  
	WHERE b.statusID IN (0, 1) AND b.SiteDBGroupID IN (3)
		AND EXISTS (
			SELECT 1
			FROM #SportBettype s
			WHERE s.RefTable = 2 AND s.bettype = b.gameID
		)
		AND srecommend =  @CustID		
	GROUP BY mrecommend;

	IF @IsChatBot = 0 -- Using for report IsChatBot = 0, order by Username
		WITH rt AS (
			SELECT
				rt.mrecommend,
				SUM(ISNULL(MemberOutstanding, 0)) AS MemberOutstanding,
				SUM(ISNULL(SuperOutstanding, 0))  AS SuperOutstanding,
				ROW_NUMBER() OVER (ORDER BY c.username) RowNum,
				c.username
			FROM #OutStanding rt
			INNER JOIN CustDB.dbo.custInfo c WITH (NOLOCK) 
					ON rt.mrecommend = c.custid
			GROUP BY rt.mrecommend,c.username
		)
		SELECT
			rt.mrecommend AS CustId,
			rt.username AS CustName,
			rt.MemberOutstanding,
			rt.SuperOutstanding
		FROM	
			rt
		WHERE @PageSize <= 0 OR (RowNum BETWEEN @RowStart AND @RowEnd)
		ORDER BY RowNum;

	ELSE -- Using for chatbot IsChatBot = 1, order by SuperOutstanding
		WITH rt AS (
		SELECT
			mrecommend,
			SUM(ISNULL(MemberOutstanding, 0)) AS MemberOutstanding,
			SUM(ISNULL(SuperOutstanding, 0))  AS SuperOutstanding,
			ROW_NUMBER() OVER(ORDER BY SUM(ISNULL(SuperOutstanding, 0)) DESC) RowNum
		FROM #OutStanding
		GROUP BY mrecommend
		)
		SELECT
			rt.mrecommend AS CustId,
			c.username AS CustName,
			rt.MemberOutstanding,
			rt.SuperOutstanding
		FROM 		rt
		INNER JOIN 	CustDB.dbo.custInfo c WITH (NOLOCK) 
					ON rt.mrecommend = c.custid
		WHERE @PageSize <= 0 OR (RowNum BETWEEN @RowStart AND @RowEnd)
		ORDER BY RowNum
		
	SELECT 	@TotalMemberOutstanding = SUM(ISNULL(MemberOutstanding, 0)),
			@TotalSuperOutstanding = SUM(ISNULL(SuperOutstanding, 0)) 
	FROM #OutStanding

	DROP TABLE #SportBettype;
	DROP TABLE #OutStanding;

	SET NOCOUNT OFF;
END
GO
