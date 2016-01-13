ALTER PROCEDURE [dbo].[Age_CustomerSelBalanceInfo_MAg]
	 @custid		INT,
	 @MoveBetsDay	DATETIME	
AS
/*
	Created: Johnson
	Date: 2011-05-31
	DB: DBAGE.BODB02
	Task: Get Master Balance Info 
	
	Revisions:
		- 20110803@Johnson: Include commission into today winloss and yesterday winloss
		- 20160112@Percy: Expand new bettype for RNG Casino [Redmine: #48283]
*/
SET NOCOUNT ON 

DECLARE @username nvarchar(50),
		@roleid INT, 
		@givenCredit MONEY,
		@memberCredit MONEY,
		@cashBalance MONEY, 
		@today_cashBalance MONEY, 
		@today_totalBalance MONEY,
		@totalBalance MONEY,
		@today_Winloss MONEY,
		@yesterday_Winloss MONEY,
		@cashBalanceRNG MONEY, 
		@today_cashBalanceRNG MONEY, 
		@today_totalBalanceRNG MONEY,
		@totalBalanceRNG MONEY,
		@today_WinlossRNG MONEY,
		@yesterday_WinlossRNG MONEY,
		@today DATE,
		@yesterday DATE
		
		
SELECT @today = CONVERT(DATE, GETDATE())
SELECT @yesterday = DATEADD(dd, -1, @today)	

SELECT @username = username ,
		@givenCredit = ISNULL(Credit,0) 
FROM custinfo WITH(NOLOCK) 
WHERE custid = @custid	

SELECT @memberCredit = ISNULL(SUM(credit),0)
FROM custinfo WITH(NOLOCK)
WHERE mrecommend = @custid AND roleid = 2

SELECT  @today_cashBalance = iSNULL(SUM(mwinlost + acomm - comm),0),
		@today_totalBalance = ISNULL(SUM(mwinlost + acomm + awinlost + winlost - actual_stake),0),
		@today_Winloss = ISNULL(SUM(mwinlost + acomm - comm),0)
FROM bettrans WITH(NOLOCK)
WHERE mrecommend = @custid
	AND bettype < 19001 AND bettype NOT BETWEEN 2101 AND 2399
	AND ruben = 1	
	AND CONVERT(DATE, winlostdate) = @today

SELECT  @today_cashBalanceRNG = iSNULL(SUM(mwinlost + acomm - comm),0),
		@today_totalBalanceRNG = ISNULL(SUM(mwinlost + acomm + awinlost + winlost - actual_stake),0),
		@today_WinlossRNG = ISNULL(SUM(mwinlost + acomm - comm),0)
FROM bettransRNG WITH(NOLOCK)
WHERE mrecommend = @custid
	AND statusID NOT IN (0, 1, 101, 102)
	AND gameID BETWEEN 2101 AND 2399
	AND CONVERT(DATE, winlostdate) = @today

SELECT
	@cashBalance = ISNULL(SUM(CASE WHEN custid = mrecommend AND bettype NOT BETWEEN 2101 AND 2399 THEN winlost - actual_stake ELSE mwinlost + acomm - comm END),0),
	@totalBalance = ISNULL(SUM(CASE WHEN custid = mrecommend AND bettype NOT BETWEEN 2101 AND 2399 THEN winlost - actual_stake ELSE mwinlost+ acomm - comm END)					
					+ SUM(CASE WHEN custid = recommend AND bettype NOT BETWEEN 2101 AND 2399 THEN winlost - actual_stake ELSE awinlost + comm - playercomm END)
					+ SUM(CASE WHEN custid <> srecommend AND custid <> mrecommend AND custid <> recommend AND ruben = 1 AND bettype NOT BETWEEN 2101 AND 2399 THEN winlost - actual_stake + playercomm ELSE 0 END),0),
	@cashBalanceRNG = ISNULL(SUM(CASE WHEN custid = mrecommend AND bettype BETWEEN 2101 AND 2399 AND CONVERT(DATE, winlostdate) < @yesterday THEN winlost - actual_stake ELSE mwinlost + acomm - comm END),0),
	@totalBalanceRNG = ISNULL(SUM(CASE WHEN custid = mrecommend AND bettype BETWEEN 2101 AND 2399 AND CONVERT(DATE, winlostdate) < @yesterday THEN winlost - actual_stake ELSE mwinlost+ acomm - comm END)					
					+ SUM(CASE WHEN custid = recommend AND bettype BETWEEN 2101 AND 2399 AND CONVERT(DATE, winlostdate) < @yesterday THEN winlost - actual_stake ELSE awinlost + comm - playercomm END)
					+ SUM(CASE WHEN custid <> srecommend AND custid <> mrecommend AND custid <> recommend AND ruben = 1 AND bettype BETWEEN 2101 AND 2399 AND CONVERT(DATE, winlostdate) < @yesterday THEN winlost - actual_stake + playercomm ELSE 0 END),0)
