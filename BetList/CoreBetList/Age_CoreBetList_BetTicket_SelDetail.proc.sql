ALTER PROCEDURE [dbo].[Age_CoreBetList_BetTicket_SelDetail]
AS
/*
Created: Bobby.Nguyen
Task : Re-factor core betlist and apply GD product
DB: DBAGE.bodb02 & DBARC.bodb_archive
Original: 

Revisions:
	- 20150504@Bobby.Nguyen: Create new SP

Param's Explanation:
	
Dependences:
	- Age_CoreBetList_BetTicket_SelMainInfo
*/
BEGIN
	SET NOCOUNT ON;
	
	-- CHECK table member ticket
	IF ( OBJECT_ID('tempdb..#tempCust') IS NULL )
	BEGIN
		RAISERROR(
			N'The table input #tempCust was not found.'
			, 10
			, 1
		);
		RETURN;
	END

	-- CREATE output detail tickets
	CREATE TABLE #BettransDetail 
	(  
		refno 				BIGINT  
		, odds 				SMALLMONEY
		, stake 			MONEY
		, status 			NVARCHAR(10)
		, apositiontaking 	SMALLMONEY
		, mpositiontaking 	SMALLMONEY
		, spositiontaking 	SMALLMONEY
		, bettype 			SMALLINT
		, betteam 			NVARCHAR (10)
		, transdesc			VARCHAR (300)
	) 
	IF ( EXISTS (SELECT TOP 1 1 
			FROM #tempCust c
			WHERE c.ProductId IN (2, 5, 4, 12)
		)
	)
	BEGIN
		IF (EXISTS (SELECT TOP 1 1 FROM #tempCust WHERE WhTicket = 1)
			AND OBJECT_ID('bodb02.dbo.bettransm', 'U') IS NOT NULL
		)
		BEGIN
			--SELECT bettransm
			EXEC sp_sqlexec N'
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
				, '''' AS transdesc
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
				, '''' AS transdesc
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
				, '''' AS transdesc
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
				AND b.ProductId		= 12'
		END

		IF (EXISTS ( SELECT TOP 1 1 FROM #tempCust WHERE WhTicket = 2)
			AND OBJECT_ID('bodb02.dbo.bettransm14', 'U') IS NOT NULL
		)
		BEGIN
			--SELECT bettransm14
			EXEC sp_sqlexec N'
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
				, '''' AS transdesc
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
				, '''' AS transdesc
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
				, '''' AS transdesc
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
				AND b.ProductId		= 12'
		END
		
		

		IF (EXISTS ( SELECT TOP 1 1 FROM #tempCust WHERE WhTicket = 3)
			AND OBJECT_ID('bodb_archive.dbo.bettransm', 'U') IS NOT NULL
		)
		BEGIN
			--SELECT bettransm from archive
			EXEC sp_sqlexec N'
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
				, '''' AS transdesc
			FROM bodb_archive.dbo.bettransm bm WITH (NOLOCK)
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
				, '''' AS transdesc
			FROM bodb_archive.dbo.bettransm bm WITH (NOLOCK)
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
				, '''' AS transdesc
			FROM bodb_archive.dbo.bettransg bg WITH (NOLOCK)
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
			FROM bodb_archive.dbo.bettransg bg WITH (NOLOCK)
				INNER JOIN #tempCust b
				ON bg.refno			= b.transid
			WHERE bg.custid			= b.custid
				AND b.ProductId		= 12'
		END
	END

	-- OUTPUT ticket detail
	SELECT * 
	FROM #BettransDetail d
	ORDER BY d.refno DESC
	
	DROP TABLE #BettransDetail;
	RETURN;
END
GO
GO
GRANT EXECUTE ON [dbo].[Age_CoreBetList_BetTicket_SelDetail] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_CoreBetList_BetTicket_SelDetail] TO [bodbDownlineNetView]
GO