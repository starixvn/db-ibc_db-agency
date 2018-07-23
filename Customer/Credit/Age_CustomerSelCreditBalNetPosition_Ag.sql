/*<info serverAlias="DBTXN-bodb02" executers="bodbDownlineNet,bodbDownlineNetView" viewers="" isFunction="0" isNested="0"></info>*/
USE [bodb02]
GO

/****** Object:  StoredProcedure [dbo].[Age_CustomerSelCreditBalNetPosition_Ag]    Script Date: 7/23/2018 8:36:52 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[Age_CustomerSelCreditBalNetPosition_Ag]
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
	DB: DBTXN/bodb02
	Original: 

	Revisions:
		- 20180720@Paul: Create new, splitted from DBAGE.bodb02.Age_CustomerSelCreditBalanceList_Ag [Redmine: #97678]

*/
BEGIN
	SET NOCOUNT ON

	CREATE TABLE #tmp_customer
	(
		[custid]		INT PRIMARY KEY
	)

	DECLARE @RowStart INT, @RowEnd INT
	SELECT @PageIndex = @PageIndex - 1, @RowStart = @PageSize * @PageIndex + 1, @RowEnd = @RowStart + @PageSize - 1

	IF @Username = ''
		INSERT INTO #tmp_customer (custid)
		SELECT TOP (@PageSize) custid
		FROM (
			SELECT ROW_NUMBER() OVER (
					ORDER BY ci.enabled DESC
						,ci.closed
						,isnull(ci.reject, 0)
						,ci.username
					) AS RowNumber
				,ci.custid
			FROM CustDB.dbo.CustInfo AS ci WITH (NOLOCK)
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
		INSERT INTO #tmp_customer (custid)
		SELECT TOP (@PageSize) custid
		FROM (
			SELECT ROW_NUMBER() OVER (
					ORDER BY ci.enabled DESC
						,ci.closed
						,isnull(ci.reject, 0)
						,ci.username
					) AS RowNumber
				,ci.custid
			FROM CustDB.dbo.CustInfo AS ci WITH (NOLOCK)
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

	SELECT TC.custid,
		ISNULL(SUM(NP.Credit - NP.Debit), 0) AS netPosition
	FROM dbo.BalNetPosition NP WITH (NOLOCK)
		INNER JOIN #tmp_customer TC ON NP.custid = TC.custid
	GROUP BY TC.custid

	DROP TABLE #tmp_customer

	SET NOCOUNT OFF
END

GO

GRANT EXECUTE ON [dbo].[Age_CustomerSelCreditBalNetPosition_Ag] TO [bodbDownlineNet] AS [dbo]
GO

GRANT EXECUTE ON [dbo].[Age_CustomerSelCreditBalNetPosition_Ag] TO [bodbDownlineNetView] AS [dbo]
GO


