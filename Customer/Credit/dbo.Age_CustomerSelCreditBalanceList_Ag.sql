/*<info serverAlias="DBAGE-bodb02" executers="bodbDownlineNet,bodbDownlineNetView" viewers="" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Age_CustomerSelCreditBalanceList_Ag]
	@CustID		INT,
	@PageSize	INT = 500,
	@PageIndex	INT = 1,
	@Username	VARCHAR(30) = NULL,
	@Enabled	BIT = NULL,
	@Closed		BIT = NULL,
	@Suspended	BIT = NULL,
	@TotalItems INT = 0 OUTPUT
AS
/*
Task : Credit/Balance of Agent
DB: DBAGE/bodb02
Original: CustAccountSelCreditList_Ag_1

Revisions:

    - 20060222: remove refno  
	- 20060320: split table Customer
	- 20080102@Vinh: add yesterday balance column
	- 20090212@Phuc: paging
	- 20090214@AnhPham: added getting data by username and status
	- 20090710@Phuc: unhide IP for TB currency.
	- 20090812@Phuc: add new filter enabled.
	- 20110516@Johnson: apply new arrange bettype
	- 20110617@Amy: modify to convert NULL for lastlogged
	- 20110823@Sophia: Count Negative stake as positive turnover
	- 20140304@Kathy: modify formula of Outstanding amount to be calculated based on table Bettrans and TransLog [Redmine:#11550]
	- 20150707@Jim: exclude Metric Gaming running ticket from bettrans (Feature #38789)
	- 20151222@Percy: exclude Cockfighting running ticket from bettrans [Redmine: #48601]
	- 20160112@Percy: Expand new bettype for RNG Casino [Redmine: #48283]
	- 20160128@Percy: Support new sport Cricket [Redmine: #50027]
	- 20160215@Percy: Support AllBet Live Casino [Redmine: #50605]
	- 20160322@Percy:
		1. Change formula turnover [Redmine: #32974]
		2. Remove @ABSDate
	- 20160413@Percy: Support Voidbridge single wallet [Redmine: #55259]
	- 20161028@Percy: Support Fishing World [RedmineID: #65731]
	- 20170622@Percy: Return ClosedReason column to apply color for closed accounts [RedmineID : #74494]
	- 20171020@Percy: Add waiting tickets on translog [RedmineID: #84690]
	- 20180630@Sophia: WC2018 enhance code with high CPU [Redmine: #97612]
	- 20180720@Paul: Enhance code, split into 3 smaller SPs: DBTXN.bodb02.Age_CustomerSelCreditBalNetPosition_Ag, DBCUST.CustDB.Age_CustomerSelCreditBalClosedReason_Ag [Redmine: #97678]
	- 20210603@Sol: Alpha - All Sites - Lock account & indirect close account - [RedmineID: #148600]
	- 20210505@Sol: NAP - Alpha - Allow more time for transfer - [Redmine: #149927]
	- 20210910@Elodie: Alpha - Enhance customer's experience with auto clear given credit - [Redmine: #160429]

Param's Explanation:

• @CustID: AgentID

*/
BEGIN
	SET NOCOUNT ON

	DECLARE @isTest BIT
	SELECT  @isTest = dbo.f_CheckSPVersion(@@PROCID)

	CREATE TABLE #SportBettype (bettype INT PRIMARY KEY, RefTable TINYINT)
	INSERT INTO #SportBettype (bettype, RefTable)
	SELECT DISTINCT bettype, RefTable FROM dbo.f_SportBettypeMatrix_Sel(0, 0, 0, 2, '', '', @isTest)

	DECLARE /* @ABSDate DATETIME,*/
			@today SMALLDATETIME,
			@yesterday SMALLDATETIME

	-- SET @ABSDate = '2011-09-01'
	SELECT @today = CONVERT(DATE, GETDATE())
	SELECT @yesterday = DATEADD(DD, -1, @today)

	DECLARE @RowCount INT, @RowStart INT, @RowEnd INT
	SELECT @PageIndex = @PageIndex - 1, @RowStart = @PageSize * @PageIndex + 1, @RowEnd = @RowStart + @PageSize - 1

	-- get move bet date
	DECLARE @balanceUpDay SMALLDATETIME, @moveBetsDay SMALLDATETIME
	DECLARE @tblMoveBetBalanceUp AS TABLE (BalanceUpDay SMALLDATETIME, MoveBetsDay SMALLDATETIME)

	INSERT INTO @tblMoveBetBalanceUp(BalanceUpDay,MoveBetsDay)
	EXEC bodb02.dbo.Age_SelBalanceUpDay

	SELECT @balanceUpDay = BalanceUpDay, @moveBetsDay = MoveBetsDay FROM @tblMoveBetBalanceUp

	CREATE TABLE #tmp_customer
	(
		[RowNumber]		INT,
		[custid]		INT PRIMARY KEY,
		[enabled]		BIT,
		[username]		VARCHAR(30),
		[closed]		BIT,
		[suspended]		BIT,
		[credit]		MONEY NULL,
		Locked			TINYINT
	)


	CREATE TABLE #balance
	(
		custid		INT PRIMARY KEY,
		outstanding MONEY,		
		balance		MONEY
	) 

	SET @Username = ISNULL(@Username, '')

	--Filter user
	IF @Username = ''
		INSERT INTO #tmp_customer
		(
			[RowNumber],
			[custid],
			[enabled],
			[username],
			[closed],
			[suspended],
			[credit],
			Locked
		)
		SELECT ROW_NUMBER() OVER (
				ORDER BY ci.enabled DESC
					,cs.IsClosed
					,cs.IsSuspended
					,ci.username
				) AS RowNumber
			,ci.custid
			,ci.enabled
			,ci.username
			,cs.IsClosed
			,cs.IsSuspended
			,ci.credit
			,cs.Locked
		FROM CustInfo AS ci WITH (NOLOCK, INDEX = ix_custinfo_1)
			CROSS APPLY  
			(
				SELECT 
					CASE WHEN CloseInfo > 0 THEN 1 ELSE 0 END AS IsClosed
					, CASE WHEN SuspendInfo > 0 THEN 1 ELSE 0 END AS IsSuspended
					, ISNULL(Locked, 0) AS Locked
				FROM dbo.CustProductStatus cs WITH(NOLOCK)
				WHERE cs.CustID = ci.custid
			) AS cs
		WHERE 1 = ci.roleid 
			AND @CustID = ci.recommend 
			AND enabled = CASE 
								WHEN coalesce(@Closed, @Suspended) IS NOT NULL THEN 1
								ELSE coalesce(@enabled, enabled)
							END 
			AND isnull(cs.IsClosed, 0) = CASE 
											WHEN @suspended = 1 THEN 0
											ELSE coalesce(@closed, isnull(cs.IsClosed, 0))
										END 
			AND isnull(cs.IsSuspended, 0) = CASE 
											WHEN @Closed = 0 THEN 0
											ELSE coalesce(@suspended, isnull(cs.IsSuspended, 0))
										END
	ELSE
		INSERT INTO #tmp_customer
		(
			[RowNumber],
			[custid],
			[enabled],
			[username],
			[closed],
			[suspended],
			[credit],
			Locked
		)
		SELECT ROW_NUMBER() OVER (
				ORDER BY ci.enabled DESC
					,cs.IsClosed
					,cs.IsSuspended
					,ci.username
				) AS RowNumber
			,ci.custid
			,ci.enabled
			,ci.username
			,cs.IsClosed
			,cs.IsSuspended
			,ci.credit
			,cs.Locked
		FROM CustInfo AS ci WITH (NOLOCK, INDEX = ix_custinfo_1)
			CROSS APPLY  
			(
				SELECT 
					CASE WHEN CloseInfo > 0 THEN 1 ELSE 0 END AS IsClosed
					, CASE WHEN SuspendInfo > 0 THEN 1 ELSE 0 END AS IsSuspended
					, ISNULL(Locked, 0) AS Locked
				FROM dbo.CustProductStatus cs WITH(NOLOCK)
				WHERE cs.CustID = ci.custid
			) AS cs
		WHERE 1 = ci.roleid 
			AND @CustID = ci.recommend 
			AND ci.username LIKE '%' + @Username + '%' 
			AND enabled = CASE 
								WHEN coalesce(@Closed, @Suspended) IS NOT NULL THEN 1
								ELSE coalesce(@enabled, enabled)
							END 
			AND isnull(cs.IsClosed, 0) = CASE 
											WHEN @suspended = 1 THEN 0
											ELSE coalesce(@closed, isnull(cs.IsClosed, 0))
										END 
			AND isnull(cs.IsSuspended, 0) = CASE 
											WHEN @Closed = 0 THEN 0
											ELSE coalesce(@suspended, isnull(cs.IsSuspended, 0))
										END
 

	;WITH rt AS
	(		
		SELECT
				 a.Custid, 
				 SUM(CASE WHEN s.bettype IS NULL THEN outstanding ELSE 0 END) AS outstanding,  
				 SUM(CASE WHEN ISNULL(s.RefTable, 3) = 3 THEN balance ELSE balanceBeforeYesterday END) AS balance
			FROM (
					SELECT b.Custid,b.matchID, Bettype,
						ISNULL(SUM(CASE WHEN statusID IN (0, 1) THEN ABS(actual_stake) ELSE 0 END), 0) outstanding,
						ISNULL(SUM(CASE WHEN statusID > 1 THEN winlost - actual_stake + playercomm ELSE 0 END), 0) balance,
						ISNULL(SUM(CASE WHEN statusID > 1 AND winlostdate < @yesterday THEN winlost - actual_stake + playercomm ELSE 0 END), 0) balanceBeforeYesterday
					FROM  (SELECT TOP (@PageSize) CustID FROM #tmp_customer WHERE RowNumber BETWEEN @RowStart AND @RowEND) c
						INNER JOIN bettrans b WITH (NOLOCK) ON c.CustID = b.CustID
					WHERE 
						1 = CASE 
								WHEN bettype = 19999 and winlostdate > @moveBetsDay THEN 0 --> get data from ticket detail
								WHEN bettype < 19999 and winlostdate <= @moveBetsDay THEN 0 --> get data from sum record
							ELSE 1 END
					GROUP BY b.custid,b.matchID, Bettype
				) a
			LEFT JOIN #SportBettype  s ON s.bettype = a.bettype AND s.RefTable <> 0 
			GROUP BY a.Custid 
	
		UNION ALL
		SELECT custid
			,ISNULL(SUM(ABS(actual_stake)), 0) outstanding
			,0 balance
		FROM  translog WITH (NOLOCK)
		WHERE statusid IN (0,1) AND recommend = @custid
		GROUP BY custid

		UNION ALL
		SELECT custid
			,ISNULL(SUM(CASE WHEN statusID IN (0, 1) THEN ABS(actual_stake) ELSE 0 END), 0) outstanding
			,ISNULL(SUM(CASE WHEN statusID > 1 AND winlostdate >= @yesterday THEN winlost - actual_stake + playercomm ELSE 0 END), 0) balance
		FROM  bettransRNG WITH (NOLOCK)
		WHERE recommend = @custid
			AND (
					statusID IN (0, 1)
					OR winlostdate >= @yesterday
				)
		GROUP BY custid

		UNION ALL
		SELECT custid
			,ISNULL(SUM(CASE WHEN statusID IN (0, 1) THEN ABS(actual_stake) ELSE 0 END), 0) outstanding
			,ISNULL(SUM(CASE WHEN statusID > 1 AND winlostdate >= @yesterday THEN winlost - actual_stake + playercomm ELSE 0	END), 0) balance
		FROM  bettransLC WITH (NOLOCK)
		WHERE recommend = @custid
			AND (
					statusID IN (0, 1)
					OR winlostdate >= @yesterday
				)
		GROUP BY custid
	)
	INSERT INTO #balance
	SELECT custid,
		SUM(outstanding),
		SUM(balance)
	FROM rt
	GROUP BY custid
 

	CREATE TABLE #today_balance
	(
		custid	INT PRIMARY KEY,
		balance MONEY
	)

	;WITH today_balance AS (
		SELECT custid, SUM(winlost-actual_stake+playercomm) AS balance
		FROM   bettrans WITH (NOLOCK)
		WHERE  recommend = @CustID AND statusID > 1 AND bettype IN (SELECT bettype FROM #SportBettype WHERE RefTable IN(0,3))
			AND winlostdate = @today
			AND 1 = CASE 
						WHEN bettype = 19999 and winlostdate > @moveBetsDay THEN 0 --> get data from ticket detail
						WHEN bettype < 19999 and winlostdate <= @moveBetsDay THEN 0 --> get data from sum record
					ELSE 1 END
		GROUP BY custid
		UNION ALL
		SELECT custid, SUM(winlost-actual_stake+playercomm) AS balance
		FROM   bettransRNG WITH (NOLOCK)
		WHERE  recommend = @CustID AND statusID > 1
			AND winlostdate = @today
		GROUP BY custid
		UNION ALL
		SELECT custid, SUM(winlost-actual_stake+playercomm) AS balance
		FROM   bettransLC WITH (NOLOCK)
		WHERE  recommend = @CustID AND statusID > 1 
			AND winlostdate = @today
		GROUP BY custid
	)
	INSERT INTO #today_balance
	SELECT	custid, SUM(balance) AS balance
	FROM	today_balance
	GROUP BY custid


	IF @TotalItems = 0
	BEGIN
		SELECT @TotalItems = count(1)
		FROM #tmp_customer
	END

	SELECT RowNumber
			,ci.username
			,ci.enabled
			,isnull(c.iplogin, '') AS iplogin
			,ci.custid
			,ci.closed closed
			,ci.suspended
			,c.firstname
			,c.lastname
			,isnull(balance.outstanding, 0) outstanding
			,isnull(balance.balance, 0) balance
			,isnull(balance.balance, 0) - isnull(today_balance.balance, 0) yesterday_balance
			,isnull(balance.balance, 0) + isnull(ci.credit, 0) - isnull(balance.outstanding, 0) betCredit
			,isnull(ci.credit, 0) AS credit
			,CONVERT(NVARCHAR(30), c.lastlogged, 121) AS lastlogged
			,ci.Locked
			,c.creatdate
		FROM (SELECT TOP (@PageSize) * FROM #tmp_customer WHERE RowNumber BETWEEN @RowStart AND @RowEND) ci
			INNER JOIN Customer c (NOLOCK) ON ci.custid = c.custid
			LEFT JOIN #balance AS balance ON c.custid = balance.custid
			LEFT JOIN #today_balance AS today_balance ON c.custid = today_balance.custid
		ORDER BY RowNumber

	DROP TABLE #balance
	DROP TABLE #today_balance
	DROP TABLE #tmp_customer
	DROP TABLE #SportBettype
END
GO
