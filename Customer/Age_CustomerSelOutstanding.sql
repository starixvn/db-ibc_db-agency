/*<info serverAlias="DBAGE-bodb02" executers="bodbDownlineNet,bodbDownlineNetView" viewers="" isFunction="0" isNested="1"></info>*/
USE [bodb02]
GO

ALTER PROCEDURE [dbo].[Age_CustomerSelOutstanding]
    @CustId INT
AS

/*
    Created by Percy
    Date: 2017-10-20
    DB: DB042.bodb02
    Task: Core SP - Get Outstanding by CustId
    Original: Acc_CustomerSelOutstanding

    Revisions:
        - 20171020@Percy: Create new [RedmineID: #84690]
        - 20170108@Sophia: Enhance SP due to high CPU [Redmine: #89029]
        - 20180416@Sophia: Enhance performance high CPU for WC2018 [Redmine: #93100]
        - 20180731@Patrick: indexes revolution [RedmineId: #98757]
*/

BEGIN
    SET NOCOUNT ON

    -- Get bettype --
    DECLARE @isTest BIT = 0
    SELECT  @isTest = dbo.f_CheckSPVersion(@@PROCID)
    
    CREATE TABLE #SportBettype (bettype INT)
    INSERT INTO #SportBettype (bettype)
    SELECT bettype FROM dbo.f_SportBettypeMatrix_Sel (0, 0, 0, 2, '', '', @isTest)
    WHERE RefTable <> 0 -- exclude bettrans

    DECLARE @roleID TINYINT
    SELECT  @roleID = roleid FROM dbo.custInfo WITH (NOLOCK) WHERE custid = @custID
    
    -- Get Balance Information --
    CREATE TABLE #Outstanding
    (
        superOutstanding  MONEY DEFAULT ((0)),
        masterOutstanding MONEY DEFAULT ((0)),
        agentOutstanding  MONEY DEFAULT ((0)),
        memberOutstanding MONEY DEFAULT ((0))
    )

    IF @roleid = 1
    BEGIN
        -- bettransRNG
        INSERT INTO #Outstanding (memberOutstanding)
        SELECT SUM(ABS(actual_stake))
        FROM dbo.bettransRNG WITH (NOLOCK, Index=IX_betrunning_custid)
        WHERE custid = @custid
            AND statusID IN (0, 1)

        -- bettransLC
        INSERT INTO #Outstanding (memberOutstanding)
        SELECT SUM(ABS(actual_stake))
        FROM dbo.bettransLC WITH (NOLOCK, Index=IX_betrunning_custid)
        WHERE custid = @custid
            AND statusID IN (0, 1)

        -- translog
        INSERT INTO #Outstanding (memberOutstanding)
        SELECT SUM(ABS(actual_stake))
        FROM dbo.translog WITH (NOLOCK, Index=IX_betrunning_custid)
        WHERE custid = @custid
            AND statusID IN (0, 1)

        -- bettrans
        INSERT INTO #Outstanding (memberOutstanding)
        SELECT SUM(ABS(actual_stake))
        FROM dbo.bettrans b WITH (NOLOCK, Index=IX_betrunning_custid)
        WHERE b.custid = @custid
            AND b.statusId IN (0,1)
            AND NOT EXISTS (SELECT 1 FROM #SportBettype s WHERE s.Bettype = b.bettype)
    END
    ELSE IF @roleid = 2
    BEGIN

        -- bettransRNG
        INSERT INTO #Outstanding (agentOutstanding, memberOutstanding)
        SELECT 
            SUM(ABS(actual_stake * apositiontaking)),
            SUM(ABS(actual_stake))
        FROM dbo.bettransRNG WITH (NOLOCK, Index=IX_betrunning_recommend)
        WHERE recommend = @custid
            AND statusID IN (0, 1)

        -- bettransLC
        INSERT INTO #Outstanding (agentOutstanding, memberOutstanding)
        SELECT 
            SUM(ABS(actual_stake * apositiontaking)),
            SUM(ABS(actual_stake))
        FROM dbo.bettransLC WITH (NOLOCK, Index=IX_betrunning_recommend)
        WHERE recommend = @custid
            AND statusID IN (0, 1)

        -- translog
        INSERT INTO #Outstanding (agentOutstanding, memberOutstanding)
        SELECT 
            SUM(ABS(actual_stake * apositiontaking)),
            SUM(ABS(actual_stake))
        FROM dbo.translog WITH (NOLOCK, Index=IX_betrunning_recommend)
        WHERE recommend = @custid
            AND statusID IN (0, 1)

        -- bettrans
        INSERT INTO #Outstanding (agentOutstanding, memberOutstanding)
        SELECT
            SUM(ABS(actual_stake * apositiontaking)) AS agentOutstanding 
           ,SUM(CASE WHEN custid <> @custid THEN ABS(actual_stake) ELSE 0 END) AS memberOutstanding
        FROM dbo.bettrans b WITH(NOLOCK)
        WHERE NOT EXISTS (SELECT 1 FROM #SportBettype s WHERE s.Bettype = b.bettype)
            AND b.recommend = @custid
            AND statusId IN (0,1)
    END
    ELSE IF @roleid = 3
    BEGIN
        -- bettransRNG
        INSERT INTO #Outstanding (masterOutstanding, memberOutstanding)
        SELECT 
            SUM(ABS(actual_stake * mpositiontaking)),
            SUM(ABS(actual_stake))
        FROM dbo.bettransRNG WITH (NOLOCK, Index=IX_betrunning_mrecommend)
        WHERE mrecommend = @custid
            AND statusID IN (0, 1)

        -- bettransLC
        INSERT INTO #Outstanding (masterOutstanding, memberOutstanding)
        SELECT 
            SUM(ABS(actual_stake * mpositiontaking)),
            SUM(ABS(actual_stake))
        FROM dbo.bettransLC WITH (NOLOCK, Index=IX_betrunning_mrecommend)
        WHERE mrecommend = @custid
            AND statusID IN (0, 1)

        -- translog
        INSERT INTO #Outstanding (masterOutstanding, memberOutstanding)
        SELECT 
            SUM(ABS(actual_stake * mpositiontaking)),
            SUM(ABS(actual_stake))
        FROM dbo.translog WITH (NOLOCK, Index=IX_betrunning_mrecommend)
        WHERE mrecommend = @custid
            AND statusID IN (0, 1)

        -- bettrans
        INSERT INTO #Outstanding (masterOutstanding, memberOutstanding)
        SELECT
            SUM(ABS(actual_stake * mpositiontaking)) AS masterOutstanding 
           ,SUM(CASE WHEN custid <> @custid AND custid <> recommend THEN ABS(actual_stake) ELSE 0 END) AS memberOutstanding
        FROM dbo.bettrans b WITH(NOLOCK)
        WHERE NOT EXISTS (SELECT 1 FROM #SportBettype s WHERE s.Bettype = b.bettype)
            AND b.mrecommend = @custid
            AND statusId IN (0,1)

    END
    ELSE IF @roleid = 4
    BEGIN
    
        -- bettransRNG
        INSERT INTO #Outstanding (superOutstanding, memberOutstanding)
        SELECT 
            SUM(ABS(actual_stake * spositiontaking)),
            SUM(ABS(actual_stake))
        FROM dbo.bettransRNG WITH (NOLOCK, Index=IX_betrunning_srecommend)
        WHERE srecommend = @custid
            AND statusID IN (0, 1)

        -- bettransLC
        INSERT INTO #Outstanding (superOutstanding, memberOutstanding)
        SELECT 
            SUM(ABS(actual_stake * spositiontaking)),
            SUM(ABS(actual_stake))
        FROM dbo.bettransLC WITH (NOLOCK, Index=IX_betrunning_srecommend)
        WHERE srecommend = @custid
            AND statusID IN (0, 1)

        -- translog
        INSERT INTO #Outstanding (superOutstanding, memberOutstanding)
        SELECT
            SUM(ABS(actual_stake * spositiontaking))
           ,SUM(ABS(actual_stake))
        FROM dbo.translog t WITH (NOLOCK, Index=IX_betrunning_srecommend)
        WHERE t.srecommend = @custid
            AND statusID IN (0, 1)

        -- bettrans
        INSERT INTO #Outstanding (superOutstanding, memberOutstanding)
        SELECT
            SUM(ABS(actual_stake * spositiontaking)) AS superOutstanding 
           ,SUM(CASE WHEN custid <> @custid AND custid <> recommend AND custid <> mrecommend THEN ABS(actual_stake) ELSE 0 END) AS memberOutstanding
        FROM dbo.bettrans b WITH(NOLOCK)
        WHERE NOT EXISTS (SELECT 1 FROM #SportBettype s WHERE s.Bettype = b.bettype)
            AND b.srecommend = @custid
            AND statusId IN (0,1)

    END

    SELECT
        SUM(superOutstanding)    AS superOutstanding,
        SUM(masterOutstanding)    AS masterOutstanding,
        SUM(agentOutstanding)    AS agentOutstanding,
        SUM(memberOutstanding)    AS memberOutstanding
    FROM #Outstanding
    
    DROP TABLE #SportBettype
    DROP TABLE #Outstanding
END
GO