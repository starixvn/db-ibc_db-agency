/*<info serverAlias="DBAGE-bodb02" executers="bodbDownlineNet,bodbDownlineNetView" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [Age_Transfer_SelList_MAg]
	@masterid int,
	@PageSize int=500,
	@PageIndex int=1,
	@Username nvarchar(50)=null,
	@CustStatus varchar(50)='Open' ,
	@IsYesterdayBalance bit = null,
	@IsAllowTotalBalance bit = null,
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

Param's Explanation:
• @CustID: MAgentID
• @IsAllowTotalBalance: filter data based on total balance transfer
*/

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
	Locked TINYINT
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

CREATE TABLE #credit
(
	recommend int primary key,
	agentCredit money,
	agentUsedCredit money
)

-- get move bet date
DECLARE @balanceUpDay SMALLDATETIME, @moveBetsDay SMALLDATETIME
DECLARE @tblMoveBetBalanceUp AS TABLE (BalanceUpDay SMALLDATETIME, MoveBetsDay SMALLDATETIME)

INSERT INTO @tblMoveBetBalanceUp(BalanceUpDay,MoveBetsDay)
EXEC bodb02.dbo.Age_SelBalanceUpDay
	
SELECT @balanceUpDay = BalanceUpDay, @moveBetsDay = MoveBetsDay FROM @tblMoveBetBalanceUp

INSERT INTO #credit
SELECT c.recommend,
	isnull(SUM(CASE WHEN roleid = 2 THEN credit ELSE 0 END), 0) AS agentCredit,			
	isnull(SUM(CASE WHEN roleid = 1 THEN credit ELSE 0 END), 0) AS agentUsedCredit
FROM custinfo as c (nolock)
WHERE mrecommend = @masterid AND roleid < 3
GROUP BY c.recommend

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
FROM dbo.bettransRnG WITH(NOLOCK)
WHERE mrecommend = @masterid
	AND (
		statusID IN (0, 1)
		OR winlostdate >= @yesterday
	)
GROUP BY recommend

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
FROM dbo.bettransLC WITH(NOLOCK)
WHERE mrecommend = @masterid
	AND (
		statusID IN (0, 1)
		OR winlostdate >= @yesterday
	)
GROUP BY recommend

-- translog
INSERT INTO #balance (recommend, YesterdayCashBalance, TotalCashBalance, YesterdayBalance, TotalBalance, Outstanding)
SELECT
	recommend,
	0,
	0,
	0,
	0,
	ISNULL(SUM(ABS(actual_stake*apositiontaking)), 0)
FROM dbo.translog t WITH(NOLOCK)
WHERE mrecommend = @masterid
	AND statusID IN (0, 1)
