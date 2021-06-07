/*<info serverAlias="DBCUST-CustDB" executers="bodbDownlineNet,bodbDownlineNetView" viewers="" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Age_CustomerSelCreditBalClosedReason_Ag]
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
		- 20210603@Sol: Alpha - All Sites - Lock account & indirect close account - [RedmineID: #148600]

*/
BEGIN
	SET NOCOUNT ON

	DECLARE @RowStart INT, @RowEnd INT
	SELECT @PageIndex = @PageIndex - 1, @RowStart = @PageSize * @PageIndex + 1, @RowEnd = @RowStart + @PageSize - 1

	SET @Username = ISNULL(@Username, '')

	IF @Username = ''
		SELECT TOP (@PageSize) custid, ISNULL(ClosedReason, 0) AS ClosedReason, a.Locked
		FROM (
			SELECT	ROW_NUMBER() OVER (
					ORDER BY ci.enabled DESC
						,cs.IsClosed
						,cs.IsSuspended
						,ci.username
					) AS RowNumber,
					ci.custid,
					m.ClosedReason,
					cs.IsClosed,
					cs.Locked
			FROM dbo.CustInfo AS ci WITH (NOLOCK, INDEX = IX_custinfo_1)
				INNER JOIN dbo.CustLoginInfo_Member m WITH(NOLOCK) ON m.CustID = ci.custid
				CROSS APPLY  
				(
					SELECT 
						CASE WHEN CloseInfo > 0 THEN 1 ELSE 0 END AS IsClosed
						, CASE WHEN SuspendInfo > 0 THEN 1 ELSE 0 END AS IsSuspended
						, ISNULL(Locked, 0) AS Locked
					FROM dbo.CustProductStatus cs WITH(NOLOCK)
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
			AND a.Locked = 1
	ELSE
		SELECT TOP (@PageSize) custid, ISNULL(ClosedReason, 0) AS ClosedReason, a.Locked
		FROM (
			SELECT ROW_NUMBER() OVER (
					ORDER BY ci.enabled DESC
						,cs.IsClosed
						,cs.IsSuspended
						,ci.username
					) AS RowNumber,
					ci.custid,
					m.ClosedReason,
					cs.IsClosed,
					cs.Locked
			FROM dbo.CustInfo AS ci WITH (NOLOCK, INDEX = IX_custinfo_1)
				INNER JOIN dbo.CustLoginInfo_Member m WITH(NOLOCK) ON m.CustID = ci.custid
				CROSS APPLY  
				(
					SELECT 
						CASE WHEN CloseInfo > 0 THEN 1 ELSE 0 END AS IsClosed
						, CASE WHEN SuspendInfo > 0 THEN 1 ELSE 0 END AS IsSuspended
						, ISNULL(Locked, 0) AS Locked
					FROM dbo.CustProductStatus cs WITH(NOLOCK)
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
			AND a.IsClosed = 1

	SET NOCOUNT OFF
END

GO