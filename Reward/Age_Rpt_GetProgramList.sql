/*<info serverAlias="DBAGE-bodb02" executers="wsv_alp,wsv_alpv,wsv_xnap" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Age_Rpt_GetProgramList]  
AS  
/*  
    Created: 20240918@Lewis  
    Task: Rebate and Retention for Credit Players - Report Reward Member
    DB: DBAGE-bodb02
  
    Revisions:  
        - 20240918@Lewis: Initialize SP [RedmineId: #208503]
  
    Param's Explanation:  
  
*/  
BEGIN  
    SET NOCOUNT ON; 

	SELECT 
		ResourceId
		,Resource_en 
	FROM RefResource WITH (NOLOCK) 
	WHERE RefId = 'RewardProgram'
	ORDER BY ResourceId

END  