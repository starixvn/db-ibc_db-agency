/*<info serverAlias="DBAGE-bodb02" executers="bodbAdminNet,bodbDownlineNet,bodbDownlineNetView" viewers="" isFunction="0" isNested="0"></info>*/
USE bodb02
GO

ALTER PROCEDURE [dbo].[Age_Rpt_MatchWinLossDetail_Ag] 
	@CustID				INT
	,@FromDate			SMALLDATETIME
	,@ToDate			SMALLDATETIME
	,@MoveBetsDay		SMALLDATETIME
	,@league			VARCHAR(4000)
	,@showSB			BIT = 1
	,@showRB			BIT = 0
	,@showNG			BIT = 0
	,@showLiveCasino	BIT = 0
	,@showVS			BIT = 0
	,@showLK3		BIT = 0
WITH RECOMPILE

AS

/*
	Created: 
	Task: 
	DB: DBAGE.bodb02
	Original:Rpt_MatchWinLostDetail_Ag
	
	Revisions:
		- 20081031@QuangVinh: Add more result "Horseracing", "Financial",
				BetGroup	0: normal and financial, 1 Horseracing, 2 outright, 3 mixparlay
		- 20090326@Phuc: get indexname for FI
		- 20090327@Kiwi: remove comstatus
		- 20090401@Hanh: exclude the refund match(isnull(m.betstatus,'')<>'refund')
		- 20090523@Hiep: get more result for Horse racing fix odds
		- 20091126@Jamie: Change the gross commission by level (super/master/agent)
			+ super  = scomm/(1 - tpos)
			+ master = acomm/(1 - apos - mpos)
			+ agent  = comm /(1 - apos)
			Applied on Dec 1, 2009 
		-- 20100527@Henry: Change to use StatusID instead of Status in WHERE statement
		- 20110221@Johnson: get Match WL by leagues and sport
		- 20110506@Jamie: Fix filter by sporttype for SB
		- 20110516@Johnson: Apply new arrange bettype
		- 20110801@Sophia: change the range of number game's bettype from 81 to 120. Add new Bettype 29 for Combination Mix Parlay
		- 20110802@Sophia: Add new column liveindicator to separate Fulltime or Deadball, but only for Number Game, if not Number Game not group by liveindicator and return 0 for liveindicator
		- 20110822@Sophia: Count Negative stake as positive turnover
		- 20111130@Sophia: . Change the range of Sport book bettype>=121 and bettype<=999	
						   . Remove ABSdate = '2011-09-01'
		- 20120112@Sophia: Add LiveCasino: Sporttype: 162, bettype: 1101 ->1199
		- 20120807@Sophia:  .Add new parametter @showVS for Virtual Sports (sporttype = 180 for representing)
							.Remove Financial product
		- 20121031@Johnson: Add new range bettype for sportting solutions: 1301 -> 1334
		- 20130228@Elodie: Add Virtual HR report
		- 20140926@Sophia:  Expand the range of Sporting Solution (1301 -> 1399)
							Grouping duplicate bettypes of Sporting Solution and IBC [Redmine: #23444]
		- 20150313@Cody: Apply sporttype bettype matrix [Redmine: #30169]
		- 20160712@Percy: Using inline function for SportBettypeMatrix [RedmineID: #62861]
		- 20170808@Percy: Integrate Lucky 3 [RedmineID: #80219]
		- 20200622@Sol: Archive VSRaceInfo - changed to use VSRaceInfo14 [RedmineID: #135963]
		- 20201229@Malcolm : Support Happy 5 Linked Games [RedminedId : #146542]
*/

SET NOCOUNT ON

IF OBJECT_ID('tempdb..#SportBettype') IS NOT NULL
BEGIN
	DROP TABLE #SportBettype
END

CREATE TABLE #SportBettype(
			ProductID INT
			,Bettype INT
			,EventType INT
		)

DECLARE @ProductPrefix VARCHAR(100)='-'

IF @ShowSB	= 1
	BEGIN
		SET @ProductPrefix=@ProductPrefix+',SB'
	END

IF @showRB	= 1
	BEGIN	
		SET @ProductPrefix=@ProductPrefix+',RB'
	END

IF @showNG	= 1
	BEGIN	
		SET @ProductPrefix=@ProductPrefix+',NG'
	END
	
IF @showLiveCasino	= 1
	BEGIN	
		SET @ProductPrefix=@ProductPrefix+',LC'		
	END
	
IF @showVS	= 1
	BEGIN	
		SET @ProductPrefix=@ProductPrefix+',VS'
	END

IF @showLK3 = 1
	BEGIN	
		SET @ProductPrefix=@ProductPrefix+',LK3'
	END
	
DECLARE @isTest BIT
SELECT  @isTest = dbo.f_CheckSPVersion(@@PROCID)

INSERT INTO #SportBettype (ProductID, Bettype, EventType)
SELECT ProductID, Bettype, EventType FROM dbo.f_SportBettypeMatrix_Sel(0,0,0,2,'',@ProductPrefix,@isTest)

IF OBJECT_ID('tempdb..#AgMatchWLDetails') IS NOT NULL
BEGIN
	DROP TABLE #AgMatchWLDetails
END

CREATE TABLE #AgMatchWLDetails(
				BetGroup		INT
				,matchid		INT
				,homeid			INT
				,awayid			INT
				,bettype		SMALLINT
				,liveindicator	INT
				,leagueid		INT
				,turnover		MONEY
				,GrossComm		MONEY
				,MemberWinLost	MONEY
				,MemberComm		MONEY
				,MemberTotal	MONEY
				,AgentWinLost	MONEY
				,AgentComm		MONEY
				,AgentTotal		MONEY
				,CompanyComm	MONEY
				,CompanyTotal	MONEY
				,race			NVARCHAR(20)
				,matchcode		NVARCHAR(50)
				,isNeutral		BIT
				,showtime		NVARCHAR(50))

