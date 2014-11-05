ALTER PROCEDURE [dbo].[Age_BetList_SelMatchResultParlay]
	@refno	BIGINT
AS
/*
Created: nqminh@20090402
Task : Select MixParlay result
DB: DBAGE/bodb02
Original: Age_BetList_SelMatchResultParlay
Revisions:
    - 20090402@Nqminh: ----------
	- 20091202@Jamie: Results for Future Mix Parlay
	- 20100123@Henry: Grant execute to Accounting site
	- 20110819@Johnson: Add column kickofftime
	- 20110831@Johnson: correct event status when refund ticket
	- 20110907@Sophia: Add column IsHTCal, calculate for Pending Status.
	- 20111003@Sophia: Add column IsPending Pending Status.
	- 20130121@Dan: change linked server DB06 to DBARC
	- 20131010@Kathy: Turn to use GlobalShowTime for display the Kick-off-Time [redmine:#6076]
	- 20141002@Sophia: Get the detail information of Tennis sport
*/
BEGIN
	SET NOCOUNT ON
	DECLARE	@tmpParlay TABLE(
		sporttype	INT,
		leagueid	INT,
		matchid		INT,
		homeID		INT,
		awayID		INT,
		hthomescore	INT,
		htawayscore	INT,
		finalhomescore INT,
		finalawayscore INT,
		kickofftime DATETIME,
		eventdate	DATETIME,
		isNeutral	BIT,
		betstatus	VARCHAR(50),
		eventstatus	VARCHAR(15),
		IsRefund	BIT,
		IsCalRefund	BIT,
		goalrecord	VARCHAR(50),
		matchcode	VARCHAR(50),
		isHTCal		BIT,
		calculate	BIT,
		IsPending	BIT, 
		Bettype		SMALLINT,
		Betcheck	VARCHAR(50)
	)

	DECLARE @tmpResultDetail AS TABLE (
		MatchId INT ,
		ResourceId VARCHAR(20),
		HomeValue VARCHAR(20),
		AwayValue VARCHAR(20),
		ResultStatusID TINYINT,
		SettlementStatusID TINYINT
	)



	IF EXISTS (SELECT 1 FROM bettransm WITH (NOLOCK) WHERE  refno = @refno)
	BEGIN
		INSERT INTO @tmpParlay (
			sporttype, 	
			LeagueID,
			matchid, 	
			homeID,
			awayID,
			hthomescore,
			htawayscore,		
			finalhomescore,
			finalawayscore,
			kickofftime,
			eventdate,
			isNeutral,
			betstatus, 	
			eventstatus,
			IsRefund ,
			IsCalRefund,
			goalrecord,
			matchcode,
			isHTCal,
			calculate,
			IsPending, 
			Bettype, 
			Betcheck
		)
		SELECT	m.sporttype, 	
				m.LeagueID,
				m.matchid, 	
				m.homeID,
				m.awayID,
				hthomescore,
				htawayscore,		
				m.finalhomescore,
				m.finalawayscore,
				m.GlobalShowTime, --kickofftime,
				m.eventdate,
				m.isNeutral,
				m.betstatus, 	
				case when m.betstatus like 'Refund FT%' then 'Refund FT' 
						when m.betstatus like 'Refund HT%' then 'Refund HT'
						when m.betstatus like 'Refund%' then 'Refund' 
					else m.eventstatus end as eventstatus, 
				isnull(mr.refund,0) IsRefund ,
				isnull(mr.calrefund,0) IsCalRefund,
				m.goalrecord,
				m.matchcode,
				ISNULL(mr.isHTCal,0) as isHTCal,
				ISNULL(mr.calculate,0) as calculate	,
				ISNULL(mr.IsPending,0) as IsPending,
				bm.Bettype, 
				bm.Betcheck 
		FROM	(SELECT b.matchId, b.Bettype,b.Betcheck FROM BettransM b WITH (NOLOCK) WHERE b.refno = @refno ) bm
				INNER JOIN match m WITH(NOLOCK) ON bm.matchid = m.matchid
				LEFT OUTER JOIN match_remark mr WITH(NOLOCK) ON m.matchid = mr.matchid
		

		INSERT INTO @tmpResultDetail
		SELECT		D.MatchId,
					D.ResourceId,
					D.HomeValue,
					D.AwayValue,
					D.ResultStatusID,
					D.SettlementStatusID
			FROM	dbo.ResultDetail D WITH (NOLOCK)
				INNER JOIN @tmpParlay P 
					ON D.MatchId = P.MatchId		
			WHERE	CASE WHEN P.Bettype NOT IN (1324) THEN 2 ELSE 
						CASE WHEN P.Bettype IN (1324) AND LEFT(D.ResourceId,2) = LEFT(REPLACE (ISNULL(P.Betcheck,''),'8','') ,2) THEN 4 
							ELSE 0 END END = LEN(D.ResourceId)
					AND D.SettlementStatusID > 0

	END
	IF EXISTS (SELECT 1 FROM bettransm14 WITH (NOLOCK) WHERE  refno = @refno)
	BEGIN
		INSERT INTO @tmpParlay (
			sporttype, 	
			LeagueID,
			matchid, 	
			homeID,
			awayID,
			hthomescore,
			htawayscore,		
			finalhomescore,
			finalawayscore,
			kickofftime,
			eventdate,
			isNeutral,
			betstatus, 	
			eventstatus,
			IsRefund ,
			IsCalRefund,
			goalrecord,
			matchcode,
			isHTCal,
			calculate,
			IsPending,
			Bettype, 
			Betcheck
		)

		SELECT	m.sporttype, 	
				m.LeagueID,
				m.matchid, 	
				m.homeID,
				m.awayID,
				hthomescore,
				htawayscore,		
				m.finalhomescore,
				m.finalawayscore,
				m.globalshowtime, -- kickofftime,
				m.eventdate,
				m.isNeutral,
				m.betstatus, 	
				case when m.betstatus like 'Refund FT%' then 'Refund FT' 
					 when m.betstatus like 'Refund HT%' then 'Refund HT'
					 when m.betstatus like 'Refund%' then 'Refund' 
					else m.eventstatus end as eventstatus, 
				isnull(mr.refund,0) IsRefund ,
				isnull(mr.calrefund,0) IsCalRefund,
				m.goalrecord,
				m.matchcode, 
				ISNULL(mr.isHTCal,0) as isHTCal,
				ISNULL(mr.calculate,0) as calculate,
				ISNULL(mr.IsPending,0) as IsPending,
				bm.Bettype, 
				bm.Betcheck 
		FROM(	SELECT b.matchId, b.Bettype, b.Betcheck FROM BettransM14 b WITH (NOLOCK) WHERE b.refno = @refno ) bm
				INNER JOIN match14 m WITH(NOLOCK) ON bm.matchid = m.matchid
				LEFT OUTER JOIN match_remark mr WITH(NOLOCK) ON m.matchid = mr.matchid

		INSERT INTO @tmpResultDetail
		SELECT		D.MatchId,
					D.ResourceId,
					D.HomeValue,
					D.AwayValue,
					D.ResultStatusID,
					D.SettlementStatusID
			FROM	dbo.ResultDetail14 D WITH (NOLOCK)
				INNER JOIN @tmpParlay P 
					ON D.MatchId = P.MatchId		
			WHERE	CASE WHEN P.Bettype NOT IN (1324) THEN 2 ELSE 
						CASE WHEN P.Bettype IN (1324) AND LEFT(D.ResourceId,2) = LEFT(REPLACE (ISNULL(P.Betcheck,''),'8','') ,2) THEN 4 
							ELSE 0 END END = LEN(D.ResourceId)
					 AND D.SettlementStatusID > 0

	END
	IF EXISTS (SELECT 1 FROM DBARC.bodb_archive.dbo.BettransM  WITH (NOLOCK) WHERE  refno = @refno)
	BEGIN
		INSERT INTO @tmpParlay (
			sporttype, 	
			LeagueID,
			matchid, 	
			homeID,
			awayID,
			hthomescore,
			htawayscore,		
			finalhomescore,
			finalawayscore,
			kickofftime,
			eventdate,
			isNeutral,
			betstatus, 	
			eventstatus,
			IsRefund ,
			IsCalRefund,
			goalrecord,
			matchcode,
			isHTCal,
			calculate,
			IsPending,
			Bettype, 
			Betcheck
		)
		SELECT	m.sporttype, 
				m.LeagueID,
				m.matchid, 			
				m.homeID,
				m.awayID,
				hthomescore,
				htawayscore,		
				m.finalhomescore,
				m.finalawayscore,
				m.globalshowtime, -- kickofftime
				m.eventdate,
				m.isNeutral,
				m.betstatus, 	
				case when m.betstatus like 'Refund FT%' then 'Refund FT' 
					 when m.betstatus like 'Refund HT%' then 'Refund HT'
					 when m.betstatus like 'Refund%' then 'Refund' 
					else m.eventstatus end as eventstatus, 
				isnull(mr.refund,0) IsRefund ,
				isnull(mr.calrefund,0) IsCalRefund,
				m.goalrecord,
				m.matchcode,
				ISNULL(mr.isHTCal,0) as isHTCal,
				ISNULL(mr.calculate,0) as calculate,
				ISNULL(mr.IsPending,0) as IsPending,
				bm.Bettype, 
				bm.Betcheck 
		FROM(	SELECT b.matchId, b.Bettype,REPLACE (ISNULL(b.Betcheck,''),'8','') AS Betcheck FROM DBARC.bodb_archive.dbo.BettransM b (NOLOCK) WHERE b.refno = @refno ) bm
				INNER JOIN DBARC.bodb_archive.dbo.match_BK m WITH(NOLOCK) ON bm.matchid = m.matchid
				LEFT OUTER JOIN match_remark mr WITH(NOLOCK) ON m.matchid = mr.matchid

		INSERT INTO @tmpResultDetail
		SELECT		D.MatchId,
					D.ResourceId,
					D.HomeValue,
					D.AwayValue,
					D.ResultStatusID,
					D.SettlementStatusID
			FROM	DBARC.bodb_archive.dbo.ResultDetail_BK D WITH (NOLOCK)
				INNER JOIN @tmpParlay P 
					ON D.MatchId = P.MatchId		
			WHERE	CASE WHEN P.Bettype NOT IN (1324) THEN 2 ELSE 
						CASE WHEN P.Bettype IN (1324) AND LEFT(D.ResourceId,2) = LEFT(P.BetCheck,2) THEN 4 
							ELSE 0 END END = LEN(D.ResourceId)
					AND D.SettlementStatusID > 0
	END
	
	SELECT * FROM @tmpParlay
	ORDER BY LeagueID, bettype, eventdate, matchcode	
	---- Order [LeagueID, Bettype] to group choices in Set x game y together in the same LeagueId.

	SELECT DISTINCT * FROM @tmpResultDetail
	ORDER BY MatchID, ResourceId
END



GO
GRANT EXECUTE ON [dbo].[Age_BetList_SelMatchResultParlay] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_BetList_SelMatchResultParlay] TO [bodbExtAccNet]
GO
GRANT EXECUTE ON [dbo].[Age_BetList_SelMatchResultParlay] TO [bodbDownlineNetView]
GO
GRANT EXECUTE ON [dbo].[Age_BetList_SelMatchResultParlay] TO [bodbAdminNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Age_BetList_SelMatchResultParlay] TO [vnteam]
