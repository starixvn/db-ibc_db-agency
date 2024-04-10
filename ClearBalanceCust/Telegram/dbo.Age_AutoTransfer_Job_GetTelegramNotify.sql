/*<info serverAlias="DBSIC-bodb02,DBCTG-bodb02" executers="bodbDownlineNet,wsv_alp" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE  [dbo].[Age_AutoTransfer_Job_GetTelegramNotify]
	@Environment VARCHAR(10) = 'PRO'
AS
/*
    Created: 20240202@Luke
    Task: 195551 - Enhance Auto Transfer Phase 3
    DB: DBSIC-bodb02,DBCTG-bodb02

    Revisions:
        - 20240202@Luke: Enhance Auto Transfer Phase 3 [Redmine: #195551]

    Param's Explanation:

*/
BEGIN
    SET NOCOUNT ON;

    DECLARE @SuperReach TABLE (SuperID INT)
    DECLARE @TelegramNotify TABLE (SuperID INT, FromCustID INT, ToCustID INT, [Status] VARCHAR(15), RowID INT, PRIMARY KEY(FromCustID, ToCustID))
    --Check line completed
    INSERT INTO @SuperReach (SuperID)
        SELECT rs.superid
        FROM (
            SELECT distinct p.Superid
            FROM dbo.Age_ClearBalanceCust_Process p WITH(NOLOCK)
            WHERE p.NotifyStatus = 0 AND Status IN ('Failed', 'Cancelled', 'Completed')
		) AS rs 
        CROSS APPLY (
            SELECT 
				SUM(CASE WHEN p.[Status] IN ('Failed', 'Pending') AND err.AllowReTry = 1 AND ISNULL(p.TryCount,0) < tmp.MaxTryCount THEN 1 
							WHEN p.[Status] IN ('New', 'Waiting', 'Processing') THEN 1 ELSE 0 END) AS FailedReTry
            FROM dbo.Age_ClearBalanceCust_Process p WITH(NOLOCK)
            LEFT JOIN dbo.f_Age_ClearBalanceCust_ErrorSel() err ON err.ErrType = JSON_VALUE(p.Result, '$.ErrType')
            OUTER APPLY (
                SELECT CASE WHEN err.ErrType = 'TransferUM' THEN 60 ELSE 5 END AS MaxTryCount
            ) AS tmp
            WHERE p.SuperId = rs.SuperId
        ) AS ck
        WHERE ck.FailedReTry = 0 -- main completed

	IF @@ROWCOUNT = 0
		RETURN
	
    INSERT INTO @TelegramNotify(SuperID, FromCustID, ToCustID, [Status])
        SELECT p.SuperID, FromCustID, ToCustID, [Status]
        FROM Age_ClearBalanceCust_Process p WITH (ROWLOCK, UPDLOCK)
            INNER JOIN @SuperReach s ON p.SuperId = s.SuperId
		WHERE Environment = @Environment AND Status IN ('Failed', 'Cancelled', 'Completed')

	IF @@ROWCOUNT = 0
		RETURN

    --Add rowid
    ;WITH CTE_update AS
    (
        SELECT SuperID, FromCustID, ToCustID, [Status], ROW_NUMBER() OVER(PARTITION BY FromCustID, Status ORDER BY ToCustID) RowID
        FROM @TelegramNotify
    )
    UPDATE t
    SET t.RowID = ct.RowID 
    FROM @TelegramNotify t INNER JOIN CTE_update ct ON ct.FromCustID = t.FromCustID AND ct.ToCustID = t.ToCustID

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
        SELECT STRING_AGG(username, ', ') WITHIN GROUP (ORDER BY c.custid) CancelledList
        FROM @TelegramNotify t
            INNER JOIN CustDB.dbo.Customer c ON t.ToCustID = c.custid
        WHERE ct.FromCustID = t.FromCustID
            AND t.[Status] = 'Cancelled'
            AND t.RowID <= 10
    )c
    CROSS APPLY
    (
        SELECT STRING_AGG(username, ', ') WITHIN GROUP (ORDER BY c.custid) FailedList
        FROM @TelegramNotify t
			INNER JOIN CustDB.dbo.Customer c ON t.ToCustID = c.custid
        WHERE ct.FromCustID = t.FromCustID
			AND t.[Status] = 'Failed'
			AND t.RowID <= 10
    )f

	WHILE (1=1)
	BEGIN
		UPDATE TOP (5000) a
		SET a.NotifyStatus = 1
		FROM dbo.Age_ClearBalanceCust_Process a WITH (ROWLOCK, UPDLOCK)
			INNER JOIN @TelegramNotify s ON a.FromCustId = s.FromCustID AND a.ToCustId = s.ToCustID
		WHERE a.NotifyStatus = 0

		IF @@ROWCOUNT = 0
			BREAK
	END
END
GO
