/*<info serverAlias="DBOST-bodb_ost" executers="" viewers="" isFunction="1"></info>*/
ALTER FUNCTION dbo.Ost_f_bettrans_running()
RETURNS TABLE
AS 
/*
	Created:20191021@Bobby
	Task: New Forecast at Agent Site 
	DB: DBOST.bodb_ost
	
	Revisions: 
		- 20191021@Bobby: Initialize [Redmine:114231] 
		
*/
RETURN (
	
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
	INNER JOIN dbo.match_remark mr WITH(NOLOCK) ON b.matchid = mr.matchid AND mr.calculate = 0 AND mr.calRefund = 0
	LEFT JOIN [dbo].[f_GetHalfTimeBetType] () bt ON b.bettype = bt.bettype
	WHERE 1 = CASE 
		WHEN mr.IsHTCal = 1 AND bt.bettype > 0 THEN 0
		ELSE 1
	END
	AND b.statusID IN (0,1)
)
GO
