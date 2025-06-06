/*<info serverAlias="DBCUST-AgencyCashService" executers="wsv_CashService" isFunction="0" isNested="0"></info>*/
use AgencyCashService
GO
ALTER PROCEDURE  [dbo].[Age_CashServiceBilling_AgentSel]
AS
/*
  Created: 20250526@Bobby
  Task: Implement daily fee and free period records for agents
  DB: DBCUST-AgencyCashService
  
  Revisions:
    - 20250526@Bobby: Initial [RedmineID: #227215]
*/
BEGIN
    SET NOCOUNT ON;

    ;WITH AgentInfo AS (
        SELECT 
            ca.AgentId,
            StartTime = FORMAT(ISNULL(ca.StartTime, ''), 'yyyy-MM-dd'),
            TrialEndTime = FORMAT(ISNULL(ca.TrialEndTime, ''), 'yyyy-MM-dd'),
            cs.ServiceType,
            si2.SiteDBGroupId
        FROM dbo.CashAgentManagement ca WITH(NOLOCK)
        INNER JOIN [CustDB].[dbo].[vw_CashService_Customer] ci WITH(NOLOCK) ON ca.AgentId = ci.CustID
        INNER JOIN [CustDB].[dbo].[Site] si2 WITH(NOLOCK) ON si2.[site] = ci.[site]
        LEFT JOIN [CustDB].[dbo].[vw_CustInfoExtra] cs WITH(NOLOCK) ON ca.AgentId = cs.CustID
        WHERE ca.TrialEndTime IS NOT NULL
            AND ci.RoleID = 2
            AND cs.ServiceType = 1
    )
    SELECT 
        SiteDBGroupId,
        AgentList = (
            SELECT 
                AgentId,
                StartTime,
                TrialEndTime,
                ServiceType
            FROM AgentInfo ai
            WHERE ai.SiteDBGroupId = cte.SiteDBGroupId
            FOR JSON PATH
        )
    FROM AgentInfo cte
    GROUP BY SiteDBGroupId
END
