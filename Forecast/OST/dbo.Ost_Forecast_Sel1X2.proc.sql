/*<info serverAlias="DBOST-bodb_ost" executers="bodbDownlineNet,bodbDownlineNetView" viewers="" isFunction="0"></info>*/	
ALTER PROCEDURE [dbo].[Ost_Forecast_Sel1X2]
	@matchid int ,
	@bettype int,
	@custid int,
	@roleid int = 2
AS
/*
	Created:20191021@Bobby
	Task: New Forecast at Agent Site 
	DB: DBOST.bodb_ost
	Original:DB042.bodb02.Age_Forecast_Sel1X2
	
	Revisions: 
		- 20191021@Bobby: Initialize [Redmine:114231] 
		
*/
BEGIN
	SET NOCOUNT ON
	--Declare @BetType1x2 int, @BetTypeHT1x2 int
	--select @BetType1x2 = 5, @BetTypeHT1x2 = 15

	DECLARE @tblBetType TABLE(BetType INT,isHT BIT)

	IF @bettype = 5
	BEGIN
		INSERT INTO @tblBetType(BetType,isHT)
		SELECT val AS BetType,0 isHT FROM strSplit('5',',') --BETTYPE FT
	END
	ELSE
	BEGIN
		INSERT INTO @tblBetType(BetType,isHT)
		SELECT val AS BetType,1 isHT FROM strSplit('15,167',',') --BETTYPE FT
	END

	if @roleid = 2 
	BEGIN
		select x.MatchID, x.homeid,	x.awayid,	
			x.liveindicator, isnull(x.LiveHomeScore, 0) as livehomescore, isnull(x.LiveAwayScore, 0) as liveawayscore,x.ShowTime,x.MatchCode,isNeutral,
			(x.awaywin - x.homelose - x.drawlose) 'al',
			(x.homewin - x.awaylose - x.drawlose) 'hl',
			(x.drawwin - x.awaylose - x.homelose) 'dl',
		
			(x.ht_awaywin - x.ht_drawlose - x.ht_homelose) 'ht_al',
			(x.ht_homewin - x.ht_drawlose - x.ht_awaylose) 'ht_hl',
			(x.ht_drawwin - x.ht_awaylose - x.ht_homelose) 'ht_dl'
		from (select m.MatchID, m.homeid,	m.awayid,	
				b.liveindicator, isnull(b.LiveHomeScore, 0) as livehomescore, isnull(b.LiveAwayScore, 0) as liveawayscore,M.ShowTime,M.MatchCode,
				isnull(m.isNeutral, CONVERT(BIT,0)) as IsNeutral,
				sum(case when betteam='1' and tblBetType.isHT = 0 then (case when odds < 0 then 1 else odds - 1 end) * stake * (b.apositiontaking) else 0 end) homewin,
				sum(case when betteam='2' and tblBetType.isHT = 0 then (case when odds < 0 then 1 else odds - 1 end) * stake * (b.apositiontaking) else 0 end) awaywin,
				sum(case when betteam='x' and tblBetType.isHT = 0 then (case when odds < 0 then 1 else odds - 1 end) * stake * (b.apositiontaking) else 0 end) drawwin,

				sum(case when betteam='1' and tblBetType.isHT = 0 then (case when odds < 0 then abs(odds - 1) else 1 end)  * stake * (b.apositiontaking) else 0 end) homelose,
				sum(case when betteam='2' and tblBetType.isHT = 0 then (case when odds < 0 then abs(odds - 1) else 1 end)  * stake * (b.apositiontaking) else 0 end) awaylose,
				sum(case when betteam='x' and tblBetType.isHT = 0 then (case when odds < 0 then abs(odds - 1) else 1 end)  * stake * (b.apositiontaking) else 0 end) drawlose,

				sum(case when betteam='1' and tblBetType.isHT = 1 then (case when odds < 0 then 1 else odds - 1 end) * stake * (b.apositiontaking) else 0 end) ht_homewin,
				sum(case when betteam='2' and tblBetType.isHT = 1 then (case when odds < 0 then 1 else odds - 1 end) * stake * (b.apositiontaking) else 0 end) ht_awaywin,
				sum(case when betteam='x' and tblBetType.isHT = 1 then (case when odds < 0 then 1 else odds - 1 end) * stake * (b.apositiontaking) else 0 end) ht_drawwin,

				sum(case when betteam='1' and tblBetType.isHT = 1 then (case when odds < 0 then abs(odds - 1) else 1 end)  * stake * (b.apositiontaking) else 0 end) ht_homelose,
				sum(case when betteam='2' and tblBetType.isHT = 1 then (case when odds < 0 then abs(odds - 1) else 1 end)  * stake * (b.apositiontaking) else 0 end) ht_awaylose,
				sum(case when betteam='x' and tblBetType.isHT = 1 then (case when odds < 0 then abs(odds - 1) else 1 end)  * stake * (b.apositiontaking) else 0 end) ht_drawlose
			--from dbo.bettrans b with(nolock) 
			FROM dbo.Ost_f_bettrans_running() b
				inner join dbo.Match M with (NOLOCK) on b.MatchID = M.MatchID and M.EventStatus = 'running'			
				INNER JOIN @tblBetType tblBetType ON b.bettype = tblBetType.BetType
			where 
				b.matchid = @MatchID
				AND b.recommend = @custid
				AND b.statusID in (0,1)
				
			group by liveindicator, b.currency ,m.MatchID, m.homeid, m.awayid,	
				b.liveindicator, b.LiveHomeScore,b.LiveAwayScore,M.ShowTime,M.MatchCode,isNeutral
			) AS x 
	END
	else if @roleid = 3
	BEGIN
		select x.MatchID, x.homeid,	x.awayid,	
			x.liveindicator, isnull(x.LiveHomeScore, 0) as livehomescore, isnull(x.LiveAwayScore, 0) as liveawayscore,x.ShowTime,x.MatchCode,isNeutral,
			(x.awaywin - x.homelose - x.drawlose) 'al',
			(x.homewin - x.awaylose - x.drawlose) 'hl',
			(x.drawwin - x.awaylose - x.homelose) 'dl',
		
			(x.ht_awaywin - x.ht_drawlose - x.ht_homelose) 'ht_al',
			(x.ht_homewin - x.ht_drawlose - x.ht_awaylose) 'ht_hl',
			(x.ht_drawwin - x.ht_awaylose - x.ht_homelose) 'ht_dl'
		from 
			(select m.MatchID, m.homeid,	m.awayid,	
				b.liveindicator, isnull(b.LiveHomeScore, 0) as livehomescore, isnull(b.LiveAwayScore, 0) as liveawayscore,M.ShowTime,M.MatchCode,
				isnull(m.isNeutral, CONVERT(BIT,0)) as IsNeutral,
				sum(case when betteam='1' and tblBetType.isHT = 0 then (case when odds < 0 then 1 else odds - 1 end) * stake * (b.mpositiontaking) else 0 end) homewin,
				sum(case when betteam='2' and tblBetType.isHT = 0 then (case when odds < 0 then 1 else odds - 1 end) * stake * (b.mpositiontaking) else 0 end) awaywin,			
				sum(case when betteam='x' and tblBetType.isHT = 0 then (case when odds < 0 then 1 else odds - 1 end) * stake * (b.mpositiontaking) else 0 end) drawwin,
				
				sum(case when betteam='1' and tblBetType.isHT = 0 then (case when odds < 0 then abs(odds - 1) else 1 end)  * stake * (b.mpositiontaking) else 0 end) homelose,
				sum(case when betteam='2' and tblBetType.isHT = 0 then (case when odds < 0 then abs(odds - 1) else 1 end)  * stake * (b.mpositiontaking) else 0 end) awaylose,			
				sum(case when betteam='x' and tblBetType.isHT = 0 then (case when odds < 0 then abs(odds - 1) else 1 end)  * stake * (b.mpositiontaking) else 0 end) drawlose,

				sum(case when betteam='1' and tblBetType.isHT = 1 then (case when odds < 0 then 1 else odds - 1 end) * stake * (b.mpositiontaking) else 0 end) ht_homewin,
				sum(case when betteam='2' and tblBetType.isHT = 1 then (case when odds < 0 then 1 else odds - 1 end) * stake * (b.mpositiontaking) else 0 end) ht_awaywin,			
				sum(case when betteam='x' and tblBetType.isHT = 1 then (case when odds < 0 then 1 else odds - 1 end) * stake * (b.mpositiontaking) else 0 end) ht_drawwin,
				
				sum(case when betteam='1' and tblBetType.isHT = 1 then (case when odds < 0 then abs(odds - 1) else 1 end)  * stake * (b.mpositiontaking) else 0 end) ht_homelose,
				sum(case when betteam='2' and tblBetType.isHT = 1 then (case when odds < 0 then abs(odds - 1) else 1 end)  * stake * (b.mpositiontaking) else 0 end) ht_awaylose,			
				sum(case when betteam='x' and tblBetType.isHT = 1 then (case when odds < 0 then abs(odds - 1) else 1 end)  * stake * (b.mpositiontaking) else 0 end) ht_drawlose
			--from dbo.bettrans b with(nolock) 
			FROM dbo.Ost_f_bettrans_running() b
				inner join dbo.Match M with (NOLOCK) on b.MatchID = M.MatchID and M.EventStatus = 'running'
				INNER JOIN @tblBetType tblBetType ON b.bettype = tblBetType.BetType
			where  b.matchid = @MatchID 
				AND b.mrecommend = @custid
				AND b.statusID in (0,1)
			group by liveindicator, b.currency ,m.MatchID, m.homeid, m.awayid,	
				b.liveindicator, b.LiveHomeScore,b.LiveAwayScore,M.ShowTime,M.MatchCode,isNeutral
			) AS x 
	END
	else if @roleid = 4
	BEGIN
		select  x.MatchID, x.homeid, x.awayid,	
			x.liveindicator, isnull(x.LiveHomeScore, 0) as livehomescore, isnull(x.LiveAwayScore, 0) as liveawayscore,x.ShowTime,x.MatchCode,isNeutral,
			(x.awaywin - x.homelose - x.drawlose) 'al',
			(x.homewin - x.awaylose - x.drawlose) 'hl',
			(x.drawwin - x.awaylose - x.homelose) 'dl',
		
			(x.ht_awaywin - x.ht_drawlose - x.ht_homelose) 'ht_al',
			(x.ht_homewin - x.ht_drawlose - x.ht_awaylose) 'ht_hl',
			(x.ht_drawwin - x.ht_awaylose - x.ht_homelose) 'ht_dl'
		from 
			(select m.MatchID, m.homeid, m.awayid,	
				b.liveindicator, isnull(b.LiveHomeScore, 0) as livehomescore, isnull(b.LiveAwayScore, 0) as liveawayscore,M.ShowTime,M.MatchCode,
				isnull(m.isNeutral, CONVERT(BIT,0)) as IsNeutral,
				sum(case when betteam='1' and tblBetType.isHT = 0 then (case when odds < 0 then 1 else odds - 1 end) * stake * (b.spositiontaking) else 0 end) homewin,
				sum(case when betteam='2' and tblBetType.isHT = 0 then (case when odds < 0 then 1 else odds - 1 end) * stake * (b.spositiontaking) else 0 end) awaywin,
				sum(case when betteam='x' and tblBetType.isHT = 0 then (case when odds < 0 then 1 else odds - 1 end) * stake * (b.spositiontaking) else 0 end) drawwin,

				sum(case when betteam='1' and tblBetType.isHT = 0 then (case when odds < 0 then abs(odds - 1) else 1 end)  * stake * (b.spositiontaking) else 0 end) homelose,
				sum(case when betteam='2' and tblBetType.isHT = 0 then (case when odds < 0 then abs(odds - 1) else 1 end)  * stake * (b.spositiontaking) else 0 end) awaylose,	
				sum(case when betteam='x' and tblBetType.isHT = 0 then (case when odds < 0 then abs(odds - 1) else 1 end)  * stake * (b.spositiontaking) else 0 end) drawlose,

				sum(case when betteam='1'  and tblBetType.isHT = 1 then (case when odds < 0 then 1 else odds - 1 end) * stake * (b.spositiontaking) else 0 end) ht_homewin,
				sum(case when betteam='2'  and tblBetType.isHT = 1 then (case when odds < 0 then 1 else odds - 1 end) * stake * (b.spositiontaking) else 0 end) ht_awaywin,
				sum(case when betteam='x'  and tblBetType.isHT = 1 then (case when odds < 0 then 1 else odds - 1 end) * stake * (b.spositiontaking) else 0 end) ht_drawwin,

				sum(case when betteam='1'  and tblBetType.isHT = 1 then (case when odds < 0 then abs(odds - 1) else 1 end)  * stake * (b.spositiontaking) else 0 end) ht_homelose,
				sum(case when betteam='2'  and tblBetType.isHT = 1 then (case when odds < 0 then abs(odds - 1) else 1 end)  * stake * (b.spositiontaking) else 0 end) ht_awaylose,	
				sum(case when betteam='x'  and tblBetType.isHT = 1 then (case when odds < 0 then abs(odds - 1) else 1 end)  * stake * (b.spositiontaking) else 0 end) ht_drawlose
			--from dbo.bettrans b with(nolock) 
			FROM dbo.Ost_f_bettrans_running() b
				inner join dbo.Match M with (NOLOCK) on b.MatchID = M.MatchID and M.EventStatus = 'running'
				INNER JOIN @tblBetType tblBetType ON b.bettype = tblBetType.BetType
			where b.matchid = @MatchID
				AND b.srecommend = @custid
				AND b.statusID in (0,1)
			group by liveindicator, b.currency ,m.MatchID, m.homeid, m.awayid,	
				b.liveindicator, b.LiveHomeScore,b.LiveAwayScore,M.ShowTime,M.MatchCode,isNeutral
			) AS x 
	END
END	
GO
