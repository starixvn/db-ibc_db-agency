USE [bodb02]
GO
/****** Object:  StoredProcedure [dbo].[Age_CoreBetList_Mem_SelBetTicket]    Script Date: 5/11/2015 10:31:30 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[Age_CoreBetList_BetTicket_SelMainInfo]
AS
/*
Created: Bobby.Nguyen
Task : Re-factor core bet list
DB: DBAGE.bodb02 & DBARC.bodb_archive
Original: 

Revisions:
	- 20150504@Bobby.Nguyen: Create new SP - Apply GD product
	- 20150526@Bobby.Nguyen: Apply metric-gaming bettype

Param's Explanation:
	
	
Dependences:
	- CREATE TABLE #tempCust 
	( 
		transid			BIGINT
		, refno			BIGINT
		, custid 		INT 
		, productId 	INT 
		, eventType		TINYINT
		, WhTicket		TINYINT
	)
*/
BEGIN
	SET NOCOUNT ON;
	
	-- CHECK dependences tables 
	IF ( OBJECT_ID('tempdb..#tempCust') IS NULL )
	BEGIN
		RAISERROR(
			N'The table input of bet list detail was not found.'
			, 10
			, 1
		);
		RETURN;
	END
	-- CREATE output main info ticket
	CREATE TABLE #MemBetTicket
	(
		TransId 			BIGINT
		, RefNo 			BIGINT	
		, custid 			INT
		, Username 			NVARCHAR(30)
		, Sporttype 		SMALLINT
		, Bettype 			SMALLINT
		, BetId 			BIGINT
		, Betteam 			NVARCHAR(20)
		, hdp1 				SMALLMONEY
		, hdp2 				SMALLMONEY 
		, OddsType 			TINYINT
		, Odds 				SMALLMONEY 
		, modds 			SMALLMONEY
		, Stake 			MONEY
		, actual_stake 		MONEY
		, Status 			NVARCHAR(10)
		, transdate 		DATETIME
		, winlostdate 		DATETIME
		, winlost 			MONEY
		, awinlost 			MONEY
		, mwinlost 			MONEY
		, swinlost 			MONEY
		, playerComm		MONEY
		, comm				MONEY
		, acomm				MONEY
		, scomm				MONEY
		, apositiontaking	SMALLMONEY
		, mpositiontaking	SMALLMONEY
		, spositiontaking	SMALLMONEY
		, adiscount 		SMALLMONEY
		, mdiscount 		SMALLMONEY
		, sdiscount 		SMALLMONEY
		, liveindicator 	BIT
		, livehomescore 	SMALLINT
		, liveawayscore 	SMALLINT
		, finalhomescore 	SMALLINT
		, finalawayscore 	SMALLINT 
		, hthomescore 		SMALLINT
		, htawayscore 		SMALLINT 
		, IP 				NVARCHAR(15)
		, LeagueId 			INT
		, MatchId 			INT
		, MatchCode 		NVARCHAR(50)
		, Race 				NVARCHAR(20)
		, eventdate 		DATETIME
		, HomeId 			INT
		, AwayId 			INT 	
		, Betstatus 		NVARCHAR(50)
		, isNeutral 		BIT
		, showtime 			NVARCHAR(50)
		, betcheck 			NVARCHAR(50)
		, comstatus 		NVARCHAR(20)
		, transdesc			NVARCHAR(300)
	);
	
	-- CHECK for selecting from translog
	IF (EXISTS (SELECT TOP 1 1 FROM #tempCust WHERE WhTicket = 0))
	BEGIN
		EXEC [dbo].[Age_CoreBetList_BetTicket_SelTranslog]
	END
	
	-- CHECK for selecting from bettrans
	IF (EXISTS (SELECT TOP 1 1 FROM #tempCust WHERE WhTicket = 1))
	BEGIN
		EXEC [dbo].[Age_CoreBetList_BetTicket_SelBettrans]
	END
	
	-- CHECK for selecting from bettrans14
	IF (EXISTS (SELECT TOP 1 1 FROM #tempCust WHERE WhTicket = 2))
	BEGIN
		EXEC [dbo].[Age_CoreBetList_BetTicket_SelBettrans14]
	END
	
	-- CHECK for selecting from bettrans_bk
	IF (EXISTS (SELECT TOP 1 1 FROM #tempCust WHERE WhTicket = 3))
	BEGIN
		EXEC [dbo].[Age_CoreBetList_BetTicket_SelBettransArc]
	END
	
	-- OUTPUT main ticket
	SELECT *
	FROM #MemBetTicket t
	ORDER BY t.transid DESC
	
	DROP TABLE #MemBetTicket;
	
	-- 	OUTPUT ticket in detail
	EXEC [dbo].[Age_CoreBetList_BetTicket_SelDetail]
	RETURN;
END
GO
GRANT EXECUTE ON [dbo].[Age_CoreBetList_BetTicket_SelMainInfo] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_CoreBetList_BetTicket_SelMainInfo] TO [bodbDownlineNetView]
GO
