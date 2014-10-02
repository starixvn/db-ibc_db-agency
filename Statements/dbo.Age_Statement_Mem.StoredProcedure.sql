USE [bodb02]
GO
/****** Object:  StoredProcedure [dbo].[Age_Statement_Mem]    Script Date: 10/02/2014 09:17:15 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.Age_Statement_Mem    Script Date: 3/18/2014 3:18:56 AM ******/
/****** Object:  Stored Procedure dbo.Age_Statement_Mem    Script Date: 3/7/2014 3:34:56 PM ******/


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
	- 20130715@Johnson: fix report in case of @fromdate > BUDate (should get from @fromdate not BUDate)	
	- 20140214@Lukas: exclude bingo transfer & bingo pending transactions
	- 20140305@Kathy: modify formula of Outstanding amount to be calculated based on table Bettrans and TransLog [Redmine:#11550]
	- 20140930@Daniel: fix bug wrong Accu row in case cannot find any BU row before @fromDate

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

DECLARE @f_date DATETIME,
		@t_date DATETIME

SELECT @f_date = @fromdate,
		@t_date = @todate
		
IF @ToDate >= @BalanceUpDay
BEGIN 
	IF @FromDate > @BalanceUpDay SELECT @f_Date = @BalanceUpDay 
 
	;WITH rt
	AS(
		SELECT winlostdate, 
			bettype,  
			CASE   
				WHEN statusID IN (102,101) THEN 102 
				WHEN statusID IN (0,1) THEN 0
			ELSE 131 END as StatusId,	  
			CASE WHEN bettype <= 19999 THEN NULL ELSE transdate END as transdate,  
			CASE WHEN bettype <= 19999 THEN '' ELSE transdesc END as transdesc,  
			SUM(CASE WHEN bettrans.winlostdate >= @ABSDate 
					THEN case when bettrans.liveawayscore = 0 and bettrans.bettype IN(33,43) AND bettrans.livehomescore <> 0 AND ruben = 1 then ABS(bettrans.stake/2) else ABS(bettrans.stake) end
					ELSE case when bettrans.liveawayscore = 0 and bettrans.bettype IN(33,43) AND bettrans.livehomescore <> 0 AND ruben = 1 then bettrans.stake/2 else bettrans.stake end 
					END
					) as stake, --TurnOver,			
			SUM(actual_stake) as actual_stake, 
			SUM(winlost)	  as winlost, 
			SUM(playercomm)   as playercomm
		FROM bettrans (NOLOCK)  
		WHERE custid = @custid
			AND winlostdate BETWEEN @f_Date AND @t_Date 
		GROUP BY winlostdate, bettype,  
			CASE   
				WHEN statusID IN (102,101) THEN 102
				WHEN statusID IN (0,1) THEN 0
			ELSE 131 END,
			CASE WHEN bettype <= 19999 THEN NULL ELSE transdate END,  
			CASE WHEN bettype <= 19999 THEN '' ELSE transdesc END 
	
		UNION ALL
		SELECT winlostdate, 
				gameid as bettype,  
				0 as StatusId,
				NULL as transdate,
				'' transdesc,
				SUM(CASE WHEN winlostdate >= @ABSDate 
						THEN ABS(stake)
						ELSE stake  
					END
					) as stake, --TurnOver,			
				SUM(actual_stake) as actual_stake, 
				0 as winlost, 
				0  as playercomm
		FROM translog with(NOLOCK)
		WHERE statusid = 0
		AND custid = @custid
		AND winlostdate BETWEEN @f_Date AND @t_Date 
		GROUP BY winlostdate, gameid
	)

	INSERT INTO @bet 
	SELECT winlostdate, 
		   bettype,
		   statusID,
		   transdate, 
		   transdesc ,  
		   sum(stake) turnover , 
		   sum(actual_stake) , 
		   sum(winlost) , 
		   sum(playercomm) 
	FROM rt
	group BY winlostdate,
			bettype,
			statusId,
			transdate,
			transdesc

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
			and winlostdate between @f_Date and @MoveBetDay 	
		 

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
			AND bettype NOT IN (23001,23002,23101,23102,23201,23202)
	GROUP BY winlostdate  
	  
	INSERT INTO @Data  
	SELECT	2, transdate, UPPER(typenamee), TransDesc,  
			0, (winlost -actual_stake), 0 
	FROM @bet AS B INNER JOIN dbo.bettype (NOLOCK) ON B.bettype = bettype.typeid  
	WHERE bettype > 20000 AND bettype NOT IN (23001,23002,23101,23102,23201,23202) AND (winlost-actual_stake) <> 0	--20120405@Hurri
	  
END 

IF @FromDate < @BalanceUpDay
BEGIN 
	DECLARE	@PreBalanceUpDay DATETIME
	IF @ToDate >= DATEADD(dd,-1,@BalanceUpDay)
		SELECT @t_Date = DATEADD(dd,-1,@BalanceUpDay) + ' 23:59:59'
		
	SELECT	TOP 1 @PreBalanceUpDay = accdate  
	FROM	DBRPT.bodb_Report.dbo.Statement with (NOLOCK)
	WHERE	custid = @custid AND transdesc = 'OPENING BALANCE' AND accdate <= @f_date
	ORDER BY accdate DESC
	
	--if cannot find any old BU row, get BUDate from last BUDate before @fromdate
	if (@PreBalanceUpDay is NULL) 
	BEGIN
		SET @PreBalanceUpDay = @f_date
		WHILE(DATEPART(WEEKDAY, @PreBalanceUpDay) <> 7) SET @PreBalanceUpDay = DATEADD(dd, -1, @PreBalanceUpDay)  
	END	
	
	SELECT @f_Date = ISNULL(@PreBalanceUpDay,@f_Date)

	

	INSERT INTO @Data 
	SELECT	1, AccDate, 'BET', 'Betting Statement', 0,
			SUM(CASE transtype WHEN 'BET' THEN totalamt ELSE 0 END),
			SUM(CASE transtype WHEN 'COM' THEN totalamt ELSE 0 END)	
	FROM	DBRPT.bodb_Report.dbo.Statement WITH (NOLOCK)
	WHERE	custid = @custid
			AND accdate BETWEEN @f_Date AND @t_Date	
			AND transtype IN ('BET','COM')
	GROUP BY AccDate	

	INSERT INTO @Data 
	SELECT	CASE transtype WHEN 'BAL' THEN 0 ELSE 2 END,
			AccDate, UPPER(transtype), transdesc, 
			0, totalAmt, 0			
	FROM	DBRPT.bodb_Report.dbo.Statement WITH (NOLOCK)
	WHERE	custid = @custid
			AND accdate BETWEEN @f_Date AND @t_Date
			AND transtype NOT IN ('BET','COM')
END 


DECLARE @AccBal money

if (@fromdate <> @BalanceUpDay)
BEGIN
	--get acc bal from current (bettrans)
	SELECT @AccBal = isnull(SUM(totalamt),0) + isnull(SUM(Commission),0)
	FROM @Data
	where winlostdate < @fromdate
	
	IF EXISTS(select 1 from @Data where winlostdate >= @fromdate AND @AccBal <>0) 
		INSERT INTO @Data
		SELECT 0,'', 'BAL', 'ACCUMULATED BALANCE',0, @AccBal,0
END

SELECT	winlostdate, 
		transtype, 
		isnull(transdesc,'') transdesc,  
		turnover, 
		totalAmt, 
		commission
FROM	@Data  
WHERE winlostdate >= @fromdate OR transdesc = 'ACCUMULATED BALANCE'
ORDER BY winlostdate, OrderKey


GO
GRANT EXECUTE ON [dbo].[Age_Statement_Mem] TO [bodbDownlineNet] AS [dbo]
GO
GRANT EXECUTE ON [dbo].[Age_Statement_Mem] TO [bodbDownlineNetView] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[Age_Statement_Mem] TO [vnteam] AS [dbo]