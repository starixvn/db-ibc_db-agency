/*<info serverAlias="DBCUST-AgencyCashService" executers="wsv_CashService" isFunction="0" isNested="0"></info>*/
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
    SELECT 
        ca.AgentId,
        StartTime = FORMAT(ISNULL(ca.StartTime, ''), 'yyyy-MM-dd'),
        TrialEndTime = FORMAT(ISNULL(ca.TrialEndTime, ''), 'yyyy-MM-dd'),
        ServiceType = ISNULL(cs.ServiceType, 0)
    FROM dbo.CashAgentManagement ca WITH(NOLOCK)
    INNER JOIN [CustDB].[dbo].[vw_Customer] ci WITH(NOLOCK) ON ca.AgentId = ci.CustID
    LEFT JOIN [CustDB].[dbo].[vw_CustInfoExtra] cs WITH(NOLOCK) ON ca.AgentId = cs.CustID
    WHERE ca.TrialEndTime IS NOT NULL
        AND ci.RoleID = 2 -- Assuming 2 is the role ID for agents
        --AND cs.[ServiceType] IN (1) -- Assuming 1 is valid service types for agents
END
