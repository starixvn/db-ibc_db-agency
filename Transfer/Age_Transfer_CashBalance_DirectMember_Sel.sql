/*<info serverAlias="DBSIC-bodb02" executers="wsv_alp,wsv_alpv" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [Age_Transfer_CashBalance_DirectMember_Sel]
	@CustID INT
AS

/*
	Created by: Max
	Task: Alpha - Offer Direct Member for Super/Master [Redmine: #211969]
	DB: DBSIC.bodb02
	
	Revisions:
		- 20241127@Max: Init SP [RedmineID: #211969]

	Param's Explanation:
		- @CustID: custid of Direct Member under Super/Master
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

	DECLARE @uplineId INT, @DirectMemberType INT --(-4: Direct under Super, -3: Direct under Master)
		, @GivenCredit MONEY, @username NVARCHAR(50)

	SELECT
		@DirectMemberType = recommend,
		@uplineId = CASE recommend WHEN -3 THEN mrecommend WHEN -4 THEN srecommend END,
		@GivenCredit = ISNULL(Credit, 0), -- must get real-time
		@username = username
	FROM DBCUST.CustDB.dbo.custInfo WITH(NOLOCK) WHERE custid = @custID AND RoleId = 1
	
	IF ISNULL(@DirectMemberType, 0) NOT IN (-3,-4) -- Direct Member only
	BEGIN
		RETURN
	END

	-- Get Balance Information --
	CREATE TABLE #BalanceInfo
	(
		UplineCash MONEY,
		memberCash MONEY,
		memberOutstanding MONEY,
		PendingTransfer3rd MONEY
	)

	-- get move bet date
	DECLARE @balanceUpDay SMALLDATETIME, @moveBetsDay SMALLDATETIME
	DECLARE @tblMoveBetBalanceUp AS TABLE (BalanceUpDay SMALLDATETIME, MoveBetsDay SMALLDATETIME)

	INSERT INTO @tblMoveBetBalanceUp(BalanceUpDay,MoveBetsDay)
	EXEC bodb02.dbo.Age_SelBalanceUpDay
	
	SELECT @balanceUpDay = BalanceUpDay, @moveBetsDay = MoveBetsDay FROM @tblMoveBetBalanceUp

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
    
	IF @DirectMemberType = -4
	BEGIN
		-- bettransRNG
		INSERT INTO #BalanceInfo (UplineCash, memberCash, memberOutstanding)
		SELECT 
			SUM(CASE WHEN statusID NOT IN (0,1) THEN swinlost+scomm-acomm ELSE 0 END),
			SUM(CASE WHEN statusID NOT IN (0,1) AND custid = @custid THEN winlost-actual_stake+playercomm ELSE 0 END),
			SUM(CASE WHEN statusID IN (0,1) AND custid = @custid THEN ABS(actual_stake) ELSE 0 END)
	    FROM dbo.bettransRNG WITH(NOLOCK)
		WHERE srecommend = @uplineId
			AND (
				statusID IN (0,1)
				OR winlostdate >= @yesterday
			)

		-- bettransLC
		INSERT INTO #BalanceInfo (UplineCash, memberCash, memberOutstanding)
		SELECT 
			SUM(CASE WHEN statusID NOT IN (0,1) THEN swinlost+scomm-acomm ELSE 0 END),
			SUM(CASE WHEN statusID NOT IN (0,1) AND custid = @custid THEN winlost-actual_stake+playercomm ELSE 0 END),
			SUM(CASE WHEN statusID IN (0,1) AND custid = @custid THEN ABS(actual_stake) ELSE 0 END)
	    FROM dbo.bettransLC WITH(NOLOCK)
		WHERE srecommend = @uplineId
			AND (
				statusID IN (0,1)
				OR winlostdate >= @yesterday
			)

		-- translog
		INSERT INTO #BalanceInfo (UplineCash, memberCash, memberOutstanding)
		SELECT 0, 0, SUM(ABS(actual_stake))
	    FROM dbo.translog WITH(NOLOCK)
		WHERE custid = @CustID
			AND statusID IN (0,1)

		-- bettrans
			-- running tickets
		INSERT INTO #BalanceInfo (UplineCash, memberCash, memberOutstanding)
		SELECT 0, 0, SUM(ABS(actual_stake))
		FROM dbo.bettrans b WITH(NOLOCK)
		WHERE b.custid = @CustID
			AND b.ruben = 0
			AND NOT EXISTS (SELECT TOP 1 1 FROM #SportBettype s WHERE s.Bettype = b.bettype AND s.RefTable <> 0)

			-- settle tickets
		INSERT INTO #BalanceInfo (UplineCash, memberCash, memberOutstanding)
		SELECT
			SUM(swinlost+scomm-acomm),
			SUM(CASE WHEN custid = @CustID THEN winlost-actual_stake+playercomm ELSE 0 END),
			0
		FROM dbo.bettrans b WITH(NOLOCK)
		WHERE b.srecommend = @uplineId
			AND b.statusID IN (111, 112, 113)
			AND winlostdate > @moveBetsDay
			AND (
				b.winlostdate < @yesterday
				OR NOT EXISTS (SELECT TOP 1 1 FROM #SportBettype s WHERE s.Bettype = b.bettype AND s.RefTable IN (1, 2))
			)

		-- transfer tickets
		INSERT INTO #BalanceInfo (UplineCash, memberCash, memberOutstanding)
		SELECT
			ISNULL(SUM(swinlost+scomm-acomm), 0) + ISNULL(SUM(CASE WHEN b.custid = b.srecommend THEN winlost-actual_stake ELSE 0 END),0),
			ISNULL(SUM(CASE WHEN CustId = @CustID THEN Winlost-Actual_Stake+PlayerComm END),0),
			0 
		FROM dbo.Transfer b WITH(NOLOCK)
		WHERE b.srecommend = @uplineId
			AND 1 = CASE WHEN bettype = 19999 AND winlostdate > @moveBetsDay THEN 0 --> new sum
						WHEN bettype = 20000 AND winlostdate > @balanceUpDay THEN 0 --> new bal
						WHEN winlostdate < @balanceUpDay THEN 0 --> old data
					ELSE 1 END
			AND bettype NOT IN (21008, 21009)
		SELECT
			@CustID AS CustId,
			1 AS RoleId,
			@username AS UserName,
			SUM(ISNULL(UplineCash, 0)) AS uplineCashBalance,
			SUM(ISNULL(memberCash, 0)) AS CashBalance,
			SUM(ISNULL(memberOutstanding, 0)) AS Outstanding,
			SUM(ISNULL(PendingTransfer3rd, 0)) AS PendingTransfer3rd,
			@GivenCredit AS GivenCredit
		FROM #BalanceInfo
	END
	ELSE IF @DirectMemberType = -3
	BEGIN
		-- bettransRNG
		INSERT INTO #BalanceInfo (UplineCash, memberCash, memberOutstanding)
		SELECT 
			SUM(CASE WHEN statusID NOT IN (0,1) THEN mwinlost+acomm-comm ELSE 0 END),
			SUM(CASE WHEN statusID NOT IN (0,1) AND custid = @CustID THEN winlost-actual_stake+playercomm ELSE 0 END),
			SUM(CASE WHEN statusID IN (0,1) AND custid = @CustID THEN ABS(actual_stake) ELSE 0 END)
	    FROM dbo.bettransRNG WITH(NOLOCK)
		WHERE mrecommend = @uplineId
			AND (
				statusID IN (0,1)
				OR winlostdate >= @yesterday
			)

		-- bettransLC
		INSERT INTO #BalanceInfo (UplineCash, memberCash, memberOutstanding)
		SELECT 
			SUM(CASE WHEN statusID NOT IN (0,1) THEN mwinlost+acomm-comm ELSE 0 END),
			SUM(CASE WHEN statusID NOT IN (0,1) AND custid = @CustID THEN winlost-actual_stake+playercomm ELSE 0 END),
			SUM(CASE WHEN statusID IN (0,1) AND custid = @CustID THEN ABS(actual_stake) ELSE 0 END)
	    FROM dbo.bettransLC WITH(NOLOCK)
		WHERE mrecommend = @uplineId
			AND (
				statusID IN (0,1)
				OR winlostdate >= @yesterday
			)

		-- translog
		INSERT INTO #BalanceInfo (UplineCash, memberCash, memberOutstanding)
		SELECT 0, 0, SUM(ABS(actual_stake))
	    FROM dbo.translog t WITH(NOLOCK)
		WHERE custid = @custid
			AND statusID IN (0,1)

		-- bettrans
			-- running tickets
		INSERT INTO #BalanceInfo (UplineCash, memberCash, memberOutstanding)
		SELECT 0, 0, SUM(ABS(actual_stake))
		FROM dbo.bettrans b WITH(NOLOCK)
		WHERE b.custid = @custid
			AND b.ruben = 0
			AND NOT EXISTS (SELECT TOP 1 1 FROM #SportBettype s WHERE s.Bettype = b.bettype AND s.RefTable <> 0)

			-- settle tickets
		INSERT INTO #BalanceInfo (UplineCash, memberCash, memberOutstanding)
		SELECT
			SUM(mwinlost+acomm-comm),
			SUM(CASE WHEN custid = @custid THEN winlost+actual_stake-playercomm ELSE 0 END),
			0
		FROM dbo.bettrans b WITH(NOLOCK)
		WHERE b.mrecommend = @uplineId
			AND b.statusID IN (111, 112, 113)
			AND winlostdate > @moveBetsDay
			AND (
				b.winlostdate < @yesterday
				OR NOT EXISTS (SELECT TOP 1 1 FROM #SportBettype s WHERE s.Bettype = b.bettype AND s.RefTable IN (1, 2))
			)
		-- transfer tickets
		INSERT INTO #BalanceInfo (UplineCash, memberCash, memberOutstanding)
		SELECT
			ISNULL(SUM(mwinlost+acomm-comm), 0) + ISNULL(SUM(CASE WHEN b.custid = b.mrecommend THEN winlost-actual_stake ELSE 0 END),0),
			ISNULL(SUM(CASE WHEN custid = @custid THEN Winlost-Actual_Stake+PlayerComm ELSE 0 END),0),
			0
		FROM dbo.Transfer b WITH(NOLOCK)
		WHERE 
			b.mrecommend = @uplineId
			AND 1 = CASE WHEN bettype = 19999 AND winlostdate > @moveBetsDay THEN 0 --> new sum
						WHEN bettype = 20000 AND winlostdate > @balanceUpDay THEN 0 --> new bal
						WHEN winlostdate < @balanceUpDay THEN 0 --> old data
					ELSE 1 END
			AND bettype NOT IN (21008, 21009)
						
		SELECT
			@CustID AS CustId,
			1 AS RoleId,
			@username AS UserName,
			SUM(ISNULL(UplineCash, 0)) AS uplineCashBalance,
			SUM(ISNULL(memberCash, 0)) AS CashBalance,
			SUM(ISNULL(memberOutstanding, 0)) AS Outstanding,
			SUM(ISNULL(PendingTransfer3rd, 0)) AS PendingTransfer3rd,
			@GivenCredit AS GivenCredit
		FROM #BalanceInfo
	END
	
	DROP TABLE #SportBettype
	DROP TABLE #BalanceInfo
END
GO