FROM bettrans WITH(NOLOCK) 
WHERE mrecommend = @custid

SELECT
	@cashBalanceRNG = @cashBalanceRNG + ISNULL(SUM(CASE WHEN custid = mrecommend THEN winlost - actual_stake ELSE mwinlost + acomm - comm END),0),
	@totalBalanceRNG = @totalBalanceRNG + ISNULL(SUM(CASE WHEN custid = mrecommend THEN winlost - actual_stake ELSE mwinlost+ acomm - comm END)					
					+ SUM(CASE WHEN custid = recommend THEN winlost - actual_stake ELSE awinlost + comm - playercomm END)
					+ SUM(CASE WHEN custid <> srecommend AND custid <> mrecommend AND custid <> recommend AND statusID NOT IN (0, 1, 101, 102) THEN winlost - actual_stake + playercomm ELSE 0 END),0)
FROM bettransRNG WITH(NOLOCK) 
WHERE mrecommend = @custid
	AND gameID BETWEEN 2101 AND 2399
	AND CONVERT(DATE, winlostdate) >= @yesterday

IF @yesterday <= @MoveBetsDay
BEGIN
	SELECT @yesterday_Winloss = ISNULL(SUM(mwinlost + acomm - comm),0)
	FROM bettrans14 WITH(NOLOCK)
	WHERE 
		 mrecommend = @custid
		 AND ruben = 1
		 AND bettype < 19001
		 AND CONVERT(DATE, winlostdate) = @yesterday 

	SELECT @yesterday_WinlossRNG = ISNULL(SUM(mwinlost + acomm - comm),0)
	FROM bettransRNG14 WITH(NOLOCK)
	WHERE 
		 mrecommend = @custid
		 AND statusID NOT IN (0, 1, 101, 102)
		 AND gameID BETWEEN 2101 AND 2399
		 AND CONVERT(DATE, winlostdate) = @yesterday
END
ELSE
BEGIN
	SELECT @yesterday_Winloss = ISNULL(SUM(mwinlost + acomm - comm),0)
	FROM bettrans WITH(NOLOCK)
	WHERE 
		 mrecommend = @custid
		 AND ruben = 1
		 AND bettype < 19001
		 AND CONVERT(DATE, winlostdate) = @yesterday

	SELECT @yesterday_WinlossRNG = ISNULL(SUM(mwinlost + acomm - comm),0)
	FROM bettransRNG WITH(NOLOCK)
	WHERE 
		 mrecommend = @custid
		 AND statusID NOT IN (0, 1, 101, 102)
		 AND gameID BETWEEN 2101 AND 2399
		 AND CONVERT(DATE, winlostdate) = @yesterday
END	
	
SELECT	@username AS username,
		@cashBalance + @cashBalanceRNG AS cashBalance,
		@cashBalance + @cashBalanceRNG - @today_cashBalance +  - @today_cashBalanceRNG AS yesterday_CashBalance,
		@totalBalance + @totalBalanceRNG AS totalBalance,
		@totalBalance + @totalBalanceRNG - @today_totalBalance  - @today_totalBalanceRNG  AS yesterday_totalBalance,
		@today_Winloss + @today_WinlossRNG AS todayWinloss,
		@yesterday_Winloss + @yesterday_WinlossRNG AS yesterdayWinloss,
		@givenCredit AS givenCredit,
		@memberCredit AS memberCredit



GO
GRANT EXECUTE ON [dbo].[Age_CustomerSelBalanceInfo_MAg] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_CustomerSelBalanceInfo_MAg] TO [bodbDownlineNetView]
GO
GRANT VIEW DEFINITION ON [dbo].[Age_CustomerSelBalanceInfo_MAg] TO [vnteam]
GO