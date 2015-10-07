USE [bodb02]
GO
/****** Object:  StoredProcedure [dbo].[Age_Forecast_SelHDP]    Script Date: 10/7/2015 11:14:37 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[Age_Forecast_SelHDP]
	@matchid int,
	@agentid int = null,
	@roleid int = 2,
	@bettype int = 1
AS
/*
Original: ForecastAgentHd
Task: Forecast for HDP bettype.
DB: DB05.bodb02
Revisions:
	- 20090213@Kiwi: + Remove inner join customer and exchange tables because we retrieve data directly from bettrans table.
					 + Super level (@roleid = 4): Remove b.status in ('running','waiting') to use correct Index.
	- 20100527@Henry: Change to use StatusID instead of Status in WHERE statement
	- 20150826@Winnie: Myanmar odds
*/
SET NOCOUNT ON

BEGIN
if @roleid = 2
BEGIN
	select  -x.hdp + score offset, 
		sum(x.hometotal * 1) 'ht',
		sum(x.awaytotal * 1) 'at',
		sum(x.MOwin+x.MOlose*1) 'drawMO',
		sum((x.homewin - x.awaylose) * 1) 'al',
		sum((x.awaywin - x.homelose) * 1) 'hl'
	from --exchange e with(nolock) inner join  
		(select b.currency, hdp2 - hdp1 hdp, livehomescore - liveawayscore score,
			sum(case when betteam='h' then stake * (b.apositiontaking) else 0 end) hometotal,
			sum(case when betteam='a' then stake * (b.apositiontaking) else 0 end) awaytotal,	
			sum(case when b.bettype IN (301,303) AND oddsspread>0 then (case when odds < 0 then 1 else odds end) * stake * (b.apositiontaking)*(oddsspread/100) else 0 end) MOwin,
			sum(case when b.bettype IN (301,303) AND oddsspread<0 then (case when odds < 0 then abs(odds) else 1 end)  * stake * (b.apositiontaking)*(oddsspread/100) else 0 end) MOlose,
			sum(case when betteam='h' then (case when odds < 0 then 1 else odds end) * stake * (b.apositiontaking) else 0 end) homewin,
			sum(case when betteam='a' then (case when odds < 0 then 1 else odds end) * stake * (b.apositiontaking) else 0 end) awaywin,
			sum(case when betteam='h' then (case when odds < 0 then abs(odds) else 1 end)  * stake * (b.apositiontaking) else 0 end) homelose,
			sum(case when betteam='a' then (case when odds < 0 then abs(odds) else 1 end)  * stake * (b.apositiontaking) else 0 end) awaylose
		from bettrans b with(nolock) --inner join customer c with (nolock) on b.custid = c.custid
		where --bettype= @bettype
			--and liveindicator=0
			 ((@bettype=1 AND b.bettype IN (1,301))OR (@bettype=7 AND b.bettype IN (7,303)) OR (b.bettype=@bettype))
			and matchid = @matchid
			AND b.recommend = @agentid
			--AND b.status in ('running','waiting')
			and b.statusID in (0,1)
			and b.ruben = 0
		group by b.currency, hdp2 - hdp1, livehomescore - liveawayscore
		)x --on e.exchangeid = x.currency
	group by -x.hdp + score
END
else if @roleid = 3
BEGIN
	select  -x.hdp + score offset, 
		sum(x.hometotal * 1) 'ht',
		sum(x.awaytotal * 1) 'at',
		sum(x.MOwin+x.MOlose*1) 'drawMO',
		sum((x.homewin - x.awaylose) * 1) 'al',
		sum((x.awaywin - x.homelose) * 1) 'hl'
	from --exchange e with(nolock) inner join  
		(select b.currency, hdp2 - hdp1 hdp, livehomescore - liveawayscore score,
			sum(case when betteam='h' then stake * (b.mpositiontaking) else 0 end) hometotal,
			sum(case when betteam='a' then stake * (b.mpositiontaking) else 0 end) awaytotal,
			sum(case when b.bettype IN (301,303) AND oddsspread>0 then (case when odds < 0 then 1 else odds end) * stake * (b.mpositiontaking)*(oddsspread/100) else 0 end) MOwin,
			sum(case when b.bettype IN (301,303) AND oddsspread<0 then (case when odds < 0 then abs(odds) else 1 end)  * stake * (b.mpositiontaking)*(oddsspread/100) else 0 end) MOlose,	
			sum(case when betteam='h'  then (case when odds < 0 then 1 else odds end) * stake * (b.mpositiontaking) else 0 end) homewin,
			sum(case when betteam='a'  then (case when odds < 0 then 1 else odds end) * stake * (b.mpositiontaking) else 0 end) awaywin,
			sum(case when betteam='h'  then (case when odds < 0 then abs(odds) else 1 end)  * stake * (b.mpositiontaking) else 0 end) homelose,
			sum(case when betteam='a'  then (case when odds < 0 then abs(odds) else 1 end)  * stake * (b.mpositiontaking) else 0 end) awaylose

		from bettrans b with(nolock) inner join customer c with (nolock) on b.custid = c.custid
		where --bettype = @bettype
			--and liveindicator=0
			((@bettype=1 AND b.bettype IN (1,301))OR (@bettype=7 AND b.bettype IN (7,303)) OR (b.bettype=@bettype))
			and matchid = @matchid
			AND b.mrecommend = @agentid
			--AND b.status in ('running','waiting')
			and b.statusID in (0,1)
			and b.ruben = 0
		group by b.currency, hdp2 - hdp1, livehomescore - liveawayscore
		)x --on e.exchangeid = x.currency
	group by -x.hdp + score
END
else if @roleid = 4
BEGIN
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
		from bettrans b with(nolock) inner join customer c with (nolock) on b.custid = c.custid
		where --bettype = @bettype
			--and liveindicator=0
			((@bettype=1 AND b.bettype IN (1,301))OR (@bettype=7 AND b.bettype IN (7,303)) OR (b.bettype=@bettype))
			and matchid = @matchid
			AND b.srecommend = @agentid
			and b.ruben = 0
			and b.statusID in (0,1)
			--AND b.status in ('running','waiting')
			
		group by b.currency, hdp2 - hdp1, livehomescore - liveawayscore
		)x --on e.exchangeid = x.currency
	group by -x.hdp + score
END
END

