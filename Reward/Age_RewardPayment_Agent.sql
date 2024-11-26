/*<info serverAlias="DBAGE-bodb02" executers="wsv_alp,wsv_alpv" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Age_RewardPayment_Agent]  
	@CustId INT
	,@Username VARCHAR(30) =''
	,@Fromdate SMALLDATETIME =''
	,@Todate SMALLDATETIME =''
	,@ProgramIds VARCHAR(MAX) = ''
	,@PaymentStatus TINYINT = NULL
AS  
/*  
    Created: 20240918@Lewis  
    Task: Rebate and Retention for Credit Players - Report Reward Agent
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
		--agent
		--,AgentUserName VARCHAR(30)
		,Recommend INT
		,AgentAmount MONEY
		,AgentPaymentStatus BIT
		,AgentPaymentDate DATE
	)
	INSERT INTO #RewardReport(
		TransId
		,CreatedDate
		,ProgramId
		--agent
		--,AgentUserName VARCHAR(30)
		,Recommend
		,AgentAmount
		,AgentPaymentStatus
		,AgentPaymentDate
	)
	SELECT 
		swt.TransId
		,swt.TransDate
		,swt.ProgramId
		--agent
		,swt.Recommend
		,swt.Amount AS AgentAmount
		,CASE WHEN swt.PaymentStatus & 2 = 2 THEN 1 ELSE 0 END AS AgentPaymentStatus
		,swt.MPaymentDate AS AgentPaymentDate

	FROM SabaWalletTicket swt WITH (NOLOCK) 
	LEFT JOIN #ProgramList p
		ON swt.ProgramId = p.ProgramId
	WHERE swt.WalletID = 2
		AND swt.Mrecommend = @CustId	
		AND swt.WinlostDate BETWEEN @Fromdate AND @Todate
		AND (swt.Recommend = @Username_CustId OR @Username_CustId = 0)
		AND (
				ISNULL(@ProgramIds,'') = '' --get all
				OR p.ProgramId IS NOT NULL
			)	
		AND 1 = CASE WHEN @PaymentStatus IS NULL THEN 1
					 WHEN @PaymentStatus = 1 AND ISNULL(swt.PaymentStatus,0) & 2 = 2 THEN 1
					 WHEN @PaymentStatus = 0 AND ISNULL(swt.PaymentStatus,0) & 2 <> 2 THEN 1
					 ELSE 0 END


	--TODO: Result
	SELECT 
		MAX(rr.TransId) AS MaxTransId
		,rr.ProgramId
		--agent
		,rr.Recommend
		,a.username AS AgentUserName 
		,SUM(rr.AgentAmount) AS AgentAmount
		,rr.AgentPaymentStatus
		,rr.AgentPaymentDate
	FROM #RewardReport rr
	INNER JOIN Customer a WITH (NOLOCK) ON a.custid = rr.Recommend
	GROUP BY rr.ProgramId
		,rr.Recommend
		,a.username
		,rr.AgentPaymentStatus
		,rr.AgentPaymentDate
	ORDER BY rr.ProgramId
		,a.username

END  