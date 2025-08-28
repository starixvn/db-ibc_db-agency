/*<info serverAlias="DBAGE-bodb02" executers="wsv_CashService" viewers="" isFuntion="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Age_CashPromotion_ManualBonus_Sel]
	@CustID INT,
	@FromDate DATE,
	@ToDate DATE
/*
    Created: 20250807@Kan
    Task: Get Manual Bonus [Redmine: #235012]
    DB: DBAGE-bodb02

	Revisions:
		- 20250807@Kan: Get Manual Bonus - Sprint 8 [Redmine: #235012]
		- 20250820@Kan: Fix remove CAST(t.CreatedTime AS DATE) because it's set index - Sprint 9 [Redmine: #236435]

    Param's Explaination:
		- @CustID: AgentID perform this action
	Sample:
		EXEC [Age_CashPromotion_ManualBonus_Sel]
			@CustId = 233657343,
			@FromDate = '2025/07/10',
			@ToDate = '2025/07/17',
*/
AS
BEGIN
	SET NOCOUNT ON

	--Avoid Parameter Sniffing
	DECLARE @FDate DATE,
		@TDate DATETIME

	SELECT @FDate = @Fromdate,
		@TDate = DATEADD(MS, -3, DATEADD(DAY, 1, DATEDIFF(DAY, 0, @ToDate)));

	CREATE TABLE #CashMember
	(
		custid INT PRIMARY KEY,
		username VARCHAR(30),
		nickname VARCHAR(50),
		firstname NVARCHAR(50),
		lastname NVARCHAR(50)
	)
	INSERT INTO #CashMember
		(custid, username, nickname, firstname, lastname)
	SELECT c.custid, c.username, c.username2, c.firstname, c.lastname
	FROM CustProductStatus s WITH (NOLOCK)
		INNER JOIN Customer c WITH (NOLOCK) ON s.CustID = c.custid AND s.ServiceType = 1
	WHERE c.recommend = @CustId AND c.roleid = 1

	SELECT
		cm.username,
		cm.nickname,
		cm.firstname,
		cm.lastname,
		t.Amount,
		c.username AS Creator,
		t.CreatedTime,
		cs.username AS SubAccName,
		t.StatusId,
		t.Remark,
		t.TransId
	FROM CashTransaction t WITH (NOLOCK)
		INNER JOIN #CashMember cm ON cm.custid = t.CustId
		LEFT JOIN Customer c WITH (NOLOCK) ON t.Creator = c.custid
		LEFT JOIN custSub cs WITH (NOLOCK) ON cs.subaccid = t.SubAccId
	WHERE t.TransactionTypeID = 12 -- Manual Bonus
		AND t.Creator = @CustID
		AND t.CreatedTime BETWEEN @FDate AND @TDate
	ORDER BY t.CreatedTime DESC

	DROP TABLE #CashMember
END
