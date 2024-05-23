/*<info serverAlias="DBBOF-bodb02" executers="wsv_alp,wsv_alpv" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Age_Rpt_Outstanding_Master]
	@CustID		INT, --srecommend
	@ProductIds	VARCHAR(MAX),
	@IsChatBot BIT = 0,
	@PageSize INT = 0,
	@PageIndex INT = 1,
	@TotalMemberOutstanding	Money = 0 OUTPUT,
	@TotalSuperOutstanding	Money = 0 OUTPUT,
	@SiteLabel varchar(50)

AS

/*
	Created: Paul
	Task : Report Outstanding
	DB: DBBOF.bodb02
	Original: Age_Rpt_Outstanding_SAg
	
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

	CREATE TABLE #SportBettype (bettype SMALLINT, RefTable TINYINT, ProductId TINYINT, PRIMARY KEY CLUSTERED (RefTable, bettype));

	INSERT INTO #SportBettype (bettype, RefTable, ProductId)
	SELECT bettype, RefTable, ProductId
	FROM dbo.f_SportBettypeMatrixByProduct(@ProductIds, @isTest);

	-- #OutStanding
	CREATE TABLE #OutStanding (mrecommend INT, MemberOutstanding MONEY, SuperOutstanding MONEY, MemberToRisk MONEY, SuperRisk MONEY);
	
	-- bettrans
	INSERT INTO #OutStanding (mrecommend, MemberOutstanding, SuperOutstanding)
	SELECT
		mrecommend,
		SUM(ABS(actual_stake)) AS MemberOutstanding,
		SUM(actual_stake * spositiontaking) AS SuperOutstanding
	FROM dbo.bettrans b WITH (NOLOCK)  
	WHERE statusId IN (0, 1)
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
	WHERE t.statusID IN (0, 1)
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
	WHERE b.statusID IN (0, 1)
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
	WHERE b.statusID IN (0, 1)
		AND EXISTS (
			SELECT 1
			FROM #SportBettype s
			WHERE s.RefTable = 2 AND s.bettype = b.gameID
		)
		AND srecommend =  @CustID		
	GROUP BY mrecommend;

	
	-- get data PotentialWinning (only SportBook)
	IF EXISTS (SELECT TOP 1 1 FROM string_split(@ProductIds,',') WHERE value = '1')
	BEGIN
	-- #PotentialWinning
		CREATE TABLE #PotentialWinning (mrecommend INT, MemberToRisk MONEY, SuperRisk MONEY)

		IF @SiteLabel = '789y'
		BEGIN  
				INSERT INTO #PotentialWinning (mrecommend, MemberToRisk, SuperRisk)
				SELECT
					b.mrecommend,
					SUM(c.PayoutAdjust - b.actual_stake) AS MemberToRisk,
					SUM((c.PayoutAdjust - b.actual_stake) * b.spositiontaking) AS SuperRisk
				FROM bettrans b WITH (NOLOCK)
					OUTER APPLY (
									SELECT TOP 1 ABS(c.PayoutAdjust)  AS PayoutAdjust
									FROM CustLimitBetHistory_789 c WITH (NOLOCK) 
									WHERE b.matchid = c.matchid 
										AND b.custid = c.custid 
										AND b.transid = c.transid) c
				WHERE b.statusID IN (0,1)
					AND EXISTS (
								SELECT 1
								FROM #SportBettype s
								WHERE s.RefTable = 0 AND s.ProductID = 1 AND s.bettype = b.bettype
								)
					AND srecommend = @CustID
				GROUP BY b.mrecommend
		END
		ELSE
		BEGIN
				INSERT INTO #PotentialWinning (mrecommend, MemberToRisk, SuperRisk)
				SELECT
					b.mrecommend,
					SUM(c.PayoutAdjust - b.actual_stake) AS MemberToRisk,
					SUM((c.PayoutAdjust - b.actual_stake) * b.spositiontaking) AS SuperRisk
				FROM bettrans b WITH (NOLOCK)
					OUTER APPLY (
									SELECT TOP 1 ABS(c.PayoutAdjust)  AS PayoutAdjust
									FROM CustLimitBetHistory_MBC c WITH (NOLOCK) 
									WHERE b.matchid = c.matchid 
										AND b.custid = c.custid 
										AND b.transid = c.transid) c
				WHERE b.statusID IN (0,1)
					AND EXISTS (
								SELECT 1
								FROM #SportBettype s
								WHERE s.RefTable = 0 AND s.ProductID = 1 AND s.bettype = b.bettype
								)
					AND srecommend = @CustID
				GROUP BY b.mrecommend
		END
	
	END	

	-- UPDATE #OutStanding
	UPDATE o
	SET o.MemberToRisk = p.MemberToRisk , o.SuperRisk = p.SuperRisk
	FROM #OutStanding o 
	LEFT JOIN #PotentialWinning p
		ON p.mrecommend = o.mrecommend

	IF @IsChatBot = 0 -- Using for report IsChatBot = 0, order by Username
		WITH rt AS (
			SELECT
				rt.mrecommend,
				SUM(ISNULL(MemberOutstanding, 0)) AS MemberOutstanding,
				SUM(ISNULL(SuperOutstanding, 0))  AS SuperOutstanding,
				SUM(rt.MemberToRisk) AS MemberToRisk,
				SUM(rt.SuperRisk) AS SuperRisk,
				ROW_NUMBER() OVER (ORDER BY c.username) RowNum,
				c.username
			FROM #OutStanding rt
			INNER JOIN dbo.custInfo c WITH (NOLOCK) 
					ON rt.mrecommend = c.custid
			GROUP BY rt.mrecommend,c.username
		)
		SELECT
			rt.mrecommend AS CustId,
			rt.username AS CustName,
			rt.MemberOutstanding,
			rt.SuperOutstanding,
			rt.MemberToRisk,
			rt.SuperRisk
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
			SUM(MemberToRisk) AS MemberToRisk,
			SUM(SuperRisk) AS SuperRisk,
			ROW_NUMBER() OVER(ORDER BY SUM(ISNULL(SuperOutstanding, 0)) DESC) RowNum
		FROM #OutStanding
		GROUP BY mrecommend
		)
		SELECT
			rt.mrecommend AS CustId,
			c.username AS CustName,
			rt.MemberOutstanding,
			rt.SuperOutstanding,
			rt.MemberToRisk,
			rt.SuperRisk
		FROM 		rt
		INNER JOIN 	dbo.custInfo c WITH (NOLOCK) 
					ON rt.mrecommend = c.custid
		WHERE @PageSize <= 0 OR (RowNum BETWEEN @RowStart AND @RowEnd)
		ORDER BY RowNum
		
	SELECT 	@TotalMemberOutstanding = SUM(ISNULL(MemberOutstanding, 0)),
			@TotalSuperOutstanding = SUM(ISNULL(SuperOutstanding, 0)) 
	FROM #OutStanding

	DROP TABLE #SportBettype;
	DROP TABLE #OutStanding;
	DROP TABLE #PotentialWinning;

	SET NOCOUNT OFF;
END
GO
