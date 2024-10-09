/*<info serverAlias="DBSIC-bodb02,DBCTG-bodb02" executers="wsv_alp" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE  [dbo].[Age_AutoTransfer_Job_GetTelegramNotify]
	@Environment VARCHAR(10) = 'PRO'
AS
/*
    Created: 20240202@Luke
    Task: 195551 - Enhance Auto Transfer Phase 3
    DB: DBSIC-bodb02,DBCTG-bodb02

    Revisions:
        - 20240202@Luke: Enhance Auto Transfer Phase 3 [Redmine: #195551]
		- 20240424@Luke: Improve auto transfer sp job to avoid deadlock [Redmine: #204349]
		- 20240823@Bobby: Avoid deadlock with main thread [Redmine: #209565]

    Param's Explanation:

*/
BEGIN
    SET NOCOUNT ON;

    DROP TABLE IF EXISTS #TelegramNotify; 
	CREATE TABLE #TelegramNotify (SuperID INT, FromCustID INT, ToCustID INT, [Status] VARCHAR(15), PRIMARY KEY(FromCustID, ToCustID))

	--- SET notify on completed supers
	;WITH super_Reach AS
	(
		SELECT rs.SuperID
        FROM dbo.Age_ClearBalanceCust_RunningSuper rs WITH (ROWLOCK)
		WHERE rs.TotalBatch = rs.RunningTotal --- completed batch by main thread
			AND rs.RunningBatchNo = 0 -- without running reTry If any
			AND NOT EXISTS(
				SELECT TOP(1) 1
				FROM dbo.Age_ClearBalanceCust_Process p WITH(NOLOCK) 
				LEFT JOIN dbo.f_Age_ClearBalanceCust_ErrorSel() err ON err.ErrType = JSON_VALUE(p.Result, '$.ErrType')
				WHERE p.SuperId = rs.SuperId 
					AND p.Environment = @Environment
					AND 
					(
						p.Status IN ('New', 'Waiting', 'Processing') --> Main Thread running
						OR (err.AllowReTry = 1 AND p.Status IN ('Failed') AND p.TryCount BETWEEN 1 AND 4) --> ReTry Thread running
						OR (err.AllowReTry = 1 AND err.ErrType = 'TransferUM' AND p.Status IN ('Pending') AND ISNULL(p.TryCount, 1) BETWEEN 1 AND 59) --> TransferUM Pending
						OR p.NotifyStatus = 1 --- done notification
					)
				)
	)
	UPDATE p WITH(ROWLOCK, UPDLOCK)
	SET p.NotifyStatus = 1
	OUTPUT INSERTED.SuperID, INSERTED.FromCustId, INSERTED.ToCustId, INSERTED.[Status]
	INTO #TelegramNotify (SuperID, FromCustId, ToCustId, [Status])
	FROM dbo.Age_ClearBalanceCust_Process p
		INNER JOIn super_Reach sr ON p.SuperId = sr.SuperId
	WHERE 
		p.Environment = @Environment
		AND p.NotifyStatus = 0
		AND p.[Status] IN ('Failed', 'Cancelled', 'Completed')
	;

	--TODO: Send notify information
	;WITH CTE_TelegramNotify AS (
		SELECT t.SuperID, t.FromCustID, t.ToCustID, t.[Status]
			, ROW_NUMBER() OVER(PARTITION BY t.FromCustID, t.[Status] ORDER BY t.ToCustID) RowID
		FROM #TelegramNotify t
	),
	CTE_Notify AS
    (
        SELECT FromCustID, 
            SUM(IIF([Status]='Completed',1,0))  AS Success,
            SUM(IIF([Status]='Cancelled',1,0)) AS Cancelled,
            SUM(IIF([Status]='Failed',1,0)) AS Failed
        FROM CTE_TelegramNotify 
        GROUP BY FromCustID
    )
    SELECT ct.FromCustID, ct.Success, ct.Cancelled, ct.Failed, 
        CASE WHEN ct.Cancelled > 10 THEN CONCAT(c.CancelledList,',...') ELSE c.CancelledList END CancelledList, 
        CASE WHEN ct.Failed > 10 THEN CONCAT(c.FailedList,',...') ELSE c.FailedList END FailedList
    FROM CTE_Notify ct
    CROSS APPLY
    (
        SELECT 
			STRING_AGG(CONVERT(VARCHAR(MAX), IIF([Status]='Cancelled', c.username, NULL)), ', ') WITHIN GROUP (ORDER BY c.custid) CancelledList,
			STRING_AGG(CONVERT(VARCHAR(MAX), IIF([Status]='Failed', c.username, NULL)), ', ') WITHIN GROUP (ORDER BY c.custid) FailedList
        FROM CTE_TelegramNotify t
            INNER JOIN CustDB.dbo.Customer c ON t.ToCustID = c.custid
        WHERE ct.FromCustID = t.FromCustID
            AND t.[Status]  IN ( 'Cancelled', 'Failed')
            AND t.RowID <= 10
    ) AS c
END
GO
