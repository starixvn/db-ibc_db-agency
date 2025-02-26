/*<info serverAlias="DBSIC-bodb02" executers="wsv_alp,wsv_alpv" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [Age_Transfer_SelList_MAg]
	@masterid int,
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
	@TotalAgentBalance money = 0 OUTPUT,
	@TotalYesterdayAgentBalance money = 0 OUTPUT,
	@TotalAgentCashBalance money = 0 OUTPUT,
	@TotalYesterday_AgentCashBalance money = 0 OUTPUT,
	@TotalPendingTransfer3rd money = 0 OUTPUT,
	@TotalPages int=0 OUTPUT
AS
--Vinh@20080102: add yesterday balance columns
/*
Task : Select transfer list of MAgent
DB: DBAGE/bodb02
Original: 

Revisions:
	- 20080102@Vinh: add yesterday balance column
	- 20090212@Phuc: paging
	- 20090214@AnhPham: added getting data by username and status
	- 20090424@AnhPham: added condition based on total balance transfer 
	- 20090812@Phuc: add new filter enabled.
	- 20090818@Kiwi: Remove un-used agentClosedAccountCredit and AccountCount
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

Param's Explanation:
	• @CustID: MAgentID
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

	DECLARE @IsExistDirect BIT = 0

	CREATE TABLE #tmp_customer
	(
		[custid] int primary key,
		[enabled] bit,
		[username] varchar(30),
		[closed] bit,
		[suspended] bit,
		[firstname] nvarchar(50) null,
		[lastname] nvarchar(50) null,
		Locked TINYINT,
		agentCredit money,
		agentUsedCredit money,
		IsDirectMember BIT DEFAULT(0)
	)

	CREATE TABLE #balance  
	(
		recommend int,
		YesterdayCashBalance money,		
		TotalCashBalance money,
		YesterdayBalance money,		
		TotalBalance money,
		Outstanding money,
		PendingTransfer3rd money
	)

	CREATE TABLE #result_balance  
	(
		recommend int,
		YesterdayCashBalance money,		
		TotalCashBalance money,
		YesterdayBalance money,		
		TotalBalance money,
		Outstanding money,
		PendingTransfer3rd money
	)

	CREATE TABLE #DirectMemberList
	(
		custid int primary key
	)



	-- get move bet date
	DECLARE @balanceUpDay SMALLDATETIME, @moveBetsDay SMALLDATETIME
	DECLARE @tblMoveBetBalanceUp AS TABLE (BalanceUpDay SMALLDATETIME, MoveBetsDay SMALLDATETIME)

	INSERT INTO @tblMoveBetBalanceUp(BalanceUpDay,MoveBetsDay)
	EXEC bodb02.dbo.Age_SelBalanceUpDay
	
	SELECT @balanceUpDay = BalanceUpDay, @moveBetsDay = MoveBetsDay FROM @tblMoveBetBalanceUp

	;WITH cte AS
	(
		SELECT c.recommend AS CustId,
			isnull(SUM(CASE WHEN roleid = 2 THEN credit ELSE 0 END), 0) AS agentCredit,			
			isnull(SUM(CASE WHEN roleid = 1 THEN credit ELSE 0 END), 0) AS agentUsedCredit,
			0 AS IsDirectMember
		FROM CustDB.dbo.custinfo as c (nolock)
		WHERE mrecommend = @masterid AND roleid < 3 AND recommend > 0
			AND @Leveltype IN (0,1)
		GROUP BY c.recommend
		UNION ALL
		SELECT
				c.custid,
				isnull(credit,0) AS magentCredit,
				0 magentUsedCredit,
				1 AS IsDirectMember
			FROM CustDB.dbo.custinfo as c (nolock)
			WHERE mrecommend = @masterid 
				AND roleid = 1
				AND recommend = -3			
				AND @Leveltype IN (0,2)
	)
	INSERT INTO #tmp_customer (custid , agentCredit, agentUsedCredit,enabled, username, closed, suspended, firstname, lastname, Locked, IsDirectMember)
	SELECT tmp.custid, tmp.agentCredit, tmp.agentUsedCredit, ci.Enabled,ci.username, CASE WHEN cs.CloseInfo > 0 THEN 1 ELSE 0 END IsClosed
			, CASE WHEN SuspendInfo > 0 THEN 1 ELSE 0 END IsSuspended
			, c.firstname, c.lastname, ISNULL(cs.Locked, 0) Locked, tmp.IsDirectMember
	FROM cte tmp	
		INNER JOIN CustDB.dbo.CustInfo ci with (NOLOCK) ON tmp.custid = ci.custid 
		INNER JOIN CustDB.dbo.Customer c with (NOLOCK) on ci.custid = c.custid 
		INNER JOIN CustDB.dbo.CustProductStatus cs WITH(NOLOCK) ON cs.CustID = ci.custid
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
	FROM #tmp_customer t
	WHERE IsDirectMember = 1

	IF @@ROWCOUNT > 0
		SET @IsExistDirect = 1

	/* Balance Info */
	-- bettransRnG
	INSERT INTO #balance (recommend, YesterdayCashBalance, TotalCashBalance, YesterdayBalance, TotalBalance, Outstanding)
	SELECT
		recommend,
		ISNULL(SUM(CASE WHEN winlostdate = @yesterday AND statusID IN (111, 112, 113) THEN awinlost+comm-playercomm ELSE 0 END), 0),
		ISNULL(SUM(CASE WHEN statusID IN (111, 112, 113) THEN awinlost+comm-playercomm ELSE 0 END), 0),
		ISNULL(SUM(CASE WHEN winlostdate = @yesterday AND statusID IN (111, 112, 113) THEN awinlost+comm-playercomm ELSE 0 END), 0)
			+ ISNULL(SUM(CASE WHEN winlostdate = @yesterday AND statusID IN (111, 112, 113) THEN winlost-actual_stake+playercomm ELSE 0 END), 0),
		ISNULL(SUM(CASE WHEN statusID IN (111, 112, 113) THEN awinlost+comm-playercomm ELSE 0 END), 0)
			+ ISNULL(SUM(CASE WHEN statusID IN (111, 112, 113) THEN winlost-actual_stake+playercomm ELSE 0 END), 0),
		ISNULL(SUM(CASE WHEN statusID IN (0, 1) THEN ABS(actual_stake*apositiontaking) ELSE 0 END), 0)
	FROM #tmp_customer c 
		INNER JOIN dbo.bettransRnG b WITH(NOLOCK, index = IX_recommend) ON b.recommend = c.custid AND c.IsDirectMember = 0
	WHERE (
			statusID IN (0, 1)
			OR winlostdate >= @yesterday
		)
	GROUP BY recommend

	IF @IsExistDirect = 1
	BEGIN
		INSERT INTO #balance (recommend, YesterdayCashBalance, TotalCashBalance, YesterdayBalance, TotalBalance, Outstanding)
		SELECT
			c.custid,
			ISNULL(SUM(CASE WHEN winlostdate = @yesterday AND statusID IN (111, 112, 113) THEN winlost-actual_stake+playercomm ELSE 0 END), 0),
			ISNULL(SUM(CASE WHEN statusID IN (111, 112, 113) THEN winlost-actual_stake+playercomm ELSE 0 END), 0),
			ISNULL(SUM(CASE WHEN winlostdate = @yesterday AND statusID IN (111, 112, 113) THEN winlost-actual_stake+playercomm ELSE 0 END), 0),
			ISNULL(SUM(CASE WHEN statusID IN (111, 112, 113) THEN winlost-actual_stake+playercomm ELSE 0 END), 0),
			ISNULL(SUM(CASE WHEN statusID IN (0, 1) THEN ABS(actual_stake) ELSE 0 END), 0)
		FROM #DirectMemberList c 
			INNER JOIN dbo.bettransRnG b WITH(NOLOCK, index = IX_custid) ON b.custid = c.custid 
		WHERE (
				statusID IN (0, 1)
				OR winlostdate >= @yesterday
			)
		GROUP BY c.custid
	END

	-- bettransLC
	INSERT INTO #balance (recommend, YesterdayCashBalance, TotalCashBalance, YesterdayBalance, TotalBalance, Outstanding)
	SELECT
		recommend,
		ISNULL(SUM(CASE WHEN winlostdate = @yesterday AND statusID IN (111, 112, 113) THEN awinlost+comm-playercomm ELSE 0 END), 0),
		ISNULL(SUM(CASE WHEN statusID IN (111, 112, 113) THEN awinlost+comm-playercomm ELSE 0 END), 0),
		ISNULL(SUM(CASE WHEN winlostdate = @yesterday AND statusID IN (111, 112, 113) THEN awinlost+comm-playercomm ELSE 0 END), 0)
			+ ISNULL(SUM(CASE WHEN winlostdate = @yesterday AND statusID IN (111, 112, 113) THEN winlost-actual_stake+playercomm ELSE 0 END), 0),
		ISNULL(SUM(CASE WHEN statusID IN (111, 112, 113) THEN awinlost+comm-playercomm ELSE 0 END), 0)
			+ ISNULL(SUM(CASE WHEN statusID IN (111, 112, 113) THEN winlost-actual_stake+playercomm ELSE 0 END), 0),
		ISNULL(SUM(CASE WHEN statusID IN (0, 1) THEN ABS(actual_stake*apositiontaking) ELSE 0 END), 0)
	FROM #tmp_customer c
		INNER JOIN dbo.bettransLC b WITH(NOLOCK, index = IX_recommend) ON b.recommend = c.custid AND c.IsDirectMember = 0
	WHERE (
			statusID IN (0, 1)
			OR winlostdate >= @yesterday
		)
	GROUP BY recommend

	IF @IsExistDirect = 1
	BEGIN
		INSERT INTO #balance (recommend, YesterdayCashBalance, TotalCashBalance, YesterdayBalance, TotalBalance, Outstanding)
		SELECT
			c.custid,
			ISNULL(SUM(CASE WHEN winlostdate = @yesterday AND statusID IN (111, 112, 113) THEN winlost-actual_stake+playercomm ELSE 0 END), 0),
			ISNULL(SUM(CASE WHEN statusID IN (111, 112, 113) THEN winlost-actual_stake+playercomm ELSE 0 END), 0),
			ISNULL(SUM(CASE WHEN winlostdate = @yesterday AND statusID IN (111, 112, 113) THEN winlost-actual_stake+playercomm ELSE 0 END), 0),
			ISNULL(SUM(CASE WHEN statusID IN (111, 112, 113) THEN winlost-actual_stake+playercomm ELSE 0 END), 0),
			ISNULL(SUM(CASE WHEN statusID IN (0, 1) THEN ABS(actual_stake) ELSE 0 END), 0)
		FROM #DirectMemberList c
			INNER JOIN dbo.bettransLC b WITH(NOLOCK, index = IX_custid) ON b.custid = c.custid
		WHERE (
				statusID IN (0, 1)
				OR winlostdate >= @yesterday
			)
		GROUP BY c.custid
	END

	-- translog
	INSERT INTO #balance (recommend, YesterdayCashBalance, TotalCashBalance, YesterdayBalance, TotalBalance, Outstanding)
	SELECT
		recommend,
		0,
		0,
		0,
		0,
		ISNULL(SUM(ABS(actual_stake*apositiontaking)), 0)
	FROM #tmp_customer c
		INNER JOIN dbo.translog t WITH(NOLOCK, index = IX_recommend) ON  t.recommend = c.custid ANd c.IsDirectMember = 0
	WHERE statusID IN (0, 1)
	GROUP BY recommend

	IF @IsExistDirect = 1
	BEGIN
		INSERT INTO #balance (recommend, YesterdayCashBalance, TotalCashBalance, YesterdayBalance, TotalBalance, Outstanding)
		SELECT
			c.custid,
			0,
			0,
			0,
			0,
			ISNULL(SUM(ABS(actual_stake)), 0)
		FROM #DirectMemberList c
			INNER JOIN dbo.translog t WITH(NOLOCK, index = IX_custid) ON  t.custid = c.custid
		WHERE statusID IN (0, 1)
		GROUP BY c.custid
	END

	-- bettrans
		-- running ticket
	INSERT INTO #balance (recommend, YesterdayCashBalance, TotalCashBalance, YesterdayBalance, TotalBalance, Outstanding)
	SELECT
		recommend,
		0,
		0,
		0,
		0,
		ISNULL(SUM(ABS(actual_stake*apositiontaking)), 0)
	FROM #tmp_customer c
		INNER JOIN dbo.bettrans b WITH(NOLOCK, index = IX_recommend) ON b.recommend = c.custid AND c.IsDirectMember = 0
	WHERE ruben = 0
		AND NOT EXISTS (SELECT 1 FROM #SportBettype s WHERE b.bettype = s.bettype AND s.RefTable <> 0)
	GROUP BY recommend

	IF @IsExistDirect = 1
	BEGIN
		INSERT INTO #balance (recommend, YesterdayCashBalance, TotalCashBalance, YesterdayBalance, TotalBalance, Outstanding)
		SELECT
			c.custid,
			0,
			0,
			0,
			0,
			ISNULL(SUM(ABS(actual_stake)), 0)
		FROM #DirectMemberList c
			INNER JOIN dbo.bettrans b WITH(NOLOCK, index = IX_customerinfo) ON b.custid = c.custid 
		WHERE ruben = 0
			AND NOT EXISTS (SELECT 1 FROM #SportBettype s WHERE b.bettype = s.bettype AND s.RefTable <> 0)
		GROUP BY c.custid
	END

		-- settle ticket
	INSERT INTO #balance (recommend, YesterdayCashBalance, TotalCashBalance, YesterdayBalance, TotalBalance, Outstanding, PendingTransfer3rd)
	SELECT
		recommend,
		SUM(CASE WHEN winlostdate <= @yesterday THEN awinlost+comm-playercomm ELSE 0 END),
		SUM(awinlost+comm-playercomm),
		ISNULL(SUM(CASE WHEN winlostdate <= @yesterday THEN awinlost+comm-playercomm ELSE 0 END), 0)
			+ ISNULL(SUM(CASE WHEN winlostdate <= @yesterday THEN winlost-actual_stake+playercomm ELSE 0 END), 0),
		ISNULL(SUM(awinlost+comm-playercomm ), 0) + ISNULL(SUM(winlost-actual_stake+playercomm ), 0),
		0,
		0
	FROM #tmp_customer c
		INNER JOIN dbo.bettrans b WITH(NOLOCK, index = IX_recommend) ON b.recommend = c.custid AND c.IsDirectMember = 0
	WHERE b.statusID IN (111, 112, 113)
		AND (
					b.winlostdate < @yesterday
					OR NOT EXISTS (SELECT TOP 1 1 FROM #SportBettype s WHERE s.Bettype = b.bettype AND s.RefTable IN (1, 2))
				)
		AND winlostdate > @moveBetsDay 
	GROUP BY recommend

	IF @IsExistDirect = 1
	BEGIN
		INSERT INTO #balance (recommend, YesterdayCashBalance, TotalCashBalance, YesterdayBalance, TotalBalance, Outstanding, PendingTransfer3rd)
		SELECT
			c.custid,
			SUM(CASE WHEN winlostdate <= @yesterday THEN winlost-actual_stake+playercomm ELSE 0 END),
			SUM(winlost-actual_stake+playercomm),
			ISNULL(SUM(CASE WHEN winlostdate <= @yesterday THEN winlost-actual_stake+playercomm ELSE 0 END), 0),
			ISNULL(SUM(winlost-actual_stake+playercomm ), 0),
			0,
			0
		FROM #DirectMemberList c
			INNER JOIN dbo.bettrans b WITH(NOLOCK , index = IX_customerinfo) ON b.custid = c.custid
		WHERE b.statusID IN (111, 112, 113)
			AND (
						b.winlostdate < @yesterday
						OR NOT EXISTS (SELECT TOP 1 1 FROM #SportBettype s WHERE s.Bettype = b.bettype AND s.RefTable IN (1, 2))
					)
			AND winlostdate > @moveBetsDay 
		GROUP BY c.custid
	END

	/*-----------TRANSFER-------------*/
	INSERT INTO #balance (recommend, YesterdayCashBalance, TotalCashBalance, YesterdayBalance, TotalBalance, Outstanding, PendingTransfer3rd)
	SELECT
		Recommend,
		SUM(CASE WHEN bettype IN (21008, 21009) THEN 0 ELSE CASE WHEN b.custid = recommend THEN winlost-actual_stake ELSE awinlost+comm-playercomm END END),
		SUM(CASE WHEN bettype IN (21008, 21009) THEN 0 ELSE CASE WHEN b.custid = recommend THEN winlost-actual_stake ELSE awinlost+comm-playercomm END END),
		ISNULL(SUM(CASE WHEN bettype IN (21008, 21009) THEN 0 ELSE CASE WHEN b.custid = recommend THEN winlost-actual_stake ELSE awinlost+comm-playercomm END END), 0)
			+ ISNULL(SUM(CASE WHEN bettype IN (21008, 21009) THEN 0 ELSE CASE WHEN b.custid <> recommend AND b.custid <> mrecommend THEN winlost-actual_stake+playercomm ELSE 0 END END), 0),
		ISNULL(SUM(CASE WHEN bettype IN (21008, 21009) THEN 0 ELSE CASE WHEN b.custid = recommend THEN winlost-actual_stake ELSE awinlost+comm-playercomm END END), 0)
			+ ISNULL(SUM(CASE WHEN bettype IN (21008, 21009) THEN 0 ELSE CASE WHEN b.custid <> recommend AND b.custid <> mrecommend THEN winlost-actual_stake+playercomm ELSE 0 END END), 0),
		0,
		ISNULL(SUM(CASE WHEN bettype IN (21008, 21009) THEN -(winlost-actual_stake) ELSE 0 END), 0)
	FROM #tmp_customer c
		INNER JOIN dbo.Transfer b WITH(NOLOCK, index = IX_Recommend) ON b.Recommend = c.custid AND c.IsDirectMember = 0
	WHERE 1 = CASE WHEN bettype = 19999 AND winlostdate > @moveBetsDay THEN 0 --> new sum
				WHEN bettype = 20000 AND winlostdate > @balanceUpDay THEN 0 --> new bal
				WHEN winlostdate < @balanceUpDay THEN 0 --> old data
			ELSE 1 END
	GROUP BY recommend

	IF @IsExistDirect = 1
	BEGIN
		INSERT INTO #balance (recommend, YesterdayCashBalance, TotalCashBalance, YesterdayBalance, TotalBalance, Outstanding, PendingTransfer3rd)
		SELECT
			c.custid,
			SUM(CASE WHEN bettype IN (21008, 21009) THEN 0 ELSE winlost-actual_stake+playercomm END),
			SUM(CASE WHEN bettype IN (21008, 21009) THEN 0 ELSE winlost-actual_stake+playercomm END),
			ISNULL(SUM(CASE WHEN bettype IN (21008, 21009) THEN 0 ELSE winlost-actual_stake+playercomm END), 0),
			ISNULL(SUM(CASE WHEN bettype IN (21008, 21009) THEN 0 ELSE winlost-actual_stake+playercomm END), 0),
			0,
			ISNULL(SUM(CASE WHEN bettype IN (21008, 21009) THEN -(winlost-actual_stake) ELSE 0 END), 0)
		FROM #DirectMemberList c
			INNER JOIN dbo.Transfer b WITH(NOLOCK, index = IX_custid) ON b.CustId = c.custid
		WHERE 1 = CASE WHEN bettype = 19999 AND winlostdate > @moveBetsDay THEN 0 --> new sum
					WHEN bettype = 20000 AND winlostdate > @balanceUpDay THEN 0 --> new bal
					WHEN winlostdate < @balanceUpDay THEN 0 --> old data
				ELSE 1 END
		GROUP BY c.custid
	END
	/*-----------TRANSFER-------------*/
	/* End Balance Info */

	INSERT INTO #result_balance (recommend, YesterdayCashBalance, TotalCashBalance, YesterdayBalance, TotalBalance, Outstanding, PendingTransfer3rd)
	SELECT recommend, SUM(YesterdayCashBalance), SUM(TotalCashBalance), SUM(YesterdayBalance), SUM(TotalBalance), SUM(Outstanding), SUM(ISNULL(PendingTransfer3rd, 0))
	FROM #balance
	GROUP BY recommend

	SET @Username = isnull(@Username, '')

	IF @TotalPages = 0
	BEGIN
		IF isnull(@IsYesterdayBalance,0) = 0 
			SELECT 
				@TotalPages = count(1),@TotalPages=@TotalPages/@PageSize + case when @TotalPages%@PageSize>0 then 1 else 0 end
			FROM
				#tmp_customer
		ELSE
			SELECT 
				@TotalPages = count(1),@TotalPages=@TotalPages/@PageSize + case when @TotalPages%@PageSize>0 then 1 else 0 end
			FROM 
				#tmp_customer c
				LEFT JOIN #result_balance balance ON c.custid = balance.recommend
			WHERE
				CASE 
					WHEN @IsAllowTotalBalance = 0 THEN ISNULL(balance.YesterdayBalance, 0)
					WHEN @IsAllowTotalBalance = 1 THEN ISNULL(balance.TotalBalance, 0)
				END <> 0
	END

	CREATE TABLE #ClosedReason (custid INT, ClosedReason TINYINT)
	DECLARE @SQL NVARCHAR(MAX)

	SELECT  @SQL = 'SELECT CustID, ClosedReason
					FROM OPENQUERY(DBCUST, ''SELECT m.CustID, m.ClosedReason
											FROM CustDB.dbo.CustLoginInfo m WITH(NOLOCK)
												INNER JOIN CustDB.dbo.Customer c WITH(NOLOCK) ON m.CustID = c.custid
											WHERE (c.roleid = 2 OR (c.roleid = 1 AND c.recommend = -3))  
												AND c.mrecommend = ' + CONVERT(VARCHAR(30), @masterid) + ''')'
	INSERT INTO #ClosedReason (custid, ClosedReason)
	EXEC (@SQL)

	--TODO: Allow Auto Transfer [182071]
	DROP TABLE IF EXISTS #ClearBalanceCust_Setting;
	CREATE TABLE #ClearBalanceCust_Setting(FromCustID INT, ToCustID INT, ScheduleOption TINYINT);
	DECLARE @SQL_CBS NVARCHAR(MAX)
	SELECT  @SQL_CBS = 'SELECT FromCustID, ToCustID, ScheduleOption
					FROM OPENQUERY(DBCUST, ''SELECT cbs.FromCustID, cbs.ToCustID, cbs.ScheduleOption
											FROM CustDB.dbo.Age_ClearBalanceCust_Setting cbs WITH(NOLOCK)
											WHERE cbs.FromCustID = ' + CONVERT(VARCHAR(30), @masterid) + ''')'
	INSERT INTO #ClearBalanceCust_Setting (FromCustID, ToCustID, ScheduleOption)
	EXEC (@SQL_CBS)

	IF isnull(@IsYesterdayBalance,0) = 0
	BEGIN
		SELECT * FROM 
		(	SELECT ROW_NUMBER() OVER (ORDER BY enabled desc, closed, suspended, username) as RowNumber,
				c.username, 
				c.custid,
				c.closed,
				ISNULL(cr.ClosedReason, 0) AS ClosedReason,
				c.enabled,
				c.suspended,
				IsNull(c.agentCredit, 0) AS agentCredit,
				c.agentUsedCredit,
				IsNull(balance.Outstanding,0) agentOutstanding,
				IsNull(balance.TotalCashBalance,0) agentCashBalance,
				IsNull(balance.TotalBalance,0) agentBalance,
				IsNull(balance.YesterdayCashBalance,0) yesterday_agentCashBalance,
				IsNull(balance.YesterdayBalance,0) yesterday_agentBalance,
				IsNull(balance.PendingTransfer3rd,0) PendingTransfer3rd,
				c.firstname, 
				c.lastname,
				c.Locked,
				IIF(cbs.ToCustID > 0, 1, 0) AS IsAllowAutoTransfer,
				dbo.f_Age_ScheduleOption_Convert(cbs.ScheduleOption) AS ScheduleWeekDays,
				c.IsDirectMember,
				c.agentCredit - isnull(balance.outstanding,0) + isnull(balance.TotalBalance,0) - isnull(balance.YesterdayBalance,0) FutureBetCredit
			FROM 
				#tmp_customer c	
				LEFT JOIN #result_balance balance ON c.custid = balance.recommend
				LEFT JOIN #ClosedReason cr ON c.custid = cr.custid
				LEFT JOIN #ClearBalanceCust_Setting cbs ON cbs.FromCustID = @masterid AND cbs.ToCustID = c.CustID
			WHERE 1 = CASE 
							WHEN @AutoTransfer = 2 THEN 1
							WHEN @AutoTransfer = 0 AND cbs.ToCustID IS NULL THEN 1
							WHEN @AutoTransfer = 1 AND cbs.ToCustID > 0 THEN 1
							ELSE 0
						END
		)a
		WHERE a.RowNumber BETWEEN @RowStart AND @RowEND
		--Total
		SELECT @TotalOutStanding = sum(agentOutstanding),
				@TotalCredit = sum(agentCredit),
				@TotalUsedCredit = sum(agentUsedCredit),
				@TotalAgentBalance = sum(agentbalance),
				@TotalYesterdayAgentBalance = sum(yesterday_agentbalance),
				@TotalAgentCashBalance = sum(agentCashBalance),
				@TotalYesterday_AgentCashBalance = sum(yesterday_agentCashBalance),
				@TotalPendingTransfer3rd = sum(PendingTransfer3rd)
		FROM
		(	SELECT ROW_NUMBER() OVER (ORDER BY enabled desc, closed, suspended, username) as RowNumber,
				c.username, 
				c.closed,
				c.enabled,
				c.suspended,
				IsNull(c.agentCredit, 0) AS agentCredit, 
				c.agentUsedCredit, 
				IsNull(balance.Outstanding,0) agentOutstanding,
				IsNull(balance.TotalCashBalance,0) agentCashBalance,
				IsNull(balance.TotalBalance,0) agentBalance,
				IsNull(balance.YesterdayCashBalance,0) yesterday_agentCashBalance,
				IsNull(balance.YesterdayBalance,0) yesterday_agentBalance,
				IsNull(balance.PendingTransfer3rd,0) PendingTransfer3rd
			FROM
				#tmp_customer c	
				LEFT JOIN #result_balance balance ON c.custid = balance.recommend
				LEFT JOIN #ClearBalanceCust_Setting cbs ON cbs.FromCustID = @masterid AND cbs.ToCustID = c.CustID
			WHERE 1 = CASE 
							WHEN @AutoTransfer = 2 THEN 1
							WHEN @AutoTransfer = 0 AND cbs.ToCustID IS NULL THEN 1
							WHEN @AutoTransfer = 1 AND cbs.ToCustID > 0 THEN 1
							ELSE 0
						END
		)a
		WHERE a.RowNumber <= @RowEND
	END
	ELSE --Yesterday balance <> 0
	BEGIN
		SELECT * FROM 
		(	SELECT ROW_NUMBER() OVER (ORDER BY enabled desc, closed, suspended, username) as RowNumber,
				c.username, 
				c.custid,
				c.closed,
				ISNULL(cr.ClosedReason, 0) AS ClosedReason,
				c.enabled,
				c.suspended,
				IsNull(c.agentCredit, 0) AS agentCredit, 
				c.agentUsedCredit, 
				IsNull(balance.Outstanding,0) agentOutstanding,
				IsNull(balance.TotalCashBalance,0) agentCashBalance,
				IsNull(balance.TotalBalance,0) agentBalance,
				IsNull(balance.YesterdayCashBalance,0) yesterday_agentCashBalance,
				IsNull(balance.YesterdayBalance,0) yesterday_agentBalance,
				IsNull(balance.PendingTransfer3rd,0) PendingTransfer3rd,
				c.firstname, 
				c.lastname,
				c.Locked,
				IIF(cbs.ToCustID > 0, 1, 0) AS IsAllowAutoTransfer,
				dbo.f_Age_ScheduleOption_Convert(cbs.ScheduleOption) AS ScheduleWeekDays,
				c.IsDirectMember,
				c.agentCredit - isnull(balance.outstanding,0) + isnull(balance.TotalBalance,0) - isnull(balance.YesterdayBalance,0) FutureBetCredit
			FROM
				#tmp_customer c	
				LEFT JOIN #result_balance balance ON c.custid = balance.recommend
				LEFT JOIN #ClosedReason cr ON c.custid = cr.custid
				LEFT JOIN #ClearBalanceCust_Setting cbs ON cbs.FromCustID = @masterid AND cbs.ToCustID = c.CustID
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
		SELECT @TotalOutStanding = sum(agentOutstanding),
				@TotalCredit = sum(agentCredit),
				@TotalUsedCredit = sum(agentUsedCredit),
				@TotalAgentBalance = sum(agentbalance),
				@TotalYesterdayAgentBalance = sum(yesterday_agentbalance),
				@TotalAgentCashBalance = sum(agentCashBalance),
				@TotalYesterday_AgentCashBalance = sum(yesterday_agentCashBalance),
				@TotalPendingTransfer3rd = sum(PendingTransfer3rd)
		FROM
		(	SELECT ROW_NUMBER() OVER (ORDER BY enabled desc, closed, suspended, username) as RowNumber,
				c.username, 
				c.closed,
				c.enabled, 
				c.suspended,
				IsNull(c.agentCredit, 0) AS agentCredit, 
				c.agentUsedCredit, 
				IsNull(balance.Outstanding,0) agentOutstanding,
				IsNull(balance.TotalCashBalance,0) agentCashBalance,
				IsNull(balance.TotalBalance,0) agentBalance,
				IsNull(balance.YesterdayCashBalance,0) yesterday_agentCashBalance,
				IsNull(balance.YesterdayBalance,0) yesterday_agentBalance,
				IsNull(balance.PendingTransfer3rd,0) PendingTransfer3rd
			FROM
				#tmp_customer c	
				LEFT JOIN #result_balance balance ON c.custid = balance.recommend
				LEFT JOIN #ClearBalanceCust_Setting cbs ON cbs.FromCustID = @masterid AND cbs.ToCustID = c.CustID
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
	DROP TABLE #tmp_customer
	DROP TABLE #SportBettype
	DROP TABLE #ClosedReason
	DROP TABLE #ClearBalanceCust_Setting
	DROP TABLE #DirectMemberList
END
GO