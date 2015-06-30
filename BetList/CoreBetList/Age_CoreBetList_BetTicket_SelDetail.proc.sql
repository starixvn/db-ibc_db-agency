USE [bodb02]
GO
/****** Object:  StoredProcedure [dbo].[Age_CoreBetList_Mem_SelBetTicket]    Script Date: 5/11/2015 10:31:30 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[Age_CoreBetList_BetTicket_SelDetail]
AS
/*
	Created: Bobby.Nguyen
	Task : Re-factor core betlist and apply GD product
	DB: DB053.bodb02
	Original: 

	Revisions:
		- 20150504@Bobby.Nguyen: Create new SP
	
	Param's Explanation:
		- @BettypeMatrix	: XML.format(<BettypeMatrix><row ProductID="1" Bettype="1" EventType="1" /></BettypeMatrix>)
		- @TransStatus		: string formation (0,1,102,103,111,112,113)
		- @SelDateType		: 0 - winlosdate | 1 - transdate
		
	Wrapped SP List:
		- Age_CoreBetList_Mem_SelBetTicket
*/
BEGIN
	SET NOCOUNT ON;
	
	-- CHECK table member ticket
	IF ( OBJECT_ID('tempdb..#MemBetTicket') IS NULL )
	BEGIN
		RAISERROR(
			N'The table input MemBetTicket was not found.'
			, 10
			, 1
		);
		RETURN;
	END
			
	IF (EXISTS (SELECT TOP 1 1 FROM #tempCust WHERE WhTicket = 1))
	BEGIN
		--SELECT bettransm
		INSERT INTO #BettransDetail
		SELECT 
			bm.refno 
			, bm.odds 
			, bm.stake
			, bm.status 
			, bm.apositiontaking
			, bm.mpositiontaking 
			, bm.spositiontaking
			, bm.bettype
			, bm.betteam  
			, '' AS transdesc
		FROM dbo.bettransm bm WITH (NOLOCK)
			INNER JOIN #tempCust b 
			ON bm.refno			= b.transid
		WHERE bm.custid			= b.custid
			AND b.ProductId		= 2
			
		UNION ALL
		SELECT 
			bm.refno 
			, bm.odds 
			, bm.stake
			, bm.status 
			, bm.apositiontaking
			, bm.mpositiontaking 
			, bm.spositiontaking
			, bm.bettype
			, bm.betteam  
			, '' AS transdesc
		FROM dbo.bettransm bm WITH (NOLOCK)
			INNER JOIN #tempCust b 
			ON bm.refno			= b.refno
		WHERE bm.custid			= b.custid
			AND b.ProductID		= 5

		-- SELECT bettransg
		INSERT INTO #BettransDetail
		SELECT 
			bg.refno 
			, bg.odds 
			, bg.stake
			, bg.status 
			, bg.apositiontaking
			, bg.mpositiontaking 
			, bg.spositiontaking
			, bg.bettype
			, bg.betteam 
			, '' AS transdesc
		FROM dbo.bettransg bg WITH (NOLOCK)
			INNER JOIN #tempCust b
			ON bg.refno			= b.refno
		WHERE bg.custid			= b.custid
			AND b.ProductId		= 4

		UNION ALL
		SELECT 
			bg.refno 
			, bg.odds 
			, bg.stake
			, bg.status 
			, bg.apositiontaking
			, bg.mpositiontaking 
			, bg.spositiontaking
			, bg.bettype
			, bg.betteam 
			, bg.transdesc
		FROM dbo.bettransg bg WITH (NOLOCK)
			INNER JOIN #tempCust b
			ON bg.refno			= b.transid
		WHERE bg.custid			= b.custid
			AND b.ProductId		= 12
	END
	
	IF (EXISTS ( SELECT TOP 1 1 FROM #tempCust WHERE WhTicket = 2))
	BEGIN
		--SELECT bettransm14
		INSERT INTO #BettransDetail
		SELECT 
			bm.refno 
			, bm.odds 
			, bm.stake
			, bm.status 
			, bm.apositiontaking
			, bm.mpositiontaking 
			, bm.spositiontaking
			, bm.bettype
			, bm.betteam  
			, '' AS transdesc
		FROM dbo.bettransm14 bm WITH (NOLOCK)
			INNER JOIN #tempCust b 
			ON bm.refno			= b.transid
		WHERE bm.custid			= b.custid
			AND b.ProductId		= 2
			
		UNION ALL
		SELECT 
			bm.refno 
			, bm.odds 
			, bm.stake
			, bm.status 
			, bm.apositiontaking
			, bm.mpositiontaking 
			, bm.spositiontaking
			, bm.bettype
			, bm.betteam  
			, '' AS transdesc
		FROM dbo.bettransm14 bm WITH (NOLOCK)
			INNER JOIN #tempCust b 
			ON bm.refno			= b.refno
		WHERE bm.custid			= b.custid
			AND b.ProductId		= 5

		-- SELECT bettransg14
		INSERT INTO #BettransDetail
		SELECT 
			bg.refno 
			, bg.odds 
			, bg.stake
			, bg.status 
			, bg.apositiontaking
			, bg.mpositiontaking 
			, bg.spositiontaking
			, bg.bettype
			, bg.betteam 
			, '' AS transdesc
		FROM dbo.bettransg14 bg WITH (NOLOCK)
			INNER JOIN #tempCust b
			ON bg.refno			= b.refno
		WHERE bg.custid			= b.custid
			AND b.ProductId		= 4

		UNION ALL
		SELECT 
			bg.refno 
			, bg.odds 
			, bg.stake
			, bg.status 
			, bg.apositiontaking
			, bg.mpositiontaking 
			, bg.spositiontaking
			, bg.bettype
			, bg.betteam 
			, bg.transdesc
		FROM dbo.bettransg14 bg WITH (NOLOCK)
			INNER JOIN #tempCust b
			ON bg.refno			= b.transid
		WHERE bg.custid			= b.custid
			AND b.ProductId		= 12
	END
	
	RETURN;
END
GO
GO
GRANT EXECUTE ON [dbo].[Age_CoreBetList_BetTicket_SelDetail] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_CoreBetList_BetTicket_SelDetail] TO [bodbDownlineNetView]
GO