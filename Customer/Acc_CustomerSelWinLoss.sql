/*<info serverAlias="DBAGE-bodb02" executers="bodbDownlineNet,bodbDownlineNetView" viewers="" isFunction="0" isNested="1"></info>*/
USE [bodb02]
GO

ALTER PROCEDURE [dbo].[Acc_CustomerSelWinLoss]
	@CustId INT
AS

/*
	Created by Percy
	Date: 2017-10-20
	DB: DBAGE.bodb02
	Task: Core SP - Get Win Loss by CustId

	Revisions:
		20171020@Percy: Create new [RedmineID: #84690]
		20180413@Sophia: Enhance performance for WC2018 (HighCPU)[Redmine: #93100]
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @yesterday SMALLDATETIME
	SELECT  @yesterday = CONVERT(DATE, DATEADD(DAY, -1, GETDATE()))

	-- Get bettype --
	DECLARE @isTest BIT = 0
	SELECT  @isTest = dbo.f_CheckSPVersion(@@PROCID)
	
	CREATE TABLE #SportBettype (bettype INT)
	INSERT INTO #SportBettype (bettype)
	SELECT bettype FROM dbo.f_SportBettypeMatrix_Sel (0, 0, 0, 2, '', '', @isTest)
	WHERE RefTable IN (0, 3) -- bettrans, translog

	DECLARE @roleID TINYINT,
			@srecommend INT

	SELECT  @roleID = roleid, @srecommend = srecommend FROM dbo.custInfo WITH (NOLOCK) WHERE custid = @custID
	
	CREATE TABLE #WinLoss (todayWinloss MONEY, yesterdayWinloss MONEY)

    IF @roleid = 1
	BEGIN
		-- bettransRNG
		INSERT INTO #WinLoss (todayWinloss, yesterdayWinloss)
		SELECT 
			SUM(CASE WHEN winlostdate > @yesterday THEN winlost-actual_stake+playercomm ELSE 0 END),
			SUM(CASE WHEN winlostdate = @yesterday THEN winlost-actual_stake+playercomm ELSE 0 END)
	    FROM dbo.bettransRNG WITH (NOLOCK)
		WHERE custid = @custid
			AND winlostdate >= @yesterday
			AND statusID NOT IN (0, 1)

		-- bettransLC
		INSERT INTO #WinLoss (todayWinloss, yesterdayWinloss)
		SELECT 
			SUM(CASE WHEN winlostdate > @yesterday THEN winlost-actual_stake+playercomm ELSE 0 END),
			SUM(CASE WHEN winlostdate = @yesterday THEN winlost-actual_stake+playercomm ELSE 0 END)
	    FROM dbo.bettransLC WITH (NOLOCK)
		WHERE custid = @custid
			AND winlostdate >= @yesterday
			AND statusID NOT IN (0, 1)
  			
		-- bettrans
		;WITH BettransCTE AS (
			SELECT winlostdate, bettype,
					SUM(winlost) AS winlost,
					SUM(actual_stake) AS actual_stake,
					SUM(playercomm) AS playercomm
			FROM dbo.bettrans b WITH (NOLOCK)
			WHERE b.custid = @custid
				AND b.srecommend = @srecommend
				AND b.ruben = 1
				AND b.winlostdate >= @yesterday
			GROUP BY winlostdate, bettype
		)
		INSERT INTO #WinLoss (todayWinloss, yesterdayWinloss)
		SELECT
			SUM(CASE WHEN winlostdate > @yesterday THEN winlost-actual_stake+playercomm ELSE 0 END),
			SUM(CASE WHEN winlostdate = @yesterday THEN winlost-actual_stake+playercomm ELSE 0 END)
		FROM BettransCTE b WITH (NOLOCK)
		WHERE EXISTS (SELECT TOP 1 1 FROM #SportBettype s WHERE s.Bettype = b.bettype)	
			
    END
    ELSE IF @roleid = 2
    BEGIN
		-- bettransRNG
		INSERT INTO #WinLoss (todayWinloss, yesterdayWinloss)
		SELECT 
			SUM(CASE WHEN winlostdate > @yesterday THEN awinlost+comm-playercomm ELSE 0 END),
			SUM(CASE WHEN winlostdate = @yesterday THEN awinlost+comm-playercomm ELSE 0 END)
	    FROM dbo.bettransRNG WITH (NOLOCK)
		WHERE recommend = @custid
			AND winlostdate >= @yesterday
			AND statusID NOT IN (0, 1)

		-- bettransLC
		INSERT INTO #WinLoss (todayWinloss, yesterdayWinloss)
		SELECT 
			SUM(CASE WHEN winlostdate > @yesterday THEN awinlost+comm-playercomm ELSE 0 END),
			SUM(CASE WHEN winlostdate = @yesterday THEN awinlost+comm-playercomm ELSE 0 END)
	    FROM dbo.bettransLC WITH (NOLOCK)
		WHERE recommend = @custid
			AND winlostdate >= @yesterday
			AND statusID NOT IN (0, 1)
			
		-- bettrans
		;WITH BettransCTE AS (
			SELECT winlostdate, bettype,
					SUM(awinlost) AS awinlost,
					SUM(comm) AS comm,
					SUM(playercomm) AS playercomm
			FROM dbo.bettrans b WITH (NOLOCK)
			WHERE b.recommend = @custid
				AND b.srecommend = @srecommend
				AND b.ruben = 1
				AND b.winlostdate >= @yesterday
			GROUP BY winlostdate, bettype
		)
		INSERT INTO #WinLoss (todayWinloss, yesterdayWinloss)
		SELECT
			SUM(CASE WHEN winlostdate > @yesterday THEN awinlost+comm-playercomm ELSE 0 END),
			SUM(CASE WHEN winlostdate = @yesterday THEN awinlost+comm-playercomm ELSE 0 END)
		FROM BettransCTE b WITH (NOLOCK)
		WHERE EXISTS (SELECT TOP 1 1 FROM #SportBettype s WHERE s.Bettype = b.bettype)
		
    END
    ELSE IF @roleid = 3
    BEGIN 

		-- bettransRNG
		INSERT INTO #WinLoss (todayWinloss, yesterdayWinloss)
		SELECT 
			SUM(CASE WHEN winlostdate > @yesterday THEN mwinlost+acomm-comm ELSE 0 END),
			SUM(CASE WHEN winlostdate = @yesterday THEN mwinlost+acomm-comm ELSE 0 END)
	    FROM dbo.bettransRNG WITH (NOLOCK)
		WHERE mrecommend = @custid
			AND winlostdate >= @yesterday
			AND statusID NOT IN (0, 1)

		-- bettransLC
		INSERT INTO #WinLoss (todayWinloss, yesterdayWinloss)
		SELECT 
			SUM(CASE WHEN winlostdate > @yesterday THEN mwinlost+acomm-comm ELSE 0 END),
			SUM(CASE WHEN winlostdate = @yesterday THEN mwinlost+acomm-comm ELSE 0 END)
	    FROM dbo.bettransLC WITH (NOLOCK)
		WHERE mrecommend = @custid
			AND winlostdate >= @yesterday
			AND statusID NOT IN (0, 1)

			
		-- bettrans
		;WITH BettransCTE AS (
			SELECT winlostdate, bettype,
					SUM(mwinlost) AS mwinlost,
					SUM(acomm) AS acomm,
					SUM(comm) AS comm
			FROM dbo.bettrans b WITH (NOLOCK)
			WHERE mrecommend = @CustId
				AND srecommend = @srecommend
				AND b.ruben = 1
				AND b.winlostdate >= @yesterday
			GROUP BY winlostdate, bettype
		)
		INSERT INTO #WinLoss (todayWinloss, yesterdayWinloss)
		SELECT
			SUM(CASE WHEN winlostdate > @yesterday THEN mwinlost+acomm-comm ELSE 0 END),
			SUM(CASE WHEN winlostdate = @yesterday THEN mwinlost+acomm-comm ELSE 0 END)
		FROM BettransCTE b WITH (NOLOCK)
		WHERE EXISTS (SELECT TOP 1 1 FROM #SportBettype s WHERE s.Bettype = b.bettype)
			
    END
    ELSE IF @roleid = 4
    BEGIN
	  
		-- bettransRNG
		INSERT INTO #WinLoss (todayWinloss, yesterdayWinloss)
		SELECT 
			SUM(CASE WHEN winlostdate > @yesterday THEN swinlost+scomm-acomm ELSE 0 END),
			SUM(CASE WHEN winlostdate = @yesterday THEN swinlost+scomm-acomm ELSE 0 END)
	    FROM dbo.bettransRNG WITH (NOLOCK)
		WHERE srecommend = @custid
			AND winlostdate >= @yesterday
			AND statusID NOT IN (0, 1)

		-- bettransLC
		INSERT INTO #WinLoss (todayWinloss, yesterdayWinloss)
		SELECT 
			SUM(CASE WHEN winlostdate > @yesterday THEN swinlost+scomm-acomm ELSE 0 END),
			SUM(CASE WHEN winlostdate = @yesterday THEN swinlost+scomm-acomm ELSE 0 END)
	    FROM dbo.bettransLC WITH (NOLOCK)
		WHERE srecommend = @custid
			AND winlostdate >= @yesterday
			AND statusID NOT IN (0, 1)

		-- bettrans
		;WITH BettransCTE AS (
			SELECT	winlostdate, bettype,
					SUM(swinlost) AS swinlost,
					SUM(scomm) AS scomm,
					SUM(acomm) AS acomm
			FROM dbo.bettrans  b WITH (NOLOCK)
			WHERE srecommend = @CustId
				AND b.ruben = 1
				AND b.winlostdate >= @yesterday
			GROUP BY winlostdate, bettype
		)
		INSERT INTO #WinLoss (todayWinloss, yesterdayWinloss)
		SELECT 
			SUM(CASE WHEN winlostdate > @yesterday THEN swinlost+scomm-acomm ELSE 0 END),
			SUM(CASE WHEN winlostdate = @yesterday THEN swinlost+scomm-acomm ELSE 0 END)
		FROM BettransCTE b WITH (NOLOCK)
		WHERE EXISTS (SELECT TOP 1 1 FROM #SportBettype s WHERE s.Bettype = b.bettype)
		
    END

	SELECT
		SUM(todayWinloss)		AS todayWinloss,
		SUM(yesterdayWinloss)	AS yesterdayWinloss
	FROM #WinLoss
	
	DROP TABLE #SportBettype 
	DROP TABLE #WinLoss
END
GO