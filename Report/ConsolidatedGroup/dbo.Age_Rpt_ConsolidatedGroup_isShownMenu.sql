 
CREATE  PROCEDURE [dbo].[Age_Rpt_ConsolidatedGroup_isShownMenu]
	@CustID INT,
	@isShownMenu BIT OUTPUT
AS 
/*	
	Created: Sophia
	Date: 2011-07-14
	Task : Show/Hide menu Consolidated Report in Agency Site
	DB: DBAGE/bodb_AGE
	Original:  
	Revisions: 
		- 20130121@Dan: Move sp from DB053/bodb02 to DBAGE/bodb_AGE

*/
SET NOCOUNT ON

IF EXISTS (	SELECT	1
			FROM	Age_CustGroup WITH (NOLOCK)
			WHERE	CustID = @CustID AND isHeader = 1)
SET @isShownMenu = 1
ELSE 
SET @isShownMenu = 0


GO
GRANT EXECUTE ON [dbo].[Age_Rpt_ConsolidatedGroup_isShownMenu] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_Rpt_ConsolidatedGroup_isShownMenu] TO [bodbDownlineNetView]
GO
GRANT VIEW DEFINITION ON [dbo].[Age_Rpt_ConsolidatedGroup_isShownMenu] TO [vnteam] 