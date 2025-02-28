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

    CREATE TABLE #SportBettype (ProductID INT, bettype SMALLINT, RefTable TINYINT);

	INSERT INTO #SportBettype (ProductID, bettype, RefTable)
	SELECT ISNULL(p.GroupProductId, s.ProductID), bettype, RefTable
	FROM dbo.f_SportBettypeMatrixByProduct(@ProductIds, @isTest) s
		LEFT JOIN dbo.f_GroupProduct() p ON s.ProductID = p.ProductId;

    CREATE TABLE #OutStanding
    (
        ProductId INT,
        MemberOutstanding MONEY,
        SuperOutstanding MONEY,
		ToWin MONEY,
		SuperRisk MONEY,
		IsSB BIT
    );

    -- bettrans  
    INSERT INTO #OutStanding (ProductId, MemberOutstanding, SuperOutstanding, ToWin, SuperRisk, IsSB)
    SELECT
        s.ProductID,
        SUM(ABS(actual_stake)) AS MemberOutstanding,
        SUM(actual_stake * spositiontaking) AS SuperOutstanding,
		SUM(pa.PayoutAdjust - actual_stake),
		SUM((pa.PayoutAdjust- actual_stake) * spositiontaking),
		ISNULL(pa.IsSB,0) AS IsSB
    FROM dbo.bettrans b WITH (NOLOCK)
		OUTER APPLY (
						SELECT TOP 1
								1 AS IsSB
							   ,ISNULL(CAST(('<xml>' + b.ExtraInfo + '</xml>') AS XML).value('data(/xml/p1/@pa)[1]','MONEY'), 0) AS PayoutAdjust
						WHERE CAST(('<xml>' + b.ExtraInfo + '</xml>') AS XML).exist('/xml/p1') = 1
					) pa
		INNER JOIN (
			SELECT DISTINCT ProductID, bettype
			FROM #SportBettype
			WHERE RefTable = 0
		) s ON s.bettype = b.bettype
    WHERE statusId IN (0, 1)
        AND b.mrecommend = @DownlineId
    GROUP BY s.ProductID,ISNULL(pa.IsSB,0);

    -- translog  
    INSERT INTO #OutStanding (ProductId, MemberOutstanding, SuperOutstanding)
    SELECT
        s.ProductID,
        SUM(ABS(actual_stake)) AS MemberOutstanding,
        SUM(actual_stake * spositiontaking) AS SuperOutstanding
    FROM dbo.translog t WITH (NOLOCK)
		INNER JOIN (
			SELECT DISTINCT ProductID, bettype
			FROM #SportBettype
			WHERE RefTable = 3
		) s ON s.bettype = t.gameID
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
		INNER JOIN (
			SELECT DISTINCT ProductID, bettype
			FROM #SportBettype
			WHERE RefTable = 1
		) s ON s.bettype = b.gameID
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
		INNER JOIN (
			SELECT DISTINCT ProductID, bettype
			FROM #SportBettype
			WHERE RefTable = 2
		) s ON s.bettype = b.gameID
    WHERE b.statusID IN (0, 1)
        AND b.mrecommend = @DownlineId
    GROUP BY s.ProductID;

    SELECT
        ProductId,
        SUM(ISNULL(MemberOutstanding, 0)) AS MemberOutstanding,
        SUM(ISNULL(SuperOutstanding, 0))  AS SuperOutstanding,
		SUM(ISNULL(ToWin,0)) AS ToWin,
		SUM(ISNULL(SuperRisk,0)) AS SuperRisk
    FROM #OutStanding
    GROUP BY ProductId;

    DROP TABLE #SportBettype;
    DROP TABLE #OutStanding;

    SET NOCOUNT OFF;
END  