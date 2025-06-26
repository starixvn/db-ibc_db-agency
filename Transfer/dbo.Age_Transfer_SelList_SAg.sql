/*<info serverAlias="DBSIC-bodb02,DBCTG-bodb02" executers="wsv_alp,wsv_alpv" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [Age_Transfer_SelList_SAg]
	@SAgID int,
	@PageSize int=500,
	@PageIndex int=1,
	@Username nvarchar(50)=null,
	@CustStatus varchar(50)='Open' ,
	@AutoTransfer	TINYINT = 2,
	@IsYesterdayBalance bit = null,
	@IsAllowTotalBalance bit = null,
	@Leveltype	TINYINT = 0,
	@TotalOutStanding money = 0 OUTPUT,
	@TotalCredit money = 0 OUTPUT,
	@TotalUsedCredit money = 0 OUTPUT,
	@TotalMagentBalance money = 0 OUTPUT,
	@TotalYesterdayMagentBalance money = 0 OUTPUT,
	@TotalMAgentCashBalance money = 0 OUTPUT,
	@TotalYesterday_MAgentCashBalance money = 0 OUTPUT,
	@TotalPendingTransfer3rd money = 0 OUTPUT,
	@TotalPages int=0 OUTPUT
AS
--Vinh@20080102: add yesterday balance columns
/*
Task : Credit/Balance of SAgent
DB: DBSIC/bodb02
Original:

Revisions:
	- 20080102@Vinh: add yesterday balance column
	- 20090212@Phuc: paging
	- 20090217@AnhPham: added getting data by username and status
	- 20090424@AnhPham: added condition based on total balance transfer 
	- 20090812@Phuc: add new filter enabled.
	- 20090818@Kiwi: Remove un-used magentClosedAccountCredit and AccountCount
	- 20110520@Johnson: Apply new arrange bettype
	- 20140304@Kathy: modify formula of Outstanding amount to be calculated based on table Bettrans and TransLog [Redmine:#11550]
	- 20150707@Jim: exclude Metric Gaming running ticket from bettrans (Feature #38789)
	- 20151214@Percy: exclude Cock Fighting running ticket from bettrans [Redmine: #48601]
	- 20160125@Percy: expand new range RNG Casino [Redmine: #50674]
	- 20160204@Percy: Support new product AllBet [Redmine: #50605]
	- 20160413@Percy: Support Voidbridge single wallet [Redmine: #55259]
	- 20161028@Percy: Support Fishing World [RedmineID: #65731]
	- 20170620@Percy: Apply new formula yesterday balance [RedmineID: #74291]
	- 20170622@Percy: Return ClosedReason column to apply color for closed accounts [RedmineID : #74494]
	- 20181005@Percy: Revise indexes [RedmineID: #101644]
	- 20200602@Percy: Separate PendingTransfer3rd from Cash and Balance [RedmineID: #135200]
	- 20210603@Sol: Alpha - All Sites - Lock account & indirect close account - [RedmineID: #148600]
	- 20210723@Evan: Replace parameter @enabled,@suspended,@closed with @CustStatus
	- 20210505@Sol: NAP - Alpha - Allow more time for transfer - [Redmine: #149927]
	- 20211111@Evan: Split transfer tickets out of bettrans - [Redmine: #164196]
	- 20230227@Evan: Balance-Up support transfer 247 [Redmine: #173554] 
	- 20230227@Bobby: AutoJob clear balance downlines [RedmineID: #182071]
	- 20231027@Bobby: AutoJob transfer - schedule option [RedmineID: #195135]
	- 20241118@Max: Alpha - Offer Direct Member for Super/Master - Move SP from DBAGE to DBSIC [Redmine: #211969]
	- 20250625@Bobby: Transfer changes for Cash Service [Redmine: #231494]

Param's Explanation:
	• @CustID: SAgentID
	• @IsAllowTotalBalance: filter data based on total balance transfer
	• @AutoTransfer: 
		- 0: NOT Allow
		- 1: Allow
		- 2: All
	• @Leveltype: 
		- 0: All
		- 1: Master Agent
		- 2: Directmember
*/
BEGIN
	SET NOCOUNT ON

	-- SportBettypeMatrix
	DECLARE @isTest BIT
	SELECT  @isTest = dbo.f_CheckSPVersion(@@PROCID)

	CREATE TABLE #SportBettype (ProductID INT, bettype INT, RefTable TINYINT)
	INSERT INTO #SportBettype (ProductID, bettype, RefTable)
	SELECT ProductID, bettype, RefTable FROM dbo.f_SportBettypeMatrix_Sel(0,0,0,2,'','',@isTest)
	
	DECLARE @RowCount int, @RowStart int, @RowEnd int
	SELECT @PageIndex = @PageIndex - 1, @RowStart = @PageSize * @PageIndex + 1, @RowEnd = @RowStart + @PageSize - 1

	DECLARE @today SMALLDATETIME,
			@yesterday SMALLDATETIME
	SELECT  @today     = CONVERT(DATE, GETDATE())
	SELECT	@yesterday = DATEADD(DD, -1, @today)

	-- get move bet date
	DECLARE @balanceUpDay SMALLDATETIME, @moveBetsDay SMALLDATETIME
	DECLARE @tblMoveBetBalanceUp AS TABLE (BalanceUpDay SMALLDATETIME, MoveBetsDay SMALLDATETIME)
	DECLARE @IsExistDirect BIT = 0

	INSERT INTO @tblMoveBetBalanceUp(BalanceUpDay,MoveBetsDay)
	EXEC bodb02.dbo.Age_SelBalanceUpDay
	
	SELECT @balanceUpDay = BalanceUpDay, @moveBetsDay = MoveBetsDay FROM @tblMoveBetBalanceUp

	CREATE TABLE #balance  
	(
		mrecommend int,
		YesterdayCashBalance money,		
		TotalCashBalance money,
		YesterdayBalance money,		
		TotalBalance money,
		Outstanding money,
		PendingTransfer3rd money
	)

	CREATE TABLE #result_balance  
	(
		mrecommend int,
		YesterdayCashBalance money,		
		TotalCashBalance money,
		YesterdayBalance money,		
		TotalBalance money,
		Outstanding money,
		PendingTransfer3rd money
	)

	CREATE TABLE #recommend (CustId INT)

	CREATE TABLE #CustomerList
	(
		custid int primary key,
		Credit money,		
		UsedCredit money,
		[enabled] bit,
		[username] varchar(30),
		[closed] bit,
		[suspended] bit,
		[firstname] nvarchar(50) null,
		[lastname] nvarchar(50) null,
		Locked TINYINT,
		IsDirectMember BIT
	)

	CREATE TABLE #DirectMemberList
	(
		custid int primary key,
		Credit money,		
		UsedCredit money,
		[enabled] bit,
		[username] varchar(30),
		[closed] bit,
		[suspended] bit,
		[firstname] nvarchar(50) null,
		[lastname] nvarchar(50) null,
		Locked TINYINT
	)

	SET @Username = isnull(@Username, '')
	--Filter user
	
	;WITH cte AS
	(
		SELECT 
			c.mrecommend AS custid,
			ISNULL(SUM(CASE WHEN roleid = 3 THEN credit ELSE 0 END), 0) AS magentCredit,
			ISNULL(SUM(CASE WHEN roleid = 2 OR recommend = -3 THEN credit ELSE 0 END), 0) AS magentUsedCredit,
			0 AS IsDirectMember
		FROM CustDB.dbo.custinfo as c (nolock)
		WHERE srecommend = @SAgID AND roleid < 4 AND mrecommend > 0
			AND @Leveltype IN (0,1)
		GROUP BY c.mrecommend
		UNION ALL
		SELECT 
			c.custid,
			isnull(credit,0) AS magentCredit,
			0 magentUsedCredit,
			1 AS IsDirectMember
		FROM CustDB.dbo.custinfo as c (nolock)
		WHERE srecommend = @SAgID 
			AND roleid = 1
			AND mrecommend = -4			
			AND @Leveltype IN (0,2)
	),
	CTE_CashAccumCredit AS (
		-- CashAccumCredit
		SELECT cac.mrecommend AS CustId
			, SUM(ISNULL(cac.AccumCreditReturn,0)) AS cashUsedCredit
		FROM dbo.CashAccumCredit cac WITH(NOLOCK)
		WHERE cac.srecommend = @SAgID
		GROUP BY cac.mrecommend
	)
	INSERT INTO #CustomerList (custid , Credit, UsedCredit,enabled, username, closed, suspended, firstname, lastname, Locked, IsDirectMember)
	SELECT tmp.custid, tmp.magentCredit, (tmp.magentUsedCredit + ISNULL(cac.cashUsedCredit, 0))
		, ci.Enabled,ci.username, CASE WHEN cs.CloseInfo > 0 THEN 1 ELSE 0 END IsClosed
		, CASE WHEN SuspendInfo > 0 THEN 1 ELSE 0 END IsSuspended
		, c.firstname, c.lastname, ISNULL(cs.Locked, 0) Locked, tmp.IsDirectMember
	FROM cte tmp	
		INNER JOIN CustDB.dbo.CustInfo ci with (NOLOCK) ON tmp.custid = ci.custid 
		INNER JOIN CustDB.dbo.Customer c with (NOLOCK) on ci.custid = c.custid 
		INNER JOIN CustDB.dbo.CustProductStatus cs WITH(NOLOCK) ON cs.CustID = ci.custid
		LEFT JOIN CTE_CashAccumCredit cac ON cac.CustId = ci.custid
	WHERE  (ci.username like '%' + @Username + '%' OR ISNULL(@username,'') = '')
					AND ci.Enabled = case @CustStatus when 'All' then ci.Enabled 
							else	case @CustStatus  
									when 'Disabled' then 0   
									else 1 end  
							end
					AND 1 =  case	when @CustStatus = 'Open' and cs.CloseInfo = 0 and cs.SuspendInfo = 0  then 1
										when @CustStatus = 'Suspended' and cs.CloseInfo = 0 and cs.SuspendInfo > 0 then 1
										when @CustStatus = 'Closed'	and cs.CloseInfo > 0  then 1
										when @CustStatus = 'Disabled' then 1
										when @CustStatus = 'All' then 1
										else 0 end

	INSERT INTO #DirectMemberList (custid)
	SELECT custid
	FROM #CustomerList t
	WHERE IsDirectMember = 1
	
	UNION ALL --Get direct member of Master
	SELECT c.CustId
	FROM #CustomerList t	
		INNER JOIN CustDB.dbo.CustInfo c WITH (NOLOCK)
			ON c.mrecommend = t.custid					
				AND c.roleid = 1
				AND c.recommend = -3
				AND t.IsDirectMember = 0

	IF @@ROWCOUNT > 0
		SET @IsExistDirect = 1
	
	/*Get Agent & direct memeber list*/
	INSERT INTO #recommend (CustId)
	SELECT custid
	FROM CustDB.dbo.custInfo c WITH(NOLOCK)
	WHERE c.roleid = 2
		AND EXISTS (SELECT 1 FROM #CustomerList m WHERE c.mrecommend = m.custid AND m.IsDirectMember = 0)

	/* Balance Info */
	-- bettransRnG
	INSERT INTO #balance (mrecommend, YesterdayCashBalance, TotalCashBalance, YesterdayBalance, TotalBalance, Outstanding)
	SELECT
		mrecommend,
		ISNULL(SUM(CASE WHEN winlostdate = @yesterday AND statusID IN (111, 112, 113) THEN mwinlost+acomm-comm ELSE 0 END), 0),
		ISNULL(SUM(CASE WHEN statusID IN (111, 112, 113) THEN mwinlost+acomm-comm ELSE 0 END), 0),
		ISNULL(SUM(CASE WHEN winlostdate = @yesterday AND statusID IN (111, 112, 113) THEN mwinlost+acomm-comm ELSE 0 END), 0)
			+ ISNULL(SUM(CASE WHEN winlostdate = @yesterday AND statusID IN (111, 112, 113) THEN awinlost+comm-playercomm ELSE 0 END), 0)
			+ ISNULL(SUM(CASE WHEN winlostdate = @yesterday AND statusID IN (111, 112, 113) THEN winlost-actual_stake+playercomm ELSE 0 END), 0),
		ISNULL(SUM(CASE WHEN statusID IN (111, 112, 113) THEN mwinlost+acomm-comm ELSE 0 END), 0)
			+ ISNULL(SUM(CASE WHEN statusID IN (111, 112, 113) THEN awinlost+comm-playercomm ELSE 0 END), 0)
			+ ISNULL(SUM(CASE WHEN statusID IN (111, 112, 113) THEN winlost-actual_stake+playercomm ELSE 0 END), 0),
		ISNULL(SUM(CASE WHEN statusID IN (0, 1) THEN ABS(actual_stake*mpositiontaking) ELSE 0 END), 0)
	FROM #recommend r
		INNER JOIN dbo.bettransRnG b WITH(NOLOCK, index = IX_recommend) ON b.recommend = r.CustId
	WHERE statusID IN (0, 1)
			OR winlostdate >= @yesterday
	GROUP BY mrecommend

	IF @IsExistDirect = 1
	BEGIN
		INSERT INTO #balance (mrecommend, YesterdayCashBalance, TotalCashBalance, YesterdayBalance, TotalBalance, Outstanding)
		SELECT
			CASE WHEN b.recommend = -3 THEN b.mrecommend ELSE r.custid END AS mrecommend,
			ISNULL(SUM(CASE WHEN winlostdate = @yesterday AND statusID IN (111, 112, 113) 
						THEN 
							CASE WHEN b.recommend = -3 THEN mwinlost+acomm-comm 
								ELSE winlost-actual_stake+playercomm END
					ELSE 0 END), 0),
			ISNULL(SUM(CASE WHEN statusID IN (111, 112, 113) 
						THEN 
							CASE WHEN b.recommend = -3 THEN mwinlost+acomm-comm 
							ELSE winlost-actual_stake+playercomm END			
					ELSE 0 END), 0),
			ISNULL(SUM(CASE WHEN winlostdate = @yesterday AND statusID IN (111, 112, 113) THEN mwinlost+acomm-comm ELSE 0 END), 0)
				+ ISNULL(SUM(CASE WHEN winlostdate = @yesterday AND statusID IN (111, 112, 113) THEN awinlost+comm-playercomm ELSE 0 END), 0)
				+ ISNULL(SUM(CASE WHEN winlostdate = @yesterday AND statusID IN (111, 112, 113) THEN winlost-actual_stake+playercomm ELSE 0 END), 0),
			ISNULL(SUM(CASE WHEN statusID IN (111, 112, 113) THEN mwinlost+acomm-comm ELSE 0 END), 0)
				+ ISNULL(SUM(CASE WHEN statusID IN (111, 112, 113) THEN awinlost+comm-playercomm ELSE 0 END), 0)
				+ ISNULL(SUM(CASE WHEN statusID IN (111, 112, 113) THEN winlost-actual_stake+playercomm ELSE 0 END), 0),
			ISNULL(SUM(CASE WHEN statusID IN (0, 1) THEN ABS(CASE WHEN b.recommend = -3 THEN actual_stake*mpositiontaking ELSE actual_stake END) ELSE 0 END), 0)
		FROM #DirectMemberList r
			inner join dbo.bettransRnG b WITH(NOLOCK, index = IX_custid ) ON r.custid = b.custid
		WHERE 	statusID IN (0, 1)
				OR winlostdate >= @yesterday
		GROUP BY CASE WHEN b.recommend = -3 THEN b.mrecommend ELSE r.custid END

	END

	-- bettransLC
	INSERT INTO #balance (mrecommend, YesterdayCashBalance, TotalCashBalance, YesterdayBalance, TotalBalance, Outstanding)
	SELECT
		mrecommend,
		ISNULL(SUM(CASE WHEN winlostdate = @yesterday AND statusID IN (111, 112, 113) THEN mwinlost+acomm-comm ELSE 0 END), 0),
		ISNULL(SUM(CASE WHEN statusID IN (111, 112, 113) THEN mwinlost+acomm-comm ELSE 0 END), 0),
		ISNULL(SUM(CASE WHEN winlostdate = @yesterday AND statusID IN (111, 112, 113) THEN mwinlost+acomm-comm ELSE 0 END), 0)
			+ ISNULL(SUM(CASE WHEN winlostdate = @yesterday AND statusID IN (111, 112, 113) THEN awinlost+comm-playercomm ELSE 0 END), 0)
			+ ISNULL(SUM(CASE WHEN winlostdate = @yesterday AND statusID IN (111, 112, 113) THEN winlost-actual_stake+playercomm ELSE 0 END), 0),
		ISNULL(SUM(CASE WHEN statusID IN (111, 112, 113) THEN mwinlost+acomm-comm ELSE 0 END), 0)
			+ ISNULL(SUM(CASE WHEN statusID IN (111, 112, 113) THEN awinlost+comm-playercomm ELSE 0 END), 0)
			+ ISNULL(SUM(CASE WHEN statusID IN (111, 112, 113) THEN winlost-actual_stake+playercomm ELSE 0 END), 0),
		ISNULL(SUM(CASE WHEN statusID IN (0, 1) THEN ABS(actual_stake*mpositiontaking) ELSE 0 END), 0)
	FROM #recommend r
		INNER JOIN dbo.bettransLC b WITH(NOLOCK, index = IX_recommend) ON b.recommend = r.CustId
	WHERE statusID IN (0, 1)
			OR winlostdate >= @yesterday
	GROUP BY mrecommend

	IF @IsExistDirect = 1
	BEGIN
		INSERT INTO #balance (mrecommend, YesterdayCashBalance, TotalCashBalance, YesterdayBalance, TotalBalance, Outstanding)
		SELECT
			CASE WHEN b.recommend = -3 THEN b.mrecommend ELSE r.custid END AS mrecommend,
			ISNULL(SUM(CASE WHEN winlostdate = @yesterday AND statusID IN (111, 112, 113) 
						THEN 
							CASE WHEN b.recommend = -3 THEN mwinlost+acomm-comm 
								ELSE winlost-actual_stake+playercomm END
					ELSE 0 END), 0),
			ISNULL(SUM(CASE WHEN statusID IN (111, 112, 113) 
						THEN 
							CASE WHEN b.recommend = -3 THEN mwinlost+acomm-comm 
							ELSE winlost-actual_stake+playercomm END			
					ELSE 0 END), 0),
			ISNULL(SUM(CASE WHEN winlostdate = @yesterday AND statusID IN (111, 112, 113) THEN mwinlost+acomm-comm ELSE 0 END), 0)
				+ ISNULL(SUM(CASE WHEN winlostdate = @yesterday AND statusID IN (111, 112, 113) THEN awinlost+comm-playercomm ELSE 0 END), 0)
				+ ISNULL(SUM(CASE WHEN winlostdate = @yesterday AND statusID IN (111, 112, 113) THEN winlost-actual_stake+playercomm ELSE 0 END), 0),
			ISNULL(SUM(CASE WHEN statusID IN (111, 112, 113) THEN mwinlost+acomm-comm ELSE 0 END), 0)
				+ ISNULL(SUM(CASE WHEN statusID IN (111, 112, 113) THEN awinlost+comm-playercomm ELSE 0 END), 0)
				+ ISNULL(SUM(CASE WHEN statusID IN (111, 112, 113) THEN winlost-actual_stake+playercomm ELSE 0 END), 0),
			ISNULL(SUM(CASE WHEN statusID IN (0, 1) THEN ABS(CASE WHEN b.recommend = -3 THEN actual_stake*mpositiontaking ELSE actual_stake END) ELSE 0 END), 0)
		FROM #DirectMemberList r
			INNER JOIN dbo.bettransLC b WITH (NOLOCK,index = IX_custid) ON b.custid = r.CustId
		WHERE 
				statusID IN (0, 1)
				OR winlostdate >= @yesterday
		GROUP BY CASE WHEN b.recommend = -3 THEN b.mrecommend ELSE r.custid END

	END

	-- translog
	INSERT INTO #balance (mrecommend, YesterdayCashBalance, TotalCashBalance, YesterdayBalance, TotalBalance, Outstanding)
	SELECT
		mrecommend,
		0,
		0,
		0,
		0,
		ISNULL(SUM(ABS(actual_stake*mpositiontaking)), 0)
	FROM #recommend r
		INNER JOIN dbo.translog t WITH(NOLOCK, index = IX_recommend) ON t.recommend = r.CustId
	WHERE statusID IN (0, 1)
	GROUP BY mrecommend
	
	IF @IsExistDirect = 1
	BEGIN
		INSERT INTO #balance (mrecommend, YesterdayCashBalance, TotalCashBalance, YesterdayBalance, TotalBalance, Outstanding)
		SELECT
			CASE WHEN t.recommend = -3 THEN t.mrecommend ELSE r.custid END AS mrecommend,
			0,
			0,
			0,
			0,
			ISNULL(SUM(ABS(CASE WHEN t.recommend = -3 THEN actual_stake*mpositiontaking ELSE actual_stake END)), 0)
		FROM #DirectMemberList r
			INNER JOIN  dbo.translog t WITH(NOLOCK,index = IX_custid ) ON t.custid = r.CustId
		WHERE statusID IN (0, 1)
		GROUP BY CASE WHEN t.recommend = -3 THEN t.mrecommend ELSE r.custid END
	END

	-- bettrans
		-- running ticket
	INSERT INTO #balance (mrecommend, YesterdayCashBalance, TotalCashBalance, YesterdayBalance, TotalBalance, Outstanding)
	SELECT
		mrecommend,
		0,
		0,
		0,
		0,
		ISNULL(SUM(ABS(actual_stake*mpositiontaking)), 0)
	FROM #recommend r
		INNER JOIN dbo.bettrans b WITH(NOLOCK, index = IX_recommend) ON b.recommend = r.CustId
	WHERE ruben = 0
		AND NOT EXISTS (SELECT 1 FROM #SportBettype s WHERE b.bettype = s.bettype AND s.RefTable <> 0)
	GROUP BY mrecommend

	IF @IsExistDirect = 1
	BEGIN
		INSERT INTO #balance (mrecommend, YesterdayCashBalance, TotalCashBalance, YesterdayBalance, TotalBalance, Outstanding)
		SELECT
			CASE WHEN b.recommend = -3 THEN b.mrecommend ELSE r.custid END AS mrecommend,
			0,
			0,
			0,
			0,
			ISNULL(SUM(ABS(CASE WHEN b.recommend = -3 THEN actual_stake*mpositiontaking ELSE actual_stake END)), 0)
		FROM #DirectMemberList r
			INNER JOIN dbo.bettrans b WITH(NOLOCK, INDEX = IX_customerinfo) ON b.custid = r.CustId
		WHERE ruben = 0
			AND NOT EXISTS (SELECT 1 FROM #SportBettype s WHERE b.bettype = s.bettype AND s.RefTable <> 0)
		GROUP BY CASE WHEN b.recommend = -3 THEN b.mrecommend ELSE r.custid END
	END
		-- settle ticket
	INSERT INTO #balance (mrecommend, YesterdayCashBalance, TotalCashBalance, YesterdayBalance, TotalBalance, Outstanding, PendingTransfer3rd)
	SELECT
		mrecommend,
		ISNULL(SUM(CASE WHEN winlostdate <= @yesterday THEN mwinlost+acomm-comm ELSE 0 END), 0),
		ISNULL(SUM(mwinlost+acomm-comm), 0),
		ISNULL(SUM(CASE WHEN winlostdate <= @yesterday THEN mwinlost+acomm-comm ELSE 0 END), 0)
			+ ISNULL(SUM(CASE WHEN winlostdate <= @yesterday THEN awinlost+comm-playercomm ELSE 0 END), 0)
			+ ISNULL(SUM(CASE WHEN winlostdate <= @yesterday THEN winlost-actual_stake+playercomm ELSE 0 END), 0),
		ISNULL(SUM(mwinlost+acomm-comm), 0)
			+ ISNULL(SUM(awinlost+comm-playercomm), 0) + ISNULL(SUM(winlost-actual_stake+playercomm), 0),
		0,
		0
	FROM #recommend r
		INNER JOIN dbo.bettrans b WITH(NOLOCK, index = IX_recommend) ON b.recommend = r.CustId
	WHERE b.statusID IN (111, 112, 113)
		AND (
					b.winlostdate < @yesterday
					OR NOT EXISTS (SELECT TOP 1 1 FROM #SportBettype s WHERE s.Bettype = b.bettype AND s.RefTable IN (1, 2))
				)
		AND winlostdate > @moveBetsDay  
	GROUP BY mrecommend

	IF @IsExistDirect = 1
	BEGIN
		INSERT INTO #balance (mrecommend, YesterdayCashBalance, TotalCashBalance, YesterdayBalance, TotalBalance, Outstanding, PendingTransfer3rd)
		SELECT
			CASE WHEN b.recommend = -3 THEN b.mrecommend ELSE r.custid END AS mrecommend,
			ISNULL(SUM(CASE WHEN winlostdate <= @yesterday 
						THEN 
							CASE WHEN b.recommend = -3 THEN mwinlost+acomm-comm 
								ELSE winlost-actual_stake+playercomm END
						ELSE 0 END), 0),
			ISNULL(SUM(CASE WHEN b.recommend = -3 THEN mwinlost+acomm-comm
							ELSE winlost-actual_stake+playercomm END)
					, 0),
			ISNULL(SUM(CASE WHEN winlostdate <= @yesterday THEN mwinlost+acomm-comm ELSE 0 END), 0)
				+ ISNULL(SUM(CASE WHEN winlostdate <= @yesterday THEN awinlost+comm-playercomm ELSE 0 END), 0)
				+ ISNULL(SUM(CASE WHEN winlostdate <= @yesterday THEN winlost-actual_stake+playercomm ELSE 0 END), 0),
			ISNULL(SUM(mwinlost+acomm-comm), 0)
				+ ISNULL(SUM(awinlost+comm-playercomm), 0) + ISNULL(SUM(winlost-actual_stake+playercomm), 0),
			0,
			0
		FROM #DirectMemberList r
			INNER JOIN dbo.bettrans b WITH(NOLOCK, INDEX = IX_customerinfo ) ON b.custid = r.CustId
		WHERE 
			 b.statusID IN (111, 112, 113)
			AND (
						b.winlostdate < @yesterday
						OR NOT EXISTS (SELECT TOP 1 1 FROM #SportBettype s WHERE s.Bettype = b.bettype AND s.RefTable IN (1, 2))
					)
			AND winlostdate > @moveBetsDay  
		GROUP BY CASE WHEN b.recommend = -3 THEN b.mrecommend ELSE r.custid END
	END

	/*---------------------TRANSFER TABLE-------------------------*/
	--Get recommend & member
	INSERT INTO #balance (mrecommend, YesterdayCashBalance, TotalCashBalance, YesterdayBalance, TotalBalance, Outstanding, PendingTransfer3rd)
	SELECT
		mrecommend,
		ISNULL(SUM(CASE WHEN bettype IN (21008, 21009) THEN 0 ELSE mwinlost+acomm-comm END), 0) YesterdayCashBalance, --19999_member

		ISNULL(SUM(CASE WHEN bettype IN (21008, 21009) THEN 0 ELSE mwinlost+acomm-comm END), 0) TotalCashBalance, --19999_member

		ISNULL(SUM(CASE WHEN bettype IN (21008, 21009) THEN 0 ELSE mwinlost+acomm-comm END), 0) --19999_member
			--19999_member + transfer_recommend
			+ ISNULL(SUM(CASE WHEN bettype IN (21008, 21009) THEN 0 ELSE CASE WHEN b.custid = recommend THEN winlost-actual_stake ELSE awinlost+comm-playercomm END END), 0)
			--19999_member + transfer_member
			+ ISNULL(SUM(CASE WHEN bettype IN (21008, 21009) THEN 0 ELSE CASE WHEN b.custid <> recommend THEN winlost-actual_stake+playercomm ELSE 0 END END), 0) YesterdayBalance,

		ISNULL(SUM(CASE WHEN bettype IN (21008, 21009) THEN 0 ELSE mwinlost+acomm-comm END), 0) --19999_member
			--19999_member + transfer_recommend
			+ ISNULL(SUM(CASE WHEN bettype IN (21008, 21009) THEN 0 ELSE CASE WHEN b.custid = recommend THEN winlost-actual_stake ELSE awinlost+comm-playercomm END END), 0)
			--19999_member + transfer_member
			+ ISNULL(SUM(CASE WHEN bettype IN (21008, 21009) THEN 0 ELSE CASE WHEN b.custid <> recommend THEN winlost-actual_stake+playercomm ELSE 0 END END), 0) TotalBalance,
		0 Outstanding,
		ISNULL(SUM(CASE WHEN bettype IN (21008, 21009) THEN -(winlost-actual_stake) ELSE 0 END), 0) PendingTransfer3rd
	FROM #recommend r
		INNER JOIN dbo.Transfer b WITH(NOLOCK, index = IX_Recommend) ON b.recommend = r.CustId
	WHERE 1 = CASE WHEN bettype = 19999 AND winlostdate > @moveBetsDay THEN 0 --> new sum
				WHEN bettype = 20000 AND winlostdate > @balanceUpDay THEN 0 --> new bal
				WHEN winlostdate < @balanceUpDay THEN 0 --> old data
				WHEN winlostdate > @yesterday AND bettype IN (31003,31004,31005) THEN 0 --> Cash service billing fees today
			ELSE 1 END
	GROUP BY mrecommend

	--Get mrecommend, only transfer record
	INSERT INTO #balance (mrecommend, YesterdayCashBalance, TotalCashBalance, YesterdayBalance, TotalBalance, Outstanding, PendingTransfer3rd)
	SELECT
		mrecommend,
		ISNULL(SUM(CASE WHEN bettype IN (21008, 21009) THEN 0 ELSE winlost-actual_stake END), 0) YesterdayCashBalance,
		ISNULL(SUM(CASE WHEN bettype IN (21008, 21009) THEN 0 ELSE winlost-actual_stake END), 0) TotalCashBalance,
		ISNULL(SUM(CASE WHEN bettype IN (21008, 21009) THEN 0 ELSE winlost-actual_stake END), 0) YesterdayBalance,
		ISNULL(SUM(CASE WHEN bettype IN (21008, 21009) THEN 0 ELSE winlost-actual_stake END), 0) TotalBalance,
		0 Outstanding,
		ISNULL(SUM(CASE WHEN bettype IN (21008, 21009) THEN -(winlost-actual_stake) ELSE 0 END), 0) PendingTransfer3rd
	FROM #CustomerList r
		INNER JOIN dbo.Transfer b WITH(NOLOCK, index = IX_custid) ON b.CustId = r.CustId AND r.IsDirectMember = 0
	WHERE 1 = CASE WHEN bettype = 19999 AND winlostdate > @moveBetsDay THEN 0 --> new sum
				WHEN bettype = 20000 AND winlostdate > @balanceUpDay THEN 0 --> new bal
				WHEN winlostdate < @balanceUpDay THEN 0 --> old data
				WHEN winlostdate > @yesterday AND bettype IN (31003,31004,31005) THEN 0 --> Cash service billing fees today
			ELSE 1 END
	GROUP BY mrecommend

	--Get member under direct Super & member under direct Master
	IF @IsExistDirect = 1
	BEGIN
		INSERT INTO #balance (mrecommend, YesterdayCashBalance, TotalCashBalance, YesterdayBalance, TotalBalance, Outstanding, PendingTransfer3rd)
		SELECT
			CASE WHEN b.recommend = -3 THEN b.mrecommend ELSE r.custid END AS mrecommend,
			ISNULL(SUM(CASE WHEN bettype IN (21008, 21009) THEN 0 
							ELSE 
								CASE WHEN b.Recommend = -3 THEN mwinlost+acomm-comm  --1999_member
								ELSE winlost-actual_stake+PlayerComm --transfer_member
								END
					END), 0) YesterdayCashBalance,

			ISNULL(SUM(CASE WHEN bettype IN (21008, 21009) THEN 0 
							ELSE 
								CASE WHEN b.Recommend = -3 THEN mwinlost+acomm-comm  --1999_member
								ELSE winlost-actual_stake+PlayerComm --transfer_member
								END
					END), 0) TotalCashBalance,
			
			ISNULL(SUM(CASE WHEN bettype IN (21008, 21009) OR b.Recommend = -4 THEN 0 ELSE mwinlost+acomm-comm END), 0)
					+ ISNULL(SUM(CASE WHEN bettype IN (21008, 21009) THEN 0 ELSE winlost-actual_stake+playercomm END), 0) YesterdayBalance,

			ISNULL(SUM(CASE WHEN bettype IN (21008, 21009) OR b.Recommend = -4 THEN 0 ELSE mwinlost+acomm-comm END), 0)
					+ ISNULL(SUM(CASE WHEN bettype IN (21008, 21009) THEN 0 ELSE winlost-actual_stake+playercomm END), 0) TotalBalance,

			0 Outstanding,
			ISNULL(SUM(CASE WHEN bettype IN (21008, 21009) THEN -(winlost-actual_stake) ELSE 0 END), 0) PendingTransfer3rd
		FROM  #DirectMemberList r
			INNER JOIN dbo.Transfer b WITH(NOLOCK, INDEX = IX_CustId) ON b.CustId = r.CustId
		WHERE  1 = CASE WHEN bettype = 19999 AND winlostdate > @moveBetsDay THEN 0 --> new sum
					WHEN bettype = 20000 AND winlostdate > @balanceUpDay THEN 0 --> new bal
					WHEN winlostdate < @balanceUpDay THEN 0 --> old data
				ELSE 1 END
		GROUP BY CASE WHEN b.recommend = -3 THEN b.mrecommend ELSE r.custid END
	END
	/*---------------------TRANSFER TABLE-------------------------*/
	/* End Balance Info */

	INSERT INTO #result_balance (mrecommend, YesterdayCashBalance, TotalCashBalance, YesterdayBalance, TotalBalance, Outstanding, PendingTransfer3rd)
	SELECT mrecommend, SUM(YesterdayCashBalance), SUM(TotalCashBalance), SUM(YesterdayBalance), SUM(TotalBalance), SUM(Outstanding), SUM(ISNULL(PendingTransfer3rd, 0))
	FROM #balance
	GROUP BY mrecommend

	--Calc total pages
	IF @TotalPages = 0
	BEGIN
		IF isnull(@IsYesterdayBalance,0) = 0 
		BEGIN
			SELECT 
				@TotalPages = count(1)
				,@TotalPages=CASE WHEN @PageSize < 10 THEN 1 ELSE @TotalPages/@PageSize + case when @TotalPages%@PageSize>0 then 1 else 0 end END
			FROM 
				#CustomerList
		END
		ELSE
		BEGIN
			SELECT 
				@TotalPages = count(1)
				,@TotalPages= CASE WHEN @PageSize < 10 THEN 1 ELSE @TotalPages/@PageSize + case when @TotalPages%@PageSize>0 then 1 else 0 end END
			FROM #CustomerList c
				LEFT JOIN #result_balance balance ON c.custid = balance.mrecommend
			WHERE
				CASE 
					WHEN @IsAllowTotalBalance = 0 THEN ISNULL(balance.YesterdayBalance, 0)
					WHEN @IsAllowTotalBalance = 1 THEN ISNULL(balance.TotalBalance, 0)
				END <> 0
		END
	END

	CREATE TABLE #ClosedReason (custid INT, ClosedReason TINYINT)
	DECLARE @SQL NVARCHAR(MAX)

	SELECT  @SQL = 'SELECT CustID, ClosedReason
					FROM OPENQUERY(DBCUST, ''SELECT m.CustID, m.ClosedReason
											FROM CustDB.dbo.CustLoginInfo m WITH(NOLOCK)
												INNER JOIN CustDB.dbo.Customer c WITH(NOLOCK) ON m.CustID = c.custid
											WHERE c.roleid = 3 AND c.srecommend = ' + CONVERT(VARCHAR(30), @SAgID) + ''')'
	INSERT INTO #ClosedReason (custid, ClosedReason)
	EXEC (@SQL)

	--get closedreason for direct member
	SELECT  @SQL = 'SELECT CustID, ClosedReason
					FROM OPENQUERY(DBCUST, ''SELECT m.CustID, m.ClosedReason
											FROM CustDB.dbo.CustLoginInfo_Member m WITH(NOLOCK)
												INNER JOIN CustDB.dbo.Customer c WITH(NOLOCK) ON m.CustID = c.custid
											WHERE c.roleid = 1 AND c.recommend = -4
												AND c.srecommend = ' + CONVERT(VARCHAR(30), @SAgID) + ''')'
	INSERT INTO #ClosedReason (custid, ClosedReason)
	EXEC (@SQL)

	--TODO: Allow Auto Transfer [182071]
	DROP TABLE IF EXISTS #ClearBalanceCust_Setting;
	CREATE TABLE #ClearBalanceCust_Setting(FromCustID INT, ToCustID INT, ScheduleOption TINYINT);
	DECLARE @SQL_CBS NVARCHAR(MAX)
	SELECT  @SQL_CBS = 'SELECT FromCustID, ToCustID, ScheduleOption
					FROM OPENQUERY(DBCUST, ''SELECT cbs.FromCustID, cbs.ToCustID, cbs.ScheduleOption
											FROM CustDB.dbo.Age_ClearBalanceCust_Setting cbs WITH(NOLOCK)
											WHERE cbs.FromCustID = ' + CONVERT(VARCHAR(30), @SAgID) + ''')'
	INSERT INTO #ClearBalanceCust_Setting (FromCustID, ToCustID, ScheduleOption)
	EXEC (@SQL_CBS)

	IF isnull(@IsYesterdayBalance,0) = 0
	BEGIN
		SELECT * FROM 
		(
			SELECT ROW_NUMBER() OVER (ORDER BY enabled desc, closed, suspended, c.username) as RowNumber,
				c.username, 
				c.custid,
				c.closed,
				ISNULL(cr.ClosedReason, 0) AS ClosedReason,
				c.enabled,
				c.suspended,
				IsNull(c.credit, 0) AS magentCredit, 
				c.UsedCredit AS magentUsedCredit, 
				IsNull(balance.Outstanding,0) magentOutstanding, 
				IsNull(balance.TotalCashBalance,0) magentCashBalance, 
				IsNull(balance.TotalBalance,0) magentBalance, 
				IsNull(balance.YesterdayCashBalance,0) yesterday_magentCashBalance, 
				IsNull(balance.YesterdayBalance,0) yesterday_magentBalance,
				IsNull(balance.PendingTransfer3rd,0) PendingTransfer3rd,
				c.firstname, 
				c.lastname,
				c.Locked,
				IIF(cbs.ToCustID > 0, 1, 0) AS IsAllowAutoTransfer,
				dbo.f_Age_ScheduleOption_Convert(cbs.ScheduleOption) AS ScheduleWeekDays,
				c.IsDirectMember,
				c.credit - isnull(balance.outstanding,0) + isnull(balance.TotalBalance,0) - isnull(balance.YesterdayBalance,0) FutureBetCredit
			FROM #CustomerList c
				LEFT JOIN #result_balance balance ON c.custid = balance.mrecommend
				LEFT JOIN #ClosedReason cr ON c.custid = cr.custid
				LEFT JOIN #ClearBalanceCust_Setting cbs ON cbs.FromCustID = @SAgID AND cbs.ToCustID = c.CustID
			WHERE 1 = CASE 
							WHEN @AutoTransfer = 2 THEN 1
							WHEN @AutoTransfer = 0 AND cbs.ToCustID IS NULL THEN 1
							WHEN @AutoTransfer = 1 AND cbs.ToCustID > 0 THEN 1
							ELSE 0
						END
		)a 
		WHERE a.RowNumber BETWEEN @RowStart AND @RowEND
		--Total
		SELECT @TotalOutStanding = sum(magentOutstanding),
				@TotalCredit = sum(magentCredit),
				@TotalUsedCredit = sum(magentUsedCredit),
				@TotalMAgentBalance = sum(magentBalance),
				@TotalYesterdayMAgentBalance = sum(yesterday_magentBalance),
				@TotalMAgentCashBalance = sum(magentCashBalance),
				@TotalYesterday_MAgentCashBalance = sum(yesterday_magentCashBalance),
				@TotalPendingTransfer3rd = sum(PendingTransfer3rd)
		FROM 
		(
			SELECT ROW_NUMBER() OVER (ORDER BY enabled desc, closed, suspended, c.username) as RowNumber,
				c.username, 
				c.custid,
				c.closed,
				c.enabled,
				c.suspended,
				IsNull(c.credit, 0) AS magentCredit, 
				c.usedcredit AS magentUsedCredit, 
				IsNull(balance.Outstanding,0) magentOutstanding, 
				IsNull(balance.TotalCashBalance,0) magentCashBalance, 
				IsNull(balance.TotalBalance,0) magentBalance, 
				IsNull(balance.YesterdayCashBalance,0) yesterday_magentCashBalance, 
				IsNull(balance.YesterdayBalance,0) yesterday_magentBalance,
				IsNull(balance.PendingTransfer3rd,0) PendingTransfer3rd
			FROM #CustomerList c
				LEFT JOIN #result_balance balance ON c.custid = balance.mrecommend
				LEFT JOIN #ClearBalanceCust_Setting cbs ON cbs.FromCustID = @SAgID AND cbs.ToCustID = c.CustID
			WHERE 1 = CASE 
							WHEN @AutoTransfer = 2 THEN 1
							WHEN @AutoTransfer = 0 AND cbs.ToCustID IS NULL THEN 1
							WHEN @AutoTransfer = 1 AND cbs.ToCustID > 0 THEN 1
							ELSE 0
						END
		)a 
		WHERE a.RowNumber <= @RowEND
	END
	ELSE--Yesterday balance <> 0
	BEGIN
		SELECT * FROM 
		(
			SELECT ROW_NUMBER() OVER (ORDER BY enabled desc, closed, suspended, c.username) as RowNumber,
				c.username, 
				c.custid,
				c.closed,
				ISNULL(cr.ClosedReason, 0) AS ClosedReason,
				c.enabled,
				c.suspended,
				IsNull(c.Credit, 0) AS magentCredit, 
				c.UsedCredit AS magentUsedCredit, 
				IsNull(balance.Outstanding,0) magentOutstanding, 
				IsNull(balance.TotalCashBalance,0) magentCashBalance, 
				IsNull(balance.TotalBalance,0) magentBalance, 
				IsNull(balance.YesterdayCashBalance,0) yesterday_magentCashBalance, 
				IsNull(balance.YesterdayBalance,0) yesterday_magentBalance,
				IsNull(balance.PendingTransfer3rd,0) PendingTransfer3rd,
				c.firstname, 
				c.lastname,
				c.Locked,
				IIF(cbs.ToCustID > 0, 1, 0) AS IsAllowAutoTransfer,
				dbo.f_Age_ScheduleOption_Convert(cbs.ScheduleOption) AS ScheduleWeekDays,
				c.IsDirectMember,
				c.credit - isnull(balance.outstanding,0) + isnull(balance.TotalBalance,0) - isnull(balance.YesterdayBalance,0) FutureBetCredit
			FROM #CustomerList c
				LEFT JOIN #result_balance balance ON c.custid = balance.mrecommend
				LEFT JOIN #ClosedReason cr ON c.custid = cr.custid
				LEFT JOIN #ClearBalanceCust_Setting cbs ON cbs.FromCustID = @SAgID AND cbs.ToCustID = c.CustID
			WHERE
				CASE 
					WHEN @IsAllowTotalBalance = 0 THEN ISNULL(balance.YesterdayBalance, 0)
					WHEN @IsAllowTotalBalance = 1 THEN ISNULL(balance.TotalBalance, 0)
				END <> 0
				AND 1 = CASE 
							WHEN @AutoTransfer = 2 THEN 1
							WHEN @AutoTransfer = 0 AND cbs.ToCustID IS NULL THEN 1
							WHEN @AutoTransfer = 1 AND cbs.ToCustID > 0 THEN 1
							ELSE 0
						END
		)a 
		WHERE a.RowNumber BETWEEN @RowStart AND @RowEND
		--Total
		SELECT @TotalOutStanding = sum(magentOutstanding),
				@TotalCredit = sum(magentCredit),
				@TotalUsedCredit = sum(UsedCredit),
				@TotalMAgentBalance = sum(magentBalance),
				@TotalYesterdayMAgentBalance = sum(yesterday_magentBalance),
				@TotalMAgentCashBalance = sum(magentCashBalance),
				@TotalYesterday_MAgentCashBalance = sum(yesterday_magentCashBalance),
				@TotalPendingTransfer3rd = sum(PendingTransfer3rd)
		FROM 
		(
			SELECT ROW_NUMBER() OVER (ORDER BY enabled desc, closed, suspended, c.username) as RowNumber,
				c.username, 
				c.custid,
				c.enabled,
				c.closed,
				c.suspended,
				IsNull(c.Credit, 0) AS magentCredit, 
				c.UsedCredit, 
				IsNull(balance.Outstanding,0) magentOutstanding, 
				IsNull(balance.TotalCashBalance,0) magentCashBalance, 
				IsNull(balance.TotalBalance,0) magentBalance, 
				IsNull(balance.YesterdayCashBalance,0) yesterday_magentCashBalance, 
				IsNull(balance.YesterdayBalance,0) yesterday_magentBalance,
				IsNull(balance.PendingTransfer3rd,0) PendingTransfer3rd
			FROM #CustomerList c
				LEFT JOIN #result_balance balance ON c.custid = balance.mrecommend
				LEFT JOIN #ClearBalanceCust_Setting cbs ON cbs.FromCustID = @SAgID AND cbs.ToCustID = c.CustID
			WHERE
				CASE 
					WHEN @IsAllowTotalBalance = 0 THEN ISNULL(balance.YesterdayBalance, 0)
					WHEN @IsAllowTotalBalance = 1 THEN ISNULL(balance.TotalBalance, 0)
				END <> 0
				AND 1 = CASE 
							WHEN @AutoTransfer = 2 THEN 1
							WHEN @AutoTransfer = 0 AND cbs.ToCustID IS NULL THEN 1
							WHEN @AutoTransfer = 1 AND cbs.ToCustID > 0 THEN 1
							ELSE 0
						END
		)a 
		WHERE a.RowNumber <= @RowEND
	END

	DROP TABLE #balance
	DROP TABLE #result_balance
	DROP TABLE #CustomerList
	DROP TABLE #SportBettype
	DROP TABLE #ClosedReason
	DROP TABLE #ClearBalanceCust_Setting
	DROP TABLE #DirectMemberList
	DROP TABLE #recommend
END
GO