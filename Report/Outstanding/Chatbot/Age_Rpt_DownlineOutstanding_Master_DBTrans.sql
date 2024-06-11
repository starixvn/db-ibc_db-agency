/*<info serverAlias="DBCTG-bodb02" executers="wsv_alp" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Age_Rpt_DownlineOutstanding_Master_DBTrans]
    @ProductIds VARCHAR(MAX),
    @DownlineId INT -- master
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
        SuperOutstanding MONEY
    );

    -- bettrans  
    INSERT INTO #OutStanding (ProductId, MemberOutstanding, SuperOutstanding)
    SELECT
        s.ProductID,
        SUM(ABS(actual_stake)) AS MemberOutstanding,
        SUM(actual_stake * spositiontaking) AS SuperOutstanding
    FROM dbo.bettrans b WITH (NOLOCK)
		INNER JOIN (
			SELECT DISTINCT ProductID, bettype
			FROM #SportBettype
			WHERE RefTable = 0
		) s ON s.bettype = b.bettype
    WHERE statusId IN (0, 1) AND SiteDBGroupID IN (3)
        AND b.mrecommend = @DownlineId
    GROUP BY s.ProductID;

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
    WHERE t.statusID IN (0, 1) AND t.SiteDBGroupID IN (3)
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
    WHERE b.statusID IN (0, 1) AND b.SiteDBGroupID IN (3)
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
    WHERE b.statusID IN (0, 1) AND b.SiteDBGroupID IN (3)
        AND b.mrecommend = @DownlineId
    GROUP BY s.ProductID;

    SELECT
        ProductId,
        SUM(ISNULL(MemberOutstanding, 0)) AS MemberOutstanding,
        SUM(ISNULL(SuperOutstanding, 0))  AS SuperOutstanding
    FROM #OutStanding
    GROUP BY ProductId;

    DROP TABLE #SportBettype;
    DROP TABLE #OutStanding;

    SET NOCOUNT OFF;
END  