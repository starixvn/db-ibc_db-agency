/*<info serverAlias="DBAGE-bodb02" executers="wsv_alp,wsv_alpv" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Age_RewardPayment_Master]  
	@CustId INT
	,@Username VARCHAR(30) =''
	,@Fromdate SMALLDATETIME =''
	,@Todate SMALLDATETIME =''
	,@ProgramIds VARCHAR(MAX) = ''
	,@PaymentStatus BIT = NULL

AS  
/*  
    Created: 20240918@Lewis  
    Task: Rebate and Retention for Credit Players - Report Reward Master
    DB: DBAGE-bodb02
  
    Revisions:  
        - 20240918@Lewis: Initialize SP [RedmineId: #208503]
  
    Param's Explanation:  
		- @Username: '': ALL | <>'': Username  
					 Super  -> MasterUsername
					 Master -> AgentUsername
					 Agent  -> MemberUsername  
			
		- @PaymentStatus: NULL: ALL | 1: Paid | 0: UnPaid 
    

*/  
BEGIN  
    SET NOCOUNT ON; 

	-- @Username
	DECLARE @Username_CustId INT = 0 -- 0: all 
	IF ISNULL(@Username,'') <> ''
	BEGIN
		SET @Username_CustId = ISNULL((SELECT custid FROM Customer WITH (NOLOCK) WHERE username = @Username),-1)
	END

	--@Fromdate ,@Todate
	SELECT @Fromdate = IIF(ISNULL(@Fromdate,'') ='',GETDATE(),@Fromdate)
		   ,@Todate = IIF(ISNULL(@Todate,'') ='',GETDATE(),@Todate)

	--@ProgramIds
	DROP TABLE IF EXISTS #ProgramList
	CREATE TABLE #ProgramList(
		ProgramId SMALLINT
	)
	IF ISNULL(@ProgramIds,'') <> ''
	BEGIN
		INSERT INTO #ProgramList(
			ProgramId
		)
		SELECT value 
		FROM string_split(@ProgramIds,',') 
	END

	--TODO: SabaWalletTicket
	DROP TABLE IF EXISTS #RewardReport
	CREATE TABLE #RewardReport(
		TransId BIGINT
		,CreatedDate DATETIME
		,ProgramId SMALLINT
		--master
		--,MasterUserName VARCHAR(30)
		,Mrecommend INT
		,MasterAmount MONEY
		,MasterPaymentStatus BIT
		,MasterPaymentDate DATE
	)
	INSERT INTO #RewardReport(
		TransId
		,CreatedDate
		,ProgramId
		--master
		--,MasterUserName VARCHAR(30)
		,Mrecommend
		,MasterAmount
		,MasterPaymentStatus
		,MasterPaymentDate
	)
	SELECT 
		swt.TransId
		,swt.TransDate
		,swt.ProgramId
		--master
		,swt.Mrecommend
		,swt.Amount AS MasterAmount
		,CASE WHEN swt.PaymentStatus & 4 = 4 THEN 1 ELSE 0 END AS MasterPaymentStatus
		,swt.SPaymentDate AS MasterPaymentDate

	FROM SabaWalletTicket swt WITH (NOLOCK) 
	LEFT JOIN #ProgramList p
		ON swt.ProgramId = p.ProgramId
	WHERE swt.WalletID = 2
		AND swt.Srecommend = @CustId
		AND swt.WinlostDate BETWEEN @Fromdate AND @Todate
		AND (swt.Mrecommend = @Username_CustId OR @Username_CustId = 0)
		AND (
				ISNULL(@ProgramIds,'') = '' --get all
				OR p.ProgramId IS NOT NULL
			)	
		AND 1 = CASE WHEN @PaymentStatus IS NULL THEN 1
					 WHEN @PaymentStatus = 1 AND swt.PaymentStatus & 4 = 4 THEN 1
					 WHEN @PaymentStatus = 0 AND swt.PaymentStatus & 4 <> 4 THEN 1
					 ELSE 0 END

	--TODO: Result
	SELECT 
		MAX(rr.TransId) AS MaxTransId
		,rr.ProgramId
		--master
		,rr.Mrecommend
		,m.username AS MasterUserName 
		,SUM(rr.MasterAmount) AS MasterAmount
		,rr.MasterPaymentStatus
		,rr.MasterPaymentDate
	FROM #RewardReport rr
	INNER JOIN Customer m WITH (NOLOCK) ON m.custid = rr.Mrecommend
	GROUP BY rr.ProgramId
		,rr.Mrecommend
		,m.username
		,rr.MasterPaymentStatus
		,rr.MasterPaymentDate
	ORDER BY rr.ProgramId
		,m.username

END  