
ALTER PROCEDURE [dbo].[Age_Statement_Mem]
	@CustID 		INT,
	@FromDate		DATETIME,
	@ToDate			DATETIME,
	@BalanceUpDay	DATETIME,
	@MoveBetDay		DATETIME,
	@Language		NVARCHAR(2)='EN'
AS
/*
Created: 
Task : Daily Statement
DB: DBAGE/bodb02
Original: rptallstatement
Revisions:
	- 20060222@[]: remove refno.
	- 20071211@Phuc: for API.
	- 20080616@Viet.
    - 20090506@Simon: for casino.
    - 20090612@Phuc: exclude refund tickets.
    - 20091003@Phuc: include bet statement on bettrans14.
	- 20100317@Jamie: select the range of date and data archive 
	-- 20100527@Henry: Change to use StatusID instead of Status in WHERE statement
	- 20101224@Johnson: Apply new arrange of bettype
	- 20110616@Amy: modify to retrieve voided ticket from zzzbettrans before Move Bet Day
	- 20110725@Lukas: Get refund tickets
	- 20110822@Sophia: Count Negative stake as positive turnover
	- 20120405@Hurri: Add bettype 23102 (P2P Pending) into condition
	- 20130121@Dan: change linked server DB06 to DBRPT
Param's Explanation:	
• @ErrCode:
    = 0: add new member successfully.
    > 0: Specific Error.
  
• @ErrMsg: Error description.
*/
SET NOCOUNT ON

DECLARE @ABSDate DATETIME
SET @ABSDate = '2011-09-01'

DECLARE @bet TABLE (  
	winlostdate DATETIME, bettype SMALLINT, statusID TINYINT,  
	transdate DATETIME, transdesc NVARCHAR(300),  
	stake MONEY, actual_stake MONEY, winlost MONEY, playercomm MONEY) 

DECLARE @Data TABLE (
	OrderKey	TINYINT, 
	winlostdate DATETIME,  
	transtype	NVARCHAR(10), 
	transdesc	NVARCHAR(300),  
	TurnOver	MONEY, 
	totalAmt	MONEY, 	 --Debit < 0 and Credit >0  
	Commission	MONEY
)  

IF @ToDate >= @BalanceUpDay
BEGIN 
	IF @FromDate > @BalanceUpDay SELECT @FromDate = @BalanceUpDay 

	INSERT INTO @bet  
	SELECT winlostdate, bettype,  
		CASE   
			--WHEN status IN ('VOID','REJECT') THEN 'VOID'  
			WHEN statusID IN (102,101) THEN 102
			--WHEN status IN ('running', 'waiting') THEN 'running'  
			WHEN statusID IN (0,1) THEN 0
		--ELSE '' END,  
		ELSE 131 END,
	  
		CASE WHEN bettype <= 19999 THEN NULL ELSE transdate END,  
		CASE WHEN bettype <= 19999 THEN '' ELSE transdesc END,  
	  
		--SUM(CASE WHEN bettrans.bettype IN(33,43) AND bettrans.liveawayscore = 0 AND bettrans.livehomescore <> 0 AND ruben = 1
		--	THEN bettrans.stake/2 ELSE bettrans.stake END),
		SUM(CASE WHEN bettrans.winlostdate >= @ABSDate 
				THEN case when bettrans.liveawayscore = 0 and bettrans.bettype IN(33,43) AND bettrans.livehomescore <> 0 AND ruben = 1 then ABS(bettrans.stake/2) else ABS(bettrans.stake) end
				ELSE case when bettrans.liveawayscore = 0 and bettrans.bettype IN(33,43) AND bettrans.livehomescore <> 0 AND ruben = 1 then bettrans.stake/2 else bettrans.stake end 
				END
				) as TurnOver,			
		SUM(actual_stake), SUM(winlost), SUM(playercomm)  
	FROM bettrans (NOLOCK)  
	WHERE custid = @custid
		AND winlostdate BETWEEN @fromDate AND @toDate 
		--AND status not in ('Refund') 
		--AND statusID <> 103
	GROUP BY winlostdate, bettype,  
		CASE   
			--WHEN status IN ('VOID','REJECT') THEN 'VOID'  
			WHEN statusID IN (102,101) THEN 102
			--WHEN status IN ('running', 'waiting') THEN 'running'  
			WHEN statusID IN (0,1) THEN 0
		--ELSE '' END,  
		ELSE 131 END,
		CASE WHEN bettype <= 19999 THEN NULL ELSE transdate END,  
		CASE WHEN bettype <= 19999 THEN '' ELSE transdesc END 
		
	IF @fromDate <= @MoveBetDay
		INSERT INTO @bet
		select distinct 
			winlostdate,
			bettype,
			102 statusID,
			transdate,			
			'Cancelled/Deleted Bets' transdesc, 
			(CASE WHEN winlostdate >= @ABSDate THEN ABS(stake) ELSE stake END) as stake, 
			stake,
			0,
			0 
		from zzzbettrans with (nolock)
		where bettype between 1 and 19999 
			and custid=@CustID 
			and winlostdate between @FromDate and @MoveBetDay 	
		 

	INSERT INTO @Data  
	SELECT	0, winlostdate, 'BAL', 'OPENING BALANCE',  
			0, SUM(winlost-actual_stake) , 0  
	FROM	@bet  
	WHERE	bettype = 20000  
	GROUP BY winlostdate  
	  
	INSERT INTO @Data  
	SELECT 1, winlostdate, 'BET', 'Betting Statement',  
			SUM(stake), SUM(winlost-actual_stake), SUM(playercomm) Commission
	FROM	@bet  
	WHERE	bettype <= 19999 
			--AND status = ''  
			AND statusID = 131
	GROUP BY winlostdate  
	  
	INSERT INTO @Data  
	SELECT	2, winlostdate, 'BET', 'Void/Cancelled Bet',  
			SUM(stake), 0, 0 
	FROM	@bet  
	WHERE	
			--status = 'VOID'  
			statusID = 102
	GROUP BY winlostdate  
	  
	INSERT INTO @Data  
	SELECT	3, winlostdate, 'BET', 'Outstanding Bet',  
			SUM(stake), 0, 0
	FROM	@bet  
	WHERE	
			--status = 'running'  
			statusID = 0
	GROUP BY winlostdate  
	  
	INSERT INTO @Data  
	SELECT	2, transdate, UPPER(typenamee), TransDesc,  
			0, (winlost -actual_stake), 0 
	FROM @bet AS B INNER JOIN dbo.bettype (NOLOCK) ON B.bettype = bettype.typeid  
	WHERE bettype > 20000 AND bettype NOT IN (23001,23002,23101,23102) AND (winlost-actual_stake) <> 0	--20120405@Hurri
	  
