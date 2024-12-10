/*<info serverAlias="DBACC-bodb02" executers="wsv_alp,wsv_alpv" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Age_Transfer_DownlineHistorySel]  
	@CustID 		INT, --SMA login
	@FromDate 		SMALLDATETIME,
	@ToDate 		SMALLDATETIME,
	@Username		VARCHAR(50) = '',
	@PageSize		INT = 0,
	@PageIndex		INT = 0,
	@LevelType		TINYINT = 0,	
	@TotalRecords	INT = 0 OUTPUT
AS  

/*  
	Created:   
	Task :   
	DB: DBACC-bodb02
	
	Revisions:  
		- 20201228@Danny: Transfer To Downline History Report  [Redmine: #146038]
		- 20211111@Evan: Split transfer tickets out of bettrans - [Redmine: #164196]
		- 20241118@Max: Alpha - Offer Direct Member for Super/Master [Redmine: #211969]
*/  
 
BEGIN
SET NOCOUNT ON;

	DECLARE @movebetsday	DATETIME
	DECLARE @balanceUpday	DATETIME 

	DECLARE @RowStart	INT,
			@RowEnd		INT;
		
	SELECT	@PageIndex = @PageIndex - 1,
			@RowStart = @PageSize * @PageIndex + 1,
			@RowEnd = @RowStart + @PageSize - 1;

	create table #MBU (
	balanceUpday	DATETIME ,
	movebetsday	DATETIME
	)
	insert into #MBU(balanceUpday, movebetsday)  exec bodb02.dbo.Age_SelBalanceUpDay

	select @movebetsday = movebetsday, @balanceUpday = balanceUpday FROM #MBU
	
	DECLARE @roleID TINYINT

	SELECT  @roleID = roleid  FROM dbo.custInfo WITH(NOLOCK) WHERE custid = @custID

	CREATE TABLE #DownLineList (CustID INT, username NVARCHAR(100), IsDirectMember BIT DEFAULT(0))

	IF @roleID = 4 
	BEGIN
		INSERT INTO #DownLineList(CustID, username, IsDirectMember)
		SELECT CustID,username  
			,IIF(recommend = -4, 1, 0) AS IsDirectMember
		FROM dbo.custInfo WITH(NOLOCK) 
		WHERE 1 = CASE WHEN roleid = 3 AND @LevelType IN (0,1) THEN 1
					WHEN roleid = 1 AND @LevelType IN (0,2) AND recommend = -4 THEN 1
				ELSE 0 END
			and srecommend = @CustID AND username LIKE '%' + @Username + '%'
	END

	IF @roleID = 3 
	BEGIN
		INSERT INTO #DownLineList(CustID, username, IsDirectMember)
		SELECT CustID, username 
			,IIF(recommend = -4, 1, 0) AS IsDirectMember
		FROM dbo.custInfo WITH(NOLOCK) 
		WHERE 1 = CASE WHEN roleid = 2 AND @LevelType IN (0,1) THEN 1
					WHEN roleid = 1 AND @LevelType IN (0,2) AND recommend = -3 THEN 1
				ELSE 0 END
			and mrecommend = @CustID AND username LIKE '%' + @Username + '%'
	END

	IF @roleID = 2 
	BEGIN
		INSERT INTO #DownLineList(CustID, username)
		SELECT CustID, username FROM dbo.custInfo WITH(NOLOCK) WHERE roleid = 1 and recommend = @CustID AND username LIKE '%' + @Username + '%'
	END

	CREATE TABLE #UplineTrans (Refno BIGINT)

	CREATE TABLE #DownlineTransferHistory(
		RefNo			BIGINT,
		CustID			INT,
		username		NVARCHAR(100),
		TransDate		DATETIME,
		TransferType	TINYINT,
		TransferAmt		MONEY,
		OldBalance		MONEY,
		NewBalance		MONEY,
		TransDesc		NVARCHAR(1000),
		creator			INT, 
		IsDirectMember BIT DEFAULT(0)
	);

	CREATE TABLE #result(
		username		NVARCHAR(100),
		TransDate		DATETIME,
		TransferType	TINYINT,
		TransferAmt		MONEY,
		OldBalance		MONEY,
		NewBalance		MONEY,
		TransDesc		NVARCHAR(1000),
		IsDirectMember BIT DEFAULT(0),
		rn				INT
	);

	DECLARE @FDate SMALLDATETIME, @TDate SMALLDATETIME
  
	IF @ToDate >= @BalanceUpDay
	BEGIN
		SET @FDate = @FromDate
		SET @TDate = @ToDate
		
		IF @FromDate <= @BalanceUpDay
		BEGIN
			SET @FDate =  @BalanceUpDay
		END

		INSERT INTO #UplineTrans (Refno)
		SELECT	RefNo	
		FROM	dbo.Transfer b WITH (NOLOCK)  
		WHERE custid = @CustID 
			AND  winlostdate BETWEEN @FDate AND @TDate
			AND bettype > 20000;

		INSERT INTO #DownlineTransferHistory(RefNo, CustID, username, TransDate, TransferType, TransferAmt, OldBalance, NewBalance, TransDesc, creator, IsDirectMember)
		SELECT  RefNo,
				CustID,
				d.username,
				TransDate,
				CASE WHEN winlost - actual_stake > 0 THEN 1 ELSE 0 END,
				ABS(winlost - actual_stake) TransferAmt,
				ISNULL(balance,0) as OldBalance,
				ISNULL((balance + winlost - actual_stake),0)  AS NewBalance,
				TransDesc,
				creator,
				d.IsDirectMember
		FROM dbo.Transfer b WITH (NOLOCK)  
		CROSS APPLY (SELECT  d.username, IsDirectMember FROM #DownLineList d WHERE d.CustID = b.custid) d
		WHERE  winlostdate BETWEEN @FDate AND @TDate AND bettype > 20000;
		
	END  

	SELECT	@FDate = @FromDate,
			@TDate = @ToDate;

	IF @FromDate < @BalanceUpDay 
	BEGIN
		IF @ToDate >= DATEADD(dd, -1, @BalanceUpDay)
		BEGIN
			SELECT @TDate = DATEADD(dd, -1, @BalanceUpDay);
		END

		SET @FDate = @FromDate

		INSERT INTO #UplineTrans (Refno)
		SELECT	refno AS RefNo	
		FROM	bodb_Archive.dbo.transfer_bk b WITH (NOLOCK)  
		WHERE custid = @CustID 
			AND  winlostdate BETWEEN @FDate AND @TDate
			AND bettype > 20000;

	
		DECLARE @winlostdateTable TABLE (winlostdate smalldatetime)

		;WITH CTE_Winlostdate (winlostdate ) AS
		(
			SELECT @FDate AS winlostdate
			UNION ALL
			SELECT DATEADD(DAY, 1, winlostdate)
			FROM CTE_Winlostdate
			WHERE winlostdate < @TDate
		)
		INSERT INTO @winlostdateTable(winlostdate)
		select winlostdate from CTE_Winlostdate
		OPTION (MAXRECURSION 0)

		CREATE TABLE #DownLineWinlost (Winlostdate SMALLDATETIME, custID INT, username NVARCHAR(100), IsDirectMember BIT DEFAULT(0))
		INSERT INTO #DownLineWinlost (Winlostdate, custID, username, IsDirectMember)
		SELECT a.winlostdate, b.CustID, b.username,b.IsDirectMember
		FROM @winlostdateTable a CROSS JOIN #DownLineList b 

		CREATE CLUSTERED INDEX cix_#DownLineWinlost ON #DownLineWinlost(Winlostdate, CustID)

		INSERT INTO #DownlineTransferHistory(RefNo, CustID, username, TransDate, TransferType, TransferAmt, OldBalance, NewBalance, TransDesc, creator, IsDirectMember)
		SELECT  refno AS RefNo,
				custID	CustID,
				d.username,
				TransDate,
				CASE WHEN credit  > 0 THEN 1 ELSE 0 END,
				(credit + debit) TransferAmt,
				ISNULL(balance,0) as OldBalance,
				ISNULL((balance + credit - debit),0)  AS NewBalance,
				transdesc as TransDesc,
				creator,
				d.IsDirectMember
		FROM  bodb_Archive.dbo.transfer_bk b WITH (NOLOCK)  
		CROSS APPLY (SELECT  d.username, d.IsDirectMember FROM #DownLineWinlost d WHERE  d.Winlostdate = b.winlostdate AND  d.CustID = b.custid) d
		WHERE bettype > 20000;

		DROP TABLE #DownLineWinlost
	END  
	

	INSERT INTO #result(username, TransDate, TransferType, TransferAmt, OldBalance, NewBalance, TransDesc, IsDirectMember, rn)
	SELECT d.username, d.TransDate, d.TransferType, d.TransferAmt, d.OldBalance, d.NewBalance
		, CASE WHEN c.roleid > @roleID THEN 'The transfer was done by upline' ELSE d.TransDesc END TransDesc 
		, d.IsDirectMember
		, ROW_NUMBER() OVER (ORDER BY d.TransDate) AS rn
	FROM #DownlineTransferHistory d
	INNER JOIN #UplineTrans u ON d.RefNo = u.Refno
	LEFT JOIN dbo.custInfo c ON d.creator = c.custid 


	IF ((@PageSize <= 0) AND (@PageIndex <= 0))
	BEGIN
		SELECT username, TransDate, TransferType, TransferAmt, OldBalance, NewBalance, TransDesc, IsDirectMember
		FROM #result
		ORDER BY TransDate

		RETURN
	END

	IF (@TotalRecords = 0 OR   @TotalRecords IS NULL)
	BEGIN  
		SELECT @TotalRecords = count(1) FROM #result 
	END

	SELECT username, TransDate, TransferType, TransferAmt, OldBalance, NewBalance, TransDesc, IsDirectMember
	FROM #result
	WHERE rn BETWEEN @RowStart AND @RowEnd;

	DROP TABLE #UplineTrans
	DROP TABLE #MBU
	DROP TABLE #DownlineTransferHistory
	DROP TABLE #DownLineList
	DROP TABLE #result

	SET NOCOUNT OFF;
END

GO