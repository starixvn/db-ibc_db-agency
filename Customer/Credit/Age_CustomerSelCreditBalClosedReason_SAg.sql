/*<info serverAlias="DBCUST-CustDB" executers="wsv_alp,wsv_alpv" viewers="" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Age_CustomerSelCreditBalClosedReason_SAg]
	@CustID		INT,
	@PageSize	INT = 500,
	@PageIndex	INT = 1,
	@Username	VARCHAR(30) = NULL,
	@Enabled	BIT = NULL,
	@Closed		BIT = NULL,
	@Suspended	BIT = NULL,
	@LevelType TINYINT = 0
AS
/*
	Task : Credit/Balance of Agent
	DB: DBCUST/CustDB
	Original: 

	Revisions:
		- 20180802@Paul: Create new, splitted from DBAGE.bodb02.Age_CustomerSelCreditBalanceList_SAg [Redmine: #97678]
		- 20210603@Sol: Alpha - All Sites - Lock account & indirect close account - [RedmineID: #148600]
		- 20250402@Eden: Enhance sp [redmine: #222752]
		- 20241107@Helios: Offer Direct Member for Super/Master [redmine: #211969] 
	@LevelType: 0: All; 1: Master Agent/ Agent; 2: Direct Member
		0 : get ALL (RoleID = 3) OR (RoleID = 1 AND Recommend = -4)
		1 : get Master (RoleID = 3) 
		2 : get SuperDirectMember (RoleID = 1 AND Recommend = -4)

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
					m.ClosedReason AS ClosedReason,
					cs.IsClosed,
					cs.Locked
			FROM dbo.CustInfo AS ci WITH (NOLOCK, INDEX = IX_srecommend)
				CROSS APPLY (	SELECT TOP 1 ClosedReason
							 FROM CustLoginInfo mt WITH (NOLOCK)
							 where ci.custid = mt.CustID and ci.roleid = 3
							 UNION ALL
							 SELECT TOP 1 ClosedReason
							 FROM CustLoginInfo_Member mb WITH (NOLOCK)
							 where ci.custid = mb.CustID and ci.roleid = 1 and ci.recommend = -4
							 ) AS m
				CROSS APPLY  
				(
					SELECT TOP 1
						CASE WHEN CloseInfo > 0 THEN 1 ELSE 0 END AS IsClosed
						, CASE WHEN SuspendInfo > 0 THEN 1 ELSE 0 END AS IsSuspended
						, ISNULL(Locked, 0) AS Locked
					FROM CustDB.dbo.CustProductStatus cs WITH(NOLOCK)
					WHERE cs.CustID = ci.custid
				) AS cs
			WHERE ci.srecommend = @CustID 
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
				AND 1 = CASE 
						WHEN (@LevelType = 1 AND ci.roleid = 3) THEN 1
						WHEN (@LevelType = 2 AND ci.roleid = 1 AND ci.recommend = -4) THEN  1
						WHEN (@LevelType = 0) AND ((ci.roleid = 3) OR (ci.roleid = 1 AND ci.recommend = -4)) THEN  1
					  ELSE 0
					 END 
		) a
		WHERE a.RowNumber BETWEEN @RowStart AND @RowEND
			AND a.IsClosed = 1
	ELSE
		SELECT TOP (@PageSize) custid, ISNULL(ClosedReason, 0) AS ClosedReason
		FROM (
			SELECT	ROW_NUMBER() OVER (
						ORDER BY ci.enabled DESC
							,cs.IsClosed
							,cs.IsSuspended
							,ci.username
					) AS RowNumber,
					ci.custid,
					m.ClosedReason AS ClosedReason,
					cs.IsClosed,
					cs.Locked
			FROM dbo.CustInfo AS ci WITH (NOLOCK, INDEX = IX_srecommend)
				CROSS APPLY (	SELECT TOP 1 ClosedReason
							 FROM CustLoginInfo mt WITH (NOLOCK)
							 where ci.custid = mt.CustID and ci.roleid = 3
							 UNION ALL
							 SELECT TOP 1 ClosedReason
							 FROM CustLoginInfo_Member mb WITH (NOLOCK)
							 where ci.custid = mb.CustID and ci.roleid = 1 and ci.recommend = -4
							 ) AS m
				CROSS APPLY  
				(
					SELECT TOP 1
						CASE WHEN CloseInfo > 0 THEN 1 ELSE 0 END AS IsClosed
						, CASE WHEN SuspendInfo > 0 THEN 1 ELSE 0 END AS IsSuspended
						, ISNULL(Locked, 0) AS Locked
					FROM CustDB.dbo.CustProductStatus cs WITH(NOLOCK)
					WHERE cs.CustID = ci.custid
				) AS cs
			WHERE ci.srecommend = @CustID
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
				AND 1 = CASE 
						WHEN (@LevelType = 1 AND ci.roleid = 3) THEN 1
						WHEN (@LevelType = 2 AND ci.roleid = 1 AND ci.recommend = -4) THEN  1
						WHEN (@LevelType = 0) AND ((ci.roleid = 3) OR (ci.roleid = 1 AND ci.recommend = -4)) THEN  1
					  ELSE 0
					  END
		) a
		WHERE a.RowNumber BETWEEN @RowStart AND @RowEND
			AND a.IsClosed = 1
	SET NOCOUNT OFF
END

GO

