USE [bodb02]
GO

ALTER PROCEDURE [dbo].[Age_Rpt_Outstanding_SAg]
	@CustID int 
AS

/*
Created: 
Task : Report Outstanding
DB: DBAGE.bodb02
Revisions:
    - 20090227@Hiep: Get more result for Casino Integration	
    - 20090422@Tuan: Two more columns ("CasinoTransfer" & "CasinoOustanding") for Casino
    - 20090716@Kiwi: Calculate data first then inner join with custinfo later.
    - 20100907@Jacob: Retrieve data for Bingo (BingoTransfer & BingoOutstanding)
    - 20101224@Johnson: Apply new arrange of bettype
    - 20110822@Sophia: Count Negative stake as positive turnover 
	- 20110927@Tom: 1. Add Report for P2P Games (Bettype: 23101)	
					2. Remove parameter @ABSDate ('2011-09-01')
					3. Remove betype 23101 in CasinoOutstanding 
	- 20140304@Kathy: modify formula of Outstanding amount to be calculated based on table Bettrans and TransLog [Redmine:#11550]   
	- 20150706@Sophia: Do not check ticket running of Metric gaming at bettrans table, because of the translog [#38789]
	- 20150907@Winnie: Do not check ticket running of Colosus bet at bettrans table, because of the translog [#43180]
	- 20151214@Percy: Do not check ticket running of Cock Fighting at bettrans table, because of the translog [#48601]
	- 20160108@Percy: Get data new bettype RNG Casino from bettransRNG [Redmine: #48283]
	- 20160204@Percy: Get data new product AllBet from bettransLC [Redmine: #50605]
	- 20160413@Percy: Support Voidbridge single wallet [Redmine: #55259]
	- 20160607@Percy: Enhance Performance - using right index on translog table [Redmine: #58288]
	- 20161028@Percy: Support Fishing World [RedmineID: #65731]
*/
SET NOCOUNT ON
/*
DECLARE @ABSDate DATETIME
SET @ABSDate = '2011-09-01'
*/

DECLARE @isTest BIT
SELECT  @isTest = dbo.f_CheckSPVersion(@@PROCID)

CREATE TABLE #SportBettype (ProductID INT, bettype INT, RefTable TINYINT)
INSERT INTO #SportBettype (ProductID, bettype, RefTable)
SELECT ProductID, bettype, RefTable FROM dbo.f_SportBettypeMatrix_Sel(0,0,0,2,'','',@isTest)

DECLARE @mrecommend TABLE (CustId INT PRIMARY KEY)
INSERT INTO @mrecommend (CustId)
SELECT CustId FROM dbo.custInfo (NOLOCK) WHERE roleid = 3 AND srecommend = @CustID

;with rt 
AS (
	SELECT	mrecommend,  
			--SUM(case when bettype <=19000 then CASE WHEN winlostdate >= @ABSDate THEN ABS(actual_stake) ELSE actual_stake END end) Outstanding,  
			SUM(CASE when bettype <=19000 then ABS(actual_stake) END) Outstanding,  
			SUM(case when bettype <=19000 then actual_stake * spositiontaking end) positiontaking,
			SUM(case when bettype = 23001 then actual_stake end) CasinoTransfer,
			SUM(case when bettype = 23002 then actual_stake end) CasinoOutstanding,
			SUM(CASE when bettype = 23101 then actual_stake END) P2PTransfer,
			SUM(CASE when bettype = 23102 then actual_stake END) P2POutstanding,					
			SUM(case when bettype = 23201 then actual_stake end) BingoTransfer,
			SUM(case when bettype = 23202 then actual_stake end) BingoOutstanding	
	FROM bettrans with (nolock) 
	WHERE	ruben=0
			/*
			AND bettype NOT BETWEEN 801 AND 899 -- Metric gaming
			AND bettype NOT IN (1003) -- Cock Fighting
			AND bettype NOT BETWEEN 2101 AND 2399 -- new RNG Casino
			AND bettype NOT BETWEEN 2401 AND 2499 -- AllBet
			AND bettype NOT BETWEEN 4001 AND 7999 -- Voidbridge
			*/
			AND bettype NOT IN (SELECT bettype FROM #SportBettype WHERE RefTable <> 0)
			AND srecommend =  @CustID
	GROUP BY mrecommend
	
	UNION ALL 
	SELECT	mrecommend,  
			SUM(ABS(actual_stake)) Outstanding,  
			SUM(actual_stake * spositiontaking) positiontaking,
			0,
			0,
			0,
			0,					
			0,
			0	
	FROM translog t with (nolock)
		INNER JOIN @mrecommend m ON t.mrecommend = m.CustId
	WHERE	statusid=0
	GROUP BY mrecommend

	UNION ALL -- bettransRNG
	SELECT	mrecommend,  
			SUM(ABS(actual_stake)) Outstanding,  
			SUM(actual_stake * spositiontaking) positiontaking,
			0,
			0,
			0,
			0,					
			0,
			0	
	FROM bettransRNG with (nolock) 
	WHERE	statusid=0
			AND srecommend =  @CustID
			--AND (gameID BETWEEN 2101 AND 2399 OR gameID BETWEEN 4001 AND 7999)
	GROUP BY mrecommend

	UNION ALL -- bettransLC
	SELECT	mrecommend,  
			SUM(ABS(actual_stake)) Outstanding,  
			SUM(actual_stake * spositiontaking) positiontaking,
			0,
			0,
			0,
			0,					
			0,
			0	
	FROM bettransLC with (nolock) 
	WHERE	statusid=0
			AND srecommend =  @CustID
			--AND gameID BETWEEN 2401 AND 2499
	GROUP BY mrecommend
)
SELECT	username, b.mrecommend as custid, 
		isnull(Outstanding, 0) Outstanding,
		isnull(positiontaking,0) positiontaking,
		isnull(CasinoTransfer,0) CasinoTransfer,
		isnull(CasinoOutstanding,0) CasinoOutstanding,
		isnull(P2PTransfer,0) P2PTransfer,
		isnull(P2POutstanding,0) P2POutstanding,		
		isnull(BingoOutstanding,0) BingoOutstanding,
		isnull(BingoTransfer,0) BingoTransfer
FROM custinfo AS c with (nolock)
INNER JOIN (SELECT mrecommend,
					SUM(ISNULL(Outstanding,0)) Outstanding,
					SUM(ISNULL(positiontaking,0)) positiontaking,
					SUM(ISNULL(CasinoTransfer,0)) CasinoTransfer,
					SUM(ISNULL(CasinoOutstanding,0)) CasinoOutstanding,
					SUM(ISNULL(P2PTransfer,0)) P2PTransfer,
					SUM(ISNULL(P2POutstanding,0)) P2POutstanding,
					SUM(ISNULL(BingoTransfer,0)) BingoTransfer,
					SUM(ISNULL(BingoOutstanding,0)) BingoOutstanding
			FROM rt
			GROUP BY mrecommend
			) b ON c.custid = b.mrecommend
ORDER BY username
DROP TABLE #SportBettype
GO
GRANT EXECUTE ON [dbo].[Age_Rpt_Outstanding_SAg] TO [bodbDownlineNet] AS [dbo]
GO
GRANT EXECUTE ON [dbo].[Age_Rpt_Outstanding_SAg] TO [bodbDownlineNetView] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[Age_Rpt_Outstanding_SAg] TO [vnteam] AS [dbo]
GO