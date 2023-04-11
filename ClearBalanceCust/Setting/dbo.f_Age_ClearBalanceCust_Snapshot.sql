/*<info serverAlias="DBCUST-CustDB" selecters="bodbDownlineNet" isFunction="1" isNested="1"></info>*/
ALTER FUNCTION dbo.f_Age_ClearBalanceCust_Snapshot() 
RETURNS TABLE
RETURN
/*
	Created:20230227@Bobby
	Task: 182071 - Auto Transfer/ Multiple Transfer	
	DB: DBTXN/bodb02

	Revisions:
		- 20230227@Bobby: AutoJob clear balance downlines [RedmineID: #182071]

*/
WITH CTE_Setting AS (
	SELECT DISTINCT c.roleid, s.FromCustID, CAST(GETDATE() AS DATE) AS SessionDate
	FROM CustDB.dbo.Age_ClearBalanceCust_Setting s WITH(NOLOCK)
	INNER JOIN CustDB.dbo.Customer c WITH(NOLOCK) ON c.custid =  s.FromCustId
),
CTE_SMASetting AS (
	SELECT tmp.SessionDate, ca.custid AS FromCustId, tmp.RoleId, ca.TransferOption,cm.IsAllDayBalTransfer
	FROM CustDB.dbo.CustAgent ca WITH (NOLOCK)
		INNER JOIN CTE_Setting tmp ON tmp.FromCustId = ca.custid
		INNER JOIN CustDB.dbo.Customer c WITH (NOLOCK) ON c.custid = ca.custid
		INNER JOIN CustDB.dbo.CustMaster cm WITH (NOLOCK) ON cm.custid = c.mrecommend
	WHERE tmp.RoleId = 2

	UNION ALL
	SELECT tmp.SessionDate, cm.custid, tmp.RoleId, cm.TransferOption, cm.IsAllDayBalTransfer
	FROM CustDB.dbo.CustMaster cm WITH (NOLOCK)
		INNER JOIN CTE_Setting tmp ON tmp.FromCustId = cm.custid
	WHERE tmp.RoleId = 3

	UNION ALL
	SELECT tmp.SessionDate, cs.custid, tmp.RoleId, cs.TransferOption, cs.IsAllDayBalTransfer
	FROM CustDB.dbo.CustSuper cs WITH (NOLOCK)
		INNER JOIN CTE_Setting tmp ON tmp.FromCustId = cs.custid
	WHERE tmp.RoleId = 4
)
SELECT s.FromCustId, cs.ToCustID, s.roleid, ISNULL(s.IsAllDayBalTransfer, 0) AS IsAllDayBalTransfer
	, c.srecommend AS SuperId
FROM CTE_SMASetting s
	INNER JOIN CustDB.dbo.Customer c ON c.custid = s.FromCustId
	INNER JOIN CustDB.dbo.Age_ClearBalanceCust_Setting cs ON cs.FromCustID = s.FromCustId AND cs.EffectiveDate <= s.SessionDate
	CROSS APPLY (
		SELECT strTransferOption = CustDB.dbo.F_Decimal_Binary(ISNULL(s.TransferOption,0))
	) AS ck
WHERE 1 = CASE 
			WHEN s.RoleId = 4 THEN 1
			WHEN SUBSTRING(ck.strTransferOption, 8, 1) = 1 
				AND SUBSTRING(ck.strTransferOption, DATEPART(WEEKDAY, CURRENT_TIMESTAMP), 1) = 1 THEN 1
			ELSE 0 
		END
GO