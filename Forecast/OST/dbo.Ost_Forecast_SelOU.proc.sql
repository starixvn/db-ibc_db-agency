/*<info serverAlias="DBOST-bodb_ost" executers="bodbDownlineNet,bodbDownlineNetView" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Ost_Forecast_SelOU]
	@matchid int,
	@agentid int = null,
	@roleid int = 2,
	@bettype int = 3
AS
/*
	Created:20191021@Bobby
	Task: New Forecast at Agent Site 
	DB: DBOST.bodb_ost
	Original:DB042.bodb02.Age_Forecast_SelOU
	
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
			SELECT 3, 302
			UNION ALL 
			SELECT 8, 304
			UNION ALL 
			SELECT @bettype, @bettype
		)
		
		select x.liveindicator, x.status, x.score +  x.hdp offset, 
			sum(x.hometotal * 1) 'ht',
			sum(x.awaytotal * 1) 'at',
			sum(x.MOwin+x.MOlose*1) 'drawMO',
			sum((x.homewin- x.awaylose) * 1) 'al',
			sum((x.awaywin- x.homelose) * 1) 'hl'
		from 
			(select liveindicator,  status, b.currency, hdp1 hdp, 0 score,
				sum(case when betteam='h' then stake * (b.apositiontaking) else 0 end) hometotal,
				sum(case when betteam='a' then stake * (b.apositiontaking) else 0 end) awaytotal,	
				sum(case when b.bettype IN (302,304) AND oddsspread>0 then (case when odds < 0 then 1 else odds end) * stake * (b.apositiontaking)*(oddsspread/100) else 0 end) MOwin,
				sum(case when b.bettype IN (302,304) AND oddsspread<0 then (case when odds < 0 then abs(odds) else 1 end)  * stake * (b.apositiontaking)*(oddsspread/100) else 0 end) MOlose,
				sum(case when betteam='h' then (case when odds < 0 then 1 else odds end) * stake * (b.apositiontaking) else 0 end) homewin,
				sum(case when betteam='a' then (case when odds < 0 then 1 else odds end) * stake * (b.apositiontaking) else 0 end) awaywin,
				sum(case when betteam='h' then (case when odds < 0 then abs(odds) else 1 end)  * stake * (b.apositiontaking) else 0 end) homelose,
				sum(case when betteam='a' then (case when odds < 0 then abs(odds) else 1 end)  * stake * (b.apositiontaking) else 0 end) awaylose
			--from bettrans b with(nolock) 
			FROM dbo.Ost_f_bettrans_running() b
				INNER JOIN (SELECT TOP (@n) typegroup,bettype FROM bettype_tmp) rs ON rs.bettype = b.bettype AND rs.typegroup = @bettype
			where matchid = @matchid
				AND b.recommend = @agentid
				and b.statusID in (0,1)
			group by liveindicator, status, b.currency, hdp1, livehomescore + liveawayscore
			)x 
		group by x.status, liveindicator, x.score + x.hdp
		OPTION (OPTIMIZE FOR (@n = 1))
	END
	else if @roleid = 3
	BEGIN
	----
	---------
		;WITH bettype_tmp (typegroup, bettype) as 
		(
			SELECT 3, 302
			UNION ALL 
			SELECT 8, 304
			UNION ALL 
			SELECT @bettype, @bettype
		)
		select x.liveindicator, x.status, x.score +  x.hdp offset, 
			sum(x.hometotal * 1) 'ht',
			sum(x.awaytotal * 1) 'at',
			sum(x.MOwin+x.MOlose*1) 'drawMO',
			sum((x.homewin - x.awaylose) * 1) 'al',
			sum((x.awaywin - x.homelose) * 1) 'hl'
		from 
			(select liveindicator,  status, b.currency, hdp1 hdp, 0 score,
				sum(case when betteam='h' then stake * (b.mpositiontaking) else 0 end) hometotal,
				sum(case when betteam='a' then stake * (b.mpositiontaking) else 0 end) awaytotal,	
				sum(case when b.bettype IN (302,304) AND oddsspread>0 then (case when odds < 0 then 1 else odds end) * stake * (b.mpositiontaking)*(oddsspread/100) else 0 end) MOwin,
				sum(case when b.bettype IN (302,304) AND oddsspread<0 then (case when odds < 0 then abs(odds) else 1 end)  * stake * (b.mpositiontaking)*(oddsspread/100) else 0 end) MOlose,
				sum(case when betteam='h'  then (case when odds < 0 then 1 else odds end) * stake * (b.mpositiontaking) else 0 end) homewin,
				sum(case when betteam='a'  then (case when odds < 0 then 1 else odds end) * stake * (b.mpositiontaking) else 0 end) awaywin,
				sum(case when betteam='h'  then (case when odds < 0 then abs(odds) else 1 end)  * stake * (b.mpositiontaking) else 0 end) homelose,
				sum(case when betteam='a'  then (case when odds < 0 then abs(odds) else 1 end)  * stake * (b.mpositiontaking) else 0 end) awaylose

			--from bettrans b with(nolock) 
			FROM dbo.Ost_f_bettrans_running() b
				INNER JOIN (SELECT TOP (@n) typegroup,bettype FROM bettype_tmp) rs ON rs.bettype = b.bettype AND rs.typegroup = @bettype
			where matchid = @matchid
				AND b.mrecommend = @agentid
				and b.statusID in (0,1)
			group by liveindicator, status, b.currency, hdp1, livehomescore + liveawayscore
			)x 
		group by x.status, liveindicator, x.score + x.hdp
		OPTION (OPTIMIZE FOR (@n = 1))
	END
	else if @roleid = 4
	BEGIN
		;WITH bettype_tmp (typegroup, bettype) as 
		(
			SELECT 3, 302
			UNION ALL 
			SELECT 8, 304
			UNION ALL 
			SELECT @bettype, @bettype
		)
		select x.liveindicator, x.status, x.score +  x.hdp offset, 
			sum(x.hometotal * 1) 'ht',
			sum(x.awaytotal * 1) 'at',
			sum(x.MOwin+x.MOlose*1) 'drawMO',
			sum((x.homewin - x.awaylose) * 1) 'al',
			sum((x.awaywin - x.homelose) * 1) 'hl'
		from 
			(select liveindicator,  status, b.currency, hdp1 hdp, 0 score,
				sum(case when betteam='h' then stake * (b.spositiontaking) else 0 end) hometotal,
				sum(case when betteam='a' then stake * (b.spositiontaking) else 0 end) awaytotal,	
				sum(case when b.bettype IN (302,304) AND oddsspread>0 then (case when odds < 0 then 1 else odds end) * stake * (b.spositiontaking)*(oddsspread/100) else 0 end) MOwin,
				sum(case when b.bettype IN (302,304) AND oddsspread<0 then (case when odds < 0 then abs(odds) else 1 end)  * stake * (b.spositiontaking)*(oddsspread/100) else 0 end) MOlose,
				sum(case when betteam='h'  then (case when odds < 0 then 1 else odds end) * stake * (b.spositiontaking) else 0 end) homewin,
				sum(case when betteam='a'  then (case when odds < 0 then 1 else odds end) * stake * (b.spositiontaking) else 0 end) awaywin,
				sum(case when betteam='h'  then (case when odds < 0 then abs(odds) else 1 end)  * stake * (b.spositiontaking) else 0 end) homelose,
				sum(case when betteam='a'  then (case when odds < 0 then abs(odds) else 1 end)  * stake * (b.spositiontaking) else 0 end) awaylose
			--from bettrans b with(nolock) 
			FROM dbo.Ost_f_bettrans_running() b
				INNER JOIN (SELECT TOP (@n) typegroup,bettype FROM bettype_tmp) rs ON rs.bettype = b.bettype AND rs.typegroup = @bettype
			where matchid = @matchid
				AND b.srecommend = @agentid
				AND b.statusID IN (0,1)
				
			group by liveindicator, status, b.currency, hdp1, livehomescore + liveawayscore
			)x 
		group by x.status, liveindicator, x.score + x.hdp
		OPTION (OPTIMIZE FOR (@n = 1))
	END

END
GO
