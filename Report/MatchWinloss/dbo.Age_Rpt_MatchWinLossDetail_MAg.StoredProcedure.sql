 USE bodb02
GO

ALTER PROCEDURE [dbo].[Age_Rpt_MatchWinLossDetail_MAg] 
	@CustID int,
	@FromDate smalldatetime,
	@ToDate smalldatetime,
	@MoveBetsDay smalldatetime,
	@league	VARCHAR(4000),
	@showSB BIT = 1,
	@showRB BIT = 0,
	@showNG BIT = 0,
	@showLiveCasino BIT = 0,
	@showVS BIT = 0
AS
/*
Created: 
Task : 
DB: DBAGE.bodb02
Original: Rpt_MatchWinLostDetail_MAg
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
	- 20100619@Phuc: put index hint bettrans14(index=IX_bettrans4)
	- 20110221@Johnson: get Match WL by leagues and sport
	- 20110308@Lukas: change param @showHR -> @showRB
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
	- 20121031@Johnson: Add new range bettype for sportting solutions :1301->1334
	- 20130228@Elodie: Add Virtual HR report
	- 20140926@Sophia:  Expand the range of Sporting Solution (1301 -> 1399)
						Grouping duplicate bettypes of Sporting Solution and IBC [Redmine: #23444]
	- 20150313@Cody: Apply sporttype bettype matrix [Redmine: #30169]
*/

SET NOCOUNT ON

IF OBJECT_ID('tempdb..#MAgMatchWLDetails') IS NOT NULL
BEGIN
	DROP TABLE #MAgMatchWLDetails
END

CREATE TABLE #MAgMatchWLDetails (
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
				,MasterWinLost	MONEY
				,MasterComm		MONEY
				,MasterTotal	MONEY
				,CompanyComm	MONEY
				,CompanyTotal	MONEY
				,race			NVARCHAR(20)
				,matchcode		NVARCHAR(50)
				,isNeutral		BIT
				,showtime		NVARCHAR(50)
			)

IF OBJECT_ID('tempdb..#SportBettype') IS NOT NULL
BEGIN
	DROP TABLE #SportBettype
END

CREATE TABLE #SportBettype (
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
	
INSERT INTO #SportBettype
EXEC bodb02.dbo.Acc_SportBettypeMatrix_Sel @mode=4,@ProductPrefix=@ProductPrefix

