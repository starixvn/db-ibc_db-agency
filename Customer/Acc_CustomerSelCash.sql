/*<info serverAlias="DBAGE-bodb02" executers="bodbDownlineNet,bodbDownlineNetView" isFunction="0" isNested="1"></info>*/
AlTER PROCEDURE [dbo].[Acc_CustomerSelCash]
	@CustId INT,
	@MoveBetDay SMALLDATETIME = NULL
AS

/*
	Created by Percy
	Date: 2017-10-20
	DB: DBAGE.bodb02
	Task: Core SP - Get Cash by CustId

	Revisions:
		- 20171020@Percy: Create new [RedmineID: #84690]
		- 20170108@Sophia: Enhance SP due to high CPU (workaround)[Redmine: #88837]
		- 20180416@Sophia: Enhance performance high CPU for WC2018 [Redmine: #93100]
		- 20181003@Patrick: Index revolution [RedmineID: #101405]
		- 20200602@Percy: Separate PendingTransfer3rd from Cash and Balance [RedmineID: #135200]
		- 20210505@Sol: NAP - Alpha - Allow more time for transfer - [Redmine: #149927]
		- 20211111@Evan: Split transfer tickets out of bettrans - [Redmine: #164196]
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
	WHERE RefTable NOT IN (0, 3) -- exclude bettrans, translog
	
	DECLARE @roleID TINYINT, @__custId INT
	SET @__custId = @custID

	SELECT @roleID = roleid FROM dbo.custInfo WITH (NOLOCK) WHERE custid = @__custId

	-- get move bet date
	DECLARE @balanceUpDay SMALLDATETIME, @moveBetsDay SMALLDATETIME
	DECLARE @tblMoveBetBalanceUp AS TABLE (BalanceUpDay SMALLDATETIME, MoveBetsDay SMALLDATETIME)

	IF (@MoveBetDay IS NULL)
	BEGIN
		INSERT INTO @tblMoveBetBalanceUp(BalanceUpDay,MoveBetsDay)
		EXEC bodb02.dbo.Age_SelBalanceUpDay

		SELECT @balanceUpDay = BalanceUpDay, @moveBetsDay = MoveBetsDay FROM @tblMoveBetBalanceUp
	END
	ELSE
	BEGIN
		SELECT @moveBetsDay = @MoveBetDay
	END
	
	-- Get Balance Information --
	CREATE TABLE #BalanceInfo
	(
		superCash	MONEY DEFAULT ((0)), yesterdaySuperCash		MONEY DEFAULT ((0)),
		masterCash	MONEY DEFAULT ((0)), yesterdayMasterCash	MONEY DEFAULT ((0)),
		agentCash	MONEY DEFAULT ((0)), yesterdayAgentCash		MONEY DEFAULT ((0)),
		memberCash	MONEY DEFAULT ((0)), yesterdayMemberCash	MONEY DEFAULT ((0)),
		PendingTransfer3rd MONEY DEFAULT ((0))
	)

    IF @roleid = 1
	BEGIN
		-- bettransRNG
		INSERT INTO #BalanceInfo (memberCash, yesterdayMemberCash)
		SELECT 
			SUM(winlost-actual_stake+playercomm),
			SUM(CASE WHEN winlostdate = @yesterday THEN winlost-actual_stake+playercomm ELSE 0 END)
	    FROM dbo.bettransRNG WITH (NOLOCK)
		WHERE custid = @__custId
			AND winlostdate >= @yesterday
			AND statusID IN (111, 112, 113)

		-- bettransLC
		INSERT INTO #BalanceInfo (memberCash, yesterdayMemberCash)
		SELECT 
			SUM(winlost-actual_stake+playercomm),
			SUM(CASE WHEN winlostdate = @yesterday THEN winlost-actual_stake+playercomm ELSE 0 END)
	    FROM dbo.bettransLC WITH (NOLOCK)
		WHERE custid = @__custId
			AND winlostdate >= @yesterday
			AND statusID IN (111, 112, 113)

		-- bettrans
		INSERT INTO #BalanceInfo (memberCash, yesterdayMemberCash)
		SELECT
			SUM( winlost-actual_stake+playercomm),
			SUM( CASE WHEN (winlostdate <= @yesterday) THEN winlost-actual_stake+playercomm ELSE 0 END) 
		FROM dbo.bettrans b WITH (NOLOCK)
		WHERE b.custid = @__custId
			AND b.bettype < 19999
			AND b.statusID IN (111, 112, 113)
			AND (
				b.winlostdate < @yesterday
				OR NOT EXISTS (SELECT 1 FROM #SportBettype s WHERE s.Bettype = b.bettype)
			)
			AND b.winlostdate > @moveBetsDay

		-- Transfer
		INSERT INTO #BalanceInfo (memberCash, yesterdayMemberCash, PendingTransfer3rd)
		SELECT
			SUM(CASE WHEN b.bettype IN (21008, 21009) THEN 0 ELSE winlost-actual_stake+playercomm END),
			SUM(CASE WHEN b.bettype IN (21008, 21009) THEN 0 ELSE winlost-actual_stake+playercomm END),
			SUM(CASE WHEN b.bettype IN (21008, 21009) THEN -(winlost-actual_stake) ELSE 0 END)
		FROM dbo.Transfer b WITH (NOLOCK)
		WHERE b.custid = @__custId
			AND ((bettype = 19999 and winlostdate <= @moveBetsDay) OR bettype > 19999)
    END
    ELSE IF @roleid = 2
    BEGIN
		-- bettransRNG
		INSERT INTO #BalanceInfo (agentCash, yesterdayAgentCash, memberCash, yesterdayMemberCash)
		SELECT 
			SUM(awinlost+comm-playercomm),
			SUM(CASE WHEN winlostdate = @yesterday THEN awinlost+comm-playercomm ELSE 0 END),
			SUM(winlost-actual_stake+playercomm),
			SUM(CASE WHEN winlostdate = @yesterday THEN winlost-actual_stake+playercomm ELSE 0 END)
	    FROM dbo.bettransRNG WITH (NOLOCK)
		WHERE recommend = @__custId
			AND winlostdate >= @yesterday
			AND statusID IN (111, 112, 113)

		-- bettransLC
		INSERT INTO #BalanceInfo (agentCash, yesterdayAgentCash, memberCash, yesterdayMemberCash)
		SELECT 
			SUM(awinlost+comm-playercomm),
			SUM(CASE WHEN winlostdate = @yesterday THEN awinlost+comm-playercomm ELSE 0 END),
			SUM(winlost-actual_stake+playercomm),
			SUM(CASE WHEN winlostdate = @yesterday THEN winlost-actual_stake+playercomm ELSE 0 END)
	    FROM dbo.bettransLC WITH (NOLOCK)
		WHERE recommend = @__custId
			AND winlostdate >= @yesterday
			AND statusID IN (111, 112, 113)
		
		-- bettrans   
		;WITH Bettrans_CTE AS (
		SELECT  Winlostdate, Bettype,
				SUM(awinlost+comm-playercomm) agentCash,  
				SUM(CASE WHEN winlostdate <= @yesterday THEN awinlost+comm-playercomm ELSE 0 END ) yesterdayAgentCash,  
				SUM(winlost-actual_stake+playercomm) memberCash,  
				SUM(CASE WHEN winlostdate <= @yesterday THEN winlost-actual_stake+playercomm ELSE 0 END ) yesterdayMemberCash			
		FROM dbo.bettrans b WITH (NOLOCK)      
		WHERE b.recommend = @__custId 
			AND b.bettype < 19999  
			AND b.statusID IN (111, 112, 113)  
			AND b.winlostdate > @moveBetsDay   
		GROUP BY Winlostdate, Bettype
		)
		INSERT INTO #BalanceInfo (agentCash, yesterdayAgentCash, memberCash, yesterdayMemberCash)  
			SELECT  SUM(agentCash) AS agentCash,
					SUM(yesterdayAgentCash) AS yesterdayAgentCash,
					SUM(memberCash) AS memberCash,
					SUM(yesterdayMemberCash) AS yesterdayMemberCash
			FROM Bettrans_CTE b
			WHERE b.winlostdate < @yesterday  
				OR NOT EXISTS (SELECT TOP 1 1 FROM #SportBettype s WHERE s.Bettype = b.bettype)  
				
		-- Transfer 
		INSERT INTO #BalanceInfo (agentCash, yesterdayAgentCash, memberCash, yesterdayMemberCash, PendingTransfer3rd)
		SELECT
			SUM(CASE WHEN b.bettype IN (21008, 21009) THEN 0 ELSE CASE WHEN b.custid = b.recommend THEN winlost-actual_stake ELSE awinlost+comm-playercomm END END) AS agentCash,
			SUM(CASE WHEN b.bettype IN (21008, 21009) THEN 0 ELSE CASE WHEN b.custid = b.recommend THEN winlost-actual_stake ELSE awinlost+comm-playercomm END END) AS yesterdayAgentCash,
			SUM(CASE WHEN b.bettype IN (21008, 21009) THEN 0 ELSE CASE WHEN b.custid <> b.recommend THEN winlost-actual_stake+playercomm ELSE 0 END END) AS memberCash,
			SUM(CASE WHEN b.bettype IN (21008, 21009) THEN 0 ELSE CASE WHEN b.custid <> b.recommend THEN winlost-actual_stake+playercomm ELSE 0 END END) AS yesterdayMemberCash,
			SUM(CASE WHEN b.bettype IN (21008, 21009) THEN -(winlost-actual_stake) ELSE 0 END) AS PendingTransfer3rd
		FROM dbo.Transfer b WITH (NOLOCK)    
		WHERE b.recommend = @__custId
			AND ((bettype = 19999 and winlostdate <= @moveBetsDay) OR bettype > 19999 )
    END
    ELSE IF @roleid = 3
    BEGIN
		-- bettransRNG
		INSERT INTO #BalanceInfo (masterCash, yesterdayMasterCash, agentCash, yesterdayAgentCash, memberCash, yesterdayMemberCash)
		SELECT 
			SUM(mwinlost+acomm-comm),
			SUM(CASE WHEN winlostdate = @yesterday THEN mwinlost+acomm-comm ELSE 0 END),
			SUM(awinlost+comm-playercomm),
			SUM(CASE WHEN winlostdate = @yesterday THEN awinlost+comm-playercomm ELSE 0 END),
			SUM(winlost-actual_stake+playercomm),
			SUM(CASE WHEN winlostdate = @yesterday THEN winlost-actual_stake+playercomm ELSE 0 END)
	    FROM dbo.bettransRNG WITH (NOLOCK)
		WHERE mrecommend = @__custId
			AND winlostdate >= @yesterday
			AND statusID IN (111, 112, 113)

		-- bettransLC
		INSERT INTO #BalanceInfo (masterCash, yesterdayMasterCash, agentCash, yesterdayAgentCash, memberCash, yesterdayMemberCash)
		SELECT 
			SUM(mwinlost+acomm-comm),
			SUM(CASE WHEN winlostdate = @yesterday THEN mwinlost+acomm-comm ELSE 0 END),
			SUM(awinlost+comm-playercomm),
			SUM(CASE WHEN winlostdate = @yesterday THEN awinlost+comm-playercomm ELSE 0 END),
			SUM(winlost-actual_stake+playercomm),
			SUM(CASE WHEN winlostdate = @yesterday THEN winlost-actual_stake+playercomm ELSE 0 END)
	    FROM dbo.bettransLC WITH (NOLOCK)
		WHERE mrecommend = @__custId
			AND winlostdate >= @yesterday
			AND statusID IN (111, 112, 113)

		-- bettrans 
		;WITH Bettrans_CTE AS (
		SELECT  Winlostdate, Bettype,
				SUM(mwinlost+acomm-comm) masterCash,  
				SUM(CASE WHEN winlostdate <= @yesterday THEN mwinlost+acomm-comm ELSE 0 END) yesterdayMasterCash,  
				SUM( awinlost+comm-playercomm) agentCash,  
				SUM(CASE WHEN winlostdate <= @yesterday THEN awinlost+comm-playercomm ELSE 0 END) yesterdayAgentCash,  
				SUM(winlost-actual_stake+playercomm) memberCash,  
				SUM(CASE WHEN winlostdate <= @yesterday THEN winlost-actual_stake+playercomm ELSE 0 END) yesterdayMemberCash
		FROM dbo.bettrans b WITH (NOLOCK)  
		WHERE b.mrecommend = @__custId  
			AND b.bettype < 19999
			AND b.winlostdate > @moveBetsDay  
			AND b.statusID IN (111, 112, 113) 
		GROUP BY Winlostdate, Bettype
		)
		INSERT INTO #BalanceInfo (masterCash, yesterdayMasterCash, agentCash, yesterdayAgentCash, memberCash, yesterdayMemberCash)
			SELECT
				SUM(masterCash),
				SUM(yesterdayMasterCash),
				SUM(agentCash),
				SUM(yesterdayAgentCash),
				SUM(memberCash),
				SUM(yesterdayMemberCash)
			FROM Bettrans_CTE b
			WHERE b.winlostdate < @yesterday  
				OR NOT EXISTS (SELECT 1 FROM #SportBettype s WHERE s.Bettype = b.bettype)  
			
		-- Transfer 
		INSERT INTO #BalanceInfo (masterCash, yesterdayMasterCash, agentCash, yesterdayAgentCash, memberCash, yesterdayMemberCash, PendingTransfer3rd)
		SELECT
			SUM(CASE WHEN b.bettype IN (21008, 21009) THEN 0 ELSE CASE WHEN b.CustID = b.mrecommend THEN winlost-actual_stake ELSE mwinlost+acomm-comm END END) AS masterCash,
			SUM(CASE WHEN b.bettype IN (21008, 21009) THEN 0 ELSE CASE WHEN b.CustID = b.mrecommend THEN winlost-actual_stake ELSE mwinlost+acomm-comm END END) AS yesterdayMasterCash,
			
			SUM(CASE WHEN b.bettype IN (21008, 21009) THEN 0 ELSE CASE WHEN b.custid = b.recommend THEN winlost-actual_stake ELSE awinlost+comm-playercomm END END) AS agentCash,		
			SUM(CASE WHEN b.bettype IN (21008, 21009) THEN 0 ELSE CASE WHEN b.custid = b.recommend THEN winlost-actual_stake ELSE awinlost+comm-playercomm END END) AS yesterdayAgentCash,
			
			SUM(CASE WHEN b.bettype IN (21008, 21009) THEN 0 ELSE CASE WHEN b.custid <> b.recommend AND b.custid <> b.mrecommend THEN winlost-actual_stake+playercomm ELSE 0 END END) AS memberCash,
			SUM(CASE WHEN b.bettype IN (21008, 21009) THEN 0 ELSE CASE WHEN b.custid <> b.recommend AND b.custid <> b.mrecommend THEN winlost-actual_stake+playercomm ELSE 0 END END) AS yesterdayMemberCash,
			SUM(CASE WHEN b.bettype IN (21008, 21009) THEN -(winlost-actual_stake) ELSE 0 END) AS PendingTransfer3rd
		FROM dbo.Transfer b WITH (NOLOCK)
		WHERE b.mrecommend = @__custId  
			AND (
					(bettype = 19999 and winlostdate <= @moveBetsDay) OR bettype > 19999 			
				)
    END
    ELSE IF @roleid = 4
    BEGIN
		-- bettransRNG
		INSERT INTO #BalanceInfo (superCash, yesterdaySuperCash, masterCash, yesterdayMasterCash, agentCash, yesterdayAgentCash, memberCash, yesterdayMemberCash)
		SELECT 
			SUM(swinlost+scomm-acomm),
			SUM(CASE WHEN winlostdate = @yesterday THEN swinlost+scomm-acomm ELSE 0 END),
			SUM(mwinlost+acomm-comm),
			SUM(CASE WHEN winlostdate = @yesterday THEN mwinlost+acomm-comm ELSE 0 END),
			SUM(awinlost+comm-playercomm),
			SUM(CASE WHEN winlostdate = @yesterday THEN awinlost+comm-playercomm ELSE 0 END),
			SUM(winlost-actual_stake+playercomm),
			SUM(CASE WHEN winlostdate = @yesterday THEN winlost-actual_stake+playercomm ELSE 0 END)
	    FROM dbo.bettransRNG WITH (NOLOCK)
		WHERE srecommend = @__custId
			AND winlostdate >= @yesterday
			AND statusID IN (111, 112, 113) 

		-- bettransLC
		INSERT INTO #BalanceInfo (superCash, yesterdaySuperCash, masterCash, yesterdayMasterCash, agentCash, yesterdayAgentCash, memberCash, yesterdayMemberCash)
		SELECT 
			SUM(swinlost+scomm-acomm),
			SUM(CASE WHEN winlostdate = @yesterday THEN swinlost+scomm-acomm ELSE 0 END),
			SUM(mwinlost+acomm-comm),
			SUM(CASE WHEN winlostdate = @yesterday THEN mwinlost+acomm-comm ELSE 0 END),
			SUM(awinlost+comm-playercomm),
			SUM(CASE WHEN winlostdate = @yesterday THEN awinlost+comm-playercomm ELSE 0 END),
			SUM(winlost-actual_stake+playercomm),
			SUM(CASE WHEN winlostdate = @yesterday THEN winlost-actual_stake+playercomm ELSE 0 END)
	    FROM dbo.bettransLC WITH (NOLOCK)
		WHERE srecommend = @__custId
			AND winlostdate >= @yesterday
			AND statusID IN (111, 112, 113)

		-- bettrans  
		;WITH Bettrans_CTE as (
		  	SELECT  winlostdate, Bettype,
				   SUM(swinlost+scomm-acomm) superCash,  
				   SUM(CASE WHEN winlostdate <= @yesterday THEN swinlost+scomm-acomm ELSE 0 END) yesterdaySuperCash,  
				   SUM(mwinlost+acomm-comm) masterCash,  
				   SUM(CASE WHEN winlostdate <= @yesterday THEN mwinlost+acomm-comm ELSE 0 END) yesterdayMasterCash,  				   
				   SUM(awinlost+comm-playercomm) agentCash,  
				   SUM(CASE WHEN winlostdate <= @yesterday THEN awinlost+comm-playercomm ELSE 0 END) yesterdayAgentCash,  				   
				   SUM(winlost-actual_stake+playercomm) memberCash,  
				   SUM(CASE WHEN winlostdate <= @yesterday THEN winlost-actual_stake+playercomm ELSE 0 END) yesterdayMemberCash
			FROM dbo.bettrans b WITH (NOLOCK)
			WHERE b.srecommend = @__custId  
				AND b.bettype < 19999
				AND b.winlostdate > @moveBetsDay  
				AND b.statusID IN (111, 112, 113)  
			Group by bettype,b.winlostdate
		)
	  	INSERT INTO #BalanceInfo (superCash, yesterdaySuperCash, masterCash, yesterdayMasterCash, agentCash, yesterdayAgentCash, memberCash, yesterdayMemberCash)  
			SELECT
				SUM(superCash),
				SUM(yesterdaySuperCash),
				SUM(masterCash),
				SUM(yesterdayMasterCash),
				SUM(agentCash),
				SUM(yesterdayAgentCash),
				SUM(memberCash),
				SUM(yesterdayMemberCash)
			FROM Bettrans_CTE b
			WHERE  b.winlostdate < @yesterday  
				OR NOT EXISTS (SELECT 1 FROM #SportBettype s WHERE s.Bettype = b.bettype)

		-- Transfer 
		INSERT INTO #BalanceInfo (superCash, yesterdaySuperCash, masterCash, yesterdayMasterCash, agentCash, yesterdayAgentCash, memberCash, yesterdayMemberCash, PendingTransfer3rd)
		SELECT  SUM(CASE WHEN b.bettype IN (21008, 21009) THEN 0 ELSE CASE WHEN custid = srecommend THEN winlost-actual_stake ELSE swinlost+scomm-acomm END END) superCash,
			    SUM(CASE WHEN b.bettype IN (21008, 21009) THEN 0 ELSE CASE WHEN custid = srecommend THEN winlost-actual_stake ELSE swinlost+scomm-acomm END END) yesterdaySuperCash,
				
			    SUM(CASE WHEN b.bettype IN (21008, 21009) THEN 0 ELSE CASE WHEN custid = mrecommend THEN winlost-actual_stake ELSE mwinlost+acomm-comm END END) masterCash,
			    SUM(CASE WHEN b.bettype IN (21008, 21009) THEN 0 ELSE CASE WHEN custid = mrecommend THEN winlost-actual_stake ELSE mwinlost+acomm-comm END END) yesterdayMasterCash,
				
				SUM(CASE WHEN b.bettype IN (21008, 21009) THEN 0 ELSE CASE WHEN custid = recommend THEN winlost-actual_stake ELSE awinlost+comm-playercomm END END) agentCash,
				SUM(CASE WHEN b.bettype IN (21008, 21009) THEN 0 ELSE CASE WHEN custid = recommend THEN winlost-actual_stake ELSE awinlost+comm-playercomm END END ) yesterdayAgentCash,
				
				SUM(CASE WHEN b.bettype IN (21008, 21009) THEN 0 ELSE CASE WHEN custid <> recommend AND custid <> mrecommend AND custid <> srecommend THEN winlost-actual_stake+playercomm ELSE 0 END END ) memberCash,
				SUM(CASE WHEN b.bettype IN (21008, 21009) THEN 0 ELSE CASE WHEN custid <> recommend AND custid <> mrecommend AND custid <> srecommend THEN winlost-actual_stake+playercomm ELSE 0 END END ) yesterdayMemberCash,
				
				SUM(CASE WHEN b.bettype IN (21008, 21009) THEN -(winlost-actual_stake) ELSE 0 END) AS PendingTransfer3rd
			FROM dbo.Transfer b WITH (NOLOCK)
			WHERE b.srecommend = @__custId 
				AND (
						(bettype = 19999 and winlostdate <= @moveBetsDay) OR bettype > 19999					 
					)
    END

	SELECT
		SUM(superCash)				AS superCash,
		SUM(yesterdaySuperCash)		AS yesterdaySuperCash,
		SUM(masterCash)				AS masterCash,
		SUM(yesterdayMasterCash)	AS yesterdayMasterCash,
		SUM(agentCash)				AS agentCash,
		SUM(yesterdayAgentCash)		AS yesterdayAgentCash,
		SUM(memberCash)				AS memberCash,
		SUM(yesterdayMemberCash)	AS yesterdayMemberCash,
		SUM(PendingTransfer3rd)		AS PendingTransfer3rd
	FROM #BalanceInfo
	
	DROP TABLE #SportBettype
	DROP TABLE #BalanceInfo
	
END
GO