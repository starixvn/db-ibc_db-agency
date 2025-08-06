/*<info serverAlias="DBCTG-bodb02,DBSIC-bodb02" executers="wsv_alp,wsv_alpv" viewers="" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Age_CustomerSelCreditBalanceList_SAg]
	@CustID		INT,
	@PageSize	INT = 500,
	@PageIndex	INT = 1,
	@Username	VARCHAR(30) = NULL,
	@Enabled	BIT = NULL,
	@Closed		BIT = NULL,
	@Suspended	BIT = NULL,
	@Leveltype	TINYINT = 0,
	@TotalItems INT = 0 OUTPUT
AS
/*
Task : Credit/Balance of SAgent
DB: DB052.bodb02
Original: CustAccountSelCreditList_SAg_1

Revisions:
    - 20060222: remove refno  
	- 20060320: split table Customer
	- 20080102@Vinh: add yesterday balance column
	- 20090212@Phuc: paging
	- 20090217@AnhPham: added getting data by username AND status
	- 20090710@Phuc: unhide IP for TP currency.
	- 20090812@Phuc: add new filter enabled.
	- 20110516@Johnson: Apply new arrange bettype 
	- 20110617@Amy: modify to convert NULL for lastlogged
	- 20110823@Sophia: Count Negative stake AS positive turnover
	- 20140304@Kathy: modify formula of Outstanding amount to be calculated based on table Bettrans AND TransLog [Redmine:#11550]
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
	- 20180802@Paul: Enhance code, split into 2 smaller SPs: DBCUST.CustDB.Age_CustomerSelCreditBalClosedReason_SAg [Redmine: #97678]
	- 20210603@Sol: Alpha - All Sites - Lock account & indirect close account - [RedmineID: #148600]
	- 20210505@Sol: NAP - Alpha - Allow more time for transfer - [Redmine: #149927]
	- 20210910@Elodie: Alpha - Enhance customer's experience with auto clear given credit - [Redmine: #160429]
	- 20211111@Evan: Split transfer tickets out of bettrans - [Redmine: #164196]
	- 20230419@Danny: Return PendingTransfer3rd info [Redmine: #187059]
	- 20230227@Evan: Balance-Up support transfer 247 [Redmine: #173554] 
	- 20241118@Max: Alpha - Offer Direct Member for Super/Master - move SP to SiteDB [Redmine: #211969]
	- 20250402@Eden: Enhance sp [redmine: #222752]
	- 20250707@Bobby: Transfer changes for Cash Service [Redmine: #232421]

Param's Explanation:
� @CustID: SAgentID
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
	DECLARE @IsExistDirect BIT = 0

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
		custid		INT,
		outstanding MONEY,		
		balance		MONEY,
		yesterdaybalance	MONEY,
		PendingTransfer3rd	MONEY
	)

	CREATE TABLE #result_balance  
	(
		custid		INT,
		outstanding MONEY,		
		balance		MONEY,
		yesterdaybalance	MONEY,
		PendingTransfer3rd	MONEY
	)

	CREATE TABLE #recommend (CustId INT)
	CREATE TABLE #DirectMemberList(custid int)

	--Filter user
	SET @Username = ISNULL(@Username, '')
	;with cte AS
	(
		SELECT 
			c.mrecommend AS custid,
			ISNULL(SUM(CASE WHEN roleid = 3 THEN credit ELSE 0 END), 0) AS Credit,
			ISNULL(SUM(CASE WHEN roleid = 2 OR recommend = -3 THEN credit ELSE 0 END), 0) AS UsedCredit,
			0 AS IsDirectMember
		FROM CustDB.dbo.custinfo as c (nolock)
		WHERE srecommend = @CustID AND roleid < 4 --AND mrecommend > 0
			AND @Leveltype IN (0,1)
		GROUP BY c.mrecommend
		UNION ALL
		SELECT 
			c.custid,
			isnull(credit,0) AS magentCredit,
			0 magentUsedCredit,
			1 AS IsDirectMember
		FROM CustDB.dbo.custinfo as c (nolock)
		WHERE srecommend = @CustID 
			AND roleid = 1
			AND mrecommend = -4			
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
		CROSS APPLY  
		(
			SELECT 
				CASE WHEN CloseInfo > 0 THEN 1 ELSE 0 END AS CloseInfo
				, CASE WHEN SuspendInfo > 0 THEN 1 ELSE 0 END AS SuspendInfo
				, ISNULL(Locked, 0) AS Locked
			FROM CustDB.dbo.CustProductStatus cs WITH(NOLOCK)
			WHERE cs.CustID = ci.custid
		) AS cs
	WHERE (ci.username like '%' + @Username + '%' OR @Username = '')
		AND enabled = case when coalesce(@Closed,@Suspended) is not null then 1 else coalesce(@enabled, enabled) end
		AND	isnull(cs.CloseInfo,0) = case when @Suspended = 1 then 0 else coalesce(@closed, isnull(cs.CloseInfo, 0)) end
		AND isnull(cs.SuspendInfo,0) = case when @Closed = 0 then 0 else coalesce(@Suspended, isnull(cs.SuspendInfo, 0))end

	/*Get Agent & direct memeber list*/
	INSERT INTO #DirectMemberList (custid)
	SELECT custid
	FROM #tmp_customer t
	WHERE IsDirectMember = 1
	
	UNION ALL --Get direct member of Master
	SELECT c.CustId
	FROM #tmp_customer t	
		INNER JOIN CustDB.dbo.CustInfo c WITH (NOLOCK)
			ON c.mrecommend = t.custid					
				AND c.roleid = 1
				AND c.recommend = -3
				AND t.IsDirectMember = 0

	IF @@ROWCOUNT > 0
		SET @IsExistDirect = 1
	
	INSERT INTO #recommend (CustId)
	SELECT custid
	FROM CustDB.dbo.custInfo c WITH(NOLOCK)
	WHERE c.roleid = 2
		AND EXISTS (SELECT 1 FROM #tmp_customer m WHERE c.mrecommend = m.custid AND m.IsDirectMember = 0)
	
	/* Balance Info */
	INSERT INTO #balance(custid, outstanding, balance, yesterdaybalance, PendingTransfer3rd)
	SELECT mrecommend AS custid,
		ISNULL(SUM(CASE WHEN statusID IN (0, 1) THEN ABS(actual_stake) * mpositiontaking ELSE 0 END),0) AS outstanding,
		
		-- Helen fix bug
		ISNULL(SUM(CASE WHEN statusID > 1 THEN mwinlost+acomm-comm ELSE 0 END ), 0) AS balance,
		ISNULL(SUM(CASE WHEN statusID > 1 AND winlostdate <= @yesterday THEN mwinlost+acomm-comm ELSE 0 END),0) AS yesterdaybalance,

		/*
		ISNULL(SUM(mwinlost+acomm-comm), 0) AS balance,
		ISNULL(SUM(CASE WHEN winlostdate <= @yesterday THEN mwinlost+acomm-comm ELSE 0 END),0) AS yesterdaybalance,
		*/
		0 AS PendingTransfer3rd
	FROM #recommend r
		INNER JOIN dbo.bettrans b WITH(NOLOCK, index = IX_recommend) ON b.recommend = r.CustId
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
	GROUP BY mrecommend
	
	IF @IsExistDirect = 1
	BEGIN
		INSERT INTO #balance(custid, outstanding, balance, yesterdaybalance, PendingTransfer3rd)
		SELECT CASE WHEN b.recommend = -3 THEN b.mrecommend ELSE r.custid END AS mrecommend,
			ISNULL(SUM(CASE WHEN statusID IN (0, 1) THEN CASE WHEN b.recommend = -3 THEN ABS(actual_stake) * mpositiontaking ELSE ABS(actual_stake) END ELSE 0 END),0) AS outstanding,
			-- Helen - Code fix issue 217128
			ISNULL(SUM(CASE WHEN b.recommend = -3 AND statusID > 1 THEN mwinlost+acomm-comm
							WHEN b.recommend = -4 AND statusID > 1 THEN winlost-actual_stake+playercomm
							ELSE 0  END)
					, 0) AS balance,
			ISNULL(SUM(CASE WHEN winlostdate <= @yesterday 
						THEN 
							CASE WHEN b.recommend = -3 AND b.statusID > 1 THEN mwinlost+acomm-comm 
								 WHEN b.recommend = -4 AND b.statusID > 1 THEN winlost-actual_stake+playercomm
								 ELSE 0 END
						ELSE 0 END), 0) AS yesterdaybalance,
			/* -- Max - Code cause issue 217128
			ISNULL(SUM(mwinlost+acomm-comm), 0) 
				+ ISNULL(SUM(winlost-actual_stake+playercomm), 0) AS balance,
			ISNULL(SUM(CASE WHEN winlostdate <= @yesterday THEN mwinlost+acomm-comm ELSE 0 END),0) 
				+ ISNULL(SUM(CASE WHEN winlostdate <= @yesterday THEN winlost-actual_stake+playercomm ELSE 0 END), 0) AS yesterdaybalance,
				*/

			0 AS PendingTransfer3rd
		FROM #DirectMemberList r
			INNER JOIN dbo.bettrans b WITH(NOLOCK, index = IX_customerinfo) ON b.custid = r.CustId
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
		GROUP BY CASE WHEN b.recommend = -3 THEN b.mrecommend ELSE r.custid END
	END

	INSERT INTO #balance(custid, outstanding, balance, yesterdaybalance, PendingTransfer3rd)
	SELECT mrecommend AS custid,
		0 AS outstanding,
		ISNULL(SUM(CASE WHEN bettype IN (21008, 21009) THEN 0 ELSE CASE WHEN b.custid = mrecommend THEN winlost-actual_stake ELSE  mwinlost+acomm-comm END END), 0) AS balance,
		ISNULL(SUM(CASE WHEN bettype IN (21008, 21009) THEN 0 ELSE CASE WHEN b.custid = mrecommend THEN winlost-actual_stake ELSE  mwinlost+acomm-comm END END * ck.CalYesterday), 0) AS yesterdaybalance,

		ISNULL(SUM(CASE WHEN bettype IN (21008, 21009) THEN -(winlost-actual_stake) ELSE 0 END), 0) PendingTransfer3rd
	FROM  #recommend r
		INNER JOIN dbo.Transfer b WITH(NOLOCK, index = IX_Recommend) ON b.recommend = r.CustId
		OUTER APPLY (
			SELECT CASE 
					WHEN winlostdate > @yesterday AND bettype >= 31000 THEN 0 --> Cash service today transfers
					ELSE 1 END
		) AS ck(CalYesterday) 
	WHERE 1 = CASE WHEN bettype = 19999 AND winlostdate > @moveBetsDay THEN 0 --> new sum
					WHEN bettype = 20000 AND winlostdate > @balanceUpDay THEN 0 --> new bal
					WHEN winlostdate < @balanceUpDay THEN 0 --> old data
				ELSE 1 END
	GROUP BY mrecommend

	--Get mrecommend, only transfer record
	INSERT INTO #balance(custid, outstanding, balance, yesterdaybalance, PendingTransfer3rd)
	SELECT
		mrecommend, 0,
		ISNULL(SUM(CASE WHEN bettype IN (21008, 21009) THEN 0 ELSE winlost-actual_stake END), 0),
		ISNULL(SUM(CASE WHEN bettype IN (21008, 21009) THEN 0 ELSE winlost-actual_stake END * ck.CalYesterday), 0),
		ISNULL(SUM(CASE WHEN bettype IN (21008, 21009) THEN -(winlost-actual_stake) ELSE 0 END), 0)
	FROM #tmp_customer r
		INNER JOIN dbo.Transfer b WITH(NOLOCK, index = IX_custid) ON b.CustId = r.CustId AND r.IsDirectMember = 0
		OUTER APPLY (
			SELECT CASE 
					WHEN winlostdate > @yesterday AND bettype >= 31000 THEN 0 --> Cash service today transfers
					ELSE 1 END
		) AS ck(CalYesterday) 
	WHERE 1 = CASE WHEN bettype = 19999 AND winlostdate > @moveBetsDay THEN 0 --> new sum
				WHEN bettype = 20000 AND winlostdate > @balanceUpDay THEN 0 --> new bal
				WHEN winlostdate < @balanceUpDay THEN 0 --> old data
			ELSE 1 END
	GROUP BY mrecommend

	--Get member under direct Super & member under direct Master
	IF @IsExistDirect = 1
	BEGIN
		INSERT INTO #balance(custid, outstanding, balance, yesterdaybalance, PendingTransfer3rd)
		SELECT
			CASE WHEN b.recommend = -3 THEN b.mrecommend ELSE r.custid END AS mrecommend,
			0 Outstanding,		
			-- Reference on dbage SP: Age_CustomerSelCreditBalanceList_XXX
			ISNULL(SUM(CASE WHEN bettype IN (21008, 21009) THEN 0 ELSE CASE		
																			WHEN b.Recommend = -4 THEN winlost - actual_stake + playercomm
																			WHEN b.custid = mrecommend THEN winlost-actual_stake ELSE  mwinlost+acomm-comm END END), 0) AS balance,
			
			ISNULL(SUM(CASE WHEN bettype IN (21008, 21009) THEN 0 ELSE CASE		
																			WHEN b.Recommend = -4 THEN winlost - actual_stake + playercomm
																			WHEN b.custid = mrecommend THEN winlost-actual_stake ELSE  mwinlost+acomm-comm END END), 0) AS yesterdaybalance,


			/* -- code MAX
			ISNULL(SUM(CASE WHEN bettype IN (21008, 21009) OR b.Recommend = -4 THEN 0 ELSE mwinlost+acomm-comm END), 0)
					+ ISNULL(SUM(CASE WHEN bettype IN (21008, 21009) THEN 0 ELSE winlost-actual_stake+playercomm END), 0),

			ISNULL(SUM(CASE WHEN bettype IN (21008, 21009) OR b.Recommend = -4 THEN 0 ELSE mwinlost+acomm-comm END), 0)
					+ ISNULL(SUM(CASE WHEN bettype IN (21008, 21009) THEN 0 ELSE winlost-actual_stake+playercomm END), 0),
			*/
			ISNULL(SUM(CASE WHEN bettype IN (21008, 21009) THEN -(winlost-actual_stake) ELSE 0 END), 0)
		FROM  #DirectMemberList r
			INNER JOIN dbo.Transfer b WITH(NOLOCK, INDEX = IX_CustId) ON b.CustId = r.CustId
		WHERE  1 = CASE WHEN bettype = 19999 AND winlostdate > @moveBetsDay THEN 0 --> new sum
					WHEN bettype = 20000 AND winlostdate > @balanceUpDay THEN 0 --> new bal
					WHEN winlostdate < @balanceUpDay THEN 0 --> old data
				ELSE 1 END
		GROUP BY CASE WHEN b.recommend = -3 THEN b.mrecommend ELSE r.custid END
	END
	
	INSERT INTO #balance(custid, outstanding, balance, yesterdaybalance, PendingTransfer3rd)
	SELECT mrecommend AS custid,
		ISNULL(SUM(ABS(actual_stake) * mpositiontaking), 0) AS outstanding,
		0 balance,
		0 yesterdaybalance,
		0 AS PendingTransfer3rd
	FROM #recommend r
		INNER JOIN dbo.translog t WITH(NOLOCK, index = IX_recommend) ON t.recommend = r.CustId
	WHERE statusid IN (0,1)
	GROUP BY mrecommend

	IF @IsExistDirect = 1
	BEGIN
		INSERT INTO #balance(custid, outstanding, balance, yesterdaybalance, PendingTransfer3rd)
		SELECT CASE WHEN t.recommend = -3 THEN t.mrecommend ELSE r.custid END AS mrecommend,
			ISNULL(SUM(CASE WHEN t.recommend = -3 THEN ABS(actual_stake) * mpositiontaking ELSE ABS(actual_stake) END),0) AS outstanding,
			0 balance,
			0 yesterdaybalance,
			0 AS PendingTransfer3rd
		FROM #DirectMemberList r
			INNER JOIN  dbo.translog t WITH(NOLOCK,index = IX_custid ) ON t.custid = r.CustId
		WHERE statusid IN (0,1)
		GROUP BY CASE WHEN t.recommend = -3 THEN t.mrecommend ELSE r.custid END

	END

	INSERT INTO #balance(custid, outstanding, balance, yesterdaybalance, PendingTransfer3rd)
	SELECT
		mrecommend AS custid,
		ISNULL(SUM(CASE WHEN statusID IN (0, 1) THEN ABS(actual_stake) * mpositiontaking ELSE  0 END),0) outstanding,
		ISNULL(SUM(CASE WHEN statusID > 1 THEN mwinlost+acomm-comm ELSE  0 END),0) AS balance,
		ISNULL(SUM(CASE WHEN statusID > 1 AND winlostdate = @yesterday THEN mwinlost+acomm-comm ELSE  0 END),0) AS yesterdaybalance,
		0 AS PendingTransfer3rd
	FROM  #recommend r
		INNER JOIN dbo.bettransRnG b WITH(NOLOCK, index = IX_recommend) ON b.recommend = r.CustId
	WHERE (
				statusID IN (0, 1)
				OR winlostdate >= @yesterday
			)
	GROUP BY mrecommend

	IF @IsExistDirect = 1
	BEGIN
		INSERT INTO #balance(custid, outstanding, balance, yesterdaybalance, PendingTransfer3rd)
		SELECT CASE WHEN b.recommend = -3 THEN b.mrecommend ELSE r.custid END AS mrecommend,
			ISNULL(SUM(CASE WHEN statusID IN (0, 1) THEN CASE WHEN b.recommend = -3 THEN ABS(actual_stake) * mpositiontaking ELSE ABS(actual_stake) END ELSE 0 END),0) AS outstanding,

			--Helen 
			ISNULL(SUM(CASE WHEN statusID > 1 AND b.recommend = -3 THEN mwinlost+acomm-comm 
							WHEN statusID > 1 AND b.recommend = -4 THEN winlost-actual_stake+playercomm	ELSE  0 END),0) AS balance,
				
			ISNULL(SUM(CASE WHEN statusID > 1 AND b.recommend = -3 AND  winlostdate = @yesterday THEN mwinlost+acomm-comm 
							WHEN statusID > 1 AND b.recommend = -4 AND  winlostdate = @yesterday THEN winlost-actual_stake+playercomm ELSE 0 END),0) AS yesterdaybalance,
			/* -- code MAX
			ISNULL(SUM(CASE WHEN statusID > 1 THEN mwinlost+acomm-comm ELSE  0 END),0) 
				+ ISNULL(SUM(CASE WHEN statusID IN (111, 112, 113) THEN winlost-actual_stake+playercomm ELSE 0 END), 0)AS balance,
			
			ISNULL(SUM(CASE WHEN statusID > 1 AND winlostdate = @yesterday THEN mwinlost+acomm-comm ELSE  0 END),0) 
				+ ISNULL(SUM(CASE WHEN winlostdate = @yesterday AND statusID IN (111, 112, 113) THEN winlost-actual_stake+playercomm ELSE 0 END), 0) AS yesterdaybalance,
			*/
			0 AS PendingTransfer3rd
		FROM  #DirectMemberList r
			inner join dbo.bettransRnG b WITH(NOLOCK, index = IX_custid ) ON r.custid = b.custid
		WHERE (
					statusID IN (0, 1)
					OR winlostdate >= @yesterday
				)
		GROUP BY CASE WHEN b.recommend = -3 THEN b.mrecommend ELSE r.custid END
	END

	INSERT INTO #balance(custid, outstanding, balance, yesterdaybalance, PendingTransfer3rd)
	SELECT
		mrecommend AS custid,
		ISNULL(SUM(CASE WHEN statusID IN (0, 1) THEN ABS(actual_stake) * mpositiontaking ELSE  0 END),0) outstanding,
		ISNULL(SUM(CASE WHEN statusID > 1 THEN mwinlost+acomm-comm ELSE  0 END),0) AS balance,
		ISNULL(SUM(CASE WHEN statusID > 1 AND winlostdate = @yesterday THEN mwinlost+acomm-comm ELSE 0 END),0) AS yesterdaybalance,
		0 AS PendingTransfer3rd
	FROM  #recommend r
		INNER JOIN dbo.bettransLC b WITH(NOLOCK, index = IX_recommend) ON b.recommend = r.CustId
	WHERE (
				statusID IN (0, 1)
				OR winlostdate >= @yesterday
			)
	GROUP BY mrecommend

	IF @IsExistDirect = 1
	BEGIN
		INSERT INTO #balance(custid, outstanding, balance, yesterdaybalance, PendingTransfer3rd)
		SELECT CASE WHEN b.recommend = -3 THEN b.mrecommend ELSE r.custid END AS mrecommend,
			ISNULL(SUM(CASE WHEN statusID IN (0, 1) THEN CASE WHEN b.recommend = -3 THEN ABS(actual_stake) * mpositiontaking ELSE ABS(actual_stake) END ELSE 0 END),0) AS outstanding,

			--Helen 
			ISNULL(SUM(CASE WHEN statusID > 1 AND b.recommend = -3 THEN mwinlost+acomm-comm 
							WHEN statusID > 1 AND b.recommend = -4 THEN winlost-actual_stake+playercomm	ELSE  0 END),0) AS balance,
				
			ISNULL(SUM(CASE WHEN statusID > 1 AND b.recommend = -3 AND  winlostdate = @yesterday THEN mwinlost+acomm-comm 
							WHEN statusID > 1 AND b.recommend = -4 AND  winlostdate = @yesterday THEN winlost-actual_stake+playercomm ELSE 0 END),0) AS yesterdaybalance,
			/* -- code MAX
			ISNULL(SUM(CASE WHEN statusID > 1 THEN mwinlost+acomm-comm ELSE  0 END),0) 
				+ ISNULL(SUM(CASE WHEN statusID IN (111, 112, 113) THEN winlost-actual_stake+playercomm ELSE 0 END), 0)AS balance,
			
			ISNULL(SUM(CASE WHEN statusID > 1 AND winlostdate = @yesterday THEN mwinlost+acomm-comm ELSE  0 END),0) 
				+ ISNULL(SUM(CASE WHEN winlostdate = @yesterday AND statusID IN (111, 112, 113) THEN winlost-actual_stake+playercomm ELSE 0 END), 0) AS yesterdaybalance,
			*/
			0 AS PendingTransfer3rd
		FROM  #DirectMemberList r
			inner join dbo.bettransLC b WITH(NOLOCK, index = IX_custid ) ON r.custid = b.custid
		WHERE (
					statusID IN (0, 1)
					OR winlostdate >= @yesterday
				)
		GROUP BY CASE WHEN b.recommend = -3 THEN b.mrecommend ELSE r.custid END
	END

	INSERT INTO #result_balance(custid, outstanding, balance, yesterdaybalance, PendingTransfer3rd)
	SELECT custid, SUM(outstanding), SUM(balance), SUM(yesterdaybalance), SUM(ISNULL(PendingTransfer3rd, 0))
	FROM #balance
	GROUP BY custid

	--Calc total pages
	IF @TotalItems = 0
	BEGIN
		SELECT @TotalItems = count(1)
		FROM #tmp_customer
	END

	SELECT * FROM 
	(
		SELECT ROW_NUMBER() OVER (ORDER BY c.enabled desc, c.closed, c.suspended, c.username) AS RowNumber,
			c.username,c.enabled,
			isnull(c.iplogin, '')as iplogin, 
			c.custid, 
			c.closed,
			c.suspended,
			c.firstname, 
			c.lastname, 
			isnull(balance.outstanding,0) AS outstanding, 
			isnull(balance.balance,0) AS balance,
			isnull(balance.yesterdaybalance,0) yesterday_balance,
			
			CASE 
				 WHEN c.IsDirectMember = 0 THEN	isnull(c.credit,0) - isnull(c.usedCredit,0) 
				 WHEN c.IsDirectMember = 1 THEN ISNULL(balance.balance, 0) + isnull(c.credit, 0) - isnull(balance.outstanding, 0) -ISNULL(balance.PendingTransfer3rd,0) 
			END AS betCredit,
			isnull(c.credit,0) credit,		
			CONVERT(nvarchar(30), c.lastlogged, 121) AS lastlogged,
			c.Locked,
			c.CreatedDate,
			ISNULL(balance.PendingTransfer3rd,0) PendingTransfer3rd,
			c.IsDirectMember
		FROM #tmp_customer c 
			LEFT JOIN #result_balance AS balance ON c.custid = balance.custid 
	)a
	WHERE a.RowNumber BETWEEN @RowStart AND @RowEND

	drop table #balance
	drop table #tmp_customer
	DROP TABLE #SportBettype
	DROP TABLE #DirectMemberList
	DROP TABLE #recommend
	DROP TABLE #result_balance
END
GO


