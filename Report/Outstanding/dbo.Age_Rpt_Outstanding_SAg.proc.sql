USE [bodb02]
GO
/****** Object:  StoredProcedure [dbo].[Age_Rpt_Outstanding_SAg]    Script Date: 9/7/2015 2:47:48 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.Age_Rpt_Outstanding_SAg    Script Date: 9/3/2015 9:23:28 AM ******/
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
*/
SET NOCOUNT ON
/*
DECLARE @ABSDate DATETIME
SET @ABSDate = '2011-09-01'
*/

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
			AND bettype NOT BETWEEN 801 AND 899
			AND bettype <>18000
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
	FROM translog with (nolock) 
	WHERE	statusid=0
			AND srecommend =  @CustID
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