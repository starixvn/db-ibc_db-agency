/*<info serverAlias="DBBOF-bodb02" executers="wsv_alp" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Age_Rpt_DownlineOutstanding_Master]
    @ProductIds VARCHAR(MAX),
    @DownlineId INT -- master
AS

/*  
	Created: Kan
	Task : Report Outstanding
	DB: DBBOF.bodb02
   
	Revisions:  
		- 20181102@Kan: Create new [RedmineId: #103467]
		- 20181108@Paul: Add more code [RedmineId: #103467]
		- 20201005@Danny: Change to use alias DBBOF alternative to DB042 [RedmineID: #139516]
		- 20240523@Lewis: Potential Winning [RedmineId: #202427]  
*/

BEGIN
    SET NOCOUNT ON;

    DECLARE @isTest BIT;
    SELECT  @isTest = dbo.f_CheckSPVersion(@@PROCID);

    SELECT @ProductIds = dbo.f_AddRelatedProducts(@ProductIds);

    CREATE TABLE #SportBettype (ProductID INT, bettype SMALLINT, RefTable TINYINT, PRIMARY KEY(RefTable, Bettype)); 

	INSERT INTO #SportBettype (ProductID, bettype, RefTable)
	SELECT DISTINCT ISNULL(p.GroupProductId, s.ProductID), bettype, RefTable
	FROM dbo.f_SportBettypeMatrixByProduct(@ProductIds, @isTest) s
		LEFT JOIN dbo.f_GroupProduct() p ON s.ProductID = p.ProductId;

    CREATE TABLE #OutStanding
    (
        ProductId INT,
        MemberOutstanding MONEY,
        SuperOutstanding MONEY,
		ToWin MONEY,
		SuperRisk MONEY
    );

    -- bettrans  
    INSERT INTO #OutStanding (ProductId, MemberOutstanding, SuperOutstanding, ToWin, SuperRisk)
    SELECT
        s.ProductID,
        SUM(ABS(actual_stake)) AS MemberOutstanding,
        SUM(actual_stake * spositiontaking) AS SuperOutstanding,
		SUM(pa.PayoutAdjust - actual_stake),
		SUM((pa.PayoutAdjust- actual_stake) * spositiontaking)
    FROM dbo.bettrans b WITH (NOLOCK)
        INNER JOIN #SportBettype s
			ON s.RefTable = 0 AND s.bettype = b.bettype
		OUTER APPLY (
            SELECT CAST(('<xml>' + b.ExtraInfo + '</xml>') AS XML).value('data(/xml/p1/@pa)[1]','MONEY') AS PayoutAdjust
            WHERE s.ProductId = 1
        ) pa
    WHERE statusId IN (0, 1)
        AND b.mrecommend = @DownlineId
    GROUP BY s.ProductID;

    -- translog  
    INSERT INTO #OutStanding (ProductId, MemberOutstanding, SuperOutstanding)
    SELECT
        s.ProductID,
        SUM(ABS(actual_stake)) AS MemberOutstanding,
        SUM(actual_stake * spositiontaking) AS SuperOutstanding
    FROM dbo.translog t WITH (NOLOCK)
        INNER JOIN #SportBettype s
			ON s.RefTable = 3 AND s.bettype = t.gameID
    WHERE t.statusID IN (0, 1)
        AND t.mrecommend = @DownlineId
    GROUP BY s.ProductID;

    -- bettransRnG  
    INSERT INTO #OutStanding (ProductId, MemberOutstanding, SuperOutstanding)
    SELECT
        s.ProductID,
        SUM(ABS(actual_stake)) AS MemberOutstanding,
        SUM(actual_stake * spositiontaking) AS SuperOutstanding
    FROM dbo.bettransRnG b WITH (NOLOCK)
        INNER JOIN #SportBettype s
			ON s.RefTable = 1 AND s.bettype = b.gameID
    WHERE b.statusID IN (0, 1)
        AND b.mrecommend = @DownlineId
    GROUP BY s.ProductID;

    -- bettransLC  
    INSERT INTO #OutStanding (ProductId, MemberOutstanding, SuperOutstanding)
    SELECT
        s.ProductID,
        SUM(ABS(actual_stake)) AS MemberOutstanding,
        SUM(actual_stake * spositiontaking) AS SuperOutstanding
    FROM dbo.bettransLC b WITH (NOLOCK)
        INNER JOIN #SportBettype s
			ON s.RefTable = 2 AND s.bettype = b.gameID
    WHERE b.statusID IN (0, 1)
        AND b.mrecommend = @DownlineId
    GROUP BY s.ProductID;

    SELECT
        ProductId,
        SUM(ISNULL(MemberOutstanding, 0)) AS MemberOutstanding,
        SUM(ISNULL(SuperOutstanding, 0))  AS SuperOutstanding,
		SUM(ToWin) AS ToWin,
		SUM(SuperRisk) AS SuperRisk
    FROM #OutStanding
    GROUP BY ProductId;

    DROP TABLE #SportBettype;
    DROP TABLE #OutStanding;

    SET NOCOUNT OFF;
END  