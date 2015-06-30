USE [bodb02]
GO
/****** Object:  StoredProcedure [dbo].[Age_CoreBetList_Mem_SelBetTicket]    Script Date: 5/11/2015 10:31:30 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[Age_CoreBetList_Mem_SelBetTicket]
(
	-- MEM INFO
	@CustId 			INT				= NULL
	, @UserName 		NVARCHAR(30)	= NULL
	, @FromDate			DATE
	, @ToDate 			DATE
	, @MoveBetsDay 		DATE			= NULL
	, @BalanceupDay		DATE			= NULL
	-- PRODUCT - BETTYPE - STATUS
	, @BettypeMatrix	XML 			= NULL
	, @TransStatus		VARCHAR(250) 	= NULL
	-- PAGING
	, @PageIndex		INT				= 1
	, @PageSize			INT				= 5000
	, @Language 		VARCHAR(2) 		= 'E'
	--OPTIONAL
	, @SelDateType		TINYINT			= 0
	, @ColumnOutput		VARCHAR(MAX) 	= NULL
	-- OUTPUT INFO
	, @TotalRows		INT 			= 0 OUTPUT
	, @Error			INT 			= 0 OUTPUT
	, @ErrorMsg			VARCHAR(250) 	= '' OUTPUT
)
AS
/*
	Created: Bobby.Nguyen
	Task : Re-factor core betlist and apply GD product
	DB: DB0AGE.bodb02, DB0ARC.bodb_archive
	Original: 

	Revisions:
		- 20150504@Bobby.Nguyen: Create new SP
	
	Param's Explanation:
		- @BettypeMatrix	: XML.format(<BettypeMatrix><row ProductID="1" Bettype="1" EventType="1" /></BettypeMatrix>)
		- @TransStatus		: string formation (0,1,102,103,111,112,113)
		- @SelDateType		: 0 - winlosdate | 1 - transdate
		
	Wrapped SP List:
		- Age_BetList_SelWinLossByDate_Mem
		- Age_BetList_SelByDayAll_Mem
		
	Scope of tickets:
		- bettrans	: All products - all status
		- translog	: Keno & GD - running status only
		- bettrans14: [MoveBetDay] All product - all status
*/
BEGIN
	SET NOCOUNT ON;
	
	DECLARE @Recommend 	INT
	
	-- CHECK for MoveBetsDay
	IF( @MoveBetsDay IS NULL )
	BEGIN
		SELECT @MoveBetsDay = MAX(Winlostdate) 
		FROM bodb02.dbo.bettrans14 WITH (NOLOCK)
	END
	
	-- CHECK for BalanceupDay
	IF( @BalanceupDay IS NULL )
	BEGIN
		SELECT @BalanceupDay = MIN(Winlostdate) 
		FROM bodb02.dbo.bettrans14 WITH (NOLOCK)
	END
	
	-- RESTET output
	SELECT @TotalRows		= 0
		,@Error				= 0
		,@ErrorMsg			= ''
	
	-- CHECK member info
	IF( @CustID IS NULL
		AND @UserName IS NOT NULL
	)
	BEGIN
		SELECT @CustID 	= CustID
		, @Recommend 	= Recommend 
		FROM bodb02.dbo.custinfo WITH(NOLOCK) 
		WHERE UserName	= @UserName
	END
	
	IF( @CustID > 0
		AND (@Recommend IS NULL 
			OR @UserName IS NULL
		)
	)
	BEGIN
		SELECT @Recommend 	= Recommend 
		,@UserName			= UserName
		FROM bodb02.dbo.custinfo WITH(NOLOCK) 
		WHERE CustID		= @CustID
	END
	
	IF(@Recommend IS NULL)
	BEGIN
		SELECT @Error 	= 100
			, @ErrorMsg	= 'The customer was not found.'
			
		RETURN;
	END
	
	CREATE TABLE #tempCust 
	( 
		transid			BIGINT
		, refno			BIGINT
		, custid 		INT 
		, productId 	INT 
		, eventType		TINYINT
		, WhTicket		TINYINT
	)
		
	-- do selecting from bettrans
	IF ( @ToDate > @MoveBetsDay )
	BEGIN
		INSERT INTO #tempCust
		SELECT 
			b.transid
			, b.refno
			, b.custid
			, bt.ProductId
			, bt.EventType
			, 1 AS WhTicket
		FROM bodb02.dbo.bettrans b WITH(nolock)
			INNER JOIN #BettypeMatrix bt
			ON b.bettype	= bt.bettype
			INNER JOIN #TransStatus stt
			ON b.statusid	= stt.statusid
			LEFT JOIN [dbo].[SportBettypeMatrix] sp
			ON bt.ProductId = sp.ProductId 
			AND bt.bettype 	= sp.bettype
		WHERE b.winlostdate	BETWEEN @fromdate AND @todate 
			AND	b.recommend	= @Recommend 
			AND	b.custid	= @CustID
			--exclude running tickets of MetricGaming
			AND (sp.SubProduct IS NULL 
				OR (sp.SubProduct IN('MG-SuperLive') AND b.statusID NOT IN (0, 1))
			) 
		
		/* 	select running tickets
			- Keno 			: ProductId = 8
			- GoldDelux		: ProductId = 12
			- Sportsbook	: Metric Gaming bettype(801-899)
		*/
		IF (
			EXISTS(SELECT TOP 1 1 FROM #TransStatus WHERE StatusId IN (0,1))
		)
		BEGIN
			INSERT INTO #tempCust
			SELECT 
				b.translogid	AS transid
				, b.translogid 	AS refno
				, b.custid
				, bt.ProductId
				, bt.EventType
				, 0 AS WhTicket
			FROM bodb02.dbo.translog AS b WITH (NOLOCK)
				INNER JOIN #BettypeMatrix bt 
				ON b.gameid			= bt.Bettype
				INNER JOIN #TransStatus st
				ON b.statusID		= st.StatusID
			WHERE b.winlostdate	BETWEEN @fromdate AND @todate 
				AND b.custid		= @CustID
				AND	(bt.ProductId	IN (8, 12)
					OR bt.Bettype BETWEEN 801 AND 899
				)
				AND b.statusID IN (0, 1)
		END
	END
	-- CHECK for bettrans14
	IF ( @FromDate <= @MoveBetsDay )
	BEGIN
		INSERT INTO #tempCust
		SELECT 
			b.transid
			, b.refno
			, b.custid
			, bt.ProductId
			, bt.EventType
			, 2 AS WhTicket
		FROM bodb02.dbo.bettrans14 b WITH(nolock)
			INNER JOIN #BettypeMatrix bt
			ON b.bettype	= bt.bettype
			INNER JOIN #TransStatus stt
			ON b.statusid	= stt.statusid
		WHERE b.winlostdate	BETWEEN @fromdate AND @todate 
			AND	b.recommend	= @Recommend 
			AND	b.custid	= @CustID
	END
	-- CHECK for bettrans_bk
	/*IF ( @FromDate < @BalanceupDay )
	BEGIN
		
		DECLARE @bettypeMatrixInfo 	VARCHAR(MAX)
			, @transStatusInfo		VARCHAR(250)

		SET @bettypeMatrixInfo 	= CONVERT( VARCHAR(MAX)
				, ( SELECT *
					FROM #BettypeMatrix AS bt
					FOR XML RAW, ROOT('BettypeMatrix')
				) )
		
		SELECT @transStatusInfo = COALESCE(@transStatusInfo + ',', '') + CAST(t.StatusID AS VARCHAR(20)) + ''
		FROM #TransStatus t		

		INSERT INTO #tempCust
		EXEC [DBARC].[bodb_archive].[dbo].[Age_CoreBetList_MemArc_SelBetTicket] 
			@CustID			= @CustID 
			,@FromDate 		= @FromDate
			,@ToDate 		= @ToDate
			,@BettypeMatrix	= @bettypeMatrixInfo
			,@TransStatus	= @transStatusInfo
		
	END
	*/
	CREATE CLUSTERED INDEX [CIX_tempCust] ON #tempCust (WhTicket, eventType)
	--CALL to get ticket info
	EXEC [dbo].[Age_CoreBetList_BetTicket_SelMainInfo]
	@ColumnOutput = @ColumnOutput
	
	DROP TABLE #tempCust;
	RETURN;
END
GO
GRANT EXECUTE ON [dbo].[Age_CoreBetList_Mem_SelBetTicket] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_CoreBetList_Mem_SelBetTicket] TO [bodbDownlineNetView]
GO
