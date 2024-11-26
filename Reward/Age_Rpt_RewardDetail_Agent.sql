/*<info serverAlias="DBAGE-bodb02" executers="wsv_alp,wsv_alpv" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Age_Rpt_RewardDetail_Agent]  
	@CustId INT
	,@Username VARCHAR(30) =''
	,@Fromdate SMALLDATETIME =''
	,@Todate SMALLDATETIME =''
	,@ProgramIds VARCHAR(MAX) = ''
	,@PaymentStatus BIT = NULL
	,@PageSize		INT = 0
	,@PageIndex		INT = 0
	,@TotalRecords	INT = 0 OUTPUT
AS  
/*  
    Created: 20240918@Lewis  
    Task: Rebate and Retention for Credit Players - Report Reward Agent
    DB: DBAGE-bodb02
  
    Revisions:  
        - 20240918@Lewis: Initialize SP [RedmineId: #208503]
  
    Param's Explanation:  
		- @Username: '': ALL | <>'': MemberUsername  
			
		- @PaymentStatus: NULL: ALL | 1: Paid | 0: UnPaid -> MemberPaymentStatus
*/  
BEGIN  
    SET NOCOUNT ON; 

	DECLARE @RowStart	INT,
			@RowEnd		INT;
		
	SELECT	@PageIndex = @PageIndex - 1,
			@RowStart = @PageSize * @PageIndex + 1,
			@RowEnd = @RowStart + @PageSize - 1;

	--@Fromdate ,@Todate
	SELECT @Fromdate = IIF(ISNULL(@Fromdate,'') ='',CAST(GETDATE() AS DATE),@Fromdate)
		   ,@Todate = IIF(ISNULL(@Todate,'') ='',CAST(GETDATE() AS DATE),@Todate)

	--Avoid Parameter Sniffing
	DECLARE @CID INT 
			,@FDate SMALLDATETIME
			,@TDate SMALLDATETIME

	SELECT @CID = @CustId
			,@FDate = @Fromdate
			,@TDate = @Todate

	-- @Username
	DECLARE @Username_CustId INT 
			,@Username_RoleId TINYINT

	IF ISNULL(@Username,'') <> '' -- @username:		='' => get all		||		<>'' => get exactly username 
	BEGIN
		SELECT @Username_CustId = custid
			  ,@Username_RoleId = roleid
		FROM customer c WITH(NOLOCK)
		WHERE c.username = @Username
	END

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
		,MemberPaymentStatus BIT
		,MemberPaymentDate DATE
		,MemberFeedback SMALLINT
		--agent
		--,AgentUserName VARCHAR(30)
		,Recommend INT
		,AgentPaymentStatus BIT
		,AgentPaymentDate DATE
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
		--agent
		--,AgentUserName VARCHAR(30)
		,Recommend
		,AgentPaymentStatus
		,AgentPaymentDate
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
			  WHEN swt.StatusId = 1 AND ISNULL(swt.IsComplaint,0) = 0 THEN 0
			  WHEN swt.StatusId = 1 AND swt.IsComplaint = 1 THEN 1
		 END AS MemberFeedback
		--agent
		,swt.Recommend
		,CASE WHEN swt.PaymentStatus & 2 = 2 THEN 1 ELSE 0 END AS AgentPaymentStatus
		,swt.MPaymentDate AS AgentPaymentDate
	FROM SabaWalletTicket swt WITH (NOLOCK) 
	LEFT JOIN #ProgramList p
		ON swt.ProgramId = p.ProgramId
	WHERE swt.WalletID = 2
		AND swt.Mrecommend = @CID	
		AND swt.WinlostDate BETWEEN @FDate AND @TDate
		AND 1 = CASE 
					WHEN ISNULL(@Username,'') = '' THEN 1 --get all
					WHEN @Username_RoleId = 1 AND swt.custid = @Username_CustId THEN 1 --mem username
					WHEN @Username_RoleId = 2 AND swt.Recommend = @Username_CustId THEN 1 --agent username
					ELSE 0 
				END
		AND (
				ISNULL(@ProgramIds,'') = '' --get all
				OR p.ProgramId IS NOT NULL
			)	
		AND (
				@PaymentStatus IS NULL --get all
				OR swt.StatusId = @PaymentStatus
			)


	--TODO: Result
	IF ((@PageSize <= 0) AND (@PageIndex <= 0))
	BEGIN
		SELECT 
			rr.CreatedDate
			,rr.ProgramId
			--mem
			,rr.CustID
			,mem.username AS MemberUserName 
			,rr.MemberAmount
			,rr.MemberPaymentStatus
			,rr.MemberPaymentDate
			,rr.MemberFeedback
			--agent
			,rr.Recommend
			,a.username AS AgentUserName 
			,rr.AgentPaymentStatus
			,rr.AgentPaymentDate
		FROM #RewardReport rr
		INNER JOIN Customer mem WITH (NOLOCK) ON mem.custid = rr.CustID
		INNER JOIN Customer a WITH (NOLOCK) ON a.custid = rr.Recommend
		ORDER BY CreatedDate DESC
	END
	ELSE
	BEGIN
		IF @TotalRecords = 0
		BEGIN
			SELECT @TotalRecords = COUNT(1)
			FROM #RewardReport
		END

		SELECT 
			A.CreatedDate
			,A.ProgramId
			--mem
			,A.CustID
			,A.MemberUserName 
			,A.MemberAmount
			,A.MemberPaymentStatus
			,A.MemberPaymentDate
			,A.MemberFeedback
			--agent
			,A.Recommend
			,A.AgentUserName 
			,A.AgentPaymentStatus
			,A.AgentPaymentDate
		FROM (
				SELECT 
					rr.CreatedDate
					,rr.ProgramId
					--mem
					,rr.CustID
					,mem.username AS MemberUserName 
					,rr.MemberAmount
					,rr.MemberPaymentStatus
					,rr.MemberPaymentDate
					,rr.MemberFeedback
					--agent
					,rr.Recommend
					,a.username AS AgentUserName 
					,rr.AgentPaymentStatus
					,rr.AgentPaymentDate
					,ROW_NUMBER() OVER (ORDER BY  rr.CreatedDate DESC) AS Rownum
				FROM #RewardReport rr
				INNER JOIN Customer mem WITH (NOLOCK) ON mem.custid = rr.CustID
				INNER JOIN Customer a WITH (NOLOCK) ON a.custid = rr.Recommend
			) A
		WHERE A.Rownum BETWEEN @RowStart AND @RowEnd
	END

END  