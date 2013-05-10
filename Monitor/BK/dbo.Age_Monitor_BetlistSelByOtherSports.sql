 USE [bodb02]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[Age_Monitor_BetlistSelByOtherSports]
    @custid             INT,
    @Bettypegroup       TINYINT = 0,
    @leagueid           NVARCHAR(4000) = '',
    @transid            BIGINT = 0,
    @Language           VARCHAR(2) = 'E',
    @LimitRowCount      INT = 10,
    @winlostdate        SMALLDATETIME
AS
BEGIN
/*	
	Created	: Don
	Date: 02/03/2011
	DB: DB05.BODB02
	Revision:
	    - 20110302@Don: - Get data related to other sports
	    - 20111229@Jim: remove function : f_ShowOddsByBettype,f_GetChoice 
		
	Parameter's Explanation:
		- @custid : Agent ID
		- @bettypegroup : 0: bettype < 99, 1: bettype in (1,7), 3: bettype in (3,8), 99: bettype < 99 AND not in (1,3,7,8)
*/
	SET NOCOUNT ON
	
	DECLARE @roleid int
	SELECT @roleid = roleid FROM customer WITH(NOLOCK) WHERE custid = @custid 		
	
	--- Declare table variables ---
	DECLARE @BetList TABLE(
		sporttype	smallint,
		username	nvarchar(30),
		leagueID		int,
		bettype		smallint,
		transid		bigint,
		refno		bigint,
		transdate	datetime,
		matchcode	nvarchar(50),
		homeID		int,
		awayID		int,
		race		varchar(20),
		betid		int,
		livehomescore	smallint,
		liveawayscore	smallint,
		liveindicator	bit,
		hdp1		smallmoney,
		hdp2		smallmoney,
		odds		smallmoney,
		stake		money,
		status		nvarchar(10),
		betteam		nvarchar(20),				
		IP			varchar(20),
		isNeutral	bit,
		oddstype	tinyint					
	)
    DECLARE @tmpMatch TABLE (

		matchID		INT PRIMARY KEY,
		leagueID	INT,
		sporttype	INT,
		matchcode	VARCHAR(50),
		homeID		INT,
		awayID		INT,
		isNeutral	BIT 
	)
	DECLARE	@tmpOutright TABLE(
			orid INT,
			leagueID INT,
			sporttype INT,
			groupmatch varchar(50),
			matchcode  VARCHAR(50),
			teamID	 INT
	)
	DECLARE @BettypeGroupTbl TABLE(
		bettypeGroup	tinyint,
		bettype2        smallint
	)
	DECLARE @LeagueInput TABLE(
		leagueID	int
	)
	--- End of      Declare table variables ---
	
	INSERT INTO @tmpMatch(matchID, leagueID, sporttype, matchcode, homeID, awayID, isNeutral)
        SELECT	m.matchID, 
		        m.leagueID,
		        m.sporttype,
		        m.matchcode,
		        m.homeID,
		        m.awayID,
		        m.isNeutral
        FROM	match m WITH(NOLOCK) 
        WHERE	eventstatus<>N'completed'
		        and eventdate>=@winlostdate
		        and m.sporttype <> 1

    INSERT INTO	@tmpOutright( orid,leagueID, sporttype, groupmatch,matchcode, teamID)
        SELECT	o.orid, o.leagueID, l.sporttype, o.groupmatch,o.matchcode,o.teamID
        FROM	outright o WITH (NOLOCK) 
		        INNER JOIN league l WITH (NOLOCK) on o.leagueid = l.leagueid 
        WHERE	o.oddsstatus<>'completed'
		        and o.eventdate>=@winlostdate
		        and l.sporttype <> 1
	
	INSERT INTO @BettypeGroupTbl(bettypeGroup,bettype2)
	SELECT bettypegroup.bettypeGroup, bettypegroup.bettype
	FROM
	    (
	        SELECT 0 bettypeGroup, typeid bettype
	        FROM bettype WITH(NOLOCK)
	        UNION
	        SELECT 1 bettypeGroup, 1 bettype
	        UNION
	        SELECT 1 bettypeGroup, 7 bettype
	        UNION
	        SELECT 3 bettypeGroup, 3 bettype
	        UNION
	        SELECT 3 bettypeGroup, 8 bettype
	        UNION
	        SELECT 99 bettypeGroup, 1 bettype
	        UNION
	        SELECT 99 bettypeGroup, 3 bettype
	        UNION
	        SELECT 99 bettypeGroup, 7 bettype
	        UNION
	        SELECT 99 bettypeGroup, 8 bettype
	    ) bettypegroup
	
	INSERT INTO @LeagueInput
	SELECT CONVERT(int ,val) FROM dbo.strSplit(@leagueid,',')
	
	IF(@roleid = 2)
	BEGIN
		--Single Bet
		INSERT INTO @BetList
		SELECT TOP(@LimitRowCount) m.sporttype,
			b.username,
			m.leagueID,
			b.bettype,
			b.transid,
			b.refno,
			b.transdate,
			m.matchcode,
			m.homeid,
			m.awayid,
			'' as race,
			b.betid as betid,
			b.livehomescore ,
			b.liveawayscore,
			b.liveindicator,
			b.hdp1,
			b.hdp2,
			b.odds,
			b.stake,		
			b.status,
			b.betteam,		
			IP as IP,
			isnull(m.isNeutral,CONVERT(BIT,0)) as isNeutral,
			b.OddsType
		FROM	
            bettrans b WITH(NOLOCK)
			INNER JOIN @tmpMatch m ON b.matchid = m.matchid	
			INNER JOIN @BettypeGroupTbl bg ON bettypeGroup = @Bettypegroup AND b.bettype = bg.bettype2
		WHERE
			b.recommend = @custid AND
			b.transid > @transid AND
			b.statusid BETWEEN 0 AND 1 AND
			winlostdate >= @winlostdate /*AND
			(@leagueid = '' OR m.leagueID IN (SELECT leagueid FROM @LeagueInput))*/
        ORDER BY b.transid DESC

		IF(@bettypegroup = 0 OR @bettypegroup = 99)
		BEGIN		
			--MixParlay
			INSERT INTO @BetList
			SELECT distinct TOP(@LimitRowCount) 
				0 as sporttype,
				b.username,
				0 as leagueID,
				b.bettype,
				b.transid,
				b.refno,
				b.transdate,
				'' as matchcode,
				0 as homeID,
				0 as awayID,
				'' as race,
				0 as betid,
				0 as livehomescore,
				0 as liveawayscore,
				0 as liveindicator,
				'' as hdp1,
				'' as hdp2,
				b.odds,
				b.stake,
				b.status,
				b.betteam,
				--dbo.f_GetChoice(b.betteam,b.bettype,@Language) betteam,
				b.IP as IP,
				CONVERT(BIT,0) as isNeutral,
				b.oddstype
				--case dbo.f_ShowOddsByBettype(b.bettype,1) when 1 then b.OddsType else 0 end as OddsType
			FROM	
			    (
				    SELECT 
					    username,bettype,transid,refno,transdate,odds,stake,status,betteam,IP,oddstype
				    FROM bettrans WITH(NOLOCK)
				    WHERE 
					    recommend = @custid AND
					    transid > @transid AND
					    (statusid BETWEEN 0 AND 1) AND
					    matchid = 9 AND
					    bettype = 9 AND
					    winlostdate >= @winlostdate 
			    ) b
				INNER JOIN bettransm bm WITH(NOLOCK) ON bm.refno = b.refno				
				INNER JOIN @tmpMatch m ON bm.matchid = m.matchid
			/*WHERE @leagueid = '' OR m.leagueID IN (SELECT leagueid FROM @LeagueInput)*/
			ORDER BY b.transid DESC

			--Outright,HR
			INSERT INTO @BetList
			SELECT TOP(@LimitRowCount) m.sporttype as sporttype,
				b.username,
				m.leagueid,
				b.bettype,
				b.transid,
				b.refno,
				b.transdate,
				m.matchcode,
				m.teamID as homeID,
				0 as awayID,				
				isNull(m.groupmatch,'') as race,
				0 as betid,
				b.livehomescore,
				b.liveawayscore,
				b.liveindicator,
				b.hdp1,
				b.hdp2,
				b.odds,
				b.stake,
				b.status,
				b.betteam, 
				--dbo.f_GetChoice(b.betteam,b.bettype,@Language) betteam,		
				IP as IP,
				CONVERT(BIT,0) as isNeutral,
				0 as oddstype
			FROM	
                bettrans b WITH(NOLOCK)
				INNER JOIN @tmpOutright m ON b.matchid = m.orid
			WHERE
				b.recommend = @custid AND
				b.transid > @transid AND
				(b.statusid BETWEEN 0 AND 1) AND
				b.bettype = 10 AND
				b.winlostdate >= @winlostdate /*AND
				(@leagueid = '' OR m.leagueID IN (SELECT leagueid FROM @LeagueInput))*/
			ORDER BY b.transid DESC
		END -- End of IF(@bettypegroup = 0 OR @bettypegroup = 99)
	END	-- End of IF(@roleid = 2)
	
	SELECT TOP(@LimitRowCount)
		b.sporttype,
		b.username,
		b.leagueID,
		b.bettype,
		b.transid,
		b.refno,
		b.transdate,
		b.matchcode,
		b.homeid,
		b.awayid,
		b.race,
		b.betid,
		b.livehomescore,
		b.liveawayscore,
		b.liveindicator,
		b.hdp1,
		b.hdp2,
		b.odds,
		b.stake,		
		b.status,
		b.betteam,		
		b.IP,
		b.isNeutral,
		b.OddsType
	FROM @BetList b
	
	--get data from bettransm for bettype 33,43
	IF EXISTS (SELECT distinct 1 FROM @BetList WHERE bettype IN (33,43))
	BEGIN
		SELECT 
			b.sporttype,
			b.username,
			b.leagueID,
			bm.bettype,
			bm.transid,
			bm.refno,
			bm.transdate,
			b.matchcode,
			b.homeid,
			b.awayid,
			b.race,
			bm.livehomescore,
			bm.liveawayscore,
			bm.liveindicator,
			bm.hdp1,
			bm.hdp2,
			bm.odds,
			bm.stake,		
			bm.status,
			bm.betteam,		
			IP as IP,
			b.isNeutral,
			b.OddsType
		FROM bettransm bm WITH (NOLOCK)
		INNER JOIN @BetList b ON  bm.refno = b.transid 
		WHERE b.bettype IN (33,43)
	END
END -- End of SP


GO
GRANT EXECUTE ON [dbo].[Age_Monitor_BetlistSelByOtherSports] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_Monitor_BetlistSelByOtherSports] TO [bodbDownlineNetView]
GO
GRANT VIEW DEFINITION ON [dbo].[Age_Monitor_BetlistSelByOtherSports] TO [vnteam]