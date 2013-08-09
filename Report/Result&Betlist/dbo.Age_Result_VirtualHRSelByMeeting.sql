 ALTER PROCEDURE [dbo].[Age_Result_VirtualHRSelByMeeting]
	@FromDate DATETIME,
	@LeagueID INT = 0,
	@sporttype SMALLINT = 0,
	@isShowAll bit = 1 -- 1: Show All; 0: is NOT show Test	
AS
/*	Created:Elodie
	Date:20130308
	DB: DBAGE/BODB02

	Revisions:		
		- 20130808@Kathy: Amend to show refund game for virtual horse racing
						
*/
BEGIN
	SET NOCOUNT ON 
	
	SELECT @isShowAll = CASE @isShowAll WHEN 1 THEN NULL ELSE 0 END
				
	-- Virtual HR	
	IF @sporttype = 181
	SELECT  o.leagueid,
			EventTime, 
			l.lcolor,
			Placing place, 
			o.RacerNum horseNo, 
			o.RacerID Horseid, 
			WinOdds,
			o.placeodds,		
			o.IsFavor, 
			CASE WHEN o.BetStatus = 'refund' THEN 'Refund' ELSE o.EventStatus END EventStatus
	FROM 
		(	SELECT	leagueid, RacerID, EventTime, EventDate, placing, r.EventStatus, r.BetStatus, WinOdds, PlaceOdds, IsFavor, RacerNum
		 	  FROM VSOutright o  with (nolock) INNER JOIN VSRaceInfo r  with (nolock) on o.EventID = r.EventID
			UNION ALL
			SELECT	leagueid, RacerID, EventTime, EventDate, placing, r.EventStatus,r.BetStatus, WinOdds, PlaceOdds, IsFavor, RacerNum FROM VSOutright14 o with (nolock) INNER JOIN VSRaceInfo r  with (nolock) on o.EventID = r.EventID
			UNION ALL
			SELECT	leagueid, RacerID, EventTime, EventDate, placing, r.EventStatus,r.BetStatus, WinOdds, PlaceOdds, IsFavor, RacerNum FROM DB06.bodb_Archive.dbo.VSOutright_bk o with (nolock) INNER JOIN VSRaceInfo r  with (nolock) on o.EventID = r.EventID
		 ) o 
		INNER JOIN league l WITH (NOLOCK) ON o.leagueid = l.leagueid 
	WHERE	o.EventDate = @FromDate 
			and l.sporttype = case when @sporttype = 0 then l.sporttype else @sporttype end 
			and o.leagueid = case when @LeagueID =0 then o.leagueid else @LeagueID end 
			and o.Eventstatus  = 'completed'
			and l.isTest = isnull(@isShowAll, l.isTest)
	--		and isnull(Placing, 0) <> 0
	ORDER BY o.EventStatus, o.leagueid, EventTime, o.placing
END 

GO
GRANT EXECUTE ON [dbo].[Age_Result_VirtualHRSelByMeeting] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_Result_VirtualHRSelByMeeting] TO [bodbDownlineNetView]
GO
GRANT VIEW DEFINITION ON [dbo].[Age_Result_VirtualHRSelByMeeting] TO [vnteam]