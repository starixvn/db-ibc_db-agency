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
		20181003@Patrick: Index revolution [RedmineID: #101405]
		20181105@Paul: Enhance perf [RedmineID: #103443]
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @yesterday SMALLDATETIME
	SELECT  @yesterday = CONVERT(DATE, DATEADD(DAY, -1, GETDATE()))

	-- Get bettype --
	DECLARE @isTest BIT = 0
	SELECT  @isTest = dbo.f_CheckSPVersion(@@PROCID)
		
	DECLARE @roleID TINYINT,			
			@__custId INT

	SET @__custId = @CustId

	SELECT  @roleID = roleid FROM dbo.custInfo WITH (NOLOCK) WHERE custid = @__custId
	
    IF @roleid = 1
	BEGIN
		SELECT todayWinloss = SUM(CASE WHEN winlostdate > @yesterday THEN memberWL ELSE 0 END)
				,yesterdayWinloss = SUM(CASE WHEN winlostdate = @yesterday THEN memberWL ELSE 0 END)	
		FROM (
			-- bettransRNG
			SELECT winlostdate, winlost-actual_stake+playercomm as memberWL
			FROM dbo.bettransRNG WITH(NOLOCK, INDEX=IX_custid)
			WHERE custid = @__custId
				AND winlostdate >= @yesterday
				AND statusID NOT IN (0, 1)

			UNION ALL -- bettransLC
			SELECT winlostdate, winlost-actual_stake+playercomm as memberWL
			FROM dbo.bettransLC WITH (NOLOCK, INDEX=IX_custid)
			WHERE custid = @__custId
				AND winlostdate >= @yesterday
				AND statusID NOT IN (0, 1)

			UNION ALL --bettrans
			SELECT winlostdate, winlost-actual_stake+playercomm as memberWL
			FROM dbo.bettrans b WITH (NOLOCK, INDEX=IX_custid)		
			WHERE custid = @__custId
				AND b.statusID NOT IN (0, 1)
				AND b.winlostdate >= @yesterday
				AND bettype IN (SELECT bettype FROM dbo.SportBettypeMatrix WITH(NOLOCK) WHERE RefTable IN (0,3) AND IsTest <= @isTest)
		) x
    END
    ELSE IF @roleid = 2
    BEGIN
		SELECT todayWinloss = SUM(CASE WHEN winlostdate > @yesterday THEN agentWL ELSE 0 END)
				,yesterdayWinloss = SUM(CASE WHEN winlostdate = @yesterday THEN agentWL ELSE 0 END)	
		FROM (
			-- bettransRNG
			SELECT winlostdate, awinlost+comm-playercomm as agentWL
			FROM dbo.bettransRNG WITH (NOLOCK, INDEX=IX_recommend)
			WHERE recommend = @__custId
				AND winlostdate >= @yesterday
				AND statusID NOT IN (0, 1)

			UNION ALL -- bettransLC
			SELECT winlostdate, awinlost+comm-playercomm as agentWL
			FROM dbo.bettransLC WITH (NOLOCK, INDEX=IX_recommend)
			WHERE recommend = @__custId
				AND winlostdate >= @yesterday
				AND statusID NOT IN (0, 1)

			UNION ALL --bettrans
			SELECT winlostdate, awinlost+comm-playercomm as agentWL
			FROM dbo.bettrans b WITH (NOLOCK, INDEX=IX_recommend)		
			WHERE recommend = @__custId
				AND b.statusID NOT IN (0, 1)
				AND b.winlostdate >= @yesterday
				AND bettype IN (SELECT bettype FROM dbo.SportBettypeMatrix WITH(NOLOCK) WHERE RefTable IN (0,3) AND IsTest <= @isTest)
		) x		
    END
    ELSE IF @roleid = 3
    BEGIN 
		SELECT todayWinloss = SUM(CASE WHEN winlostdate > @yesterday THEN masterWL ELSE 0 END)
				,yesterdayWinloss = SUM(CASE WHEN winlostdate = @yesterday THEN masterWL ELSE 0 END)	
		FROM (
			-- bettransRNG
			SELECT winlostdate, mwinlost+acomm-comm as masterWL
			FROM dbo.bettransRNG WITH (NOLOCK, INDEX=IX_mrecommend)
			WHERE mrecommend = @__custId
				AND winlostdate >= @yesterday
				AND statusID NOT IN (0, 1)

			UNION ALL -- bettransLC
			SELECT winlostdate, mwinlost+acomm-comm as masterWL
			FROM dbo.bettransLC WITH (NOLOCK, INDEX=IX_mrecommend)
			WHERE mrecommend = @__custId
				AND winlostdate >= @yesterday
				AND statusID NOT IN (0, 1)

			UNION ALL --bettrans
			SELECT winlostdate, mwinlost+acomm-comm as masterWL
			FROM dbo.bettrans b WITH (NOLOCK, INDEX=IX_mrecommend)		
			WHERE mrecommend = @__custId
				AND b.statusID NOT IN (0, 1)
				AND b.winlostdate >= @yesterday
				AND bettype IN (SELECT bettype FROM dbo.SportBettypeMatrix WITH(NOLOCK) WHERE RefTable IN (0,3) AND IsTest <= @isTest)
		) x
			
    END
    ELSE IF @roleid = 4  
    BEGIN
	  SELECT todayWinloss = SUM(CASE WHEN winlostdate > @yesterday THEN superWL ELSE 0 END)
				,yesterdayWinloss = SUM(CASE WHEN winlostdate = @yesterday THEN superWL ELSE 0 END)	
		FROM (
			-- bettransRNG
			SELECT winlostdate, swinlost+scomm-acomm as superWL
			FROM dbo.bettransRNG WITH (NOLOCK, INDEX=IX_srecommend)
			WHERE srecommend = @__custId
				AND winlostdate >= @yesterday
				AND statusID NOT IN (0, 1) 

			UNION ALL -- bettransLC
			SELECT winlostdate, swinlost+scomm-acomm as superWL
			FROM dbo.bettransLC WITH (NOLOCK, INDEX=IX_srecommend)
			WHERE srecommend = @__custId
				AND winlostdate >= @yesterday
				AND statusID NOT IN (0, 1)

			UNION ALL --bettrans
			SELECT winlostdate, swinlost+scomm-acomm as superWL
			FROM dbo.bettrans b WITH (NOLOCK, INDEX=IX_srecommend)		
			WHERE srecommend = @__custId
				AND b.statusID NOT IN (0, 1)
				AND b.winlostdate >= @yesterday
				AND bettype IN (SELECT bettype FROM dbo.SportBettypeMatrix WITH(NOLOCK) WHERE RefTable IN (0,3) AND IsTest <= @isTest)
		) x

    END
END
GO