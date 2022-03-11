/*<info serverAlias="DBTXN-bodb02" executers="bodbDownlineNet,bodbDownlineNetView" viewers="" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Age_CustomerSelCreditBalNetPosition_Ag]
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
		- 20210603@Sol: Alpha - All Sites - Lock account & indirect close account - [RedmineID: #148600]
		- 20220310@Percy: Use SELECT TOP (1) on CROSS APPLY statement [RedmineID: #169687]

*/
BEGIN
	SET NOCOUNT ON

	CREATE TABLE #tmp_customer
	(
		[custid]		INT PRIMARY KEY,
		Locked			TINYINT
	)

	DECLARE @RowStart INT, @RowEnd INT
	SELECT @PageIndex = @PageIndex - 1, @RowStart = @PageSize * @PageIndex + 1, @RowEnd = @RowStart + @PageSize - 1

	IF @Username = ''
		INSERT INTO #tmp_customer (custid, Locked)
		SELECT TOP (@PageSize) custid, a.Locked
		FROM (
			SELECT ROW_NUMBER() OVER (
					ORDER BY ci.enabled DESC
						,cs.IsClosed
						,cs.IsSuspended
						,ci.username
					) AS RowNumber
				,ci.custid
				,cs.Locked
			FROM CustDB.dbo.CustInfo AS ci WITH (NOLOCK, INDEX = IX_custinfo_1)
				CROSS APPLY  
				(
					SELECT TOP (1)
						CASE WHEN CloseInfo > 0 THEN 1 ELSE 0 END AS IsClosed
						, CASE WHEN SuspendInfo > 0 THEN 1 ELSE 0 END AS IsSuspended
						, ISNULL(Locked, 0) AS Locked
					FROM CustDB.dbo.CustProductStatus cs WITH(NOLOCK)
					WHERE cs.CustID = ci.custid
				) AS cs
			WHERE ci.roleid = 1 AND ci.recommend = @CustID
				AND enabled = CASE 
						WHEN coalesce(@Closed, @Suspended) IS NOT NULL THEN 1
						ELSE coalesce(@enabled, enabled)
					END
				AND isnull(cs.IsClosed, 0) = CASE 
						WHEN @suspended = 1 THEN 0
						ELSE coalesce(@closed, isnull(cs.IsClosed, 0))
					END
				AND isnull(cs.IsSuspended, 0) = CASE 
						WHEN @Closed = 0 THEN 0
						ELSE coalesce(@suspended, isnull(cs.IsSuspended, 0))
					END
		) a
		WHERE a.RowNumber BETWEEN @RowStart AND @RowEND
	ELSE
		INSERT INTO #tmp_customer (custid, Locked)
		SELECT TOP (@PageSize) custid, a.Locked
		FROM (
			SELECT ROW_NUMBER() OVER (
					ORDER BY ci.enabled DESC
						,cs.IsClosed
						,cs.IsSuspended
						,ci.username
					) AS RowNumber
				,ci.custid
				,cs.Locked
			FROM CustDB.dbo.CustInfo AS ci WITH (NOLOCK, INDEX = IX_custinfo_1)
				CROSS APPLY  
				(
					SELECT TOP (1)
						CASE WHEN CloseInfo > 0 THEN 1 ELSE 0 END AS IsClosed
						, CASE WHEN SuspendInfo > 0 THEN 1 ELSE 0 END AS IsSuspended
						, ISNULL(Locked, 0) AS Locked
					FROM CustDB.dbo.CustProductStatus cs WITH(NOLOCK)
					WHERE cs.CustID = ci.custid
				) AS cs
			WHERE ci.roleid = 1 AND ci.recommend = @CustID
				AND ci.username LIKE '%' + @Username + '%'
				AND enabled = CASE 
						WHEN coalesce(@Closed, @Suspended) IS NOT NULL THEN 1
						ELSE coalesce(@enabled, enabled)
					END
				AND isnull(cs.IsClosed, 0) = CASE 
						WHEN @suspended = 1 THEN 0
						ELSE coalesce(@closed, isnull(cs.IsClosed, 0))
					END
				AND isnull(cs.IsSuspended, 0) = CASE 
						WHEN @Closed = 0 THEN 0
						ELSE coalesce(@suspended, isnull(cs.IsSuspended, 0))
					END
		) a
		WHERE a.RowNumber BETWEEN @RowStart AND @RowEND

	SELECT TC.custid,
		ISNULL(SUM(NP.Credit - NP.Debit), 0) AS netPosition,
		tc.Locked
	FROM dbo.BalNetPosition NP WITH (NOLOCK)
		INNER JOIN #tmp_customer TC ON NP.custid = TC.custid
	GROUP BY TC.custid, tc.Locked

	DROP TABLE #tmp_customer

	SET NOCOUNT OFF
END

GO


