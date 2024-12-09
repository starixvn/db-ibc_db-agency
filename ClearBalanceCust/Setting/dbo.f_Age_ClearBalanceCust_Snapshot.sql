/*<info serverAlias="DBCUST-CustDB" selecters="wsv_alp" isFunction="1" isNested="1"></info>*/
ALTER FUNCTION dbo.f_Age_ClearBalanceCust_Snapshot(@SiteDBGroupID SMALLINT, @TestSuperIds VARCHAR(200), @Environment VARCHAR(10)) 
RETURNS TABLE
RETURN
/*
	Created:20230227@Bobby
	Task: 182071 - Auto Transfer/ Multiple Transfer	
	DB: DBCUST/CustDB

	Revisions:
		- 20230227@Bobby: AutoJob clear balance downlines [RedmineID: #182071]
		- 20230822@Bobby: Enhance checking cross level [RedmineID: #193021]
		- 20231027@Bobby: AutoJob transfer - schedule option [RedmineID: #195135]
		- 20241206@Helen: Alpha - Offer Direct Member for Super/Master [Redmine: #211969]
*/
WITH CTE_Setting AS (
	SELECT DISTINCT c.roleid, s.FromCustID, CAST(GETDATE() AS DATE) AS SessionDate, cs.custid AS SuperId
	FROM dbo.Age_ClearBalanceCust_Setting s WITH(NOLOCK)
		INNER JOIN dbo.Customer c WITH(NOLOCK) ON c.custid =  s.FromCustId
		INNER JOIN dbo.CustSuper cs WITH(NOLOCK) ON cs.custid = c.srecommend
		LEFT JOIN STRING_SPLIT(@TestSuperIds, ',') AS test ON test.[value] = cs.custid
	WHERE cs.SiteDBGroupID = @SiteDBGroupID
		AND 1 = CASE 
					WHEN @Environment = 'PRO' AND test.[value] IS NULL THEN 1
					WHEN @Environment = 'UAT' AND test.[value] > 0 THEN 1
					ELSE 0
				END
),
CTE_SMASetting AS (
	SELECT tmp.SessionDate, ca.custid AS FromCustId, tmp.RoleId, ca.TransferOption, ISNULL(cm.IsAllDayBalTransfer, 0) AS IsAllDayBalTransfer, tmp.SuperId
	FROM dbo.CustAgent ca WITH (NOLOCK)
		INNER JOIN CTE_Setting tmp ON tmp.FromCustId = ca.custid
		INNER JOIN dbo.Customer c WITH (NOLOCK) ON c.custid = ca.custid
		INNER JOIN dbo.CustMaster cm WITH (NOLOCK) ON cm.custid = c.mrecommend
	WHERE tmp.RoleId = 2

	UNION ALL
	SELECT tmp.SessionDate, cm.custid, tmp.RoleId, cm.TransferOption, ISNULL(cm.IsAllDayBalTransfer, 0), tmp.SuperId
	FROM dbo.CustMaster cm WITH (NOLOCK)
		INNER JOIN CTE_Setting tmp ON tmp.FromCustId = cm.custid
	WHERE tmp.RoleId = 3

	UNION ALL
	SELECT tmp.SessionDate, cs.custid, tmp.RoleId, cs.TransferOption, ISNULL(cs.IsAllDayBalTransfer, 0), tmp.SuperId
	FROM dbo.CustSuper cs WITH (NOLOCK)
		INNER JOIN CTE_Setting tmp ON tmp.FromCustId = cs.custid
	WHERE tmp.RoleId = 4
)
SELECT s.FromCustId, cs.ToCustID
	,s.roleid, s.IsAllDayBalTransfer, s.SuperId
	,s.TransferOption
FROM CTE_SMASetting s
	INNER JOIN dbo.Age_ClearBalanceCust_Setting cs ON cs.FromCustID = s.FromCustId
	INNER JOIN dbo.Customer c WITH(NOLOCK) ON c.custid =  cs.ToCustID
WHERE cs.EffectiveDate <= s.SessionDate
	AND 1 = CASE 
				WHEN cs.ScheduleOption > 0 THEN IIF(cs.ScheduleOption & POWER(2, DATEPART(WEEKDAY, CURRENT_TIMESTAMP)) > 0, 1, 0)
			ELSE 0 
		END
	AND 1 = CASE 
				WHEN s.roleid = 2 AND c.roleid = 1 and c.recommend = s.FromCustId THEN 1	--direct agent/member
				WHEN s.roleid = 3 AND c.roleid = 2 and c.mrecommend = s.FromCustId THEN 1	--direct master/agent
				WHEN s.roleid = 3 AND c.roleid = 1 and c.mrecommend = s.FromCustId AND c.recommend = -3 THEN 1	--master direct member
				WHEN s.roleid = 4 AND c.roleid = 3 and c.srecommend = s.FromCustId THEN 1	--direct super/master
				WHEN s.roleid = 4 AND c.roleid = 1 and c.srecommend = s.FromCustId AND c.recommend = -4 THEN 1	--super direct member
				ELSE 0
			END
	AND s.IsAllDayBalTransfer = 0 -- NOT support Cash model
GO