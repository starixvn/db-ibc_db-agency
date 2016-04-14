ALTER PROCEDURE [dbo].[Age_CustomerSelBalanceInfo_SAg]
	 @custid		INT,
	 @MoveBetsDay	DATETIME
AS
/*
	Created: Johnson
	Date: 2011-04-27
	DB: DBAGE.BODB02
	Task: Get Super Balance Info 
	
	Revisions:
		- 20110803@Johnson: Include commission into today winloss and yesterday winloss
		- 20160112@Percy: Expand new bettype for RNG Casino [Redmine: #48283]
		- 20160204@Percy: Support new product AllBet [Redmine: #50605]
		- 20160413@Percy: Support Voidbridge single wallet [Redmine: #55259]
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
WHERE srecommend = @custid AND roleid = 3

SELECT  @today_cashBalance  = ISNULL(SUM(swinlost + scomm - acomm),0),
		@today_totalBalance = ISNULL(SUM(swinlost + scomm + mwinlost + awinlost + winlost - actual_stake),0),
		@today_Winloss      = ISNULL(SUM(swinlost + scomm - acomm),0)
FROM bettrans WITH(NOLOCK)
WHERE srecommend = @custid 
	AND ruben = 1
	AND bettype < 19001 AND bettype NOT BETWEEN 2101 AND 2499
	AND bettype NOT BETWEEN 4001 AND 7999
	AND CONVERT(DATE, winlostdate) = @today

SELECT  @today_cashBalance  = @today_cashBalance  + ISNULL(SUM(swinlost + scomm - acomm),0),
		@today_totalBalance = @today_totalBalance + ISNULL(SUM(swinlost + scomm + mwinlost + awinlost + winlost - actual_stake),0),
		@today_Winloss      = @today_Winloss      + ISNULL(SUM(swinlost + scomm - acomm),0)
FROM bettransRNG WITH(NOLOCK)
WHERE srecommend = @custid 
	AND statusID NOT IN (0, 1)
	AND (gameID BETWEEN 2101 AND 2399 OR gameID BETWEEN 4001 AND 7999)
	AND CONVERT(DATE, winlostdate) = @today

SELECT  @today_cashBalance  = @today_cashBalance  + ISNULL(SUM(swinlost + scomm - acomm),0),
		@today_totalBalance = @today_totalBalance + ISNULL(SUM(swinlost + scomm + mwinlost + awinlost + winlost - actual_stake),0),
		@today_Winloss      = @today_Winloss      + ISNULL(SUM(swinlost + scomm - acomm),0)
FROM bettransLC WITH(NOLOCK)
WHERE srecommend = @custid 
	AND statusID NOT IN (0, 1)
	AND gameID BETWEEN 2401 AND 2499
	AND CONVERT(DATE, winlostdate) = @today

SELECT
	@cashBalance  = ISNULL(SUM(CASE WHEN custid = srecommend THEN winlost - actual_stake ELSE swinlost + scomm - acomm END),0),
	@totalBalance = ISNULL(SUM(CASE WHEN custid = srecommend THEN winlost - actual_stake ELSE swinlost+ scomm - acomm END)
					+ SUM(CASE WHEN custid = mrecommend THEN winlost - actual_stake ELSE mwinlost + acomm - comm END)
					+ SUM(CASE WHEN custid = recommend THEN winlost - actual_stake ELSE awinlost + comm - playercomm END)
					+ SUM(CASE WHEN custid <> srecommend AND custid <> mrecommend AND custid <> recommend AND ruben = 1 THEN winlost - actual_stake + playercomm ELSE 0 END),0)
FROM bettrans WITH(NOLOCK) 
WHERE srecommend = @custid
	AND (
			(CONVERT(DATE, winlostdate) >= @yesterday AND bettype NOT BETWEEN 2101 AND 2499 AND bettype NOT BETWEEN 4001 AND 7999)
			OR (CONVERT(DATE, winlostdate) < @yesterday)
		)

SELECT
	@cashBalance  = @cashBalance + ISNULL(SUM(CASE WHEN custid = srecommend THEN winlost - actual_stake ELSE swinlost + scomm - acomm END),0),
	@totalBalance = @totalBalance + ISNULL(SUM(CASE WHEN custid = srecommend THEN winlost - actual_stake ELSE swinlost+ scomm - acomm END)
					+ SUM(CASE WHEN custid = mrecommend THEN winlost - actual_stake ELSE mwinlost + acomm - comm END)
					+ SUM(CASE WHEN custid = recommend THEN winlost - actual_stake ELSE awinlost + comm - playercomm END)
					+ SUM(CASE WHEN custid <> srecommend AND custid <> mrecommend AND custid <> recommend AND statusID NOT IN (0, 1) THEN winlost - actual_stake + playercomm ELSE 0 END),0)
FROM bettransRNG WITH(NOLOCK) 
WHERE srecommend = @custid
	AND (gameID BETWEEN 2101 AND 2399 OR gameID BETWEEN 4001 AND 7999)
	AND CONVERT(DATE, winlostdate) >= @yesterday

SELECT
	@cashBalance  = @cashBalance + ISNULL(SUM(CASE WHEN custid = srecommend THEN winlost - actual_stake ELSE swinlost + scomm - acomm END),0),
	@totalBalance = @totalBalance + ISNULL(SUM(CASE WHEN custid = srecommend THEN winlost - actual_stake ELSE swinlost+ scomm - acomm END)
					+ SUM(CASE WHEN custid = mrecommend THEN winlost - actual_stake ELSE mwinlost + acomm - comm END)
					+ SUM(CASE WHEN custid = recommend THEN winlost - actual_stake ELSE awinlost + comm - playercomm END)
					+ SUM(CASE WHEN custid <> srecommend AND custid <> mrecommend AND custid <> recommend AND statusID NOT IN (0, 1) THEN winlost - actual_stake + playercomm ELSE 0 END),0)
FROM bettransLC WITH(NOLOCK) 
WHERE srecommend = @custid
	AND gameID BETWEEN 2401 AND 2499
	AND CONVERT(DATE, winlostdate) >= @yesterday

IF @yesterday <= @MoveBetsDay
	BEGIN
		SELECT @yesterday_Winloss = ISNULL(SUM(swinlost + scomm - acomm),0)
		FROM bettrans14 WITH(NOLOCK)
		WHERE srecommend = @custid
			AND ruben = 1 
			AND bettype < 19001 AND bettype NOT BETWEEN 2101 AND 2499 AND bettype NOT BETWEEN 4001 AND 7999
			AND CONVERT(DATE, winlostdate) = @yesterday

		SELECT @yesterday_Winloss = @yesterday_Winloss + ISNULL(SUM(swinlost + scomm - acomm),0)
		FROM bettransRNG14 WITH(NOLOCK)
		WHERE srecommend = @custid
			AND statusID NOT IN (0, 1)
			AND (gameID BETWEEN 2101 AND 2399 OR gameID BETWEEN 4001 AND 7999)
			AND CONVERT(DATE, winlostdate) = @yesterday

		SELECT @yesterday_Winloss = @yesterday_Winloss + ISNULL(SUM(swinlost + scomm - acomm),0)
		FROM bettransLC14 WITH(NOLOCK)
		WHERE srecommend = @custid
			AND statusID NOT IN (0, 1)
			AND gameID BETWEEN 2401 AND 2499
			AND CONVERT(DATE, winlostdate) = @yesterday
	END
ELSE
BEGIN
		SELECT @yesterday_Winloss = ISNULL(SUM(swinlost + scomm - acomm),0)
		FROM bettrans WITH(NOLOCK)
		WHERE srecommend = @custid
			AND ruben = 1 
			AND bettype < 19001 AND bettype NOT BETWEEN 2101 AND 2499 AND bettype NOT BETWEEN 4001 AND 7999
			AND CONVERT(DATE, winlostdate) = @yesterday

		SELECT @yesterday_Winloss = @yesterday_Winloss + ISNULL(SUM(swinlost + scomm - acomm),0)
		FROM bettransRNG WITH(NOLOCK)
		WHERE srecommend = @custid
			AND statusID NOT IN (0, 1)
			AND (gameID BETWEEN 2101 AND 2399 OR gameID BETWEEN 4001 AND 7999)
			AND CONVERT(DATE, winlostdate) = @yesterday

		SELECT @yesterday_Winloss = @yesterday_Winloss + ISNULL(SUM(swinlost + scomm - acomm),0)
		FROM bettransLC WITH(NOLOCK)
		WHERE srecommend = @custid
			AND statusID NOT IN (0, 1)
			AND gameID BETWEEN 2401 AND 2499
			AND CONVERT(DATE, winlostdate) = @yesterday
	END
	
SELECT	@username AS username,
		@cashBalance AS cashBalance,
		@cashBalance - @today_cashBalance AS yesterday_CashBalance,
		@totalBalance AS totalBalance,
		@totalBalance - @today_totalBalance  AS yesterday_totalBalance,
		@today_Winloss AS todayWinloss,
		@yesterday_winloss AS yesterdayWinloss,
		@givenCredit AS givenCredit,
		@memberCredit AS memberCredit


GO

GRANT EXECUTE ON [dbo].[Age_CustomerSelBalanceInfo_SAg] TO [bodbDownlineNet] AS [dbo]
GO

GRANT EXECUTE ON [dbo].[Age_CustomerSelBalanceInfo_SAg] TO [bodbDownlineNetView] AS [dbo]
GO

GRANT VIEW DEFINITION ON [dbo].[Age_CustomerSelBalanceInfo_SAg] TO [vnteam] AS [dbo]
GO