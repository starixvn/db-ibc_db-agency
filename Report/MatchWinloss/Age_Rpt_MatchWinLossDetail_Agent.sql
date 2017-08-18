USE bodb02
GO

ALTER PROCEDURE [dbo].[Age_Rpt_MatchWinLossDetail_Agent] 
	@CustID			INT, --mrecommend
	@FromDate		SMALLDATETIME,
	@ToDate			SMALLDATETIME,
	@MoveBetsDay	SMALLDATETIME,
	@league			VARCHAR(4000),
	@ProductIds		VARCHAR(MAX)
AS

/*
	Created: 
	Task : 
	DB: DBAGE.bodb02
	Original: Age_Rpt_MatchWinLossDetail_MAg
	Revisions:
		- 20170224@Paul: Create new [RedmineID: #70554]
		- 20170622@Percy: Combine Betradar Virtual Sports with Virtual Sports [RedmineID: #78339]

*/

BEGIN
	SET NOCOUNT ON

	DECLARE @showSB	BIT,
			@showRB	BIT,
			@showNG	BIT,
			@showVS	BIT;

	SELECT	@showSB = CASE WHEN PATINDEX('%,1,%', ',' + @ProductIds + ',') > 0 THEN 1 ELSE 0 END,
			@showRB = CASE WHEN PATINDEX('%,2,%', ',' + @ProductIds + ',') > 0 THEN 1 ELSE 0 END,
			@showNG = CASE WHEN PATINDEX('%,3,%', ',' + @ProductIds + ',') > 0 THEN 1 ELSE 0 END,
			@showVS = CASE WHEN PATINDEX('%,5,%', ',' + @ProductIds + ',') > 0 THEN 1 ELSE 0 END;

	CREATE TABLE #MAgMatchWLDetails (
		BetGroup		INT,
		matchid			INT,
		homeid			INT,
		awayid			INT,
		bettype			SMALLINT,
		liveindicator	INT,
		leagueid		INT,
		turnover		MONEY,
		GrossComm		MONEY,
		MemberWinLoss	MONEY,
		MemberComm		MONEY,
		AgWinLoss		MONEY,
		AgComm			MONEY,
		MAgWinLoss		MONEY,
		MAgComm			MONEY,
		race			NVARCHAR(20),
		matchcode		NVARCHAR(50),
		isNeutral		BIT,
		showtime		NVARCHAR(50)
	);

	CREATE TABLE #SportBettype (
		ProductID	INT,
		Bettype		INT,
		EventType	INT
	);

	
	DECLARE @isTest BIT;
	SELECT  @isTest = dbo.f_CheckSPVersion(@@PROCID);

	SELECT @ProductIds = dbo.f_AddRelatedProducts(@ProductIds);

	INSERT INTO #SportBettype (ProductID, Bettype, EventType)
	SELECT ISNULL(p.GroupProductId, s.ProductID), Bettype, EventType
	FROM dbo.f_SportBettypeMatrixByProduct_Sel(@ProductIds, @isTest) s
		LEFT JOIN dbo.f_GroupProduct() p ON s.ProductID = p.ProductId;

	IF @league = ''
	BEGIN
		-- Get all leagues by sport's selected
		IF @Todate > @MoveBetsDay
		BEGIN
			INSERT INTO #MAgMatchWLDetails(BetGroup, matchid, homeid, awayid, bettype, liveindicator, leagueid, turnover, GrossComm, MemberWinLoss, MemberComm, AgWinLoss, AgComm, MAgWinLoss, MAgComm, race, matchcode, isNeutral, showtime)
			SELECT  0 as BetGroup,
					m.matchid,
					m.homeid,
					m.awayid,
					b.bettype,
					b.liveindicator,
					m.leagueid,
					SUM(ABS(stake)) as turnover,
					SUM(acomm/(1 - apositiontaking - mpositiontaking)) as GrossComm,
					SUM(winlost - actual_stake) as MemberWinLoss,
					SUM(playercomm) as MemberComm,
					SUM(awinlost) as AgWinLoss,
					SUM(comm) AS  AgComm,
					SUM(mwinlost) as MAgWinLoss,
					SUM(acomm - comm) AS  MAgComm,
					'' as race,
					m.matchcode,
					m.isNeutral,
					'' as showtime
			FROM bettrans b WITH (NOLOCK)
				INNER JOIN match m WITH (NOLOCK) ON m.matchid = b.matchid
				INNER JOIN #SportBettype s ON b.bettype = s.Bettype		
			WHERE b.mrecommend = @custid
				AND b.bettype NOT IN (9,29,10)
				AND b.statusID NOT IN (101, 102, 103)
				AND m.eventdate >= @fromdate
				AND m.eventdate <= @todate
				AND m.eventstatus = 'completed'
				AND isnull(m.betstatus, '') <> 'refund'
				AND s.ProductID = 3				
			GROUP BY 
				m.matchid, m.homeid, m.awayid, b.bettype, m.leagueid, m.matchcode, m.isNeutral,b.liveindicator
				
			UNION ALL --- Not number Game not group by liveindicator
			SELECT  0 as BetGroup,
					m.matchid,
					m.homeid,
					m.awayid,
					CASE WHEN ISNULL(f.bettype,0) = 0 THEN b.bettype ELSE f.GroupTypeId END AS bettype,
					0 as liveindicator,
					m.leagueid,
					SUM(ABS(stake)) as turnover,
					SUM(acomm/(1 - apositiontaking-mpositiontaking)) as GrossComm,
					SUM(winlost - actual_stake) as MemberWinLoss,
					SUM(playercomm) as MemberComm,
					SUM(awinlost) as AgWinLoss,
					SUM(comm) AS  AgComm,
					SUM(mwinlost) as MAgWinLoss,
					SUM(acomm - comm) AS  MAgComm,
					'' as race,
					m.matchcode,
					m.isNeutral,
					ISNULL(m.showtime, '') as showtime
			FROM bettrans b WITH (NOLOCK)
				INNER JOIN match m WITH (NOLOCK) ON m.matchid = b.matchid 	
				LEFT JOIN (SELECT * FROM [dbo].[f_GroupBettype]()) f ON f.bettype = b.bettype
				INNER JOIN #SportBettype s ON b.bettype = s.Bettype		
			WHERE b.mrecommend = @custid
				AND b.bettype NOT IN (9,29,10)
				AND b.statusID NOT IN (101, 102, 103)
				AND m.eventdate >= @fromdate
				AND m.eventdate <= @todate
				AND m.eventstatus = 'completed'
				AND isnull(m.betstatus,'') <> 'refund'
				AND s.ProductID IN(1, 4, 5)
				AND s.EventType <> 3	
			GROUP BY 
				m.matchid, m.homeid, m.awayid, m.leagueid, m.matchcode, m.isNeutral, m.showtime,
				CASE WHEN ISNULL(f.bettype,0) = 0 THEN b.bettype ELSE f.GroupTypeId END 
		
			-- MixParlay
			IF @showSB = 1 
			BEGIN
				INSERT INTO #MAgMatchWLDetails(BetGroup, matchid, homeid, awayid, bettype, liveindicator, leagueid, turnover, GrossComm, MemberWinLoss, MemberComm, AgWinLoss, AgComm, MAgWinLoss, MAgComm, race, matchcode, isNeutral, showtime)
				SELECT  3 as BetGroup,
						0 as matchid,
						0 as homeid,
						0 as awayid,
						b.bettype,
						0 as liveindicator,
						0 as leagueid,
						SUM(ABS(stake)) as turnover,
						SUM(acomm/(1 - apositiontaking - mpositiontaking)) as GrossComm,
						SUM(winlost - actual_stake) as MemberWinLoss,
						SUM(playercomm) as MemberComm,
						SUM(awinlost) as AgWinLoss,
						SUM(comm) AS  AgComm,
						SUM(mwinlost) as MAgWinLoss,
						SUM(acomm - comm) AS  MAgComm,
						'' as race,
						'' as matchcode,
						CONVERT(BIT,0) as IsNeutral,
						'' as showtime
					FROM bettrans b WITH (NOLOCK)
					WHERE b.mrecommend = @custid
						AND b.bettype IN (9,29)
						AND b.winlostdate >= @fromdate
						AND b.winlostdate <= @todate
						AND b.ruben = 1
						AND b.statusID NOT IN (101, 102, 103) 
					GROUP BY b.bettype	
					HAVING ISNULL(COUNT(transid),0) > 0
				END
		
			-- Virtual HR
			IF @showVS = 1 
			BEGIN
				INSERT INTO #MAgMatchWLDetails(BetGroup, matchid, homeid, awayid, bettype, liveindicator, leagueid, turnover, GrossComm, MemberWinLoss, MemberComm, AgWinLoss, AgComm, MAgWinLoss, MAgComm, race, matchcode, isNeutral, showtime)
				SELECT  0 as BetGroup,
						'' matchid,
						0 as homeid,
						0 as awayid,
						b.bettype,
						0 as liveindicator,
						r.leagueid,
						SUM(ABS(stake)) as turnover,
						SUM(acomm/(1 - apositiontaking - mpositiontaking)) as GrossComm,
						SUM(winlost - actual_stake) as MemberWinLoss,
						SUM(playercomm) as MemberComm,
						SUM(awinlost) as AgWinLoss,
						SUM(comm) AS  AgComm,
						SUM(mwinlost) as MAgWinLoss,
						SUM(acomm - comm) AS  MAgComm,					
						r.EventID as Race,
						'' matchcode,
						CONVERT (BIT, 0) AS IsNeutral,
						r.EventTime as showtime
				FROM bettrans b WITH (NOLOCK)
					INNER JOIN VSOutright o WITH (NOLOCK) ON b.oddsid = o.Orid
					INNER JOIN VSRaceInfo r WITH (NOLOCK) ON r.EventID = o.EventID
					INNER JOIN #SportBettype s ON s.Bettype = b.bettype
				WHERE b.mrecommend = @custid
					AND b.statusID NOT IN (101, 102, 103)
					AND o.eventdate >= @fromdate
					AND o.eventdate <= @todate
					AND o.eventstatus = 'completed'
					AND isnull(r.betstatus,'') <> 'refund'
					AND s.ProductID = 5
					AND s.EventType = 3
				GROUP BY 
					r.LeagueID, r.EventTime, r.eventID, b.bettype

				INSERT INTO #MAgMatchWLDetails(BetGroup, matchid, homeid, awayid, bettype, liveindicator, leagueid, turnover, GrossComm, MemberWinLoss, MemberComm, AgWinLoss, AgComm, MAgWinLoss, MAgComm, race, matchcode, isNeutral, showtime)
				SELECT  3 as BetGroup,
						0 as matchid,
						0 as homeid,
						0 as awayid,
						b.bettype,
						0 as liveindicator,
						0 as leagueid,
						SUM(ABS(stake)) as turnover,
						SUM(acomm/(1 - apositiontaking - mpositiontaking)) as GrossComm,
						SUM(winlost - actual_stake) as MemberWinLoss,
						SUM(playercomm) as MemberComm,
						SUM(awinlost) as AgWinLoss,
						SUM(comm) AS  AgComm,
						SUM(mwinlost) as MAgWinLoss,
						SUM(acomm - comm) AS  MAgComm,
						'' as race,
						'' as matchcode,
						CONVERT(BIT,0) as IsNeutral,
						'' as showtime
					FROM bettrans b WITH (NOLOCK)
					WHERE b.mrecommend = @custid
						AND b.bettype IN (2799)
						AND b.winlostdate >= @fromdate
						AND b.winlostdate <= @todate
						AND b.ruben = 1
						AND b.statusID NOT IN (101, 102, 103) 
					GROUP BY b.bettype	
					HAVING ISNULL(COUNT(transid),0) > 0
			END
		
			-- Outright
			INSERT INTO #MAgMatchWLDetails(BetGroup, matchid, homeid, awayid, bettype, liveindicator, leagueid, turnover, GrossComm, MemberWinLoss, MemberComm, AgWinLoss, AgComm, MAgWinLoss, MAgComm, race, matchcode, isNeutral, showtime)
			SELECT  (case b.bettype when 10 then 2 else 1 end) as BetGroup,		
					0 as matchid,
					0 as homeid,
					0 as awayid,
					b.bettype,
					0 as liveindicator,
					m.leagueid as leagueid,		
					SUM(case when b.liveawayscore = 0 and b.bettype in(33,43) then ABS(b.stake)/2 else ABS(b.stake) end) as TurnOver,				
					SUM(acomm/(1 - apositiontaking - mpositiontaking)) as GrossComm,
					SUM(winlost - actual_stake) as MemberWinLoss,
					SUM(playercomm) as MemberComm,	
					SUM(awinlost) as AgWinLoss,
					SUM(comm) AS  AgComm,
					SUM(mwinlost) as MAgWinLoss,
					SUM(acomm - comm) AS  MAgComm,
					m.groupmatch as race,		
					'ZZZZ' as matchcode,
					CONVERT(BIT, 0) as IsNeutral,
					'' as showtime
			FROM bettrans b WITH (NOLOCK)
				INNER JOIN outright m with (nolock) on m.orid = b.matchid
				INNER JOIN #SportBettype s ON b.bettype = s.Bettype
			WHERE b.mrecommend = @custid
				AND b.winlostdate >= @fromdate
				AND b.winlostdate <= @todate
				AND b.ruben = 1
				AND b.statusID NOT IN (101, 102, 103)
				AND s.EventType = 2
			GROUP BY b.bettype, m.groupmatch, m.leagueid
			HAVING ISNULL(COUNT(transid),0) > 0	

		END

		IF @Fromdate <= @MoveBetsDay
		BEGIN	
			INSERT INTO #MAgMatchWLDetails(BetGroup, matchid, homeid, awayid, bettype, liveindicator, leagueid, turnover, GrossComm, MemberWinLoss, MemberComm, AgWinLoss, AgComm, MAgWinLoss, MAgComm, race, matchcode, isNeutral, showtime) 	
			SELECT  0 as BetGroup,
					m.matchid,
					m.homeid,
					m.awayid,
					b.bettype,
					b.liveindicator,
					m.leagueid,
					SUM(ABS(stake)) as turnover,
					SUM(acomm/(1 - apositiontaking - mpositiontaking)) as GrossComm,
					SUM(winlost - actual_stake) as MemberWinLoss,
					SUM(playercomm) as MemberComm,
					SUM(awinlost) as AgWinLoss,
					SUM(comm) AS  AgComm,
					SUM(mwinlost) as MAgWinLoss,
					SUM(acomm - comm) AS  MAgComm,
					'' as race,
					m.matchcode,
					isnull(m.isNeutral, CONVERT(BIT,0)) as IsNeutral,
					'' as showtime
			FROM bettrans14 b WITH (NOLOCK,index=IX_bettrans4)
				INNER JOIN match14 m WITH (NOLOCK) ON m.matchid = b.matchid
				INNER JOIN #SportBettype s ON b.bettype = s.Bettype				
			WHERE b.mrecommend = @custid
				AND b.statusID NOT IN (101, 102, 103)
				AND b.bettype NOT IN (9,29,10)
				AND m.eventdate >= @fromdate
				AND m.eventdate <= @todate
				AND m.eventstatus = 'completed'
				AND isnull(m.betstatus,'') <> 'refund'
				AND s.ProductID = 3				
			GROUP BY 
				m.matchid, m.homeid, m.awayid, b.bettype, m.leagueid, m.matchcode, m.isNeutral, b.liveindicator
			
			UNION ALL --- Not number Game not group by liveindicator
			SELECT  0 as BetGroup,
					m.matchid,
					m.homeid,
					m.awayid,
					CASE WHEN ISNULL(f.bettype,0) = 0 THEN b.bettype ELSE f.GroupTypeId END AS bettype,
					0 as liveindicator,
					m.leagueid,
					SUM(ABS(stake)) as turnover,
					SUM(acomm/(1 - apositiontaking - mpositiontaking)) as GrossComm,
					SUM(winlost - actual_stake) as MemberWinLoss,
					SUM(playercomm) as MemberComm,
					SUM(awinlost) as AgWinLoss,
					SUM(comm) AS  AgComm,
					SUM(mwinlost) as MAgWinLoss,
					SUM(acomm - comm) AS  MAgComm,
					'' as race,
					m.matchcode,
					isnull(m.isNeutral, CONVERT(BIT, 0)) as IsNeutral,
					isnull(m.showtime, '') as showtime
			FROM bettrans14 b WITH (NOLOCK, index=IX_bettrans4)
				INNER JOIN match14 m WITH (NOLOCK) ON m.matchid = b.matchid 	
				LEFT JOIN (SELECT * FROM [dbo].[f_GroupBettype]()) f ON f.bettype = b.bettype
				INNER JOIN #SportBettype s ON b.bettype = s.Bettype		
			WHERE b.mrecommend = @custid
				AND b.statusID NOT IN (101, 102, 103)
				AND b.bettype NOT IN (9,29,10)
				AND m.eventdate >= @fromdate
				AND m.eventdate <= @todate
				AND m.eventstatus = 'completed'
				AND isnull(m.betstatus,'') <> 'refund'
				AND s.ProductID IN(1, 4, 5)
				AND s.EventType <> 3	
			GROUP BY m.matchid, m.homeid, m.awayid, m.leagueid, m.matchcode, m.isNeutral, m.showtime,
				CASE WHEN ISNULL(f.bettype,0) = 0 THEN b.bettype ELSE f.GroupTypeId END

			-- mix parlay (14)	
			IF @showSB = 1
			BEGIN
				INSERT INTO #MAgMatchWLDetails(BetGroup, matchid, homeid, awayid, bettype, liveindicator, leagueid, turnover, GrossComm, MemberWinLoss, MemberComm, AgWinLoss, AgComm, MAgWinLoss, MAgComm, race, matchcode, isNeutral, showtime) 	
				SELECT  3 as BetGroup,
						0 as matchid,
						0 as homeid,
						0 as awayid,
						b.bettype,
						0 as liveindicator,
						0 as leagueid,
						SUM(ABS(stake)) as turnover,
						SUM(acomm/(1 - apositiontaking - mpositiontaking)) as GrossComm,
						SUM(winlost - actual_stake) as MemberWinLoss,
						SUM(playercomm) as MemberComm,
						SUM(awinlost) as AgWinLoss,
						SUM(comm) AS  AgComm,
						SUM(mwinlost) as MAgWinLoss,
						SUM(acomm - comm) AS  MAgComm,
						'' as race,
						'' as matchcode,
						CONVERT(BIT,0) as IsNeutral,
						'' as showtime
				FROM bettrans14 b WITH (NOLOCK,index=IX_bettrans4)
				WHERE b.mrecommend = @custid
					AND b.bettype IN (9, 29)
					AND b.winlostdate >= @fromdate
					AND b.winlostdate <= @todate
					AND b.ruben = 1
					AND b.statusID NOT IN (101, 102, 103)
				GROUP BY b.bettype	
				HAVING ISNULL(COUNT(transid),0) > 0
			END
			
			-- Virtual HR
			IF @showVS = 1 
			BEGIN
				INSERT INTO #MAgMatchWLDetails(BetGroup, matchid, homeid, awayid, bettype, liveindicator, leagueid, turnover, GrossComm, MemberWinLoss, MemberComm, AgWinLoss, AgComm, MAgWinLoss, MAgComm, race, matchcode, isNeutral, showtime)
				SELECT  0 as BetGroup,
						'' matchid,
						0 as homeid,
						0 as awayid,
						b.bettype,
						0 as liveindicator,
						r.leagueid,
						SUM(ABS(stake)) as turnover,
						SUM(acomm/(1 - apositiontaking - mpositiontaking)) as GrossComm,
						SUM(winlost - actual_stake) as MemberWinLoss,
						SUM(playercomm) as MemberComm,
						SUM(awinlost) as AgWinLoss,
						SUM(comm) AS  AgComm,
						SUM(mwinlost) as MAgWinLoss,
						SUM(acomm - comm) AS  MAgComm,					
						r.EventID as Race,
						'' matchcode,
						CONVERT (BIT, 0) AS IsNeutral,
						r.EventTime as showtime
				FROM bettrans14 b WITH (NOLOCK)
					INNER JOIN VSOutright14 o WITH (NOLOCK) ON b.oddsid = o.Orid
					INNER JOIN VSRaceInfo r WITH (NOLOCK) ON r.EventID = o.EventID
					INNER JOIN #SportBettype s ON b.bettype = s.Bettype
				WHERE b.mrecommend = @custid
					AND b.statusID NOT IN (101, 102, 103)
					AND o.eventdate >= @fromdate
					AND o.eventdate <= @todate
					AND o.eventstatus = 'completed'
					AND isnull(r.betstatus, '') <> 'refund'
					AND s.ProductID = 5
					AND s.EventType = 3
				GROUP BY r.LeagueID, r.EventTime, r.eventID, b.bettype

				INSERT INTO #MAgMatchWLDetails(BetGroup, matchid, homeid, awayid, bettype, liveindicator, leagueid, turnover, GrossComm, MemberWinLoss, MemberComm, AgWinLoss, AgComm, MAgWinLoss, MAgComm, race, matchcode, isNeutral, showtime)
				SELECT  3 as BetGroup,
						0 as matchid,
						0 as homeid,
						0 as awayid,
						b.bettype,
						0 as liveindicator,
						0 as leagueid,
						SUM(ABS(stake)) as turnover,
						SUM(acomm/(1 - apositiontaking - mpositiontaking)) as GrossComm,
						SUM(winlost - actual_stake) as MemberWinLoss,
						SUM(playercomm) as MemberComm,
						SUM(awinlost) as AgWinLoss,
						SUM(comm) AS  AgComm,
						SUM(mwinlost) as MAgWinLoss,
						SUM(acomm - comm) AS  MAgComm,
						'' as race,
						'' as matchcode,
						CONVERT(BIT,0) as IsNeutral,
						'' as showtime
					FROM bettrans14 b WITH (NOLOCK)
					WHERE b.mrecommend = @custid
						AND b.bettype IN (2799)
						AND b.winlostdate >= @fromdate
						AND b.winlostdate <= @todate
						AND b.ruben = 1
						AND b.statusID NOT IN (101, 102, 103) 
					GROUP BY b.bettype	
					HAVING ISNULL(COUNT(transid),0) > 0
			END
		
			-- outright (14)
			INSERT INTO #MAgMatchWLDetails(BetGroup, matchid, homeid, awayid, bettype, liveindicator, leagueid, turnover, GrossComm, MemberWinLoss, MemberComm, AgWinLoss, AgComm, MAgWinLoss, MAgComm, race, matchcode, isNeutral, showtime)
			SELECT  (case b.bettype when 10 then 2 else 1 end) as BetGroup,		
					0 as matchid,
					0 as homeid,
					0 as awayid,
					b.bettype,
					0 as liveindicator,
					m.leagueid,	
					SUM(case when b.liveawayscore = 0 and b.bettype IN(33,43) then ABS(b.stake)/2 else ABS(b.stake) end) as TurnOver,
					SUM(acomm/(1 - apositiontaking - mpositiontaking)) as GrossComm,
					SUM(winlost - actual_stake) as MemberWinLoss,
					SUM(playercomm) as MemberComm,
					SUM(awinlost) as AgWinLoss,
					SUM(comm) AS  AgComm,
					SUM(mwinlost) as MAgWinLoss,
					SUM(acomm - comm) AS  MAgComm,
					m.groupmatch as race,		
					'ZZZZ' as matchcode,
					CONVERT(BIT,0) as IsNeutral,
					'' as showtime
			FROM bettrans14 b WITH (NOLOCK,index=IX_bettrans4)
				INNER JOIN outright14 m WITH (NOLOCK) ON m.orid = b.matchid
				INNER JOIN #SportBettype s ON b.bettype = s.Bettype
			WHERE b.mrecommend = @custid
				AND b.winlostdate >= @fromdate
				AND b.winlostdate <= @todate
				AND s.EventType = 2
				AND b.ruben = 1
				AND b.statusID NOT IN (101, 102, 103)
			GROUP BY b.bettype, m.groupmatch, m.leagueid
			HAVING ISNULL(COUNT(transid),0) > 0	

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
			INSERT INTO #MAgMatchWLDetails(BetGroup, matchid, homeid, awayid, bettype, liveindicator, leagueid, turnover, GrossComm, MemberWinLoss, MemberComm, AgWinLoss, AgComm, MAgWinLoss, MAgComm, race, matchcode, isNeutral, showtime)
			SELECT  0 as BetGroup,
					m.matchid,
					m.homeid,
					m.awayid,
					b.bettype,
					b.liveindicator,
					m.leagueid,
					SUM(ABS(stake)) as turnover,
					SUM(acomm/(1 - apositiontaking - mpositiontaking)) as GrossComm,
					SUM(winlost - actual_stake) as MemberWinLoss,
					SUM(playercomm) as MemberComm,
					SUM(awinlost) as AgWinLoss,
					SUM(comm) AS  AgComm,
					SUM(mwinlost) as MAgWinLoss,
					SUM(acomm - comm) AS  MAgComm,
					'' as race,
					m.matchcode,
					m.isNeutral,
					'' as showtime
			FROM bettrans b WITH (NOLOCK)
				INNER JOIN match m WITH (NOLOCK) ON m.matchid = b.matchid
				INNER JOIN #SportBettype s ON b.bettype = s.Bettype	
				INNER JOIN @tmpLeague l ON m.leagueid = l.leagueid 			
			WHERE b.mrecommend = @custid
				AND b.bettype NOT IN (9,29,10)
				AND b.statusID NOT IN (101, 102, 103)
				AND m.eventdate >= @fromdate
				AND m.eventdate <= @todate
				AND m.eventstatus = 'completed'
				AND isnull(m.betstatus, '') <> 'refund'
				AND s.ProductID = 3
			GROUP BY m.matchid, m.homeid, m.awayid, b.bettype, m.leagueid, m.matchcode, m.isNeutral, b.liveindicator
				
			UNION ALL --- Not number Game not group by liveindicator
			SELECT  0 as BetGroup,
					m.matchid,
					m.homeid,
					m.awayid,
					CASE WHEN ISNULL(f.bettype,0) = 0 THEN b.bettype ELSE f.GroupTypeId END AS bettype,	
					0 as liveindicator,
					m.leagueid,
					SUM(ABS(stake)) as turnover,
					SUM(acomm/(1 - apositiontaking - mpositiontaking)) as GrossComm,
					SUM(winlost - actual_stake) as MemberWinLoss,
					SUM(playercomm) as MemberComm,
					SUM(awinlost) as AgWinLoss,
					SUM(comm) AS  AgComm,
					SUM(mwinlost) as MAgWinLoss,
					SUM(acomm - comm) AS  MAgComm,
					'' as race,
					m.matchcode,
					m.isNeutral,
					isnull(m.showtime, '') as showtime
			FROM bettrans b WITH (NOLOCK)
				INNER JOIN match m WITH (NOLOCK) ON m.matchid = b.matchid 	
				INNER JOIN @tmpLeague l ON m.leagueid = l.leagueid 
				INNER JOIN #SportBettype s ON b.bettype = s.Bettype
				LEFT JOIN (SELECT * FROM [dbo].[f_GroupBettype]()) f ON f.bettype = b.bettype	
			WHERE b.mrecommend = @custid
				AND b.bettype < 19001 
				AND b.bettype NOT IN (9,29,10)
				AND b.statusID NOT IN (101, 102, 103)
				AND m.eventdate >= @fromdate
				AND m.eventdate <= @todate
				AND m.eventstatus = 'completed'
				AND isnull(m.betstatus,'') <> 'refund'
				AND s.ProductID IN(1, 4, 5)
				AND s.EventType <> 3
			GROUP BY m.matchid, m.homeid, m.awayid, m.leagueid, m.matchcode, m.isNeutral, m.showtime,
				CASE WHEN ISNULL(f.bettype,0) = 0 THEN b.bettype ELSE f.GroupTypeId END
		
			-- Virtual HR		
			INSERT INTO #MAgMatchWLDetails(BetGroup, matchid, homeid, awayid, bettype, liveindicator, leagueid, turnover, GrossComm, MemberWinLoss, MemberComm, AgWinLoss, AgComm, MAgWinLoss, MAgComm, race, matchcode, isNeutral, showtime)
			SELECT  0 as BetGroup,
					'' matchid,
					0 as homeid,
					0 as awayid,
					b.bettype,
					0 as liveindicator,
					r.leagueid,
					SUM(ABS(stake)) as turnover,
					SUM(acomm/(1 - apositiontaking - mpositiontaking)) as GrossComm,
					SUM(winlost - actual_stake) as MemberWinLoss,
					SUM(playercomm) as MemberComm,
					SUM(awinlost) as AgWinLoss,
					SUM(comm) AS  AgComm,
					SUM(mwinlost) as MAgWinLoss,
					SUM(acomm - comm) AS  MAgComm,					
					r.EventID as Race,
					'' matchcode,
					CONVERT (BIT, 0) AS IsNeutral,
					r.EventTime as showtime
			FROM bettrans b WITH (NOLOCK)
				INNER JOIN VSOutright o WITH (NOLOCK) ON b.oddsid = o.Orid
				INNER JOIN VSRaceInfo r WITH (NOLOCK) ON r.EventID = o.EventID
				INNER JOIN @tmpLeague l ON r.leagueid = l.leagueid
				INNER JOIN #SportBettype s ON b.bettype = s.Bettype
			WHERE b.mrecommend = @custid
				AND b.statusID NOT IN (101, 102, 103)
				AND o.eventdate >= @fromdate
				AND o.eventdate <= @todate
				AND o.eventstatus = 'completed'
				AND isnull(r.betstatus, '') <> 'refund'
				AND s.ProductID = 5
				AND s.EventType = 3
			GROUP BY r.LeagueID, r.EventTime, r.eventID, b.bettype
			
			-- Outright
			INSERT INTO #MAgMatchWLDetails(BetGroup, matchid, homeid, awayid, bettype, liveindicator, leagueid, turnover, GrossComm, MemberWinLoss, MemberComm, AgWinLoss, AgComm, MAgWinLoss, MAgComm, race, matchcode, isNeutral, showtime)
			SELECT  (case b.bettype when 10 then 2 else 1 end) as BetGroup,		
					0 as matchid,
					0 as homeid,
					0 as awayid,
					b.bettype,
					0 as liveindicator,
					m.leagueid  as leagueid,	
					SUM(case when b.liveawayscore = 0 and b.bettype in(33,43) then ABS(b.stake)/2 else ABS(b.stake) end) as TurnOver,
					SUM(acomm/(1 - apositiontaking - mpositiontaking)) as GrossComm,
					SUM(winlost - actual_stake) as MemberWinLoss,
					SUM(playercomm) as MemberComm,	
					SUM(awinlost) as AgWinLoss,
					SUM(comm) AS  AgComm,
					SUM(mwinlost) as MAgWinLoss,
					SUM(acomm - comm) AS  MAgComm,
					m.groupmatch as race,		
					'ZZZZ' as matchcode,
					CONVERT(BIT,0) as IsNeutral,
					'' as showtime
			FROM bettrans b WITH (NOLOCK)
				INNER JOIN outright m WITH (NOLOCK) ON m.orid = b.matchid
				INNER JOIN @tmpLeague l ON m.leagueid = l.leagueid
				INNER JOIN #SportBettype s ON b.bettype = s.Bettype
			WHERE b.mrecommend = @custid
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
			INSERT INTO #MAgMatchWLDetails(BetGroup, matchid, homeid, awayid, bettype, liveindicator, leagueid, turnover, GrossComm, MemberWinLoss, MemberComm, AgWinLoss, AgComm, MAgWinLoss, MAgComm, race, matchcode, isNeutral, showtime)
			SELECT  0 as BetGroup,
					m.matchid,
					m.homeid,
					m.awayid,
					b.bettype,
					b.liveindicator,
					m.leagueid,
					SUM(ABS(stake)) as turnover,
					SUM(acomm/(1 - apositiontaking - mpositiontaking)) as GrossComm,
					SUM(winlost - actual_stake) as MemberWinLoss,
					SUM(playercomm) as MemberComm,
					SUM(awinlost) as AgWinLoss,
					SUM(comm) AS  AgComm,
					SUM(mwinlost) as MAgWinLoss,
					SUM(acomm - comm) AS  MAgComm,
					'' as race,
					m.matchcode,
					isnull(m.isNeutral, CONVERT(BIT,0)) as IsNeutral,
					'' as showtime
			FROM bettrans14 b WITH (NOLOCK,index=IX_bettrans4)
				INNER JOIN match14 m WITH (NOLOCK) ON m.matchid = b.matchid 	
				INNER JOIN @tmpLeague l ON m.leagueid = l.leagueid
				INNER JOIN #SportBettype s ON b.bettype = s.Bettype		
			WHERE b.mrecommend = @custid
				AND b.statusID NOT IN (101, 102, 103)
				AND b.bettype NOT IN (9,29,10)
				AND m.eventdate >= @fromdate
				AND m.eventdate <= @todate 
				AND m.eventstatus = 'completed'  
				AND isnull(m.betstatus,'') <> 'refund'  
				AND s.ProductID = 3
			GROUP BY m.matchid, m.homeid, m.awayid, b.bettype, m.leagueid, m.matchcode, m.isNeutral, b.liveindicator
				
			UNION ALL --- Not number Game not group by liveindicator
			SELECT  0 as BetGroup,
					m.matchid,
					m.homeid,
					m.awayid,
					CASE WHEN ISNULL(f.bettype,0) = 0 THEN b.bettype ELSE f.GroupTypeId END AS bettype,
					0 as liveindicator,
					m.leagueid,
					SUM(ABS(stake)) as turnover,
					SUM(acomm/(1 - apositiontaking - mpositiontaking)) as GrossComm,
					SUM(winlost - actual_stake) as MemberWinLoss,
					SUM(playercomm) as MemberComm,
					SUM(awinlost) as AgWinLoss,
					SUM(comm) AS  AgComm,
					SUM(mwinlost) as MAgWinLoss,
					SUM(acomm - comm) AS  MAgComm,
					'' as race,
					m.matchcode,
					isnull(m.isNeutral, CONVERT(BIT,0)) as IsNeutral,
					isnull(m.showtime, '') as showtime
			FROM bettrans14 b WITH (NOLOCK,index=IX_bettrans4)
				INNER JOIN match14 m WITH (NOLOCK) ON m.matchid = b.matchid 	
				INNER JOIN @tmpLeague l ON m.leagueid = l.leagueid
				INNER JOIN #SportBettype s ON s.Bettype = b.bettype
				LEFT JOIN (SELECT * FROM [dbo].[f_GroupBettype]()) f ON f.bettype = b.bettype			
			WHERE b.mrecommend = @custid
				AND b.statusID NOT IN (101, 102, 103)
				AND b.bettype < 19001 
				AND b.bettype NOT IN (9,29,10)
				AND m.eventdate >= @fromdate
				AND m.eventdate <= @todate
				AND m.eventstatus = 'completed'
				AND isnull(m.betstatus,'') <> 'refund' 
				AND s.ProductID IN(1, 4, 5) 
				AND s.EventType <> 3
			GROUP BY m.matchid, m.homeid, m.awayid, m.leagueid, m.matchcode, m.isNeutral, m.showtime,
				CASE WHEN ISNULL(f.bettype,0) = 0 THEN b.bettype ELSE f.GroupTypeId END 
			
			-- Virtual HR		
			INSERT INTO #MAgMatchWLDetails(BetGroup, matchid, homeid, awayid, bettype, liveindicator, leagueid, turnover, GrossComm, MemberWinLoss, MemberComm, AgWinLoss, AgComm, MAgWinLoss, MAgComm, race, matchcode, isNeutral, showtime)
			SELECT  0 as BetGroup,
					'' matchid,
					0 as homeid,
					0 as awayid,
					b.bettype,
					0 as liveindicator,
					r.leagueid,
					SUM(ABS(stake)) as turnover,
					SUM(acomm/(1 - apositiontaking - mpositiontaking)) as GrossComm,
					SUM(winlost - actual_stake) as MemberWinLoss,
					SUM(playercomm) as MemberComm,
					SUM(awinlost) as AgWinLoss,
					SUM(comm) AS  AgComm,
					SUM(mwinlost) as MAgWinLoss,
					SUM(acomm - comm) AS  MAgComm,					
					r.EventID as Race,
					'' matchcode,
					CONVERT (BIT, 0) AS IsNeutral,
					r.EventTime as showtime
			FROM bettrans14 b WITH (NOLOCK)
				INNER JOIN VSOutright14 o WITH (NOLOCK) ON b.oddsid = o.Orid
				INNER JOIN VSRaceInfo r WITH (NOLOCK) ON r.EventID = o.EventID
				INNER JOIN @tmpLeague l ON r.leagueid = l.leagueid
				INNER JOIN #SportBettype s ON b.bettype = s.Bettype
			WHERE b.mrecommend = @custid
				AND b.statusID NOT IN (101, 102, 103)
				AND o.eventdate >= @fromdate
				AND o.eventdate <= @todate
				AND o.eventstatus = 'completed'
				AND isnull(r.betstatus,'') <> 'refund'
				AND s.ProductID = 5
				AND s.EventType = 3
			GROUP BY r.LeagueID, r.EventTime, r.eventID, b.bettype
			
			-- outright (14)
			INSERT INTO #MAgMatchWLDetails(BetGroup, matchid, homeid, awayid, bettype, liveindicator, leagueid, turnover, GrossComm, MemberWinLoss, MemberComm, AgWinLoss, AgComm, MAgWinLoss, MAgComm, race, matchcode, isNeutral, showtime)
			SELECT  (case b.bettype when 10 then 2 else 1 end) as BetGroup,		
					0 as matchid,
					0 as homeid,
					0 as awayid,
					b.bettype,
					0 as liveindicator,
					m.leagueid  as leagueid,	
					SUM(case when b.liveawayscore = 0 and b.bettype in(33,43) then ABS(b.stake)/2 else ABS(b.stake) end) as TurnOver,
					SUM(acomm/(1 - apositiontaking-mpositiontaking)) as GrossComm,
					SUM(winlost - actual_stake) as MemberWinLoss,
					SUM(playercomm) as MemberComm,
					SUM(awinlost) as AgWinLoss,
					SUM(comm) AS  AgComm,
					SUM(mwinlost) as MAgWinLoss,
					SUM(acomm - comm) AS  MAgComm,
					m.groupmatch as race,		
					'ZZZZ' as matchcode,
					CONVERT(BIT,0) as IsNeutral,
					'' as showtime
			FROM bettrans14 b WITH (NOLOCK,index=IX_bettrans4)
				INNER JOIN outright14 m WITH (NOLOCK) ON m.orid = b.matchid
				INNER JOIN @tmpLeague l ON m.leagueid = l.leagueid
				INNER JOIN #SportBettype s ON s.Bettype = b.bettype
			WHERE b.mrecommend = @custid
				AND b.winlostdate >= @fromdate
				AND b.winlostdate <= @todate
				AND s.EventType = 2
				AND b.ruben = 1
				AND b.statusID NOT IN (101, 102, 103)
			GROUP BY b.bettype, m.groupmatch, m.leagueid 
			HAVING ISNULL(COUNT(transid),0) > 0	

		END
	END

	SELECT	BetGroup, 
			matchid, 
			homeid, 
			awayid, 
			bettype, 
			liveindicator,
			leagueid,
			SUM(turnover) as turnover,
			SUM(GrossComm) as GrossComm, 
			SUM(MemberWinLoss) as MemberWinLoss, 
			SUM(MemberComm) as MemberComm, 
			SUM(AgWinLoss) as AgWinLoss,
			SUM(AgComm) as AgComm, 
			SUM(MAgWinLoss) as MAgWinLoss, 
			SUM(MAgComm) as MAgComm, 
			race, 
			matchcode, 
			isNeutral, 
			showtime
	FROM #MAgMatchWLDetails	
	GROUP BY BetGroup, matchid, homeid, awayid, bettype, liveindicator, leagueid, race, matchcode,isNeutral, showtime
	ORDER BY betgroup, matchid, leagueid, race, bettype, liveindicator, matchcode

	SET NOCOUNT OFF;
END
GO

SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO


GO 
 GRANT VIEW DEFINITION ON [dbo].[Age_Rpt_MatchWinLossDetail_Agent] TO [vnteam]
GO 
 GRANT EXECUTE ON [dbo].[Age_Rpt_MatchWinLossDetail_Agent] TO [bodbDownlineNetView]
GO 
 GRANT EXECUTE ON [dbo].[Age_Rpt_MatchWinLossDetail_Agent] TO [bodbDownlineNet]
GO 
 GRANT EXECUTE ON [dbo].[Age_Rpt_MatchWinLossDetail_Agent] TO [bodbAdminNet]
GO 
