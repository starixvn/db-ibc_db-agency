/*<info serverAlias="DBACC-bodb02" executers="bodbDownlineNet,bodbDownlineNetView" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Age_Rpt_Downline_Transfer_History]  
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
 

	CREATE TABLE #TransferHistory(
		RefNo			BIGINT,
		UserName		VARCHAR(50),
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
		INSERT INTO #TransferHistory(RefNo, TransDate, TransferType, TransferAmt, OldBalance, NewBalance, TransDesc)
		SELECT  refno AS RefNo,
				TransDate,
				CASE WHEN winlost - actual_stake > 0 THEN 1 ELSE 0 END,
				ABS(winlost - actual_stake) TransferAmt,
				balance as OldBalance,
				(balance + winlost - actual_stake)  AS NewBalance,
				transdesc as TransDesc
		FROM dbo.bettrans b WITH (NOLOCK)  
		WHERE custid = @CustID 
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

		INSERT INTO #TransferHistory(RefNo, TransDate, TransferType, TransferAmt, OldBalance, NewBalance, TransDesc)
		SELECT  refno AS RefNo,
				TransDate,
				CASE WHEN credit  > 0 THEN 1 ELSE 0 END,
				(credit + debit) TransferAmt,
				0. as OldBalance,
				(0. + credit + debit)  AS NewBalance,
				transdesc as TransDesc
		FROM DBARC.bodb_archive.dbo.transfer_bk b WITH (NOLOCK)  
		WHERE custid = @CustID 
			AND  winlostdate BETWEEN @FDate AND @TDate
			AND bettype > 20000;
	END  
  
	SELECT * FROM #TransferHistory

	SET NOCOUNT OFF;
END
GO