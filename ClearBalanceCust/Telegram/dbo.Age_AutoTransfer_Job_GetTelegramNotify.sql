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

    Param's Explanation:

*/
BEGIN
    SET NOCOUNT ON;

    DECLARE @TelegramNotify TABLE (SuperID INT, FromCustID INT, ToCustID INT, [Status] VARCHAR(15), RowID INT, PRIMARY KEY(FromCustID, ToCustID))

	;WITH super_Reach AS
	(
		SELECT rs.SuperID
        FROM Age_ClearBalanceCust_RunningSuper rs WITH (NOLOCK) 
		WHERE rs.TotalBatch = rs.RunningTotal
			AND NOT EXISTS(
					SELECT TOP(1) 1
					FROM dbo.Age_ClearBalanceCust_Process p WITH(NOLOCK) 
					WHERE p.SuperId = rs.SuperId 
						AND p.Environment = @Environment
						AND (
							p.Status IN ('New', 'Waiting', 'Processing') --> Main Thread running
							OR (p.Status IN ('Failed') AND p.TryCount BETWEEN 1 AND 4) --> ReTry Thread running
							OR (p.Status IN ('Pending') AND p.TryCount BETWEEN 1 AND 59) --> TransferUM Pending
						)
					)		
	)
	INSERT INTO @TelegramNotify(SuperID, FromCustID, ToCustID, [Status], RowID)
        SELECT sr.SuperID, t.FromCustID, t.ToCustID, t.[Status], ROW_NUMBER() OVER(PARTITION BY t.FromCustID, t.Status ORDER BY t.ToCustID) RowID
        FROM super_Reach sr 
			CROSS APPLY(
				SELECT FromCustID, ToCustID, [Status]
				FROM Age_ClearBalanceCust_Process p WITH (NOLOCK)
				WHERE p.SuperId = sr.SuperId
					AND p.Environment = @Environment
					AND p.NotifyStatus = 0
					AND p.Status IN ('Failed', 'Cancelled', 'Completed')
			)t

    --Get Telegram notification info
    ;WITH CTE_Notify AS
    (
        SELECT FromCustID, 
            SUM(IIF([Status]='Completed',1,0))  AS Success,
            SUM(IIF([Status]='Cancelled',1,0)) AS Cancelled,
            SUM(IIF([Status]='Failed',1,0)) AS Failed
        FROM @TelegramNotify 
        GROUP BY FromCustID
    )

    SELECT ct.FromCustID, Success, Cancelled, Failed, 
        CASE WHEN Cancelled > 10 THEN CONCAT(CancelledList,',...') ELSE CancelledList END CancelledList, 
        CASE WHEN Failed > 10 THEN CONCAT(FailedList,',...') ELSE FailedList END FailedList
    FROM CTE_Notify ct
    CROSS APPLY
    (
        SELECT STRING_AGG(CONVERT(VARCHAR(MAX),username), ', ') WITHIN GROUP (ORDER BY c.custid) CancelledList
        FROM @TelegramNotify t
            INNER JOIN CustDB.dbo.Customer c ON t.ToCustID = c.custid
        WHERE ct.FromCustID = t.FromCustID
            AND t.[Status] = 'Cancelled'
            AND t.RowID <= 10
    )c
    CROSS APPLY
    (
        SELECT STRING_AGG(CONVERT(VARCHAR(MAX),username), ', ') WITHIN GROUP (ORDER BY c.custid) FailedList
        FROM @TelegramNotify t
			INNER JOIN CustDB.dbo.Customer c ON t.ToCustID = c.custid
        WHERE ct.FromCustID = t.FromCustID
			AND t.[Status] = 'Failed'
			AND t.RowID <= 10
    )f

	WHILE (1=1)
	BEGIN
		UPDATE TOP (500) a
		SET a.NotifyStatus = 1
		FROM dbo.Age_ClearBalanceCust_Process a WITH (ROWLOCK, UPDLOCK)
			INNER JOIN @TelegramNotify s ON a.SuperId = s.SuperID AND a.FromCustId = s.FromCustID AND a.ToCustId = s.ToCustID
		WHERE a.Environment = @Environment
			AND a.NotifyStatus = 0

		IF @@ROWCOUNT = 0
			BREAK
	END
END
GO
