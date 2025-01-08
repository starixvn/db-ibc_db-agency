/*<info serverAlias="DBAGE-bodb02" executers="wsv_alp,wsv_alpv" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Age_RewardPayment_Master]  
	@CustId INT
	,@Username VARCHAR(30) =''
	,@Fromdate SMALLDATETIME =''
	,@Todate SMALLDATETIME =''
	,@ProgramIds VARCHAR(MAX) = ''
	,@PaymentStatus BIT = NULL
	,@LevelType TINYINT = 0

AS  
/*  
    Created: 20240918@Lewis  
    Task: Rebate and Retention for Credit Players - Report Reward Master
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
		, @recommend INT
	IF ISNULL(@Username,'') <> ''
	BEGIN
		SELECT @Username_CustId = ISNULL(custid,-1)
			,@recommend = recommend 
		FROM Customer WITH (NOLOCK) 
		WHERE username = @Username
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
		,IsDirectMember BIT DEFAULT(0)
	)
	INSERT INTO #RewardReport(
		TransId
		,CreatedDate
		,ProgramId
		--master/ Direct member
		--,MasterUserName VARCHAR(30)
		,Mrecommend
		,MasterAmount
		,MasterPaymentStatus
		,MasterPaymentDate
		,IsDirectMember
	)
	SELECT 
		swt.TransId
		,swt.TransDate
		,swt.ProgramId
		--master/ Direct member
		,IIF(swt.Mrecommend = -4, swt.CustId, swt.Mrecommend) AS Mrecommend
		,swt.Amount AS MasterAmount
		,CASE WHEN swt.Mrecommend > 0 AND swt.PaymentStatus & 4 = 4 THEN 1 
				WHEN swt.Mrecommend = -4 AND swt.StatusId = 1 THEN 1		
			ELSE 0 END AS MasterPaymentStatus
		,IIF(swt.Mrecommend = -4, swt.APaymentDate, swt.SPaymentDate) AS MasterPaymentDate
		,IIF(swt.Mrecommend = -4, 1, 0) AS IsDirectMember
	FROM SabaWalletTicket swt WITH (NOLOCK) 
	LEFT JOIN #ProgramList p
		ON swt.ProgramId = p.ProgramId
	WHERE swt.WalletID = 2
		AND swt.Srecommend = @CustId
		AND swt.WinlostDate BETWEEN @Fromdate AND @Todate
		AND 1 = CASE WHEN @Username_CustId = 0 THEN 1
					WHEN swt.Mrecommend = @Username_CustId THEN 1
					WHEN swt.CustID = @Username_CustId AND @recommend < 0 THEN 1
				ELSE 0 END
		AND 1 = CASE WHEN @LevelType = 0 THEN 1
					WHEN @LevelType = 1 AND swt.Mrecommend > 0 THEN 1
					WHEN @LevelType = 2 AND swt.Mrecommend = -4 THEN 1
				ELSE 0 END
		AND (
				ISNULL(@ProgramIds,'') = '' --get all
				OR p.ProgramId IS NOT NULL
			)	
		AND 1 = CASE WHEN @PaymentStatus IS NULL THEN 1
					 WHEN @PaymentStatus = 1 AND swt.PaymentStatus & 4 = 4 AND swt.Mrecommend > 0 THEN 1
					 WHEN @PaymentStatus = 1 AND swt.StatusId = 1 AND swt.Mrecommend = -4 THEN 1
					 WHEN @PaymentStatus = 0 AND swt.PaymentStatus & 4 <> 4 AND swt.Mrecommend > 0 THEN 1
					 WHEN @PaymentStatus = 0 AND swt.StatusId <> 1 AND swt.Mrecommend = -4 THEN 1
					ELSE 0 END

	--TODO: Result
	SELECT 
		MAX(rr.TransId) AS MaxTransId
		,rr.ProgramId
		--master/ Direct member
		,rr.Mrecommend
		,m.username AS MasterUserName 
		,SUM(rr.MasterAmount) AS MasterAmount
		,rr.MasterPaymentStatus
		,rr.MasterPaymentDate
		,rr.IsDirectMember
	FROM #RewardReport rr
	INNER JOIN Customer m WITH (NOLOCK) ON m.custid = rr.Mrecommend
	GROUP BY rr.ProgramId
		,rr.Mrecommend
		,m.username
		,rr.MasterPaymentStatus
		,rr.MasterPaymentDate
		,rr.IsDirectMember
	ORDER BY rr.ProgramId
		,m.username

END  