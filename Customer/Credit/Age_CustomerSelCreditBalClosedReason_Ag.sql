/*<info serverAlias="DBCUST-CustDB" executers="bodbDownlineNet,bodbDownlineNetView" viewers="" isFunction="0" isNested="0"></info>*/
USE [CustDB]
GO

/****** Object:  StoredProcedure [dbo].[Age_CustomerSelCreditBalClosedReason_Ag]    Script Date: 7/23/2018 8:54:38 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[Age_CustomerSelCreditBalClosedReason_Ag]
	@CustID		INT,
	@PageSize	INT = 500,
	@PageIndex	INT = 1,
	@Username	VARCHAR(30) = NULL,
	@Enabled	BIT = NULL,
	@Closed		BIT = NULL,
	@Suspended	BIT = NULL
AS
/*
	Task : Credit/Balance of Agent
	DB: DBCUST/CustDB
	Original: 

	Revisions:
		- 20180720@Paul: Create new, splitted from DBAGE.bodb02.Age_CustomerSelCreditBalanceList_Ag [Redmine: #97678]

*/
BEGIN
	SET NOCOUNT ON

	DECLARE @RowStart INT, @RowEnd INT
	SELECT @PageIndex = @PageIndex - 1, @RowStart = @PageSize * @PageIndex + 1, @RowEnd = @RowStart + @PageSize - 1

	IF @Username = ''
		SELECT TOP (@PageSize) custid, ISNULL(ClosedReason, 0) AS ClosedReason
		FROM (
			SELECT ROW_NUMBER() OVER (
					ORDER BY ci.enabled DESC
						,ci.closed
						,isnull(ci.reject, 0)
						,ci.username
					) AS RowNumber
				,ci.custid
				,m.ClosedReason
			FROM dbo.CustInfo AS ci WITH (NOLOCK)
				JOIN dbo.CustLoginInfo_Member m WITH(NOLOCK) ON m.CustID = ci.custid
			WHERE 1 = ci.roleid AND @CustID = ci.recommend AND enabled = CASE 
					WHEN coalesce(@Closed, @Suspended) IS NOT NULL THEN 1
					ELSE coalesce(@enabled, enabled)
					END AND isnull(ci.closed, 0) = CASE 
					WHEN @suspended = 1 THEN 0
					ELSE coalesce(@closed, isnull(ci.closed, 0))
					END AND isnull(ci.reject, 0) = CASE 
					WHEN @Closed = 0 THEN 0
					ELSE coalesce(@suspended, isnull(ci.reject, 0))
					END
		) a
		WHERE a.RowNumber BETWEEN @RowStart AND @RowEND
	ELSE
		SELECT TOP (@PageSize) custid, ISNULL(ClosedReason, 0) AS ClosedReason
		FROM (
			SELECT ROW_NUMBER() OVER (
					ORDER BY ci.enabled DESC
						,ci.closed
						,isnull(ci.reject, 0)
						,ci.username
					) AS RowNumber
				,ci.custid
				,m.ClosedReason
			FROM dbo.CustInfo AS ci WITH (NOLOCK)
				JOIN dbo.CustLoginInfo_Member m WITH(NOLOCK) ON m.CustID = ci.custid
			WHERE 1 = ci.roleid AND @CustID = ci.recommend AND ci.username LIKE '%' + @Username + '%' AND enabled = CASE 
					WHEN coalesce(@Closed, @Suspended) IS NOT NULL THEN 1
					ELSE coalesce(@enabled, enabled)
					END AND isnull(ci.closed, 0) = CASE 
					WHEN @suspended = 1 THEN 0
					ELSE coalesce(@closed, isnull(ci.closed, 0))
					END AND isnull(ci.reject, 0) = CASE 
					WHEN @Closed = 0 THEN 0
					ELSE coalesce(@suspended, isnull(ci.reject, 0))
					END
		) a
		WHERE a.RowNumber BETWEEN @RowStart AND @RowEND

	SET NOCOUNT OFF
END

GO

GRANT EXECUTE ON [dbo].[Age_CustomerSelCreditBalClosedReason_Ag] TO [bodbDownlineNet] AS [dbo]
GO

GRANT EXECUTE ON [dbo].[Age_CustomerSelCreditBalClosedReason_Ag] TO [bodbDownlineNetView] AS [dbo]
GO