IF @league = ''
BEGIN
	-- Get all leagues by sport's selected
	IF @Todate > @MoveBetsDay
	BEGIN
		INSERT INTO #MAgMatchWLDetails 	
			SELECT
				0 as BetGroup,
				m.matchid,
				m.homeid,
				m.awayid,
				b.bettype,
				b.liveindicator,
				m.leagueid,
				SUM(ABS(stake)) as turnover,
				SUM(acomm/(1 - apositiontaking - mpositiontaking)) as GrossComm,
				SUM(winlost - actual_stake) as MemberWinLost,
				SUM(playercomm) as MemberComm,
				SUM(Winlost - actual_stake + playercomm) as MemberTotal,
				SUM(awinlost) as AgentWinLost,
				SUM(comm) AS  AgentComm,
				SUM(winlost - actual_stake + awinlost + comm) AS AgentTotal,
				SUM(mwinlost) as MasterWinLost,
				SUM(acomm - comm) AS  MasterComm,
				SUM(mwinlost + acomm - comm) AS MasterTotal,
				SUM(acomm) as CompanyComm,
				-SUM(winlost - actual_stake + awinlost + mwinlost + acomm) as CompanyTotal,	
				'' as race,
				m.matchcode,
				m.isNeutral,
				'' as showtime
			FROM 
				bettrans b WITH (NOLOCK)
				INNER JOIN match m WITH (NOLOCK) ON m.matchid = b.matchid
				INNER JOIN #SportBettype s ON b.bettype = s.Bettype
		--		INNER JOIN league l WITH(NOLOCK) ON m.leagueid = l.leagueid 			
			WHERE 
				b.mrecommend = @custid
				--AND b.bettype < 19001 
				AND b.bettype NOT IN (9,29,10)
				--b.status NOT IN ('VOID', 'REJECT', 'Refund') AND
				AND b.statusID NOT IN (101, 102, 103)
				AND m.eventdate >= @fromdate
				AND m.eventdate <= @todate
				AND m.eventstatus = 'completed'
				AND isnull(m.betstatus, '') <> 'refund'
				AND s.ProductID = 3
				--AND 1 = CASE ----WHEN @showSB = 1 and b.bettype < 31 then 1 
				--		 WHEN @showNG = 1 and b.bettype BETWEEN 81 AND 120 then 1 else 0 end
				
			GROUP BY 
				m.matchid, m.homeid, m.awayid, b.bettype, m.leagueid, m.matchcode, m.isNeutral,b.liveindicator
				
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
				SUM(acomm/(1 - apositiontaking-mpositiontaking)) as GrossComm,
				SUM(winlost - actual_stake) as MemberWinLost,
				SUM(playercomm) as MemberComm,
				SUM(Winlost - actual_stake + playercomm) as MemberTotal,
				SUM(awinlost) as AgentWinLost,
				SUM(comm) AS  AgentComm,
				SUM(winlost - actual_stake + awinlost + comm) AS AgentTotal,
				SUM(mwinlost) as MasterWinLost,
				SUM(acomm - comm) AS  MasterComm,
				SUM(mwinlost + acomm - comm) AS MasterTotal,
				SUM(acomm) as CompanyComm,
				-SUM(winlost - actual_stake + awinlost + mwinlost + acomm) as CompanyTotal,	
				'' as race,
				m.matchcode,
				m.isNeutral,
				ISNULL(m.showtime, '') as showtime
			FROM 
				bettrans b WITH (NOLOCK)
				INNER JOIN match m WITH (NOLOCK) ON m.matchid = b.matchid 	
				LEFT JOIN (SELECT * FROM [dbo].[f_GroupBettype]()) f ON f.bettype = b.bettype
				INNER JOIN #SportBettype s ON b.bettype = s.Bettype		
			WHERE 
				b.mrecommend = @custid
				--AND b.bettype < 19001 
				AND b.bettype NOT IN (9,29,10)--,1231,1232,1233,1237,1238)
				--b.status not in ('VOID', 'REJECT', 'Refund') AND
				AND b.statusID NOT IN (101, 102, 103)
				AND m.eventdate >= @fromdate
				AND m.eventdate <= @todate
				AND m.eventstatus = 'completed'
				AND isnull(m.betstatus,'') <> 'refund'
				AND s.ProductID IN(1, 4, 5)
				AND s.EventType <> 3
				--AND 1 = CASE WHEN @showSB = 1 and (b.bettype < 31 OR b.bettype BETWEEN 121 AND 999 OR b.bettype BETWEEN 1301 AND 1399) THEN 1 	
				--		 WHEN @showLiveCasino = 1 and b.bettype BETWEEN 1101 AND 1199 THEN 1  
				--		 WHEN @showVS = 1 and b.bettype BETWEEN 1201 AND 1299 THEN 1  END		
			GROUP BY 
				m.matchid, m.homeid, m.awayid, m.leagueid, m.matchcode, m.isNeutral, m.showtime,
				CASE WHEN ISNULL(f.bettype,0) = 0 THEN b.bettype ELSE f.GroupTypeId END 
		
		-- MixParlay
		IF @showSB = 1 
		BEGIN
			INSERT INTO #MAgMatchWLDetails 	
				SELECT
					3 as BetGroup,
					0 as matchid,
					0 as homeid,
					0 as awayid,
					b.bettype,
					0 as liveindicator,
					0 as leagueid,
					SUM(ABS(stake)) as turnover,
					SUM(acomm/(1 - apositiontaking - mpositiontaking)) as GrossComm,
					SUM(winlost - actual_stake) as MemberWinLost,
					SUM(playercomm) as MemberComm,
					SUM(Winlost - actual_stake + playercomm) as MemberTotal,
					SUM(awinlost) as AgentWinLost,
					SUM(comm) AS  AgentComm,
					SUM(winlost - actual_stake + awinlost + comm) AS AgentTotal,
					SUM(mwinlost) as MasterWinLost,
					SUM(acomm - comm) AS  MasterComm,
					SUM(mwinlost + acomm - comm) AS MasterTotal,
					SUM(acomm) as CompanyComm,
					-SUM(winlost - actual_stake + awinlost + mwinlost + acomm) as CompanyTotal,	
					'' as race,
					'' as matchcode,
					CONVERT(BIT,0) as IsNeutral,
					'' as showtime
				FROM
					bettrans b WITH (NOLOCK)
				WHERE 
					b.mrecommend = @custid
					AND b.bettype IN (9,29)
					AND b.winlostdate >= @fromdate
					AND b.winlostdate <= @todate
					AND b.ruben = 1
					--b.status not in ('VOID', 'REJECT', 'Refund') AND
					AND b.statusID NOT IN (101, 102, 103) 
				GROUP BY b.bettype	
				HAVING ISNULL(COUNT(transid),0) > 0
			END
		
		-- Virtual HR
		IF @showVS = 1 
		BEGIN
			INSERT INTO #MAgMatchWLDetails
			SELECT
				0 as BetGroup,
				'' matchid,
				0 as homeid,
                0 as awayid,
				b.bettype,
				0 as liveindicator,
				r.leagueid,
				SUM(ABS(stake)) as turnover,
				SUM(acomm/(1 - apositiontaking - mpositiontaking)) as GrossComm,
				SUM(winlost - actual_stake) as MemberWinLost,
				SUM(playercomm) as MemberComm,
				SUM(Winlost - actual_stake + playercomm) as MemberTotal,
				SUM(awinlost) as AgentWinLost,
				SUM(comm) AS  AgentComm,
				SUM(winlost - actual_stake + awinlost + comm) AS AgentTotal,
				SUM(mwinlost) as MasterWinLost,
				SUM(acomm - comm) AS  MasterComm,
				SUM(mwinlost + acomm - comm) AS MasterTotal,
				SUM(acomm) as CompanyComm,
				-SUM(winlost - actual_stake + awinlost + mwinlost + acomm) as CompanyTotal,						
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
				b.mrecommend = @custid
				AND b.statusID NOT IN (101, 102, 103)
				AND o.eventdate >= @fromdate
				AND o.eventdate <= @todate
				AND o.eventstatus = 'completed'
				AND isnull(r.betstatus,'') <> 'refund'
				AND s.ProductID = 5
				AND s.EventType = 3
				--AND @showVS = 1 AND b.bettype IN (1231, 1232, 1233, 1237, 1238)
			GROUP BY 
				r.LeagueID, r.EventTime, r.eventID, b.bettype
		END
		
		-- Outright
		INSERT INTO #MAgMatchWLDetails 
			SELECT
				(case b.bettype when 10 then 2 else 1 end) as BetGroup,		
				0 as matchid,
				0 as homeid,
				0 as awayid,
				b.bettype,
				0 as liveindicator,
				m.leagueid as leagueid,	
				--SUM(case when b.liveawayscore = 0 and b.bettype in(33,43) then b.stake/2 else b.stake end),	
				SUM(case when b.liveawayscore = 0 and b.bettype in(33,43) then ABS(b.stake)/2 else ABS(b.stake) end) as TurnOver,				
				SUM(acomm/(1 - apositiontaking - mpositiontaking)) as GrossComm,
				SUM(winlost - actual_stake) as MemberWinLost,
				SUM(playercomm) as MemberComm,	
				SUM(Winlost - actual_stake + playercomm) as MemberTotal,
				SUM(awinlost) as AgentWinLost,
				SUM(comm) AS  AgentComm,
				SUM(winlost - actual_stake + awinlost + comm) AS AgentTotal,
				SUM(mwinlost) as MasterWinLost,
				SUM(acomm - comm) AS  MasterComm,
				SUM(mwinlost + acomm - comm) AS MasterTotal,
				SUM(acomm) as CompanyComm,
				-SUM(winlost - actual_stake + awinlost + mwinlost + acomm) as CompanyTotal,
				m.groupmatch as race,		
				'ZZZZ' as matchcode,
				CONVERT(BIT, 0) as IsNeutral,
				'' as showtime
			FROM 
				bettrans b WITH (NOLOCK)
				INNER JOIN outright m with (nolock) on m.orid = b.matchid
				INNER JOIN #SportBettype s ON b.bettype = s.Bettype
			WHERE 
				b.mrecommend = @custid
				AND b.winlostdate >= @fromdate
				AND b.winlostdate <= @todate
				--AND b.bettype IN (10,31,32,33,41,42,43)
				AND b.ruben = 1
				--b.status not in ('VOID', 'REJECT', 'Refund') AND
				AND b.statusID NOT IN (101, 102, 103)
				AND s.EventType = 2
				--AND 1 =  CASE WHEN @showSB = 1 AND b.bettype = 10 THEN 1 
				--		  WHEN @showRB = 1 AND b.bettype IN (31,32,33) THEN 1 ELSE 0 END
			GROUP BY b.bettype, m.groupmatch, m.leagueid
			HAVING ISNULL(COUNT(transid),0) > 0	

	END
	IF @Fromdate <= @MoveBetsDay
	BEGIN	
		INSERT INTO #MAgMatchWLDetails 	
			SELECT
				0 as BetGroup,
				m.matchid,
				m.homeid,
				m.awayid,
				b.bettype,
				b.liveindicator,
				m.leagueid,
				SUM(ABS(stake)) as turnover,
				SUM(acomm/(1 - apositiontaking - mpositiontaking)) as GrossComm,
				SUM(winlost - actual_stake) as MemberWinLost,
				SUM(playercomm) as MemberComm,
				SUM(Winlost - actual_stake + playercomm) as MemberTotal,
				SUM(awinlost) as AgentWinLost,
				SUM(comm) AS  AgentComm,
				SUM(winlost - actual_stake + awinlost + comm) AS AgentTotal,
				SUM(mwinlost) as MasterWinLost,
				SUM(acomm - comm) AS  MasterComm,
				SUM(mwinlost + acomm - comm) AS MasterTotal,
				SUM(acomm) as CompanyComm,
				-SUM(winlost - actual_stake + awinlost + mwinlost + acomm) as CompanyTotal,	
				'' as race,
				m.matchcode,
				isnull(m.isNeutral, CONVERT(BIT,0)) as IsNeutral,
				'' as showtime
			FROM 
				bettrans14 b WITH (NOLOCK,index=IX_bettrans4)
				INNER JOIN match14 m WITH (NOLOCK) ON m.matchid = b.matchid
				INNER JOIN #SportBettype s ON b.bettype = s.Bettype
			--	INNER JOIN league l WITH (NOLOCK) ON m.leagueid = l.leagueid 				
			WHERE 
				b.mrecommend = @custid
				--b.status not in ('VOID', 'REJECT', 'Refund') AND
				AND b.statusID NOT IN (101, 102, 103)
				--AND b.bettype < 19001 
				AND b.bettype NOT IN (9,29,10)
				AND m.eventdate >= @fromdate
				AND m.eventdate <= @todate
				AND m.eventstatus = 'completed'
				AND isnull(m.betstatus,'') <> 'refund'
				AND s.ProductID = 3
				--AND 1 = CASE ----WHEN @showSB = 1 AND b.bettype < 31 THEN 1
				--		 WHEN @showNG = 1 AND b.bettype BETWEEN 81 AND 120 THEN 1 ELSE 0 END
				
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
				SUM(acomm/(1 - apositiontaking - mpositiontaking)) as GrossComm,
				SUM(winlost - actual_stake) as MemberWinLost,
				SUM(playercomm) as MemberComm,
				SUM(Winlost - actual_stake + playercomm) as MemberTotal,
				SUM(awinlost) as AgentWinLost,
				SUM(comm) AS  AgentComm,
				SUM(winlost - actual_stake + awinlost + comm) AS AgentTotal,
				SUM(mwinlost) as MasterWinLost,
				SUM(acomm - comm) AS  MasterComm,
				SUM(mwinlost + acomm - comm) AS MasterTotal,
				SUM(acomm) as CompanyComm,
				-SUM(winlost - actual_stake + awinlost + mwinlost + acomm) as CompanyTotal,	
				'' as race,
				m.matchcode,
				isnull(m.isNeutral, CONVERT(BIT, 0)) as IsNeutral,
				isnull(m.showtime, '') as showtime
			FROM 
				bettrans14 b WITH (NOLOCK, index=IX_bettrans4)
				INNER JOIN match14 m WITH (NOLOCK) ON m.matchid = b.matchid 	
				LEFT JOIN (SELECT * FROM [dbo].[f_GroupBettype]()) f ON f.bettype = b.bettype
				INNER JOIN #SportBettype s ON b.bettype = s.Bettype		
			WHERE 
				b.mrecommend = @custid
				--b.status not in ('VOID', 'REJECT', 'Refund') AND
				AND b.statusID NOT IN (101, 102, 103)
				--AND b.bettype < 19001 
				AND b.bettype NOT IN (9,29,10)--,1231,1232,1233,1237,1238)
				AND m.eventdate >= @fromdate
				AND m.eventdate <= @todate
				AND m.eventstatus = 'completed'
				AND isnull(m.betstatus,'') <> 'refund'
				AND s.ProductID IN(1, 4, 5)
				AND s.EventType <> 3
				--AND 1 = CASE WHEN @showSB = 1 AND (b.bettype < 31 OR b.bettype BETWEEN 121 AND 999 OR b.bettype BETWEEN 1301 AND 1399) THEN 1 
				--		 WHEN @showLiveCasino = 1 and b.bettype BETWEEN 1101 AND 1199 THEN 1  
				--		 WHEN @showVS = 1 and b.bettype BETWEEN 1201 AND 1299 THEN 1  END		
			GROUP BY 
				m.matchid, m.homeid, m.awayid, m.leagueid, m.matchcode, m.isNeutral, m.showtime,
				CASE WHEN ISNULL(f.bettype,0) = 0 THEN b.bettype ELSE f.GroupTypeId END

			-- mix parlay (14)	
			IF @showSB = 1
			BEGIN
				INSERT INTO #MAgMatchWLDetails 	
				SELECT
					3 as BetGroup,
					0 as matchid,
					0 as homeid,
					0 as awayid,
					b.bettype,
					0 as liveindicator,
					0 as leagueid,
					SUM(ABS(stake)) as turnover,
					SUM(acomm/(1 - apositiontaking - mpositiontaking)) as GrossComm,
					SUM(winlost - actual_stake) as MemberWinLost,
					SUM(playercomm) as MemberComm,
					SUM(Winlost - actual_stake+ playercomm) as MemberTotal,
					SUM(awinlost) as AgentWinLost,
					SUM(comm) AS  AgentComm,
					SUM(winlost - actual_stake + awinlost + comm) AS AgentTotal,
					SUM(mwinlost) as MasterWinLost,
					SUM(acomm - comm) AS  MasterComm,
					SUM(mwinlost + acomm - comm) AS MasterTotal,
					SUM(acomm) as CompanyComm,
					-SUM(winlost - actual_stake + awinlost + mwinlost + acomm) as CompanyTotal,	
					'' as race,
					'' as matchcode,
					CONVERT(BIT,0) as IsNeutral,
					'' as showtime
				FROM
					bettrans14 b WITH (NOLOCK,index=IX_bettrans4)
				WHERE 
					b.mrecommend = @custid
					AND b.bettype IN (9, 29)
					AND b.winlostdate >= @fromdate
					AND b.winlostdate <= @todate
					AND b.ruben = 1
					--b.status not in ('VOID', 'REJECT', 'Refund') AND
					AND b.statusID NOT IN (101, 102, 103)
				GROUP BY b.bettype	
				HAVING ISNULL(COUNT(transid),0) > 0
			END
			
			-- Virtual HR
			IF @showVS = 1 
			BEGIN
				INSERT INTO #MAgMatchWLDetails
				SELECT
				0 as BetGroup,
				'' matchid,
				0 as homeid,
                0 as awayid,
				b.bettype,
				0 as liveindicator,
				r.leagueid,
				SUM(ABS(stake)) as turnover,
				SUM(acomm/(1 - apositiontaking - mpositiontaking)) as GrossComm,
				SUM(winlost - actual_stake) as MemberWinLost,
				SUM(playercomm) as MemberComm,
				SUM(Winlost - actual_stake + playercomm) as MemberTotal,
				SUM(awinlost) as AgentWinLost,
				SUM(comm) AS  AgentComm,
				SUM(winlost - actual_stake + awinlost + comm) AS AgentTotal,
				SUM(mwinlost) as MasterWinLost,
				SUM(acomm - comm) AS  MasterComm,
				SUM(mwinlost + acomm - comm) AS MasterTotal,
				SUM(acomm) as CompanyComm,
				-SUM(winlost - actual_stake + awinlost + mwinlost + acomm) as CompanyTotal,						
				r.EventID as Race,
				'' matchcode,
				CONVERT (BIT, 0) AS IsNeutral,
				r.EventTime as showtime
				FROM 
					bettrans14 b WITH (NOLOCK)
					INNER JOIN VSOutright14 o WITH (NOLOCK) ON b.oddsid = o.Orid
					INNER JOIN VSRaceInfo r WITH (NOLOCK) ON r.EventID = o.EventID
					INNER JOIN #SportBettype s ON b.bettype = s.Bettype
				WHERE 
					b.mrecommend = @custid
					AND b.statusID NOT IN (101, 102, 103)
					AND o.eventdate >= @fromdate
					AND o.eventdate <= @todate
					AND o.eventstatus = 'completed'
					AND isnull(r.betstatus, '') <> 'refund'
					AND s.ProductID = 5
					AND s.EventType = 3
					--AND @showVS = 1 and b.bettype IN (1231, 1232, 1233, 1237, 1238)
				GROUP BY 
					r.LeagueID, r.EventTime, r.eventID, b.bettype
			END
		
			-- outright (14)
			INSERT INTO #MAgMatchWLDetails 
			SELECT
				(case b.bettype when 10 then 2 else 1 end) as BetGroup,		
				0 as matchid,
				0 as homeid,
				0 as awayid,
				b.bettype,
				0 as liveindicator,
				m.leagueid,	
				---SUM(case when b.liveawayscore = 0 and b.bettype in(33,43) then b.stake/2 else b.stake end),	
				SUM(case when b.liveawayscore = 0 and b.bettype IN(33,43) then ABS(b.stake)/2 else ABS(b.stake) end) as TurnOver,
				SUM(acomm/(1 - apositiontaking - mpositiontaking)) as GrossComm,
				SUM(winlost - actual_stake) as MemberWinLost,
				SUM(playercomm) as MemberComm,
				SUM(Winlost - actual_stake + playercomm) as MemberTotal,
				SUM(awinlost) as AgentWinLost,
				SUM(comm) AS  AgentComm,
				SUM(winlost - actual_stake + awinlost + comm) AS AgentTotal,
				SUM(mwinlost) as MasterWinLost,
				SUM(acomm - comm) AS  MasterComm,
				SUM(mwinlost + acomm - comm) AS MasterTotal,
				SUM(acomm) as CompanyComm,
				-SUM(winlost - actual_stake + awinlost + mwinlost + acomm) as CompanyTotal,
				m.groupmatch as race,		
				'ZZZZ' as matchcode,
				CONVERT(BIT,0) as IsNeutral,
				'' as showtime
			FROM 
				bettrans14 b WITH (NOLOCK,index=IX_bettrans4)
				inner join outright14 m with (nolock) on m.orid = b.matchid
				INNER JOIN #SportBettype s ON b.bettype = s.Bettype
			WHERE 
				b.mrecommend = @custid
				AND b.winlostdate >= @fromdate
				AND b.winlostdate <= @todate
				--AND b.bettype IN (10,31,32,33,41,42,43)
				AND s.EventType = 2
				AND b.ruben = 1
				--b.status not in ('VOID', 'REJECT', 'Refund') AND
				AND b.statusID NOT IN (101, 102, 103)
				--AND 1 = CASE WHEN @showSB = 1 AND b.bettype = 10 THEN 1
				--		 WHEN @showRB = 1 AND b.bettype IN (31,32,33) THEN 1 ELSE 0 END
			GROUP BY b.bettype, m.groupmatch, m.leagueid
			HAVING ISNULL(COUNT(transid),0) > 0	

	END
