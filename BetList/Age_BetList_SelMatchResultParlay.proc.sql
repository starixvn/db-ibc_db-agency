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
		IsPending	BIT
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
			IsPending
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
						ISNULL(mr.IsPending,0) as IsPending 
		FROM(	SELECT b.matchId FROM BettransM b WITH (NOLOCK) WHERE b.refno = @refno ) bM
				INNER JOIN match m WITH(NOLOCK) ON bM.matchid = m.matchid
				LEFT OUTER JOIN match_remark mr WITH(NOLOCK) ON m.matchid = mr.matchid
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
			IsPending
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
				ISNULL(mr.IsPending,0) as IsPending
		FROM(	SELECT b.matchId FROM BettransM14 b WITH (NOLOCK) WHERE b.refno = @refno ) bM
				INNER JOIN match14 m WITH(NOLOCK) ON bM.matchid = m.matchid
				LEFT OUTER JOIN match_remark mr WITH(NOLOCK) ON m.matchid = mr.matchid
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
			IsPending
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
				ISNULL(mr.IsPending,0) as IsPending
		FROM(	SELECT b.matchId FROM DBARC.bodb_archive.dbo.BettransM b (NOLOCK) WHERE b.refno = @refno ) bM
				INNER JOIN DBARC.bodb_archive.dbo.match_BK m WITH(NOLOCK) ON bM.matchid = m.matchid
				LEFT OUTER JOIN match_remark mr WITH(NOLOCK) ON m.matchid = mr.matchid
	END
	SELECT * FROM @tmpParlay
	ORDER BY LeagueID, eventdate, matchcode	
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