GROUP BY recommend

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
FROM dbo.bettrans b WITH(NOLOCK)
WHERE b.mrecommend = @masterid
	AND ruben = 0
	AND NOT EXISTS (SELECT 1 FROM #SportBettype s WHERE b.bettype = s.bettype AND s.RefTable <> 0)
GROUP BY recommend

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
FROM dbo.bettrans b WITH(NOLOCK)
WHERE b.mrecommend = @masterid
	AND b.statusID IN (111, 112, 113)
	AND (
				b.winlostdate < @yesterday
				OR NOT EXISTS (SELECT TOP 1 1 FROM #SportBettype s WHERE s.Bettype = b.bettype AND s.RefTable IN (1, 2))
			)
	AND winlostdate > @moveBetsDay 
GROUP BY recommend

INSERT INTO #balance (recommend, YesterdayCashBalance, TotalCashBalance, YesterdayBalance, TotalBalance, Outstanding, PendingTransfer3rd)
SELECT
	Recommend,
	SUM(CASE WHEN bettype IN (21008, 21009) THEN 0 ELSE CASE WHEN custid = recommend THEN winlost-actual_stake ELSE awinlost+comm-playercomm END END),
	SUM(CASE WHEN bettype IN (21008, 21009) THEN 0 ELSE CASE WHEN custid = recommend THEN winlost-actual_stake ELSE awinlost+comm-playercomm END END),
	ISNULL(SUM(CASE WHEN bettype IN (21008, 21009) THEN 0 ELSE CASE WHEN custid = recommend THEN winlost-actual_stake ELSE awinlost+comm-playercomm END END), 0)
		+ ISNULL(SUM(CASE WHEN bettype IN (21008, 21009) THEN 0 ELSE CASE WHEN custid <> recommend AND custid <> mrecommend THEN winlost-actual_stake+playercomm ELSE 0 END END), 0),
	ISNULL(SUM(CASE WHEN bettype IN (21008, 21009) THEN 0 ELSE CASE WHEN custid = recommend THEN winlost-actual_stake ELSE awinlost+comm-playercomm END END), 0)
		+ ISNULL(SUM(CASE WHEN bettype IN (21008, 21009) THEN 0 ELSE CASE WHEN custid <> recommend AND custid <> mrecommend THEN winlost-actual_stake+playercomm ELSE 0 END END), 0),
	0,
	ISNULL(SUM(CASE WHEN bettype IN (21008, 21009) THEN -(winlost-actual_stake) ELSE 0 END), 0)
FROM dbo.Transfer b WITH(NOLOCK)
WHERE b.mrecommend = @masterid
	AND 1 = CASE WHEN bettype = 19999 AND winlostdate > @moveBetsDay THEN 0 --> new sum
				WHEN bettype = 20000 AND winlostdate > @balanceUpDay THEN 0 --> new bal
				WHEN winlostdate < @balanceUpDay THEN 0 --> old data
			ELSE 1 END
GROUP BY recommend
/* End Balance Info */

INSERT INTO #result_balance (recommend, YesterdayCashBalance, TotalCashBalance, YesterdayBalance, TotalBalance, Outstanding, PendingTransfer3rd)
SELECT recommend, SUM(YesterdayCashBalance), SUM(TotalCashBalance), SUM(YesterdayBalance), SUM(TotalBalance), SUM(Outstanding), SUM(ISNULL(PendingTransfer3rd, 0))
FROM #balance
GROUP BY recommend

SET @Username = isnull(@Username, '')

--Filter user
IF @Username = ''
	INSERT INTO #tmp_customer
	(
		[custid],
		[enabled],
		[username],
		[closed],
		[suspended],
		[firstname],
		[lastname],
		Locked
	)
	SELECT 
		c.custid, ci.enabled, ci.username, cs.IsClosed, cs.IsSuspended, c.firstname, c.lastname, ISNULL(cs.Locked, 0)
	FROM CustInfo ci with (NOLOCK,index=IX_custinfo)  
		INNER JOIN Customer c (nolock) on ci.custid = c.custid 
		CROSS APPLY  
				(
					SELECT 
						CloseInfo
						, SuspendInfo
						, CASE WHEN CloseInfo > 0 THEN 1 ELSE 0 END AS IsClosed
						, CASE WHEN SuspendInfo > 0 THEN 1 ELSE 0 END AS IsSuspended
						, Locked
					FROM dbo.CustProductStatus cs WITH(NOLOCK)
					WHERE cs.CustID = ci.custid
				) AS cs	
	WHERE	ci.mrecommend=@masterid AND ci.roleid = 2 
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
ELSE
	INSERT INTO #tmp_customer
	(
		[custid],
		[enabled],
		[username],
		[closed],
		[suspended],
		[firstname],
		[lastname],
		Locked
	)
	SELECT 
		c.custid, ci.enabled, ci.username, cs.IsClosed, cs.IsSuspended, c.firstname, c.lastname, ISNULL(cs.Locked, 0)
	FROM CustInfo ci with (NOLOCK,index=IX_custinfo) 
		INNER JOIN Customer c (nolock) on ci.custid = c.custid 
		CROSS APPLY  
				(
					SELECT 
						CloseInfo
						, SuspendInfo
						, CASE WHEN CloseInfo > 0 THEN 1 ELSE 0 END AS IsClosed
						, CASE WHEN SuspendInfo > 0 THEN 1 ELSE 0 END AS IsSuspended
						, Locked
					FROM dbo.CustProductStatus cs WITH(NOLOCK)
					WHERE cs.CustID = ci.custid
				) AS cs	
	WHERE	ci.mrecommend=@masterid AND ci.roleid = 2  AND ci.username like '%' + @Username + '%'  
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
										WHERE c.roleid = 2 AND c.mrecommend = ' + CONVERT(VARCHAR(30), @masterid) + ''')'
INSERT INTO #ClosedReason (custid, ClosedReason)
EXEC (@SQL)

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
			IsNull(credit.agentCredit, 0) AS agentCredit,
			credit.agentUsedCredit,
			IsNull(balance.Outstanding,0) agentOutstanding,
			IsNull(balance.TotalCashBalance,0) agentCashBalance,
			IsNull(balance.TotalBalance,0) agentBalance,
			IsNull(balance.YesterdayCashBalance,0) yesterday_agentCashBalance,
			IsNull(balance.YesterdayBalance,0) yesterday_agentBalance,
			IsNull(balance.PendingTransfer3rd,0) PendingTransfer3rd,
			c.firstname, 
			c.lastname,
			c.Locked
		FROM 
			#tmp_customer c	
			INNER JOIN #credit credit ON c.custid = credit.recommend
			LEFT JOIN #result_balance balance ON c.custid = balance.recommend
			LEFT JOIN #ClosedReason cr ON c.custid = cr.custid
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
			IsNull(credit.agentCredit, 0) AS agentCredit, 
			credit.agentUsedCredit, 
			IsNull(balance.Outstanding,0) agentOutstanding,
			IsNull(balance.TotalCashBalance,0) agentCashBalance,
			IsNull(balance.TotalBalance,0) agentBalance,
			IsNull(balance.YesterdayCashBalance,0) yesterday_agentCashBalance,
			IsNull(balance.YesterdayBalance,0) yesterday_agentBalance,
			IsNull(balance.PendingTransfer3rd,0) PendingTransfer3rd
		FROM
			#tmp_customer c	
			INNER JOIN #credit credit ON c.custid = credit.recommend
			LEFT JOIN #result_balance balance ON c.custid = balance.recommend
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
			IsNull(credit.agentCredit, 0) AS agentCredit, 
			credit.agentUsedCredit, 
			IsNull(balance.Outstanding,0) agentOutstanding,
			IsNull(balance.TotalCashBalance,0) agentCashBalance,
			IsNull(balance.TotalBalance,0) agentBalance,
			IsNull(balance.YesterdayCashBalance,0) yesterday_agentCashBalance,
			IsNull(balance.YesterdayBalance,0) yesterday_agentBalance,
			IsNull(balance.PendingTransfer3rd,0) PendingTransfer3rd,
			c.firstname, 
			c.lastname,
			c.Locked
		FROM
			#tmp_customer c	
			INNER JOIN #credit credit ON c.custid = credit.recommend
			LEFT JOIN #result_balance balance ON c.custid = balance.recommend
			LEFT JOIN #ClosedReason cr ON c.custid = cr.custid
		WHERE
		    CASE 
		        WHEN @IsAllowTotalBalance = 0 THEN ISNULL(balance.YesterdayBalance, 0)
		        WHEN @IsAllowTotalBalance = 1 THEN ISNULL(balance.TotalBalance, 0)
		    END <> 0
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
			IsNull(credit.agentCredit, 0) AS agentCredit, 
			credit.agentUsedCredit, 
			IsNull(balance.Outstanding,0) agentOutstanding,
			IsNull(balance.TotalCashBalance,0) agentCashBalance,
			IsNull(balance.TotalBalance,0) agentBalance,
			IsNull(balance.YesterdayCashBalance,0) yesterday_agentCashBalance,
			IsNull(balance.YesterdayBalance,0) yesterday_agentBalance,
			IsNull(balance.PendingTransfer3rd,0) PendingTransfer3rd
		FROM
			#tmp_customer c	
			INNER JOIN #credit credit ON c.custid = credit.recommend
			LEFT JOIN #result_balance balance ON c.custid = balance.recommend
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
GO