USE bodb02
GO

ALTER PROCEDURE [dbo].[Age_BetList_SelWinlossByBettypeMatch_SAg]
	@MatchID 			INT
	, @custid 			INT	= NULL
	, @username 		VARCHAR(50) = NULL
	, @bettype 			INT
	, @Language 		VARCHAR(2) = 'E'
	, @liveindicator 	INT = 0
AS
/*
Created: 
Task : Betlist
DB: DBAGE.bodb02
Original:BetsSelBetListMatchWinLoss_SAg
Revisions:
    - 20071211@Phuc: For API
    - 20080629@Viet: Remove Teamname, Leaguename, Sportname, TypeName
    - 20090326@Phuc: get indexname for FI
    - 20090407@HanhVu: remove refno
    - 20090416@Minh: remove indexName
    - 20090421@[HiepVo]: Include more columns: comm, acomm, scomm, awinlost, mwinlost, swinlost
    - 20090505@HiepVo: Change formula of commission
    - 20090618@AnhPham: Remove 'Customer' table
	- 20090710@Phuc: unhide IP for TB currency.
	- 20101123@Jacob: Add column betid in select clause
	- 20110408@Amy: Change function to get Odds value and showed odds type
	- 20110809@Sophia: Add a new parametter @liveindicator
	- 20110811@Sophia: Add new columns actual_stake and modds 
	- 20111216@Sophia: Remove function f_GetOddsByBettype , f_GetChoice , f_ShowOddsByBettype
	- 20120112@Sophia:  Add refno, showtime for Table - Shoe - Hand of LiveCasino 
						Add Sub table for Live Casino
	- 20120927@Sophia: Get comstatus
	- 20141016@Sophia: support Sporting solution-grouped bettype 
	- 20150209@Tom: Support 60 BetRadar (27218) Show betcheck coloum on Bettype 216,217 		
	- 20150331@Cody: Aplly sport bettype matrix [Redmine: #30169]
	- 20150522@Bobby: Rollback code caused by holding core bet list
	- 20150526@Bobby: Re-factor code and apply bettype matrix
*/
BEGIN
	SET NOCOUNT ON;
	
	-- Gather Ticket status
	CREATE TABLE #TransStatus (
		StatusID 		INT
	);
	INSERT INTO #TransStatus
	SELECT StatusId
	FROM bodb02.dbo.All_f_TransStatus (1) stt	
	
	-- Gather BettypeMatrix
	CREATE TABLE #BettypeMatrix (
		ProductID 		INT
		, Bettype 		INT
		, EventType 	INT
	);
	INSERT INTO #BettypeMatrix
	EXEC bodb02.dbo.Acc_SportBettypeMatrix_Sel @mode=4
	
	;WITH CteBettype (bettype)
	AS (
		SELECT bt.bettype
		FROM #BettypeMatrix bt
			LEFT JOIN (SELECT Bettype, GroupTypeId 
				FROM [dbo].[f_GroupBettype]()
			) AS  f 
			ON f.bettype 		= bt.bettype	
		WHERE bt.bettype		= @bettype 
			OR f.GroupTypeId 	= @bettype
	)
	DELETE bt
	FROM #BettypeMatrix bt
		LEFT JOIN CteBettype ct 
		ON bt.bettype = ct.bettype
	WHERE ct.bettype IS NULL
		
	EXEC [bodb02].[dbo].[Age_CoreBetList_SMAEventBettype_SelBetTicket]
		@CustId 			= @CustId
		,@username			= @username
		, @RoleId			= 4
		, @MatchId 			= @MatchID
		, @Liveindicator 	= @liveindicator
		, @Language 		= @Language
		, @ColumnOutput		= 'sporttype,
								username,
								bettype,
								leagueID,		
								transid,
								matchcode,
								homeID,
								awayID,
								hdp1, 
								hdp2, 
								odds,
								modds,
								status,
								stake,
								actual_stake,
								winlost,
								awinlost,
								mwinlost,
								swinlost,
								playercomm,
								comm,
								acomm,
								scomm,
								transdate,
								winlostdate,
								betteam,
								apositiontaking,
								mpositiontaking,
								spositiontaking,	
								Adiscount,
								Mdiscount,
								Sdiscount,	
								liveindicator,
								livehomescore,
								liveawayscore,
								matchid, 
								IP,
								betstatus,
								IsNeutral,
								OddsType,
								betid,
								showtime,
								refno,
								betcheck,		
								comstatus,
								transdesc'
		
	RETURN;
END

GO
GRANT EXECUTE ON [dbo].[Age_BetList_SelWinlossByBettypeMatch_SAg] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_BetList_SelWinlossByBettypeMatch_SAg] TO [bodbDownlineNetView]
GO
GRANT VIEW DEFINITION ON [dbo].[Age_BetList_SelWinlossByBettypeMatch_SAg] TO vnteam
GO