USE bodb02
GO

ALTER PROCEDURE [dbo].[Age_BetList_SelWinlossByBettypeMatch_MAg]
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
Original:BetsSelBetListMatchWinLoss_MAg
Revisions:
    - 20071211@Phuc: For API
    - 20080108: add leaguename,typenamee2,sportname
    - 20080407@Phuc: Add matchid
    - 20080629@Viet: Remove Teamname, Leaguename, Sportname, TypeName
    - 20090326@Phuc: get indexname for FI
    - 20090406@HanhVu: remove refno
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
	- 20120927@Sophia: Get comstatus]
	- 20141016@Sophia: support Sporting solution-grouped bettype 
	- 20150209@Tom: Support 60 BetRadar (27218) Show betcheck coloum on Bettype 216,217 
	- 20150331@Cody: Apply sport bettype matrix [Remine: #30169]
	- 20150508@Bobby: Re-factor code and apply bettype matrix
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
	EXEC bodb02.dbo.Acc_SportBettypeMatrix_Sel_xtest @mode=4
	
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
		, @RoleId			= 3
		, @MatchId 			= @MatchID
		, @Liveindicator 	= @liveindicator
		, @Language 		= @Language
		
	RETURN;
END
GO
GRANT EXECUTE ON [dbo].[Age_BetList_SelWinlossByBettypeMatch_MAg] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_BetList_SelWinlossByBettypeMatch_MAg] TO [bodbDownlineNetView]
GO
GRANT VIEW DEFINITION ON [dbo].[Age_BetList_SelWinlossByBettypeMatch_MAg] TO vnteam