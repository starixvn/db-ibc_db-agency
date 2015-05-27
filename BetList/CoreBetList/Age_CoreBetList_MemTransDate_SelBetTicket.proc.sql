USE [bodb02]
GO
/****** Object:  StoredProcedure [dbo].[Age_BetList_CoreMem_SelBetTicket]    Script Date: 5/5/2015 1:45:13 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[Age_CoreBetList_MemTransDate_SelBetTicket]
(
	-- MEM INFO
	@CustId 			INT
	, @Username			NVARCHAR(30)
	, @FromDate			DATE
	, @ToDate 			DATE
	-- PRODUCT - BETTYPE - STATUS
	, @BettypeMatrix	XML 			= NULL
	, @TransStatus		VARCHAR(250) 	= NULL
	, @Error			INT = 0 OUTPUT
	, @ErrorMsg			VARCHAR(250) = '' OUTPUT
)
AS
/*
	Created: Bobby.Nguyen
	Task : Aphla site - refactor betlist core 
	DB: DB053.bodb02
	Original: 

	Revisions:
		- 20150504@Bobby.Nguyen: Create new SP
	
	Param's Explanation:
		- @BettypeMatrix	: XML.format(<BettypeMatrix><row ProductID="1" Bettype="1" EventType="1" /></BettypeMatrix>)
		- @TransStatus		: string formation (0,1,102,103,111,112,113)
		- @SelDateType		: 0 - winlosdate | 1 - transdate
		
	Wrapped SP List:
		- Age_BetList_SelRunningByDate_Mem
		- Age_BetList_SelAllByDate_Mem
		
	Scope of tickets:
		- bettrans	: All products - all status
		- translog	: Keno & GD - running status only
*/
BEGIN
	SET NOCOUNT ON;
	
	DECLARE @Recommend		INT
	
	-- CHECK TransStatus
	IF ( OBJECT_ID('tempdb..#TransStatus') IS NULL )
	BEGIN
		CREATE TABLE #TransStatus (
			StatusID 		INT
		);
		INSERT INTO #TransStatus
		SELECT CAST(t.Val AS INT) 
		FROM [bodb02].[dbo].[Age_f_SplitString] (@TransStatus, ',') t
	END
	
	-- CHECK BettypeMatrix
	IF ( OBJECT_ID('tempdb..#BettypeMatrix') IS NULL )
	BEGIN
		CREATE TABLE #BettypeMatrix (
			ProductID 		INT
			, Bettype 		INT
			, EventType 	INT
		);
		WITH CteBT (ProductID, Bettype, EventType)
		AS (
			SELECT bt.Col.value('@ProductID'	,'INT')
				, bt.Col.value('@Bettype'		,'INT')
				, bt.Col.value('@EventType'		,'INT')
			FROM  @BettypeMatrix.nodes('//row') bt(Col)
		)
		INSERT INTO #BettypeMatrix
		SELECT *
		FROM CteBT bt
	END
	
	SELECT @Error			= 0
		, @ErrorMsg			= ''
	
	-- CHECK member info
	IF( @CustID IS NULL
		AND @UserName IS NOT NULL
	)
	BEGIN
		SELECT @CustID 	= CustID
		, @Recommend 	= Recommend 
		FROM dbo.custinfo WITH(NOLOCK) 
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
		FROM dbo.custinfo WITH(NOLOCK) 
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
	INSERT INTO #tempCust
	SELECT 
		b.transid
		, b.refno
		, b.custid
		, bt.ProductId
		, bt.EventType
		, 1 AS WhTicket
	FROM dbo.bettrans b WITH(nolock)
		INNER JOIN #BettypeMatrix bt
		ON b.bettype	= bt.bettype
		INNER JOIN #TransStatus stt
		ON b.statusid	= stt.statusid
	WHERE b.transdate	BETWEEN @fromdate AND @todate 
		AND	b.recommend	= @Recommend 
		AND	b.custid	= @CustID
	
	/* running tickets
		- Keno 			: ProductId = 8
		- GoldDelux		: ProductId = 12
		- Metric Gaming	: Bettype(801-899)
	*/
	IF (EXISTS(SELECT TOP 1 1 FROM #TransStatus WHERE StatusId IN (0,1)))
	BEGIN
		INSERT INTO #tempCust
		SELECT 
			b.translogid	AS transid
			, b.translogid 	AS refno
			, b.custid
			, bt.ProductId
			, bt.EventType
			, 0 AS WhTicket
		FROM dbo.translog AS b WITH (NOLOCK)
			INNER JOIN #BettypeMatrix bt 
			ON b.gameid		= bt.Bettype
			INNER JOIN #TransStatus st
			ON b.statusID	= st.StatusID
		WHERE	b.transdate		BETWEEN @fromdate AND @todate 
			AND	b.custid		= @CustID
			AND	(
				bt.ProductId	IN (8, 12) 
				OR bt.bettype BETWEEN 801 AND 899
			)
				
	END
	
	CREATE CLUSTERED INDEX [CIX_tempCust] ON #tempCust (WhTicket, eventType)
	--CALL to get ticket info
	EXEC [dbo].[Age_CoreBetList_BetTicket_SelMainInfo]
	
	DROP TABLE #tempCust;
	
	RETURN;
END
GO
GRANT EXECUTE ON [dbo].[Age_CoreBetList_MemTransDate_SelBetTicket] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_CoreBetList_MemTransDate_SelBetTicket] TO [bodbDownlineNetView]
GO