IF @league = ''
BEGIN
	-- Get all leagues by sport's selected
	IF @Todate > @MoveBetsDay
	BEGIN
		INSERT INTO #AgMatchWLDetails
			SELECT
				0 as BetGroup,
				m.matchid,
				m.homeid,
				m.awayid,
				b.bettype,
				b.liveindicator,
				m.leagueid,
				SUM(ABS(stake)) as turnover,
				SUM(comm/(1 - apositiontaking)) as GrossComm,
				SUM(winlost - actual_stake) as MemberWinLost,
				SUM(playercomm) as MemberComm,
				SUM(Winlost - actual_stake + playercomm) as MemberTotal,
				SUM(awinlost) as AgentWinLost,
				SUM(comm - playercomm) AS  AgentComm,
				SUM(awinlost + comm - playercomm) AS AgentTotal,
				SUM(comm) as CompanyComm,
				-SUM(winlost - actual_stake + awinlost + comm) as CompanyTotal,		
				'' as race,
				m.matchcode,
				isnull(m.isNeutral, CONVERT(BIT,0)) as IsNeutral,
				'' as showtime
			FROM 
				bettrans b WITH (NOLOCK)
				INNER JOIN match m WITH (NOLOCK) ON m.matchid = b.matchid
				INNER JOIN #SportBettype s ON s.Bettype = b.bettype
			WHERE 
				b.recommend = @custid
				AND b.bettype NOT IN (9,10,29)
				AND b.statusID NOT IN (101, 102, 103)
				AND m.eventdate >= @fromdate
				AND m.eventdate <= @todate
				AND m.eventstatus = 'completed'
				AND isnull(m.betstatus, '') <> 'refund'
				AND s.ProductID = 3
			GROUP BY 
				m.matchid, m.homeid, m.awayid, b.bettype, m.leagueid, m.matchcode, m.isNeutral, b.liveindicator	

		UNION ALL --- Not number Game not group by liveindicator
		SELECT
				0 as BetGroup,
				m.matchid,
				m.homeid,
				m.awayid,
				CASE WHEN ISNULL(f.bettype,0) = 0 THEN b.bettype ELSE f.GroupTypeId END AS bettype,	
				0 as liveindicator,
				m.leagueid,
				SUM(ABS(stake)) as turnover,
				SUM(comm/(1 - apositiontaking)) as GrossComm,
				SUM(winlost - actual_stake) as MemberWinLost,
				SUM(playercomm) as MemberComm,
				SUM(Winlost - actual_stake + playercomm) as MemberTotal,
				SUM(awinlost) as AgentWinLost,
				SUM(comm - playercomm) AS  AgentComm,
				SUM(awinlost + comm - playercomm) AS AgentTotal,
				SUM(comm) as CompanyComm,
				-SUM(winlost - actual_stake + awinlost + comm) as CompanyTotal,		
				'' as race,
				m.matchcode,
				isnull(m.isNeutral, CONVERT(BIT,0)) as IsNeutral,
				isnull(m.showtime,'') as showtime
			FROM 
				bettrans b WITH (NOLOCK)
				INNER JOIN match m WITH (NOLOCK) ON m.matchid = b.matchid
				LEFT JOIN (SELECT * FROM [dbo].[f_GroupBettype]()) f ON f.bettype = b.bettype
				INNER JOIN #SportBettype s ON s.Bettype = b.bettype
			WHERE 
				b.recommend = @custid
				AND b.bettype NOT IN (9,10,29)
				AND b.statusID NOT IN (101, 102, 103)
				AND m.eventdate >= @fromdate
				AND m.eventdate <= @todate
				AND m.eventstatus = 'completed'
				AND isnull(m.betstatus,'') <> 'refund'
				AND s.ProductID IN (1, 4, 5, 26)
				AND s.EventType <> 3
			GROUP BY 
				m.matchid, m.homeid, m.awayid, m.leagueid, m.matchcode, m.isNeutral, m.showtime,
				CASE WHEN ISNULL(f.bettype,0) = 0 THEN b.bettype ELSE f.GroupTypeId END

		-- NG
		IF @showNG = 1 
		BEGIN
			INSERT INTO #AgMatchWLDetails
				SELECT 
					4 as BetGroup,
					0 as matchid,
					0 as homeid,
					0 as awayid,
					b.bettype,
					0 as liveindicator,
					0 as leagueid,
					SUM(ABS(b.stake)) as turnover,
					SUM(b.comm/(1 - b.apositiontaking)) as GrossComm,
					SUM(b.winlost - b.actual_stake) as MemberWinLost,
					SUM(b.playercomm) as MemberComm,
					SUM(b.Winlost - b.actual_stake + b.playercomm) as MemberTotal,
					SUM(b.awinlost) as AgentWinLost,
					SUM(b.comm - b.playercomm) AS  AgentComm,
					SUM(b.awinlost + b.comm - b.playercomm) AS AgentTotal,
					SUM(b.comm) as CompanyComm,
					-SUM(b.winlost - b.actual_stake + b.awinlost + b.comm) as CompanyTotal,
					'' as race,		
					'' as matchcode,
					CONVERT(BIT,0) as IsNeutral,
					'' as showtime
				FROM bettrans b WITH (NOLOCK)	
					INNER JOIN #SportBettype s ON s.Bettype = b.bettype
					
				WHERE 
					b.recommend = @custid
					AND b.winlostdate >= @fromdate
					AND b.winlostdate <= @todate
					AND b.ruben = 1
					AND b.statusID NOT IN (101, 102, 103)
					AND s.ProductID = 3
					AND s.EventType <> 1
				GROUP BY b.bettype	
				HAVING ISNULL(COUNT(transid),0) > 0
		END
		-- MixParlay
		IF @showSB = 1 
		BEGIN
			INSERT INTO #AgMatchWLDetails
				SELECT 
					3 as BetGroup,
					0 as matchid,
					0 as homeid,
					0 as awayid,
					b.bettype,
					0 as liveindicator,
					0 as leagueid,
					SUM(ABS(b.stake)) as turnover,
					SUM(b.comm/(1 - b.apositiontaking)) as GrossComm,
					SUM(b.winlost - b.actual_stake) as MemberWinLost,
					SUM(b.playercomm) as MemberComm,
					SUM(b.Winlost - b.actual_stake + b.playercomm) as MemberTotal,
					SUM(b.awinlost) as AgentWinLost,
					SUM(b.comm - b.playercomm) AS  AgentComm,
					SUM(b.awinlost + b.comm - b.playercomm) AS AgentTotal,
					SUM(b.comm) as CompanyComm,
					-SUM(b.winlost - b.actual_stake + b.awinlost + b.comm) as CompanyTotal,
					'' as race,		
					'' as matchcode,
					CONVERT(BIT,0) as IsNeutral,
					'' as showtime
				FROM
					bettrans b WITH (NOLOCK)						
				WHERE 
					b.recommend = @custid
					AND b.winlostdate >= @fromdate
					AND b.winlostdate <= @todate
					AND b.bettype IN (9,29)
					AND b.ruben = 1
					AND b.statusID NOT IN (101, 102, 103)
				GROUP BY b.bettype	
				HAVING ISNULL(COUNT(transid),0) > 0
		END

		-- Virtual HR
		IF @showVS = 1 
		BEGIN
			INSERT INTO #AgMatchWLDetails
			SELECT
				0 as BetGroup,
				'' matchid,
				0 as homeid,
                0 as awayid,
				b.bettype,
				0 as liveindicator,
				r.leagueid,
				SUM(ABS(stake)) as turnover,
				SUM(comm/(1 - apositiontaking)) as GrossComm,
				SUM(winlost - actual_stake) as MemberWinLost,
				SUM(playercomm) as MemberComm,
				SUM(Winlost - actual_stake + playercomm) as MemberTotal,
				SUM(awinlost) as AgentWinLost,
				SUM(comm - playercomm) AS  AgentComm,
				SUM(awinlost + comm - playercomm) AS AgentTotal,
				SUM(comm) as CompanyComm,
				-SUM(winlost - actual_stake + awinlost + comm) as CompanyTotal,		
				r.EventID as Race,
				'' matchcode,
				CONVERT (BIT, 0) AS IsNeutral,
				r.EventTime as showtime
			FROM 
				bettrans b WITH (NOLOCK)
				INNER JOIN VSOutright o WITH (NOLOCK) ON b.oddsid = o.Orid
                INNER JOIN VSRaceInfo r WITH (NOLOCK) ON r.EventID = o.EventID
                INNER JOIN #SportBettype s ON s.Bettype = b.bettype
			WHERE 
				b.recommend = @custid
				AND b.statusID NOT IN (101, 102, 103)
				AND o.eventdate >= @fromdate
				AND o.eventdate <= @todate
				AND o.eventstatus = 'completed'
				AND isnull(r.betstatus,'') <> 'refund'
				AND s.ProductID = 5
				AND s.EventType = 3
			GROUP BY 
				r.LeagueID, r.EventTime, r.eventID, b.bettype
		END
		
		-- Outright
		INSERT INTO #AgMatchWLDetails
			SELECT
				(case b.bettype when 10 then 2 else 1 end) as BetGroup,		
				0 as matchid,
				0 as homeid,
				0 as awayid,
				b.bettype,
				0 as liveindicator,
				m.leagueid as leagueid,
				SUM(case when b.liveawayscore = 0 and b.bettype in(33,43) then ABS(b.stake)/2 else ABS(b.stake) end	) as TurnOver,	
				SUM(comm/(1 - apositiontaking)) as GrossComm,
				SUM(winlost - actual_stake) as MemberWinLost,
				SUM(playercomm) as MemberComm,
				SUM(Winlost - actual_stake + playercomm) as MemberTotal,
				SUM(awinlost) as AgentWinLost,
				SUM(comm - playercomm) AS  AgentComm,
				SUM(awinlost + comm - playercomm) AS AgentTotal,
				SUM(comm) as CompanyComm,
				-SUM(winlost - actual_stake + awinlost + comm) as CompanyTotal,
				m.groupmatch as race,		
				'ZZZZ' as matchcode,
				CONVERT(BIT, 0) as IsNeutral,
				'' as showtime
			FROM 
				bettrans b WITH (NOLOCK)
				inner join outright m with (nolock) on m.orid = b.matchid
				INNER JOIN #SportBettype s ON b.bettype = s.Bettype
			WHERE 
				b.recommend = @custid
				AND b.winlostdate >= @fromdate
				AND b.winlostdate <= @todate
				AND s.EventType = 2
				AND b.ruben = 1
				AND b.statusID NOT IN (101, 102, 103)
			GROUP BY b.bettype, m.groupmatch, m.leagueid
			HAVING ISNULL(COUNT(transid),0) > 0	
	END
	
	IF @Fromdate <= @MoveBetsDay
	BEGIN
		INSERT INTO #AgMatchWLDetails
			SELECT
				0 as BetGroup,
				m.matchid,
				m.homeid,
				m.awayid,
				b.bettype,
				b.liveindicator,
				m.leagueid,
				SUM(ABS(stake)) as turnover,
				SUM(comm/(1 - apositiontaking)) as GrossComm,
				SUM(winlost - actual_stake) as MemberWinLost,
				SUM(playercomm) as MemberComm,
				SUM(Winlost - actual_stake + playercomm) as MemberTotal,
				SUM(awinlost) as AgentWinLost,
				SUM(comm - playercomm) AS  AgentComm,
				SUM(awinlost + comm - playercomm) AS AgentTotal,
				SUM(comm) as CompanyComm,
				-SUM(winlost - actual_stake + awinlost + comm) as CompanyTotal,	
				'' as race,			
				m.matchcode,
				isnull(m.isNeutral, CONVERT(BIT,0)) as IsNeutral,
				'' as showtime
			FROM 
				bettrans14 b WITH (NOLOCK)
				INNER JOIN match14 m WITH (NOLOCK) ON m.matchid = b.matchid
				INNER JOIN #SportBettype s ON s.Bettype = b.bettype
			WHERE 
				b.recommend = @custid
				AND b.bettype NOT IN (9, 29, 10)
				AND b.statusID NOT IN (101, 102, 103)
				AND m.eventdate >= @fromdate
				AND m.eventdate <= @todate
				AND m.eventstatus = 'completed'
				AND isnull(m.betstatus, '') <> 'refund'
				AND s.ProductID = 3
			GROUP BY 
				m.matchid, m.homeid, m.awayid, b.bettype, m.leagueid, m.matchcode, m.isNeutral, b.liveindicator

			UNION ALL  --- Not number Game not group by liveindicator
			SELECT
				0 as BetGroup,
				m.matchid,
				m.homeid,
				m.awayid,
				CASE WHEN ISNULL(f.bettype,0) = 0 THEN b.bettype ELSE f.GroupTypeId END AS bettype,	
				0 as liveindicator,
				m.leagueid,
				SUM(ABS(stake)) as turnover,
				SUM(comm/(1 - apositiontaking)) as GrossComm,
				SUM(winlost - actual_stake) as MemberWinLost,
				SUM(playercomm) as MemberComm,
				SUM(Winlost - actual_stake + playercomm) as MemberTotal,
				SUM(awinlost) as AgentWinLost,
				SUM(comm - playercomm) AS AgentComm,
				SUM(awinlost + comm - playercomm) AS AgentTotal,
				SUM(comm) as CompanyComm,
				-SUM(winlost - actual_stake + awinlost + comm) as CompanyTotal,	
				'' as race,			
				m.matchcode,
				isnull(m.isNeutral, CONVERT(BIT,0)) as IsNeutral,
				isnull(m.showtime,'') as showtime
			FROM 
				bettrans14 b WITH (NOLOCK)
				INNER JOIN match14 m WITH (NOLOCK) ON m.matchid = b.matchid
				LEFT JOIN (SELECT * FROM [dbo].[f_GroupBettype] ()) f ON f.bettype = b.bettype
				INNER JOIN #SportBettype s ON b.bettype = s.Bettype	
			WHERE 
				b.recommend = @custid
				AND b.bettype NOT IN (9,29,10)
				AND b.statusID NOT IN (101, 102, 103)
				AND m.eventdate >= @fromdate
				AND m.eventdate <= @todate
				AND m.eventstatus = 'completed'
				AND isnull(m.betstatus,'') <> 'refund'
				AND s.ProductID IN (1, 4, 5, 26)
				AND s.EventType <> 3
			GROUP BY 
				m.matchid, m.homeid, m.awayid, m.leagueid, m.matchcode, m.isNeutral, m.showtime,
				CASE WHEN ISNULL(f.bettype,0) = 0 THEN b.bettype ELSE f.GroupTypeId END
		-- NG
		IF @showNG = 1
		BEGIN
			INSERT INTO #AgMatchWLDetails
				SELECT
					4 as BetGroup,
					0 as matchid,
					0 as homeid,
					0 as awayid,
					b.bettype,
					0 as liveindicator,
					0 as leagueid,
					SUM(ABS(stake)) as turnover,
					SUM(comm/(1 - apositiontaking)) as GrossComm,
					SUM(winlost - actual_stake) as MemberWinLost,
					SUM(playercomm) as MemberComm,
					SUM(Winlost - actual_stake + playercomm) as MemberTotal,
					SUM(awinlost) as AgentWinLost,
					SUM(comm - playercomm) AS  AgentComm,
					SUM(awinlost + comm - playercomm) AS AgentTotal,
					SUM(comm) as CompanyComm,
					-SUM(winlost - actual_stake + awinlost + comm) as CompanyTotal,
					'' as race,				
					'' as matchcode,
					CONVERT(BIT,0) as IsNeutral,
					'' as showtime
				FROM bettrans14 b WITH (NOLOCK)
					INNER JOIN #SportBettype s ON s.Bettype = b.bettype
				WHERE 
					b.recommend = @custid
					AND b.winlostdate >= @fromdate
					AND b.winlostdate <= @todate
					AND b.ruben = 1
					AND b.statusID NOT IN (101, 102, 103)
					AND s.ProductID = 3
					AND s.EventType <> 1
				GROUP BY b.bettype	
				HAVING ISNULL(COUNT(transid), 0) > 0	
		END
		-- Mix parlay (14)
		IF @showSB = 1
		BEGIN
			INSERT INTO #AgMatchWLDetails
				SELECT
					3 as BetGroup,
					0 as matchid,
					0 as homeid,
					0 as awayid,
					b.bettype,
					0 as liveindicator,
					0 as leagueid,
					SUM(ABS(stake)) as turnover,
					SUM(comm/(1 - apositiontaking)) as GrossComm,
					SUM(winlost - actual_stake) as MemberWinLost,
					SUM(playercomm) as MemberComm,
					SUM(Winlost - actual_stake + playercomm) as MemberTotal,
					SUM(awinlost) as AgentWinLost,
					SUM(comm - playercomm) AS  AgentComm,
					SUM(awinlost + comm - playercomm) AS AgentTotal,
					SUM(comm) as CompanyComm,
					-SUM(winlost - actual_stake + awinlost + comm) as CompanyTotal,
					'' as race,				
					'' as matchcode,
					CONVERT(BIT,0) as IsNeutral,
					'' as showtime
				FROM
					bettrans14 b WITH (NOLOCK)
				WHERE 
					b.recommend = @custid
					AND b.winlostdate >= @fromdate
					AND b.winlostdate <= @todate
					AND b.bettype IN (9,29)
					AND b.ruben = 1
					AND b.statusID NOT IN (101, 102, 103)
				GROUP BY b.bettype	
				HAVING ISNULL(COUNT(transid), 0) > 0	
		END
		
		-- Virtual HR
		IF @showVS = 1 
		BEGIN
			INSERT INTO #AgMatchWLDetails
			SELECT
				0 as BetGroup,
				'' matchid,
				0 as homeid,
                0 as awayid,
				b.bettype,
				0 as liveindicator,
				r.leagueid,
				SUM(ABS(stake)) as turnover,
				SUM(comm/(1 - apositiontaking)) as GrossComm,
				SUM(winlost - actual_stake) as MemberWinLost,
				SUM(playercomm) as MemberComm,
				SUM(Winlost - actual_stake + playercomm) as MemberTotal,
				SUM(awinlost) as AgentWinLost,
				SUM(comm - playercomm) AS  AgentComm,
				SUM(awinlost + comm - playercomm) AS AgentTotal,
				SUM(comm) as CompanyComm,
				-SUM(winlost - actual_stake + awinlost + comm) as CompanyTotal,		
				r.EventID as Race,
				'' matchcode,
				CONVERT (BIT, 0) AS IsNeutral,
				r.EventTime as showtime
			FROM 
				bettrans14 b WITH (NOLOCK)
				INNER JOIN VSOutright14 o WITH (NOLOCK) ON b.oddsid = o.Orid
                INNER JOIN VSRaceInfo14 r WITH (NOLOCK) ON r.EventID = o.EventID
                INNER JOIN #SportBettype s ON b.bettype = s.Bettype
			WHERE 
				b.recommend = @custid
				AND b.statusID NOT IN (101, 102, 103)
				AND o.eventdate >= @fromdate
				AND o.eventdate <= @todate
				AND o.eventstatus = 'completed'
				AND isnull(r.betstatus,'') <> 'refund'
				AND s.ProductID = 5
				AND s.EventType = 3
			GROUP BY 
				r.LeagueID, r.EventTime, r.eventID, b.bettype
		END
		
		-- Outright (14)
		INSERT INTO #AgMatchWLDetails
			SELECT
				(case b.bettype when 10 then 2 else 1 end) as BetGroup,		
				0 as matchid,
				0 as homeid,
				0 as awayid,
				b.bettype,
				0 as liveindicator,
				m.leagueid,
				SUM(case when b.liveawayscore = 0 and b.bettype in(33, 43) then ABS(b.stake)/2 else ABS(b.stake) end) as TurnOver,	
				SUM(comm/(1 - apositiontaking)) as GrossComm,
				SUM(winlost - actual_stake) as MemberWinLost,
				SUM(playercomm) as MemberComm,
				SUM(Winlost - actual_stake + playercomm) as MemberTotal,
				SUM(awinlost) as AgentWinLost,
				SUM(comm - playercomm) AS  AgentComm,
				SUM(awinlost + comm - playercomm) AS AgentTotal,
				SUM(comm) as CompanyComm,
				-SUM(winlost - actual_stake + awinlost + comm) as CompanyTotal,		
				m.groupmatch as race,		
				'ZZZZ' as matchcode,
				CONVERT(BIT, 0) as IsNeutral,
				'' as showtime
			FROM 
				bettrans14 b WITH (NOLOCK)
				inner join outright14 m with (nolock) on m.orid = b.matchid
				INNER JOIN #SportBettype s ON b.bettype = s.Bettype
			WHERE 
				b.recommend = @custid
				AND b.winlostdate >= @fromdate
				AND b.winlostdate <= @todate
				AND s.EventType = 2
				AND b.ruben = 1
				AND b.statusID not in (101, 102, 103)
			GROUP BY b.bettype, m.groupmatch, m.leagueid
			HAVING ISNULL(COUNT(transid), 0) > 0	
	END
