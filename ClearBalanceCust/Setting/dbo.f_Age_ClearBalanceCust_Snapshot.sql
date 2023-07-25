/*<info serverAlias="DBCUST-CustDB" selecters="bodbDownlineNet" isFunction="1" isNested="1"></info>*/
ALTER FUNCTION dbo.f_Age_ClearBalanceCust_Snapshot(@SiteDBGroupID SMALLINT) 
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
	SELECT DISTINCT c.roleid, s.FromCustID, CAST(GETDATE() AS DATE) AS SessionDate, cs.custid AS SuperId
	FROM CustDB.dbo.Age_ClearBalanceCust_Setting s WITH(NOLOCK)
		INNER JOIN CustDB.dbo.Customer c WITH(NOLOCK) ON c.custid =  s.FromCustId
		INNER JOIN CustDB.dbo.CustSuper cs WITH(NOLOCK) ON cs.custid = c.srecommend
	WHERE cs.SiteDBGroupID = @SiteDBGroupID
),
CTE_SMASetting AS (
	SELECT tmp.SessionDate, ca.custid AS FromCustId, tmp.RoleId, ca.TransferOption,cm.IsAllDayBalTransfer, tmp.SuperId
	FROM CustDB.dbo.CustAgent ca WITH (NOLOCK)
		INNER JOIN CTE_Setting tmp ON tmp.FromCustId = ca.custid
		INNER JOIN CustDB.dbo.Customer c WITH (NOLOCK) ON c.custid = ca.custid
		INNER JOIN CustDB.dbo.CustMaster cm WITH (NOLOCK) ON cm.custid = c.mrecommend
	WHERE tmp.RoleId = 2

	UNION ALL
	SELECT tmp.SessionDate, cm.custid, tmp.RoleId, cm.TransferOption, cm.IsAllDayBalTransfer, tmp.SuperId
	FROM CustDB.dbo.CustMaster cm WITH (NOLOCK)
		INNER JOIN CTE_Setting tmp ON tmp.FromCustId = cm.custid
	WHERE tmp.RoleId = 3

	UNION ALL
	SELECT tmp.SessionDate, cs.custid, tmp.RoleId, cs.TransferOption, cs.IsAllDayBalTransfer, tmp.SuperId
	FROM CustDB.dbo.CustSuper cs WITH (NOLOCK)
		INNER JOIN CTE_Setting tmp ON tmp.FromCustId = cs.custid
	WHERE tmp.RoleId = 4
)
SELECT s.FromCustId, cs.ToCustID
	,s.roleid, ISNULL(s.IsAllDayBalTransfer, 0) AS IsAllDayBalTransfer, s.SuperId
	,s.TransferOption
FROM CTE_SMASetting s
	INNER JOIN CustDB.dbo.Age_ClearBalanceCust_Setting cs ON cs.FromCustID = s.FromCustId
	--CROSS APPLY (
	--		SELECT 
	--			--strTransferOption = dbo.f_Decimal_Binary(ISNULL(s.TransferOption,0))
	--			strTransferOption = CONCAT(
	--				(ISNULL(s.TransferOption,0)/POWER(2*1, 7)% 2) --SUN
	--				,(ISNULL(s.TransferOption,0)/POWER(2*1, 6)% 2) --MON
	--				,(ISNULL(s.TransferOption,0)/POWER(2*1, 5)% 2) --WEN
	--				,(ISNULL(s.TransferOption,0)/POWER(2*1, 4)% 2) --TUE
	--				,(ISNULL(s.TransferOption,0)/POWER(2*1, 3)% 2) --THUR
	--				,(ISNULL(s.TransferOption,0)/POWER(2*1, 2)% 2) --FRI
	--				,(ISNULL(s.TransferOption,0)/POWER(2*1, 1)% 2) --SAT
	--				,(ISNULL(s.TransferOption,0)/POWER(2*1, 0)% 2) --IsWeekly
	--			)
	--	) AS ck
WHERE cs.EffectiveDate <= s.SessionDate
	AND 1 = CASE 
			WHEN s.RoleId = 4 THEN 1 -- by pass cheking super vs master 
			WHEN ISNULL(s.TransferOption, 0) = 0 THEN 1 -- Daily mode
			WHEN ((ISNULL(s.TransferOption,0)/POWER(2*1, 0))% 2) = 1 -- Weekly mode
				AND ((ISNULL(s.TransferOption,0)/POWER(2*1, 8-DATEPART(WEEKDAY, CURRENT_TIMESTAMP)))% 2) = 1 THEN 1 -- WEEKDAY enabled
			ELSE 0 
		END
GO