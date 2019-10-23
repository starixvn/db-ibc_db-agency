/*<info serverAlias="DBOST-bodb_ost" executers="" viewers="" isFunction="1"></info>*/
ALTER FUNCTION dbo.Ost_f_bettrans_running()
RETURNS TABLE
AS 
/*
	Created:20191021@Bobby
	Task: New Forecast at Agent Site 
	DB: DBOST.bodb_ost
	Original:DB042.bodb02.Age_LeagueSelRunning_SAg
	
	Revisions: 
		- 20191021@Bobby: Initialize [Redmine:114231] 
		
*/
RETURN (
	
	WITH CTE_bettype (bettype, IsHT) AS (
		SELECT bt.typeid
			, CASE WHEN typenamee LIKE '%1H%' AND typenamee NOT LIKE '%2H%' THEN 1 ELSE 0 END IsHT
		FROM bodb02.dbo.bettype bt WITH(NOLOCK) 
		WHERE bt.typeid < 20000
	)
	SELECT 
		------index keys
		b.matchid 
		, b.bettype
		, b.srecommend
		, b.mrecommend
		, b.recommend
		, b.custid
		, b.transid

		------forcecase usages
		, b.livehomescore
		, b.liveawayscore
		, b.liveindicator
		, b.hdp1
		, b.hdp2
		, b.currency
		, b.betteam
		, b.odds
		, b.oddsspread
		, b.stake
		, b.apositiontaking
		, b.mpositiontaking
		, b.spositiontaking

		----betlist usages
		, b.username 
		, b.modds
		, b.refno
		, b.status
		, b.statusID
		, b.comstatus
		, b.actual_stake
		, b.transdate
		, b.betid
		, b.discount
		, b.adiscount
		, b.sdiscount
		, b.ip
		, b.oddstype
		, b.transdesc
		, b.checktime
		, b.SecAcceptFlag
		, b.oddsid

	FROM dbo.bettrans b WITH(NOLOCK)
	INNER JOIN dbo.match m WITH(NOLOCK) ON b.matchid = m.matchid AND m.eventstatus = 'running'
	INNER JOIN dbo.match_remark mr WITH(NOLOCK) ON m.matchid = mr.matchid
	INNER JOIN CTE_bettype bt WITH(NOLOCK) ON b.bettype = bt.bettype
	WHERE 1 = CASE 
		WHEN mr.IsHTCal = 1 AND bt.IsHT = 1 THEN 0
		ELSE 1
	END
	AND b.statusID NOT IN (101,102)
)
GO
