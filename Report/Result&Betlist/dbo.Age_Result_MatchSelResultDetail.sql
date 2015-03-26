ALTER PROCEDURE [dbo].[Age_Result_MatchSelResultDetail]
(	
	@MatchId INT
)
AS
/*
Created: 20141016@Sophia
Task: 	Get ResultDetail of a match
DB:  DBAGE/bodb02
Revisions: 
	- 20141218@Sophia: Not to use Betstatus to get REFUND status of Tennis anymore

*/
BEGIN 
	SET NOCOUNT ON 	 

	SELECT 
		m.sporttype, 
		m.betstatus, 
		m.leagueid,
		m.matchid,		 
		m.matchcode,
		m.eventdate, 
		m.globalshowtime as kickofftime,
		m.homeID,
		m.awayID,
		m.hthomescore,
		m.htawayscore, 
		m.finalhomescore,
		m.finalawayscore,
		CASE ISNULL(R.SettlementStatusID,0)	 
			WHEN 1 THEN 'Refund' 
			WHEN 2 THEN 'Refund HT'
			WHEN 3 THEN 'Refund FT'
		ELSE m.eventstatus END AS eventstatus,  
		m.showtime,
		isnull(m.isNeutral, CONVERT(BIT,0)) as IsNeutral,
		m.goalrecord,
		m.homeid2,   
		ISNULL(mr.IsHTCal,0) as IsHTCal,
		ISNULL(mr.calculate,0) as calculate	,
		ISNULL(mr.IsPending,0) as IsPending	
	FROM  dbo.Match m WITH (NOLOCK)
		LEFT JOIN dbo.match_remark mr WITH(NOLOCK) ON m.matchid = mr.matchid
		LEFT JOIN dbo.ResultDetail R WITH (NOLOCK) ON R.matchID = M.MatchID AND R.ResourceId = '00'
	WHERE m.MatchId = @matchid

	UNION ALL 
	SELECT 
		m.sporttype, 
		m.betstatus, 
		m.leagueid,
		m.matchid,		 
		m.matchcode,
		m.eventdate, 
		m.globalshowtime as kickofftime,
		m.homeID,
		m.awayID,
		m.hthomescore,
		m.htawayscore, 
		m.finalhomescore,
		m.finalawayscore,
		CASE ISNULL(R.SettlementStatusID,0)	 
			WHEN 1 THEN 'Refund' 
			WHEN 2 THEN 'Refund HT'
			WHEN 3 THEN 'Refund FT'
		ELSE m.eventstatus END AS eventstatus,  
		m.showtime,
		isnull(m.isNeutral, CONVERT(BIT,0)) as IsNeutral,
		m.goalrecord,
		m.homeid2,   
		ISNULL(mr.IsHTCal,0) as IsHTCal,
		ISNULL(mr.calculate,0) as calculate	,
		ISNULL(mr.IsPending,0) as IsPending	
	FROM  dbo.Match14 m WITH (NOLOCK)
		LEFT JOIn dbo.match_remark mr WITH(NOLOCK) ON m.matchid = mr.matchid
		LEFT JOIN dbo.ResultDetail14 R WITH (NOLOCK) ON R.matchID = M.MatchID AND R.ResourceId = '00'
	WHERE m.MatchId = @matchid	


	SELECT	MatchId
			,ResourceId
			,HomeValue
			,AwayValue
			,ResultStatusID
			,SettlementStatusID
	FROM	dbo.ResultDetail WITH (NOLOCK)
	WHERE	MatchId = @MatchId AND SettlementStatusID > 0
	UNION ALL
	SELECT	MatchId
			,ResourceId
			,HomeValue
			,AwayValue
			,ResultStatusID
			,SettlementStatusID
	FROM	dbo.ResultDetail14 WITH (NOLOCK)
	WHERE	MatchId = @MatchId AND SettlementStatusID > 0
	
END
GO 
GRANT EXECUTE ON [dbo].[Age_Result_MatchSelResultDetail] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_Result_MatchSelResultDetail] TO [bodbDownlineNetView] AS [dbo]
GO