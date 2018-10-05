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
		- 20181003@Patrick: Index revolution [RedmineID: #101405]
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

	DECLARE @roleID TINYINT, @srecommend INT, @ID INT = 1, @__custId INT
	SET @__custId = @custId

	SELECT  @roleID = roleid, @srecommend = srecommend FROM dbo.custInfo WITH (NOLOCK) WHERE custid = @__custId
	
	-- Get Balance Information --

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
		WHERE custid = @__custId
			AND statusID IN (0, 1)

		-- bettransLC
		INSERT INTO #Outstanding (memberOutstanding)
		SELECT SUM(ABS(actual_stake))
	    FROM dbo.bettransLC WITH (NOLOCK)
		WHERE custid = @__custId
			AND statusID IN (0, 1)

		-- translog
		INSERT INTO #Outstanding (memberOutstanding)
		SELECT SUM(ABS(actual_stake))
	    FROM dbo.translog WITH (NOLOCK)
		WHERE custid = @__custId
			AND statusID IN (0, 1)

		-- bettrans
		INSERT INTO #Outstanding (memberOutstanding)
		SELECT SUM(ABS(actual_stake))
		FROM dbo.bettrans b WITH (NOLOCK)
		WHERE b.custid = @__custId
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
		WHERE recommend = @__custId
			AND statusID IN (0, 1)

		-- bettransLC
		INSERT INTO #Outstanding (agentOutstanding, memberOutstanding)
		SELECT 
			SUM(ABS(actual_stake * apositiontaking)),
			SUM(ABS(actual_stake))
	    FROM dbo.bettransLC WITH (NOLOCK)
		WHERE recommend = @__custId
			AND statusID IN (0, 1)

		-- translog
		INSERT INTO #Outstanding (agentOutstanding, memberOutstanding)
		SELECT 
			SUM(ABS(actual_stake * apositiontaking)),
			SUM(ABS(actual_stake))
	    FROM dbo.translog WITH (NOLOCK)
		WHERE recommend = @__custId
			AND statusID IN (0, 1)

		-- bettrans
		;WITH Bettrans_CTE AS (
			SELECT
				WinlostDate, Bettype,
				SUM(ABS(actual_stake * apositiontaking)) AS agentOutstanding 
			   ,SUM(CASE WHEN custid <> @__custId THEN ABS(actual_stake) ELSE 0 END) AS memberOutstanding
			FROM dbo.bettrans b WITH (NOLOCK)
			WHERE b.recommend = @__custId
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
		-- bettransRNG
		INSERT INTO #Outstanding (masterOutstanding, memberOutstanding)
		SELECT 
			SUM(ABS(actual_stake * mpositiontaking)),
			SUM(ABS(actual_stake))
	    FROM dbo.bettransRNG WITH (NOLOCK)
		WHERE mrecommend = @__custId
			AND statusID IN (0, 1)

		-- bettransLC
		INSERT INTO #Outstanding (masterOutstanding, memberOutstanding)
		SELECT 
			SUM(ABS(actual_stake * mpositiontaking)),
			SUM(ABS(actual_stake))
	    FROM dbo.bettransLC WITH (NOLOCK)
		WHERE mrecommend = @__custId
			AND statusID IN (0, 1)

		-- translog
		INSERT INTO #Outstanding (masterOutstanding, memberOutstanding)
		SELECT 
			SUM(ABS(actual_stake * mpositiontaking)),
			SUM(ABS(actual_stake))
	    FROM dbo.translog WITH (NOLOCK)
		WHERE mrecommend = @__custId
			AND statusID IN (0, 1)

		-- bettrans
		; WITH Bettrans_CTE AS (
			SELECT WinlostDate, Bettype,
				SUM(ABS(actual_stake * mpositiontaking)) AS masterOutstanding ,
				SUM(CASE WHEN custid <> @__custId AND custid <> recommend THEN ABS(actual_stake) ELSE 0 END) AS memberOutstanding
			FROM dbo.bettrans b WITH (NOLOCK)
			WHERE b.mrecommend = @__custId
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
	
		-- bettransRNG
		INSERT INTO #Outstanding (superOutstanding, memberOutstanding)
		SELECT 
			SUM(ABS(actual_stake * spositiontaking)),
			SUM(ABS(actual_stake))
	    FROM dbo.bettransRNG WITH (NOLOCK)
		WHERE srecommend = @__custId
			AND statusID IN (0, 1)

		-- bettransLC
		INSERT INTO #Outstanding (superOutstanding, memberOutstanding)
		SELECT 
			SUM(ABS(actual_stake * spositiontaking)),
			SUM(ABS(actual_stake))
	    FROM dbo.bettransLC WITH (NOLOCK)
		WHERE srecommend = @__custId
			AND statusID IN (0, 1)

		-- translog
		INSERT INTO #Outstanding (superOutstanding, memberOutstanding)
		SELECT
			SUM(ABS(actual_stake * spositiontaking))
		   ,SUM(ABS(actual_stake))
	    FROM dbo.translog t WITH (NOLOCK)
		WHERE srecommend = @__custId
			AND statusID IN (0, 1)

		-- bettrans
		; WITH Bettrans_CTE AS (
			SELECT WinlostDate, Bettype,
				SUM(ABS(actual_stake*spositiontaking)) AS superOutstanding,
				SUM(CASE WHEN custid <> @__custId AND custid <> mrecommend AND custid <> recommend THEN ABS(actual_stake) ELSE 0 END) AS memberOutstanding
			FROM dbo.bettrans b WITH (NOLOCK)   ---- use Index IX_srecommend 
			WHERE b.srecommend = @__custId					
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