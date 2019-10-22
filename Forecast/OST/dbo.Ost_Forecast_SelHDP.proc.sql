/*<info serverAlias="DBOST-bodb_ost" executers="bodbDownlineNet,bodbDownlineNetView" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Ost_Forecast_SelHDP]
	@matchid int,
	@agentid int = null,
	@roleid int = 2,
	@bettype int = 1
AS
/*
	Created:20191021@Bobby
	Task: New Forecast at Agent Site 
	DB: DBOST.bodb_ost
	Original:DB042.bodb02.Age_Forecast_SelHDP
	
	Revisions: 
		- 20191021@Bobby: Initialize [Redmine:114231] 
		
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @n BIGINT = 3
		
	if @roleid = 2
	BEGIN
		
		;WITH bettype_tmp (typegroup, bettype) as 
		(
			SELECT 1, 301
			UNION ALL 
			SELECT 7, 303
			UNION ALL 
			SELECT @bettype, @bettype
		)
	
		select  -x.hdp + score offset, 
			sum(x.hometotal * 1) 'ht',
			sum(x.awaytotal * 1) 'at',
			sum(x.MOwin+x.MOlose*1) 'drawMO',
			sum((x.homewin - x.awaylose) * 1) 'al',
			sum((x.awaywin - x.homelose) * 1) 'hl'
		from 
			(select b.currency, hdp2 - hdp1 hdp, livehomescore - liveawayscore score,
				sum(case when betteam='h' then stake * (b.apositiontaking) else 0 end) hometotal,
				sum(case when betteam='a' then stake * (b.apositiontaking) else 0 end) awaytotal,	
				sum(case when b.bettype IN (301,303) AND oddsspread>0 then (case when odds < 0 then 1 else odds end) * stake * (b.apositiontaking)*(oddsspread/100) else 0 end) MOwin,
				sum(case when b.bettype IN (301,303) AND oddsspread<0 then (case when odds < 0 then abs(odds) else 1 end)  * stake * (b.apositiontaking)*(oddsspread/100) else 0 end) MOlose,
				sum(case when betteam='h' then (case when odds < 0 then 1 else odds end) * stake * (b.apositiontaking) else 0 end) homewin,
				sum(case when betteam='a' then (case when odds < 0 then 1 else odds end) * stake * (b.apositiontaking) else 0 end) awaywin,
				sum(case when betteam='h' then (case when odds < 0 then abs(odds) else 1 end)  * stake * (b.apositiontaking) else 0 end) homelose,
				sum(case when betteam='a' then (case when odds < 0 then abs(odds) else 1 end)  * stake * (b.apositiontaking) else 0 end) awaylose
			--from bettrans b WITH(NOLOCK) 
			FROM dbo.Ost_f_bettrans_running() b
				INNER JOIN (SELECT TOP (@n) typegroup,bettype FROM bettype_tmp) rs ON rs.bettype = b.bettype AND rs.typegroup = @bettype
			where  matchid = @matchid
				AND b.recommend = @agentid
				and b.statusID in (0,1)
			group by b.currency, hdp2 - hdp1, livehomescore - liveawayscore
			)x --on e.exchangeid = x.currency
		group by -x.hdp + score
		OPTION (OPTIMIZE FOR (@n = 1))
	END
	else if @roleid = 3
	BEGIN
		;WITH bettype_tmp (typegroup, bettype) as 
		(
			SELECT 1, 301
			UNION ALL 
			SELECT 7, 303
			UNION ALL 
			SELECT @bettype, @bettype
		)
		select  -x.hdp + score offset, 
			sum(x.hometotal * 1) 'ht',
			sum(x.awaytotal * 1) 'at',
			sum(x.MOwin+x.MOlose*1) 'drawMO',
			sum((x.homewin - x.awaylose) * 1) 'al',
			sum((x.awaywin - x.homelose) * 1) 'hl'
		from 
			(select b.currency, hdp2 - hdp1 hdp, livehomescore - liveawayscore score,
				sum(case when betteam='h' then stake * (b.mpositiontaking) else 0 end) hometotal,
				sum(case when betteam='a' then stake * (b.mpositiontaking) else 0 end) awaytotal,
				sum(case when b.bettype IN (301,303) AND oddsspread>0 then (case when odds < 0 then 1 else odds end) * stake * (b.mpositiontaking)*(oddsspread/100) else 0 end) MOwin,
				sum(case when b.bettype IN (301,303) AND oddsspread<0 then (case when odds < 0 then abs(odds) else 1 end)  * stake * (b.mpositiontaking)*(oddsspread/100) else 0 end) MOlose,	
				sum(case when betteam='h'  then (case when odds < 0 then 1 else odds end) * stake * (b.mpositiontaking) else 0 end) homewin,
				sum(case when betteam='a'  then (case when odds < 0 then 1 else odds end) * stake * (b.mpositiontaking) else 0 end) awaywin,
				sum(case when betteam='h'  then (case when odds < 0 then abs(odds) else 1 end)  * stake * (b.mpositiontaking) else 0 end) homelose,
				sum(case when betteam='a'  then (case when odds < 0 then abs(odds) else 1 end)  * stake * (b.mpositiontaking) else 0 end) awaylose

			--from bettrans b with(nolock) inner join customer c with (nolock) on b.custid = c.custid
			FROM dbo.Ost_f_bettrans_running() b
				INNER JOIN (SELECT TOP (@n) typegroup,bettype FROM bettype_tmp) rs ON rs.bettype = b.bettype AND rs.typegroup = @bettype
			where matchid = @matchid
				AND b.mrecommend = @agentid
				and b.statusID in (0,1)
			group by b.currency, hdp2 - hdp1, livehomescore - liveawayscore
			)x --on e.exchangeid = x.currency
		group by -x.hdp + score
		OPTION (OPTIMIZE FOR (@n = 1))
	END
	else if @roleid = 4
	BEGIN
		;WITH bettype_tmp (typegroup, bettype) as 
		(
			SELECT 1, 301
			UNION ALL 
			SELECT 7, 303
			UNION ALL 
			SELECT @bettype, @bettype
		)
		select  -x.hdp + score offset, 
			sum(x.hometotal * 1) 'ht',
			sum(x.awaytotal * 1) 'at',
			sum(x.MOwin+x.MOlose*1) 'drawMO',
			sum((x.homewin - x.awaylose) * 1) 'al',
			sum((x.awaywin - x.homelose) * 1) 'hl'
		from --exchange e with(nolock) inner join  
			(select b.currency, hdp2 - hdp1 hdp, livehomescore - liveawayscore score,
				sum(case when betteam='h' then stake * (b.spositiontaking) else 0 end) hometotal,
				sum(case when betteam='a' then stake * (b.spositiontaking) else 0 end) awaytotal,	
				sum(case when b.bettype IN (301,303) AND oddsspread>0 then (case when odds < 0 then 1 else odds end) * stake * (b.spositiontaking)*(oddsspread/100) else 0 end) MOwin,
				sum(case when b.bettype IN (301,303) AND oddsspread<0 then (case when odds < 0 then abs(odds) else 1 end)  * stake * (b.spositiontaking)*(oddsspread/100) else 0 end) MOlose,	
				sum(case when betteam='h'  then (case when odds < 0 then 1 else odds end) * stake * (b.spositiontaking) else 0 end) homewin,
				sum(case when betteam='a'  then (case when odds < 0 then 1 else odds end) * stake * (b.spositiontaking) else 0 end) awaywin,
				sum(case when betteam='h'  then (case when odds < 0 then abs(odds) else 1 end)  * stake * (b.spositiontaking) else 0 end) homelose,
				sum(case when betteam='a'  then (case when odds < 0 then abs(odds) else 1 end)  * stake * (b.spositiontaking) else 0 end) awaylose
			--from bettrans b with(nolock) 
			FROM dbo.Ost_f_bettrans_running() b
				INNER JOIN (SELECT TOP (@n) typegroup,bettype FROM bettype_tmp) rs ON rs.bettype = b.bettype AND rs.typegroup = @bettype
			where matchid = @matchid
				AND b.srecommend = @agentid
				and b.statusID in (0,1)
			group by b.currency, hdp2 - hdp1, livehomescore - liveawayscore
			)x --on e.exchangeid = x.currency
		group by -x.hdp + score
		OPTION (OPTIMIZE FOR (@n = 1))
	END
END
GO