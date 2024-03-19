/*<info serverAlias="DBAGE-bodb02,DBACC-bodb02,DBBOF-bodb02" selecters="wsv_nap,wsv_alp,wsv_alpv" isFunction="1" isNested="1"></info>*/
ALTER FUNCTION [dbo].[f_GroupProduct]
(
)
RETURNS TABLE
AS

/*
	Created by Percy
	Date: 2017-06-22
	DB: DBAGE.bodb02, DBACC.bodb02, DBBOF.bodb02
	Task: Get parent product
	
	Revisions:
		- 20170622@Percy: Create new [RedmineID: #78339]
		- 20180418@Razor: Add Pragmatic under Macau Games [RedmineID: #92647]
		- 20190612@Percy: Add Card Club under Macau Games [RedmineID: #107703]
		- 20191029@Percy: Add Spadegaming under Macau Games [RedmineID: #122353]
		- 20200810@Sophia: Exclude these Products: Pragmatic, Card Club, Spadegaming of of Macau Games [Redmine: #137767]
		- 20201005@Danny: Change to use alias DBBOF alternative to DB042 [RedmineID: #139516]
		- 20201124@Malcolm: Add Virtual Sports 3 [redmine: #131375]
		- 20230713@Lewis: Add Virtual Sports 3 (New) - Leap Gaming [RedmineID: #189207]
		- 20240119@Lewis: Add VS4 [RedmineID: #198621]
*/

RETURN
	-- Virtual Sports: Betradar Virtual Sports, Virtual Sports, VS3-LeapGamingVS(New)
	SELECT 5 AS ProductId, 5 AS GroupProductId
	UNION ALL
	SELECT 27, 5
	UNION ALL
	SELECT 49, 5
	UNION ALL
	SELECT 77, 5	
	UNION ALL
	SELECT 83, 5

	
	/*
	-- Macau Games: Macau Games, Pragmatic, Card Club, Spadegaming
	UNION ALL	
	SELECT 22, 22
	UNION ALL	
	SELECT 32, 22
	UNION ALL
	SELECT 34, 22
	UNION ALL
	SELECT 36, 22
	*/
GO