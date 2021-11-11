/*<info serverAlias="DBAGE-bodb02" executers="bodbDownlineNet,bodbDownlineNetView" viewers="" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Age_CustomerSelCreditBalanceList_MAg]
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
		CreatedDate		SMALLDATETIME
	)

	CREATE TABLE #balance  
	(
		custid		INT PRIMARY KEY,
		outstanding MONEY,		
		balance		MONEY,
		yesterdaybalance	MONEY
	)

	;WITH rt AS
	(
		SELECT recommend AS custid,
			ISNULL(SUM(CASE WHEN statusID IN (0, 1) THEN ABS(actual_stake) * apositiontaking ELSE 0 END), 0) AS outstanding,
			ISNULL(SUM(awinlost+comm-playercomm), 0) AS balance,
			ISNULL(SUM(CASE WHEN winlostdate <= @yesterday THEN awinlost+comm-playercomm ELSE 0 END), 0) AS yesterdaybalance
		FROM  bettrans WITH (NOLOCK)
		WHERE mrecommend = @CustID
			AND	(
					bettype NOT IN (SELECT bettype FROM #SportBettype WHERE RefTable <> 0)
					OR (
							statusID > 1 
							AND (
									bettype NOT IN (SELECT bettype FROM #SportBettype WHERE RefTable <> 3)
									OR winlostdate < @yesterday
								)
						)
				)
			AND bettype < 19999
			AND winlostdate > @moveBetsDay
		GROUP BY recommend

		UNION ALL

		SELECT recommend AS custid,
			0 AS outstanding,
			ISNULL(SUM(CASE WHEN custid = recommend THEN winlost-actual_stake ELSE awinlost+comm-playercomm END), 0) AS balance,
			ISNULL(SUM(CASE WHEN custid = recommend THEN winlost-actual_stake ELSE awinlost+comm-playercomm END), 0) AS yesterdaybalance
		FROM  Transfer t WITH (NOLOCK)
		WHERE mrecommend = @CustID
			AND ((bettype = 19999 and winlostdate <= @moveBetsDay) OR bettype > 19999)
		GROUP BY recommend

		UNION ALL

		SELECT recommend AS custid,
			ISNULL(SUM(ABS(actual_stake) * apositiontaking),0) AS outstanding, 
			0 balance,
			0 yesterdaybalance
		FROM  translog WITH (NOLOCK)
		WHERE mrecommend = @CustID
			AND statusid IN (0,1)
		GROUP BY recommend

		UNION ALL

		SELECT
			recommend AS custid,
			ISNULL(SUM(CASE WHEN statusID IN (0, 1) THEN ABS(actual_stake) * apositiontaking ELSE 0 END),0) outstanding, 
			ISNULL(SUM(CASE WHEN statusID > 1 THEN awinlost+comm-playercomm ELSE 0 END),0) AS balance,
			ISNULL(SUM(CASE WHEN statusID > 1 AND winlostdate = @yesterday THEN awinlost+comm-playercomm ELSE 0 END),0) AS yesterdaybalance
		FROM  bettransRNG WITH (NOLOCK)
		WHERE mrecommend = @CustID
			AND (
					statusID IN (0, 1)
					OR winlostdate >= @yesterday
				)
		GROUP BY recommend

		UNION ALL

		SELECT
			recommend AS custid,
			ISNULL(SUM(CASE WHEN statusID IN (0, 1) THEN ABS(actual_stake) * apositiontaking ELSE 0 END),0) outstanding, 
			ISNULL(SUM(CASE WHEN statusID > 1 THEN awinlost+comm-playercomm ELSE 0 END),0) AS balance,
			ISNULL(SUM(CASE WHEN statusID > 1 AND winlostdate = @yesterday THEN awinlost+comm-playercomm ELSE 0 END),0) AS yesterdaybalance
		FROM  bettransLC WITH (NOLOCK)
		WHERE mrecommend = @CustID
			AND (
					statusID IN (0, 1)
					OR winlostdate >= @yesterday
				)
		GROUP BY recommend
	)
	INSERT INTO #balance
	SELECT custid,
		SUM(outstanding),
		SUM(balance),
		SUM(yesterdaybalance)
	FROM rt
	GROUP BY custid

	SET @Username = ISNULL(@Username, '')
	--Filter user
	IF @Username = ''
		INSERT INTO #tmp_customer
		(
			[custid],
			[enabled],
			[username],
			[iplogin],
			[closed],
			[suspended],
			[firstname],
			[lastname],
			[credit],
			[lastlogged],
			[usedCredit],
			Locked,
			CreatedDate
		)
		SELECT	c.custid,
				ci.enabled,
				c.username,
				c.iplogin,
				cs.IsClosed,
				cs.IsSuspended,
				c.firstname,
				c.lastname,
				ci.credit,
				c.lastlogged,
				(SELECT SUM(credit) FROM custInfo WITH(NOLOCK) WHERE roleid = 1 AND recommend = ci.custid) AS usedCredit,
				cs.Locked,
				c.creatdate
		FROM CustInfo AS ci WITH (NOLOCK, INDEX = ix_custinfo)
			INNER JOIN Customer AS c (nolock) ON ci.custid = c.custid
			CROSS APPLY  
			(
				SELECT 
					CASE WHEN CloseInfo > 0 THEN 1 ELSE 0 END AS IsClosed
					, CASE WHEN SuspendInfo > 0 THEN 1 ELSE 0 END AS IsSuspended
					, ISNULL(Locked, 0) AS Locked
				FROM dbo.CustProductStatus cs WITH(NOLOCK)
				WHERE cs.CustID = ci.custid
			) AS cs
		WHERE	ci.roleid = 2
			AND ci.mrecommend=@CustID 
			AND enabled = case when coalesce(@Closed,@Suspended) is not null then 1 else coalesce(@enabled, enabled) end
			and	isnull(cs.IsClosed,0) = case when @Suspended = 1 then 0 else coalesce(@closed, isnull(cs.IsClosed, 0)) end
			and isnull(cs.IsSuspended,0) = case when @Closed = 0 then 0 else coalesce(@Suspended, isnull(cs.IsSuspended, 0))end
	ELSE
		INSERT INTO #tmp_customer
		(
			[custid],
			[enabled],
			[username],
			[iplogin],
			[closed],
			[suspended],
			[firstname],
			[lastname],
			[credit],
			[lastlogged],
			[usedCredit],
			Locked,
			CreatedDate
		)
		SELECT 
			c.custid, ci.enabled, c.username, c.iplogin, cs.IsClosed, cs.IsSuspended, c.firstname, c.lastname, ci.credit, c.lastlogged,
			(SELECT SUM(credit) FROM custInfo WITH(NOLOCK) WHERE roleid = 1 AND recommend = ci.custid) AS usedCredit, cs.Locked, c.creatdate
		FROM
			CustInfo as ci with (NOLOCK,index=ix_custinfo) 
			inner join Customer c (nolock) on ci.custid = c.custid
			CROSS APPLY  
			(
				SELECT 
					CASE WHEN CloseInfo > 0 THEN 1 ELSE 0 END AS IsClosed
					, CASE WHEN SuspendInfo > 0 THEN 1 ELSE 0 END AS IsSuspended
					, ISNULL(Locked, 0) AS Locked
				FROM dbo.CustProductStatus cs WITH(NOLOCK)
				WHERE cs.CustID = ci.custid
			) AS cs
		WHERE 
			ci.roleid=2 and ci.mrecommend=@CustID and ci.username like '%' + @Username + '%' 
			AND enabled = case when coalesce(@Closed,@Suspended) is not null then 1 else coalesce(@enabled, enabled) end
			and	isnull(cs.IsClosed,0) = case when @Suspended = 1 then 0 else coalesce(@closed, isnull(cs.IsClosed, 0)) end
			and isnull(cs.IsSuspended,0) = case when @Closed = 0 then 0 else coalesce(@Suspended, isnull(cs.IsSuspended, 0))end

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
			c.CreatedDate
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
