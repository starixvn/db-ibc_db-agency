/*<info serverAlias="DBCUST-AgencyCashService" executers="wsv_CashService" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE  [dbo].[Age_CashServiceBilling_AgentSel]
    @SiteDBGroupIds VARCHAR(1000) = '3' -- Optional parameter for filtering by SiteDBGroupIds
AS
/*
  Created: 20250526@Bobby
  Task: Implement daily fee and free period records for agents
  DB: DBCUST-AgencyCashService
  
  Revisions:
    - 20250526@Bobby: Initial [RedmineID: #227215]
    - 20250617@Bobby: Fix table Site - cross DB [RedmineID: #230803]
*/
BEGIN
    SET NOCOUNT ON;

    ;WITH CTE_SiteDBGroupIds AS (
        SELECT 
            SiteDBGroupId = TRY_CAST([value] AS SMALLINT)
        FROM STRING_SPLIT(@SiteDBGroupIds, ',')
    ),
    AgentInfo AS (
        SELECT 
            ca.AgentId,
            StartTime = FORMAT(ISNULL(ca.StartTime, ''), 'yyyy-MM-dd'),
            TrialEndTime = FORMAT(ISNULL(ca.TrialEndTime, ''), 'yyyy-MM-dd'),
            cs.ServiceType,
            si.SiteDBGroupId
        FROM dbo.CashAgentManagement ca WITH(NOLOCK)
        INNER JOIN [CustDB].[dbo].[vw_CashService_Customer] ci WITH(NOLOCK) ON ca.AgentId = ci.CustID
        INNER JOIN [GlobCustDB].[dbo].[Site] si WITH(NOLOCK) ON si.[site] = ci.[site]
        INNER JOIN CTE_SiteDBGroupIds cte ON si.SiteDBGroupId = cte.SiteDBGroupId
        LEFT JOIN [CustDB].[dbo].[vw_CustInfoExtra] cs WITH(NOLOCK) ON ca.AgentId = cs.CustID
        WHERE ca.TrialEndTime IS NOT NULL
            AND ci.RoleID = 2
            AND cs.ServiceType = 1
    )
    SELECT 
        cte.SiteDBGroupId,
        AgentList = ISNULL((
            SELECT 
                AgentId,
                StartTime,
                TrialEndTime,
                ServiceType
            FROM AgentInfo ai
            WHERE ai.SiteDBGroupId = cte.SiteDBGroupId
            FOR JSON PATH
        ), '[]')
    FROM CTE_SiteDBGroupIds cte
    GROUP BY cte.SiteDBGroupId
END
