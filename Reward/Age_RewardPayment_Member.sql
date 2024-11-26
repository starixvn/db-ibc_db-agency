/*<info serverAlias="DBAGE-bodb02" executers="wsv_alp,wsv_alpv" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Age_RewardPayment_Member]  
	@CustId INT
	,@Username VARCHAR(30) =''
	,@Fromdate SMALLDATETIME =''
	,@Todate SMALLDATETIME =''
	,@ProgramIds VARCHAR(MAX) = ''
	,@PaymentStatus BIT = NULL

AS  
/*  
    Created: 20240918@Lewis  
    Task: Rebate and Retention for Credit Players - Report Reward Member
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
		--mem
		--,MemberUserName VARCHAR(30)
		,CustID INT
		,MemberAmount MONEY
		,MemberPaymentStatus TINYINT
		,MemberPaymentDate DATE
		,MemberFeedback VARCHAR(30)
	)
	INSERT INTO #RewardReport(
		TransId
		,CreatedDate
		,ProgramId
		--mem
		--,MemberUserName VARCHAR(30)
		,CustID
		,MemberAmount
		,MemberPaymentStatus
		,MemberPaymentDate
		,MemberFeedback
	)
	SELECT 
		swt.TransId
		,swt.TransDate
		,swt.ProgramId
		--mem
		,swt.CustID
		,swt.Amount AS MemberAmount
		,CASE WHEN swt.StatusId = 1 THEN 1 ELSE 0 END AS MemberPaymentStatus
		,swt.APaymentDate AS MemberPaymentDate
		,CASE 
			  WHEN swt.StatusId = 1 AND swt.IsComplaint = 0 THEN 0
			  WHEN swt.StatusId = 1 AND swt.IsComplaint = 1 THEN 1
		 END AS MemberFeedback
	FROM SabaWalletTicket swt WITH (NOLOCK) 
	LEFT JOIN #ProgramList p
		ON swt.ProgramId = p.ProgramId
	WHERE swt.WalletID = 2
		AND swt.Recommend = @CustId
		AND swt.WinlostDate BETWEEN @Fromdate AND @Todate
		AND (swt.CustID = @Username_CustId OR @Username_CustId = 0)
		AND (
				ISNULL(@ProgramIds,'') = '' --get all
				OR p.ProgramId IS NOT NULL
			)	
		AND (
				@PaymentStatus IS NULL --get all
				OR swt.StatusId = @PaymentStatus
			)

	--TODO: Result
	SELECT 
		MAX(rr.TransId) AS MaxTransId
		,rr.ProgramId
		--mem
		,rr.CustID
		,mem.username AS MemberUserName 
		,SUM(rr.MemberAmount) AS MemberAmount
		,rr.MemberPaymentStatus
		,rr.MemberPaymentDate
	FROM #RewardReport rr
	INNER JOIN Customer mem WITH (NOLOCK) ON mem.custid = rr.CustID
	GROUP BY rr.ProgramId
		,rr.CustID
		,mem.username
		,rr.MemberPaymentStatus
		,rr.MemberPaymentDate
	ORDER BY rr.ProgramId
		,mem.username

END  