/*<info serverAlias="DBAGE-bodb02" executers="wsv_CashService" viewers="" isFuntion="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Age_CashTransaction_PendingCount]
    @CustID INT,
    @TypeId TINYINT = 1
/*
    Created: 20250728@Kan
    Task: Cash Transaction - Count pending transaction [Redmine: #233481]
    DB: DBAGE-bodb02

	Revisions:
		- 20250728@Kan: Alpha - Agency Cash Service - Sprint 7 [Redmine: #233481]

    Param's Explaination:
		- @CustID: AgentID perform this ation
		- @TypeId:
			1: Pending Transaction (Deposit, Withdraw)
			2: Pending Promotion
	Sample:
		EXEC [Age_CashTransaction_PendingCount]
			@CustId = 233657343,
			@TypeId = 1
*/
AS
BEGIN
    SET NOCOUNT ON

    CREATE TABLE #CashMember
    (
        custid INT PRIMARY KEY
    )
    INSERT INTO #CashMember
        (custid)
    SELECT c.custid
    FROM CustProductStatus s WITH (NOLOCK)
        INNER JOIN Customer c WITH (NOLOCK) ON s.CustID = c.custid AND s.ServiceType = 1
    WHERE c.recommend = @CustId AND c.roleid = 1

    IF @TypeId = 1
    BEGIN
        SELECT
            COUNT(CASE WHEN TransactionTypeID IN (1, 2) THEN 1 END) AS PendingDeposit,
            COUNT(CASE WHEN TransactionTypeID IN (3, 4) THEN 1 END) AS PendingWithdrawal
        FROM CashTransaction t WITH (NOLOCK)
            INNER JOIN #CashMember cm ON cm.custid = t.CustId
        WHERE t.TransactionTypeID IN (1,2,3,4)
            AND t.StatusId = 2
    -- Pending
    END
    ELSE IF @TypeId = 2
    BEGIN
        SELECT COUNT(1) AS PendingPromotion
        FROM CashTransaction t WITH (NOLOCK)
            INNER JOIN #CashMember cm ON cm.custid = t.CustId
            INNER JOIN AgencyCashService.dbo.CashPromotion p WITH (NOLOCK)
            ON p.PromotionID = JSON_VALUE(t.ExtraInfo, '$.PromotionID')
                AND p.SiteDBGroupID = t.SiteDBGroupID
                AND p.IsSoftDeleted = 0
        WHERE t.TransactionTypeID = 11 -- Promotion
            AND t.StatusId = 2 -- Pending
            AND ISNULL(JSON_VALUE(t.ExtraInfo, '$.PromotionID'),0) <> 0
    END

    DROP TABLE #CashMember
END