END
ELSE
BEGIN
	DECLARE @tmpLeague TABLE(leagueid INT)
	DECLARE @tmpParlayRefno TABLE(TransID BIGINT)
	
	INSERT INTO @tmpLeague
	SELECT CONVERT(INT,val)
	FROM strSplit(@league,',')
	
	IF @Todate > @MoveBetsDay
	BEGIN
		BEGIN
			INSERT INTO #AgMatchWLDetails
			SELECT
				0 as BetGroup,
				m.matchid,
				m.homeid,
				m.awayid,
				b.bettype,
				b.liveindicator,
				m.leagueid,
				SUM(ABS(stake)) as turnover,
				SUM(comm/(1 - apositiontaking)) as GrossComm,
				SUM(winlost - actual_stake) as MemberWinLost,
				SUM(playercomm) as MemberComm,
				SUM(Winlost - actual_stake + playercomm) as MemberTotal,
				SUM(awinlost) as AgentWinLost,
				SUM(comm - playercomm) AS  AgentComm,
				SUM(awinlost + comm - playercomm) AS AgentTotal,
				SUM(comm) as CompanyComm,
				-SUM(winlost - actual_stake + awinlost + comm) as CompanyTotal,		
				'' as race,
				m.matchcode,
				isnull(m.isNeutral, CONVERT(BIT,0)) as IsNeutral,
				'' as showtime
			FROM 
				bettrans b WITH (NOLOCK)
				INNER JOIN match m WITH (NOLOCK) ON m.matchid = b.matchid 			
				INNER JOIN @tmpLeague l ON m.leagueid = l.leagueid 
				INNER JOIN #SportBettype s ON b.bettype = s.Bettype
			WHERE 
				b.recommend = @custid
				AND b.bettype NOT IN (9,29,10)
				AND b.statusID NOT IN (101, 102, 103)
				AND m.eventdate >= @fromdate
				AND m.eventdate <= @todate
				AND m.eventstatus = 'completed'
				AND isnull(m.betstatus, '') <> 'refund' 
				AND s.ProductID = 3
			GROUP BY 
				m.matchid, m.homeid, m.awayid, b.bettype, m.leagueid, m.matchcode, m.isNeutral, b.liveindicator	
		
		UNION ALL --- Not number Game not group by liveindicator
		SELECT
				0 as BetGroup,
				m.matchid,
				m.homeid,
				m.awayid,
				CASE WHEN ISNULL(f.bettype,0) = 0 THEN b.bettype ELSE f.GroupTypeId END AS bettype,	
				0 as liveindicator,
				m.leagueid,
				SUM(ABS(stake)) as turnover,
				SUM(comm/(1 - apositiontaking)) as GrossComm,
				SUM(winlost - actual_stake) as MemberWinLost,
				SUM(playercomm) as MemberComm,
				SUM(Winlost - actual_stake + playercomm) as MemberTotal,
				SUM(awinlost) as AgentWinLost,
				SUM(comm - playercomm) AS  AgentComm,
				SUM(awinlost + comm - playercomm) AS AgentTotal,
				SUM(comm) as CompanyComm,
				-SUM(winlost - actual_stake + awinlost + comm) as CompanyTotal,		
				'' as race,
				m.matchcode,
				isnull(m.isNeutral, CONVERT(BIT,0)) as IsNeutral,
				isnull(m.showtime , '') as showtime
			FROM 
				bettrans b WITH (NOLOCK)
				INNER JOIN match m WITH (NOLOCK) ON m.matchid = b.matchid 			
				INNER JOIN @tmpLeague l ON m.leagueid = l.leagueid 
				LEFT JOIN (SELECT * FROM [dbo].[f_GroupBettype]()) f ON f.bettype = b.bettype
				INNER JOIN #SportBettype s ON b.bettype = s.Bettype
			WHERE 
				b.recommend = @custid
				AND b.bettype NOT IN (9, 29, 10)
				AND b.statusID NOT IN (101, 102, 103)
				AND m.eventdate >= @fromdate
				AND m.eventdate <= @todate
				AND m.eventstatus = 'completed'
				AND isnull(m.betstatus,'') <> 'refund'
				AND s.ProductID IN (1, 4, 5, 26)
				AND s.EventType <> 3
			GROUP BY 
				m.matchid, m.homeid, m.awayid, m.leagueid, m.matchcode, m.isNeutral, m.showtime,
				CASE WHEN ISNULL(f.bettype,0) = 0 THEN b.bettype ELSE f.GroupTypeId END
		END
		
		-- MixParlay (dont show)
		
		-- Virtual HR		
		INSERT INTO #AgMatchWLDetails
		SELECT
			0 as BetGroup,
			'' matchid,
			0 as homeid,
            0 as awayid,
			b.bettype,
			0 as liveindicator,
			r.leagueid,
			SUM(ABS(stake)) as turnover,
			SUM(comm/(1 - apositiontaking)) as GrossComm,
			SUM(winlost - actual_stake) as MemberWinLost,
			SUM(playercomm) as MemberComm,
			SUM(Winlost - actual_stake + playercomm) as MemberTotal,
			SUM(awinlost) as AgentWinLost,
			SUM(comm - playercomm) AS  AgentComm,
			SUM(awinlost + comm - playercomm) AS AgentTotal,
			SUM(comm) as CompanyComm,
			-SUM(winlost - actual_stake + awinlost + comm) as CompanyTotal,		
			r.EventID as Race,
			'' matchcode,
			CONVERT (BIT, 0) AS IsNeutral,
			r.EventTime as showtime
		FROM 
			bettrans b WITH (NOLOCK)
			INNER JOIN VSOutright o WITH (NOLOCK) ON b.oddsid = o.Orid
            INNER JOIN VSRaceInfo r WITH (NOLOCK) ON r.EventID = o.EventID
            INNER JOIN @tmpLeague l ON r.leagueid = l.leagueid
            INNER JOIN #SportBettype s ON s.Bettype = b.bettype
		WHERE 
			b.recommend = @custid
			AND b.statusID NOT IN (101, 102, 103)
			AND o.eventdate >= @fromdate
			AND o.eventdate <= @todate
			AND o.eventstatus = 'completed'
			AND isnull(r.betstatus,'') <> 'refund'
			AND s.ProductID = 5
			AND s.EventType = 3
		GROUP BY 
			r.LeagueID, r.EventTime, r.eventID, b.bettype
				
		-- Outright
		INSERT INTO #AgMatchWLDetails
			SELECT
				(case b.bettype when 10 then 2 else 1 end) as BetGroup,		
				0 as matchid,
				0 as homeid,
				0 as awayid,
				b.bettype,
				0 as liveindicator,
				m.leagueid as leagueid,
				SUM(case when b.liveawayscore = 0 and b.bettype in(33,43) then ABS(b.stake)/2 else ABS(b.stake) end) as TurnOver,	
				SUM(comm/(1 - apositiontaking)) as GrossComm,
				SUM(winlost - actual_stake) as MemberWinLost,
				SUM(playercomm) as MemberComm,
				SUM(Winlost - actual_stake + playercomm) as MemberTotal,
				SUM(awinlost) as AgentWinLost,
				SUM(comm - playercomm) AS  AgentComm,
				SUM(awinlost + comm - playercomm) AS AgentTotal,
				SUM(comm) as CompanyComm,
				-SUM(winlost - actual_stake + awinlost + comm) as CompanyTotal,
				m.groupmatch as race,		
				'ZZZZ' as matchcode,
				CONVERT(BIT,0) as IsNeutral,
				'' as showtime
			FROM 
				bettrans b WITH (NOLOCK)
				inner join outright m with (nolock) on m.orid = b.matchid
				INNER JOIN @tmpLeague l ON m.leagueid = l.leagueid
				INNER JOIN #SportBettype s ON b.bettype = s.Bettype
			WHERE 
				b.recommend = @custid
				AND b.winlostdate >= @fromdate
				AND b.winlostdate <= @todate
				AND s.EventType = 2
				AND b.ruben = 1
				AND b.statusID NOT IN (101, 102, 103)
			GROUP BY b.bettype, m.groupmatch, m.leagueid 
			HAVING ISNULL(COUNT(transid),0) > 0	

	END
	
	IF @Fromdate <= @MoveBetsDay
	BEGIN
		INSERT INTO #AgMatchWLDetails
			SELECT
				0 as BetGroup,
				m.matchid,
				m.homeid,
				m.awayid,
				b.bettype,
				b.liveindicator,
				m.leagueid,
				SUM(ABS(stake)) as turnover,
				SUM(comm/(1 - apositiontaking)) as GrossComm,
				SUM(winlost - actual_stake) as MemberWinLost,
				SUM(playercomm) as MemberComm,
				SUM(Winlost - actual_stake + playercomm) as MemberTotal,
				SUM(awinlost) as AgentWinLost,
				SUM(comm - playercomm) AS  AgentComm,
				SUM(awinlost + comm - playercomm) AS AgentTotal,
				SUM(comm) as CompanyComm,
				-SUM(winlost - actual_stake + awinlost + comm) as CompanyTotal,	
				'' as race,			
				m.matchcode,
				isnull(m.isNeutral, CONVERT(BIT,0)) as IsNeutral,
				'' as showtime
			FROM 
				bettrans14 b WITH (NOLOCK)
				INNER JOIN match14 m WITH (NOLOCK) ON m.matchid = b.matchid 
				INNER JOIN @tmpLeague l ON m.leagueid = l.leagueid
				INNER JOIN #SportBettype s ON s.Bettype = b.bettype
			WHERE 
				b.recommend = @custid
				AND b.bettype NOT IN (9, 29, 10)
				AND b.statusID NOT IN (101, 102, 103)
				AND m.eventdate >= @fromdate
				AND m.eventdate <= @todate
				AND m.eventstatus = 'completed'
				AND isnull(m.betstatus,'') <> 'refund'
				AND s.ProductID = 3
			GROUP BY 
				m.matchid, m.homeid, m.awayid, b.bettype, m.leagueid, m.matchcode, m.isNeutral, b.liveindicator
				
			UNION ALL   --- Not number Game not group by liveindicator
			SELECT
				0 as BetGroup,
				m.matchid,
				m.homeid,
				m.awayid,
				CASE WHEN ISNULL(f.bettype,0) = 0 THEN b.bettype ELSE f.GroupTypeId END AS bettype,	
				0 as liveindicator,
				m.leagueid,
				SUM(ABS(stake)) as turnover,
				SUM(comm/(1 - apositiontaking)) as GrossComm,
				SUM(winlost - actual_stake) as MemberWinLost,
				SUM(playercomm) as MemberComm,
				SUM(Winlost - actual_stake + playercomm) as MemberTotal,
				SUM(awinlost) as AgentWinLost,
				SUM(comm - playercomm) AS  AgentComm,
				SUM(awinlost + comm - playercomm) AS AgentTotal,
				SUM(comm) as CompanyComm,
				-SUM(winlost - actual_stake + awinlost + comm) as CompanyTotal,	
				'' as race,			
				m.matchcode,
				isnull(m.isNeutral, CONVERT(BIT,0)) as IsNeutral,
				isnull(m.showtime, '') as showtime
			FROM 
				bettrans14 b WITH (NOLOCK)
				INNER JOIN match14 m WITH (NOLOCK) ON m.matchid = b.matchid 
				INNER JOIN @tmpLeague l ON m.leagueid = l.leagueid	
				LEFT JOIN (SELECT * FROM [dbo].[f_GroupBettype]()) f ON f.bettype = b.bettype
				INNER JOIN #SportBettype s ON s.Bettype = b.bettype					
			WHERE 
				b.recommend = @custid
				AND b.bettype NOT IN (9,29,10)
				AND b.statusID NOT IN (101, 102, 103)
				AND m.eventdate >= @fromdate
				AND m.eventdate <= @todate
				AND m.eventstatus = 'completed'
				AND isnull(m.betstatus,'') <> 'refund'
				AND s.ProductID IN (1, 4, 5, 26)
				AND s.EventType <> 3
			GROUP BY 
				m.matchid, m.homeid, m.awayid,m.leagueid, m.matchcode, m.isNeutral , m.showtime,
				CASE WHEN ISNULL(f.bettype,0) = 0 THEN b.bettype ELSE f.GroupTypeId END
			
		-- Mix parlay (14) (dont show)
		
		-- Virtual HR		
		INSERT INTO #AgMatchWLDetails
		SELECT
			0 as BetGroup,
			'' matchid,
			0 as homeid,
            0 as awayid,
			b.bettype,
			0 as liveindicator,
			r.leagueid,
			SUM(ABS(stake)) as turnover,
			SUM(comm/(1 - apositiontaking)) as GrossComm,
			SUM(winlost - actual_stake) as MemberWinLost,
			SUM(playercomm) as MemberComm,
			SUM(Winlost - actual_stake + playercomm) as MemberTotal,
			SUM(awinlost) as AgentWinLost,
			SUM(comm - playercomm) AS  AgentComm,
			SUM(awinlost + comm - playercomm) AS AgentTotal,
			SUM(comm) as CompanyComm,
			-SUM(winlost - actual_stake + awinlost + comm) as CompanyTotal,		
			r.EventID as Race,
			'' matchcode,
			CONVERT (BIT, 0) AS IsNeutral,
			r.EventTime as showtime
		FROM 
			bettrans14 b WITH (NOLOCK)
			INNER JOIN VSOutright14 o WITH (NOLOCK) ON b.oddsid = o.Orid
            INNER JOIN VSRaceInfo14 r WITH (NOLOCK) ON r.EventID = o.EventID
            INNER JOIN @tmpLeague l ON r.leagueid = l.leagueid
            INNER JOIN #SportBettype s ON b.bettype = s.Bettype
		WHERE 
			b.recommend = @custid
			AND b.statusID NOT IN (101, 102, 103)
			AND o.eventdate >= @fromdate
			AND o.eventdate <= @todate
			AND o.eventstatus = 'completed'
			AND isnull(r.betstatus,'') <> 'refund'
			AND s.ProductID = 5
			AND s.EventType = 3
		GROUP BY 
			r.LeagueID, r.EventTime, r.eventID, b.bettype
			
		-- Outright (14)
		INSERT INTO #AgMatchWLDetails
			SELECT
				(case b.bettype when 10 then 2 else 1 end) as BetGroup,		
				0 as matchid,
				0 as homeid,
				0 as awayid,
				b.bettype,
				0 as liveindicator,
				m.leagueid as leagueid,	
				SUM(case when b.liveawayscore = 0 and b.bettype in(33,43) then ABS(b.stake)/2 else ABS(b.stake) end) as TurnOver,	
				SUM(comm/(1 - apositiontaking)) as GrossComm,
				SUM(winlost - actual_stake) as MemberWinLost,
				SUM(playercomm) as MemberComm,
				SUM(Winlost - actual_stake + playercomm) as MemberTotal,
				SUM(awinlost) as AgentWinLost,
				SUM(comm - playercomm) AS  AgentComm,
				SUM(awinlost + comm - playercomm) AS AgentTotal,
				SUM(comm) as CompanyComm,
				-SUM(winlost - actual_stake + awinlost + comm) as CompanyTotal,		
				m.groupmatch as race,		
				'ZZZZ' as matchcode,
				CONVERT(BIT,0) as IsNeutral, 
				'' as showtime
			FROM 
				bettrans14 b WITH (NOLOCK)
				inner join outright14 m with (nolock) on m.orid = b.matchid
				INNER JOIN @tmpLeague l ON m.leagueid = l.leagueid
				INNER JOIN #SportBettype s ON s.Bettype = b.bettype
			WHERE 
				b.recommend = @custid
				AND b.winlostdate >= @fromdate
				AND b.winlostdate <= @todate
				AND s.EventType = 2
				AND b.ruben = 1
				AND b.statusID not in (101, 102, 103)
			GROUP BY b.bettype, m.groupmatch, m.leagueid
			HAVING ISNULL(COUNT(transid), 0) > 0	
	END
END

SELECT 
	BetGroup, 
	matchid, 
	homeid, 
	awayid, 
	bettype, 
	liveindicator,
	leagueid,
	SUM(turnover) as turnover,
	SUM(GrossComm) as GrossComm, 
	SUM(MemberWinLost) as MemberWinLost, 
	SUM(MemberComm) as MemberComm, 
	SUM(MemberTotal) as MemberTotal, 
	SUM(AgentWinLost) as AgentWinLost,
	SUM(AgentComm) as AgentComm, 
	SUM(AgentTotal) as AgentTotal, 		
	SUM(CompanyComm) as CompanyComm, 
	SUM(CompanyTotal) as CompanyTotal, 
	race,
	matchcode,
	isNeutral,
	showtime
FROM #AgMatchWLDetails	
GROUP BY BetGroup, matchid, homeid, awayid, bettype,liveindicator, matchcode, leagueid, isNeutral, race,showtime
ORDER BY betgroup, matchid, leagueid, race, bettype, liveindicator, matchcode

DROP TABLE #AgMatchWLDetails
DROP TABLE #SportBettype
GO