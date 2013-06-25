ALTER PROCEDURE [dbo].[Age_Rpt_ConsolidatedGroup_isShownMenu_xpre]
	@CustID INT,
	@isShownMenu BIT OUTPUT
AS 
/*	
	Created: Elodie
	Date: 20130612
	Task : Show/Hide menu Consolidated Report in Agency Site
	DB: DBAGE/bodb02
	Original:  
	
	Revisions: 		

*/
SET NOCOUNT ON

IF EXISTS (	SELECT	1
			FROM	custAccount WITH (NOLOCK)
			WHERE	CustID = @CustID AND IsGroupHeadLine = 1 AND IsRptConsol = 1)
	SET @isShownMenu = 1
ELSE 
	SET @isShownMenu = 0


GO
GRANT EXECUTE ON [dbo].[Age_Rpt_ConsolidatedGroup_isShownMenu] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_Rpt_ConsolidatedGroup_isShownMenu] TO [bodbDownlineNetView]
GO
GRANT VIEW DEFINITION ON [dbo].[Age_Rpt_ConsolidatedGroup_isShownMenu] TO [vnteam] 