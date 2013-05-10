USE [bodb02]
GO
/****** Object:  StoredProcedure [dbo].[Age_Monitor_BetlistSel]    Script Date: 02/10/2011 05:50:36 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[Age_Monitor_BetlistSel]
 @custid	INT,
 @sporttypegroup tinyint = 0,
 @Bettypegroup	tinyint = 0,
 @leagueid	NVARCHAR(4000) = '',  
 @transid bigint,
 @Language	VARCHAR(2) = 'E',
 @LimitRowCount int = 20 
WITH RECOMPILE
AS
BEGIN
/*	
	Created	: Johnson
	Date: 26/10/2010
	DB: DB05.BODB02
	Revision:
		- 20110121@Johnson: add column betid into bet list for select number game
		- 20110209@Simon: Add Filter transid > @transid.
		- 20110210@Jamie: Remove join in Customer and League 
		- 20110225@Don: Use derived table to improve performance 
		- 20110411@Amy: Change function to get Odds value and showed odds type
		- 20111229@Jim: remove function : f_GetOddsByBettype,f_ShowOddsByBettype,f_GetChoice
	Parameter's Explanation:
		- @custid : Agent ID
		- @Sporttypegroup: 0: all, 1: soccer, 99: others
		- @bettypegroup : 0: bettype < 99, 1: bettype in (1,7), 3: bettype in (3,8), 99: bettype < 99 AND not in (1,3,7,8)		
*/
	SET NOCOUNT ON
	
	DECLARE @roleid int
	
	SELECT @roleid = roleid FROM customer WITH(NOLOCK) WHERE custid = @custid 		
	
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
	
	DECLARE @LeagueInput TABLE(
		leagueID	int
	)
	
	DECLARE @BettypeGroupTbl TABLE(
		bettypeGroup	tinyint,
		bettype2        smallint
	)
	
	IF @leagueid like '' 
	    SET @leagueid = '0,'
	
	INSERT INTO @LeagueInput
	SELECT CONVERT(int ,val) FROM dbo.strSplit(@leagueid,',')
	
	INSERT INTO @BettypeGroupTbl(bettypeGroup,bettype2)
	SELECT 0, typeid
	FROM bettype WITH(NOLOCK)
	
	INSERT INTO @BettypeGroupTbl(bettypeGroup,bettype2)
	SELECT bettypegroup.bettypeGroup, bettypegroup.bettype
	FROM
	    (
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
	
	IF(@roleid = 4)
	BEGIN
		IF @sporttypegroup =0 -- get all sports
		BEGIN
			--Single Bet
			INSERT INTO @BetList
			SELECT m.sporttype,
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
				b.livehomescore,
				b.liveawayscore,
				b.liveindicator,
				b.hdp1,
				b.hdp2,
				b.odds,
				--dbo.f_GetOddsByBettype(b.odds,b.bettype,b.oddstype) as odds,
				b.stake,		
				b.status,
				b.betteam,
				--dbo.f_GetChoice(b.betteam,b.bettype,@Language) betteam,		
				IP as IP,
				ISNULL(m.isNeutral,CONVERT(BIT,0)) as isNeutral,b.oddstype
				--dbo.f_ShowOddsByBettype(b.bettype,b.oddstype) as OddsType 
			FROM	
                (
                    SELECT TOP(@LimitRowCount)
                        username,bettype,transid,refno,transdate,matchid,betid,livehomescore,liveawayscore,liveindicator,hdp1,hdp2,odds,stake,status,betteam,IP,oddstype
                    FROM bettrans WITH(NOLOCK)
                    WHERE 
                        srecommend = @custid AND
                        transid > @transid AND
                        statusid BETWEEN 0 AND 1
                ) b
				INNER JOIN match m WITH(NOLOCK) ON b.matchid = m.matchid	
				INNER JOIN @LeagueInput li ON m.leagueid = li.leagueid
				INNER JOIN @BettypeGroupTbl bg ON bettypeGroup = @Bettypegroup AND b.bettype = bg.bettype2
	
			IF(@bettypegroup = 0 OR @bettypegroup = 99) 	
			BEGIN		
				--MixParlay
				INSERT INTO @BetList
				SELECT distinct 
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
					IP as IP,
					CONVERT(BIT,0) as isNeutral,
					0 as oddstype 
				FROM	
				    (
                        SELECT TOP(@LimitRowCount)
                            username,bettype,transid,refno,transdate,matchid,betid,livehomescore,liveawayscore,liveindicator,hdp1,hdp2,odds,stake,status,betteam,IP,oddstype
                        FROM bettrans WITH(NOLOCK)
                        WHERE 
                            srecommend = @custid AND
                            transid > @transid AND
                            (statusid BETWEEN 0 AND 1) AND
						    matchid = 9 AND
						    bettype = 9
                    ) b
					INNER JOIN bettransm bm WITH(NOLOCK) ON bm.refno = b.refno				
					INNER JOIN match m WITH(NOLOCK) ON bm.matchid = m.matchid
					INNER JOIN @LeagueInput li ON m.leagueid = li.leagueid

				--Outright,HR
				INSERT INTO @BetList
				SELECT l.sporttype as sporttype,
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
				    (
                        SELECT TOP(@LimitRowCount)
                            username,bettype,transid,refno,transdate,matchid,betid,livehomescore,liveawayscore,liveindicator,hdp1,hdp2,odds,stake,status,betteam,IP,oddstype
                        FROM bettrans WITH(NOLOCK)
                        WHERE 
                            srecommend = @custid AND
                            transid > @transid AND
                            (statusid BETWEEN 0 AND 1) AND
						    bettype = 10
                    ) b
					INNER JOIN outright m WITH(NOLOCK) ON b.matchid = m.orid
					INNER JOIN league l WITH(NOLOCK) ON m.leagueid = l.leagueid
					INNER JOIN @LeagueInput li ON m.leagueid = li.leagueid
			END
		END
		ELSE IF @sporttypegroup =1 -- soccer
		BEGIN
			--Single Bet
			INSERT INTO @BetList
			SELECT m.sporttype,
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
				0 as betid,
				b.livehomescore,
				b.liveawayscore,
				b.liveindicator,
				b.hdp1,
				b.hdp2,
				b.odds,
				--dbo.f_GetOddsByBettype(b.odds,b.bettype,b.oddstype) as odds,
				b.stake,		
				b.status,
				b.betteam,
				--dbo.f_GetChoice(b.betteam,b.bettype,@Language) betteam,		
				IP as IP,
				isnull(m.isNeutral,CONVERT(BIT,0)) as isNeutral,b.oddstype
				--dbo.f_ShowOddsByBettype(b.bettype,b.oddstype) as OddsType 
			FROM	
			    (
                    SELECT TOP(@LimitRowCount)
                        username,bettype,transid,refno,transdate,matchid,betid,livehomescore,liveawayscore,liveindicator,hdp1,hdp2,odds,stake,status,betteam,IP,oddstype
                    FROM bettrans WITH(NOLOCK)
                    WHERE 
                        srecommend = @custid AND
                        transid > @transid AND
                        statusid BETWEEN 0 AND 1
                ) b
				INNER JOIN match m WITH(NOLOCK) ON b.matchid= m.matchid		
				INNER JOIN @LeagueInput li ON m.leagueid = li.leagueid
				INNER JOIN @BettypeGroupTbl bg ON bettypeGroup = @Bettypegroup AND b.bettype = bg.bettype2
			WHERE
				m.sporttype = 1 
			
			IF(@bettypegroup = 0 OR @bettypegroup = 99) 	
			BEGIN
				--MixParlay
				INSERT INTO @BetList
				SELECT distinct 
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
					IP as IP,
					CONVERT(BIT,0) as isNeutral,
					0 as oddstype
				FROM	
				    (
                        SELECT TOP(@LimitRowCount)
                            username,bettype,transid,refno,transdate,matchid,betid,livehomescore,liveawayscore,liveindicator,hdp1,hdp2,odds,stake,status,betteam,IP,oddstype
                        FROM bettrans WITH(NOLOCK)
                        WHERE 
                            srecommend = @custid AND
                            transid > @transid AND
                            (statusid BETWEEN 0 AND 1) AND
						    matchid = 9 AND
						    bettype = 9
                    ) b
					INNER JOIN bettransm bm WITH(NOLOCK) ON bm.refno = b.refno				
					INNER JOIN match m WITH(NOLOCK) ON bm.matchid = m.matchid
					INNER JOIN @LeagueInput li ON m.leagueid = li.leagueid
				WHERE
					m.sporttype = 1 
					
				--Outright,HR
				INSERT INTO @BetList
				SELECT l.sporttype as sporttype,
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
				    (
                        SELECT TOP(@LimitRowCount)
                            username,bettype,transid,refno,transdate,matchid,betid,livehomescore,liveawayscore,liveindicator,hdp1,hdp2,odds,stake,status,betteam,IP,oddstype
                        FROM bettrans WITH(NOLOCK)
                        WHERE 
                            srecommend = @custid AND
                            transid > @transid AND
                            (statusid BETWEEN 0 AND 1) AND
						    bettype = 10
                    ) b
					INNER JOIN outright m WITH(NOLOCK) ON b.matchid = m.orid
                    INNER JOIN league l WITH(NOLOCK) ON m.leagueid = l.leagueid
					INNER JOIN @LeagueInput li ON m.leagueid = li.leagueid
				WHERE
					l.sporttype = 1
			END
		END
		ELSE -- others		
		BEGIN
			--Single Bet
			INSERT INTO @BetList
			SELECT m.sporttype,
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
				b.livehomescore,
				b.liveawayscore,
				b.liveindicator,
				b.hdp1,
				b.hdp2,
				b.odds,
				--dbo.f_GetOddsByBettype(b.odds,b.bettype,b.oddstype) as odds,
				b.stake,		
				b.status,
				b.betteam,
				--dbo.f_GetChoice(b.betteam,b.bettype,@Language) betteam,		
				IP as IP,
				isnull(m.isNeutral,CONVERT(BIT,0)) as isNeutral,
				b.oddstype
				--dbo.f_ShowOddsByBettype(b.bettype,b.oddstype) as OddsType 
			FROM	
			    (
                    SELECT TOP(@LimitRowCount)
                        username,bettype,transid,refno,transdate,matchid,betid,livehomescore,liveawayscore,liveindicator,hdp1,hdp2,odds,stake,status,betteam,IP,oddstype
                    FROM bettrans WITH(NOLOCK)
                    WHERE 
                        srecommend = @custid AND
                        transid > @transid AND
                        statusid BETWEEN 0 AND 1
                ) b
				INNER JOIN match m WITH(NOLOCK) ON b.matchid= m.matchid			
				INNER JOIN @LeagueInput li ON m.leagueid = li.leagueid
				INNER JOIN @BettypeGroupTbl bg ON bettypeGroup = @Bettypegroup AND b.bettype = bg.bettype2
			WHERE
				m.sporttype <> 1 

			IF(@bettypegroup = 0 OR @bettypegroup = 99) 	
			BEGIN			
				--MixParlay
				INSERT INTO @BetList
				SELECT distinct 
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
					IP as IP,
					CONVERT(BIT,0) as isNeutral,
					0 as oddstype
				FROM	
				    (
                        SELECT TOP(@LimitRowCount)
                            username,bettype,transid,refno,transdate,matchid,betid,livehomescore,liveawayscore,liveindicator,hdp1,hdp2,odds,stake,status,betteam,IP,oddstype
                        FROM bettrans WITH(NOLOCK)
                        WHERE 
                            srecommend = @custid AND
                            transid > @transid AND
                            (statusid BETWEEN 0 AND 1) AND
						    matchid = 9 AND
						    bettype = 9
                    ) b
					INNER JOIN bettransm bm WITH(NOLOCK) ON bm.refno = b.refno				
					INNER JOIN match m WITH(NOLOCK) ON bm.matchid = m.matchid
					INNER JOIN @LeagueInput li ON m.leagueid = li.leagueid
				WHERE
					m.sporttype <> 1 

				--Outright,HR
				INSERT INTO @BetList
				SELECT l.sporttype as sporttype,
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
				    (
                        SELECT TOP(@LimitRowCount)
                            username,bettype,transid,refno,transdate,matchid,betid,livehomescore,liveawayscore,liveindicator,hdp1,hdp2,odds,stake,status,betteam,IP,oddstype
                        FROM bettrans WITH(NOLOCK)
                        WHERE 
                            srecommend = @custid AND
                            transid > @transid AND
                            (statusid BETWEEN 0 AND 1) AND
						    bettype = 10
                    ) b
					INNER JOIN outright m WITH(NOLOCK) ON b.matchid = m.orid
					INNER JOIN league l WITH(NOLOCK) ON m.leagueid = l.leagueid
					INNER JOIN @LeagueInput li ON m.leagueid = li.leagueid
				WHERE 
					l.sporttype <> 1 
			END
		END
	END	
	ELSE IF(@roleid = 3)
	BEGIN
		IF @sporttypegroup =0 -- get all sports
		BEGIN
			--Single Bet
			INSERT INTO @BetList
			SELECT m.sporttype,
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
				b.livehomescore,
				b.liveawayscore,
				b.liveindicator,
				b.hdp1,
				b.hdp2,
				b.odds,
				--dbo.f_GetOddsByBettype(b.odds,b.bettype,b.oddstype) as odds,
				b.stake,		
				b.status,
				b.betteam,
				--dbo.f_GetChoice(b.betteam,b.bettype,@Language) betteam,		
				IP as IP,
				isnull(m.isNeutral,CONVERT(BIT,0)) as isNeutral,b.oddstype
				--dbo.f_ShowOddsByBettype(b.bettype,b.oddstype) as OddsType 
			FROM	
                (
                    SELECT TOP(@LimitRowCount)
                        username,bettype,transid,refno,transdate,matchid,betid,livehomescore,liveawayscore,liveindicator,hdp1,hdp2,odds,stake,status,betteam,IP,oddstype
                    FROM bettrans WITH(NOLOCK)
                    WHERE 
                        mrecommend = @custid AND
                        transid > @transid AND
                        statusid BETWEEN 0 AND 1
                ) b
				INNER JOIN match m WITH(NOLOCK) ON b.matchid = m.matchid	
				INNER JOIN @LeagueInput li ON m.leagueid = li.leagueid
				INNER JOIN @BettypeGroupTbl bg ON bettypeGroup = @Bettypegroup AND b.bettype = bg.bettype2

			IF(@bettypegroup = 0 OR @bettypegroup = 99) 	
			BEGIN		
				--MixParlay
				INSERT INTO @BetList
				SELECT distinct 
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
					IP as IP,
					CONVERT(BIT,0) as isNeutral,
					0 as oddstype
				FROM	
				    (
                        SELECT TOP(@LimitRowCount)
                            username,bettype,transid,refno,transdate,matchid,betid,livehomescore,liveawayscore,liveindicator,hdp1,hdp2,odds,stake,status,betteam,IP,oddstype
                        FROM bettrans WITH(NOLOCK)
                        WHERE 
                            mrecommend = @custid AND
                            transid > @transid AND
                            (statusid BETWEEN 0 AND 1) AND
						    matchid = 9 AND
						    bettype = 9
                    ) b
					INNER JOIN bettransm bm WITH(NOLOCK) ON bm.refno = b.refno				
					INNER JOIN match m WITH(NOLOCK) ON bm.matchid = m.matchid
					INNER JOIN @LeagueInput li ON m.leagueid = li.leagueid
			
				--Outright,HR
				INSERT INTO @BetList
				SELECT l.sporttype as sporttype,
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
				    (
                        SELECT TOP(@LimitRowCount)
                            username,bettype,transid,refno,transdate,matchid,betid,livehomescore,liveawayscore,liveindicator,hdp1,hdp2,odds,stake,status,betteam,IP,oddstype
                        FROM bettrans WITH(NOLOCK)
                        WHERE 
                            mrecommend = @custid AND
                            transid > @transid AND
                            (statusid BETWEEN 0 AND 1) AND
						    bettype = 10
                    ) b
					INNER JOIN outright m WITH(NOLOCK) ON b.matchid = m.orid
					INNER JOIN league l WITH(NOLOCK) ON m.leagueid = l.leagueid
					INNER JOIN @LeagueInput li ON m.leagueid = li.leagueid
			END
		END
		ELSE IF @sporttypegroup =1 -- soccer
		BEGIN
			--Single Bet
			INSERT INTO @BetList
			SELECT m.sporttype,
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
				0 as betid,
				b.livehomescore,
				b.liveawayscore,
				b.liveindicator,
				b.hdp1,
				b.hdp2,
				b.odds,
				--dbo.f_GetOddsByBettype(b.odds,b.bettype,b.oddstype) as odds,
				b.stake,		
				b.status,
				b.betteam,
				--dbo.f_GetChoice(b.betteam,b.bettype,@Language) betteam,		
				IP as IP,
				isnull(m.isNeutral,CONVERT(BIT,0)) as isNeutral,b.oddstype
				--dbo.f_ShowOddsByBettype(b.bettype,b.oddstype) as OddsType 
			FROM	
			    (
                    SELECT TOP(@LimitRowCount)
                        username,bettype,transid,refno,transdate,matchid,betid,livehomescore,liveawayscore,liveindicator,hdp1,hdp2,odds,stake,status,betteam,IP,oddstype
                    FROM bettrans WITH(NOLOCK)
                    WHERE 
                        mrecommend = @custid AND
                        transid > @transid AND
                        statusid BETWEEN 0 AND 1
                ) b
				INNER JOIN match m WITH(NOLOCK) ON b.matchid= m.matchid		
				INNER JOIN @LeagueInput li ON m.leagueid = li.leagueid
				INNER JOIN @BettypeGroupTbl bg ON bettypeGroup = @Bettypegroup AND b.bettype = bg.bettype2
            WHERE
				m.sporttype = 1 

			IF(@bettypegroup = 0 OR @bettypegroup = 99) 	
			BEGIN			
				--MixParlay
				INSERT INTO @BetList
				SELECT distinct 
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
					IP as IP,
					CONVERT(BIT,0) as isNeutral,
					0 as oddstype
				FROM	
				    (
                        SELECT TOP(@LimitRowCount)
                            username,bettype,transid,refno,transdate,matchid,betid,livehomescore,liveawayscore,liveindicator,hdp1,hdp2,odds,stake,status,betteam,IP,oddstype
                        FROM bettrans WITH(NOLOCK)
                        WHERE 
                            mrecommend = @custid AND
                            transid > @transid AND
                            (statusid BETWEEN 0 AND 1) AND
						    matchid = 9 AND
						    bettype = 9
                    ) b
					INNER JOIN bettransm bm WITH(NOLOCK) ON bm.refno = b.refno				
					INNER JOIN match m WITH(NOLOCK) ON bm.matchid = m.matchid
					INNER JOIN @LeagueInput li ON m.leagueid = li.leagueid
				WHERE
					m.sporttype = 1 

				--Outright,HR
				INSERT INTO @BetList
				SELECT l.sporttype as sporttype,
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
				    (
                        SELECT TOP(@LimitRowCount)
                            username,bettype,transid,refno,transdate,matchid,betid,livehomescore,liveawayscore,liveindicator,hdp1,hdp2,odds,stake,status,betteam,IP,oddstype
                        FROM bettrans WITH(NOLOCK)
                        WHERE 
                            mrecommend = @custid AND
                            transid > @transid AND
                            (statusid BETWEEN 0 AND 1) AND
						    bettype = 10
                    ) b
					INNER JOIN outright m WITH(NOLOCK) ON b.matchid = m.orid
						INNER JOIN league l WITH(NOLOCK) ON m.leagueid = l.leagueid
					INNER JOIN @LeagueInput li ON m.leagueid = li.leagueid
				WHERE
					l.sporttype = 1
			END	
		END
		ELSE -- others		
		BEGIN
			--Single Bet
			INSERT INTO @BetList
			SELECT m.sporttype,
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
				b.livehomescore,
				b.liveawayscore,
				b.liveindicator,
				b.hdp1,
				b.hdp2,
				b.odds,
				--dbo.f_GetOddsByBettype(b.odds,b.bettype,b.oddstype) as odds,
				b.stake,		
				b.status,
				b.betteam,
				--dbo.f_GetChoice(b.betteam,b.bettype,@Language) betteam,		
				IP as IP,
				isnull(m.isNeutral,CONVERT(BIT,0)) as isNeutral,b.oddstype
				--dbo.f_ShowOddsByBettype(b.bettype,b.oddstype) as OddsType 
			FROM	
			    (
                    SELECT TOP(@LimitRowCount)
                        username,bettype,transid,refno,transdate,matchid,betid,livehomescore,liveawayscore,liveindicator,hdp1,hdp2,odds,stake,status,betteam,IP,oddstype
                    FROM bettrans WITH(NOLOCK)
                    WHERE 
                        mrecommend = @custid AND
                        transid > @transid AND
                        statusid BETWEEN 0 AND 1
                ) b
				INNER JOIN match m WITH(NOLOCK) ON b.matchid= m.matchid			
				INNER JOIN @LeagueInput li ON m.leagueid = li.leagueid
				INNER JOIN @BettypeGroupTbl bg ON bettypeGroup = @Bettypegroup AND b.bettype = bg.bettype2
			WHERE
				m.sporttype <> 1 

			IF(@bettypegroup = 0 OR @bettypegroup = 99) 	
			BEGIN			
				--MixParlay
				INSERT INTO @BetList
				SELECT distinct 
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
					IP as IP,
					CONVERT(BIT,0) as isNeutral,
					0 as oddstype
				FROM	
				    (
                        SELECT TOP(@LimitRowCount)
                            username,bettype,transid,refno,transdate,matchid,betid,livehomescore,liveawayscore,liveindicator,hdp1,hdp2,odds,stake,status,betteam,IP,oddstype
                        FROM bettrans WITH(NOLOCK)
                        WHERE 
                            mrecommend = @custid AND
                            transid > @transid AND
                            (statusid BETWEEN 0 AND 1) AND
						    matchid = 9 AND
						    bettype = 9
                    ) b
					INNER JOIN bettransm bm WITH(NOLOCK) ON bm.refno = b.refno				
					INNER JOIN match m WITH(NOLOCK) ON bm.matchid = m.matchid
					INNER JOIN @LeagueInput li ON m.leagueid = li.leagueid
				WHERE
					m.sporttype <> 1 
				
				--Outright,HR
				INSERT INTO @BetList
				SELECT l.sporttype as sporttype,
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
				    (
                        SELECT TOP(@LimitRowCount)
                            username,bettype,transid,refno,transdate,matchid,betid,livehomescore,liveawayscore,liveindicator,hdp1,hdp2,odds,stake,status,betteam,IP,oddstype
                        FROM bettrans WITH(NOLOCK)
                        WHERE 
                            mrecommend = @custid AND
                            transid > @transid AND
                            (statusid BETWEEN 0 AND 1) AND
						    bettype = 10
                    ) b
					INNER JOIN outright m WITH(NOLOCK) ON b.matchid = m.orid
					INNER JOIN league l WITH(NOLOCK) ON m.leagueid = l.leagueid
					INNER JOIN @LeagueInput li ON m.leagueid = li.leagueid
				WHERE 
					l.sporttype <> 1 
			END	
		END
	END
	ELSE IF(@roleid = 2)
	BEGIN
		IF @sporttypegroup =0 -- get all sports
		BEGIN
			--Single Bet
			--INSERT INTO @BetList
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
				--dbo.f_GetOddsByBettype(b.odds,b.bettype,b.oddstype) as odds,
				b.stake,		
				b.status,
				b.betteam,		
				IP as IP,
				isnull(m.isNeutral,CONVERT(BIT,0)) as isNeutral,
				b.oddstype
				--dbo.f_ShowOddsByBettype(b.bettype,b.oddstype) as OddsType 
			FROM	
                bettrans b WITH(NOLOCK)
				INNER JOIN match m WITH(NOLOCK) ON b.matchid = m.matchid	
				INNER JOIN @LeagueInput li ON m.leagueid = li.leagueid
				INNER JOIN @BettypeGroupTbl bg ON bettypeGroup = @Bettypegroup AND b.bettype = bg.bettype2
			WHERE
				b.recommend = @custid AND
				b.transid > @transid AND
				b.statusid BETWEEN 0 AND 1
            ORDER BY b.transid DESC

			IF((@bettypegroup = 0 OR @bettypegroup = 99) and (1=0))
			BEGIN		
				--MixParlay
				INSERT INTO @BetList
				SELECT TOP(@LimitRowCount) --distinct 
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
					0 as oddstype
				FROM	
				    /*(
                        SELECT TOP(@LimitRowCount)
                            --bt.username,bm.bettype,bt.transid,bm.refno,bm.transdate,bm.matchid,bt.betid,bm.livehomescore,bm.liveawayscore,bm.liveindicator,bm.hdp1,bm.hdp2,bm.odds,bm.stake,bm.status,bm.betteam,bt.IP,bt.oddstype
                            bt.username,bm.bettype,0 as transid,bm.refno,bm.transdate,bm.matchid,0 as betid,bm.livehomescore,bm.liveawayscore,bm.liveindicator,bm.hdp1,bm.hdp2,bm.odds,bm.stake,bm.status,bm.betteam,null as IP,0 as oddstype
                        FROM bettrans bt WITH(NOLOCK)
                            INNER JOIN bettransm bm WITH(NOLOCK) ON bm.refno = bt.refno
                        WHERE 
                            bt.recommend = @custid AND
                            bt.transid > @transid AND
                            (bt.statusid BETWEEN 0 AND 1) AND
						    bt.matchid = 9 AND
						    bt.bettype = 9
                    ) b*/
                    bettrans b WITH(NOLOCK, INDEX= IX_recommend_transid)
					INNER JOIN bettransm bm WITH(NOLOCK) ON bm.refno = b.refno				
					INNER JOIN match m WITH(NOLOCK) ON b.matchid = m.matchid
					INNER JOIN @LeagueInput li ON m.leagueid = li.leagueid
				WHERE
					b.recommend = @custid AND
					b.transid > @transid AND
					(b.statusid BETWEEN 0 AND 1) AND
					b.matchid = 9 AND
					b.bettype = 9
				ORDER BY b.transid desc

				--Outright,HR
				INSERT INTO @BetList
				SELECT TOP(@LimitRowCount) l.sporttype as sporttype,
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
				    /*(
                        SELECT TOP(@LimitRowCount)
                            username,bettype,transid,refno,transdate,matchid,betid,livehomescore,liveawayscore,liveindicator,hdp1,hdp2,odds,stake,status,betteam,IP,oddstype
                        FROM bettrans WITH(NOLOCK)
                        WHERE 
                            recommend = @custid AND
                            transid > @transid AND
                            (statusid BETWEEN 0 AND 1) AND
						    bettype = 10
                    ) b*/
                    bettrans b WITH(NOLOCK)
					INNER JOIN outright m WITH(NOLOCK) ON b.matchid = m.orid
					INNER JOIN league l WITH(NOLOCK) ON m.leagueid = l.leagueid
					INNER JOIN @LeagueInput li ON m.leagueid = li.leagueid
				WHERE
					b.recommend = @custid AND
					b.transid > @transid AND
					(b.statusid BETWEEN 0 AND 1) AND
					b.bettype = 10 
				ORDER BY b.transid desc
			END
		END
		ELSE IF @sporttypegroup =1 -- soccer
		BEGIN
			--Single Bet
			INSERT INTO @BetList
			SELECT m.sporttype,
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
				0 as betid,
				b.livehomescore,
				b.liveawayscore,
				b.liveindicator,
				b.hdp1,
				b.hdp2,
				b.odds,
				--dbo.f_GetOddsByBettype(b.odds,b.bettype,b.oddstype) as odds,
				b.stake,		
				b.status,
				b.betteam,
				--dbo.f_GetChoice(b.betteam,b.bettype,@Language) betteam,		
				IP as IP,
				isnull(m.isNeutral,CONVERT(BIT,0)) as isNeutral,b.oddstype
				--dbo.f_ShowOddsByBettype(b.bettype,b.oddstype) as OddsType 
			FROM	
			    (
                    SELECT TOP(@LimitRowCount)
                        username,bettype,transid,refno,transdate,matchid,betid,livehomescore,liveawayscore,liveindicator,hdp1,hdp2,odds,stake,status,betteam,IP,oddstype
                    FROM bettrans WITH(NOLOCK)
                    WHERE 
                        recommend = @custid AND
                        transid > @transid AND
                        statusid BETWEEN 0 AND 1
                ) b
				INNER JOIN match m WITH(NOLOCK) ON b.matchid= m.matchid		
				INNER JOIN @LeagueInput li ON m.leagueid = li.leagueid
				INNER JOIN @BettypeGroupTbl bg ON bettypeGroup = @Bettypegroup AND b.bettype = bg.bettype2
			WHERE
				m.sporttype = 1 
			
			IF(@bettypegroup = 0 OR @bettypegroup = 99) 	
			BEGIN
				--MixParlay
				INSERT INTO @BetList
				SELECT distinct 
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
					IP as IP,
					CONVERT(BIT,0) as isNeutral,
					0 as oddstype
				FROM	
				    (
                        SELECT TOP(@LimitRowCount)
                            username,bettype,transid,refno,transdate,matchid,betid,livehomescore,liveawayscore,liveindicator,hdp1,hdp2,odds,stake,status,betteam,IP,oddstype
                        FROM bettrans WITH(NOLOCK)
                        WHERE 
                            recommend = @custid AND
                            transid > @transid AND
                            (statusid BETWEEN 0 AND 1) AND
						    matchid = 9 AND
						    bettype = 9
                    ) b
					INNER JOIN bettransm bm WITH(NOLOCK) ON bm.refno = b.refno				
					INNER JOIN match m WITH(NOLOCK) ON bm.matchid = m.matchid
					INNER JOIN @LeagueInput li ON m.leagueid = li.leagueid
				WHERE
					m.sporttype = 1 
					
				--Outright,HR
				INSERT INTO @BetList
				SELECT l.sporttype as sporttype,
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
				    (
                        SELECT TOP(@LimitRowCount)
                            username,bettype,transid,refno,transdate,matchid,betid,livehomescore,liveawayscore,liveindicator,hdp1,hdp2,odds,stake,status,betteam,IP,oddstype
                        FROM bettrans WITH(NOLOCK)
                        WHERE 
                            recommend = @custid AND
                            transid > @transid AND
                            (statusid BETWEEN 0 AND 1) AND
						    bettype = 10
                    ) b
					INNER JOIN outright m WITH(NOLOCK) ON b.matchid = m.orid
					INNER JOIN league l WITH(NOLOCK) ON m.leagueid = l.leagueid
					INNER JOIN @LeagueInput li ON m.leagueid = li.leagueid
				WHERE
					l.sporttype = 1 
			END
		END
		ELSE -- others		
		BEGIN
			--Single Bet
			INSERT INTO @BetList
			SELECT m.sporttype,
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
				b.livehomescore,
				b.liveawayscore,
				b.liveindicator,
				b.hdp1,
				b.hdp2,
				b.odds,
				--dbo.f_GetOddsByBettype(b.odds,b.bettype,b.oddstype) as odds,
				b.stake,		
				b.status,
				b.betteam,
				--dbo.f_GetChoice(b.betteam,b.bettype,@Language) betteam,		
				IP as IP,
				isnull(m.isNeutral,CONVERT(BIT,0)) as isNeutral,b.oddstype
				--dbo.f_ShowOddsByBettype(b.bettype,b.oddstype) as OddsType 
			FROM	
			    (
                    SELECT TOP(@LimitRowCount)
                        username,bettype,transid,refno,transdate,matchid,betid,livehomescore,liveawayscore,liveindicator,hdp1,hdp2,odds,stake,status,betteam,IP,oddstype
                    FROM bettrans WITH(NOLOCK)
                    WHERE 
                        recommend = @custid AND
                        transid > @transid AND
                        statusid BETWEEN 0 AND 1
                ) b
				INNER JOIN match m WITH(NOLOCK) ON b.matchid= m.matchid			
				INNER JOIN @LeagueInput li ON m.leagueid = li.leagueid
				INNER JOIN @BettypeGroupTbl bg ON bettypeGroup = @Bettypegroup AND b.bettype = bg.bettype2
			WHERE
				m.sporttype <> 1 

			IF(@bettypegroup = 0 OR @bettypegroup = 99) 	
			BEGIN			
				--MixParlay
				INSERT INTO @BetList
				SELECT distinct 
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
					IP as IP,
					CONVERT(BIT,0) as isNeutral,
					0 as oddstype
				FROM	
				    (
                        SELECT TOP(@LimitRowCount)
                            username,bettype,transid,refno,transdate,matchid,betid,livehomescore,liveawayscore,liveindicator,hdp1,hdp2,odds,stake,status,betteam,IP,oddstype
                        FROM bettrans WITH(NOLOCK)
                        WHERE 
                            recommend = @custid AND
                            transid > @transid AND
                            (statusid BETWEEN 0 AND 1) AND
						    matchid = 9 AND
						    bettype = 9
                    ) b
					INNER JOIN bettransm bm WITH(NOLOCK) ON bm.refno = b.refno				
					INNER JOIN match m WITH(NOLOCK) ON bm.matchid = m.matchid
					INNER JOIN @LeagueInput li ON m.leagueid = li.leagueid
				WHERE
					m.sporttype <> 1 

				--Outright,HR
				INSERT INTO @BetList
				SELECT l.sporttype as sporttype,
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
				    (
                        SELECT TOP(@LimitRowCount)
                            username,bettype,transid,refno,transdate,matchid,betid,livehomescore,liveawayscore,liveindicator,hdp1,hdp2,odds,stake,status,betteam,IP,oddstype
                        FROM bettrans WITH(NOLOCK)
                        WHERE 
                            recommend = @custid AND
                            transid > @transid AND
                            (statusid BETWEEN 0 AND 1) AND
						    bettype = 10
                    ) b
					INNER JOIN outright m WITH(NOLOCK) ON b.matchid = m.orid
					INNER JOIN league l WITH(NOLOCK) ON m.leagueid = l.leagueid
					INNER JOIN @LeagueInput li ON m.leagueid = li.leagueid
				WHERE 
					l.sporttype <> 1 
			END
		END
	END	
	
	/*SELECT TOP(@LimitRowCount)
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
	FROM @BetList b*/
	
	/*
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
	END*/
	
END


GO
GRANT EXECUTE ON [dbo].[Age_Monitor_BetlistSel] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_Monitor_BetlistSel] TO [bodbDownlineNetView]
GO
GRANT VIEW DEFINITION ON [dbo].[Age_Monitor_BetlistSel] TO [vnteam]