END 
IF @FromDate < @BalanceUpDay
BEGIN 
	DECLARE	@PreBalanceUpDay DATETIME
	IF @ToDate >= DATEADD(dd,-1,@BalanceUpDay)
		SELECT @ToDate = DATEADD(dd,-1,@BalanceUpDay) + ' 23:59:59'
	SELECT	TOP 1 @PreBalanceUpDay = accdate  
	FROM	DBRPT.bodb_Report.dbo.Statement with (NOLOCK)
	WHERE	custid = @custid AND transdesc = 'OPENING BALANCE' AND accdate <= @fromdate
	ORDER BY accdate DESC
	
	SELECT @FromDate = ISNULL(@PreBalanceUpDay,@FromDate)

	INSERT INTO @Data 
	SELECT	1, AccDate, 'BET', 'Betting Statement', 0,
			SUM(CASE transtype WHEN 'BET' THEN totalamt ELSE 0 END),
			SUM(CASE transtype WHEN 'COM' THEN totalamt ELSE 0 END)	
	FROM	DBRPT.bodb_Report.dbo.Statement WITH (NOLOCK)
	WHERE	custid = @custid
			AND accdate BETWEEN @FromDate AND @ToDate	
			AND transtype IN ('BET','COM')
	GROUP BY AccDate	

	INSERT INTO @Data 
	SELECT	CASE transtype WHEN 'BAL' THEN 0 ELSE 2 END,
			AccDate, UPPER(transtype), transdesc, 
			0, totalAmt, 0			
	FROM	DBRPT.bodb_Report.dbo.Statement WITH (NOLOCK)
	WHERE	custid = @custid
			AND accdate BETWEEN @FromDate AND @ToDate
			AND transtype NOT IN ('BET','COM')
END 

SELECT	winlostdate, 
		transtype, 
		isnull(transdesc,'') transdesc,  
		turnover, 
		totalAmt, 
		commission
FROM	@Data  
ORDER BY winlostdate, OrderKey



GO
GRANT EXECUTE ON [dbo].[Age_Statement_Mem] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_Statement_Mem] TO [bodbDownlineNetView]
GO
GRANT VIEW DEFINITION ON [dbo].[Age_Statement_Mem] TO [VNTeam]
GO


