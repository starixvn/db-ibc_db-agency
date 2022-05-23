/*<info serverAlias="DBAGE-bodb02" executers="bodbDownlineNet,bodbDownlineNetView" viewers="" isFunction="0" isNested="0"></info>*/  
CREATE PROCEDURE [dbo].[Age_CustomerSelBalanceList_Agent]  
 @CustID  INT,  --Master
 @PageSize INT = 0,
 @PageIndex INT = 0
AS  
/*  
	Created by Evan  
	Date: 2022-05-20
	Task : Balance Report  
	DB: DBAGE.bodb02  

	Revisions:  
		- 20220520@Evan: Create new [RedmineId: #167819]  
   
*/  
BEGIN
	SET NOCOUNT ON

	DECLARE @RowStart	INT,
			@RowEnd		INT;
		
	SELECT	@PageIndex = @PageIndex - 1,
			@RowStart = @PageSize * @PageIndex + 1,
			@RowEnd = @RowStart + @PageSize - 1;

	DECLARE @isTest BIT
	SELECT  @isTest = dbo.f_CheckSPVersion(@@PROCID)

	CREATE TABLE #SportBettype (bettype INT)
	INSERT INTO #SportBettype (bettype)
	SELECT bettype FROM dbo.f_SportBettypeMatrix_Sel (0, 0, 0, 2, '', '', @isTest)
	WHERE RefTable NOT IN (0, 3) -- exclude bettrans, translog

	DECLARE @today SMALLDATETIME,
			@yesterday SMALLDATETIME

	SELECT @today = CONVERT(DATE, GETDATE())
	SELECT @yesterday = DATEADD(DD, -1, @today)	

	-- get move bet date
	DECLARE @moveBetsDay SMALLDATETIME
	DECLARE @tblMoveBetBalanceUp AS TABLE (BalanceUpDay SMALLDATETIME, MoveBetsDay SMALLDATETIME)

	INSERT INTO @tblMoveBetBalanceUp(BalanceUpDay,MoveBetsDay)
	EXEC bodb02.dbo.Age_SelBalanceUpDay

	SELECT @moveBetsDay = MoveBetsDay FROM @tblMoveBetBalanceUp

	CREATE TABLE #tmp_customer
	(
		[custid]		INT PRIMARY KEY,
		[username]		VARCHAR(30)
	)

	CREATE TABLE #balance  
	(
		custid		INT PRIMARY KEY,
		balance		MONEY,
		yesterdaybalance	MONEY
	)
	
	;WITH rt AS
	(
		SELECT recommend AS custid,
			ISNULL(SUM(awinlost+comm-playercomm), 0) AS balance,
			ISNULL(SUM(CASE WHEN winlostdate <= @yesterday THEN awinlost+comm-playercomm ELSE 0 END),0) AS yesterdaybalance 
		FROM  bettrans b WITH (NOLOCK)
		WHERE mrecommend = @CustID
			AND	(
					b.winlostdate < @yesterday  
					OR NOT EXISTS (SELECT 1 FROM #SportBettype s WHERE s.Bettype = b.bettype)
				)
			AND bettype < 19999
			AND b.statusID IN (111, 112, 113)
			AND winlostdate > @moveBetsDay
		GROUP BY recommend

		UNION ALL

		SELECT recommend AS custid,
			ISNULL(SUM(CASE WHEN custid = recommend THEN winlost-actual_stake ELSE  awinlost+comm-playercomm END), 0) AS balance,
			ISNULL(SUM(CASE WHEN custid = recommend THEN winlost-actual_stake ELSE  awinlost+comm-playercomm END), 0) AS yesterdaybalance
		FROM  Transfer t WITH (NOLOCK)
		WHERE mrecommend = @CustID
			AND ((bettype = 19999 and winlostdate <= @moveBetsDay) OR bettype > 19999)
		GROUP BY recommend

		UNION ALL

		SELECT
			recommend AS custid,
			ISNULL(SUM(awinlost+comm-playercomm),0) AS balance,
			ISNULL(SUM(CASE WHEN winlostdate = @yesterday THEN awinlost+comm-playercomm ELSE  0 END),0) AS yesterdaybalance
		FROM  bettransRNG WITH (NOLOCK)
		WHERE mrecommend = @CustID
			AND winlostdate >= @yesterday
			AND statusID IN (111, 112, 113)
		GROUP BY recommend

		UNION ALL

		SELECT
			recommend AS custid,
			ISNULL(SUM(awinlost+comm-playercomm),0) AS balance,
			ISNULL(SUM(CASE WHEN winlostdate = @yesterday THEN awinlost+comm-playercomm ELSE 0 END),0) AS yesterdaybalance
		FROM  bettransLC WITH (NOLOCK)
		WHERE mrecommend = @CustID
			AND winlostdate >= @yesterday
			AND statusID IN (111, 112, 113)
		GROUP BY recommend
	)
	INSERT INTO #balance
	SELECT custid,
		SUM(balance),
		SUM(yesterdaybalance)
	FROM rt
	GROUP BY custid
	    
	INSERT INTO #tmp_customer 
		(
			[custid],
			[username]
		)
		SELECT 
			c.custid,c.username
		FROM 
			Customer c (nolock) 
		WHERE 
			c.roleid = 2 AND c.mrecommend = @CustID 

	IF @PageSize <= 0
		SELECT	x.custid,
				x.username,
				x.balance,
				x.yesterday_balance
		FROM (
			SELECT
				c.username,
				c.custid, 
				isnull(balance.balance,0) AS balance,
				isnull(balance.yesterdaybalance,0) yesterday_balance
			FROM #tmp_customer c 
				INNER JOIN #balance AS balance ON c.custid = balance.custid 
			WHERE balance <> 0
		) x
		ORDER BY balance DESC
		
	ELSE
		SELECT	x.custid,
				x.username,
				x.balance,
				x.yesterday_balance,
				x.RowNum
		FROM (
			SELECT
				c.username,
				c.custid, 
				isnull(balance.balance,0) AS balance,
				isnull(balance.yesterdaybalance,0) yesterday_balance,
				ROW_NUMBER() OVER(ORDER BY ABS(balance) DESC) RowNum
			FROM #tmp_customer c 
				INNER JOIN #balance AS balance ON c.custid = balance.custid 
			WHERE balance <> 0
		) x
		WHERE (RowNum <= @PageSize AND @PageIndex < 0) 
					OR (@PageIndex >= 0 AND RowNum BETWEEN @RowStart AND @RowEnd)
		ORDER BY RowNum

	DROP TABLE #balance
	DROP TABLE #tmp_customer
	DROP TABLE #SportBettype
END
GO