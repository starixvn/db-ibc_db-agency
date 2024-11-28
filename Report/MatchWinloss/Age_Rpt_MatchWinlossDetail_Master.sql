/*<info serverAlias="DBAGE-bodb02" executers="wsv_nap,wsv_alp,wsv_alpv" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Age_Rpt_MatchWinlossDetail_Master] 
	@CustID			INT, --srecommend
	@FromDate		SMALLDATETIME,
	@ToDate			SMALLDATETIME,  
	@MoveBetsDay	SMALLDATETIME,
	@leagueIds		VARCHAR(MAX),
	@ProductIds		VARCHAR(MAX),
	@league3rdIds	VARCHAR(MAX),
	@isGetAll		BIT
AS

/*
	Created: 
	Task : 
	DB: DBAGE.bodb02
	
	Revisions:
		- 20170224@Paul: Create new [RedmineID: #70554]
		- 20171020@Percy: Add @league3rdIds, @isGetAll params [RedmineID: #84690]
			1. @isGetAll: get data all (support Parlay)
			2. @leagueIds: get data from league table
			2. @league3rdIds: get data from league3rd table
		- 20190826@Percy: Remove inactive products [RedmineID: #118699]
		- 20210823@Sol: Alpha - Allow more time to transfer (phase 2b) - [RedmineID: #160440]
		- 20240711@Lewis: Add VS5 - EventType = 5 [RedmineID: #206527]
*/

BEGIN 
	SET NOCOUNT ON
	
	IF @isGetAll = 1
	BEGIN 
		EXEC dbo.Age_Rpt_MatchWinlossDetail_Master_All
			@CustID = @CustID,
			@Fromdate = @Fromdate,
			@Todate = @Todate,
			@MoveBetsDay = @MoveBetsDay,
			@ProductIds = @ProductIds
	END
	ELSE
	BEGIN
		EXEC dbo.Age_Rpt_MatchWinlossDetail_Master_ByLeague 
			@CustID = @CustID,
			@Fromdate = @Fromdate,
			@Todate = @Todate,
			@MoveBetsDay = @MoveBetsDay,
			@leagueIds = @leagueIds,
			@league3rdIds =	@league3rdIds,
			@ProductIds = @ProductIds
	END
END
GO