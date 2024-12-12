/*<info serverAlias="DBCTG-bodb02,DBSIC-bodb02" executers="wsv_alp,wsv_alpv" viewers="" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Age_CustomerSelCreditBalanceList_MAg]
	@CustID		INT,
	@PageSize	INT = 500,
	@PageIndex	INT = 1,
	@Username	VARCHAR(30) = NULL,
	@Enabled	BIT = NULL,
	@Closed		BIT = NULL,
	@Suspended	BIT = NULL,
	@LevelType	TINYINT = 0,
	@TotalItems INT = 0 OUTPUT
AS 
/*
Task : Credit/Balance of Master Agent
DB: DB052.bodb02
Original: CustAccountSelCreditList_MAg_1

Revisions:
    - 20060222: remove refno  
	- 20060320: split table Customer
	- 20080102@Vinh: add yesterday balance column
	- 20090212@Phuc: paging
	- 20090214@AnhPham: added getting data by username and status
	- 20090710@Phuc: unhide IP for TB currency.
	- 20090812@Phuc: add new filter enabled.
	- 20110516@Johnson: Apply new arrange bettype
	- 20110617@Amy: modify to convert NULL for lastlogged
	- 20110823@Sophia: Count Negative stake as positive turnover
	- 20140304@Kathy: modify formula of Outstanding amount to be calculated based on table Bettrans and TransLog [Redmine:#11550]
	- 20150707@Jim: exclude Metric Gaming running ticket from bettrans (Feature #38789)
	- 20151222@Percy: exclude Cockfighting running ticket from bettrans [Redmine: #48601]
	- 20160112@Percy: Expand new bettype for RNG Casino [Redmine: #48283]
	- 20160222@Percy: Change formula when calculating bet credit [Redmine: #52653]
	- 20160215@Percy: Support AllBet Live Casino [Redmine: #50605]
	- 20160322@Percy:
		1. Change formula turnover [Redmine: #32974]
		2. Remove @ABSDate
	- 20160413@Percy: Support Voidbridge single wallet [Redmine: #55259]
	- 20161028@Percy: Support Fishing World [RedmineID: #65731]
	- 20170622@Percy: Return ClosedReason column to apply color for closed accounts [RedmineID : #74494]
	- 20171020@Percy: Add waiting tickets on translog [RedmineID: #84690]
	- 20180802@Paul: Enhance code, split into 2 smaller SPs: DBCUST.CustDB.Age_CustomerSelCreditBalClosedReason_MAg [Redmine: #97678]
	- 20210603@Sol: Alpha - All Sites - Lock account & indirect close account - [RedmineID: #148600]
	- 20210505@Sol: NAP - Alpha - Allow more time for transfer - [Redmine: #149927]
	- 20210910@Elodie: Alpha - Enhance customer's experience with auto clear given credit - [Redmine: #160429]
	- 20211111@Evan: Split transfer tickets out of bettrans - [Redmine: #164196]
	- 20230419@Danny: Return PendingTransfer3rd info [Redmine: #187059]
	- 20230227@Evan: Balance-Up support transfer 247 [Redmine: #173554] 
	- 20241118@Max: Alpha - Offer Direct Member for Super/Master - move SP to SiteDB [Redmine: #211969]

Param's Explanation:
• @CustID: MAgentID
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @isTest BIT
	SELECT  @isTest = dbo.f_CheckSPVersion(@@PROCID)

	CREATE TABLE #SportBettype (bettype INT, RefTable TINYINT)
	INSERT INTO #SportBettype (bettype, RefTable)
	SELECT bettype, RefTable FROM dbo.f_SportBettypeMatrix_Sel(0, 0, 0, 2, '', '', @isTest)

	DECLARE @today SMALLDATETIME,
			@yesterday SMALLDATETIME

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
		[custid]		INT PRIMARY KEY,
		[enabled]		BIT,
		[username]		VARCHAR(30),
		[iplogin]		NVARCHAR(20) NULL,
		[closed]		BIT,
		[suspended]		BIT,
		[firstname]		NVARCHAR(50) NULL,
		[lastname]		NVARCHAR(50) NULL,
		[credit]		MONEY NULL,
		[lastlogged]	SMALLDATETIME NULL,
		[usedCredit]	MONEY NULL,
		Locked			TINYINT,
		CreatedDate		SMALLDATETIME,
		IsDirectMember	BIT DEFAULT(0)
	)

	CREATE TABLE #balance  
	(
		custid		INT PRIMARY KEY,
		outstanding MONEY,		
		balance		MONEY,
		yesterdaybalance	MONEY,
		PendingTransfer3rd	MONEY
	)

	--Filter user
	SET @Username = ISNULL(@Username, '')
	;with cte AS
	(
		SELECT c.recommend AS CustId,
			isnull(SUM(CASE WHEN roleid = 2 THEN credit ELSE 0 END), 0) AS Credit,			
			isnull(SUM(CASE WHEN roleid = 1 THEN credit ELSE 0 END), 0) AS UsedCredit,
			0 AS IsDirectMember
		FROM CustDB.dbo.custinfo as c (nolock)
		WHERE mrecommend = @CustID AND roleid < 3 AND recommend > 0
			AND @Leveltype IN (0,1)
		GROUP BY c.recommend
		UNION ALL
		SELECT
				c.custid,
				isnull(credit,0) AS magentCredit,
				0 magentUsedCredit,
				1 AS IsDirectMember
			FROM CustDB.dbo.custinfo as c (nolock)
			WHERE mrecommend = @CustID 
				AND roleid = 1
				AND recommend = -3			
				AND @Leveltype IN (0,2)
	)
	INSERT INTO #tmp_customer ([custid],[enabled],[username],[iplogin],[closed],[suspended],[firstname],[lastname],[credit],[lastlogged],[usedCredit],Locked,CreatedDate,IsDirectMember)
	SELECT t.CustId, ci.Enabled, ci.username, c.iplogin
		, CASE WHEN cs.CloseInfo > 0 THEN 1 ELSE 0 END 
		, CASE WHEN SuspendInfo > 0 THEN 1 ELSE 0 END 
		, c.firstname, c.lastname, t.Credit, c.lastlogged, t.UsedCredit
		, ISNULL(cs.Locked, 0)
		, c.creatdate, t.IsDirectMember
	FROM cte t
		INNER JOIN CustDB.dbo.CustInfo ci with (NOLOCK) ON t.custid = ci.custid 
		INNER JOIN CustDB.dbo.Customer c with (NOLOCK) on ci.custid = c.custid 
		INNER JOIN CustDB.dbo.CustProductStatus cs WITH(NOLOCK) ON cs.CustID = ci.custid
	WHERE (ci.username like '%' + @Username + '%' OR @Username = '')
		AND enabled = case when coalesce(@Closed,@Suspended) is not null then 1 else coalesce(@enabled, enabled) end
		AND	isnull(cs.CloseInfo,0) = case when @Suspended = 1 then 0 else coalesce(@closed, isnull(cs.CloseInfo, 0)) end
		AND isnull(cs.SuspendInfo,0) = case when @Closed = 0 then 0 else coalesce(@Suspended, isnull(cs.SuspendInfo, 0))end

	--Capture balance
	--Normal recommend
	;WITH rt AS
	(
		SELECT recommend AS custid,
			ISNULL(SUM(CASE WHEN statusID IN (0, 1) THEN ABS(actual_stake) * apositiontaking ELSE 0 END), 0) AS outstanding,
			ISNULL(SUM(awinlost+comm-playercomm), 0) AS balance,
			ISNULL(SUM(CASE WHEN winlostdate <= @yesterday THEN awinlost+comm-playercomm ELSE 0 END), 0) AS yesterdaybalance,
			0 AS PendingTransfer3rd
		FROM  #tmp_customer c 
			INNER JOIN dbo.bettrans b WITH (NOLOCK, index = IX_recommend) ON b.recommend = c.custid AND c.IsDirectMember = 0
		WHERE (
					bettype NOT IN (SELECT bettype FROM #SportBettype WHERE RefTable <> 0)
					OR (
							statusID > 1 
							AND (
									bettype NOT IN (SELECT bettype FROM #SportBettype WHERE RefTable <> 3)
									OR winlostdate < @yesterday
								)
						)
				)
			AND winlostdate > @moveBetsDay
		GROUP BY recommend

		UNION ALL

		SELECT recommend AS custid,
			0 AS outstanding,
			ISNULL(SUM(CASE WHEN bettype IN (21008, 21009) THEN 0 ELSE CASE WHEN t.custid = recommend THEN winlost-actual_stake ELSE awinlost+comm-playercomm END END), 0) AS balance,
			ISNULL(SUM(CASE WHEN bettype IN (21008, 21009) THEN 0 ELSE CASE WHEN t.custid = recommend THEN winlost-actual_stake ELSE awinlost+comm-playercomm END END), 0) AS yesterdaybalance,
			ISNULL(SUM(CASE WHEN bettype IN (21008, 21009) THEN -(winlost-actual_stake) ELSE 0 END),0)
		FROM #tmp_customer c
			INNER JOIN dbo.Transfer t WITH (NOLOCK, index = IX_recommend) ON t.Recommend = c.custid AND c.IsDirectMember = 0
		WHERE 1 = CASE WHEN bettype = 19999 AND winlostdate > @moveBetsDay THEN 0 --> new sum
						WHEN bettype = 20000 AND winlostdate > @balanceUpDay THEN 0 --> new bal
						WHEN winlostdate < @balanceUpDay THEN 0 --> old data
					ELSE 1 END
		GROUP BY recommend

		UNION ALL

		SELECT recommend AS custid,
			ISNULL(SUM(ABS(actual_stake) * apositiontaking),0) AS outstanding, 
			0 balance,
			0 yesterdaybalance,
			0 AS PendingTransfer3rd
		FROM  #tmp_customer c
			INNER JOIN dbo.translog t WITH (NOLOCK) ON t.recommend = c.custid AND c.IsDirectMember = 0
		WHERE statusid IN (0,1)
		GROUP BY recommend

		UNION ALL

		SELECT
			recommend AS custid,
			ISNULL(SUM(CASE WHEN statusID IN (0, 1) THEN ABS(actual_stake) * apositiontaking ELSE 0 END),0) outstanding, 
			ISNULL(SUM(CASE WHEN statusID > 1 THEN awinlost+comm-playercomm ELSE 0 END),0) AS balance,
			ISNULL(SUM(CASE WHEN statusID > 1 AND winlostdate = @yesterday THEN awinlost+comm-playercomm ELSE 0 END),0) AS yesterdaybalance,
			0 AS PendingTransfer3rd
		FROM  #tmp_customer c
			INNER JOIN dbo.bettransRNG b WITH (NOLOCK) ON b.recommend = c.custid AND c.IsDirectMember = 0
		WHERE (
					statusID IN (0, 1)
					OR winlostdate >= @yesterday
				)
		GROUP BY recommend

		UNION ALL

		SELECT
			recommend AS custid,
			ISNULL(SUM(CASE WHEN statusID IN (0, 1) THEN ABS(actual_stake) * apositiontaking ELSE 0 END),0) outstanding, 
			ISNULL(SUM(CASE WHEN statusID > 1 THEN awinlost+comm-playercomm ELSE 0 END),0) AS balance,
			ISNULL(SUM(CASE WHEN statusID > 1 AND winlostdate = @yesterday THEN awinlost+comm-playercomm ELSE 0 END),0) AS yesterdaybalance,
			0 AS PendingTransfer3rd
		FROM  #tmp_customer c
			INNER JOIN dbo.bettransLC b WITH (NOLOCK) ON b.recommend = c.custid AND c.IsDirectMember = 0
		WHERE (
					statusID IN (0, 1)
					OR winlostdate >= @yesterday
				)
		GROUP BY recommend
	)
	INSERT INTO #balance(custid, outstanding, balance, yesterdaybalance, PendingTransfer3rd)
	SELECT custid,
		SUM(outstanding),
		SUM(balance),
		SUM(yesterdaybalance),
		SUM(PendingTransfer3rd)
	FROM rt
	GROUP BY custid

	--Member under direct master
	IF EXISTS (SELECT TOP 1 1 FROM #tmp_customer WHERE IsDirectMember = 1)
	BEGIN
		;WITH dr AS
		(
			SELECT c.custid AS custid,
				ISNULL(SUM(CASE WHEN statusID IN (0, 1) THEN ABS(actual_stake) ELSE 0 END), 0) AS outstanding,
				ISNULL(SUM(winlost-actual_stake+playercomm), 0) AS balance,
				ISNULL(SUM(CASE WHEN winlostdate <= @yesterday THEN winlost-actual_stake+playercomm ELSE 0 END), 0) AS yesterdaybalance,
				0 AS PendingTransfer3rd
			FROM  #tmp_customer c 
				INNER JOIN dbo.bettrans b WITH (NOLOCK, index = IX_customerinfo) ON b.custid = c.custid AND c.IsDirectMember = 1
			WHERE (
						bettype NOT IN (SELECT bettype FROM #SportBettype WHERE RefTable <> 0)
						OR (
								statusID > 1 
								AND (
										bettype NOT IN (SELECT bettype FROM #SportBettype WHERE RefTable <> 3)
										OR winlostdate < @yesterday
									)
							)
					)
				AND winlostdate > @moveBetsDay
			GROUP BY c.custid

			UNION ALL

			SELECT c.custid AS custid,
				0 AS outstanding,
				ISNULL(SUM(CASE WHEN bettype IN (21008, 21009) THEN 0 ELSE Winlost-Actual_Stake+PlayerComm END), 0) AS balance,
				ISNULL(SUM(CASE WHEN bettype IN (21008, 21009) THEN 0 ELSE Winlost-Actual_Stake+PlayerComm END), 0) AS yesterdaybalance,
				ISNULL(SUM(CASE WHEN bettype IN (21008, 21009) THEN -(winlost-actual_stake+PlayerComm) ELSE 0 END),0)
			FROM #tmp_customer c
				INNER JOIN dbo.Transfer t WITH (NOLOCK, index = IX_custid) ON t.CustId = c.custid AND c.IsDirectMember = 1
			WHERE 1 = CASE WHEN bettype = 19999 AND winlostdate > @moveBetsDay THEN 0 --> new sum
							WHEN bettype = 20000 AND winlostdate > @balanceUpDay THEN 0 --> new bal
							WHEN winlostdate < @balanceUpDay THEN 0 --> old data
						ELSE 1 END
			GROUP BY c.custid

			UNION ALL

			SELECT c.custid AS custid,
				ISNULL(SUM(ABS(actual_stake)),0) AS outstanding, 
				0 balance,
				0 yesterdaybalance,
				0 AS PendingTransfer3rd
			FROM  #tmp_customer c
				INNER JOIN dbo.translog t WITH (NOLOCK, index = IX_custid) ON t.custid = c.custid AND c.IsDirectMember = 1
			WHERE statusid IN (0,1)
			GROUP BY c.custid

			UNION ALL

			SELECT
				c.custid AS custid,
				ISNULL(SUM(CASE WHEN statusID IN (0, 1) THEN ABS(actual_stake) ELSE 0 END),0) outstanding, 
				ISNULL(SUM(CASE WHEN statusID > 1 THEN winlost-actual_stake+playercomm ELSE 0 END),0) AS balance,
				ISNULL(SUM(CASE WHEN statusID > 1 AND winlostdate = @yesterday THEN winlost-actual_stake+playercomm ELSE 0 END),0) AS yesterdaybalance,
				0 AS PendingTransfer3rd
			FROM  #tmp_customer c
				INNER JOIN dbo.bettransRNG b WITH (NOLOCK, index = IX_custid) ON b.custid = c.custid AND c.IsDirectMember = 1
			WHERE (
						statusID IN (0, 1)
						OR winlostdate >= @yesterday
					)
			GROUP BY c.custid

			UNION ALL

			SELECT
				c.custid AS custid,
				ISNULL(SUM(CASE WHEN statusID IN (0, 1) THEN ABS(actual_stake) ELSE 0 END),0) outstanding, 
				ISNULL(SUM(CASE WHEN statusID > 1 THEN winlost-actual_stake+playercomm ELSE 0 END),0) AS balance,
				ISNULL(SUM(CASE WHEN statusID > 1 AND winlostdate = @yesterday THEN winlost-actual_stake+playercomm ELSE 0 END),0) AS yesterdaybalance,
				0 AS PendingTransfer3rd
			FROM  #tmp_customer c
				INNER JOIN dbo.bettransLC b WITH (NOLOCK, index = IX_custid) ON b.custid = c.custid AND c.IsDirectMember = 1
			WHERE (
						statusID IN (0, 1)
						OR winlostdate >= @yesterday
					)
			GROUP BY c.custid
		)
		INSERT INTO #balance(custid, outstanding, balance, yesterdaybalance, PendingTransfer3rd)
		SELECT custid,
			SUM(outstanding),
			SUM(balance),
			SUM(yesterdaybalance),
			SUM(PendingTransfer3rd)
		FROM dr
		GROUP BY custid
	END

	--Calc total pages
	IF @TotalItems = 0
	BEGIN
		SELECT @TotalItems = count(1)
		FROM #tmp_customer
	END

	SELECT * FROM 
	(
		SELECT ROW_NUMBER() OVER (ORDER BY c.enabled desc, c.closed, suspended, c.username) as RowNumber,
			c.username,c.enabled,
			isnull(c.iplogin, '')as iplogin, 
			c.custid, 		
			c.closed closed,	
			suspended,
			c.firstname, 
			c.lastname, 
			isnull(balance.outstanding,0) AS outstanding, 
			isnull(balance.balance,0) AS balance, 
			isnull(balance.yesterdaybalance,0) AS yesterday_balance,
			isnull(c.credit,0) - isnull(c.usedCredit,0) betCredit,
			isnull(c.credit,0) credit,		
			CONVERT(nvarchar(30), c.lastlogged, 121) as lastlogged,
			c.Locked,
			c.CreatedDate,
			ISNULL(balance.PendingTransfer3rd,0) AS PendingTransfer3rd,
			IsDirectMember
		FROM #tmp_customer c
			LEFT JOIN #balance AS balance ON c.custid = balance.custid 
			--Members'Bet is settled today @Phuong20080930 
	)a
	WHERE a.RowNumber BETWEEN @RowStart AND @RowEND

	drop table #balance
	drop table #tmp_customer
	DROP TABLE #SportBettype
END
GO
