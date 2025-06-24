/*<info serverAlias="DBSIC-bodb02" executers="asv_CashService,wsv_CashService,wsv_nap,wsv_alp,wsv_alpv,wsv_xnap" selecters="" viewers="" isFunction="0" isNested=""></info>*/
ALTER PROCEDURE [dbo].[Age_CashTransaction_Sel]  
	@CustId	INT
	,@TransactionType TINYINT
	,@Fromdate DATETIME = NULL
	,@Todate DATETIME = NULL
	,@PaymentFrom VARCHAR(100) = ''
	,@PaymentTo VARCHAR(100) = ''
	,@PaymentStatus SMALLINT = -1
	,@PageSize		INT = 5000
	,@PageIndex		INT = 1
	,@TotalRecords	INT = 0 OUTPUT
AS  
/*
	Created: 20250502@Max		
	Task: Alpha - Agency Cash Service [redmine: #223896] 
	DB:  DBSIC-bodb02
		
	Revisions:
		- 20250502@Max: Alpha - Agency Cash Service [redmine: #223896] 
		- 20250611@Max: Alpha - Agency Cash Service - Sprint 4 [redmine: #223896] 

	Parameter's Explanation:
		@TransactionType:  
			1  : Deposit
			2  : Withdrawal

		@PayemntStatus:
			-1: All
			0: Waiting
			1: Cancelled
			2: Pending
			3: Expired
			4: Completed
			5: Rejected
			6. Provider Rejected
*/ 
BEGIN  
    SET NOCOUNT ON; 

	DECLARE @RowStart	INT,
			@RowEnd		INT;
		
	SELECT	@PageIndex = @PageIndex - 1,
			@RowStart = @PageSize * @PageIndex + 1,
			@RowEnd = @RowStart + @PageSize - 1;

	--@Fromdate ,@Todate
	SELECT @Fromdate = ISNULL(@Fromdate,'') 
		   ,@Todate = ISNULL(@Todate,'')

	--Avoid Parameter Sniffing
	DECLARE @FDate SMALLDATETIME
			,@TDate SMALLDATETIME

	SELECT @FDate = @Fromdate
			,@TDate = @Todate

	CREATE TABLE #TransactionHistory(
		TransId BIGINT,
		CustId INT,
		Amount MONEY,
		PaymentFrom VARCHAR(100),
		PaymentTo VARCHAR(100),
		StatusId TINYINT,
		TransactionType VARCHAR(50),
		TransferRefNo BIGINT,
		CreatedTime DATETIME,
		Remark VARCHAR(1000),
		PaymentType TINYINT,
		IsHadPayslip BIT
	)

	CREATE TABLE #CashMember (CustId INT PRIMARY KEY)
	INSERT INTO #CashMember (CustId)
	SELECT c.CustId
	FROM CustDB.dbo.custInfo c WITH (NOLOCK)
		INNER JOIN CustDB.dbo.vw_CustInfoExtra vw ON vw.CustID = c.custid AND vw.ServiceType = 1
	WHERE c.recommend = @CustId
		AND c.roleid = 1
	
	INSERT INTO #TransactionHistory(
		TransId,
		CustId,
		Amount,
		PaymentFrom,
		PaymentTo,
		StatusId,
		TransactionType,
		TransferRefNo,
		CreatedTime,
		Remark,
		IsHadPayslip
	)
	SELECT c.TransId,
		c.CustId,
		Amount,
		PaymentFrom,
		PaymentTo,
		StatusId,
		CASE c.TransactionTypeID
			WHEN 1  THEN 'Manual Deposit'
			WHEN 2  THEN 'Auto Deposit'
			WHEN 3  THEN 'Manual Withdraw'
			WHEN 4  THEN 'Auto Withdraw'
		END AS TransactionType,
		TransferRefNo,
		CreatedTime,
		Remark,
		IIF(c.PaySlip IS NOT NULL, 1, 0)
	FROM dbo.CashTransaction c WITH (NOLOCK)
		INNER JOIN #CashMember ci ON ci.CustId = c.CustId
	WHERE ((@FDate = '' AND @TDate = '') OR c.CreatedTime BETWEEN @FDate AND @TDate)
		AND ((@PaymentStatus = -1 AND c.StatusId IN (3,4,5,6)) OR c.StatusId = @PaymentStatus)
		AND (@PaymentFrom = '' OR c.PaymentFrom = @PaymentFrom)
		AND (@PaymentTo = '' OR c.PaymentTo = @PaymentTo)
		AND 1 = CASE WHEN @TransactionType = 1 AND c.TransactionTypeID IN (1,2) THEN 1
					WHEN @TransactionType = 2 AND c.TransactionTypeID = 3 THEN 1 END

	--TODO: Result
	IF ((@PageSize <= 0) AND (@PageIndex <= 0))
	BEGIN
		SELECT tr.CustId
			,c.username
			,c.firstname
			,c.lastname
			,tr.Amount
			,e.currency
			,tr.PaymentFrom
			,tr.PaymentTo
			,tr.StatusId
			,tr.TransactionType
			,tr.TransId
			,tr.CreatedTime
			,tr.Remark
			,c.username2 AS nickname
			,tr.IsHadPayslip
		FROM #TransactionHistory tr
			INNER JOIN CustDB.dbo.vw_CashService_Customer c WITH (NOLOCK) ON c.custid = tr.CustID
			INNER JOIN CustDB.dbo.exchange e WITH (NOLOCK) ON e.ExchangeId = c.currency
		ORDER BY tr.TransId DESC
	END
	ELSE
	BEGIN
		IF @TotalRecords = 0
		BEGIN
			SELECT @TotalRecords = COUNT(1)
			FROM #TransactionHistory
		END

		SELECT 
			CustId
			,username
			,firstname
			,lastname
			,Amount
			,currency
			,PaymentFrom
			,PaymentTo
			,StatusId
			,TransactionType
			,TransId
			,CreatedTime
			,Remark
			,nickname
			,IsHadPayslip
		FROM (
				SELECT tr.CustId
					,c.username
					,c.firstname
					,c.lastname
					,tr.Amount
					,e.currency
					,tr.PaymentFrom
					,tr.PaymentTo
					,tr.StatusId
					,tr.TransactionType
					,tr.TransId
					,tr.CreatedTime
					,tr.Remark
					,c.username2 AS nickname
					,tr.IsHadPayslip
					,ROW_NUMBER() OVER (ORDER BY tr.transid DESC) AS Rownum
				FROM #TransactionHistory tr
					INNER JOIN CustDB.dbo.vw_CashService_Customer c WITH (NOLOCK) ON c.custid = tr.CustID
					INNER JOIN CustDB.dbo.exchange e WITH (NOLOCK) ON e.ExchangeId = c.currency
			) t
		WHERE t.Rownum BETWEEN @RowStart AND @RowEnd
	END

	DROP TABLE #TransactionHistory
	DROP TABLE #CashMember

END  