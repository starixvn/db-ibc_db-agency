/*<info serverAlias="DB042-bodb02" executers="bodbDownlineNet" viewers="vnteam" isFunction="0" isNested="0"></info>*/
USE [bodb02]
GO

ALTER PROCEDURE [dbo].[Age_Rpt_DownlineOutstanding_Master]
    @CustID  INT, --srecommend
    @ProductIds VARCHAR(MAX),
    @DownlineId INT -- master
AS

/*  
 Created: Kan
 Task : Report Outstanding
 DB: DB042-bodb02
   
 Revisions:  
  - 20181102@Kan: Create new [RedmineId: #103467]
*/

BEGIN
    SET NOCOUNT ON;

    DECLARE @isTest BIT;
    SELECT @isTest = dbo.f_CheckSPVersion(@@PROCID);

    SELECT @ProductIds = dbo.f_AddRelatedProducts(@ProductIds);

    CREATE TABLE #SportBettype
    (
        bettype SMALLINT,
        RefTable TINYINT
    );

    INSERT INTO #SportBettype
        (bettype, RefTable)
    SELECT bettype, RefTable
    FROM dbo.f_SportBettypeMatrixByProduct(@ProductIds, @isTest);

    CREATE TABLE #OutStanding
    (
        mrecommend INT,
        MemberOutstanding MONEY,
        SuperOutstanding MONEY
    );

    -- bettrans  
    INSERT INTO #OutStanding
        (mrecommend, MemberOutstanding, SuperOutstanding)
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
        AND b.mrecommend = @DownlineId
    GROUP BY mrecommend;

    -- translog  
    INSERT INTO #OutStanding
        (mrecommend, MemberOutstanding, SuperOutstanding)
    SELECT
        t.mrecommend,
        SUM(ABS(actual_stake)) AS MemberOutstanding,
        SUM(actual_stake * spositiontaking) AS SuperOutstanding
    FROM dbo.translog t WITH (NOLOCK)
    WHERE t.statusID IN (0, 1)
        AND t.srecommend = @CustID
        AND t.mrecommend = @DownlineId
        AND EXISTS (  
   SELECT 1
        FROM #SportBettype s
        WHERE s.RefTable = 3 AND s.bettype = t.gameID  
  )
    GROUP BY t.mrecommend;

    -- bettransRnG  
    INSERT INTO #OutStanding
        (mrecommend, MemberOutstanding, SuperOutstanding)
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
        AND b.mrecommend = @DownlineId
    GROUP BY mrecommend;

    -- bettransLC  
    INSERT INTO #OutStanding
        (mrecommend, MemberOutstanding, SuperOutstanding)
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
        AND b.mrecommend = @DownlineId
    GROUP BY mrecommend;

    WITH
        rt
        AS
        (
            SELECT
                mrecommend,
                SUM(ISNULL(MemberOutstanding, 0)) AS MemberOutstanding,
                SUM(ISNULL(SuperOutstanding, 0))  AS SuperOutstanding
            FROM #OutStanding
            GROUP BY mrecommend
        )
    SELECT
        rt.mrecommend AS CustId,
        c.username AS CustName,
        rt.MemberOutstanding,
        rt.SuperOutstanding
    FROM rt
        INNER JOIN dbo.custInfo c WITH (NOLOCK) ON rt.mrecommend = c.custid
    ORDER BY c.username;

    DROP TABLE #SportBettype;
    DROP TABLE #OutStanding;

    SET NOCOUNT OFF;
END  