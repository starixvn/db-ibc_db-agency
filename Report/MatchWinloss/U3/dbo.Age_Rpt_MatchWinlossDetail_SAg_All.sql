/*<info serverAlias="DBAGE-bodb02" executers="bodbAdminNet,bodbDownlineNet,bodbDownlineNetView" viewers="" isFunction="0" isNested="1"></info>*/
ALTER PROCEDURE [dbo].[Age_Rpt_MatchWinlossDetail_SAg_All] 
	@CustID				INT
	,@fromdate			SMALLDATETIME   
	,@todate			SMALLDATETIME   
	,@MoveBetsDay		SMALLDATETIME
	,@showSB			BIT = 1
	,@showRB			BIT = 0
	,@showNG			BIT	= 0
	,@showLiveCasino	BIT = 0
	,@showVS			BIT = 0
	,@showLK3		BIT = 0
AS

/*
	Created: 20160505@Sophia
	Task: Create SP Match Winloss Detail all League [Redmine: #55746]
	DB: DBAGE.bodb02
	Original: Rpt_MatchWinlostDetail_SAg
	
	Revisions:
		- 20170808@Percy: Integrate Lucky 3 [RedmineID: #80219]
		- 20200622@Sol: Archive VSRaceInfo - changed to use VSRaceInfo14 [RedmineID: #135963]
		- 20201229@Malcolm : Support Happy 5 Linked Games [RedminedId : #146542]
		- 20210823@Sol: Alpha - Allow more time to transfer (phase 2b) - [RedmineID: #160440]
    
*/

