/*<info serverAlias="DBSIC-bodb02" executers="asv_CashService,wsv_CashService" selecters="" viewers="" isFunction="0" isNested=""></info>*/
ALTER PROCEDURE [dbo].[Age_CashPromotion_Transaction_Sel]  
	 @CustId	INT
	,@Fromdate DATETIME = NULL
	,@Todate DATETIME = NULL
	,@Status SMALLINT = 2
	,@PromotionType TINYINT = NULL
	,@PageSize		INT = 5000
	,@PageIndex		INT = 1
	,@TotalRecords	INT = 0 OUTPUT
AS   
/*
	Created: 20250709@Eden	
	Task: Get pending Promotion - Bonus by Agent 
	DB:  DBSIC-bodb02
		
	Revisions:
		- 20250709@Eden: Alpha - Agency Cash Service - Sprint 6 [redmine: #223896] 

	Parameter's Explanation:
		@PayemntStatus:
			-1: All
			2: Pending
			3: Expired
			4: Completed
			5: Rejected
	Sample:
		DECLARE @TotalRecords INT
		EXEC [Age_CashPromotion_Transaction_Sel] 
			  @CustId = 233657343
			, @Status = 2
			, @PromotionType = 1
			, @Fromdate = '2025/07/10'
			, @Todate = '2025/07/17'
			, @TotalRecords = @TotalRecords OUT
		SELECT @TotalRecords
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
		   ,@Todate = ISNULL(@Todate,GETDATE() + 1)

	--Avoid Parameter Sniffing
	DECLARE @FDate SMALLDATETIME
			,@TDate SMALLDATETIME

	SELECT @FDate = @Fromdate
			,@TDate = @Todate

	CREATE TABLE #CashTransaction_Promotion(
		TransId BIGINT,
		CustId INT,
		Amount MONEY,
		StatusId TINYINT,
		CreatedTime DATETIME,
		PromotionID INT,
		SiteDBGroupID SMALLINT,
		FromDate DATE,
		ToDate DATE,
		PromotionType TINYINT
	)

	CREATE TABLE #CashMember (CustId INT PRIMARY KEY)
	INSERT INTO #CashMember (CustId)
	SELECT c.CustId
	FROM CustDB.dbo.custInfo c WITH (NOLOCK)
		INNER JOIN CustDB.dbo.vw_CustInfoExtra vw ON vw.CustID = c.custid AND vw.ServiceType = 1
	WHERE c.recommend = @CustId
		AND c.roleid = 1
	
	INSERT INTO #CashTransaction_Promotion(
		TransId,
		CustId,
		Amount,
		StatusId,
		CreatedTime,
		PromotionID,
		SiteDBGroupID,
		FromDate,
		ToDate,
		PromotionType
	)
	SELECT c.TransId,
		c.CustId,
		c.Amount,
		c.StatusId,
		c.CreatedTime,
		JSON_VALUE(c.ExtraInfo, '$.PromotionID') AS PromotionID,
		c.SiteDBGroupID,
		JSON_VALUE(c.ExtraInfo, '$.FromDate') AS FromDate,
		JSON_VALUE(c.ExtraInfo, '$.ToDate') AS ToDate,
		p.Type AS PromotionType
	FROM dbo.CashTransaction c WITH (NOLOCK)
		INNER JOIN #CashMember ci ON ci.CustId = c.CustId
		INNER JOIN AgencyCashService.dbo.CashPromotion p WITH (NOLOCK) 
			ON p.PromotionID = JSON_VALUE(c.ExtraInfo, '$.PromotionID') 
				AND p.SiteDBGroupID = c.SiteDBGroupID
				AND p.IsSoftDeleted = 0
	WHERE (@Status = -1 OR c.StatusId = @Status)
		AND c.TransactionTypeID = 11 --Promotion
		AND ISNULL(JSON_VALUE(c.ExtraInfo, '$.PromotionID'),0) <> 0
		--filer date range must cover data date range
		AND JSON_VALUE(c.ExtraInfo, '$.FromDate') <= @TDate 
		AND JSON_VALUE(c.ExtraInfo, '$.ToDate') >= @FDate
		AND JSON_VALUE(c.ExtraInfo, '$.FromDate') <= JSON_VALUE(c.ExtraInfo, '$.ToDate')
		AND (@PromotionType IS NULL OR p.Type = @PromotionType)

	--TODO: Result
	IF ((@PageSize <= 0) AND (@PageIndex <= 0))
	BEGIN
		RETURN
	END
	ELSE
	BEGIN
		SELECT @TotalRecords = COUNT(1)
		FROM #CashTransaction_Promotion
	
		SELECT 
			CustId
			,username
			,firstname
			,lastname
			,Amount
			,currency
			,StatusId
			,TransId
			,CreatedTime
			,nickname
			,PromotionID
			,Title
			,PromotionType
			,FromDate
			,ToDate
		FROM (
				SELECT tr.CustId
					,c.username
					,c.firstname
					,c.lastname
					,tr.Amount
					,e.currency
					,tr.StatusId
					,tr.TransId
					,tr.CreatedTime
					,c.username2 AS nickname
					,tr.PromotionID
					,tr.SiteDBGroupID
					,pl.Title
					,tr.FromDate
					,tr.ToDate
					,tr.PromotionType
					,ROW_NUMBER() OVER (ORDER BY tr.transid DESC) AS Rownum
				FROM #CashTransaction_Promotion tr
					INNER JOIN CustDB.dbo.vw_CashService_Customer c WITH (NOLOCK) ON c.custid = tr.CustID
					INNER JOIN CustDB.dbo.exchange e WITH (NOLOCK) ON e.ExchangeId = c.currency
					INNER JOIN AgencyCashService.dbo.CashPromotionLanguage pl WITH (NOLOCK) 
						ON pl.PromotionID = tr.PromotionID 
							AND pl.SiteDBGroupID = tr.SiteDBGroupID
							AND pl.LanguageCode = 'EN'
			) t
		WHERE t.Rownum BETWEEN @RowStart AND @RowEnd
	END

	DROP TABLE #CashTransaction_Promotion
	DROP TABLE #CashMember
END  