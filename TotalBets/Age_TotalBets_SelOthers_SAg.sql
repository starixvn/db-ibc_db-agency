ALTER PROCEDURE [dbo].[Age_TotalBets_SelOthers_SAg]
	@custid	 INT = 0
AS
	/*
		Created: Johnson
		Date: 2012-10-10
		Task: Retrieve total bets of new bet types for tenis from 1301 to 1334
		DB: DB053.BODB02
		
		Revisions:
		
		Parameter's Explanation:		
	*/ 
SET NOCOUNT ON
	SELECT 
		b.transid,
		b.username,
		b.transdate,
		m.sporttype,
		m.leagueid,
		m.homeid,
		m.awayid,
		b.betteam,
		b.bettype,
		b.betid,
		b.hdp1,
		b.hdp2,
		b.odds,
		b.modds,
		CASE WHEN b.status = 'running' AND IsNull(b.SecAcceptFlag, 0) = 1 and IsNull(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
				 ELSE b.status 
				 END as status,
		CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END as comstatus,
		b.stake,
		b.actual_stake,
		b.spositiontaking,
		b.mpositiontaking,
		b.apositiontaking,
		b.discount as Adiscount,
		b.adiscount as Mdiscount,
		b.sdiscount as Sdiscount,
		b.livehomescore,
		b.liveawayscore,
		b.liveindicator, 
		IP as IP,
		isnull(m.isNeutral, CONVERT(BIT,0)) as IsNeutral,
		b.OddsType
	FROM bettrans b WITH(NOLOCK)
		INNER JOIN match m WITH(NOLOCK) ON b.matchid = m.matchid
	WHERE b.bettype BETWEEN 1301 AND 1334
		AND b.srecommend = @custid 
		AND b.statusid BETWEEN 0 AND 1
	ORDER BY b.transid
GO