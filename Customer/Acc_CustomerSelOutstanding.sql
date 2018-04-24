/*<info serverAlias="DBAGE-bodb02" executers="bodbDownlineNet,bodbDownlineNetView" viewers="" isFunction="0" isNested="1"></info>*/
USE [bodb02]
GO

ALTER PROCEDURE [dbo].[Acc_CustomerSelOutstanding]
	@CustId INT
AS

/*
	Created by Percy
	Date: 2017-10-20
	DB: DBAGE.bodb02
	Task: Core SP - Get Outstanding by CustId

	Revisions:
		- 20171020@Percy: Create new [RedmineID: #84690]
		- 20170108@Sophia: Enhance SP due to high CPU [Redmine: #89029]
		- 20180416@Sophia: Enhance performance high CPU for WC2018 [Redmine: #93100]
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

	DECLARE @roleID TINYINT, @srecommend INT, @ID INT = 1

	SELECT  @roleID = roleid, @srecommend = srecommend FROM dbo.custInfo WITH (NOLOCK) WHERE custid = @custID
	
	-- Get Balance Information --
	--DECLARE @recommend TABLE (custid INT) -- using for super and master level
	--DECLARE @Super TABLE (custid INT) -- using for super level

	DECLARE @MinDate SMALLDATETIME 

	SELECT @MinDate = MIN (WinlostDate)
	FROM dbo.bettrans b WITH (NOLOCK)
	WHERE b.srecommend = @srecommend
			AND b.ruben = 0

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
	    FROM dbo.bettransRNG WITH (NOLOCK)
		WHERE custid = @custid
			AND statusID IN (0, 1)

		-- bettransLC
		INSERT INTO #Outstanding (memberOutstanding)
		SELECT SUM(ABS(actual_stake))
	    FROM dbo.bettransLC WITH (NOLOCK)
		WHERE custid = @custid
			AND statusID IN (0, 1)

		-- translog
		INSERT INTO #Outstanding (memberOutstanding)
		SELECT SUM(ABS(actual_stake))
	    FROM dbo.translog WITH (NOLOCK)
		WHERE custid = @custid
			AND statusID IN (0, 1)

		-- bettrans
		INSERT INTO #Outstanding (memberOutstanding)
		SELECT SUM(ABS(actual_stake))
		FROM dbo.bettrans b WITH (NOLOCK)     ---- use Index IX_custid_matchid_bettype
		WHERE b.custid = @custid
			AND b.ruben = 0
			AND NOT EXISTS (SELECT 1 FROM #SportBettype s WHERE s.Bettype = b.bettype)
    END
    ELSE IF @roleid = 2
    BEGIN

		-- bettransRNG
		INSERT INTO #Outstanding (agentOutstanding, memberOutstanding)
		SELECT 
			SUM(ABS(actual_stake * apositiontaking)),
			SUM(ABS(actual_stake))
	    FROM dbo.bettransRNG WITH (NOLOCK)
		WHERE recommend = @custid
			AND statusID IN (0, 1)

		-- bettransLC
		INSERT INTO #Outstanding (agentOutstanding, memberOutstanding)
		SELECT 
			SUM(ABS(actual_stake * apositiontaking)),
			SUM(ABS(actual_stake))
	    FROM dbo.bettransLC WITH (NOLOCK)
		WHERE recommend = @custid
			AND statusID IN (0, 1)

		-- translog
		INSERT INTO #Outstanding (agentOutstanding, memberOutstanding)
		SELECT 
			SUM(ABS(actual_stake * apositiontaking)),
			SUM(ABS(actual_stake))
	    FROM dbo.translog WITH (NOLOCK)
		WHERE recommend = @custid
			AND statusID IN (0, 1)

		-- bettrans
		;WITH Bettrans_CTE AS (
			SELECT
				WinlostDate, Bettype,
				SUM(ABS(actual_stake * apositiontaking)) AS agentOutstanding 
			   ,SUM(CASE WHEN custid <> @custid THEN ABS(actual_stake) ELSE 0 END) AS memberOutstanding
			FROM dbo.bettrans b WITH (NOLOCK)     ---- use @ID to blind the optimize to use Index IX_srecommend instead of CIX_recommend_matchid_bettype in case big line
			WHERE b.srecommend = @srecommend  
				AND (b.recommend * @ID) = @custid
				AND b.ruben = 0
				AND b.Winlostdate >= @MinDate
			GROUP BY WinlostDate, Bettype
			)
		INSERT INTO #Outstanding (agentOutstanding, memberOutstanding)
		SELECT
			SUM(agentOutstanding)
		   ,SUM(memberOutstanding)
		FROM Bettrans_CTE b  
		WHERE NOT EXISTS (SELECT 1 FROM #SportBettype s WHERE s.Bettype = b.bettype)


    END
    ELSE IF @roleid = 3
    BEGIN
		--INSERT INTO @recommend (custid)
		--SELECT custid FROM dbo.custinfo WITH (NOLOCK)
		--WHERE mrecommend = @custid AND roleid = 2

		-- bettransRNG
		INSERT INTO #Outstanding (masterOutstanding, memberOutstanding)
		SELECT 
			SUM(ABS(actual_stake * mpositiontaking)),
			SUM(ABS(actual_stake))
	    FROM dbo.bettransRNG WITH (NOLOCK)
		WHERE mrecommend = @custid
			AND statusID IN (0, 1)

		-- bettransLC
		INSERT INTO #Outstanding (masterOutstanding, memberOutstanding)
		SELECT 
			SUM(ABS(actual_stake * mpositiontaking)),
			SUM(ABS(actual_stake))
	    FROM dbo.bettransLC WITH (NOLOCK)
		WHERE mrecommend = @custid
			AND statusID IN (0, 1)

		-- translog
		INSERT INTO #Outstanding (masterOutstanding, memberOutstanding)
		SELECT 
			SUM(ABS(actual_stake * mpositiontaking)),
			SUM(ABS(actual_stake))
	    FROM dbo.translog WITH (NOLOCK)
		WHERE mrecommend = @custid
			AND statusID IN (0, 1)

		-- bettrans
		; WITH Bettrans_CTE AS (
			SELECT WinlostDate, Bettype,
				SUM(ABS(actual_stake * mpositiontaking)) AS masterOutstanding ,
				SUM(CASE WHEN custid <> @custid AND custid <> recommend THEN ABS(actual_stake) ELSE 0 END) AS memberOutstanding
			FROM dbo.bettrans b WITH (NOLOCK)
			WHERE b.srecommend = @srecommend   
				AND (b.mrecommend * @ID) = @CustId    ---- use @ID to blind the optimize to use Index IX_srecommend 
				AND b.ruben = 0
				AND b.WinlostDate >= @MinDate		
			GROUP BY WinlostDate, Bettype				
			)
		INSERT INTO #Outstanding (masterOutstanding, memberOutstanding)
		SELECT
			SUM(masterOutstanding),
		    SUM(memberOutstanding)
		FROM Bettrans_CTE b
		WHERE NOT EXISTS (SELECT 1 FROM #SportBettype s WHERE s.Bettype = b.bettype)

    END
    ELSE IF @roleid = 4
    BEGIN
		-- INSERT INTO @recommend (custid)
		--SELECT custid FROM dbo.custinfo WITH (NOLOCK)
		--WHERE srecommend = @custid AND roleid = 2

		--INSERT INTO @Super (custid) -- this super and all masters
		--SELECT custid FROM dbo.custinfo WITH (NOLOCK)
		--WHERE srecommend = @custid AND roleid IN (3, 4)

		-- bettransRNG
		INSERT INTO #Outstanding (superOutstanding, memberOutstanding)
		SELECT 
			SUM(ABS(actual_stake * spositiontaking)),
			SUM(ABS(actual_stake))
	    FROM dbo.bettransRNG WITH (NOLOCK)
		WHERE srecommend = @custid
			AND statusID IN (0, 1)

		-- bettransLC
		INSERT INTO #Outstanding (superOutstanding, memberOutstanding)
		SELECT 
			SUM(ABS(actual_stake * spositiontaking)),
			SUM(ABS(actual_stake))
	    FROM dbo.bettransLC WITH (NOLOCK)
		WHERE srecommend = @custid
			AND statusID IN (0, 1)

		-- translog
		INSERT INTO #Outstanding (superOutstanding, memberOutstanding)
		SELECT
			SUM(ABS(actual_stake * spositiontaking))
		   ,SUM(ABS(actual_stake))
	    FROM dbo.translog t WITH (NOLOCK)
		WHERE EXISTS (
				SELECT 1
				FROM dbo.custInfo c WITH (NOLOCK)
				WHERE c.srecommend = @custid AND c.roleid = 3 AND t.mrecommend = c.custid
			) -- using index on mrecommend
			AND statusID IN (0, 1)

		-- bettrans
		; WITH Bettrans_CTE AS (
			SELECT WinlostDate, Bettype,
				SUM(ABS(actual_stake*spositiontaking)) AS superOutstanding,
				SUM(CASE WHEN custid <> @CustId AND custid <> mrecommend AND custid <> recommend THEN ABS(actual_stake) ELSE 0 END) AS memberOutstanding
			FROM dbo.bettrans b WITH (NOLOCK)   ---- use Index IX_srecommend 
			WHERE b.srecommend = @custId					
				AND b.ruben = 0
				AND b.WinlostDate >= @MinDate
			GROUP BY WinlostDate, Bettype
			)
		INSERT INTO #Outstanding (superOutstanding, memberOutstanding)
		SELECT
			SUM(superOutstanding),
			SUM(memberOutstanding)
		FROM Bettrans_CTE b
		WHERE NOT EXISTS (SELECT 1 FROM #SportBettype s WHERE s.Bettype = b.bettype)

    END

	SELECT
		SUM(superOutstanding)	AS superOutstanding,
		SUM(masterOutstanding)	AS masterOutstanding,
		SUM(agentOutstanding)	AS agentOutstanding,
		SUM(memberOutstanding)	AS memberOutstanding
	FROM #Outstanding
	
	DROP TABLE #SportBettype
	DROP TABLE #Outstanding
END
GO