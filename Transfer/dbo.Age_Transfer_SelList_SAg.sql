/*<info serverAlias="DBTXN-bodb02" executers="bodbDownlineNet,bodbDownlineNetView" isFunction="0" isNested="0"></info>*/
CREATE PROCEDURE [dbo].[Age_Transfer_SelList_SAg]
	@SAgID int,
	@PageSize int=500,
	@PageIndex int=1,
	@Username varchar(30)=null,
	@Enabled bit = null,
	@Closed bit=null,
	@Suspended bit=null,
	@IsYesterdayBalance bit = null,
	@IsAllowTotalBalance bit = null,
	@TotalOutStanding money = 0 OUTPUT,
	@TotalCredit money = 0 OUTPUT,
	@TotalUsedCredit money = 0 OUTPUT,
	@TotalMagentBalance money = 0 OUTPUT,
	@TotalYesterdayMagentBalance money = 0 OUTPUT,
	@TotalMAgentCashBalance money = 0 OUTPUT,
	@TotalYesterday_MAgentCashBalance money = 0 OUTPUT,
	@TotalPages int=0 OUTPUT
AS

--Vinh@20080102: add yesterday balance columns
/*
Task : Credit/Balance of SAgent
DB: DBTXN/bodb02
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
	- 20190305@Helen: Move SP to DBTRANS - Enhance Transfer function to avoid replication delay [RedmineID : #107963]

Param's Explanation:
• @CustID: SAgentID
• @IsAllowTotalBalance: filter data based on total balance transfer
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

	CREATE TABLE #tmp_customer
	(
		[custid] int primary key,
		[enabled] bit,
		[username] varchar(30),
		[closed] bit,
		[suspended] bit,
		[firstname] nvarchar(50) null,
		[lastname] nvarchar(50) null,
	)

	CREATE TABLE #balance  
	(
		mrecommend int,
		YesterdayCashBalance money,		
		TotalCashBalance money,
		YesterdayBalance money,		
		TotalBalance money,
		Outstanding money
	)

	CREATE TABLE #result_balance  
	(
		mrecommend int,
		YesterdayCashBalance money,		
		TotalCashBalance money,
		YesterdayBalance money,		
		TotalBalance money,
		Outstanding money
	)

	CREATE TABLE #credit
	(
		mrecommend int primary key,
		magentCredit money,		
		magentUsedCredit money
	)

	INSERT INTO #credit
	SELECT 
		c.mrecommend,
		isnull(SUM(CASE WHEN roleid = 3 THEN credit ELSE 0 END), 0) AS magentCredit,
		isnull(SUM(CASE WHEN roleid = 1 THEN credit ELSE 0 END), 0) AS magentUsedCredit
	FROM CUSTDB.dbo.custinfo as c (nolock)
	WHERE srecommend = @SAgID AND roleid IN (1,2,3)
	GROUP BY c.mrecommend
	
	DECLARE @n INT 
	DECLARE @recommend AS TABLE (recommend INT,mrecommend INT)

	INSERT INTO @recommend (recommend,mrecommend)
	SELECT custid,mrecommend 
	FROM CUSTDB.dbo.custInfo WITH(NOLOCK) 
	WHERE srecommend = @SAgID AND roleid = 2

	SET @n = @@ROWCOUNT
	
	-- bettransRnG
	INSERT INTO #balance (mrecommend, YesterdayCashBalance, TotalCashBalance, YesterdayBalance, TotalBalance, Outstanding)
	SELECT
		mrecommend,
		ISNULL(SUM(YesterdayCashBalance), 0),
		ISNULL(SUM(TotalCashBalance), 0),
		ISNULL(SUM(YesterdayBalance), 0),
		ISNULL(SUM(TotalBalance), 0),
		ISNULL(SUM(Outstanding), 0)
	FROM (SELECT TOP (@n) * FROM @recommend )as  r
		CROSS APPLY (SELECT
						ISNULL(SUM(CASE WHEN winlostdate = @yesterday AND statusID NOT IN (0, 1) THEN mwinlost+acomm-comm ELSE 0 END), 0) AS YesterdayCashBalance,
						ISNULL(SUM(CASE WHEN statusID NOT IN (0, 1) THEN mwinlost+acomm-comm ELSE 0 END), 0) AS TotalCashBalance,
						ISNULL(SUM(CASE WHEN winlostdate = @yesterday AND statusID NOT IN (0, 1) THEN mwinlost+acomm-comm ELSE 0 END), 0)
							+ ISNULL(SUM(CASE WHEN winlostdate = @yesterday AND statusID NOT IN (0, 1) THEN awinlost+comm-playercomm ELSE 0 END), 0)
							+ ISNULL(SUM(CASE WHEN winlostdate = @yesterday AND statusID NOT IN (0, 1) THEN winlost-actual_stake+playercomm ELSE 0 END), 0) AS YesterdayBalance,
							
						ISNULL(SUM(CASE WHEN statusID NOT IN (0, 1) THEN mwinlost+acomm-comm ELSE 0 END), 0)
							+ ISNULL(SUM(CASE WHEN statusID NOT IN (0, 1) THEN awinlost+comm-playercomm ELSE 0 END), 0)
							+ ISNULL(SUM(CASE WHEN statusID NOT IN (0, 1) THEN winlost-actual_stake+playercomm ELSE 0 END), 0) AS TotalBalance,
						ISNULL(SUM(CASE WHEN statusID IN (0, 1) THEN ABS(actual_stake*mpositiontaking) ELSE 0 END), 0) AS Outstanding
					FROM dbo.bettransRnG b WITH(NOLOCK)
					WHERE r.recommend = b.recommend
						AND (
							statusID IN (0, 1)
							OR winlostdate >= @yesterday
						)
					GROUP BY b.recommend) AS tmp
	
	GROUP BY r.mrecommend
	OPTION (OPTIMIZE FOR (@n=0))
	-- bettransLC
	INSERT INTO #balance (mrecommend, YesterdayCashBalance, TotalCashBalance, YesterdayBalance, TotalBalance, Outstanding)
	SELECT
		mrecommend,
		ISNULL(SUM(YesterdayCashBalance), 0),
		ISNULL(SUM(TotalCashBalance), 0),
		ISNULL(SUM(YesterdayBalance), 0),
		ISNULL(SUM(TotalBalance), 0),
		ISNULL(SUM(Outstanding), 0)
	FROM (SELECT TOP (@n) * FROM @recommend )as  r
		CROSS APPLY (SELECT
						--YesterdayCashBalance, TotalCashBalance, YesterdayBalance, TotalBalance, Outstanding
						ISNULL(SUM(CASE WHEN winlostdate = @yesterday AND statusID NOT IN (0, 1) THEN mwinlost+acomm-comm ELSE 0 END), 0) AS YesterdayCashBalance,
						ISNULL(SUM(CASE WHEN statusID NOT IN (0, 1) THEN mwinlost+acomm-comm ELSE 0 END), 0) AS TotalCashBalance,
						ISNULL(SUM(CASE WHEN winlostdate = @yesterday AND statusID NOT IN (0, 1) THEN mwinlost+acomm-comm ELSE 0 END), 0)
							+ ISNULL(SUM(CASE WHEN winlostdate = @yesterday AND statusID NOT IN (0, 1) THEN awinlost+comm-playercomm ELSE 0 END), 0)
							+ ISNULL(SUM(CASE WHEN winlostdate = @yesterday AND statusID NOT IN (0, 1) THEN winlost-actual_stake+playercomm ELSE 0 END), 0) AS YesterdayBalance,
						ISNULL(SUM(CASE WHEN statusID NOT IN (0, 1) THEN mwinlost+acomm-comm ELSE 0 END), 0)
							+ ISNULL(SUM(CASE WHEN statusID NOT IN (0, 1) THEN awinlost+comm-playercomm ELSE 0 END), 0)
							+ ISNULL(SUM(CASE WHEN statusID NOT IN (0, 1) THEN winlost-actual_stake+playercomm ELSE 0 END), 0) TotalBalance,
						ISNULL(SUM(CASE WHEN statusID IN (0, 1) THEN ABS(actual_stake*mpositiontaking) ELSE 0 END), 0) AS Outstanding
						FROM dbo.bettransLC b WITH(NOLOCK)
						WHERE r.recommend = b.recommend
							AND (
								statusID IN (0, 1)
								OR winlostdate >= @yesterday
							)
						GROUP BY b.recommend	) AS tmp
	GROUP BY mrecommend
	OPTION (OPTIMIZE FOR (@n=0))
	-- translog
	INSERT INTO #balance (mrecommend, YesterdayCashBalance, TotalCashBalance, YesterdayBalance, TotalBalance, Outstanding)
	SELECT
		r.mrecommend,
		0,
		0,
		0,
		0,
		ISNULL(SUM(Outstanding), 0)
	FROM (SELECT TOP (@n) * FROM @recommend )as  r
		CROSS APPLY (SELECT ISNULL(SUM(CASE WHEN t.statusID IN (0, 1) THEN ABS(actual_stake*mpositiontaking) ELSE 0 END), 0) AS Outstanding
					FROM dbo.translog t WITH(NOLOCK)
					WHERE t.recommend = r.recommend --AND t.statusID IN (0, 1) 
					GROUP BY t.recommend
					) AS tmp
	GROUP BY r.mrecommend
	OPTION (OPTIMIZE FOR (@n=0))
	-- bettrans
	-- running ticket
	INSERT INTO #balance (mrecommend, YesterdayCashBalance, TotalCashBalance, YesterdayBalance, TotalBalance, Outstanding)
	SELECT
		r.mrecommend,0,	0,0,0,
		ISNULL(SUM(tmp.OutStanding), 0)
	FROM (SELECT TOP (@n) * FROM @recommend )as  r
		CROSS APPLY (SELECT SUM(ABS(actual_stake*mpositiontaking)) AS OutStanding
					FROM bettrans b WITH (NOLOCK) 
					WHERE b.recommend = r.recommend
						AND NOT EXISTS (SELECT TOP 1 1 FROM #SportBettype s WHERE b.bettype = s.bettype AND s.RefTable <> 0)
						AND ruben = 0
					GROUP BY b.recommend) AS tmp
	GROUP BY r.mrecommend
	OPTION (OPTIMIZE FOR (@n=0))
	-- settle ticket
	INSERT INTO #balance (mrecommend, YesterdayCashBalance, TotalCashBalance, YesterdayBalance, TotalBalance, Outstanding)
	SELECT
		r.mrecommend,
		ISNULL(SUM(YesterdayCashBalance), 0) AS YesterdayCashBalance,
		ISNULL(SUM(TotalCashBalance), 0) AS TotalCashBalance,
		ISNULL(SUM(YesterdayBalance), 0) AS YesterdayBalance,
		ISNULL(SUM(TotalBalance), 0) AS TotalBalance,
		0 Outstanding
	FROM (SELECT TOP (@n) * FROM @recommend )as  r
		CROSS APPLY (
						SELECT
							ISNULL(SUM(mwinlost+acomm-comm ), 0) AS YesterdayCashBalance,
							ISNULL(SUM(mwinlost+acomm-comm) , 0) AS TotalCashBalance,
							ISNULL(SUM(mwinlost+acomm-comm ), 0)
								+ ISNULL(SUM(CASE WHEN custid = b.recommend THEN winlost-actual_stake ELSE awinlost+comm-playercomm END), 0)
								+ ISNULL(SUM(CASE WHEN custid <> b.recommend THEN winlost-actual_stake+playercomm ELSE 0 END), 0) YesterdayBalance,

							ISNULL(SUM(mwinlost+acomm-comm), 0)
								+ ISNULL(SUM(CASE WHEN custid = b.recommend THEN winlost-actual_stake ELSE awinlost+comm-playercomm END), 0)
								+ ISNULL(SUM(CASE WHEN custid <> b.recommend THEN winlost-actual_stake+playercomm ELSE 0 END), 0) AS TotalBalance
						FROM dbo.bettrans b WITH(NOLOCK)
						WHERE  r.recommend = b.recommend
								AND ruben = 1
								AND winlostdate < @yesterday	
						GROUP BY b.recommend	) AS tmp
	
	GROUP BY r.mrecommend
	OPTION (OPTIMIZE FOR (@n=0))
	
	INSERT INTO #balance (mrecommend, YesterdayCashBalance, TotalCashBalance, YesterdayBalance, TotalBalance, Outstanding)
	SELECT
		mrecommend,
		ISNULL(SUM(YesterdayCashBalance), 0),
		ISNULL(SUM(TotalCashBalance), 0),
		ISNULL(SUM(YesterdayBalance), 0),
		ISNULL(SUM(TotalBalance), 0),
		0
	FROM (SELECT TOP (@n) * FROM @recommend )as  r
		CROSS APPLY (SELECT
						ISNULL(SUM(CASE WHEN winlostdate = @yesterday OR bettype > 20000 THEN mwinlost+acomm-comm ELSE 0 END), 0) AS YesterdayCashBalance,
						ISNULL(SUM(mwinlost+acomm-comm), 0) TotalCashBalance,
						ISNULL(SUM(CASE WHEN winlostdate = @yesterday OR bettype > 20000 THEN mwinlost+acomm-comm ELSE 0 END), 0)
							+ ISNULL(SUM(CASE WHEN winlostdate = @yesterday OR bettype > 20000 THEN CASE WHEN custid = recommend THEN winlost-actual_stake ELSE awinlost+comm-playercomm END ELSE 0 END), 0)
							+ ISNULL(SUM(CASE WHEN winlostdate = @yesterday OR bettype > 20000 THEN CASE WHEN custid <> recommend THEN winlost-actual_stake+playercomm ELSE 0 END ELSE 0 END), 0) AS YesterdayBalance,
						ISNULL(SUM(mwinlost+acomm-comm), 0)
							+ ISNULL(SUM(CASE WHEN custid = recommend THEN winlost-actual_stake ELSE awinlost+comm-playercomm END), 0)
							+ ISNULL(SUM(CASE WHEN custid <> recommend THEN winlost-actual_stake+playercomm ELSE 0 END), 0) AS TotalBalance
						
					FROM dbo.bettrans b WITH(NOLOCK)
					WHERE r.recommend = b.recommend
						AND ruben = 1
						AND winlostdate >= @yesterday
						AND NOT EXISTS (SELECT 1 FROM #SportBettype s WHERE b.bettype = s.bettype AND s.RefTable IN (1,2))
					GROUP BY recommend) AS tmp
	GROUP BY r.mrecommend
	OPTION (OPTIMIZE FOR (@n=0))
	
		-- sum, balance, transfer ticket
	INSERT INTO #balance (mrecommend, YesterdayCashBalance, TotalCashBalance, YesterdayBalance, TotalBalance, Outstanding)
	SELECT
		r.mrecommend,
		ISNULL(SUM(YesterdayCashBalance), 0),
		ISNULL(SUM(TotalCashBalance), 0),
		ISNULL(SUM(YesterdayBalance), 0),
		ISNULL(SUM(TotalBalance), 0),
		0
	FROM #credit r
		CROSS APPLY (SELECT
						ISNULL(SUM(winlost-actual_stake), 0) YesterdayCashBalance,
						ISNULL(SUM(winlost-actual_stake), 0) TotalCashBalance,
						ISNULL(SUM(winlost-actual_stake), 0) YesterdayBalance,
						ISNULL(SUM(winlost-actual_stake), 0) TotalBalance	
					FROM dbo.bettrans b WITH(NOLOCK)
					WHERE r.mrecommend = b.custid
						AND bettype >= 19999
						AND matchid = 0
					GROUP BY b.recommend
					) AS tmp
	
	GROUP BY r.mrecommend
	
	
	/* End Balance Info */
	INSERT INTO #result_balance (mrecommend, YesterdayCashBalance, TotalCashBalance, YesterdayBalance, TotalBalance, Outstanding)
	SELECT mrecommend, SUM(YesterdayCashBalance), SUM(TotalCashBalance), SUM(YesterdayBalance), SUM(TotalBalance), SUM(Outstanding)
	FROM #balance
	GROUP BY mrecommend
	
	SET @Username = isnull(@Username, '')
	--Filter user
	IF @Username = ''
		
		INSERT INTO #tmp_customer ([custid],[enabled],[username],[closed],[suspended],[firstname],[lastname])
		SELECT 
			c.custid, ci.enabled, c.username, ci.closed, isnull(ci.reject,0) as suspended, c.firstname, c.lastname
		FROM CUSTDB.dbo.CustInfo ci WITH (NOLOCK) 
			INNER JOIN CUSTDB.dbo.Customer c WITH (NOLOCK) ON ci.custid = c.custid 
			INNER JOIN #credit cd ON cd.mrecommend = ci.custid
		WHERE enabled = case when coalesce(@Closed,@Suspended) is not null then 1 else coalesce(@enabled, enabled) end
			AND isnull(closed,0) = CASE WHEN @Suspended = 1 THEN 0 ELSE coalesce(@closed, isnull(closed, 0)) END
			AND isnull(reject,0) = CASE WHEN @Closed = 0 THEN 0 ELSE coalesce(@Suspended, isnull(reject, 0)) END
	ELSE
		INSERT INTO #tmp_customer ([custid],[enabled],[username],[closed],[suspended],[firstname],[lastname])
		SELECT 
			c.custid, ci.enabled, c.username, ci.closed, isnull(ci.reject,0) as suspended, c.firstname, c.lastname
		FROM CUSTDB.dbo.CustInfo ci WITH (NOLOCK) 
			INNER JOIN CUSTDB.dbo.Customer c WITH (NOLOCK) ON ci.custid = c.custid 
			INNER JOIN #credit cd ON cd.mrecommend = ci.custid
		WHERE c.username like '%' + @Username + '%'  
			AND enabled = case when coalesce(@Closed,@Suspended) is not null then 1 else coalesce(@enabled, enabled) end
			AND isnull(closed,0) = case when @Suspended = 1 then 0 else coalesce(@closed, isnull(closed, 0)) end
			AND isnull(reject,0) = case when @Closed = 0 then 0 else coalesce(@Suspended, isnull(reject, 0))end

	--Calc total pages
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
			FROM #tmp_customer c
				LEFT JOIN #result_balance balance ON c.custid = balance.mrecommend
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
											WHERE c.roleid = 3 AND c.srecommend = ' + CONVERT(VARCHAR(30), @SAgID) + ''')'
	INSERT INTO #ClosedReason (custid, ClosedReason)
	EXEC (@SQL)

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
				IsNull(credit.magentCredit, 0) AS magentCredit, 
				credit.magentUsedCredit, 
				IsNull(balance.Outstanding,0) magentOutstanding, 
				IsNull(balance.TotalCashBalance,0) magentCashBalance, 
				IsNull(balance.TotalBalance,0) magentBalance, 
				IsNull(balance.YesterdayCashBalance,0) yesterday_magentCashBalance, 
				IsNull(balance.YesterdayBalance,0) yesterday_magentBalance, 
				c.firstname, 
				c.lastname
			FROM #tmp_customer c
				INNER JOIN #credit credit ON c.custid = credit.mrecommend
				LEFT JOIN #result_balance balance ON c.custid = balance.mrecommend
				LEFT JOIN #ClosedReason cr ON c.custid = cr.custid
		)a 
		WHERE a.RowNumber BETWEEN @RowStart AND @RowEND
		--Total
		SELECT @TotalOutStanding = sum(magentOutstanding),
				@TotalCredit = sum(magentCredit),
				@TotalUsedCredit = sum(magentUsedCredit),
				@TotalMAgentBalance = sum(magentBalance),
				@TotalYesterdayMAgentBalance = sum(yesterday_magentBalance),
				@TotalMAgentCashBalance = sum(magentCashBalance),
				@TotalYesterday_MAgentCashBalance = sum(yesterday_magentCashBalance)
		FROM 
		(
			SELECT ROW_NUMBER() OVER (ORDER BY enabled desc, closed, suspended, c.username) as RowNumber,
				c.username, 
				c.custid,
				c.closed,
				c.enabled,
				c.suspended,
				IsNull(credit.magentCredit, 0) AS magentCredit, 
				credit.magentUsedCredit, 
				IsNull(balance.Outstanding,0) magentOutstanding, 
				IsNull(balance.TotalCashBalance,0) magentCashBalance, 
				IsNull(balance.TotalBalance,0) magentBalance, 
				IsNull(balance.YesterdayCashBalance,0) yesterday_magentCashBalance, 
				IsNull(balance.YesterdayBalance,0) yesterday_magentBalance
			FROM #tmp_customer c
				INNER JOIN #credit credit ON c.custid = credit.mrecommend
				LEFT JOIN #result_balance balance ON c.custid = balance.mrecommend
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
				IsNull(credit.magentCredit, 0) AS magentCredit, 
				credit.magentUsedCredit, 
				IsNull(balance.Outstanding,0) magentOutstanding, 
				IsNull(balance.TotalCashBalance,0) magentCashBalance, 
				IsNull(balance.TotalBalance,0) magentBalance, 
				IsNull(balance.YesterdayCashBalance,0) yesterday_magentCashBalance, 
				IsNull(balance.YesterdayBalance,0) yesterday_magentBalance,
				c.firstname, 
				c.lastname
			FROM #tmp_customer c
				INNER JOIN #credit credit ON c.custid = credit.mrecommend
				LEFT JOIN #result_balance balance ON c.custid = balance.mrecommend
				LEFT JOIN #ClosedReason cr ON c.custid = cr.custid
			WHERE
				CASE 
					WHEN @IsAllowTotalBalance = 0 THEN ISNULL(balance.YesterdayBalance, 0)
					WHEN @IsAllowTotalBalance = 1 THEN ISNULL(balance.TotalBalance, 0)
				END <> 0
		)a 
		WHERE a.RowNumber BETWEEN @RowStart AND @RowEND
			--Total
			SELECT @TotalOutStanding = sum(magentOutstanding),
					@TotalCredit = sum(magentCredit),
					@TotalUsedCredit = sum(magentUsedCredit),
					@TotalMAgentBalance = sum(magentBalance),
					@TotalYesterdayMAgentBalance = sum(yesterday_magentBalance),
					@TotalMAgentCashBalance = sum(magentCashBalance),
					@TotalYesterday_MAgentCashBalance = sum(yesterday_magentCashBalance)
			FROM 
			(
				SELECT ROW_NUMBER() OVER (ORDER BY enabled desc, closed, suspended, c.username) as RowNumber,
					c.username, 
					c.custid,
					c.enabled,
					c.closed,
					c.suspended,
					IsNull(credit.magentCredit, 0) AS magentCredit, 
					credit.magentUsedCredit, 
					IsNull(balance.Outstanding,0) magentOutstanding, 
					IsNull(balance.TotalCashBalance,0) magentCashBalance, 
					IsNull(balance.TotalBalance,0) magentBalance, 
					IsNull(balance.YesterdayCashBalance,0) yesterday_magentCashBalance, 
					IsNull(balance.YesterdayBalance,0) yesterday_magentBalance
				FROM #tmp_customer c
					INNER JOIN #credit credit ON c.custid = credit.mrecommend
					LEFT JOIN #result_balance balance ON c.custid = balance.mrecommend
				WHERE
					CASE 
						WHEN @IsAllowTotalBalance = 0 THEN ISNULL(balance.YesterdayBalance, 0)
						WHEN @IsAllowTotalBalance = 1 THEN ISNULL(balance.TotalBalance, 0)
					END <> 0
			)a 
			WHERE a.RowNumber <= @RowEND
	END

	DROP TABLE #balance
	DROP TABLE #result_balance
	DROP TABLE #credit
	DROP TABLE #tmp_customer
	DROP TABLE #SportBettype
	DROP TABLE #ClosedReason
	
END

GO