END
ELSE BEGIN
	DECLARE @tmpLeague TABLE(leagueid INT)
	
	DECLARE @tmpParlayRefno TABLE(TransID BIGINT)
	
	INSERT INTO @tmpLeague
	SELECT CONVERT(INT,val)
	FROM strSplit(@league,',')
	
	IF @Todate > @MoveBetsDay
	BEGIN
		INSERT INTO #MAgMatchWLDetails 	
			SELECT
				0 as BetGroup,
				m.matchid,
				m.homeid,
				m.awayid,
				b.bettype,
				b.liveindicator,
				m.leagueid,
				SUM(ABS(stake)) as turnover,
				SUM(acomm/(1 - apositiontaking - mpositiontaking)) as GrossComm,
				SUM(winlost - actual_stake) as MemberWinLost,
				SUM(playercomm) as MemberComm,
				SUM(Winlost - actual_stake + playercomm) as MemberTotal,
				SUM(awinlost) as AgentWinLost,
				SUM(comm) AS  AgentComm,
				SUM(winlost - actual_stake + awinlost + comm) AS AgentTotal,
				SUM(mwinlost) as MasterWinLost,
				SUM(acomm - comm) AS  MasterComm,
				SUM(mwinlost + acomm - comm) AS MasterTotal,
				SUM(acomm) as CompanyComm,
				-SUM(winlost - actual_stake + awinlost + mwinlost + acomm) as CompanyTotal,	
				'' as race,
				m.matchcode,
				m.isNeutral,
				'' as showtime
			FROM 
				bettrans b WITH (NOLOCK)
				INNER JOIN match m WITH (NOLOCK) ON m.matchid = b.matchid
				INNER JOIN #SportBettype s ON b.bettype = s.Bettype	
				INNER JOIN @tmpLeague l ON m.leagueid = l.leagueid 			
			WHERE 
				b.mrecommend = @custid
				--AND b.bettype < 19001 
				AND b.bettype NOT IN (9,29,10)
				--b.status not in ('VOID', 'REJECT', 'Refund') AND
				AND b.statusID NOT IN (101, 102, 103)
				AND m.eventdate >= @fromdate
				AND m.eventdate <= @todate
				AND m.eventstatus = 'completed'
				AND isnull(m.betstatus, '') <> 'refund'
				AND s.ProductID = 3
				--AND b.bettype BETWEEN 81 AND 120
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
				SUM(acomm/(1 - apositiontaking - mpositiontaking)) as GrossComm,
				SUM(winlost - actual_stake) as MemberWinLost,
				SUM(playercomm) as MemberComm,
				SUM(Winlost - actual_stake + playercomm) as MemberTotal,
				SUM(awinlost) as AgentWinLost,
				SUM(comm) AS  AgentComm,
				SUM(winlost - actual_stake + awinlost + comm) AS AgentTotal,
				SUM(mwinlost) as MasterWinLost,
				SUM(acomm - comm) AS  MasterComm,
				SUM(mwinlost + acomm - comm) AS MasterTotal,
				SUM(acomm) as CompanyComm,
				-SUM(winlost - actual_stake + awinlost + mwinlost + acomm) as CompanyTotal,	
				'' as race,
				m.matchcode,
				m.isNeutral,
				isnull(m.showtime, '') as showtime
			FROM 
				bettrans b WITH (NOLOCK)
				INNER JOIN match m WITH (NOLOCK) ON m.matchid = b.matchid 	
				INNER JOIN @tmpLeague l ON m.leagueid = l.leagueid 
				INNER JOIN #SportBettype s ON b.bettype = s.Bettype
				LEFT JOIN (SELECT * FROM [dbo].[f_GroupBettype]()) f ON f.bettype = b.bettype	
			WHERE 
				b.mrecommend = @custid
				AND b.bettype < 19001 
				AND b.bettype NOT IN (9,29,10)--,1231,1232,1233,1237,1238)
				--b.status not in ('VOID', 'REJECT', 'Refund') AND
				AND b.statusID NOT IN (101, 102, 103)
				AND m.eventdate >= @fromdate
				AND m.eventdate <= @todate
				AND m.eventstatus = 'completed'
				AND isnull(m.betstatus,'') <> 'refund'
				AND s.ProductID IN(1, 4, 5) -- bettype NOT BETWEEN 81 AND 120
				AND s.EventType <> 3 -- bettype not in(1231,1232,1233,1237,1238)
				--AND b.bettype NOT BETWEEN 81 AND 120
			GROUP BY 
				m.matchid, m.homeid, m.awayid, m.leagueid, m.matchcode, m.isNeutral, m.showtime,
				CASE WHEN ISNULL(f.bettype,0) = 0 THEN b.bettype ELSE f.GroupTypeId END
		
		-- MixParlay
		/*
		IF @showSB = 1
		BEGIN
			INSERT INTO @tmpParlayRefno(TransID)
			SELECT b.TransID
			FROM bettrans b WITH (NOLOCK)
				INNER JOIN bettransm bm WITH(NOLOCK) ON b.refno = bm.refno
				INNER JOIN match m WITH(NOLOCK) ON bm.matchid = m.matchid
				INNER JOIN @tmpLeague l ON m.leagueid = l.leagueid
			WHERE 
				b.mrecommend = @custid
				AND b.winlostdate >= @fromdate
				AND b.winlostdate <= @todate
				AND b.bettype IN (9, 29)
				AND b.ruben = 1
				AND b.statusID NOT IN (101, 102, 103)
			GROUP BY  b.TransID
				
			INSERT INTO #MAgMatchWLDetails 	
			SELECT
				3 as BetGroup,
				0 as matchid,
				0 as homeid,
				0 as awayid,
				b.bettype,
				0 as liveindicator,
				0 as leagueid,
				SUM(ABS(b.stake)) as turnover,
				SUM(b.acomm/(1 - b.apositiontaking - b.mpositiontaking)) as GrossComm,
				SUM(b.winlost - b.actual_stake) as MemberWinLost,
				SUM(b.playercomm) as MemberComm,
				SUM(b.Winlost - b.actual_stake + b.playercomm) as MemberTotal,
				SUM(b.awinlost) as AgentWinLost,
				SUM(b.comm) AS  AgentComm,
				SUM(b.winlost - b.actual_stake + b.awinlost + b.comm) AS AgentTotal,
				SUM(b.mwinlost) as MasterWinLost,
				SUM(b.acomm - b.comm) AS  MasterComm,
				SUM(b.mwinlost + b.acomm - b.comm) AS MasterTotal,
				SUM(b.acomm) as CompanyComm,
				-SUM(b.winlost - b.actual_stake + b.awinlost + b.mwinlost + b.acomm) as CompanyTotal,	
				'' as race,
				'' as matchcode,
				CONVERT(BIT,0) as IsNeutral,
				'' as showtime
			FROM
				bettrans b WITH (NOLOCK)
				INNER JOIN @tmpParlayRefno tmp ON b.TransID = tmp.TransID 
			WHERE 
				b.mrecommend = @custid
				AND b.bettype IN (9, 29)
				AND b.winlostdate >= @fromdate
				AND b.winlostdate <= @todate
				AND b.ruben = 1
				--b.status not in ('VOID', 'REJECT', 'Refund') AND
				AND b.statusID NOT IN (101, 102, 103) 
			GROUP BY b.bettype	
			HAVING ISNULL(COUNT(b.transid),0) > 0
		END
		*/
		
		-- Virtual HR		
		INSERT INTO #MAgMatchWLDetails
		SELECT
			0 as BetGroup,
				'' matchid,
				0 as homeid,
                0 as awayid,
				b.bettype,
				0 as liveindicator,
				r.leagueid,
				SUM(ABS(stake)) as turnover,
				SUM(acomm/(1 - apositiontaking - mpositiontaking)) as GrossComm,
				SUM(winlost - actual_stake) as MemberWinLost,
				SUM(playercomm) as MemberComm,
				SUM(Winlost - actual_stake + playercomm) as MemberTotal,
				SUM(awinlost) as AgentWinLost,
				SUM(comm) AS  AgentComm,
				SUM(winlost - actual_stake + awinlost + comm) AS AgentTotal,
				SUM(mwinlost) as MasterWinLost,
				SUM(acomm - comm) AS  MasterComm,
				SUM(mwinlost + acomm - comm) AS MasterTotal,
				SUM(acomm) as CompanyComm,
				-SUM(winlost - actual_stake + awinlost + mwinlost + acomm) as CompanyTotal,						
				r.EventID as Race,
				'' matchcode,
				CONVERT (BIT, 0) AS IsNeutral,
				r.EventTime as showtime
		FROM 
			bettrans b WITH (NOLOCK)
			INNER JOIN VSOutright o WITH (NOLOCK) ON b.oddsid = o.Orid
            INNER JOIN VSRaceInfo r WITH (NOLOCK) ON r.EventID = o.EventID
            INNER JOIN @tmpLeague l ON r.leagueid = l.leagueid
            INNER JOIN #SportBettype s ON b.bettype = s.Bettype
		WHERE 
			b.mrecommend = @custid
			AND b.statusID NOT IN (101, 102, 103)
			AND o.eventdate >= @fromdate
			AND o.eventdate <= @todate
			AND o.eventstatus = 'completed'
			AND isnull(r.betstatus, '') <> 'refund'
			AND s.ProductID = 5
			AND s.EventType = 3
			--AND @showVS = 1 AND b.bettype IN (1231, 1232, 1233, 1237, 1238)
		GROUP BY 
			r.LeagueID, r.EventTime, r.eventID, b.bettype
			
		-- Outright
		INSERT INTO #MAgMatchWLDetails 
			SELECT
				(case b.bettype when 10 then 2 else 1 end) as BetGroup,		
				0 as matchid,
				0 as homeid,
				0 as awayid,
				b.bettype,
				0 as liveindicator,
				m.leagueid  as leagueid,	
				--SUM(case when b.liveawayscore = 0 and b.bettype in(33,43) then b.stake/2 else b.stake end),	
				SUM(case when b.liveawayscore = 0 and b.bettype in(33,43) then ABS(b.stake)/2 else ABS(b.stake) end) as TurnOver,
				SUM(acomm/(1 - apositiontaking - mpositiontaking)) as GrossComm,
				SUM(winlost - actual_stake) as MemberWinLost,
				SUM(playercomm) as MemberComm,	
				SUM(Winlost - actual_stake + playercomm) as MemberTotal,
				SUM(awinlost) as AgentWinLost,
				SUM(comm) AS  AgentComm,
				SUM(winlost - actual_stake + awinlost + comm) AS AgentTotal,
				SUM(mwinlost) as MasterWinLost,
				SUM(acomm - comm) AS  MasterComm,
				SUM(mwinlost + acomm - comm) AS MasterTotal,
				SUM(acomm) as CompanyComm,
				-SUM(winlost - actual_stake + awinlost + mwinlost + acomm) as CompanyTotal,
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
				b.mrecommend = @custid
				AND b.winlostdate >= @fromdate
				AND b.winlostdate <= @todate
				--AND s.ProductID IN(1, 2)
				AND s.EventType = 2
				--AND b.bettype IN (10,31,32,33,41,42,43)
				AND b.ruben = 1
				--b.status not in ('VOID', 'REJECT', 'Refund') AND
				AND b.statusID NOT IN (101, 102, 103) 
			GROUP BY b.bettype, m.groupmatch, m.leagueid 
			HAVING ISNULL(COUNT(transid),0) > 0	
	END
	IF @Fromdate <= @MoveBetsDay
	BEGIN	
		INSERT INTO #MAgMatchWLDetails 	
			SELECT
				0 as BetGroup,
				m.matchid,
				m.homeid,
				m.awayid,
				b.bettype,
				b.liveindicator,
				m.leagueid,
				SUM(ABS(stake)) as turnover,
				SUM(acomm/(1 - apositiontaking - mpositiontaking)) as GrossComm,
				SUM(winlost - actual_stake) as MemberWinLost,
				SUM(playercomm) as MemberComm,
				SUM(Winlost - actual_stake + playercomm) as MemberTotal,
				SUM(awinlost) as AgentWinLost,
				SUM(comm) AS  AgentComm,
				SUM(winlost - actual_stake + awinlost + comm) AS AgentTotal,
				SUM(mwinlost) as MasterWinLost,
				SUM(acomm - comm) AS  MasterComm,
				SUM(mwinlost + acomm - comm) AS MasterTotal,
				SUM(acomm) as CompanyComm,
				-SUM(winlost - actual_stake + awinlost + mwinlost + acomm) as CompanyTotal,	
				'' as race,
				m.matchcode,
				isnull(m.isNeutral, CONVERT(BIT,0)) as IsNeutral,
				'' as showtime
			FROM 
				bettrans14 b WITH (NOLOCK,index=IX_bettrans4)
				INNER JOIN match14 m WITH (NOLOCK) ON m.matchid = b.matchid 	
				INNER JOIN @tmpLeague l ON m.leagueid = l.leagueid
				INNER JOIN #SportBettype s ON b.bettype = s.Bettype		
			WHERE 
				b.mrecommend = @custid
				--b.status not in ('VOID', 'REJECT', 'Refund') AND
				AND b.statusID NOT IN (101, 102, 103)
				--AND b.bettype < 19001 
				AND b.bettype NOT IN (9,29,10)
				AND m.eventdate >= @fromdate
				AND m.eventdate <= @todate 
				AND m.eventstatus = 'completed'  
				AND isnull(m.betstatus,'') <> 'refund'  
				AND s.ProductID = 3
				--AND b.bettype BETWEEN 81 AND 120
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
				SUM(acomm/(1 - apositiontaking - mpositiontaking)) as GrossComm,
				SUM(winlost - actual_stake) as MemberWinLost,
				SUM(playercomm) as MemberComm,
				SUM(Winlost - actual_stake + playercomm) as MemberTotal,
				SUM(awinlost) as AgentWinLost,
				SUM(comm) AS  AgentComm,
				SUM(winlost - actual_stake + awinlost + comm) AS AgentTotal,
				SUM(mwinlost) as MasterWinLost,
				SUM(acomm - comm) AS  MasterComm,
				SUM(mwinlost + acomm - comm) AS MasterTotal,
				SUM(acomm) as CompanyComm,
				-SUM(winlost - actual_stake + awinlost + mwinlost + acomm) as CompanyTotal,	
				'' as race,
				m.matchcode,
				isnull(m.isNeutral, CONVERT(BIT,0)) as IsNeutral,
				isnull(m.showtime, '') as showtime
			FROM 
				bettrans14 b WITH (NOLOCK,index=IX_bettrans4)
				INNER JOIN match14 m WITH (NOLOCK) ON m.matchid = b.matchid 	
				INNER JOIN @tmpLeague l ON m.leagueid = l.leagueid
				INNER JOIN #SportBettype s ON s.Bettype = b.bettype
				LEFT JOIN (SELECT * FROM [dbo].[f_GroupBettype]()) f ON f.bettype = b.bettype			
			WHERE 
				b.mrecommend = @custid
				--b.status not in ('VOID', 'REJECT', 'Refund') AND
				AND b.statusID NOT IN (101, 102, 103)
				AND b.bettype < 19001 
				AND b.bettype NOT IN (9,29,10)--,1231,1232,1233,1237,1238) AND
				AND m.eventdate >= @fromdate
				AND m.eventdate <= @todate
				AND m.eventstatus = 'completed'
				AND isnull(m.betstatus,'') <> 'refund' 
				AND s.ProductID IN(1, 4, 5) -- bettype NOT BETWEEN 81 AND 120
				AND s.EventType <> 3 -- bettype not in(1231, 1232, 1233, 1237, 1238)
				--AND b.bettype NOT BETWEEN 81 AND 120
			GROUP BY 
				m.matchid, m.homeid, m.awayid, m.leagueid, m.matchcode, m.isNeutral, m.showtime,
				CASE WHEN ISNULL(f.bettype,0) = 0 THEN b.bettype ELSE f.GroupTypeId END 

		-- mix parlay (14)
		/*
		IF @showSB = 1
		BEGIN
			INSERT INTO @tmpParlayRefno(TransID)
			SELECT b.TransID
			FROM bettrans14 b WITH (NOLOCK)
				INNER JOIN bettransm14 bm WITH(NOLOCK) ON b.refno = bm.refno
				INNER JOIN match14 m WITH(NOLOCK) ON bm.matchid = m.matchid
				INNER JOIN @tmpLeague l ON m.leagueid = l.leagueid
			WHERE 
				b.mrecommend = @custid
				AND b.winlostdate >= @fromdate
				AND b.winlostdate <= @todate
				AND b.bettype IN (9, 29)
				AND b.ruben = 1
				AND b.statusID NOT IN (101, 102, 103)
			GROUP BY  b.TransID
				
			INSERT INTO #MAgMatchWLDetails 	
			SELECT
				3 as BetGroup,
				0 as matchid,
				0 as homeid,
				0 as awayid,
				b.bettype,
				0 as liveindicator,
				0 as leagueid,
				SUM(ABS(b.stake)) as turnover,
				SUM(b.acomm/(1 - b.apositiontaking - b.mpositiontaking)) as GrossComm,
				SUM(b.winlost - b.actual_stake) as MemberWinLost,
				SUM(b.playercomm) as MemberComm,
				SUM(b.Winlost - b.actual_stake + b.playercomm) as MemberTotal,
				SUM(b.awinlost) as AgentWinLost,
				SUM(b.comm) AS  AgentComm,
				SUM(b.winlost - b.actual_stake + b.awinlost + b.comm) AS AgentTotal,
				SUM(b.mwinlost) as MasterWinLost,
				SUM(b.acomm - b.comm) AS  MasterComm,
				SUM(b.mwinlost + b.acomm - b.comm) AS MasterTotal,
				SUM(b.acomm) as CompanyComm,
				-SUM(b.winlost - b.actual_stake + b.awinlost + b.mwinlost + b.acomm) as CompanyTotal,	
				'' as race,
				'' as matchcode,
				CONVERT(BIT,0) as IsNeutral,
				'' as showtime
			FROM
				bettrans14 b WITH (NOLOCK,index=IX_bettrans4)
				INNER JOIN @tmpParlayRefno tmp ON b.TransID = tmp.TransID 
			WHERE 
				b.mrecommend = @custid AND
				b.bettype IN (9, 29) AND
				b.winlostdate >= @fromdate AND
				b.winlostdate <= @todate AND
				b.ruben = 1 AND
				--b.status not in ('VOID', 'REJECT', 'Refund') AND
				b.statusID NOT IN (101, 102, 103)
			GROUP BY b.bettype	
			HAVING ISNULL(COUNT(b.transid), 0) > 0
		END
			*/
			-- Virtual HR		
			INSERT INTO #MAgMatchWLDetails
			SELECT
				0 as BetGroup,
				'' matchid,
				0 as homeid,
                0 as awayid,
				b.bettype,
				0 as liveindicator,
				r.leagueid,
				SUM(ABS(stake)) as turnover,
				SUM(acomm/(1 - apositiontaking - mpositiontaking)) as GrossComm,
				SUM(winlost - actual_stake) as MemberWinLost,
				SUM(playercomm) as MemberComm,
				SUM(Winlost - actual_stake + playercomm) as MemberTotal,
				SUM(awinlost) as AgentWinLost,
				SUM(comm) AS  AgentComm,
				SUM(winlost - actual_stake + awinlost + comm) AS AgentTotal,
				SUM(mwinlost) as MasterWinLost,
				SUM(acomm - comm) AS  MasterComm,
				SUM(mwinlost + acomm - comm) AS MasterTotal,
				SUM(acomm) as CompanyComm,
				-SUM(winlost - actual_stake + awinlost + mwinlost + acomm) as CompanyTotal,						
				r.EventID as Race,
				'' matchcode,
				CONVERT (BIT, 0) AS IsNeutral,
				r.EventTime as showtime
			FROM 
				bettrans14 b WITH (NOLOCK)
				INNER JOIN VSOutright14 o WITH (NOLOCK) ON b.oddsid = o.Orid
				INNER JOIN VSRaceInfo r WITH (NOLOCK) ON r.EventID = o.EventID
				INNER JOIN @tmpLeague l ON r.leagueid = l.leagueid
				INNER JOIN #SportBettype s ON b.bettype = s.Bettype
			WHERE 
				b.mrecommend = @custid
				AND b.statusID NOT IN (101, 102, 103)
				AND o.eventdate >= @fromdate
				AND o.eventdate <= @todate
				AND o.eventstatus = 'completed'
				AND isnull(r.betstatus,'') <> 'refund'
				AND s.ProductID = 5
				AND s.EventType = 3
				--AND @showVS = 1 AND b.bettype IN (1231, 1232, 1233, 1237, 1238)
			GROUP BY 
				r.LeagueID, r.EventTime, r.eventID, b.bettype
			
			-- outright (14)
			INSERT INTO #MAgMatchWLDetails 
			SELECT
				(case b.bettype when 10 then 2 else 1 end) as BetGroup,		
				0 as matchid,
				0 as homeid,
				0 as awayid,
				b.bettype,
				0 as liveindicator,
				m.leagueid  as leagueid,	
				---SUM(case when b.liveawayscore = 0 and b.bettype in(33,43) then b.stake/2 else b.stake end),	
				SUM(case when b.liveawayscore = 0 and b.bettype in(33,43) then ABS(b.stake)/2 else ABS(b.stake) end) as TurnOver,
				SUM(acomm/(1 - apositiontaking-mpositiontaking)) as GrossComm,
				SUM(winlost - actual_stake) as MemberWinLost,
				SUM(playercomm) as MemberComm,
				SUM(Winlost - actual_stake+ playercomm) as MemberTotal,
				SUM(awinlost) as AgentWinLost,
				SUM(comm) AS  AgentComm,
				SUM(winlost - actual_stake+awinlost+comm) AS AgentTotal,
				SUM(mwinlost) as MasterWinLost,
				SUM(acomm - comm) AS  MasterComm,
				SUM(mwinlost + acomm - comm) AS MasterTotal,
				SUM(acomm) as CompanyComm,
				-SUM(winlost - actual_stake + awinlost + mwinlost + acomm) as CompanyTotal,
				m.groupmatch as race,		
				'ZZZZ' as matchcode,
				CONVERT(BIT,0) as IsNeutral,
				'' as showtime
			FROM 
				bettrans14 b WITH (NOLOCK,index=IX_bettrans4)
				inner join outright14 m with (nolock) on m.orid = b.matchid
				INNER JOIN @tmpLeague l ON m.leagueid = l.leagueid
				INNER JOIN #SportBettype s ON s.Bettype = b.bettype
			WHERE 
				b.mrecommend = @custid
				AND b.winlostdate >= @fromdate
				AND b.winlostdate <= @todate
				--AND s.ProductID IN(1, 2)
				AND s.EventType = 2
				--AND b.bettype IN (10,31,32,33,41,42,43)
				AND b.ruben = 1
				--b.status not in ('VOID', 'REJECT', 'Refund') AND
				AND b.statusID NOT IN (101, 102, 103)
			GROUP BY b.bettype, m.groupmatch, m.leagueid 
			HAVING ISNULL(COUNT(transid),0) > 0	

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
	SUM(MasterWinLost) as MasterWinLost, 
	SUM(MasterComm) as MasterComm, 
	SUM(MasterTotal) as MasterTotal,	
	SUM(CompanyComm) as CompanyComm, 
	SUM(CompanyTotal) as CompanyTotal,
	race, 
	matchcode, 
	isNeutral, 
	showtime
FROM #MAgMatchWLDetails	
GROUP BY BetGroup, matchid, homeid, awayid, bettype, liveindicator, leagueid, race, matchcode,isNeutral, showtime
ORDER BY betgroup, matchid, leagueid, race, bettype, liveindicator, matchcode


GO

SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO


GO 
 GRANT VIEW DEFINITION ON [dbo].[Age_Rpt_MatchWinLossDetail_MAg] TO [vnteam]
GO 
 GRANT EXECUTE ON [dbo].[Age_Rpt_MatchWinLossDetail_MAg] TO [bodbDownlineNetView]
GO 
 GRANT EXECUTE ON [dbo].[Age_Rpt_MatchWinLossDetail_MAg] TO [bodbDownlineNet]
GO 
 GRANT EXECUTE ON [dbo].[Age_Rpt_MatchWinLossDetail_MAg] TO [bodbAdminNet]
GO 
