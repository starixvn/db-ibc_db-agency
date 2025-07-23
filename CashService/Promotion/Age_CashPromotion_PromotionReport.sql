/*<info serverAlias="DBAGE-bodb02" executers="wsv_CashService" viewers="" isFuntion="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Age_CashPromotion_PromotionReport]
	@CustID INT,
	@FromDate DATE,
	@ToDate DATE,
	@PromotionType TINYINT = NULL,
	@StatusID BIT = NULL
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
			1: Enabled
			0: Disabled
	Sample:
		EXEC [Age_CashPromotion_PromotionReport]
			@CustId = 233657343,
			@Fromdate = '2025/07/10',
			@Todate = '2025/07/17',
			@PromotionType = NULL,
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
		CustId INT PRIMARY KEY
	)
	INSERT INTO #CashMember
		(CustId)
	SELECT c.custid
	FROM CustProductStatus s WITH (NOLOCK)
		INNER JOIN Customer c WITH (NOLOCK) ON s.CustID = c.custid AND s.ServiceType = 1
	WHERE c.recommend = @CustId AND c.roleid = 1

	SELECT
		p.PromotionID,
		MAX(pl.Title) AS PromotionTitle,
		MAX(p.Type) AS PromotionType,
		MAX(p.FromDate) AS FromDate,
		MAX(p.ToDate) AS ToDate,
		MAX(CAST(p.Enabled AS TINYINT)) AS Enabled,
		MAX(CAST(p.IsSoftDeleted AS TINYINT)) AS IsSoftDeleted,
		SUM(CASE WHEN t.StatusId IN (2, 4, 5) AND cm.CustId IS NOT NULL THEN 1 ELSE 0 END) AS TotalRequest,
		SUM(CASE WHEN t.StatusId = 4 AND cm.CustId IS NOT NULL THEN 1 ELSE 0 END) AS TotalApproved,
		SUM(CASE WHEN t.StatusId = 5 AND cm.CustId IS NOT NULL THEN 1 ELSE 0 END) AS TotalRejected,
		SUM(CASE WHEN t.StatusId = 4 AND cm.CustId IS NOT NULL THEN t.Amount ELSE 0 END) AS TotalAmount
	FROM AgencyCashService.dbo.CashPromotion p WITH (NOLOCK)
		INNER JOIN AgencyCashService.dbo.CashPromotionLanguage pl WITH (NOLOCK) ON p.PromotionID = pl.PromotionID
		LEFT JOIN CashTransaction t WITH (NOLOCK)
		ON p.PromotionID = JSON_VALUE(t.ExtraInfo, '$.PromotionID')
			AND p.SiteDBGroupID = t.SiteDBGroupID
			AND t.TransactionTypeID = 11 -- Promotion
			AND ISNULL(JSON_VALUE(t.ExtraInfo, '$.PromotionID'), 0) <> 0
		LEFT JOIN #CashMember cm ON cm.CustId = t.CustId
	WHERE
		p.AgentID = @CustID
		AND pl.LanguageCode = 'EN'
		AND (@PromotionType IS NULL OR p.Type = @PromotionType)
		AND (@StatusID IS NULL OR p.Enabled = @StatusId)
		--filer date range must cover data date range
		AND p.FromDate <= @TDate
		AND p.ToDate >= @FDate
		AND p.FromDate <= p.ToDate
	GROUP BY
        p.PromotionID,
		p.SiteDBGroupID
	ORDER BY
        PromotionTitle,
        Enabled DESC,
		IsSoftDeleted

	DROP TABLE #CashMember
END
