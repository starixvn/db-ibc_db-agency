/*<info serverAlias="DBAGE-bodb02" executers="bodbDownlineNet,bodbDownlineNetView" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [Age_Transfer_CashBalance_Sel]
	@CustID INT
AS

/*
	Created by: Percy
	Task: Get Cash Balance Info of @CustID and Upline
	DB: DBAGE.bodb02
	
	Revisions:
		- 20170609@Percy: Create new [RedmineID: #74291]
		- 20181005@Percy: Revise indexes [RedmineID: #101644]
		- 20200602@Percy: Separate PendingTransfer3rd from Cash and Balance [RedmineID: #135200]

	Param's Explanation:
		- @CustID: custid of Master/Agent/Member
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @yesterday SMALLDATETIME
	SELECT  @yesterday = CONVERT(DATE, DATEADD(DAY, -1, GETDATE()))

	-- Get bettype --
	DECLARE @isTest BIT = 0
	SELECT  @isTest = dbo.f_CheckSPVersion(@@PROCID)
	
	CREATE TABLE #SportBettype (bettype INT, RefTable TINYINT)
	INSERT INTO #SportBettype (bettype, RefTable)
	SELECT bettype, RefTable FROM dbo.f_SportBettypeMatrix_Sel (0, 0, 0, 2, '', '', @isTest)

	DECLARE @uplineId INT, @roleID TINYINT, @GivenCredit MONEY, @username NVARCHAR(50)

	SELECT
		@roleID = roleid,
		@uplineId = CASE roleid WHEN 1 THEN recommend WHEN 2 THEN mrecommend WHEN 3 THEN srecommend END,
		@GivenCredit = ISNULL(Credit, 0), -- must get real-time
		@username = username
	FROM DBCUST.CustDB.dbo.custInfo WITH(NOLOCK) WHERE custid = @custID
	
	IF ISNULL(@roleID, 0) NOT BETWEEN 1 AND 3 -- Master/Agent/Member only
	BEGIN
		RETURN
	END

	-- Get Balance Information --
	CREATE TABLE #BalanceInfo
	(
		superCash MONEY,
		masterCash MONEY, masterOutstanding MONEY,
		agentCash MONEY, agentOutstanding MONEY,
		memberCash MONEY, memberOutstanding MONEY,
		PendingTransfer3rd MONEY
	)

	/*
		=========================================Balance Info====================================================
							
						|	bettransRnG	|	bettransLC	|	translog	|	bettrans
		---------------------------------------------------------------------------------------------------------
		running tickets	|	get all		|	get all		|	get all		| exclude tickets from bettransRnG, bettransLC, translog
						|				|				|				| 
		-------------------------------------------------------------------------------------------------------
		settle tickets	|	yesterday	|	yesterday	|	don't get	| . < yesterday: get all
						|	today		|	today		|				| . >= yesterday: exclude tickets from bettransRnG, bettransLC
		---------------------------------------------------------------------------------------------------------
		---------------------------------------------------------------------------------------------------------
		RefTable Info	|	1			|	2			|	3			|	0
		=========================================================================================================
	*/
    
	IF @roleid = 1
    BEGIN
		-- bettransRNG
		INSERT INTO #BalanceInfo (agentCash, memberCash, memberOutstanding)
		SELECT 
			SUM(CASE WHEN statusID NOT IN (0,1) THEN awinlost+comm-playercomm ELSE 0 END),
			SUM(CASE WHEN statusID NOT IN (0,1) AND custid = @custid THEN winlost-actual_stake+playercomm ELSE 0 END),
			SUM(CASE WHEN statusID IN (0,1) AND custid = @custid THEN ABS(actual_stake) ELSE 0 END)
	    FROM dbo.bettransRNG WITH(NOLOCK)
		WHERE recommend = @uplineId
			AND (
				statusID IN (0,1)
				OR winlostdate >= @yesterday
			)

		-- bettransLC
		INSERT INTO #BalanceInfo (agentCash, memberCash, memberOutstanding)
		SELECT 
			SUM(CASE WHEN statusID NOT IN (0,1) THEN awinlost+comm-playercomm ELSE 0 END),
			SUM(CASE WHEN statusID NOT IN (0,1) AND custid = @custid THEN winlost-actual_stake+playercomm ELSE 0 END),
			SUM(CASE WHEN statusID IN (0,1) AND custid = @custid THEN ABS(actual_stake) ELSE 0 END)
	    FROM dbo.bettransLC WITH(NOLOCK)
		WHERE recommend = @uplineId
			AND (
				statusID IN (0,1)
				OR winlostdate >= @yesterday
			)

		-- translog
		INSERT INTO #BalanceInfo (agentCash, memberCash, memberOutstanding)
		SELECT 0, 0, SUM(ABS(actual_stake))
	    FROM dbo.translog WITH(NOLOCK)
		WHERE custid = @custid
			AND statusID IN (0,1)

		-- bettrans
			-- running tickets
		INSERT INTO #BalanceInfo (agentCash, memberCash, memberOutstanding)
		SELECT 0, 0, SUM(ABS(actual_stake))
		FROM dbo.bettrans b WITH(NOLOCK)
		WHERE b.custid = @custid
			AND b.ruben = 0
			AND NOT EXISTS (SELECT TOP 1 1 FROM #SportBettype s WHERE s.Bettype = b.bettype AND s.RefTable <> 0)
			
			-- settle tickets
				-- < yesterday
		INSERT INTO #BalanceInfo (agentCash, memberCash, memberOutstanding, PendingTransfer3rd)
		SELECT
			SUM(CASE WHEN bettype IN (21008, 21009) THEN 0 ELSE CASE WHEN custid = @uplineId THEN winlost-actual_stake ELSE awinlost+comm-playercomm END END),
			SUM(CASE WHEN bettype IN (21008, 21009) THEN 0 ELSE CASE WHEN custid = @custid THEN winlost-actual_stake+playercomm ELSE 0 END END),
			0,
			SUM(CASE WHEN bettype IN (21008, 21009) AND custid = @custid THEN -(winlost-actual_stake) ELSE 0 END)
		FROM dbo.bettrans b WITH(NOLOCK)
		WHERE b.recommend = @uplineId
			AND b.ruben = 1
			AND b.winlostdate < @yesterday
				
				-- >= yesterday
		INSERT INTO #BalanceInfo (agentCash, memberCash, memberOutstanding, PendingTransfer3rd)
		SELECT
			SUM(CASE WHEN bettype IN (21008, 21009) THEN 0 ELSE CASE WHEN custid = @uplineId THEN winlost-actual_stake ELSE awinlost+comm-playercomm END END),
			SUM(CASE WHEN bettype IN (21008, 21009) THEN 0 ELSE CASE WHEN custid = @custid THEN winlost-actual_stake+playercomm ELSE 0 END END),
			0,
			SUM(CASE WHEN bettype IN (21008, 21009) AND custid = @custid THEN -(winlost-actual_stake) ELSE 0 END)
		FROM dbo.bettrans b WITH(NOLOCK)
		WHERE b.recommend = @uplineId
			AND b.ruben = 1
			AND b.winlostdate >= @yesterday
			AND NOT EXISTS (SELECT TOP 1 1 FROM #SportBettype s WHERE s.Bettype = b.bettype AND s.RefTable IN (1, 2))

		SELECT
			@CustID AS CustId,
			@roleID AS RoleId,
			@username AS UserName,
			SUM(ISNULL(agentCash, 0)) AS uplineCashBalance,
			SUM(ISNULL(memberCash, 0)) AS CashBalance,
			SUM(ISNULL(memberOutstanding, 0)) AS Outstanding,
			SUM(ISNULL(PendingTransfer3rd, 0)) AS PendingTransfer3rd,
			@GivenCredit AS GivenCredit
		FROM #BalanceInfo
    END
    ELSE IF @roleid = 2
    BEGIN
		-- bettransRNG
		INSERT INTO #BalanceInfo (masterCash, agentCash, agentOutstanding)
		SELECT 
			SUM(CASE WHEN statusID NOT IN (0,1) THEN mwinlost+acomm-comm ELSE 0 END),
			SUM(CASE WHEN statusID NOT IN (0,1) AND recommend = @CustID THEN awinlost+comm-playercomm ELSE 0 END),
			SUM(CASE WHEN statusID IN (0,1) AND recommend = @CustID THEN ABS(actual_stake*apositiontaking) ELSE 0 END)
	    FROM dbo.bettransRNG WITH(NOLOCK)
		WHERE mrecommend = @uplineId
			AND (
				statusID IN (0,1)
				OR winlostdate >= @yesterday
			)

		-- bettransLC
		INSERT INTO #BalanceInfo (masterCash, agentCash, agentOutstanding)
		SELECT 
			SUM(CASE WHEN statusID NOT IN (0,1) THEN mwinlost+acomm-comm ELSE 0 END),
			SUM(CASE WHEN statusID NOT IN (0,1) AND recommend = @CustID THEN awinlost+comm-playercomm ELSE 0 END),
			SUM(CASE WHEN statusID IN (0,1) AND recommend = @CustID THEN ABS(actual_stake*apositiontaking) ELSE 0 END)
	    FROM dbo.bettransLC WITH(NOLOCK)
		WHERE mrecommend = @uplineId
			AND (
				statusID IN (0,1)
				OR winlostdate >= @yesterday
			)

		-- translog
		INSERT INTO #BalanceInfo (masterCash, agentCash, agentOutstanding)
		SELECT 0, 0, SUM(ABS(actual_stake*apositiontaking))
	    FROM dbo.translog t WITH(NOLOCK)
		WHERE recommend = @custid
			AND statusID IN (0,1)

		-- bettrans
			-- running tickets
		INSERT INTO #BalanceInfo (masterCash, agentCash, agentOutstanding)
		SELECT 0, 0, SUM(ABS(actual_stake*apositiontaking))
		FROM dbo.bettrans b WITH(NOLOCK)
		WHERE b.recommend = @custid
			AND b.ruben = 0
			AND NOT EXISTS (SELECT TOP 1 1 FROM #SportBettype s WHERE s.Bettype = b.bettype AND s.RefTable <> 0)

			-- settle tickets
				-- < yesterday
		INSERT INTO #BalanceInfo (masterCash, agentCash, agentOutstanding, PendingTransfer3rd)
		SELECT
			SUM(CASE WHEN bettype IN (21008, 21009) THEN 0 ELSE mwinlost+acomm-comm END),
			SUM(CASE WHEN bettype IN (21008, 21009) THEN 0 ELSE CASE WHEN recommend = @custid THEN CASE WHEN custid = recommend THEN winlost-actual_stake ELSE awinlost+comm-playercomm END ELSE 0 END END),
			0,
			SUM(CASE WHEN bettype IN (21008, 21009) AND recommend = @custid THEN -(winlost-actual_stake) ELSE 0 END)
		FROM dbo.bettrans b WITH(NOLOCK)
		WHERE b.mrecommend = @uplineId
			AND b.ruben = 1
			AND b.winlostdate < @yesterday
				
				-- >= yesterday
		INSERT INTO #BalanceInfo (masterCash, agentCash, agentOutstanding, PendingTransfer3rd)
		SELECT
			SUM(CASE WHEN bettype IN (21008, 21009) THEN 0 ELSE mwinlost+acomm-comm END),
			SUM(CASE WHEN bettype IN (21008, 21009) THEN 0 ELSE CASE WHEN recommend = @custid THEN CASE WHEN custid = recommend THEN winlost-actual_stake ELSE awinlost+comm-playercomm END ELSE 0 END END),
			0,
			SUM(CASE WHEN bettype IN (21008, 21009) AND recommend = @custid THEN -(winlost-actual_stake) ELSE 0 END)
		FROM dbo.bettrans b WITH(NOLOCK)
		WHERE b.mrecommend = @uplineId
			AND b.ruben = 1
			AND b.winlostdate >= @yesterday
			AND NOT EXISTS (SELECT TOP 1 1 FROM #SportBettype s WHERE s.Bettype = b.bettype AND s.RefTable IN (1, 2))

				-- sum, balance, transfer tickets of this master
		INSERT INTO #BalanceInfo (masterCash, agentCash, agentOutstanding, PendingTransfer3rd)
		SELECT
			SUM(CASE WHEN bettype IN (21008, 21009) THEN 0 ELSE winlost-actual_stake END),
			0,
			0,
			SUM(CASE WHEN bettype IN (21008, 21009) THEN -(winlost-actual_stake) ELSE 0 END)
		FROM dbo.bettrans b WITH(NOLOCK)
		WHERE b.custid = @uplineId
			AND b.matchid = 0
			AND b.bettype >= 19999
			AND b.ruben = 1

		SELECT
			@CustID AS CustId,
			@roleID AS RoleId,
			@username AS UserName,
			SUM(ISNULL(masterCash, 0)) AS uplineCashBalance,
			SUM(ISNULL(agentCash, 0)) AS CashBalance,
			SUM(ISNULL(agentOutstanding, 0)) AS Outstanding,
			SUM(ISNULL(PendingTransfer3rd, 0)) AS PendingTransfer3rd,
			@GivenCredit AS GivenCredit
		FROM #BalanceInfo
    END
    ELSE IF @roleid = 3
    BEGIN
		-- bettransRNG
		INSERT INTO #BalanceInfo (superCash, masterCash, masterOutstanding)
		SELECT 
			SUM(CASE WHEN statusID NOT IN (0,1) THEN swinlost+scomm-acomm ELSE 0 END),
			SUM(CASE WHEN statusID NOT IN (0,1) AND mrecommend = @CustID THEN mwinlost+acomm-comm ELSE 0 END),
			SUM(CASE WHEN statusID IN (0,1) AND mrecommend = @CustID THEN ABS(actual_stake*mpositiontaking) ELSE 0 END)
	    FROM dbo.bettransRNG WITH(NOLOCK)
		WHERE srecommend = @uplineId
			AND (
				statusID IN (0,1)
				OR winlostdate >= @yesterday
			)

		-- bettransLC
		INSERT INTO #BalanceInfo (superCash, masterCash, masterOutstanding)
		SELECT 
			SUM(CASE WHEN statusID NOT IN (0,1) THEN swinlost+scomm-acomm ELSE 0 END),
			SUM(CASE WHEN statusID NOT IN (0,1) AND mrecommend = @CustID THEN mwinlost+acomm-comm ELSE 0 END),
			SUM(CASE WHEN statusID IN (0,1) AND mrecommend = @CustID THEN ABS(actual_stake*mpositiontaking) ELSE 0 END)
	    FROM dbo.bettransLC WITH(NOLOCK)
		WHERE srecommend = @uplineId
			AND (
				statusID IN (0,1)
				OR winlostdate >= @yesterday
			)

		-- translog
		INSERT INTO #BalanceInfo (superCash, masterCash, masterOutstanding)
		SELECT 0, 0, SUM(ABS(actual_stake*mpositiontaking))
	    FROM dbo.translog WITH(NOLOCK)
		WHERE mrecommend = @CustID
			AND statusID IN (0,1)

		-- bettrans
			-- running tickets
		INSERT INTO #BalanceInfo (superCash, masterCash, masterOutstanding)
		SELECT 0, 0, SUM(ABS(actual_stake*mpositiontaking))
		FROM dbo.bettrans b WITH(NOLOCK)
		WHERE EXISTS (SELECT TOP 1 1 FROM dbo.custInfo c WITH(NOLOCK) WHERE b.recommend = c.custid AND c.mrecommend = @CustID AND c.roleid = 2)
			AND b.ruben = 0
			AND NOT EXISTS (SELECT TOP 1 1 FROM #SportBettype s WHERE s.Bettype = b.bettype AND s.RefTable <> 0)

			-- settle tickets
				-- < yesterday
		INSERT INTO #BalanceInfo (superCash, masterCash, masterOutstanding, PendingTransfer3rd)
		SELECT
			SUM(CASE WHEN bettype IN (21008, 21009) THEN 0 ELSE swinlost+scomm-acomm END),
			SUM(CASE WHEN bettype IN (21008, 21009) THEN 0 ELSE CASE WHEN mrecommend = @CustID THEN mwinlost+acomm-comm ELSE 0 END END),
			0,
			SUM(CASE WHEN bettype IN (21008, 21009) AND mrecommend = @CustID THEN -(winlost-actual_stake) ELSE 0 END)
		FROM dbo.bettrans b WITH(NOLOCK)
		WHERE b.srecommend = @uplineId
			AND b.ruben = 1
			AND b.winlostdate < @yesterday

				-- >= yesterday
		INSERT INTO #BalanceInfo (superCash, masterCash, masterOutstanding, PendingTransfer3rd)
		SELECT
			SUM(CASE WHEN bettype IN (21008, 21009) THEN 0 ELSE swinlost+scomm-acomm END),
			SUM(CASE WHEN bettype IN (21008, 21009) THEN 0 ELSE CASE WHEN mrecommend = @CustID THEN mwinlost+acomm-comm ELSE 0 END END),
			0,
			SUM(CASE WHEN bettype IN (21008, 21009) AND mrecommend = @CustID THEN -(winlost-actual_stake) ELSE 0 END)
		FROM dbo.bettrans b WITH(NOLOCK)
		WHERE b.srecommend = @uplineId
			AND b.ruben = 1
			AND b.winlostdate >= @yesterday
			AND NOT EXISTS (SELECT TOP 1 1 FROM #SportBettype s WHERE s.Bettype = b.bettype AND s.RefTable IN (1, 2))

				-- sum, balance, transfer tickets of this master and upline super
		INSERT INTO #BalanceInfo (superCash, masterCash, masterOutstanding, PendingTransfer3rd)
		SELECT
			SUM(CASE WHEN bettype IN (21008, 21009) THEN 0 ELSE CASE WHEN custid = @uplineId THEN winlost-actual_stake ELSE 0 END END),
			SUM(CASE WHEN bettype IN (21008, 21009) THEN 0 ELSE CASE WHEN custid = @CustID THEN winlost-actual_stake ELSE 0 END END),
			0,
			SUM(CASE WHEN bettype IN (21008, 21009) AND custid = @CustID THEN -(winlost-actual_stake) ELSE 0 END)
		FROM dbo.bettrans WITH(NOLOCK)
		WHERE custid IN (@CustID, @uplineId)
			AND matchid = 0
			AND bettype >= 19999
			AND ruben = 1

		SELECT
			@CustID AS CustId,
			@roleID AS RoleId,
			@username AS UserName,
			SUM(ISNULL(superCash, 0)) AS uplineCashBalance,
			SUM(ISNULL(masterCash, 0)) AS CashBalance,
			SUM(ISNULL(masterOutstanding, 0)) AS Outstanding,
			SUM(ISNULL(PendingTransfer3rd, 0)) AS PendingTransfer3rd,
			@GivenCredit AS GivenCredit
		FROM #BalanceInfo
    END
	
	DROP TABLE #SportBettype
	DROP TABLE #BalanceInfo
END
GO