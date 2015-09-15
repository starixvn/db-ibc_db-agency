USE [bodb_archive]
GO
/****** Object:  StoredProcedure [dbo].[Age_BetList_SelWinLossByDate_Mem]    Script Date: 3/10/2014 3:29:18 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[Age_CoreBetList_MemArc_SelBetTicket]
(
	-- MEM INFO
	@CustId 				INT
	, @FromDate				DATE
	, @ToDate 				DATE
	-- PRODUCT - BETTYPE - STATUS
	, @TransStatus 		[dbo].[TVP_BetTicketStatus]		READONLY
	, @BettypeMatrix	[dbo].[TVP_SportBettypeMatrix]	READONLY
	-- PAGING
	, @PageIndex			INT	= 1
	, @PageSize				INT	= 1000
	, @ColumnOutput			VARCHAR(MAX) 	= NULL
	-- OUTPUT INFO
	, @Error				INT = 0 OUTPUT
	, @ErrorMsg				VARCHAR(250) = '' OUTPUT
)
AS
/*
Created: Bobby.Nguyen
Task : Aphla site - refactor betlist core 
DB: DB0ARC.bodb_archive
Original: 

Revisions:
	- 20150504@Bobby.Nguyen: Create new SP

Param's Explanation:
	- @BettypeMatrix	: 
		+ VARCHAR(MAX) for remote call via linked server
		+ XML.format(<BettypeMatrix><row ProductID="1" Bettype="1" EventType="1" /></BettypeMatrix>)
		
Wrapped SP List:
	- Age_BetList_SelByDayAll_Mem_Old
	- Age_BetList_SelWinLossByDate_Mem_Old
	
Dependences:
		
*/
BEGIN
	SET NOCOUNT ON;
	
	DECLARE @Recommend 	INT
		, @Username		NVARCHAR(30)
		, @tempCust		dbo.TVP_TicketSportBettype
	
	SELECT @Error		= 0
		,@ErrorMsg		= ''
	
	SELECT @Recommend 	= Recommend 
		,@UserName		= UserName
	FROM bodb02.dbo.custinfo WITH(NOLOCK) 
	WHERE CustID		= @CustID
	
	IF(@Recommend IS NULL)
	BEGIN
		SELECT @Error 	= 100
			, @ErrorMsg	= 'The customer was not found.'
			
		RETURN;
		
	END
	
	INSERT INTO @tempCust
	SELECT 
		b.transid
		, b.refno
		, b.custid
		, bt.ProductId
		, b.bettype
		, bt.EventType
		, 3 AS WhTicket
	FROM dbo.bettrans_bk b WITH(nolock, INDEX=IX_custid)
		INNER JOIN @BettypeMatrix bt
		ON b.bettype	= bt.bettype
		INNER JOIN @TransStatus stt
		ON b.statusid	= stt.statusid
	WHERE b.winlostdate	BETWEEN @fromdate AND @todate 
		AND	b.custid	= @CustID
	
	--CALL to get ticket info
	EXEC [dbo].[Age_CoreBetList_BetTicket_SelMainInfoArc] @tempCust = @tempCust, @ColumnOutput = @ColumnOutput
	
	RETURN;
END

GO
GRANT EXECUTE ON [dbo].[Age_CoreBetList_MemArc_SelBetTicket] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_CoreBetList_MemArc_SelBetTicket] TO [bodbDownlineNetView]
GO