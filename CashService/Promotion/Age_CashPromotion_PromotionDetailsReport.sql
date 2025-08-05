/*<info serverAlias="DBAGE-bodb02" executers="wsv_CashService" viewers="" isFuntion="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Age_CashPromotion_PromotionDetailsReport]
	@CustID INT,
	@PromotionID INT,
	@FromDate DATE,
	@ToDate DATE,
	@StatusID TINYINT = NULL
/*
    Created: 20250716@Kan
    Task: Get Promotion Report - Exclude Pending Promotion [Redmine: #232347]
    DB: DBAGE-bodb02

	Revisions:
		- 20250716@Kan: Alpha - Agency Cash Service - Sprint 6 [Redmine: #232347]

    Param's Explaination:
		- @CustID: AgentID perform this ation
		- @StatusID:
			NULL: All
			2: Pending
			4: Approved
			5: Rejected
	Sample:
		EXEC [Age_CashPromotion_PromotionDetailsReport]
			@CustId = 233657343,
			@PromotionID = 1,
			@Fromdate = '2025/07/10',
			@Todate = '2025/07/17',
			@StatusID = NULL
*/
AS
BEGIN
	SET NOCOUNT ON

	--Avoid Parameter Sniffing
	DECLARE @FDate DATE,
		@TDate DATE

	SELECT @FDate = @Fromdate,
		@TDate = @Todate

	CREATE TABLE #CashMember
	(
		custid INT PRIMARY KEY,
		username VARCHAR(30),
		nickname VARCHAR(50),
		firstname NVARCHAR(50),
		lastname NVARCHAR(50)
	)
	INSERT INTO #CashMember
		(custid, username, nickname, firstname, lastname)
	SELECT c.custid, c.username, c.username2, c.firstname, c.lastname
	FROM CustProductStatus s WITH (NOLOCK)
		INNER JOIN Customer c WITH (NOLOCK) ON s.CustID = c.custid AND s.ServiceType = 1
	WHERE c.recommend = @CustId AND c.roleid = 1

	CREATE TABLE #PromotionDetails
	(
		username VARCHAR(30),
		nickname VARCHAR(50),
		firstname NVARCHAR(50),
		lastname NVARCHAR(50),
		FromDate VARCHAR(10),
		ToDate VARCHAR(10),
		Amount MONEY,
		OperatedBy VARCHAR(30),
		OperatedTime DATETIME,
		SubAccName VARCHAR(30),
		StatusId TINYINT
	)
	INSERT INTO #PromotionDetails
		(username, nickname, firstname, lastname, FromDate, ToDate, Amount, OperatedBy, OperatedTime, SubAccName, StatusId)
	SELECT
		cm.username,
		cm.nickname,
		cm.firstname,
		cm.lastname,
		JSON_VALUE(t.ExtraInfo, '$.FromDate') AS FromDate,
		JSON_VALUE(t.ExtraInfo, '$.ToDate') AS ToDate,
		t.Amount,
		c.username AS OperatedBy,
		t.OperatedTime,
		cs.username AS SubAccName,
		t.StatusId
	FROM CashTransaction t WITH (NOLOCK)
		INNER JOIN #CashMember cm ON cm.custid = t.CustId
		LEFT JOIN Customer c WITH (NOLOCK) ON t.OperatedBy = c.custid
		LEFT JOIN custSub cs WITH (NOLOCK) ON cs.subaccid = t.SubAccId
	WHERE t.TransactionTypeID = 11 -- Promotion
		AND ISNULL(JSON_VALUE(t.ExtraInfo, '$.PromotionID'), 0) = @PromotionID
		AND (@StatusID IS NULL OR t.StatusId = @StatusId)
		--filer date range must cover data date range
		AND JSON_VALUE(t.ExtraInfo, '$.FromDate') <= @TDate
		AND JSON_VALUE(t.ExtraInfo, '$.ToDate') >= @FDate
		AND JSON_VALUE(t.ExtraInfo, '$.FromDate') <= JSON_VALUE(t.ExtraInfo, '$.ToDate')

	SELECT *
	FROM #PromotionDetails
	SELECT
		ISNULL(SUM(CASE WHEN StatusId = 4 THEN 1 ELSE 0 END), 0) AS TotalApproved,
		ISNULL(SUM(CASE WHEN StatusId = 5 THEN 1 ELSE 0 END), 0) AS TotalRejected,
		ISNULL(SUM(CASE WHEN StatusId = 4 THEN Amount ELSE 0 END), 0) AS TotalAmount
	FROM #PromotionDetails
	WHERE StatusId <> 2
	-- Pending

	DROP TABLE #CashMember
	DROP TABLE #PromotionDetails
END