BEGIN
	SET NOCOUNT ON

	---- To avoid parametter sniffing
	DECLARE @FDate SMALLDATETIME, @TDate SMALLDATETIME
	SELECT @FDate = @fromdate, @TDate= @todate

	DECLARE @BalanceUpDay SMALLDATETIME
	DECLARE @tblMoveBetBalanceUp AS TABLE (BalanceUpDay SMALLDATETIME, MoveBetsDay SMALLDATETIME)

	INSERT INTO @tblMoveBetBalanceUp(BalanceUpDay,MoveBetsDay)
	EXEC bodb02.dbo.Age_SelBalanceUpDay
	
	SELECT @BalanceUpDay = BalanceUpDay FROM @tblMoveBetBalanceUp

	IF OBJECT_ID('tempdb..#SAgMatchWLDetails') IS NOT NULL
	BEGIN
		DROP TABLE #SAgMatchWLDetails
	END

	CREATE TABLE #SAgMatchWLDetails(
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
					,SAgWinLost		MONEY
					,SAgComm		MONEY
					,SAgTotal		MONEY
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

	----- Get sport bettype-------
	----- Check SP Version
	DECLARE @isTest BIT = 0
	SELECT  @isTest = dbo.f_CheckSPVersion(@@PROCID)
	
	INSERT INTO #SportBettype (ProductID, Bettype, EventType)
	SELECT ProductID, Bettype, EventType 
	FROM  dbo.f_SportBettypeMatrix_Sel (0, 0, 0, 2, '', @ProductPrefix, @IsTest) 

	---- End get sport bettype ----

	CREATE TABLE #RecommendList (recommend INT)

	-- Get all leagues by sport's selected
	IF @tdate > @MoveBetsDay
	BEGIN
		IF @FromDate <= @MoveBetsDay
		BEGIN
			SET @FDate = DATEADD(DD, 1, @MoveBetsDay);
		END

		IF @showNG	= 1
		BEGIN 
			INSERT INTO #SAgMatchWLDetails 
			SELECT
				0 AS BetGroup
				,m.matchid
				,m.homeid
				,m.awayid
				,b.bettype
				,b.liveindicator
				,m.leagueid
				,SUM(ABS(stake)) AS turnover
				,SUM(CASE WHEN b.tpositiontaking = 1 THEN 0 ELSE scomm/(1 - tpositiontaking) END) AS GrossComm
				,SUM(winlost - actual_stake) AS MemberWinLost
				,SUM(playercomm) AS MemberComm
				,SUM(Winlost - actual_stake + playercomm) AS MemberTotal
				,SUM(awinlost) AS AgentWinLost
				,SUM(comm - playercomm) AS  AgentComm
				,SUM(awinlost + comm - playercomm) AS AgentTotal
				,SUM(mwinlost) AS MasterWinLost
				,SUM(acomm - comm) AS  MasterComm
				,SUM(mwinlost + acomm - comm) AS MasterTotal
				,SUM(swinlost) AS SAgWinLost
				,SUM(scomm - acomm) AS SAgComm
				,ISNULL(SUM(swinlost), 0) + ISNULL(SUM(scomm), 0) - SUM(acomm) AS SAgTotal
				,SUM(scomm) AS CompanyComm
				,-(ISNULL(SUM(swinlost), 0) + ISNULL(SUM(awinlost), 0) + ISNULL(SUM(mwinlost), 0) + ISNULL(SUM(scomm), 0) + ISNULL(SUM(winlost - actual_stake), 0)) AS CompanyTotal
				,'' AS race
				,m.matchcode
				,isnull(m.isNeutral, CONVERT(BIT, 0)) AS IsNeutral
				,'' AS showtime
			FROM 
				bettrans b WITH (NOLOCK)
				INNER JOIN match m WITH (NOLOCK) ON m.matchid = b.matchid
				INNER JOIN #SportBettype s ON b.bettype = s.Bettype 		
			WHERE 
				b.srecommend = @custid
				AND b.winlostdate BETWEEN @FDate AND @TDate
				AND m.eventstatus = 'completed' 
				AND isnull(m.betstatus,'') <> 'refund'					
				AND b.statusID NOT IN (101, 102, 103)
				AND s.ProductID = 3													
			GROUP BY 
				m.matchid, m.homeid, m.awayid, b.bettype, m.leagueid, m.matchcode, m.isNeutral, b.liveindicator
			
			INSERT INTO #SAgMatchWLDetails 
				SELECT
					4 as BetGroup,
					0 as matchid,
					0 as homeid,
					0 as awayid,
					b.bettype,
					0 as liveindicator,
					0 as leagueid,
					isnull(SUM(ABS(stake)), 0) as turnover,
					isnull(SUM(CASE WHEN b.tpositiontaking = 1 THEN 0 ELSE scomm/(1 - tpositiontaking) END), 0) AS GrossComm,
					isnull(SUM(winlost - actual_stake), 0) as MemberWinLost,
					isnull(SUM(playercomm), 0) as MemberComm,
					isnull(SUM(Winlost - actual_stake + playercomm), 0) as MemberTotal,
					isnull(SUM(awinlost), 0) as AgentWinLost,
					isnull(SUM(comm - playercomm), 0) AS  AgentComm,
					isnull(SUM(awinlost + comm - playercomm), 0) AS AgentTotal,
					isnull(SUM(mwinlost), 0) as MasterWinLost,
					isnull(SUM(acomm - comm), 0) AS  MasterComm,
					isnull(SUM(mwinlost + acomm - comm), 0) AS MasterTotal,
					isnull(SUM(swinlost), 0) as SAgWinLost,
					isnull(SUM(scomm - acomm), 0) AS  SAgComm,
					isnull(SUM(swinlost), 0) + isnull(SUM(scomm), 0)-isnull(SUM(acomm),0) as SAgTotal,
					isnull(SUM(scomm), 0) as CompanyComm,
					-(isnull(SUM(swinlost), 0) + isnull(SUM(awinlost), 0) + isnull(SUM(mwinlost), 0) + isnull(SUM(scomm), 0) + isnull(SUM(winlost-actual_stake), 0))  as CompanyTotal,	
					'' as race,
					'' as matchcode,
					CONVERT(BIT,0) as IsNeutral,
					'' as showtime
				FROM bettrans b WITH (NOLOCK)
					INNER JOIN #SportBettype s ON s.Bettype = b.bettype
				WHERE 
					b.srecommend = @custid
					AND b.winlostdate BETWEEN @FDate AND @TDate
					AND b.ruben = 1
					AND b.statusID NOT IN (101, 102, 103) 
					AND s.ProductID = 3 
					AND s.EventType <> 1
				GROUP BY b.bettype	
				HAVING ISNULL(COUNT(transid), 0) > 0
		END 
			
		--- Not number Game not group by liveindicator	
		IF (@ShowSB = 1 OR @showLiveCasino = 1 OR @showVS = 1 OR @showLK3 = 1)
		BEGIN
			INSERT INTO #SAgMatchWLDetails 
			SELECT
				0 AS BetGroup
				,m.matchid
				,m.homeid
				,m.awayid
				,CASE WHEN ISNULL(f.bettype,0) = 0 THEN b.bettype ELSE f.GroupTypeId END AS bettype
				,0 AS liveindicator
				,m.leagueid
				,SUM(ABS(stake)) AS turnover
				,SUM(CASE WHEN b.tpositiontaking = 1 THEN 0 ELSE scomm/(1 - tpositiontaking) END) AS GrossComm
				,SUM(winlost - actual_stake) AS MemberWinLost
				,SUM(playercomm) AS MemberComm
				,SUM(Winlost - actual_stake + playercomm) AS MemberTotal
				,SUM(awinlost) AS AgentWinLost
				,SUM(comm - playercomm) AS  AgentComm
				,SUM(awinlost + comm - playercomm) AS AgentTotal
				,SUM(mwinlost) AS MasterWinLost
				,SUM(acomm - comm) AS  MasterComm
				,SUM(mwinlost + acomm - comm) AS MasterTotal
				,SUM(swinlost) AS SAgWinLost
				,SUM(scomm - acomm) AS  SAgComm
				,ISNULL(SUM(swinlost), 0) + ISNULL(SUM(scomm), 0) - SUM(acomm) AS SAgTotal
				,SUM(scomm) AS CompanyComm
				,-(ISNULL(SUM(swinlost), 0) + ISNULL(SUM(awinlost), 0) + ISNULL(SUM(mwinlost), 0) + ISNULL(SUM(scomm), 0) + ISNULL(SUM(winlost - actual_stake), 0)) AS CompanyTotal
				,'' AS race
				,m.matchcode
				,ISNULL(m.isNeutral, CONVERT(BIT, 0)) AS IsNeutral
				,ISNULL(m.showtime, '') AS showtime
			FROM 
				bettrans b WITH (NOLOCK)
				INNER JOIN match m WITH (NOLOCK) ON m.matchid = b.matchid 	
				LEFT JOIN (SELECT bettype, GroupTypeId FROM [dbo].[f_GroupBettype]()) f ON f.bettype = b.bettype
				INNER JOIN #SportBettype s ON b.bettype = s.Bettype			
			WHERE 
				b.srecommend = @custid				
				AND b.winlostdate BETWEEN @FDate AND @TDate
				AND m.eventstatus = 'completed'
				AND isnull(m.betstatus,'') <> 'refund'
				AND b.Bettype < 19001
				AND b.bettype NOT IN (9, 29, 10)
				AND b.statusID NOT IN (101, 102, 103)
				AND s.ProductID IN (1, 4, 5, 26)	--- SB - Live Casino - VS - Lucky 3
				AND s.EventType <> 3 --- exclude VS HR					
			GROUP BY 
				m.matchid, m.homeid, m.awayid, m.leagueid, m.matchcode, m.isNeutral,m.showtime,
				CASE WHEN ISNULL(f.bettype,0) = 0 THEN b.bettype ELSE f.GroupTypeId END
		END 	
					
		-- Mix Parlay
		IF @showSB = 1
		BEGIN
			INSERT INTO #SAgMatchWLDetails 
				SELECT
					3 as BetGroup,
					0 as matchid,
					0 as homeid,
					0 as awayid,
					b.bettype,
					0 as liveindicator,
					0 as leagueid,
					isnull(SUM(ABS(stake)), 0) as turnover,
					isnull(SUM(CASE WHEN b.tpositiontaking = 1 THEN 0 ELSE scomm/(1 - tpositiontaking) END) , 0) as GrossComm,
					isnull(SUM(winlost - actual_stake), 0) as MemberWinLost,
					isnull(SUM(playercomm), 0) as MemberComm,
					isnull(SUM(Winlost - actual_stake + playercomm), 0) as MemberTotal,
					isnull(SUM(awinlost), 0) as AgentWinLost,
					isnull(SUM(comm - playercomm), 0) AS  AgentComm,
					isnull(SUM(awinlost + comm - playercomm), 0) AS AgentTotal,
					isnull(SUM(mwinlost), 0) as MasterWinLost,
					isnull(SUM(acomm - comm), 0) AS  MasterComm,
					isnull(SUM(mwinlost + acomm - comm), 0) AS MasterTotal,
					isnull(SUM(swinlost), 0) as SAgWinLost,
					isnull(SUM(scomm - acomm), 0) AS  SAgComm,
					isnull(SUM(swinlost), 0) + isnull(SUM(scomm), 0)-isnull(SUM(acomm),0) as SAgTotal,
					isnull(SUM(scomm), 0) as CompanyComm,
					-(isnull(SUM(swinlost), 0) + isnull(SUM(awinlost), 0) + isnull(SUM(mwinlost), 0) + isnull(SUM(scomm), 0) + isnull(SUM(winlost-actual_stake), 0))  as CompanyTotal,	
					'' as race,
					'' as matchcode,
					CONVERT(BIT,0) as IsNeutral,
					'' as showtime
				FROM
					bettrans b WITH (NOLOCK)
				WHERE 
					b.srecommend = @custid
					AND b.bettype IN (9, 29)
					AND b.winlostdate BETWEEN @FDate AND @TDate
					AND b.ruben = 1
					AND b.statusID NOT IN (101, 102, 103) 
				GROUP BY b.bettype	
				HAVING ISNULL(COUNT(transid), 0) > 0
		END
		
		-- Outright
		IF (@showSB = 1 OR @showRB = 1)
		BEGIN 
			INSERT INTO #SAgMatchWLDetails 
			SELECT
				(case b.bettype when 10 then 2 else 1 end) as BetGroup,		
				0 as matchid,
				0 as homeid,
				0 as awayid,
				b.bettype,
				0 as liveindicator,
				m.leagueid,
				SUM(case when b.liveawayscore = 0 and b.bettype in(33,43) then ABS(b.stake)/2 else ABS(b.stake) end) as TurnOver,
				--isnull(SUM(stake), 0) as turnover,
				isnull(SUM(CASE WHEN b.tpositiontaking = 1 THEN 0 ELSE scomm/(1 - tpositiontaking) END) , 0) as GrossComm,
				isnull(SUM(winlost - actual_stake), 0) as MemberWinLost,
				isnull(SUM(playercomm), 0) as MemberComm,
				isnull(SUM(Winlost - actual_stake + playercomm), 0) as MemberTotal,
				isnull(SUM(awinlost), 0) as AgentWinLost,
				isnull(SUM(comm - playercomm), 0) AS  AgentComm,
				isnull(SUM(awinlost + comm - playercomm), 0) AS AgentTotal,
				isnull(SUM(mwinlost), 0) as MasterWinLost,
				isnull(SUM(acomm - comm), 0) AS  MasterComm,
				isnull(SUM(mwinlost + acomm - comm), 0) AS MasterTotal,
				isnull(SUM(swinlost), 0) as SAgWinLost,
				isnull(SUM(scomm - acomm), 0) AS  SAgComm,
				isnull(SUM(swinlost), 0) + isnull(SUM(scomm), 0) - isnull(SUM(acomm),0) as SAgTotal,
				isnull(SUM(scomm), 0) as CompanyComm,
				-(isnull(SUM(swinlost), 0) + isnull(SUM(awinlost), 0) + isnull(SUM(mwinlost), 0) + isnull(SUM(scomm), 0) + isnull(SUM(winlost - actual_stake), 0))  as CompanyTotal,
				m.groupmatch as race,	
				'ZZZZ' as matchcode,
				CONVERT(BIT,0) as IsNeutral,
				'' as showtime
			FROM 
				bettrans b WITH (NOLOCK)
				INNER JOIN outright m with (nolock) on m.orid = b.matchid
				INNER JOIN #SportBettype s ON b.bettype = s.Bettype
			WHERE 
				b.srecommend = @custid
				AND b.winlostdate BETWEEN @FDate AND @TDate
				AND s.ProductID IN (1, 2)
				AND s.EventType = 2
				AND b.ruben = 1
				AND b.statusID NOT IN (101, 102, 103)				
			GROUP BY b.bettype, m.groupmatch, m.leagueid
			HAVING ISNULL(COUNT(transid), 0) > 0	
		END 

		IF @showVS = 1 
		BEGIN
			-- Virtual HR		
			INSERT INTO #SAgMatchWLDetails
			SELECT
				0 as BetGroup,
				'' matchid,
				0 as homeid,
				0 as awayid,
				b.bettype,
				0 as liveindicator,
				r.leagueid,
				SUM(ABS(stake)) as turnover,
				SUM(CASE WHEN b.tpositiontaking = 1 THEN 0 ELSE scomm/(1 - tpositiontaking) END) AS GrossComm,
				SUM(winlost - actual_stake) as MemberWinLost,
				SUM(playercomm) as MemberComm,
				SUM(Winlost - actual_stake + playercomm) as MemberTotal,
				SUM(awinlost) as AgentWinLost,
				SUM(comm - playercomm) AS  AgentComm,
				SUM(awinlost + comm - playercomm) AS AgentTotal,
				SUM(mwinlost) as MasterWinLost,
				SUM(acomm - comm) AS  MasterComm,
				SUM(mwinlost + acomm - comm) AS MasterTotal,
				SUM(swinlost) as SAgWinLost,
				SUM(scomm - acomm) AS  SAgComm,
				isnull(SUM(swinlost), 0) + isnull(SUM(scomm), 0)- SUM(acomm) as SAgTotal,
				SUM(scomm) as CompanyComm,
				-(isnull(SUM(swinlost), 0) + isnull(SUM(awinlost), 0) + isnull(SUM(mwinlost), 0) + isnull(SUM(scomm), 0) + isnull(SUM(winlost-actual_stake), 0))  as CompanyTotal,						
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
				b.srecommend = @custid
				AND b.statusID NOT IN (101, 102, 103)
				AND b.winlostdate BETWEEN @FDate AND @TDate
				AND o.eventstatus = 'completed'
				AND isnull(r.betstatus,'') <> 'refund'
				AND s.ProductID = 5
				AND s.EventType = 3				
			GROUP BY 
				r.LeagueID, r.EventTime, r.eventID, b.bettype			
		END	

	END

	IF @fromdate <= @MoveBetsDay
	BEGIN	
		INSERT INTO #RecommendList (recommend)
		SELECT CustId 
		FROM dbo.CustInfo WITH (NOLOCK) 
		WHERE srecommend = @CustId AND RoleId = 2		

		IF @BalanceUpDay < @FromDate
		BEGIN
			SET @FDate = @FromDate;
		END
		ELSE
		BEGIN
			SET @FDate = @BalanceUpDay;
		END
		
		IF @ToDate > @MoveBetsDay
		BEGIN
			SET @TDate = @MoveBetsDay;
		END
		
		IF @showNG = 1 
		BEGIN
			INSERT INTO #SAgMatchWLDetails 
			SELECT
				0 as BetGroup,
				m.matchid,
				m.homeid,
				m.awayid,
				b.bettype,
				b.liveindicator,
				m.leagueid,
				SUM(ABS(stake)) as turnover,
				SUM(CASE WHEN b.tpositiontaking = 1 THEN 0 ELSE scomm/(1 - tpositiontaking) END) AS GrossComm,
				SUM(winlost - actual_stake) as MemberWinLost,
				SUM(playercomm) as MemberComm,
				SUM(Winlost - actual_stake + playercomm) as MemberTotal,
				SUM(awinlost) as AgentWinLost,
				SUM(comm - playercomm) AS  AgentComm,
				SUM(awinlost + comm - playercomm) AS AgentTotal,
				SUM(mwinlost) as MasterWinLost,
				SUM(acomm - comm) AS  MasterComm,
				SUM(mwinlost + acomm - comm) AS MasterTotal,
				SUM(swinlost) as SAgWinLost,
				SUM(scomm - acomm) AS  SAgComm,
				isnull(SUM(swinlost), 0) + isnull(SUM(scomm), 0) - SUM(acomm) as SAgTotal,
				SUM(scomm) as CompanyComm,
				-(isnull(SUM(swinlost), 0) + isnull(SUM(awinlost), 0) + isnull(SUM(mwinlost), 0) + isnull(SUM(scomm), 0) + isnull(SUM(winlost-actual_stake), 0))  as CompanyTotal,
				'' as race,	
				m.matchcode,
				isnull(m.isNeutral, CONVERT(BIT,0)) as IsNeutral,
				'' as showtime
			FROM 
				bettrans14 b WITH (NOLOCK)
				INNER JOIN match14 m WITH (NOLOCK) ON m.matchid = b.matchid
				INNER JOIN #SportBettype s ON b.bettype = s.Bettype		
				INNER JOIN #RecommendList R ON R.recommend = b.recommend
			WHERE 
				b.winlostdate BETWEEN @FDate AND @TDate
				AND m.eventstatus = 'completed'
				AND isnull(m.betstatus,'') <> 'refund'
				AND b.statusID NOT IN (101, 102, 103)
				AND s.ProductID = 3				
			GROUP BY 
				m.matchid, m.homeid, m.awayid, b.bettype, m.leagueid, m.matchcode, m.isNeutral, b.liveindicator


			INSERT INTO #SAgMatchWLDetails 
			SELECT
				4 as BetGroup,
				0 as matchid,
				0 as homeid,
				0 as awayid,
				b.bettype,
				0 as liveindicator,
				0 as leagueid,
				isnull(SUM(ABS(stake)), 0) as turnover,
				isnull(SUM(CASE WHEN b.tpositiontaking = 1 THEN 0 ELSE scomm/(1 - tpositiontaking) END), 0) as GrossComm,
				isnull(SUM(winlost - actual_stake), 0) as MemberWinLost,
				isnull(SUM(playercomm), 0) as MemberComm,
				isnull(SUM(Winlost - actual_stake + playercomm), 0) as MemberTotal,
				isnull(SUM(awinlost), 0) as AgentWinLost,
				isnull(SUM(comm - playercomm), 0) AS  AgentComm,
				isnull(SUM(awinlost + comm - playercomm), 0) AS AgentTotal,
				isnull(SUM(mwinlost), 0) as MasterWinLost,
				isnull(SUM(acomm - comm), 0) AS  MasterComm,
				isnull(SUM(mwinlost + acomm - comm), 0) AS MasterTotal,
				isnull(SUM(swinlost), 0) as SAgWinLost,
				isnull(SUM(scomm - acomm), 0) AS  SAgComm,
				isnull(SUM(swinlost), 0) + isnull(SUM(scomm), 0) - isnull(SUM(acomm), 0) as SAgTotal,
				isnull(SUM(scomm), 0) as CompanyComm,
				-(isnull(SUM(swinlost), 0) + isnull(SUM(awinlost), 0) + isnull(SUM(mwinlost), 0) + isnull(SUM(scomm), 0) + isnull(SUM(winlost-actual_stake), 0))  as CompanyTotal,
				'' as race,	
				'' as matchcode,
				CONVERT(BIT, 0) as IsNeutral,
				'' as showtime
			FROM
				bettrans14 b WITH (NOLOCK)
				INNER JOIN #SportBettype s ON s.Bettype = b.bettype
				INNER JOIN #RecommendList R ON R.recommend = b.recommend
			WHERE 
				b.winlostdate BETWEEN @FDate AND @TDate
				AND b.ruben = 1
				AND b.statusID NOT IN (101, 102, 103)
				AND s.ProductID = 3
				AND s.EventType <> 1
				
			GROUP BY b.bettype		
			HAVING ISNULL(COUNT(transid),0) > 0

			END 
		
		--- Not number Game not group by liveindicator
		IF (@ShowSB = 1 OR @showLiveCasino = 1 OR @showVS = 1 OR @showLK3 = 1)
		BEGIN
			INSERT INTO #SAgMatchWLDetails		
			SELECT
				0 as BetGroup,
				m.matchid,
				m.homeid,
				m.awayid,
				CASE WHEN ISNULL(f.bettype, 0) = 0 THEN b.bettype ELSE f.GroupTypeId END AS bettype,
				0 as liveindicator,
				m.leagueid,
				SUM(ABS(stake)) as turnover,
				SUM(CASE WHEN b.tpositiontaking = 1 THEN 0 ELSE scomm/(1 - tpositiontaking) END) AS GrossComm,
				SUM(winlost - actual_stake) as MemberWinLost,
				SUM(playercomm) as MemberComm,
				SUM(Winlost - actual_stake + playercomm) as MemberTotal,
				SUM(awinlost) as AgentWinLost,
				SUM(comm - playercomm) AS  AgentComm,
				SUM(awinlost + comm - playercomm) AS AgentTotal,
				SUM(mwinlost) as MasterWinLost,
				SUM(acomm - comm) AS  MasterComm,
				SUM(mwinlost + acomm - comm) AS MasterTotal,
				SUM(swinlost) as SAgWinLost,
				SUM(scomm - acomm) AS  SAgComm,
				isnull(SUM(swinlost), 0) + isnull(SUM(scomm), 0) - SUM(acomm) as SAgTotal,
				SUM(scomm) as CompanyComm,
				-(isnull(SUM(swinlost), 0) + isnull(SUM(awinlost), 0) + isnull(SUM(mwinlost), 0) + isnull(SUM(scomm), 0) + isnull(SUM(winlost-actual_stake), 0))  as CompanyTotal,
				'' as race,	
				m.matchcode,
				isnull(m.isNeutral, CONVERT(BIT, 0)) as IsNeutral,
				ISNULL(m.showtime, '') as showtime
			FROM 
				bettrans14 b WITH (NOLOCK)
				INNER JOIN match14 m WITH (NOLOCK) ON m.matchid = b.matchid 	
				LEFT JOIN (SELECT * FROM [dbo].[f_GroupBettype]()) f ON f.bettype = b.bettype
				INNER JOIN #SportBettype s ON b.bettype = s.Bettype
				INNER JOIN #RecommendList R ON R.recommend = b.recommend			
			WHERE 
				b.winlostdate BETWEEN @FDate AND @TDate
				AND m.eventstatus = 'completed'
				AND isnull(m.betstatus,'') <> 'refund'
				AND b.bettype < 19001 
				AND b.bettype NOT IN (9,29,10)
				AND b.statusID NOT IN (101, 102, 103)
				AND s.ProductID IN(1, 4, 5, 26)
				AND s.EventType <> 3				
			GROUP BY 
				m.matchid, m.homeid, m.awayid, m.leagueid, m.matchcode, m.isNeutral,showtime,
				CASE WHEN ISNULL(f.bettype,0) = 0 THEN b.bettype ELSE f.GroupTypeId END
		END 

		-- Mix parlay(14)
		IF @showSB = 1 
		BEGIN
			INSERT INTO #SAgMatchWLDetails 
			SELECT
				3 as BetGroup,
				0 as matchid,
				0 as homeid,
				0 as awayid,
				b.bettype,
				0 as liveindicator,
				0 as leagueid,
				isnull(SUM(ABS(stake)), 0) as turnover,
				isnull(SUM(CASE WHEN b.tpositiontaking = 1 THEN 0 ELSE scomm/(1 - tpositiontaking) END), 0) as GrossComm,
				isnull(SUM(winlost - actual_stake), 0) as MemberWinLost,
				isnull(SUM(playercomm), 0) as MemberComm,
				isnull(SUM(Winlost - actual_stake + playercomm), 0) as MemberTotal,
				isnull(SUM(awinlost), 0) as AgentWinLost,
				isnull(SUM(comm - playercomm), 0) AS  AgentComm,
				isnull(SUM(awinlost + comm - playercomm), 0) AS AgentTotal,
				isnull(SUM(mwinlost), 0) as MasterWinLost,
				isnull(SUM(acomm - comm), 0) AS  MasterComm,
				isnull(SUM(mwinlost + acomm - comm), 0) AS MasterTotal,
				isnull(SUM(swinlost), 0) as SAgWinLost,
				isnull(SUM(scomm - acomm), 0) AS  SAgComm,
				isnull(SUM(swinlost), 0) + isnull(SUM(scomm), 0) - isnull(SUM(acomm), 0) as SAgTotal,
				isnull(SUM(scomm), 0) as CompanyComm,
				-(isnull(SUM(swinlost), 0) + isnull(SUM(awinlost), 0) + isnull(SUM(mwinlost), 0) + isnull(SUM(scomm), 0) + isnull(SUM(winlost-actual_stake), 0))  as CompanyTotal,
				'' as race,	
				'' as matchcode,
				CONVERT(BIT, 0) as IsNeutral,
				'' as showtime
			FROM
				bettrans14 b WITH (NOLOCK)
				INNER JOIN #RecommendList R ON R.recommend = b.recommend
			WHERE 
				b.bettype IN (9, 29)
				AND b.winlostdate BETWEEN @FDate AND @TDate
				AND b.ruben = 1
				AND b.statusID NOT IN (101, 102, 103)
				
			GROUP BY b.bettype		
			HAVING ISNULL(COUNT(transid),0) > 0
		END
		
		---Outright, RB
		IF (@showSB = 1 OR @showRB = 1)
		BEGIN
			INSERT INTO #SAgMatchWLDetails 
			SELECT
				(case b.bettype when 10 then 2 else 1 end) as BetGroup,		
				0 as matchid,
				0 as homeid,
				0 as awayid,
				b.bettype,
				0 as liveindicator,
				m.leagueid,
				--isnull(SUM(stake), 0) as turnover,
				SUM(case when b.liveawayscore = 0 AND b.bettype IN(33,43) then ABS(b.stake)/2 else ABS(b.stake) end) as TurnOver,
				isnull(SUM(CASE WHEN b.tpositiontaking = 1 THEN 0 ELSE scomm/(1 - tpositiontaking) END), 0) as GrossComm,
				isnull(SUM(winlost - actual_stake), 0) as MemberWinLost,
				isnull(SUM(playercomm), 0) as MemberComm,
				isnull(SUM(Winlost - actual_stake + playercomm), 0) as MemberTotal,
				isnull(SUM(awinlost), 0) as AgentWinLost,
				isnull(SUM(comm - playercomm), 0) AS  AgentComm,
				isnull(SUM(awinlost + comm - playercomm), 0) AS AgentTotal,
				isnull(SUM(mwinlost), 0) as MasterWinLost,
				isnull(SUM(acomm - comm), 0) AS  MasterComm,
				isnull(SUM(mwinlost + acomm - comm), 0) AS MasterTotal,
				isnull(SUM(swinlost), 0) as SAgWinLost,
				isnull(SUM(scomm - acomm), 0) AS  SAgComm,
				isnull(SUM(swinlost), 0) + isnull(SUM(scomm), 0) - isnull(SUM(acomm),0) as SAgTotal,
				isnull(SUM(scomm), 0) as CompanyComm,
				-(isnull(SUM(swinlost), 0) + isnull(SUM(awinlost), 0) + isnull(SUM(mwinlost), 0) + isnull(SUM(scomm), 0) + isnull(SUM(winlost - actual_stake), 0))  as CompanyTotal,
				m.groupmatch as race,		
				'ZZZZ' as matchcode,
				CONVERT(BIT,0) as IsNeutral,
				'' as showtime
			FROM 
				bettrans14 b WITH (NOLOCK)---, index= bettrans143)			
				inner join outright14 m with (nolock) on m.orid = b.matchid
				INNER JOIN #SportBettype s ON b.bettype = s.Bettype
				INNER JOIN #RecommendList R ON R.recommend = b.recommend
			WHERE 
				b.winlostdate BETWEEN @FDate AND @TDate
				AND s.ProductID IN (1, 2)
				AND s.EventType = 2
				AND b.ruben=1
				AND b.statusID not in (101, 102, 103)				
			GROUP BY b.bettype, m.groupmatch, m.leagueid
			HAVING ISNULL(COUNT(transid),0) > 0	
		END
		
		IF @showVS = 1 
		BEGIN
			-- Virtual HR		
			INSERT INTO #SAgMatchWLDetails
			SELECT
				0 as BetGroup,
				'' matchid,
				0 as homeid,
				0 as awayid,
				b.bettype,
				0 as liveindicator,
				r.leagueid,
				SUM(ABS(stake)) as turnover,
				SUM(CASE WHEN b.tpositiontaking = 1 THEN 0 ELSE scomm/(1 - tpositiontaking) END) AS GrossComm,
				SUM(winlost - actual_stake) as MemberWinLost,
				SUM(playercomm) as MemberComm,
				SUM(Winlost - actual_stake + playercomm) as MemberTotal,
				SUM(awinlost) as AgentWinLost,
				SUM(comm - playercomm) AS  AgentComm,
				SUM(awinlost + comm - playercomm) AS AgentTotal,
				SUM(mwinlost) as MasterWinLost,
				SUM(acomm - comm) AS  MasterComm,
				SUM(mwinlost + acomm - comm) AS MasterTotal,
				SUM(swinlost) as SAgWinLost,
				SUM(scomm - acomm) AS  SAgComm,
				isnull(SUM(swinlost), 0) + isnull(SUM(scomm), 0)-SUM(acomm) as SAgTotal,
				SUM(scomm) as CompanyComm,
				-(isnull(SUM(swinlost), 0) + isnull(SUM(awinlost), 0) + isnull(SUM(mwinlost), 0) + isnull(SUM(scomm), 0) + isnull(SUM(winlost - actual_stake), 0))  as CompanyTotal,						
				r.EventID as Race,
				r.EventTime matchcode,
				CONVERT (BIT, 0) AS IsNeutral,
				'' as showtime
			FROM 
				bettrans14 b WITH (NOLOCK)
				INNER JOIN VSOutright14 o WITH (NOLOCK) ON b.oddsid = o.Orid
				INNER JOIN VSRaceInfo14 r WITH (NOLOCK) ON r.EventID = o.EventID
				INNER JOIN #SportBettype s ON b.bettype = s.Bettype
				INNER JOIN #RecommendList Re ON Re.recommend = b.recommend
			WHERE 
				b.statusID NOT IN (101, 102, 103)
				AND b.winlostdate BETWEEN @FDate AND @TDate
				AND o.eventstatus = 'completed' 
				AND isnull(r.betstatus,'') <> 'refund'
				AND s.ProductID = 5
				AND s.EventType = 3					
			GROUP BY 
				r.LeagueID, r.EventTime, r.eventID, b.bettype
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
		SUM(SAgWinLost) as SAgWinLost, 
		SUM(SAgComm) as SAgComm, 
		SUM(SAgTotal) as SAgTotal, 
		SUM(CompanyComm) as CompanyComm, 
		SUM(CompanyTotal) as CompanyTotal, 
		race,
		matchcode,	
		isNeutral,
		showtime
	FROM #SAgMatchWLDetails
	GROUP BY BetGroup, matchid, homeid, awayid, bettype, liveindicator, leagueid, race, matchcode, isNeutral, showtime
	ORDER BY betgroup, matchid, leagueid, race, bettype, liveindicator, matchcode

	DROP TABLE #RecommendList
	DROP TABLE #SAgMatchWLDetails
	DROP TABLE #SportBettype
END
GO