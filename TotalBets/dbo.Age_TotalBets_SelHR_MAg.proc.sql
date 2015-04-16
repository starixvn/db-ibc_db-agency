USE bodb02
GO

ALTER PROCEDURE [dbo].[Age_TotalBets_SelHR_MAg]
@custid int,
@Language varchar(2) = 'E'
 AS
 
/*
	Created: 
	Task : Retrieve Total Bet values for bettype HR
	DB: DBAGE.bodb02
	Original:

	Revisions:
		- 20060222: remove refno  
		- 20090520@AnhPham: add "turnover and winloss" information with PT for each bet type of HR
		-- 20100527@Henry: Change to use StatusID instead of Status in WHERE statement
		- 20101007@Henry: Change column transid from INT to BIGINT
		- 20101224@Johnson: change type of bettype to smallint in temporary table
		- 20120313@Lukas: modify winlostdate condition to get tickets of Aust racing (cross-date meetings)
		- 20150318@Cody: Apply sport bettype matrix
	Param's Explanation:
	• @CustID: Master Agent ID
*/

SET NOCOUNT ON

DECLARE @FromDate DATETIME
SELECT @FromDate = CONVERT(VARCHAR(10), CURRENT_TIMESTAMP,120)

DECLARE @SportBettype TABLE(
			ProductID INT
			,Bettype INT
			,EventType INT
		)
		
INSERT INTO @SportBettype
EXEC bodb02.dbo.Acc_SportBettypeMatrix_Sel @mode = 4

DECLARE @TotalBets TABLE(
			transid				BIGINT
			,bettype			SMALLINT
			,matchid			INT
			,stake				MONEY
			,mpositiontaking	SMALLMONEY
			,mwinlost			MONEY
			,ruben				TINYINT
			,GroupMatch			VARCHAR(20)
			,MatchCode			VARCHAR(10)
			,oddsstatus			VARCHAR(10)
			,eventdate			SMALLDATETIME
			,kickofftime		DATETIME
			,teamID				INT
			,leagueId			INT
		)
		
INSERT INTO @TotalBets(
			transid
			,bettype
			,matchid
			,stake
			,mpositiontaking
			,mwinlost
			,ruben
			,GroupMatch
			,MatchCode
			,oddsstatus
			,eventdate
			,kickofftime
			,teamID
			,leagueId
		)
    SELECT 
        b1.transid
	    ,b1.bettype
	    ,b1.matchid 
	    ,b1.stake
	    ,b1.mpositiontaking
	    ,b1.mwinlost
	    ,b1.ruben
	    ,m1.GroupMatch
	    ,m1.MatchCode 
	    ,m1.oddsstatus
	    ,m1.eventdate 
	    ,m1.kickofftime
	    ,m1.teamID
	    ,m1.leagueId 
    FROM 
	    bettrans b1 (NOLOCK)
	    INNER JOIN outright m1 (NOLOCK) ON b1.matchid = m1.orid
	    INNER JOIN @SportBettype s ON b1.bettype = s.Bettype
    WHERE 
	    b1.MRecommend = @CustID
	    AND s.ProductID = 2
	    --b1.bettype IN (31,32,41,42, 33, 43) AND 
	    AND m1.eventdate >= @fromdate
	    --b1.status NOT IN('reject','void','Refund')
	    AND b1.statusID NOT IN (101,102,103)
    
SELECT b2.leagueId,
		b2.Matchid,
		b2.GroupMatch AS Race,
		b2.MatchCode AS HorseNo,
		b2.TeamId,
		b2.oddsstatus,
		b2.eventdate,
		b2.kickofftime,
		SUM(CASE WHEN b2.bettype=31 THEN (b2.mpositiontaking * b2.stake) ELSE 0 END) AS Total_Win_Tote,
		SUM(CASE WHEN b2.bettype=31 AND b2.ruben=1 THEN b2.mwinlost ELSE 0 END) AS Winloss_Win_Tote,
		
		SUM(CASE WHEN b2.bettype=32 THEN (b2.mpositiontaking * b2.stake) ELSE 0 END) AS Total_Place_Tote,
		SUM(CASE WHEN b2.bettype=32 AND b2.ruben=1 THEN b2.mwinlost ELSE 0 END) AS Winloss_Place_Tote,
		
		SUM(CASE WHEN b2.bettype=33 THEN (bm.mpositiontaking * bm.stake) ELSE 0 END) AS Total_WinPlace_Tote,
		SUM(CASE WHEN b2.bettype=33 AND b2.ruben=1 THEN bm.mwinlost ELSE 0 END) AS Winloss_WinPlace_Tote,
		
		SUM(CASE WHEN b2.bettype=41 THEN (b2.mpositiontaking * b2.stake) ELSE 0 END) AS Total_Win_FO,
		SUM(CASE WHEN b2.bettype=41 AND b2.ruben=1 THEN b2.mwinlost ELSE 0 END) AS Winloss_Win_FO,
		
		SUM(CASE WHEN b2.bettype=42 THEN (b2.mpositiontaking * b2.stake) ELSE 0 END) AS Total_Place_FO,
		SUM(CASE WHEN b2.bettype=42 AND b2.ruben=1 THEN b2.mwinlost ELSE 0 END) AS Winloss_Place_FO,
		
		SUM(CASE WHEN b2.bettype=43 THEN (bm.mpositiontaking * bm.stake) ELSE 0 END) AS Total_WinPlace_FO,
		SUM(CASE WHEN b2.bettype=43 AND b2.ruben=1 THEN bm.mwinlost ELSE 0 END) AS Winloss_WinPlace_FO
FROM @TotalBets b2 LEFT JOIN bettransm bm (NOLOCK) ON b2.transid = bm.refno
GROUP BY b2.leagueId,
		b2.GroupMatch,
		b2.Matchid,
		b2.MatchCode,
		b2.TeamId,
		b2.oddsstatus,
		b2.eventdate,
		b2.kickofftime
ORDER BY 
	CASE WHEN b2.oddsstatus = 'running' THEN -1 ELSE 0 END ASC, b2.leagueId, cast(b2.GroupMatch as int), cast(b2.MatchCode as int)


GO
GRANT EXECUTE ON [dbo].[Age_TotalBets_SelHR_MAg] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_TotalBets_SelHR_MAg] TO [bodbDownlineNetView]
GO
GRANT VIEW DEFINITION ON [dbo].[Age_TotalBets_SelHR_MAg] TO [vnteam]
