/*<info serverAlias="DBSIC-bodb02,DBCTG-bodb02" executers="bodbDownlineNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE  [dbo].[Age_ClearBalanceCust_Job_GetNotify]
AS
/*
	Created: 20230831@Bobby
	Task: 182071 - Auto Transfer/ Multiple Transfer	
	DB: DBSIC-bodb02,DBCTG-bodb02

	Revisions:
		- 20230831@Bobby: AutoJob clear balance downlines - Notice message [RedmineID: #182071]

	Param's Explanation:

*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @Creator INT;

	SELECT @Creator = custid
	FROM CustDB.dbo.custInfo WITH(NOLOCK) 
	WHERE username = 'StarixIT'
	;

	--TODO: Check line completed with Failed cases
	WITH CTE_SuperReach AS (
		SELECT rs.SuperId 
		FROM (
			SELECT DISTINCT SuperId 
			FROM dbo.Age_ClearBalanceCust_Process p WITH(NOLOCK) 
			WHERE p.[Status] = 'Failed' AND p.IsSyncNotice = 0
		) AS rs 
		CROSS APPLY (
			SELECT 
				SUM(CASE WHEN p.[Status] IN ('New', 'Waiting', 'Processing') THEN 1 ELSE 0 END) AS ActiveCount,
				SUM(CASE WHEN p.[Status] = 'Failed' THEN 1 ELSE 0 END) AS FailedCount,
				SUM(CASE WHEN p.[Status] IN ('Failed', 'Pending') AND err.AllowReTry = 1 AND ISNULL(p.TryCount,0) < tmp.MaxTryCount THEN 1 ELSE 0 END) AS FailedReTry
			FROM dbo.Age_ClearBalanceCust_Process p WITH(NOLOCK)
			LEFT JOIN dbo.f_Age_ClearBalanceCust_ErrorSel() err ON err.ErrType = JSON_VALUE(p.Result, '$.ErrType')
			OUTER APPLY (
				SELECT 
					CASE WHEN err.ErrType = 'TransferUM' THEN 60 ELSE 5 END AS MaxTryCount
			) AS tmp
			WHERE p.SuperId = rs.SuperId
		) AS ck
		WHERE ck.ActiveCount = 0 -- main completed
			AND ck.FailedReTry = 0 -- retry remaining
			AND ck.FailedCount > 0 -- has Failed cases
				
	), 
	CTE_Notify AS (
		SELECT 
			'Age_AutoTransfer_Failed' AS SiteFunctionName,
			p.FromCustId AS TargetId, 
			ft.username AS TargetName,
			COUNT(1) AS UserCount, STRING_AGG(c.username, ', ') AS UserNames
		FROM dbo.Age_ClearBalanceCust_Process p WITH(NOLOCK)
			INNER JOIN CTE_SuperReach sr ON sr.SuperId = p.SuperId
			INNER JOIN CustDB.dbo.Customer c WITH(NOLOCK) ON c.CustId = p.ToCustId
			INNER JOIN CustDB.dbo.Customer ft WITH(NOLOCK) ON ft.CustId = p.FromCustId
		WHERE 
			p.[Status] = 'Failed' 
			AND p.IsSyncNotice = 0
		GROUP BY FromCustId, ft.username
	)
	SELECT nt.*, @Creator AS Creator
	FROM CTE_Notify nt
	ORDER BY nt.TargetId
END
GO