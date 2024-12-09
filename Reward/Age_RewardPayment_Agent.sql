/*<info serverAlias="DBAGE-bodb02" executers="wsv_alp,wsv_alpv" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Age_RewardPayment_Agent]  
	@CustId INT
	,@Username VARCHAR(30) =''
	,@Fromdate SMALLDATETIME =''
	,@Todate SMALLDATETIME =''
	,@ProgramIds VARCHAR(MAX) = ''
	,@PaymentStatus TINYINT = NULL
	,@LevelType TINYINT = 0
AS  
/*  
    Created: 20240918@Lewis  
    Task: Rebate and Retention for Credit Players - Report Reward Agent
    DB: DBAGE-bodb02
  
    Revisions:  
        - 20240918@Lewis: Initialize SP [RedmineId: #208503]
		- 20241118@Max: Alpha - Offer Direct Member for Super/Master - Move SP from DBAGE to DBSIC [Redmine: #211969]
  
    Param's Explanation:  
		- @Username: '': ALL | <>'': Username  
					 Super  -> MasterUsername
					 Master -> AgentUsername
					 Agent  -> MemberUsername  

		- @PaymentStatus: NULL: ALL | 1: Paid | 0: UnPaid 		
		• @Leveltype: 
			- 0: All
			- 1: Master Agent
			- 2: Directmember

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
		--agent/ Direct Member
		--,AgentUserName VARCHAR(30)
		,Recommend INT
		,AgentAmount MONEY
		,AgentPaymentStatus BIT
		,AgentPaymentDate DATE
		,IsDirectMember BIT DEFAULT(0)
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
		,IsDirectMember
	)
	SELECT 
		swt.TransId
		,swt.TransDate
		,swt.ProgramId
		--agent/ Direct member
		,IIF(swt.Recommend = -3, swt.CustId, swt.Recommend) AS Recommend
		,swt.Amount AS AgentAmount
		,CASE WHEN swt.PaymentStatus & 2 = 2 THEN 1 ELSE 0 END AS AgentPaymentStatus
		,swt.MPaymentDate AS AgentPaymentDate
		,IIF(swt.Recommend = -3, 1, 0) AS IsDirectMember
	FROM SabaWalletTicket swt WITH (NOLOCK) 
	LEFT JOIN #ProgramList p
		ON swt.ProgramId = p.ProgramId
	WHERE swt.WalletID = 2
		AND swt.Mrecommend = @CustId	
		AND swt.WinlostDate BETWEEN @Fromdate AND @Todate
		AND 1 = CASE WHEN @Username_CustId = 0 THEN 1
					WHEN swt.Recommend = @Username_CustId THEN 1
					WHEN swt.CustID = @Username_CustId THEN 1
				ELSE 0 END
		AND 1 = CASE WHEN @LevelType = 0 THEN 1
					WHEN @LevelType = 1 AND swt.Recommend > 0 THEN 1
					WHEN @LevelType = 2 AND swt.Recommend = -3 THEN 1
				ELSE 0 END
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
		--agent/ Direct member
		,rr.Recommend
		,a.username AS AgentUserName 
		,SUM(rr.AgentAmount) AS AgentAmount
		,rr.AgentPaymentStatus
		,rr.AgentPaymentDate
		,rr.IsDirectMember
	FROM #RewardReport rr
	INNER JOIN Customer a WITH (NOLOCK) ON a.custid = rr.Recommend
	GROUP BY rr.ProgramId
		,rr.Recommend
		,a.username
		,rr.AgentPaymentStatus
		,rr.AgentPaymentDate
		,rr.IsDirectMember
	ORDER BY rr.ProgramId
		,a.username

END  