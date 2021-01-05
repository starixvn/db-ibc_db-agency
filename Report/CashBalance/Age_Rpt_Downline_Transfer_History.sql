/*<info serverAlias="DBAGE-bodb02" executers="bodbDownlineNet,bodbDownlineNetView" isFunction="0" isNested="0"></info>*/
CREATE PROCEDURE [dbo].[Age_Rpt_Downline_Transfer_History]  
	@CustID 		INT, --SMA login
	@FromDate 		SMALLDATETIME,
	@ToDate 		SMALLDATETIME,
	@Username		VARCHAR(50) = ''
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

	create table #MBU (
	balanceUpday	DATETIME ,
	movebetsday	DATETIME
	)
	insert into #MBU(balanceUpday, movebetsday)  exec Age_SelBalanceUpDay

	select @movebetsday = movebetsday, @balanceUpday = balanceUpday FROM #MBU
	
	DECLARE @roleID TINYINT

	SELECT  @roleID = roleid  FROM dbo.custInfo WITH(NOLOCK) WHERE custid = @custID

	CREATE TABLE #DownLineList (CustID INT)

	IF @roleID = 4 
	BEGIN
		INSERT INTO #DownLineList(CustID)
		SELECT CustID FROM dbo.custInfo WITH(NOLOCK) WHERE roleid = 3 and srecommend = @CustID
	END

	IF @roleID = 3 
	BEGIN
		INSERT INTO #DownLineList(CustID)
		SELECT CustID FROM dbo.custInfo WITH(NOLOCK) WHERE roleid = 2 and mrecommend = @CustID
	END

	IF @roleID = 2 
	BEGIN
		INSERT INTO #DownLineList(CustID)
		SELECT CustID FROM dbo.custInfo WITH(NOLOCK) WHERE roleid = 1 and recommend = @CustID
	END

	CREATE TABLE #UplineTrans (Refno BIGINT)

	CREATE TABLE #DownlineTransferHistory(
		RefNo			BIGINT,
		CustID			INT,
		TransDate		DATETIME,
		TransferType	TINYINT,
		TransferAmt		MONEY,
		OldBalance		MONEY,
		NewBalance		MONEY,
		TransDesc		NVARCHAR(1000)
	);

	DECLARE @FDate SMALLDATETIME, @TDate SMALLDATETIME
  
	IF @ToDate >= @BalanceUpDay
	BEGIN
		IF @FromDate <= @BalanceUpDay
		BEGIN
			SET @FDate =  @BalanceUpDay
		END

		SET @TDate = @ToDate

		INSERT INTO #UplineTrans (Refno)
		SELECT	refno AS RefNo	
		FROM	dbo.bettrans b WITH (NOLOCK)  
		WHERE custid = @CustID 
			AND  winlostdate BETWEEN @FDate AND @TDate
			AND bettype > 20000;


		INSERT INTO #DownlineTransferHistory(RefNo, CustID, TransDate, TransferType, TransferAmt, OldBalance, NewBalance, TransDesc)
		SELECT  refno AS RefNo,
				CustID,
				TransDate,
				CASE WHEN winlost - actual_stake > 0 THEN 1 ELSE 0 END,
				ABS(winlost - actual_stake) TransferAmt,
				balance as OldBalance,
				(balance + winlost - actual_stake)  AS NewBalance,
				transdesc as TransDesc
		FROM dbo.bettrans b WITH (NOLOCK)  
		WHERE b.custid in (SELECT d.CustID FROM #DownLineList d) 
			AND  winlostdate BETWEEN @FDate AND @TDate
			AND bettype > 20000;
   
		
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

		INSERT INTO #DownlineTransferHistory(RefNo, CustID, TransDate, TransferType, TransferAmt, OldBalance, NewBalance, TransDesc)
		SELECT  refno AS RefNo,
				custID	CustID,
				TransDate,
				CASE WHEN credit  > 0 THEN 1 ELSE 0 END,
				(credit + debit) TransferAmt,
				ISNULL(balance,0) as OldBalance,
				(ISNULL(balance,0) + credit - debit)  AS NewBalance,
				transdesc as TransDesc
		FROM DBARC.bodb_archive.dbo.transfer_bk b WITH (NOLOCK)  
		WHERE custid in (SELECT d.CustID FROM #DownLineList d) 
			AND  winlostdate BETWEEN @FDate AND @TDate
			AND bettype > 20000;
	END  
  
	SELECT c.username, TransDate, TransferType, TransferAmt, OldBalance, NewBalance, TransDesc 
	FROM #DownlineTransferHistory d
	INNER JOIN #UplineTrans u ON d.RefNo = u.Refno
	LEFT JOIN dbo.custInfo  c WITH(NOLOCK) ON c.custid = d.CustID
	WHERE c.username LIKE '%' + @Username + '%'

	SET NOCOUNT OFF;
END

GO