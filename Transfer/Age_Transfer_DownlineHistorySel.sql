/*<info serverAlias="DBAGE-bodb02" executers="bodbDownlineNet,bodbDownlineNetView" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Age_Transfer_DownlineHistorySel]  
	@CustID 		INT, --SMA login
	@FromDate 		SMALLDATETIME,
	@ToDate 		SMALLDATETIME,
	@Username		VARCHAR(50) = '',
	@PageSize		INT = 0,
	@PageIndex		INT = 0,
	@TotalRecords	INT = 0 OUTPUT
AS  

/*  
	Created:   
	Task :   
	DB: DBAGE/bodb02
	
	Revisions:  
		- 20201228@Danny: Transfer To Downline History Report  [Redmine: #146038]
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
	insert into #MBU(balanceUpday, movebetsday)  exec Age_SelBalanceUpDay

	select @movebetsday = movebetsday, @balanceUpday = balanceUpday FROM #MBU
	
	DECLARE @roleID TINYINT

	SELECT  @roleID = roleid  FROM dbo.custInfo WITH(NOLOCK) WHERE custid = @custID

	CREATE TABLE #DownLineList (CustID INT, username NVARCHAR(100))

	IF @roleID = 4 
	BEGIN
		INSERT INTO #DownLineList(CustID, username)
		SELECT CustID,username  FROM dbo.custInfo WITH(NOLOCK) WHERE roleid = 3 and srecommend = @CustID AND username LIKE '%' + @Username + '%'
	END

	IF @roleID = 3 
	BEGIN
		INSERT INTO #DownLineList(CustID, username)
		SELECT CustID, username FROM dbo.custInfo WITH(NOLOCK) WHERE roleid = 2 and mrecommend = @CustID AND username LIKE '%' + @Username + '%'
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
		TransDesc		NVARCHAR(1000)
	);

	CREATE TABLE #result(
		username		NVARCHAR(100),
		TransDate		DATETIME,
		TransferType	TINYINT,
		TransferAmt		MONEY,
		OldBalance		MONEY,
		NewBalance		MONEY,
		TransDesc		NVARCHAR(1000),
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
		SELECT	refno AS RefNo	
		FROM	dbo.bettrans b WITH (NOLOCK)  
		WHERE custid = @CustID 
			AND  winlostdate BETWEEN @FDate AND @TDate
			AND bettype > 20000;


		INSERT INTO #DownlineTransferHistory(RefNo, CustID, username, TransDate, TransferType, TransferAmt, OldBalance, NewBalance, TransDesc)
		SELECT  refno AS RefNo,
				CustID,
				d.username,
				TransDate,
				CASE WHEN winlost - actual_stake > 0 THEN 1 ELSE 0 END,
				ABS(winlost - actual_stake) TransferAmt,
				balance as OldBalance,
				(balance + winlost - actual_stake)  AS NewBalance,
				transdesc as TransDesc
		FROM dbo.bettrans b WITH (NOLOCK)  
		CROSS APPLY (SELECT  d.username FROM #DownLineList d WHERE d.CustID = b.custid) d
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
		FROM	DBARC.bodb_archive.dbo.transfer_bk b WITH (NOLOCK)  
		WHERE custid = @CustID 
			AND  winlostdate BETWEEN @FDate AND @TDate
			AND bettype > 20000;

		INSERT INTO #DownlineTransferHistory(RefNo, CustID, username, TransDate, TransferType, TransferAmt, OldBalance, NewBalance, TransDesc)
		SELECT  refno AS RefNo,
				custID	CustID,
				d.username,
				TransDate,
				CASE WHEN credit  > 0 THEN 1 ELSE 0 END,
				(credit + debit) TransferAmt,
				ISNULL(balance,0) as OldBalance,
				(ISNULL(balance,0) + credit - debit)  AS NewBalance,
				transdesc as TransDesc
		FROM DBARC.bodb_archive.dbo.transfer_bk b WITH (NOLOCK)  
		CROSS APPLY (SELECT  d.username FROM #DownLineList d WHERE d.CustID = b.custid) d
		WHERE  winlostdate BETWEEN @FDate AND @TDate
			AND bettype > 20000;
	END  
	

	INSERT INTO #result(username, TransDate, TransferType, TransferAmt, OldBalance, NewBalance, TransDesc, rn)
	SELECT username, TransDate, TransferType, TransferAmt, OldBalance, NewBalance, TransDesc , ROW_NUMBER() OVER (ORDER BY TransDate) AS rn
	FROM #DownlineTransferHistory d
	INNER JOIN #UplineTrans u ON d.RefNo = u.Refno


	IF ((@PageSize <= 0) AND (@PageIndex <= 0))
	BEGIN
		SELECT username, TransDate, TransferType, TransferAmt, OldBalance, NewBalance, TransDesc 
		FROM #result
		ORDER BY TransDate

		RETURN
	END

	IF @TotalRecords = 0  
	BEGIN  
		SELECT @TotalRecords = count(1) FROM #result 
	END

	SELECT username, TransDate, TransferType, TransferAmt, OldBalance, NewBalance, TransDesc 
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