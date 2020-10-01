/*<info serverAlias="DB042-bodb02" executers="bodbDownlineNet,bodbDownlineNetView" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Age_Forecast_SelOU]
	@matchid int,
	@agentid int = null,
	@roleid int = 2,
	@bettype int = 3
AS
/*
Task: Forcast for OU bettypes.
DB: DB042/bodb02

Revisions: 
	- 20090213@Kiwi: + Remove inner join customer and exchange tables because we retrieve data directly from bettrans table.
					 + Super level (@roleid = 4): Remove b.status in ('running','waiting') to use correct Index.
	- 20100527@Henry: Change to use StatusID instead of Status in WHERE statement
	- 20150825@Winnie: Myanmar Odds
	- 20180802@Helen: Update code for adjusting indexes - [Redmine:98757]
	- 20190918@Percy: Remove inactive products [RedmineID: #118699]
	- 20200929@Malcolm : add Oddstype and oddsspread [RedmineId : #141956]
*/
BEGIN
	SET NOCOUNT ON
	
	if @roleid = 2 
	BEGIN
		select x.liveindicator, x.status, x.score +  x.hdp offset, oddstype, oddsspread,
			sum(x.hometotal * 1) 'ht',
			sum(x.awaytotal * 1) 'at',
			sum((x.homewin- x.awaylose) * 1) 'al',
			sum((x.awaywin- x.homelose) * 1) 'hl'
		from 
			(select liveindicator,  status, b.currency, hdp1 hdp, 0 score, oddstype, oddsspread,
				sum(case when betteam='h' then stake * (b.apositiontaking) else 0 end) hometotal,
				sum(case when betteam='a' then stake * (b.apositiontaking) else 0 end) awaytotal,	
				sum(case when betteam='h' then (case when odds < 0 then 1 else odds end) * stake * (b.apositiontaking) else 0 end) homewin,
				sum(case when betteam='a' then (case when odds < 0 then 1 else odds end) * stake * (b.apositiontaking) else 0 end) awaywin,
				sum(case when betteam='h' then (case when odds < 0 then abs(odds) else 1 end)  * stake * (b.apositiontaking) else 0 end) homelose,
				sum(case when betteam='a' then (case when odds < 0 then abs(odds) else 1 end)  * stake * (b.apositiontaking) else 0 end) awaylose
			from bettrans b with(nolock) 
			where matchid = @matchid
				AND b.bettype = @bettype
				AND b.recommend = @agentid
				and b.statusID in (0,1)
			group by liveindicator, status, b.currency, hdp1, livehomescore + liveawayscore, oddstype, oddsspread
			)x 
		group by x.status, liveindicator, x.score + x.hdp ,oddstype, oddsspread
	END
	else if @roleid = 3
	BEGIN
		select x.liveindicator, x.status, x.score +  x.hdp offset, oddstype, oddsspread, 
			sum(x.hometotal * 1) 'ht',
			sum(x.awaytotal * 1) 'at',
			sum((x.homewin - x.awaylose) * 1) 'al',
			sum((x.awaywin - x.homelose) * 1) 'hl'
		from 
			(select liveindicator,  status, b.currency, hdp1 hdp, 0 score ,oddstype, oddsspread,
				sum(case when betteam='h' then stake * (b.mpositiontaking) else 0 end) hometotal,
				sum(case when betteam='a' then stake * (b.mpositiontaking) else 0 end) awaytotal,	
				sum(case when betteam='h'  then (case when odds < 0 then 1 else odds end) * stake * (b.mpositiontaking) else 0 end) homewin,
				sum(case when betteam='a'  then (case when odds < 0 then 1 else odds end) * stake * (b.mpositiontaking) else 0 end) awaywin,
				sum(case when betteam='h'  then (case when odds < 0 then abs(odds) else 1 end)  * stake * (b.mpositiontaking) else 0 end) homelose,
				sum(case when betteam='a'  then (case when odds < 0 then abs(odds) else 1 end)  * stake * (b.mpositiontaking) else 0 end) awaylose
			from bettrans b with(nolock) 
			where matchid = @matchid
				AND b.bettype = @bettype
				AND b.mrecommend = @agentid
				and b.statusID in (0,1)
			group by liveindicator, status, b.currency, hdp1, livehomescore + liveawayscore, oddstype, oddsspread
			)x 
		group by x.status, liveindicator, x.score + x.hdp, oddstype, oddsspread
	END
	else if @roleid = 4
	BEGIN
		select x.liveindicator, x.status, x.score +  x.hdp offset, oddstype, oddsspread,
			sum(x.hometotal * 1) 'ht',
			sum(x.awaytotal * 1) 'at',
			sum((x.homewin - x.awaylose) * 1) 'al',
			sum((x.awaywin - x.homelose) * 1) 'hl'
		from 
			(select liveindicator,  status, b.currency, hdp1 hdp, 0 score,oddstype, oddsspread,
				sum(case when betteam='h' then stake * (b.spositiontaking) else 0 end) hometotal,
				sum(case when betteam='a' then stake * (b.spositiontaking) else 0 end) awaytotal,	
				sum(case when betteam='h'  then (case when odds < 0 then 1 else odds end) * stake * (b.spositiontaking) else 0 end) homewin,
				sum(case when betteam='a'  then (case when odds < 0 then 1 else odds end) * stake * (b.spositiontaking) else 0 end) awaywin,
				sum(case when betteam='h'  then (case when odds < 0 then abs(odds) else 1 end)  * stake * (b.spositiontaking) else 0 end) homelose,
				sum(case when betteam='a'  then (case when odds < 0 then abs(odds) else 1 end)  * stake * (b.spositiontaking) else 0 end) awaylose
			from bettrans b with(nolock) 
			where matchid = @matchid
				AND b.bettype = @bettype
				AND b.srecommend = @agentid
				AND b.statusID IN (0,1)
			group by liveindicator, status, b.currency, hdp1, livehomescore + liveawayscore, oddstype, oddsspread
			)x 
		group by x.status, liveindicator, x.score + x.hdp, oddstype, oddsspread
	END
END
GO
